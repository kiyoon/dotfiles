"""Run with /usr/bin/python3 -m unittest discover -s tmux/tests -v."""

import base64
import hashlib
import importlib.util
import json
import os
from pathlib import Path
import shlex
import socket
import struct
import subprocess
import tempfile
import threading
import unittest
from unittest.mock import patch


SCRIPTS = Path(__file__).resolve().parents[1] / "scripts"
spec = importlib.util.spec_from_file_location("codex_sid", SCRIPTS / "codex-daemon-sid.py")
sid = importlib.util.module_from_spec(spec)
spec.loader.exec_module(sid)
FIRST = "019a0000-0000-7000-8000-000012345678"
SECOND = "019a0000-0000-7000-8000-000087654321"
CHILD = "019a0000-0000-7000-8000-0000aabbccdd"
PORT = 54726


def read_exact(stream, length):
    value = bytearray()
    while len(value) < length:
        chunk = stream.recv(length - len(value))
        if not chunk:
            raise EOFError
        value.extend(chunk)
    return bytes(value)


def read_frame(stream):
    first, second = read_exact(stream, 2)
    if not second & 128:
        raise AssertionError("Client frames must be masked")
    length = second & 127
    if length == 126:
        length = struct.unpack("!H", read_exact(stream, 2))[0]
    elif length == 127:
        length = struct.unpack("!Q", read_exact(stream, 8))[0]
    mask = read_exact(stream, 4)
    payload = read_exact(stream, length)
    return first & 15, bytes(value ^ mask[i % 4] for i, value in enumerate(payload))


def frame(payload, opcode=1, final=True):
    length = len(payload)
    header = bytes([(128 if final else 0) | opcode])
    if length < 126:
        header += bytes([length])
    elif length < 65536:
        header += b"\x7e" + struct.pack("!H", length)
    else:
        header += b"\x7f" + struct.pack("!Q", length)
    return header + payload


class FakeDaemon:
    """Independent Unix WebSocket peer; reject any non-metadata RPC."""

    def __init__(self, home, threads, pages=None, reject=False):
        self.path = home / sid.SOCKET_PATH
        self.path.parent.mkdir(parents=True)
        self.threads = threads
        self.pages = pages or [list(threads)]
        self.reject = reject
        self.calls = []
        self.errors = []
        self.listener = socket.socket(socket.AF_UNIX, socket.SOCK_STREAM)
        self.listener.bind(str(self.path))
        self.listener.listen(1)
        self.listener.settimeout(3)

    def __enter__(self):
        self.worker = threading.Thread(target=self.serve, daemon=True)
        self.worker.start()
        return self

    def __exit__(self, *_):
        self.worker.join(4)
        self.listener.close()
        if self.worker.is_alive():
            raise AssertionError("Discovery failed to close its connection")
        if self.errors:
            raise self.errors[0]

    def serve(self):
        try:
            stream, _ = self.listener.accept()
            with stream:
                stream.settimeout(3)
                headers = b""
                while not headers.endswith(b"\r\n\r\n"):
                    headers += read_exact(stream, 1)
                key = next(line.split(b": ", 1)[1] for line in headers.split(b"\r\n")
                           if line.startswith(b"Sec-WebSocket-Key:"))
                accept = base64.b64encode(hashlib.sha1(
                    key + b"258EAFA5-E914-47DA-95CA-C5AB0DC85B11"
                ).digest())
                stream.sendall(b"HTTP/1.1 101 Switching Protocols\r\nUpgrade: websocket\r\n"
                               b"Connection: Upgrade\r\nSec-WebSocket-Accept: " + accept + b"\r\n\r\n")
                while True:
                    opcode, payload = read_frame(stream)
                    if opcode == 10:
                        continue
                    request = json.loads(payload)
                    self.calls.append(request)
                    if request["method"] == "initialized":
                        continue
                    result = self.respond(request)
                    response = {"id": request["id"], "result": result}
                    if self.reject and request["method"] == "mcpServerStatus/list":
                        response = {"id": request["id"], "error": {"code": -32602}}
                    # Interleaved notifications, fragmented responses and pings
                    # must not corrupt the metadata exchange.
                    encoded = json.dumps(response).encode()
                    stream.sendall(frame(b'{"method":"status/changed"}')
                                   + frame(encoded[:10], final=False)
                                   + frame(b"ping", opcode=9)
                                   + frame(encoded[10:], opcode=0))
        except EOFError:
            pass
        except Exception as error:
            self.errors.append(error)

    def respond(self, request):
        method, params = request["method"], request.get("params", {})
        if method == "initialize":
            assert params["capabilities"]["experimentalApi"]
            return {}
        if method == "thread/loaded/list":
            page = int(params["cursor"] or 0)
            return {"data": self.pages[page],
                    "nextCursor": str(page + 1) if page + 1 < len(self.pages) else None}
        if method == "thread/read":
            assert params["includeTurns"] is False
            return {"thread": self.threads[params["threadId"]][0]}
        if method == "mcpServerStatus/list":
            assert params["serverName"] == "codex_tui"
            assert params["detail"] == "toolsAndAuthOnly"
            return {"data": self.threads[params["threadId"]][1]}
        raise AssertionError("Unexpected daemon request: " + method)


def thread(thread_id, port=PORT, **metadata):
    return ({"id": thread_id, "source": "cli", **metadata},
            [{"name": "codex_tui", "httpOrigin": f"http://127.0.0.1:{port}"}])


class DaemonDiscoveryTests(unittest.TestCase):
    def setUp(self):
        # Keep Unix socket paths below macOS's 104-byte limit.
        self.temp = tempfile.TemporaryDirectory(prefix="tmux-sid-", dir="/tmp")
        self.addCleanup(self.temp.cleanup)
        self.home = Path(self.temp.name)

    def lookup(self, threads, **options):
        with FakeDaemon(self.home, threads, **options) as daemon:
            rpc = sid.Rpc(self.home)
            try:
                result = sid.session_id(rpc, {PORT})
            finally:
                rpc.close()
        return result, daemon.calls

    def test_exact_listener_match_across_pages_excludes_subagents(self):
        threads = {
            FIRST: thread(FIRST, cwd="/same/project", description="x" * 66000),
            SECOND: thread(SECOND, port=PORT + 1, cwd="/same/project"),
            CHILD: thread(CHILD, source={"subagent": {"parent_thread_id": FIRST}}),
        }
        result, calls = self.lookup(threads, pages=[[CHILD, SECOND], [FIRST]])
        self.assertEqual(result, FIRST)
        self.assertFalse(any(call["method"] == "mcpServerStatus/list"
                             and call["params"]["threadId"] == CHILD for call in calls))

    def test_ambiguous_main_threads_return_nothing(self):
        self.assertIsNone(self.lookup({FIRST: thread(FIRST), SECOND: thread(SECOND)})[0])

    def test_unowned_port_returns_nothing(self):
        self.assertIsNone(self.lookup({FIRST: thread(FIRST, port=PORT + 1)})[0])

    def test_non_main_threads_are_excluded(self):
        threads = {
            FIRST: thread(FIRST, ephemeral=True),
            SECOND: thread(SECOND, parentThreadId=FIRST),
            CHILD: thread(CHILD, source="subagent"),
        }
        result, calls = self.lookup(threads)
        self.assertIsNone(result)
        self.assertFalse(any(call["method"] == "mcpServerStatus/list" for call in calls))

    def test_non_loopback_origins_and_other_servers_are_excluded(self):
        metadata, _ = thread(FIRST)
        servers = [{"name": "other", "httpOrigin": f"http://127.0.0.1:{PORT}"}]
        for origin in [f"http://evil:{PORT}", f"https://127.0.0.1:{PORT}",
                       f"http://127.0.0.1:{PORT}/path", None]:
            servers.append({"name": "codex_tui", "httpOrigin": origin})
        self.assertIsNone(self.lookup({FIRST: (metadata, servers)})[0])

    def test_older_daemon_rejection(self):
        with self.assertRaises(ValueError):
            self.lookup({FIRST: thread(FIRST)}, reject=True)

    def test_missing_daemon_does_not_start_one(self):
        with self.assertRaises(FileNotFoundError):
            sid.Rpc(self.home)

    def test_custom_home_from_open_sqlite_files(self):
        socket_path = self.home / sid.SOCKET_PATH
        socket_path.parent.mkdir()
        socket_path.touch()
        paths = [str(self.home / "logs_2.sqlite"), str(self.home / "logs_2.sqlite-shm")]
        self.assertEqual(sid.daemon_home(paths), self.home.resolve())
        with self.assertRaises(ValueError):
            sid.Rpc(self.home)  # A regular file cannot masquerade as a daemon.

    def test_linux_requires_owned_loopback_listening_socket(self):
        tcp = ("header\n"
               "0: 0100007F:D5C6 00000000:0000 0A 0:0 0:0 0 501 0 42\n"
               "1: 0100007F:D5C7 00000000:0000 01 0:0 0:0 0 501 0 42\n"
               "2: 0100007F:D5C8 00000000:0000 0A 0:0 0:0 0 501 0 99\n"
               "3: 00000000:D5C9 00000000:0000 0A 0:0 0:0 0 501 0 42\n")
        self.assertEqual(sid.linux_ports(tcp, {"42"}), {PORT})

    def test_mac_uses_pid_filtered_listeners(self):
        output = subprocess.CompletedProcess([], 0, "p999999999\nf38\nn127.0.0.1:54726\nn*:9999\n")
        with patch.object(sid.subprocess, "run", return_value=output) as run:
            self.assertEqual(sid.listener_ports(999999999), {PORT})
        self.assertEqual(run.call_args[0][0], [
            "lsof", "-n", "-P", "-a", "-p", "999999999", "-iTCP", "-sTCP:LISTEN", "-Fn",
        ])

    def shell_lookup(self, paths):
        fake_bin = self.home / "bin"
        fake_bin.mkdir()
        paths_file = self.home / "open-paths"
        paths_file.write_text("".join("n" + str(path) + "\n" for path in paths))
        commands = {
            "ps": "printf '%s\\n' '999999999 /bin/codex'",
            "lsof": ("case \" $* \" in *' -iTCP '*) printf '%s\\n' 'n127.0.0.1:54726';; "
                     "*) cat " + shlex.quote(str(paths_file)) + ";; esac"),
        }
        for name, command in commands.items():
            executable = fake_bin / name
            executable.write_text("#!/bin/sh\n" + command + "\n")
            executable.chmod(0o755)
        env = dict(os.environ, PATH=str(fake_bin) + os.pathsep + os.environ["PATH"],
                   XDG_CACHE_HOME=str(self.home / "cache"), CLAUDE_CONFIG_DIR=str(self.home / "claude"),
                   CODEX_HOME=str(self.home / "unused-codex-home"))
        return subprocess.run(["sh", str(SCRIPTS / "agent-sid.sh"), "%999", "/dev/fake"],
                              env=env, capture_output=True, text=True, check=True, timeout=5)

    def test_shell_displays_daemon_session_and_caches_result(self):
        with FakeDaemon(self.home, {FIRST: thread(FIRST)}):
            result = self.shell_lookup([self.home / "logs_2.sqlite"])
        self.assertEqual(result.stdout, " cx:12345678")
        self.assertEqual(result.stderr, "")
        cache = self.home / "cache/agent-sid/cx.999999999"
        self.assertEqual(cache.read_text().split()[1], "cx:12345678")

    def test_shell_keeps_no_daemon_rollout_lookup(self):
        rollout = self.home / f"rollout-2026-10-08T12-00-00-{FIRST}.jsonl"
        rollout.write_text(json.dumps({"type": "session_meta", "payload": {"id": FIRST}}) + "\n")
        result = self.shell_lookup([rollout])
        self.assertEqual(result.stdout, " cx:12345678")
        self.assertEqual(result.stderr, "")

    def test_shell_missing_daemon_is_silent(self):
        result = self.shell_lookup([])
        self.assertEqual(result.stdout, "")
        self.assertEqual(result.stderr, "")


if __name__ == "__main__":
    unittest.main()
