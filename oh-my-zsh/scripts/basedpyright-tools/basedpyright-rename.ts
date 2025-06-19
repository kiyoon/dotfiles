import { spawn } from "child_process"
import * as fs from "fs"
import * as path from "path"
import {
  StreamMessageReader,
  StreamMessageWriter,
  createMessageConnection,
} from "vscode-jsonrpc/node"
import {
  ApplyWorkspaceEditRequest,
  DidCloseTextDocumentNotification,
  DidOpenTextDocumentNotification,
  InitializeRequest,
  InitializedNotification,
  Position,
  TextDocumentEdit,
  TextDocumentItem,
  TextEdit,
  WorkspaceEdit,
} from "vscode-languageserver-protocol"
import { URI } from "vscode-uri"

/*───────────────────────────────────────────────────────────────────────────*/
/* helpers                                                                  */

function uriToPath(uri: string) {
  return URI.parse(uri).fsPath
}

function applyWorkspaceEditLocally(edit: WorkspaceEdit) {
  if (!edit.documentChanges) return

  for (const dc of edit.documentChanges) {
    // only the “text edit” branch matters for a variable rename
    if ("edits" in dc) {
      const tde = dc as TextDocumentEdit
      const file = uriToPath(tde.textDocument.uri)

      let text = fs.readFileSync(file, "utf8")
      // edits are sorted, but apply **last → first** so offsets stay valid
      ;[...tde.edits].reverse().forEach((e: TextEdit) => {
        const { start, end } = e.range
        const toOffset = (pos: Position) =>
          text
            .split(/\r?\n/)
            .slice(0, pos.line)
            .reduce((n, ln) => n + ln.length + 1, 0) + pos.character

        const s = toOffset(start)
        const e_ = toOffset(end)
        text = text.slice(0, s) + e.newText + text.slice(e_)
      })

      fs.writeFileSync(file, text)
    }
  }
}

/*───────────────────────────────────────────────────────────────────────────*/
/* main                                                                     */

async function main() {
  /* 1 – spawn LS */
  const server = spawn("basedpyright-langserver", ["--stdio"])
  const conn = createMessageConnection(
    new StreamMessageReader(server.stdout),
    new StreamMessageWriter(server.stdin),
  )
  conn.listen()

  /* pretty-print every server → client message for debugging */
  conn.onNotification((m, p) =>
    console.log(`🔔 ${m}`, JSON.stringify(p, null, 2)),
  )
  conn.onRequest((m, p) => console.log(`➡  ${m}`, JSON.stringify(p, null, 2)))

  /* let the server push edits *to* us if it wants */
  conn.onRequest(ApplyWorkspaceEditRequest.method, ({ edit }) => {
    try {
      applyWorkspaceEditLocally(edit)
      return { applied: true }
    } catch (err) {
      return { applied: false, failureReason: String(err) }
    }
  })

  /* 2 – initialise */
  const projectRoot = path.resolve(__dirname) // adjust if needed
  await conn.sendRequest(InitializeRequest.method, {
    processId: process.pid,
    rootUri: URI.file(projectRoot).toString(),
    capabilities: {},
    workspaceFolders: [
      { uri: URI.file(projectRoot).toString(), name: "deardent-src" },
    ],
  })
  conn.sendNotification(InitializedNotification.method)
  conn.sendNotification("workspace/didChangeConfiguration", {
    settings: {
      basedpyright: {
        analysis: { logLevel: "Trace" },
      },
    },
  })

  /* 3 – open the file that contains the symbol */
  const filePath = path.resolve("src/deardent/_version.py")
  const fileUri = URI.file(filePath).toString()
  const text = fs.readFileSync(filePath, "utf8")
  conn.sendNotification(DidOpenTextDocumentNotification.method, {
    textDocument: TextDocumentItem.create(fileUri, "python", 1, text),
  })

  /* 4 – compute the position of the identifier to rename */
  const oldName = "get_version_dict"
  const newName = "vdict"

  const symbols = await conn.sendRequest("workspace/symbol", { query: oldName })
  const def = symbols.find(
    (s: any) => s.name === oldName && s.location.uri.endsWith("_version.py"),
  )
  if (!def) throw new Error("symbol not found")
  const pos = def.location.range.start

  console.log(
    `🔍 found symbol ${oldName} at line ${pos.line + 1}, char ${pos.character + 1}`,
  )

  // // --- double-check it's renamable ------------------------------------
  // const can = await conn.sendRequest("textDocument/prepareRename", {
  //   textDocument: { uri: fileUri },
  //   position: pos,
  // })
  // if (can == null) throw new Error("LS says this symbol can’t be renamed")

  /* 5 – ask the LS to build the edit */
  const wsEdit: WorkspaceEdit = await conn.sendRequest("textDocument/rename", {
    textDocument: { uri: fileUri },
    position: pos,
    newName,
  })
  console.log("✅ got WorkspaceEdit", JSON.stringify(wsEdit, null, 2))

  if (!wsEdit) {
    console.error("❌ rename rejected (null WorkspaceEdit)")
    server.kill()
    return
  }
  /* 6 – apply edits locally */
  applyWorkspaceEditLocally(wsEdit)

  /* 7 – notify the LS of our change (one big “didClose/didOpen” is fine) */
  conn.sendNotification(DidCloseTextDocumentNotification.method, {
    textDocument: { uri: fileUri },
  })
  const newText = fs.readFileSync(filePath, "utf8")
  conn.sendNotification(DidOpenTextDocumentNotification.method, {
    textDocument: TextDocumentItem.create(fileUri, "python", 2, newText),
  })

  console.log("🎉 variable renamed, edits applied")
  server.kill()
}

main().catch(e => {
  console.error("❌", e)
  process.exit(1)
})
