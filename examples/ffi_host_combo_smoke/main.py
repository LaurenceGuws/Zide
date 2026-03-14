#!/usr/bin/env python3
import argparse
import ctypes
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
if str(ROOT) not in sys.path:
    sys.path.insert(0, str(ROOT))

from examples.common.ffi_host_boot import (  # noqa: E402
    STATUS_OK,
    consume_terminal_events_once,
    consume_terminal_metadata_once,
    consume_terminal_publication_once,
    poll_terminal_then_editor_once,
)
from examples.terminal_ffi_smoke.main import (
    CreateConfig,
    EVENT_TITLE_CHANGED,
    HandlePtr as TerminalHandlePtr,
    EventBuffer,
    Metadata,
    Snapshot,
    load_library as load_terminal_library,
    query_redraw_state,
)
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
        state: dict[str, object] = {}

        def terminal_step() -> None:
            if terminal_lib.zide_terminal_resize(terminal_handle, 32, 6, 8, 16) != STATUS_OK:
                raise RuntimeError("terminal resize failed")
            chunk = b"\x1b]0;combo-title\x07combo-line\r\n"
            chunk_buf = (ctypes.c_uint8 * len(chunk)).from_buffer_copy(chunk)
            if terminal_lib.zide_terminal_feed_output(terminal_handle, chunk_buf, len(chunk)) != STATUS_OK:
                raise RuntimeError("terminal feed_output failed")

            def consume_snapshot(snapshot: Snapshot) -> None:
                title = as_bytes(snapshot.title_ptr, snapshot.title_len).decode("utf-8", errors="replace")
                if title != "combo-title":
                    raise RuntimeError(f"unexpected combo terminal title: {title!r}")
                state["snapshot_title"] = title

            consume_terminal_publication_once(
                terminal_lib,
                terminal_handle,
                Snapshot,
                query_redraw_state,
                consume_snapshot,
            )

            def consume_metadata(metadata: Metadata) -> None:
                title = as_bytes(metadata.title_ptr, metadata.title_len).decode("utf-8", errors="replace")
                if title != "combo-title":
                    raise RuntimeError(f"unexpected combo metadata title: {title!r}")
                if metadata.alive != 1:
                    raise RuntimeError(f"unexpected combo metadata alive: {metadata.alive}")
                state["metadata_title"] = title
                state["metadata_alive"] = metadata.alive

            consume_terminal_metadata_once(
                terminal_lib,
                terminal_handle,
                Metadata,
                consume_metadata,
            )

            def consume_events(events: EventBuffer) -> None:
                seen_title_event = False
                for i in range(events.count):
                    event = events.events[i]
                    payload = as_bytes(event.data_ptr, event.data_len).decode("utf-8", errors="replace")
                    if event.kind == EVENT_TITLE_CHANGED and payload == "combo-title":
                        seen_title_event = True
                if not seen_title_event:
                    raise RuntimeError("missing combo terminal title_changed event")
                state["saw_title_event"] = True

            consume_terminal_events_once(
                terminal_lib,
                terminal_handle,
                EventBuffer,
                consume_events,
            )

        def editor_step() -> None:
            if editor_lib.zide_editor_create(ctypes.byref(editor_handle)) != STATUS_OK:
                raise RuntimeError("editor create failed")

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

            state["cursor"] = cursor.value
            state["text_value"] = text_value

        poll_terminal_then_editor_once(terminal_step, editor_step)

        print("ffi combo smoke ok")
        print(
            f"terminal_snapshot_title={state['snapshot_title']!r} "
            f"terminal_metadata_title={state['metadata_title']!r} "
            f"terminal_alive={state['metadata_alive']} "
            f"terminal_title_event={state['saw_title_event']} "
            f"editor_cursor={state['cursor']} "
            f"editor_text={state['text_value']!r}"
        )
        return 0
    finally:
        if editor_handle:
            editor_lib.zide_editor_destroy(editor_handle)
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
