#!/usr/bin/env python3
from http.server import ThreadingHTTPServer, SimpleHTTPRequestHandler
from pathlib import Path
import os
import sys


def main() -> int:
    repo_root = Path(__file__).resolve().parent.parent
    os.chdir(repo_root)

    host = "127.0.0.1"
    port = 8000

    if len(sys.argv) > 1:
        port = int(sys.argv[1])

    server = ThreadingHTTPServer((host, port), SimpleHTTPRequestHandler)
    print(f"serving {repo_root}")
    print(f"open http://{host}:{port}/tools/docs_explorer/")
    try:
        server.serve_forever()
    except KeyboardInterrupt:
        pass
    finally:
        server.server_close()
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
