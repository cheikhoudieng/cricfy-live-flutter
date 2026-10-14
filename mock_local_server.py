import http.server
import socketserver
import json
import os

PORT = 8080

JSON_FILE = os.path.join(os.path.dirname(__file__), "real_live_events.json")
if os.path.exists(JSON_FILE):
    with open(JSON_FILE, "r", encoding="utf-8") as f:
        SAMPLE_EVENTS = json.load(f)
else:
    SAMPLE_EVENTS = []

class LocalCricfyHandler(http.server.SimpleHTTPRequestHandler):
    def do_GET(self):
        if self.path.startswith("/categories/live-events.txt"):
            self.send_response(200)
            self.send_header("Content-Type", "application/json; charset=utf-8")
            self.send_header("Access-Control-Allow-Origin", "*")
            self.end_headers()
            self.wfile.write(json.dumps(SAMPLE_EVENTS, ensure_ascii=False).encode("utf-8"))
        elif self.path.startswith("/channels/"):
            slug = self.path.split("/")[-1].replace(".txt", "")
            matched = None
            for ev in SAMPLE_EVENTS:
                if ev.get("slug") == slug:
                    matched = ev
                    break
            if not matched and SAMPLE_EVENTS:
                matched = SAMPLE_EVENTS[0]
            self.send_response(200)
            self.send_header("Content-Type", "application/json; charset=utf-8")
            self.send_header("Access-Control-Allow-Origin", "*")
            self.end_headers()
            self.wfile.write(json.dumps(matched if matched else {}, ensure_ascii=False).encode("utf-8"))
        else:
            super().do_GET()

if __name__ == "__main__":
    with socketserver.TCPServer(("0.0.0.0", PORT), LocalCricfyHandler) as httpd:
        print(f"[+] Serveur local Cricfy actif sur http://192.168.1.27:{PORT}")
        print(f"[+] {len(SAMPLE_EVENTS)} événements réels avec sources DASH/MPD prêts à être servis.")
        httpd.serve_forever()
