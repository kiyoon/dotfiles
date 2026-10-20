#!/usr/bin/env python3
"""Print cx:<last 8 session ID chars> for a daemon-backed Codex TUI PID.

Open paths from that PID arrive on stdin. Like godot-ghostty's
apps/cli/src/codex_discovery.rs, join the PID-owned loopback listener with
codex_tui's httpOrigin on loaded main threads. All daemon requests read metadata;
never start a daemon, resume a thread, invoke tools, or infer ownership from cwd.
Uses only the Python standard library, including for WebSocket over a Unix socket.
"""

import base64
import hashlib
import json
import os
from pathlib import Path
import re
import socket
import stat
import struct
import subprocess
import sys
import time
import uuid


SOCKET_PATH = "app-server-control/app-server-control.sock"
MAX_MESSAGE = 4 * 1024 * 1024


def listener_ports(pid):
    proc = Path("/proc") / str(pid)
    if (proc / "fd").is_dir():
        inodes = set()
        for fd in (proc / "fd").iterdir():
            try:
                match = re.fullmatch(r"socket:\[(\d+)\]", os.readlink(fd))
                if match:
                    inodes.add(match[1])
            except OSError:
                continue
        return linux_ports((proc / "net/tcp").read_text(), inodes)
    output = subprocess.run(
        ["lsof", "-n", "-P", "-a", "-p", str(pid), "-iTCP", "-sTCP:LISTEN", "-Fn"],
        capture_output=True, text=True, timeout=2,
    ).stdout
    return {int(port) for port in re.findall(r"^n127\.0\.0\.1:(\d+)$", output, re.M)}


def linux_ports(tcp, inodes):
    ports = set()
    for line in tcp.splitlines()[1:]:
        fields = line.split()
        if len(fields) >= 10 and fields[3] == "0A" and fields[9] in inodes:
            address, port = fields[1].split(":")
            if address == "0100007F":
                ports.add(int(port, 16))
    return ports


def daemon_home(paths):
    # Use the TUI's files, not the tmux server's potentially different account.
    homes = set()
    for path in map(Path, paths):
        if re.fullmatch(r"(?:logs|state)_\d+\.sqlite(?:-wal|-shm)?", path.name):
            if (path.parent / SOCKET_PATH).exists():
                homes.add(path.parent.resolve())
    if len(homes) > 1:
        raise ValueError("Ambiguous Codex home")
    if homes:
        return homes.pop()
    return Path(os.environ.get("CODEX_HOME") or Path.home() / ".codex")


class Rpc:
    """Small, bounded JSON WebSocket client for the existing local daemon."""

    def __init__(self, home):
        path = home / SOCKET_PATH
        metadata = path.stat()
        if not stat.S_ISSOCK(metadata.st_mode) or metadata.st_uid != os.geteuid():
            raise ValueError("Invalid Codex socket owner/type")
        self.deadline = time.monotonic() + 5
        self.request_id = 0
        self.socket = socket.socket(socket.AF_UNIX, socket.SOCK_STREAM)
        try:
            self.set_timeout()
            self.socket.connect(str(path))
            key = base64.b64encode(os.urandom(16)).decode()
            self.send_bytes((
                "GET / HTTP/1.1\r\nHost: localhost\r\nUpgrade: websocket\r\n"
                "Connection: Upgrade\r\nSec-WebSocket-Version: 13\r\n"
                f"Sec-WebSocket-Key: {key}\r\n\r\n"
            ).encode())
            header = bytearray()
            while not header.endswith(b"\r\n\r\n"):
                if len(header) >= 16384:
                    raise ValueError("WebSocket handshake too large")
                header.extend(self.read_exact(1))
            lines = header.decode("ascii").split("\r\n")
            headers = {name.lower(): value.strip() for name, value in (
                line.split(":", 1) for line in lines[1:] if ":" in line
            )}
            accept = base64.b64encode(hashlib.sha1(
                (key + "258EAFA5-E914-47DA-95CA-C5AB0DC85B11").encode()
            ).digest()).decode()
            if (lines[0].split()[1] != "101"
                    or headers.get("sec-websocket-accept") != accept
                    or headers.get("upgrade", "").lower() != "websocket"):
                raise ValueError("Invalid WebSocket handshake")
            self.call("initialize", {
                "clientInfo": {"name": "tmux_agent_sid", "version": "1.0"},
                "capabilities": {"experimentalApi": True},
            })
            self.send_json({"method": "initialized"})
        except Exception:
            self.close()
            raise

    def close(self):
        self.socket.close()

    def set_timeout(self):
        remaining = self.deadline - time.monotonic()
        if remaining <= 0:
            raise TimeoutError("Codex discovery timed out")
        self.socket.settimeout(min(2, remaining))

    def send_bytes(self, data):
        self.set_timeout()
        self.socket.sendall(data)

    def read_exact(self, length):
        data = bytearray()
        while len(data) < length:
            self.set_timeout()
            chunk = self.socket.recv(length - len(data))
            if not chunk:
                raise EOFError("Codex daemon closed the connection")
            data.extend(chunk)
        return bytes(data)

    def send_frame(self, payload, opcode=1):
        length = len(payload)
        header = bytes([0x80 | opcode])
        if length < 126:
            header += bytes([0x80 | length])
        elif length < 65536:
            header += b"\xfe" + struct.pack("!H", length)
        else:
            header += b"\xff" + struct.pack("!Q", length)
        mask = os.urandom(4)
        masked = bytes(value ^ mask[i % 4] for i, value in enumerate(payload))
        self.send_bytes(header + mask + masked)

    def send_json(self, value):
        self.send_frame(json.dumps(value, separators=(",", ":")).encode())

    def receive_json(self):
        message = bytearray()
        started = False
        while True:
            first, second = self.read_exact(2)
            opcode, length = first & 15, second & 127
            if first & 0x70 or second & 0x80:
                raise ValueError("Unsupported WebSocket frame")
            if length == 126:
                length = struct.unpack("!H", self.read_exact(2))[0]
            elif length == 127:
                length = struct.unpack("!Q", self.read_exact(8))[0]
            if length + len(message) > MAX_MESSAGE:
                raise ValueError("WebSocket message too large")
            payload = self.read_exact(length)
            if opcode == 8:
                raise EOFError("Codex daemon closed the connection")
            if opcode in (9, 10):
                if length > 125 or not first & 0x80:
                    raise ValueError("Invalid WebSocket control frame")
                if opcode == 9:
                    self.send_frame(payload, opcode=10)
                continue
            if opcode != (0 if started else 1):
                raise ValueError("Expected a WebSocket text message")
            started = True
            message.extend(payload)
            if first & 0x80:
                return json.loads(message)

    def call(self, method, params):
        self.request_id += 1
        self.send_json({"id": self.request_id, "method": method, "params": params})
        while True:
            response = self.receive_json()
            if response.get("id") == self.request_id:
                if "error" in response:
                    raise ValueError("Codex daemon rejected metadata request")
                return response["result"]


def session_id(rpc, ports):
    matches, cursors = set(), set()
    cursor = None
    for _ in range(10):
        page = rpc.call("thread/loaded/list", {"limit": 100, "cursor": cursor})
        for thread_id in page["data"]:
            uuid.UUID(thread_id)
            thread = rpc.call("thread/read", {
                "threadId": thread_id, "includeTurns": False,
            })["thread"]
            source = thread.get("source")
            if (thread.get("ephemeral") or thread.get("parentThreadId")
                    or source == "subagent"
                    or isinstance(source, dict) and "subagent" in source):
                continue
            servers = rpc.call("mcpServerStatus/list", {
                "threadId": thread_id, "serverName": "codex_tui", "detail": "toolsAndAuthOnly",
            })
            for server in servers["data"]:
                if server.get("name") != "codex_tui":
                    continue
                origin = server.get("httpOrigin") or ""
                match = re.fullmatch(r"http://127\.0\.0\.1:(\d+)", origin)
                if match and int(match[1]) in ports and thread.get("id") == thread_id:
                    matches.add(thread_id)
        cursor = page.get("nextCursor")
        if cursor is None:
            return next(iter(matches)) if len(matches) == 1 else None
        if cursor in cursors:
            break
        cursors.add(cursor)
    raise ValueError("Codex thread pagination did not finish")


def discover(pid, paths):
    ports = listener_ports(pid)
    if not ports:
        return None
    rpc = Rpc(daemon_home(paths))
    try:
        return session_id(rpc, ports)
    finally:
        rpc.close()


def main():
    try:
        pid = int(sys.argv[1])
        if pid <= 0:
            return
        sid = discover(pid, sys.stdin.read().splitlines())
        if sid:
            print("cx:" + sid[-8:], end="")
    except (OSError, ValueError, EOFError, KeyError, TypeError, IndexError, subprocess.SubprocessError):
        # Missing/old daemons, disabled task tools and ambiguous threads leave
        # the border blank. agent-sid.sh retries an empty result after five seconds.
        pass


if __name__ == "__main__":
    main()
