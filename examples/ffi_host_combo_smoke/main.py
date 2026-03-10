#!/usr/bin/env python3
import argparse
import ctypes
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
if str(ROOT) not in sys.path:
    sys.path.insert(0, str(ROOT))

from examples.common.ffi_host_boot import STATUS_OK  # noqa: E402
from examples.terminal_ffi_smoke.main import CreateConfig, HandlePtr as TerminalHandlePtr, Snapshot, load_library as load_terminal_library
from examples.editor_ffi_smoke.main import HandlePtr as EditorHandlePtr, StringBuffer, load_library as load_editor_library, to_buf, as_bytes


def run_combo(terminal_lib_path: Path, editor_lib_path: Path) -> int:
    terminal_lib = load_terminal_library(terminal_lib_path)
    editor_lib = load_editor_library(editor_lib_path)

    terminal_handle = TerminalHandlePtr()
    editor_handle = EditorHandlePtr()

    cfg = CreateConfig(rows=6, cols=32, scrollback_rows=64, cursor_shape=0, cursor_blink=1)
    if terminal_lib.zide_terminal_create(ctypes.byref(cfg), ctypes.byref(terminal_handle)) != STATUS_OK:
        raise RuntimeError("terminal create failed")
    try:
        if terminal_lib.zide_terminal_resize(terminal_handle, 32, 6, 8, 16) != STATUS_OK:
            raise RuntimeError("terminal resize failed")
        chunk = b"\x1b]0;combo-title\x07combo-line\r\n"
        chunk_buf = (ctypes.c_uint8 * len(chunk)).from_buffer_copy(chunk)
        if terminal_lib.zide_terminal_feed_output(terminal_handle, chunk_buf, len(chunk)) != STATUS_OK:
            raise RuntimeError("terminal feed_output failed")

        snapshot = Snapshot()
        if terminal_lib.zide_terminal_snapshot_acquire(terminal_handle, ctypes.byref(snapshot)) != STATUS_OK:
            raise RuntimeError("terminal snapshot failed")
        try:
            title = as_bytes(snapshot.title_ptr, snapshot.title_len).decode("utf-8", errors="replace")
            if title != "combo-title":
                raise RuntimeError(f"unexpected combo terminal title: {title!r}")
        finally:
            terminal_lib.zide_terminal_snapshot_release(ctypes.byref(snapshot))

        if editor_lib.zide_editor_create(ctypes.byref(editor_handle)) != STATUS_OK:
            raise RuntimeError("editor create failed")
        try:
            editor_text = b"combo editor text\n"
            if editor_lib.zide_editor_set_text(editor_handle, *to_buf(editor_text)) != STATUS_OK:
                raise RuntimeError("editor set_text failed")

            cursor = ctypes.c_size_t(0)
            if editor_lib.zide_editor_primary_caret_offset(editor_handle, ctypes.byref(cursor)) != STATUS_OK:
                raise RuntimeError("editor primary_caret_offset failed")

            text = StringBuffer()
            if editor_lib.zide_editor_text_alloc(editor_handle, ctypes.byref(text)) != STATUS_OK:
                raise RuntimeError("editor text_alloc failed")
            try:
                text_value = as_bytes(text.ptr, text.len).decode("utf-8", errors="replace")
            finally:
                editor_lib.zide_editor_string_free(ctypes.byref(text))

            if text_value != "combo editor text\n":
                raise RuntimeError(f"unexpected combo editor text: {text_value!r}")

            print("ffi combo smoke ok")
            print(f"terminal_title={title!r} editor_cursor={cursor.value} editor_text={text_value!r}")
            return 0
        finally:
            editor_lib.zide_editor_destroy(editor_handle)
    finally:
        terminal_lib.zide_terminal_destroy(terminal_handle)


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--terminal-lib", default="zig-out/lib/libzide-terminal-ffi.so")
    parser.add_argument("--editor-lib", default="zig-out/lib/libzide-editor-ffi.so")
    args = parser.parse_args()

    try:
        return run_combo(Path(args.terminal_lib), Path(args.editor_lib))
    except Exception as exc:
        print(f"ffi combo smoke failed: {exc}", file=sys.stderr)
        return 1


if __name__ == "__main__":
    raise SystemExit(main())
