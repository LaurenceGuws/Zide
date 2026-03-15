#!/usr/bin/env python3
import argparse
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
if str(ROOT) not in sys.path:
    sys.path.insert(0, str(ROOT))

from examples.editor_ffi_smoke.main import load_library as load_editor_library  # noqa: E402
from examples.terminal_ffi_smoke.main import load_library as load_terminal_library  # noqa: E402


def run_inventory(terminal_lib_path: Path, editor_lib_path: Path) -> int:
    terminal_lib = load_terminal_library(terminal_lib_path)
    editor_lib = load_editor_library(editor_lib_path)

    print("ffi abi inventory ok")
    print(
        "terminal "
        f"snapshot={terminal_lib.zide_terminal_snapshot_abi_version()} "
        f"event={terminal_lib.zide_terminal_event_abi_version()} "
        f"scrollback={terminal_lib.zide_terminal_scrollback_abi_version()} "
        f"metadata={terminal_lib.zide_terminal_metadata_abi_version()} "
        f"redraw_state={terminal_lib.zide_terminal_redraw_state_abi_version()} "
        f"string={terminal_lib.zide_terminal_string_abi_version()} "
        f"close_confirm={terminal_lib.zide_terminal_close_confirm_abi_version()} "
        f"renderer_metadata={terminal_lib.zide_terminal_renderer_metadata_abi_version()}"
    )
    print(f"editor string={editor_lib.zide_editor_string_abi_version()}")
    return 0


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--terminal-lib", default="zig-out/lib/libzide-terminal-ffi.so")
    parser.add_argument("--editor-lib", default="zig-out/lib/libzide-editor-ffi.so")
    args = parser.parse_args()

    try:
        return run_inventory(Path(args.terminal_lib), Path(args.editor_lib))
    except Exception as exc:
        print(f"ffi abi inventory failed: {exc}", file=sys.stderr)
        return 1


if __name__ == "__main__":
    raise SystemExit(main())
