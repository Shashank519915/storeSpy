#!/bin/sh
# Minimal health server for scaffold images until service-specific entrypoints land.
exec python3 -c "
from http.server import BaseHTTPRequestHandler, HTTPServer

class Handler(BaseHTTPRequestHandler):
    def do_GET(self):
        if self.path == '/healthz':
            self.send_response(200)
            self.end_headers()
            self.wfile.write(b'ok')
        else:
            self.send_response(404)
            self.end_headers()

    def log_message(self, *_):
        pass

HTTPServer(('0.0.0.0', 8080), Handler).serve_forever()
"
