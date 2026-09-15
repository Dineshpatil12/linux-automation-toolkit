#!/usr/bin/env python3

from http.server import BaseHTTPRequestHandler, HTTPServer


HOST = "127.0.0.1"
PORT = 8080


class HealthHandler(BaseHTTPRequestHandler):

    def do_GET(self):
        if self.path == "/health":
            self.send_response(200)
            self.send_header("Content-Type", "text/plain")
            self.end_headers()
            self.wfile.write(b"OK\n")
        else:
            self.send_response(404)
            self.send_header("Content-Type", "text/plain")
            self.end_headers()
            self.wfile.write(b"Not Found\n")

    def log_message(self, format, *args):
        print("%s - %s" % (self.address_string(), format % args))


if __name__ == "__main__":
    server = HTTPServer((HOST, PORT), HealthHandler)

    print(f"Demo application listening on http://{HOST}:{PORT}")

    try:
        server.serve_forever()
    except KeyboardInterrupt:
        print("\nDemo application stopped")
    finally:
        server.server_close()
