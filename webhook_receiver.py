#!/usr/bin/env python3
"""S3NS3 webhook receiver — listens for alerts and fires desktop notifications."""

import json
import subprocess
import sys
from http.server import HTTPServer, BaseHTTPRequestHandler

NOTIFY_TIMEOUT_MS = 20000
NOTIFY_URGENCY = "critical"
BIND_ADDR = "127.0.0.1"
PORT = 9000


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

        subprocess.Popen([
            "notify-send",
            "-u", NOTIFY_URGENCY,
            "-t", str(NOTIFY_TIMEOUT_MS),
            title,
            message,
        ])

        self.send_response(200)
        self.end_headers()

    # Silence per-request access logs
    def log_message(self, format, *args):
        pass


def main():
    port = int(sys.argv[1]) if len(sys.argv) > 1 else PORT
    server = HTTPServer((BIND_ADDR, port), WebhookHandler)
    server.serve_forever()


if __name__ == "__main__":
    main()
