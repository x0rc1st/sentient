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


def _get_desktop_session():
    """Find the real user and their DBUS/DISPLAY vars from /proc.

    The framework runs under sudo so we're root — but notify-send must
    run as the desktop user (DBUS rejects connections from other UIDs).
    """
    real_user = os.environ.get("SUDO_USER", "")
    target_uid = os.environ.get("SUDO_UID", "1000")
    display = ":0"
    dbus_addr = ""

    for pid_dir in glob.glob("/proc/[0-9]*"):
        try:
            if str(os.stat(pid_dir).st_uid) != target_uid:
                continue
            with open(f"{pid_dir}/environ", "rb") as f:
                proc_env = f.read()
            for entry in proc_env.split(b"\x00"):
                if entry.startswith(b"DBUS_SESSION_BUS_ADDRESS="):
                    dbus_addr = entry.split(b"=", 1)[1].decode()
                if entry.startswith(b"DISPLAY="):
                    display = entry.split(b"=", 1)[1].decode()
            if dbus_addr:
                break
        except (PermissionError, FileNotFoundError, ProcessLookupError):
            continue

    return real_user, display, dbus_addr


REAL_USER, DISPLAY, DBUS_ADDR = _get_desktop_session()


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

        # Run notify-send as the real desktop user so DBUS accepts the connection
        subprocess.Popen(
            [
                "runuser", "-u", REAL_USER, "--",
                "env",
                f"DISPLAY={DISPLAY}",
                f"DBUS_SESSION_BUS_ADDRESS={DBUS_ADDR}",
                "notify-send",
                "-u", NOTIFY_URGENCY,
                "-t", str(NOTIFY_TIMEOUT_MS),
                title,
                message,
            ],
            stdout=subprocess.DEVNULL,
            stderr=subprocess.DEVNULL,
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
