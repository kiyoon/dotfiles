// rename-debug.ts
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
  DidRenameFilesNotification,
  InitializeRequest,
  InitializedNotification,
  TextDocumentItem,
  WillRenameFilesRequest,
  WorkspaceEdit,
} from "vscode-languageserver-protocol"
import { URI } from "vscode-uri"

function uriToPath(uri: string) {
  return URI.parse(uri).fsPath
}

// Apply a WorkspaceEdit to the local file system & disk buffers.
// This is *very* small-scale – good enough for the RenameFile a Python
// LS usually returns.  Build something richer if you need full-blown
// text-edit support.
function applyWorkspaceEditLocally(edit: WorkspaceEdit) {
  if (edit.documentChanges) {
    for (const change of edit.documentChanges) {
      // a) file rename operations
      if ("kind" in change && change.kind === "rename") {
        const from = uriToPath(change.oldUri)
        const to = uriToPath(change.newUri)
        fs.mkdirSync(path.dirname(to), { recursive: true })
        fs.renameSync(from, to)
      }
      // b) plain text edits, etc. – left out for brevity
    }
  }
}

async function main() {
  // 1) Spawn the server
  console.log("⏳ Spawning basedpyright-langserver…")
  const server = spawn("basedpyright-langserver", ["--stdio"])

  // 2) Wrap stdio
  console.log("📡 Wrapping stdio in JSON-RPC")
  const connection = createMessageConnection(
    new StreamMessageReader(server.stdout),
    new StreamMessageWriter(server.stdin),
  )
  connection.listen()

  // 2.1) Debug-log everything the server sends us
  connection.onNotification((method, params) => {
    console.log(`🔔 Notification <${method}>`, JSON.stringify(params))
  })
  connection.onRequest((method, params) => {
    console.log(`➡  Incoming Request <${method}>`, JSON.stringify(params))
  })

  connection.onRequest(ApplyWorkspaceEditRequest.method, params => {
    // the *server* may still ask us to apply edits at any point
    try {
      applyWorkspaceEditLocally(params.edit)
      return { applied: true }
    } catch (e) {
      return { applied: false, failureReason: String(e) }
    }
  })

  // 3) Initialize
  console.log("🚀 Sending initialize request")
  const projectRoot = path.resolve(__dirname) // adjust to repo root
  console.log(`Project root: ${projectRoot}`)
  const initResult = await connection.sendRequest(InitializeRequest.method, {
    processId: process.pid,
    rootUri: URI.file(projectRoot).toString(),
    capabilities: {},
    workspaceFolders: [
      { uri: URI.file(projectRoot).toString(), name: "deardent-src" },
    ],
  })
  console.log("✅ Initialize response:", JSON.stringify(initResult))

  // 3.1) Send the required initialized notification
  console.log("📨 Sending initialized notification")
  connection.sendNotification(InitializedNotification.method, {})

  // Log verbose messages
  connection.sendNotification("workspace/didChangeConfiguration", {
    settings: {
      basedpyright: {
        analysis: { logLevel: "Trace" },
      },
    },
  })

  // 4) Open the document
  const oldPath = path.resolve("src/deardent/_version.py")
  const oldUri = URI.file(oldPath).toString()
  console.log(`📝 Opening document ${oldPath}`)
  const text = fs.readFileSync(oldPath, "utf8")
  connection.sendNotification(DidOpenTextDocumentNotification.method, {
    textDocument: TextDocumentItem.create(oldUri, "python", 1, text),
  })
  console.log("✅ didOpen sent")

  // 5) Request the rename
  const newPath = path.resolve("src/deardent/_version2.py")
  const newUri = URI.file(newPath).toString()
  console.log(`✏  Requesting rename:\n     ${oldUri}\n→    ${newUri}`)
  const workspaceEdit = await connection.sendRequest(
    WillRenameFilesRequest.method,
    { files: [{ oldUri, newUri }] },
  )
  console.log("✅ Received workspace edit:", JSON.stringify(workspaceEdit))

  // 6) Apply those edits ourselves
  applyWorkspaceEditLocally(workspaceEdit)

  // 7) Actually rename the file (if the WorkspaceEdit did not already)
  fs.renameSync(oldPath, newPath)

  // 6) Apply it
  // console.log("🛠 Applying workspace edit")
  // const applyResult = await connection.sendRequest(
  //   ApplyWorkspaceEditRequest.method,
  //   { edit: workspaceEdit },
  // )
  // console.log("✅ Apply edit result:", JSON.stringify(applyResult))

  connection.sendNotification(DidCloseTextDocumentNotification.method, {
    textDocument: { uri: oldUri },
  })
  connection.sendNotification(DidRenameFilesNotification.method, {
    files: [{ oldUri, newUri }],
  })
  const newText = fs.readFileSync(newPath, "utf8")
  connection.sendNotification(DidOpenTextDocumentNotification.method, {
    textDocument: TextDocumentItem.create(newUri, "python", 1, newText),
  })

  console.log("🎉 Rename applied and notifications sent")

  // 7) Done
  console.log("🎉 Done, shutting down")
  server.kill()
}

main().catch(err => {
  console.error("❌ ERROR in main():", err)
  process.exit(1)
})
