#!/usr/bin/env python3
from http.server import ThreadingHTTPServer, SimpleHTTPRequestHandler
from pathlib import Path
import json
import mimetypes
import os
import subprocess
import sys
from urllib.parse import parse_qs, unquote, urlparse


class DocsExplorerHandler(SimpleHTTPRequestHandler):
    repo_root = Path.cwd()

    def do_POST(self) -> None:
        parsed = urlparse(self.path)
        if parsed.path != "/tools/docs_explorer/__search":
            self.send_error(404, "File not found")
            return
        self.handle_search()

    def do_GET(self) -> None:
        parsed = urlparse(self.path)
        if parsed.path == "/tools/docs_explorer/__repo":
            self.handle_repo_file(parsed)
            return
        super().do_GET()

    def handle_search(self) -> None:
        length = int(self.headers.get("Content-Length", "0"))
        if length <= 0:
            self.send_error(400, "Missing request body")
            return

        try:
            payload = json.loads(self.rfile.read(length).decode("utf-8"))
        except Exception:
            self.send_error(400, "Invalid JSON")
            return

        query = str(payload.get("query", "")).strip()
        docs = payload.get("docs", [])
        limit = int(payload.get("limit", 80))
        limit = max(1, min(limit, 200))

        self.send_response(200)
        self.send_header("Content-Type", "application/x-ndjson; charset=utf-8")
        self.send_header("Cache-Control", "no-store")
        self.end_headers()

        if not query or not isinstance(docs, list):
            return

        files: list[str] = []
        for rel_path in docs:
            if not isinstance(rel_path, str):
                continue
            candidate = (self.repo_root / rel_path).resolve()
            try:
                candidate.relative_to(self.repo_root)
            except ValueError:
                continue
            if candidate.is_file():
                files.append(str(candidate))

        if not files:
            return

        proc = subprocess.Popen(
            [
                "rg",
                "--json",
                "--smart-case",
                "--color",
                "never",
                "--max-columns",
                "300",
                "--",
                query,
                *files,
            ],
            cwd=self.repo_root,
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
            text=True,
        )

        hits = 0
        assert proc.stdout is not None
        assert proc.stderr is not None

        try:
            for raw in proc.stdout:
                event = json.loads(raw)
                if event.get("type") != "match":
                    continue
                data = event.get("data", {})
                path_data = data.get("path", {})
                path_text = path_data.get("text", "")
                try:
                    relative_path = str(Path(path_text).resolve().relative_to(self.repo_root))
                except Exception:
                    continue
                line_text = data.get("lines", {}).get("text", "").rstrip("\r\n")
                line_number = int(data.get("line_number", 1))

                for submatch in data.get("submatches", []):
                    match_text = submatch.get("match", {}).get("text", "")
                    result = {
                        "path": relative_path,
                        "line": line_number,
                        "column": int(submatch.get("start", 0)) + 1,
                        "preview": line_text,
                        "matchText": match_text,
                        "start": int(submatch.get("start", 0)),
                        "end": int(submatch.get("end", 0)),
                    }
                    self.wfile.write((json.dumps(result) + "\n").encode("utf-8"))
                    self.wfile.flush()
                    hits += 1
                    if hits >= limit:
                        proc.kill()
                        proc.wait()
                        return
        finally:
            if proc.poll() is None:
                proc.wait()

        stderr_text = proc.stderr.read().strip()
        if proc.returncode not in (0, 1) and stderr_text:
            error = {"error": stderr_text}
            self.wfile.write((json.dumps(error) + "\n").encode("utf-8"))
            self.wfile.flush()

    def handle_repo_file(self, parsed) -> None:
        query = parse_qs(parsed.query, keep_blank_values=False)
        root_raw = query.get("root", [None])[0]
        path_raw = query.get("path", [None])[0]
        if not root_raw or not path_raw:
            self.send_error(400, "Missing root or path")
            return

        try:
            repo_root = Path(unquote(root_raw)).resolve()
            candidate = (repo_root / unquote(path_raw)).resolve()
            candidate.relative_to(repo_root)
        except Exception:
            self.send_error(400, "Invalid path")
            return

        if not candidate.is_file():
            self.send_error(404, "File not found")
            return

        content_type = mimetypes.guess_type(str(candidate))[0] or "application/octet-stream"
        data = candidate.read_bytes()
        self.send_response(200)
        self.send_header("Content-Type", f"{content_type}; charset=utf-8" if content_type.startswith("text/") else content_type)
        self.send_header("Content-Length", str(len(data)))
        self.send_header("Cache-Control", "no-store")
        self.end_headers()
        self.wfile.write(data)


def main() -> int:
    repo_root = Path(__file__).resolve().parent.parent.parent
    os.chdir(repo_root)

    built_entry = repo_root / "tools" / "docs_explorer" / "build" / "js" / "main.js"
    if not built_entry.exists():
        print("docs explorer build output is missing.")
        print("run:")
        print('  cd "$(git rev-parse --show-toplevel)"')
        print("  npm run build:docs-explorer")
        return 1

    host = "127.0.0.1"
    port = 8000
    config_name = None

    if len(sys.argv) > 1:
        port = int(sys.argv[1])
    if len(sys.argv) > 2:
        config_name = sys.argv[2]

    DocsExplorerHandler.repo_root = repo_root
    server = ThreadingHTTPServer((host, port), DocsExplorerHandler)
    print(f"serving {repo_root}")
    url = f"http://{host}:{port}/tools/docs_explorer/"
    if config_name:
        url = f"{url}?config={config_name}"
    print(f"open {url}")
    try:
        server.serve_forever()
    except KeyboardInterrupt:
        pass
    finally:
        server.server_close()
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
