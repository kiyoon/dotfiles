// All lines/columns are 0-based, per LSP spec.
// NOTE: this script may modify same variable multiple times. However, it wouldn't matter even if it did.

import { spawn } from "node:child_process";
import * as fs from "node:fs";
import * as path from "node:path";
import {
	createMessageConnection,
	StreamMessageReader,
	StreamMessageWriter,
} from "vscode-jsonrpc/node";
import {
	ApplyWorkspaceEditRequest,
	InitializedNotification,
	InitializeRequest,
} from "vscode-languageserver-protocol";
import { URI } from "vscode-uri";
import {
	applyWorkspaceEditLocally,
	renameDirectory,
	renameFile,
} from "./lsp-utils.ts";

/*──────────────────────── main ───────────────────────────*/

async function main() {
	if (!process.argv[2] || !process.argv[3]) {
		console.error(
			"Usage: bun rename_modules.ts <path/to/file-or-dir> <new/path>",
		);
		process.exit(1);
	}

	const fileOrDirPath = path.resolve(process.argv[2]);
	const newPath = path.resolve(process.argv[3]);
	if (!fs.existsSync(fileOrDirPath)) {
		console.error("❌ Path does not exist:", fileOrDirPath);
		process.exit(1);
	}

	// build list of targets
	const st = fs.statSync(fileOrDirPath);

	/* 1 – spawn LS */
	const server = spawn("basedpyright-langserver", ["--stdio"]);
	const conn = createMessageConnection(
		new StreamMessageReader(server.stdout),
		new StreamMessageWriter(server.stdin),
	);
	conn.listen();

	// keep noise down; comment out to debug
	// conn.onNotification((m, p) => console.log("🔔", m, JSON.stringify(p)));
	// conn.onRequest((m, p) => console.log("➡ ", m, JSON.stringify(p)));
	// conn.onNotification("window/logMessage", params => {
	//   const level =
	//     params.type === 1
	//       ? "Error"
	//       : params.type === 2
	//         ? "Warning"
	//         : params.type === 3
	//           ? "Info"
	//           : params.type === 4
	//             ? "Trace"
	//             : String(params.type)
	//   console.log(`🐞[${level}]`, params.message)
	// })

	conn.onRequest(ApplyWorkspaceEditRequest.method, ({ edit }) => {
		try {
			applyWorkspaceEditLocally(edit);
			return { applied: true };
		} catch (e) {
			return { applied: false, failureReason: String(e) };
		}
	});

	/* 2 – init */
	let root = fileOrDirPath;
	// find pyproject.toml by walking up the directory tree
	while (root !== path.dirname(root)) {
		if (fs.existsSync(path.join(root, "pyproject.toml"))) {
			break;
		}
		root = path.dirname(root);
	}
	if (root === path.dirname(root)) {
		console.error(
			"❌ No pyproject.toml or setup.py found in parent directories",
		);
		process.exit(1);
	}
	console.log("Using root directory:", root);

	await conn.sendRequest(InitializeRequest.method, {
		processId: process.pid,
		rootUri: URI.file(root).toString(),
		// tell the server both which folders to index
		workspaceFolders: [
			{ uri: URI.file(root).toString(), name: path.basename(root) },
		],
		// and that we support cross-file workspace edits
		capabilities: {
			workspace: {
				workspaceEdit: {
					documentChanges: true,
					resourceOperations: ["rename"] /* for rename support across files */,
				},
				fileOperations: {
					willRename: true,
					didRename: true,
				},
			},
		},
	});
	conn.sendNotification(InitializedNotification.method);

	// const workspaceFiles: string[] = walkPythonFiles(root);
	// add tools and tests directories to the workspace
	// const toolsDir = path.join(root, "tools")
	// if (fs.existsSync(toolsDir)) {
	//   workspaceFiles.push(...walkPythonFiles(toolsDir))
	// }
	// const testsDir = path.join(root, "tests")
	// if (fs.existsSync(testsDir)) {
	//   workspaceFiles.push(...walkPythonFiles(testsDir))
	// }

	// open all files in the workspace
	// for (const filePath of workspaceFiles) {
	//   console.log(`🔄 Opening ${filePath} in basedpyright`)
	//   const fileUri = URI.file(filePath).toString()
	//   const text = fs.readFileSync(filePath, "utf8")
	//   conn.sendNotification(DidOpenTextDocumentNotification.method, {
	//     textDocument: TextDocumentItem.create(fileUri, "python", 1, text),
	//   })
	// }
	console.log(`\n🔄 Renaming ${fileOrDirPath} -> ${newPath}`);

	if (st.isDirectory()) {
		await renameDirectory(conn, fileOrDirPath, newPath);
	} else {
		await renameFile(conn, fileOrDirPath, newPath);
	}

	console.log("✅ Done with", fileOrDirPath);

	console.log("\n✅ finished");
	// console.log(renameMap)
	server.kill();
}

main().catch((e) => {
	console.error("❌", e);
	process.exit(1);
});
