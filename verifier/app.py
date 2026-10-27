#!/usr/bin/env python3
"""
SIXS flag verifier — tiny stdlib service.

Serves the flag console (same origin, so no CORS needed) and exposes a
yes/no verification oracle. It reads only SHA-256 digests of the current
run's flags from the shared /flaghashes volume (written by each lab's
entrypoint). It never stores or returns a flag value: it hashes what the
student submits and compares. A wrong id or a digest that is not present
yet simply returns {"ok": false}.
"""
import hashlib, hmac, json, os, re
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer

FLAG_DIR = os.environ.get("FLAG_DIR", "/flaghashes")
PANEL    = os.environ.get("PANEL", "/app/index.html")
PORT     = int(os.environ.get("PORT", "8099"))
ID_RE    = re.compile(r"^[a-z0-9-]{1,40}$")
FLAG_RE  = re.compile(r"^FLAG\{[^}\s][^}]*\}$")

def stored_hash(fid):
    if not fid or not ID_RE.match(fid):
        return None
    try:
        with open(os.path.join(FLAG_DIR, fid + ".sha256")) as f:
            return f.read().strip()
    except OSError:
        return None

class Handler(BaseHTTPRequestHandler):
    server_version = "sixs-verifier"

    def _send(self, code, body, ctype="application/json"):
        data = body if isinstance(body, (bytes, bytearray)) else body.encode()
        self.send_response(code)
        self.send_header("Content-Type", ctype)
        self.send_header("Content-Length", str(len(data)))
        self.send_header("Access-Control-Allow-Origin", "*")
        self.send_header("Access-Control-Allow-Headers", "Content-Type")
        self.send_header("Cache-Control", "no-store")
        self.end_headers()
        if self.command != "HEAD":
            self.wfile.write(data)

    def do_OPTIONS(self):
        self._send(204, b"")

    def do_GET(self):
        if self.path.split("?")[0] == "/health":
            try:
                n = len([x for x in os.listdir(FLAG_DIR) if x.endswith(".sha256")])
            except OSError:
                n = 0
            return self._send(200, json.dumps({"ok": True, "flags": n}))
        if self.path.split("?")[0] in ("/", "/index.html"):
            try:
                with open(PANEL, "rb") as f:
                    return self._send(200, f.read(), "text/html; charset=utf-8")
            except OSError:
                return self._send(500, json.dumps({"error": "panel not found"}))
        return self._send(404, json.dumps({"error": "not found"}))

    do_HEAD = do_GET

    def do_POST(self):
        if self.path.split("?")[0] != "/verify":
            return self._send(404, json.dumps({"error": "not found"}))
        try:
            n = int(self.headers.get("Content-Length", "0") or "0")
            payload = json.loads(self.rfile.read(n) or b"{}")
        except Exception:
            return self._send(400, json.dumps({"ok": False, "error": "bad request"}))
        fid  = str(payload.get("id", ""))
        flag = str(payload.get("flag", "")).strip()
        h = stored_hash(fid)
        if h is None:
            return self._send(200, json.dumps({"ok": False, "known": False}))
        if not FLAG_RE.match(flag):
            return self._send(200, json.dumps({"ok": False, "known": True}))
        calc = hashlib.sha256(flag.encode()).hexdigest()
        return self._send(200, json.dumps({"ok": hmac.compare_digest(calc, h), "known": True}))

    def log_message(self, *a):
        pass

if __name__ == "__main__":
    ThreadingHTTPServer(("0.0.0.0", PORT), Handler).serve_forever()
