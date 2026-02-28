#!/usr/bin/env python3
import argparse
import ctypes
import os
import sys
from pathlib import Path

STATUS_OK = 0
EVENT_TITLE_CHANGED = 1
EVENT_CLIPBOARD_WRITE = 3


class ZideTerminalHandle(ctypes.Structure):
    pass


class CreateConfig(ctypes.Structure):
    _fields_ = [
        ("rows", ctypes.c_uint16),
        ("cols", ctypes.c_uint16),
        ("scrollback_rows", ctypes.c_uint32),
        ("cursor_shape", ctypes.c_uint8),
        ("cursor_blink", ctypes.c_uint8),
    ]


class Color(ctypes.Structure):
    _fields_ = [("r", ctypes.c_uint8), ("g", ctypes.c_uint8), ("b", ctypes.c_uint8), ("a", ctypes.c_uint8)]


class Cell(ctypes.Structure):
    _fields_ = [
        ("codepoint", ctypes.c_uint32),
        ("combining_len", ctypes.c_uint8),
        ("width", ctypes.c_uint8),
        ("height", ctypes.c_uint8),
        ("x", ctypes.c_uint8),
        ("y", ctypes.c_uint8),
        ("combining_0", ctypes.c_uint32),
        ("combining_1", ctypes.c_uint32),
        ("fg", Color),
        ("bg", Color),
        ("underline_color", Color),
        ("bold", ctypes.c_uint8),
        ("blink", ctypes.c_uint8),
        ("blink_fast", ctypes.c_uint8),
        ("reverse", ctypes.c_uint8),
        ("underline", ctypes.c_uint8),
        ("_padding0", ctypes.c_uint8 * 3),
        ("link_id", ctypes.c_uint32),
    ]


class Snapshot(ctypes.Structure):
    _fields_ = [
        ("abi_version", ctypes.c_uint32),
        ("struct_size", ctypes.c_uint32),
        ("rows", ctypes.c_uint32),
        ("cols", ctypes.c_uint32),
        ("generation", ctypes.c_uint64),
        ("cell_count", ctypes.c_size_t),
        ("cells", ctypes.POINTER(Cell)),
        ("cursor_row", ctypes.c_uint32),
        ("cursor_col", ctypes.c_uint32),
        ("cursor_visible", ctypes.c_uint8),
        ("cursor_shape", ctypes.c_uint8),
        ("cursor_blink", ctypes.c_uint8),
        ("alt_active", ctypes.c_uint8),
        ("screen_reverse", ctypes.c_uint8),
        ("has_damage", ctypes.c_uint8),
        ("damage_start_row", ctypes.c_uint32),
        ("damage_end_row", ctypes.c_uint32),
        ("damage_start_col", ctypes.c_uint32),
        ("damage_end_col", ctypes.c_uint32),
        ("title_ptr", ctypes.POINTER(ctypes.c_uint8)),
        ("title_len", ctypes.c_size_t),
        ("cwd_ptr", ctypes.POINTER(ctypes.c_uint8)),
        ("cwd_len", ctypes.c_size_t),
        ("_ctx", ctypes.c_void_p),
    ]


class Event(ctypes.Structure):
    _fields_ = [
        ("kind", ctypes.c_int),
        ("data_ptr", ctypes.POINTER(ctypes.c_uint8)),
        ("data_len", ctypes.c_size_t),
        ("int0", ctypes.c_int32),
        ("int1", ctypes.c_int32),
    ]


class EventBuffer(ctypes.Structure):
    _fields_ = [
        ("events", ctypes.POINTER(Event)),
        ("count", ctypes.c_size_t),
        ("_ctx", ctypes.c_void_p),
    ]


class StringBuffer(ctypes.Structure):
    _fields_ = [
        ("ptr", ctypes.POINTER(ctypes.c_uint8)),
        ("len", ctypes.c_size_t),
        ("_ctx", ctypes.c_void_p),
    ]


HandlePtr = ctypes.POINTER(ZideTerminalHandle)


def load_library(path: Path):
    os.environ.setdefault("ZIDE_LOG", "none")
    lib = ctypes.CDLL(str(path))
    lib.zide_terminal_create.argtypes = [ctypes.POINTER(CreateConfig), ctypes.POINTER(HandlePtr)]
    lib.zide_terminal_create.restype = ctypes.c_int
    lib.zide_terminal_destroy.argtypes = [HandlePtr]
    lib.zide_terminal_destroy.restype = None
    lib.zide_terminal_resize.argtypes = [HandlePtr, ctypes.c_uint16, ctypes.c_uint16, ctypes.c_uint16, ctypes.c_uint16]
    lib.zide_terminal_resize.restype = ctypes.c_int
    lib.zide_terminal_feed_output.argtypes = [HandlePtr, ctypes.POINTER(ctypes.c_uint8), ctypes.c_size_t]
    lib.zide_terminal_feed_output.restype = ctypes.c_int
    lib.zide_terminal_snapshot_acquire.argtypes = [HandlePtr, ctypes.POINTER(Snapshot)]
    lib.zide_terminal_snapshot_acquire.restype = ctypes.c_int
    lib.zide_terminal_snapshot_release.argtypes = [ctypes.POINTER(Snapshot)]
    lib.zide_terminal_snapshot_release.restype = None
    lib.zide_terminal_event_drain.argtypes = [HandlePtr, ctypes.POINTER(EventBuffer)]
    lib.zide_terminal_event_drain.restype = ctypes.c_int
    lib.zide_terminal_events_free.argtypes = [ctypes.POINTER(EventBuffer)]
    lib.zide_terminal_events_free.restype = None
    lib.zide_terminal_is_alive.argtypes = [HandlePtr]
    lib.zide_terminal_is_alive.restype = ctypes.c_uint8
    lib.zide_terminal_current_title.argtypes = [HandlePtr, ctypes.POINTER(StringBuffer)]
    lib.zide_terminal_current_title.restype = ctypes.c_int
    lib.zide_terminal_current_cwd.argtypes = [HandlePtr, ctypes.POINTER(StringBuffer)]
    lib.zide_terminal_current_cwd.restype = ctypes.c_int
    lib.zide_terminal_string_free.argtypes = [ctypes.POINTER(StringBuffer)]
    lib.zide_terminal_string_free.restype = None
    lib.zide_terminal_child_exit_status.argtypes = [HandlePtr, ctypes.POINTER(ctypes.c_int32), ctypes.POINTER(ctypes.c_uint8)]
    lib.zide_terminal_child_exit_status.restype = ctypes.c_int
    lib.zide_terminal_snapshot_abi_version.argtypes = []
    lib.zide_terminal_snapshot_abi_version.restype = ctypes.c_uint32
    lib.zide_terminal_event_abi_version.argtypes = []
    lib.zide_terminal_event_abi_version.restype = ctypes.c_uint32
    lib.zide_terminal_status_string.argtypes = [ctypes.c_int]
    lib.zide_terminal_status_string.restype = ctypes.c_char_p
    return lib


def as_bytes(ptr, length: int) -> bytes:
    if not ptr or length == 0:
        return b""
    return ctypes.string_at(ptr, length)


def render_first_row(snapshot: Snapshot) -> str:
    if not snapshot.cells:
        return ""
    cols = int(snapshot.cols)
    chars: list[str] = []
    for col in range(cols):
        cell = snapshot.cells[col]
        if cell.width == 0:
            continue
        cp = int(cell.codepoint)
        chars.append(" " if cp == 0 else chr(cp))
    return "".join(chars).rstrip()


def run_smoke(lib_path: Path) -> int:
    lib = load_library(lib_path)
    handle = HandlePtr()
    cfg = CreateConfig(rows=12, cols=60, scrollback_rows=256, cursor_shape=0, cursor_blink=1)

    status = lib.zide_terminal_create(ctypes.byref(cfg), ctypes.byref(handle))
    if status != STATUS_OK:
        raise RuntimeError(f"create failed: {status}")
    try:
        status = lib.zide_terminal_resize(handle, 60, 12, 8, 16)
        if status != STATUS_OK:
            raise RuntimeError(f"resize failed: {status}")

        vt = b"\x1b]0;ffi-title\x07\x1b]52;c;ZmZpLWNsaXA=\x07"
        vt_buf = (ctypes.c_uint8 * len(vt)).from_buffer_copy(vt)
        status = lib.zide_terminal_feed_output(handle, vt_buf, len(vt))
        if status != STATUS_OK:
            raise RuntimeError(f"feed_output failed: {status}")

        snapshot = Snapshot()
        status = lib.zide_terminal_snapshot_acquire(handle, ctypes.byref(snapshot))
        if status != STATUS_OK:
            raise RuntimeError(f"snapshot_acquire failed: {status}")
        try:
            title = as_bytes(snapshot.title_ptr, snapshot.title_len).decode("utf-8", errors="replace")
            cwd = as_bytes(snapshot.cwd_ptr, snapshot.cwd_len).decode("utf-8", errors="replace")
            row0 = render_first_row(snapshot)
            title_buf = StringBuffer()
            cwd_buf = StringBuffer()
            if lib.zide_terminal_current_title(handle, ctypes.byref(title_buf)) != STATUS_OK:
                raise RuntimeError("current_title failed")
            if lib.zide_terminal_current_cwd(handle, ctypes.byref(cwd_buf)) != STATUS_OK:
                raise RuntimeError("current_cwd failed")
            try:
                title_getter = as_bytes(title_buf.ptr, title_buf.len).decode("utf-8", errors="replace")
                cwd_getter = as_bytes(cwd_buf.ptr, cwd_buf.len).decode("utf-8", errors="replace")
            finally:
                lib.zide_terminal_string_free(ctypes.byref(title_buf))
                lib.zide_terminal_string_free(ctypes.byref(cwd_buf))

            exit_code = ctypes.c_int32(-1)
            has_exit = ctypes.c_uint8(0)
            if lib.zide_terminal_child_exit_status(handle, ctypes.byref(exit_code), ctypes.byref(has_exit)) != STATUS_OK:
                raise RuntimeError("child_exit_status failed")

            print("ffi smoke ok")
            print(
                f"snapshot_abi={lib.zide_terminal_snapshot_abi_version()} event_abi={lib.zide_terminal_event_abi_version()}"
            )
            print(f"status_ok={lib.zide_terminal_status_string(STATUS_OK).decode()} status_unknown={lib.zide_terminal_status_string(99).decode()}")
            print(f"size={snapshot.rows}x{snapshot.cols} cells={snapshot.cell_count}")
            print(f"title={title!r} cwd={cwd!r} alive={lib.zide_terminal_is_alive(handle)}")
            print(f"title_getter={title_getter!r} cwd_getter={cwd_getter!r} exit_status=({has_exit.value},{exit_code.value})")
            print(f"row0={row0!r}")
            if snapshot.rows != 12 or snapshot.cols != 60:
                raise RuntimeError("unexpected snapshot dimensions")
            if snapshot.cell_count != 12 * 60:
                raise RuntimeError("unexpected cell count")
            if title != "ffi-title":
                raise RuntimeError(f"unexpected title: {title!r}")
            if title_getter != title or cwd_getter != cwd:
                raise RuntimeError("getter mismatch")
        finally:
            lib.zide_terminal_snapshot_release(ctypes.byref(snapshot))

        events = EventBuffer()
        status = lib.zide_terminal_event_drain(handle, ctypes.byref(events))
        if status != STATUS_OK:
            raise RuntimeError(f"event_drain failed: {status}")
        try:
            seen_title = False
            seen_clip = False
            for i in range(events.count):
                event = events.events[i]
                payload = as_bytes(event.data_ptr, event.data_len)
                if event.kind == EVENT_TITLE_CHANGED and payload == b"ffi-title":
                    seen_title = True
                if event.kind == EVENT_CLIPBOARD_WRITE and payload == b"ffi-clip":
                    seen_clip = True
            if not seen_title:
                raise RuntimeError("missing title_changed event")
            if not seen_clip:
                raise RuntimeError("missing clipboard_write event")
        finally:
            lib.zide_terminal_events_free(ctypes.byref(events))
        return 0
    finally:
        lib.zide_terminal_destroy(handle)


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--lib", default="zig-out/lib/libzide-terminal-ffi.so")
    args = parser.parse_args()

    lib_path = Path(args.lib)
    if not lib_path.exists():
        print(f"missing library: {lib_path}", file=sys.stderr)
        return 2

    try:
        return run_smoke(lib_path)
    except Exception as exc:
        print(f"ffi smoke failed: {exc}", file=sys.stderr)
        return 1


if __name__ == "__main__":
    raise SystemExit(main())
