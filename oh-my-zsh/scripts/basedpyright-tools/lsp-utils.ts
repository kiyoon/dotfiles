import * as fs from "node:fs"
import * as path from "node:path"
import type { createMessageConnection } from "vscode-jsonrpc"
import {
  DidCloseTextDocumentNotification,
  DidOpenTextDocumentNotification,
  DidRenameFilesNotification,
  type Position,
  type TextDocumentEdit,
  TextDocumentItem,
  type TextEdit,
  WillRenameFilesRequest,
  type WorkspaceEdit,
} from "vscode-languageserver-protocol"
import { URI } from "vscode-uri"
import { walkPythonFiles } from "./file-utils.ts"

export const uriToPath = (uri: string) => URI.parse(uri).fsPath

/**
 * Remove no-op entries from a WorkspaceEdit and return a cleaned version.
 */
export function cleanupWorkspaceEdit(edit: WorkspaceEdit): WorkspaceEdit {
  if (!edit) {
    return edit
  }
  if (!edit.documentChanges) {
    // if there are no documentChanges, we can just return the edit as is
    return edit
  }
  // from documentChanges (list of TextDocumentEdit), remove ones with no edits
  const cleaned: WorkspaceEdit = {
    ...edit,
    documentChanges: edit.documentChanges.filter(
      dc => "edits" in dc && (dc as TextDocumentEdit).edits.length > 0,
    ),
  }
  return cleaned
}

// export function applyWorkspaceEditLocally(edit: WorkspaceEdit) {
//   if (!edit?.documentChanges) return
//   for (const dc of edit.documentChanges) {
//     if ("edits" in dc) {
//       const tde = dc as TextDocumentEdit
//       // **skip** no-op entries
//       if (!tde.edits || tde.edits.length === 0) {
//         continue
//       }
//       const file = uriToPath(tde.textDocument.uri)
//       let content = fs.readFileSync(file, "utf8")
//
//       // apply from bottom to top so offsets stay valid
//       ;[...tde.edits]
//         .sort(
//           (a, b) =>
//             b.range.start.line - a.range.start.line ||
//             b.range.start.character - a.range.start.character,
//         )
//         .forEach((e: TextEdit) => {
//           const { start, end } = e.range
//
//           // convert Position -> absolute offset
//           const toOff = (p: Position) =>
//             content
//               .split(/\r?\n/)
//               .slice(0, p.line)
//               .reduce((n, ln) => n + ln.length + 1, 0) + p.character
//
//           const st = toOff(start)
//           const en = toOff(end)
//           content = content.slice(0, st) + e.newText + content.slice(en)
//         })
//
//       fs.writeFileSync(file, content)
//     }
//   }
// }

/**
 * Apply a set of TextEdits to a string, bottom→top so offsets stay valid.
 */
function applyTextEdits(content: string, edits: TextEdit[]): string {
  // sort descending by start position
  return edits
    .slice()
    .sort(
      (a, b) =>
        b.range.start.line - a.range.start.line ||
        b.range.start.character - a.range.start.character,
    )
    .reduce((text, e) => {
      const { start, end } = e.range

      // compute offset in this text
      const toOffset = (pos: Position) =>
        text
          .split(/\r?\n/)
          .slice(0, pos.line)
          .reduce((n, ln) => n + ln.length + 1, 0) + pos.character

      const s = toOffset(start)
      const en = toOffset(end)
      return text.slice(0, s) + e.newText + text.slice(en)
    }, content)
}

export function applyWorkspaceEditLocally(edit: WorkspaceEdit) {
  if (!edit.documentChanges) return

  for (const dc of edit.documentChanges) {
    if (!("edits" in dc)) continue
    const tde = dc as TextDocumentEdit
    if (!tde.edits || tde.edits.length === 0) continue

    const parsed = URI.parse(tde.textDocument.uri)
    const filePath = parsed.fsPath

    // --- Handle notebooks specially ---
    if (filePath.endsWith(".ipynb") && parsed.fragment) {
      const cellIndex = Number(parsed.fragment)
      if (!Number.isSafeInteger(cellIndex)) {
        console.warn("Invalid notebook cell index:", parsed.fragment)
        continue
      }

      // load the notebook JSON
      const raw = fs.readFileSync(filePath, "utf8")
      const nb = JSON.parse(raw)
      if (!Array.isArray(nb.cells) || cellIndex >= nb.cells.length) {
        console.warn("Cell index out of range for", filePath, "→", cellIndex)
        continue
      }

      // 2) find the JSON index of the nth *code* cell
      const codeCellIndices: number[] = []
      nb.cells.forEach((cell: any, idx: number) => {
        if (cell.cell_type === "code") codeCellIndices.push(idx)
      })
      if (cellIndex < 0 || cellIndex >= codeCellIndices.length) {
        console.warn("Notebook code-cell index out of range:", cellIndex)
        continue
      }
      const jsonIdx = codeCellIndices[cellIndex]
      const cell = nb.cells[jsonIdx]
      const origSource = Array.isArray(cell.source)
        ? cell.source.join("")
        : cell.source

      // apply edits
      const newSource = applyTextEdits(origSource, tde.edits)

      // write it back into the cell.source array (preserving newlines)
      // Note: Jupyter expects an array of lines; we split on line breaks,
      // but keep the trailing "\n" so diffs stay sane.
      const newLines = newSource
        .split(/\r?\n/)
        .map((ln, i, arr) =>
          i < arr.length - 1 ? `${ln}\n` : ln.length ? ln : "",
        )
      cell.source = newLines

      // finally, rewrite the whole notebook (2-space indent)
      fs.writeFileSync(filePath, JSON.stringify(nb, null, 2), "utf8")
    } else {
      // --- otherwise, plain‐text file (py, txt, etc) ---
      const content = fs.readFileSync(filePath, "utf8")
      const newContent = applyTextEdits(content, tde.edits)
      fs.writeFileSync(filePath, newContent, "utf8")
    }
  }
}

/**
 * Rename a single directory `oldDir` → `newDir`:
 *  - asks the LS for workspace edits (import-fixes)
 *  - applies those edits locally
 *  - renames the folder on disk
 *  - tells the LS via didRenameFiles
 *  - closes & re-opens every .py under that folder
 */
export async function renameDirectory(
  conn: ReturnType<typeof createMessageConnection>,
  oldDir: string,
  newDir: string,
) {
  const oldUri = URI.file(oldDir).toString()
  const newUri = URI.file(newDir).toString()

  // 1) ask for the import-fix workspace edit
  const edit: WorkspaceEdit = await conn.sendRequest(
    WillRenameFilesRequest.method,
    { files: [{ oldUri, newUri }] },
  )
  if (edit) {
    applyWorkspaceEditLocally(edit)
  }

  // 2) rename the folder on disk
  fs.mkdirSync(path.dirname(newDir), { recursive: true })
  fs.renameSync(oldDir, newDir)

  // 3) notify the server
  conn.sendNotification(DidRenameFilesNotification.method, {
    files: [{ oldUri, newUri }],
  })

  // 4) close all .py under the old path
  for (const f of walkPythonFiles(newDir)) {
    // the LS previously knew them under oldDir, so we need to close oldUri:
    const oldFileUri = URI.file(f.replace(newDir, oldDir)).toString()
    conn.sendNotification(DidCloseTextDocumentNotification.method, {
      textDocument: { uri: oldFileUri },
    })
  }

  // 5) reopen them under the new path
  for (const f of walkPythonFiles(newDir)) {
    const uri = URI.file(f).toString()
    const text = fs.readFileSync(f, "utf8")
    conn.sendNotification(DidOpenTextDocumentNotification.method, {
      textDocument: TextDocumentItem.create(uri, "python", 1, text),
    })
  }
}

export async function renameFile(
  conn: ReturnType<typeof createMessageConnection>,
  oldFile: string,
  newFile: string,
) {
  const oldUri = URI.file(oldFile).toString()
  const newUri = URI.file(newFile).toString()

  // 1) ask for the import-fix workspace edit
  let workspaceEdit = (await conn.sendRequest(WillRenameFilesRequest.method, {
    files: [{ oldUri: oldUri, newUri: newUri }],
  })) as WorkspaceEdit
  workspaceEdit = cleanupWorkspaceEdit(workspaceEdit)
  if (!workspaceEdit) {
    console.log(`× no edits returned for '${oldFile}'`)
    return
  }
  console.log("📋 workspaceEdit:", JSON.stringify(workspaceEdit, null, 2))

  applyWorkspaceEditLocally(workspaceEdit)

  fs.renameSync(oldFile, newFile)

  // didRenameFiles
  conn.sendNotification(DidRenameFilesNotification.method, {
    files: [{ oldUri: oldUri, newUri: newUri }],
  })

  // Even with didRenameFiles, the server may still think the old file is open.
  // So we close and reopen the file to ensure the server's view matches disk.
  conn.sendNotification(DidCloseTextDocumentNotification.method, {
    textDocument: { uri: oldUri },
  })

  const newText = fs.readFileSync(newFile, "utf8")
  conn.sendNotification(DidOpenTextDocumentNotification.method, {
    textDocument: TextDocumentItem.create(newUri, "python", 1, newText),
  })
}
