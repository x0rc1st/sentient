#!/usr/bin/env python3
"""S3NS3 webhook receiver — listens for alerts and fires desktop notifications."""

import glob
import json
import os
import subprocess
import sys
from http.server import HTTPServer, BaseHTTPRequestHandler

NOTIFY_TIMEOUT_MS = 20000
NOTIFY_URGENCY = "critical"
BIND_ADDR = "127.0.0.1"
PORT = 9000


def _get_desktop_env():
    """Build env dict with DISPLAY and DBUS so notify-send works under sudo.

    Since the framework runs under sudo, the desktop session vars are gone.
    Recover them by reading /proc/<pid>/environ from a process owned by the
    real logged-in user (found via SUDO_UID or the first non-root UID).
    """
    env = os.environ.copy()
    env.setdefault("DISPLAY", ":0")

    if "DBUS_SESSION_BUS_ADDRESS" not in env:
        target_uid = os.environ.get("SUDO_UID", "1000")
        # Scan /proc for a process owned by the real user that has DBUS set
        for pid_dir in glob.glob("/proc/[0-9]*"):
            try:
                if str(os.stat(pid_dir).st_uid) != target_uid:
                    continue
                with open(f"{pid_dir}/environ", "rb") as f:
                    proc_env = f.read()
                for entry in proc_env.split(b"\x00"):
                    if entry.startswith(b"DBUS_SESSION_BUS_ADDRESS="):
                        env["DBUS_SESSION_BUS_ADDRESS"] = entry.split(b"=", 1)[1].decode()
                        return env
            except (PermissionError, FileNotFoundError, ProcessLookupError):
                continue

    return env


DESKTOP_ENV = _get_desktop_env()


class WebhookHandler(BaseHTTPRequestHandler):
    def do_POST(self):
        length = int(self.headers.get("Content-Length", 0))
        body = self.rfile.read(length) if length else b""
        try:
            data = json.loads(body) if body else {}
        except json.JSONDecodeError:
            data = {"raw": body.decode(errors="replace")}

        title = data.get("title", "S3NS3 Alert")
        message = data.get("message", json.dumps(data, indent=2))

        subprocess.Popen(
            [
                "notify-send",
                "-u", NOTIFY_URGENCY,
                "-t", str(NOTIFY_TIMEOUT_MS),
                title,
                message,
            ],
            env=DESKTOP_ENV,
        )

        self.send_response(200)
        self.end_headers()
        self.wfile.write(b'{"status":"ok"}\n')

    # Silence per-request access logs
    def log_message(self, format, *args):
        pass


def main():
    port = int(sys.argv[1]) if len(sys.argv) > 1 else PORT
    server = HTTPServer((BIND_ADDR, port), WebhookHandler)
    server.serve_forever()


if __name__ == "__main__":
    main()
