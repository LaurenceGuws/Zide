#!/usr/bin/env python3
import argparse
import base64
import pathlib
import sys
import textwrap

def emit_image(path: pathlib.Path, chunk: int, image_id: int, cols: int, rows: int, place_only: bool) -> None:
    data = path.read_bytes()
    b64 = base64.b64encode(data).decode()
    size = ""
    if cols > 0:
        size += f",c={cols}"
    if rows > 0:
        size += f",r={rows}"
    if chunk <= 0:
        if place_only:
            sys.stdout.write(f"\033_Ga=p,i={image_id}{size}\033\\")
        else:
            sys.stdout.write(f"\033_Ga=T,f=100,i={image_id}{size};" + b64 + "\033\\")
        return
    chunks = textwrap.wrap(b64, chunk)
    for i, chunk_data in enumerate(chunks):
        m = 1 if i < len(chunks) - 1 else 0
        sys.stdout.write(f"\033_Ga=T,f=100,i={image_id},m={m}{size};{chunk_data}\033\\")
    if place_only:
        sys.stdout.write(f"\033_Ga=p,i={image_id}{size}\033\\")


def main() -> int:
    parser = argparse.ArgumentParser(description="Send a PNG using kitty graphics protocol.")
    parser.add_argument("path", help="Path to PNG file")
    parser.add_argument("--chunk", type=int, default=4096, help="Base64 chunk size (0 = no chunking)")
    parser.add_argument("--id", type=int, default=1, help="Kitty image id to use")
    parser.add_argument("--cols", type=int, default=0, help="Place image across this many columns")
    parser.add_argument("--rows", type=int, default=0, help="Place image across this many rows")
    parser.add_argument("--place-only", action="store_true", help="Send a separate placement after transmit")
    args = parser.parse_args()

    path = pathlib.Path(args.path)
    if not path.exists():
        print(f"error: file not found: {path}", file=sys.stderr)
        return 2
    emit_image(path, args.chunk, args.id, args.cols, args.rows, args.place_only)
    return 0

if __name__ == "__main__":
    raise SystemExit(main())
