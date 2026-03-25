#!/usr/bin/env python3
import hashlib
import json
from pathlib import Path
import sys


def sha256_file(path: Path) -> str:
    h = hashlib.sha256()
    with path.open("rb") as f:
        for chunk in iter(lambda: f.read(1024 * 1024), b""):
            h.update(chunk)
    return h.hexdigest()


def main() -> int:
    root = Path(sys.argv[1]).resolve() if len(sys.argv) > 1 else Path(__file__).resolve().parents[1]
    config_path = root / "config" / "grammar_packs.json"
    base_dir = root / "dist"
    manifest = base_dir / "manifest.json"

    cfg = json.loads(config_path.read_text(encoding="utf-8"))
    version = cfg.get("version")
    if not version:
        raise SystemExit("Missing version in config")

    artifacts = []
    for path in sorted(base_dir.rglob("*")):
        if not path.is_file():
            continue
        if path.suffix not in {".so", ".dylib", ".dll", ".scm"}:
            continue
        artifacts.append(
            {
                "path": path.relative_to(base_dir).as_posix(),
                "sha256": sha256_file(path),
                "size": path.stat().st_size,
            }
        )

    manifest.write_text(json.dumps({"version": version, "artifacts": artifacts}, indent=2) + "\n", encoding="utf-8")
    print(f"Wrote {manifest}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
