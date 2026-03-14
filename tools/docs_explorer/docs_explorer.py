#!/usr/bin/env python3
from http.server import ThreadingHTTPServer, SimpleHTTPRequestHandler
from pathlib import Path
import os
import sys


def main() -> int:
    repo_root = Path(__file__).resolve().parent.parent.parent
    os.chdir(repo_root)

    built_entry = repo_root / "tools" / "docs_explorer" / "build" / "js" / "main.js"
    if not built_entry.exists():
        print("docs explorer build output is missing.")
        print("run:")
        print("  cd /home/home/personal/zide")
        print("  npm run build:docs-explorer")
        return 1

    host = "127.0.0.1"
    port = 8000
    config_name = None

    if len(sys.argv) > 1:
        port = int(sys.argv[1])
    if len(sys.argv) > 2:
        config_name = sys.argv[2]

    server = ThreadingHTTPServer((host, port), SimpleHTTPRequestHandler)
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
