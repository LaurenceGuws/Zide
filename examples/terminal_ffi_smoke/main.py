#!/usr/bin/env python3
import argparse
import ctypes
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
if str(ROOT) not in sys.path:
    sys.path.insert(0, str(ROOT))

from examples.common.ffi_host_boot import as_bytes, load_cdll, STATUS_OK  # noqa: E402

STATUS_OK = 0
EVENT_TITLE_CHANGED = 1
EVENT_ALIVE_CHANGED = 5
EVENT_REDRAW_READY = 6
EVENT_CLIPBOARD_WRITE = 3
GLYPH_CLASS_BOX = 1 << 0
GLYPH_CLASS_BOX_ROUNDED = 1 << 1
GLYPH_CLASS_GRAPH = 1 << 2
GLYPH_CLASS_BRAILLE = 1 << 3
GLYPH_CLASS_POWERLINE = 1 << 4
GLYPH_CLASS_POWERLINE_ROUNDED = 1 << 5
DAMAGE_POLICY_ADVISORY_BOUNDS = 1 << 0
DAMAGE_POLICY_FULL_REDRAW_SAFE_DEFAULT = 1 << 1


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


class ScrollbackBuffer(ctypes.Structure):
    _fields_ = [
        ("abi_version", ctypes.c_uint32),
        ("struct_size", ctypes.c_uint32),
        ("total_rows", ctypes.c_uint32),
        ("start_row", ctypes.c_uint32),
        ("row_count", ctypes.c_uint32),
        ("cols", ctypes.c_uint32),
        ("cell_count", ctypes.c_size_t),
        ("cells", ctypes.POINTER(Cell)),
        ("_ctx", ctypes.c_void_p),
    ]


class Metadata(ctypes.Structure):
    _fields_ = [
        ("abi_version", ctypes.c_uint32),
        ("struct_size", ctypes.c_uint32),
        ("scrollback_count", ctypes.c_uint32),
        ("scrollback_offset", ctypes.c_uint32),
        ("alive", ctypes.c_uint8),
        ("has_exit_code", ctypes.c_uint8),
        ("_padding0", ctypes.c_uint8 * 2),
        ("exit_code", ctypes.c_int32),
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


class RendererMetadata(ctypes.Structure):
    _fields_ = [
        ("abi_version", ctypes.c_uint32),
        ("struct_size", ctypes.c_uint32),
        ("codepoint", ctypes.c_uint32),
        ("glyph_class_flags", ctypes.c_uint32),
        ("damage_policy_flags", ctypes.c_uint32),
    ]


HandlePtr = ctypes.POINTER(ZideTerminalHandle)


class MockTerminalService:
    def __init__(self) -> None:
        self._chunks = [
            b"\x1b]0;mock-title\x07",
            b"\x1b]7;file://localhost/mock/service\x07",
            b"mock-line-1\r\n",
            b"mock-line-2\r\n",
            b"\x1b]52;c;bW9jay1jbGlw\x07",
            b"tail",
        ]

    def stream(self):
        for chunk in self._chunks:
            yield chunk

def load_library(path: Path):
    lib = load_cdll(path)
    lib.zide_terminal_create.argtypes = [ctypes.POINTER(CreateConfig), ctypes.POINTER(HandlePtr)]
    lib.zide_terminal_create.restype = ctypes.c_int
    lib.zide_terminal_destroy.argtypes = [HandlePtr]
    lib.zide_terminal_destroy.restype = None
    lib.zide_terminal_resize.argtypes = [HandlePtr, ctypes.c_uint16, ctypes.c_uint16, ctypes.c_uint16, ctypes.c_uint16]
    lib.zide_terminal_resize.restype = ctypes.c_int
    lib.zide_terminal_feed_output.argtypes = [HandlePtr, ctypes.POINTER(ctypes.c_uint8), ctypes.c_size_t]
    lib.zide_terminal_feed_output.restype = ctypes.c_int
    lib.zide_terminal_close_input.argtypes = [HandlePtr]
    lib.zide_terminal_close_input.restype = ctypes.c_int
    lib.zide_terminal_snapshot_acquire.argtypes = [HandlePtr, ctypes.POINTER(Snapshot)]
    lib.zide_terminal_snapshot_acquire.restype = ctypes.c_int
    lib.zide_terminal_snapshot_release.argtypes = [ctypes.POINTER(Snapshot)]
    lib.zide_terminal_snapshot_release.restype = None
    lib.zide_terminal_scrollback_acquire.argtypes = [
        HandlePtr,
        ctypes.c_uint32,
        ctypes.c_uint32,
        ctypes.POINTER(ScrollbackBuffer),
    ]
    lib.zide_terminal_scrollback_acquire.restype = ctypes.c_int
    lib.zide_terminal_scrollback_release.argtypes = [ctypes.POINTER(ScrollbackBuffer)]
    lib.zide_terminal_scrollback_release.restype = None
    lib.zide_terminal_metadata_acquire.argtypes = [HandlePtr, ctypes.POINTER(Metadata)]
    lib.zide_terminal_metadata_acquire.restype = ctypes.c_int
    lib.zide_terminal_metadata_release.argtypes = [ctypes.POINTER(Metadata)]
    lib.zide_terminal_metadata_release.restype = None
    lib.zide_terminal_event_drain.argtypes = [HandlePtr, ctypes.POINTER(EventBuffer)]
    lib.zide_terminal_event_drain.restype = ctypes.c_int
    lib.zide_terminal_events_free.argtypes = [ctypes.POINTER(EventBuffer)]
    lib.zide_terminal_events_free.restype = None
    lib.zide_terminal_is_alive.argtypes = [HandlePtr]
    lib.zide_terminal_is_alive.restype = ctypes.c_uint8
    lib.zide_terminal_string_free.argtypes = [ctypes.POINTER(StringBuffer)]
    lib.zide_terminal_string_free.restype = None
    lib.zide_terminal_child_exit_status.argtypes = [HandlePtr, ctypes.POINTER(ctypes.c_int32), ctypes.POINTER(ctypes.c_uint8)]
    lib.zide_terminal_child_exit_status.restype = ctypes.c_int
    lib.zide_terminal_snapshot_abi_version.argtypes = []
    lib.zide_terminal_snapshot_abi_version.restype = ctypes.c_uint32
    lib.zide_terminal_event_abi_version.argtypes = []
    lib.zide_terminal_event_abi_version.restype = ctypes.c_uint32
    lib.zide_terminal_scrollback_abi_version.argtypes = []
    lib.zide_terminal_scrollback_abi_version.restype = ctypes.c_uint32
    lib.zide_terminal_renderer_metadata_abi_version.argtypes = []
    lib.zide_terminal_renderer_metadata_abi_version.restype = ctypes.c_uint32
    lib.zide_terminal_renderer_metadata.argtypes = [ctypes.c_uint32, ctypes.POINTER(RendererMetadata)]
    lib.zide_terminal_renderer_metadata.restype = ctypes.c_int
    lib.zide_terminal_status_string.argtypes = [ctypes.c_int]
    lib.zide_terminal_status_string.restype = ctypes.c_char_p
    return lib


def expect_invalid_argument(status: int, context: str) -> None:
    if status != 1:
        raise RuntimeError(f"{context} expected invalid_argument, got {status}")

def render_first_row(snapshot: Snapshot) -> str:
    return render_snapshot_row(snapshot, 0)


def render_snapshot_row(snapshot: Snapshot, row: int) -> str:
    if not snapshot.cells:
        return ""
    cols = int(snapshot.cols)
    start = row * cols
    chars: list[str] = []
    for col in range(cols):
        cell = snapshot.cells[start + col]
        if cell.width == 0:
            continue
        cp = int(cell.codepoint)
        chars.append(" " if cp == 0 else chr(cp))
    return "".join(chars).rstrip()


def render_scrollback_row(scrollback: ScrollbackBuffer, row: int) -> str:
    if not scrollback.cells:
        return ""
    cols = int(scrollback.cols)
    start = row * cols
    chars: list[str] = []
    for col in range(cols):
        cell = scrollback.cells[start + col]
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
        history = b"".join([f"hist-{i:02d}\r\n".encode("ascii") for i in range(20)])
        history_buf = (ctypes.c_uint8 * len(history)).from_buffer_copy(history)
        status = lib.zide_terminal_feed_output(handle, history_buf, len(history))
        if status != STATUS_OK:
            raise RuntimeError(f"feed_output(history) failed: {status}")

        snapshot = Snapshot()
        status = lib.zide_terminal_snapshot_acquire(handle, ctypes.byref(snapshot))
        if status != STATUS_OK:
            raise RuntimeError(f"snapshot_acquire failed: {status}")
        try:
            title = as_bytes(snapshot.title_ptr, snapshot.title_len).decode("utf-8", errors="replace")
            cwd = as_bytes(snapshot.cwd_ptr, snapshot.cwd_len).decode("utf-8", errors="replace")
            row0 = render_first_row(snapshot)
            metadata = Metadata()
            if lib.zide_terminal_metadata_acquire(handle, ctypes.byref(metadata)) != STATUS_OK:
                raise RuntimeError("metadata_acquire failed")
            try:
                title_getter = as_bytes(metadata.title_ptr, metadata.title_len).decode("utf-8", errors="replace")
                cwd_getter = as_bytes(metadata.cwd_ptr, metadata.cwd_len).decode("utf-8", errors="replace")
                scrollback_count = metadata.scrollback_count
            finally:
                lib.zide_terminal_metadata_release(ctypes.byref(metadata))

            exit_code = ctypes.c_int32(-1)
            has_exit = ctypes.c_uint8(0)
            if lib.zide_terminal_child_exit_status(handle, ctypes.byref(exit_code), ctypes.byref(has_exit)) != STATUS_OK:
                raise RuntimeError("child_exit_status failed")

            print("ffi smoke ok")
            print(
                f"snapshot_abi={lib.zide_terminal_snapshot_abi_version()} event_abi={lib.zide_terminal_event_abi_version()} scrollback_abi={lib.zide_terminal_scrollback_abi_version()} renderer_meta_abi={lib.zide_terminal_renderer_metadata_abi_version()}"
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

        rounded_box_meta = RendererMetadata()
        if lib.zide_terminal_renderer_metadata(0x256D, ctypes.byref(rounded_box_meta)) != STATUS_OK:
            raise RuntimeError("renderer_metadata(rounded box) failed")
        if (rounded_box_meta.glyph_class_flags & GLYPH_CLASS_BOX) == 0 or (rounded_box_meta.glyph_class_flags & GLYPH_CLASS_BOX_ROUNDED) == 0:
            raise RuntimeError("rounded box glyph flags missing")

        braille_meta = RendererMetadata()
        if lib.zide_terminal_renderer_metadata(0x28FF, ctypes.byref(braille_meta)) != STATUS_OK:
            raise RuntimeError("renderer_metadata(braille) failed")
        if (braille_meta.glyph_class_flags & GLYPH_CLASS_BRAILLE) == 0 or (braille_meta.glyph_class_flags & GLYPH_CLASS_GRAPH) == 0:
            raise RuntimeError("braille/graph glyph flags missing")

        rounded_powerline_meta = RendererMetadata()
        if lib.zide_terminal_renderer_metadata(0xE0B5, ctypes.byref(rounded_powerline_meta)) != STATUS_OK:
            raise RuntimeError("renderer_metadata(rounded powerline) failed")
        if (rounded_powerline_meta.glyph_class_flags & GLYPH_CLASS_POWERLINE) == 0 or (
            rounded_powerline_meta.glyph_class_flags & GLYPH_CLASS_POWERLINE_ROUNDED
        ) == 0:
            raise RuntimeError("powerline glyph flags missing")
        if (rounded_powerline_meta.damage_policy_flags & DAMAGE_POLICY_ADVISORY_BOUNDS) == 0 or (
            rounded_powerline_meta.damage_policy_flags & DAMAGE_POLICY_FULL_REDRAW_SAFE_DEFAULT
        ) == 0:
            raise RuntimeError("damage policy flags missing")

        print(
            "renderer_metadata "
            f"box=0x{rounded_box_meta.glyph_class_flags:x} "
            f"braille=0x{braille_meta.glyph_class_flags:x} "
            f"powerline=0x{rounded_powerline_meta.glyph_class_flags:x} "
            f"damage=0x{rounded_powerline_meta.damage_policy_flags:x}"
        )

        if scrollback_count == 0:
            raise RuntimeError("expected scrollback rows")
        scrollback = ScrollbackBuffer()
        status = lib.zide_terminal_scrollback_acquire(handle, 0, min(2, scrollback_count), ctypes.byref(scrollback))
        if status != STATUS_OK:
            raise RuntimeError(f"scrollback_acquire failed: {status}")
        try:
            scrollback_row0 = render_scrollback_row(scrollback, 0)
            print(
                f"scrollback_total={scrollback.total_rows} window=({scrollback.start_row},{scrollback.row_count}) cols={scrollback.cols} row0={scrollback_row0!r}"
            )
            if "hist-" not in scrollback_row0:
                raise RuntimeError("unexpected scrollback row content")
        finally:
            lib.zide_terminal_scrollback_release(ctypes.byref(scrollback))

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


def run_mock_service_smoke(lib_path: Path) -> int:
    lib = load_library(lib_path)
    handle = HandlePtr()
    cfg = CreateConfig(rows=8, cols=40, scrollback_rows=64, cursor_shape=0, cursor_blink=1)

    status = lib.zide_terminal_create(ctypes.byref(cfg), ctypes.byref(handle))
    if status != STATUS_OK:
        raise RuntimeError(f"create failed: {status}")
    try:
        if lib.zide_terminal_resize(handle, 40, 8, 8, 16) != STATUS_OK:
            raise RuntimeError("resize failed")

        service = MockTerminalService()
        saw_title = False
        saw_clipboard = False
        saw_alive_closed = False
        redraw_events = 0

        for chunk in service.stream():
            buf = (ctypes.c_uint8 * len(chunk)).from_buffer_copy(chunk)
            if lib.zide_terminal_feed_output(handle, buf, len(chunk)) != STATUS_OK:
                raise RuntimeError("feed_output(mock chunk) failed")

            events = EventBuffer()
            if lib.zide_terminal_event_drain(handle, ctypes.byref(events)) != STATUS_OK:
                raise RuntimeError("event_drain(mock) failed")
            try:
                for i in range(events.count):
                    event = events.events[i]
                    payload = as_bytes(event.data_ptr, event.data_len)
                    if event.kind == EVENT_TITLE_CHANGED and payload == b"mock-title":
                        saw_title = True
                    if event.kind == EVENT_CLIPBOARD_WRITE and payload == b"mock-clip":
                        saw_clipboard = True
                    if event.kind == EVENT_REDRAW_READY:
                        redraw_events += 1
            finally:
                lib.zide_terminal_events_free(ctypes.byref(events))

        if lib.zide_terminal_close_input(handle) != STATUS_OK:
            raise RuntimeError("close_input(mock) failed")

        events = EventBuffer()
        if lib.zide_terminal_event_drain(handle, ctypes.byref(events)) != STATUS_OK:
            raise RuntimeError("event_drain(close_input) failed")
        try:
            for i in range(events.count):
                event = events.events[i]
                if event.kind == EVENT_ALIVE_CHANGED and event.int0 == 0:
                    saw_alive_closed = True
        finally:
            lib.zide_terminal_events_free(ctypes.byref(events))

        snapshot = Snapshot()
        if lib.zide_terminal_snapshot_acquire(handle, ctypes.byref(snapshot)) != STATUS_OK:
            raise RuntimeError("snapshot_acquire(mock) failed")
        try:
            title = as_bytes(snapshot.title_ptr, snapshot.title_len).decode("utf-8", errors="replace")
            cwd = as_bytes(snapshot.cwd_ptr, snapshot.cwd_len).decode("utf-8", errors="replace")
            row0 = render_snapshot_row(snapshot, 0)
            row2 = render_snapshot_row(snapshot, 2)
            metadata = Metadata()
            if lib.zide_terminal_metadata_acquire(handle, ctypes.byref(metadata)) != STATUS_OK:
                raise RuntimeError("metadata_acquire(mock) failed")
            try:
                scrollback_count = metadata.scrollback_count
                alive = metadata.alive
            finally:
                lib.zide_terminal_metadata_release(ctypes.byref(metadata))
            if title != "mock-title":
                raise RuntimeError(f"unexpected mock title: {title!r}")
            if cwd != "/mock/service":
                raise RuntimeError(f"unexpected mock cwd: {cwd!r}")
            if row0 != "mock-line-1":
                raise RuntimeError(f"unexpected mock row0: {row0!r}")
            if row2 != "tail":
                raise RuntimeError(f"unexpected mock row2: {row2!r}")
            if scrollback_count != 0:
                raise RuntimeError(f"unexpected mock scrollback_count: {scrollback_count}")
            if alive != 0:
                raise RuntimeError(f"unexpected mock alive after close_input: {alive}")
            print("terminal ffi mock service ok")
            print(f"title={title!r} cwd={cwd!r} row0={row0!r} row2={row2!r} scrollback_count={scrollback_count} alive={alive}")
        finally:
            lib.zide_terminal_snapshot_release(ctypes.byref(snapshot))

        if not saw_title:
            raise RuntimeError("missing mock title_changed event")
        if not saw_clipboard:
            raise RuntimeError("missing mock clipboard_write event")
        if not saw_alive_closed:
            raise RuntimeError("missing mock alive_changed event after close_input")
        if redraw_events == 0:
            raise RuntimeError("missing mock redraw_ready event")
        return 0
    finally:
        lib.zide_terminal_destroy(handle)


def run_abi_mismatch_smoke(lib_path: Path) -> int:
    lib = load_library(lib_path)
    handle = HandlePtr()
    cfg = CreateConfig(rows=4, cols=16, scrollback_rows=16, cursor_shape=0, cursor_blink=0)

    status = lib.zide_terminal_create(ctypes.byref(cfg), ctypes.byref(handle))
    if status != STATUS_OK:
        raise RuntimeError(f"create failed: {status}")
    try:
        if lib.zide_terminal_resize(handle, 16, 4, 8, 16) != STATUS_OK:
            raise RuntimeError("resize failed")

        snapshot = Snapshot()
        snapshot.abi_version = 999
        snapshot.struct_size = 1
        status = lib.zide_terminal_snapshot_acquire(handle, ctypes.byref(snapshot))
        if status != STATUS_OK:
            raise RuntimeError(f"snapshot_acquire failed: {status}")
        try:
            if snapshot.abi_version != lib.zide_terminal_snapshot_abi_version():
                raise RuntimeError(f"unexpected snapshot abi_version: {snapshot.abi_version}")
            if snapshot.struct_size != ctypes.sizeof(Snapshot):
                raise RuntimeError(f"unexpected snapshot struct_size: {snapshot.struct_size}")
            snapshot_result = (snapshot.abi_version, snapshot.struct_size)
        finally:
            lib.zide_terminal_snapshot_release(ctypes.byref(snapshot))

        scrollback = ScrollbackBuffer()
        scrollback.abi_version = 999
        scrollback.struct_size = 1
        status = lib.zide_terminal_scrollback_acquire(handle, 0, 1, ctypes.byref(scrollback))
        if status != STATUS_OK:
            raise RuntimeError(f"scrollback_acquire failed: {status}")
        try:
            if scrollback.abi_version != lib.zide_terminal_scrollback_abi_version():
                raise RuntimeError(f"unexpected scrollback abi_version: {scrollback.abi_version}")
            if scrollback.struct_size != ctypes.sizeof(ScrollbackBuffer):
                raise RuntimeError(f"unexpected scrollback struct_size: {scrollback.struct_size}")
            scrollback_result = (scrollback.abi_version, scrollback.struct_size)
        finally:
            lib.zide_terminal_scrollback_release(ctypes.byref(scrollback))

        metadata = Metadata()
        metadata.abi_version = 999
        metadata.struct_size = 1
        status = lib.zide_terminal_metadata_acquire(handle, ctypes.byref(metadata))
        if status != STATUS_OK:
            raise RuntimeError(f"metadata_acquire failed: {status}")
        try:
            if metadata.abi_version != lib.zide_terminal_metadata_abi_version():
                raise RuntimeError(f"unexpected metadata abi_version: {metadata.abi_version}")
            if metadata.struct_size != ctypes.sizeof(Metadata):
                raise RuntimeError(f"unexpected metadata struct_size: {metadata.struct_size}")
            metadata_result = (metadata.abi_version, metadata.struct_size)
        finally:
            lib.zide_terminal_metadata_release(ctypes.byref(metadata))

        renderer = RendererMetadata()
        renderer.abi_version = 999
        renderer.struct_size = 1
        status = lib.zide_terminal_renderer_metadata(0x41, ctypes.byref(renderer))
        if status != STATUS_OK:
            raise RuntimeError(f"renderer_metadata failed: {status}")
        if renderer.abi_version != lib.zide_terminal_renderer_metadata_abi_version():
            raise RuntimeError(f"unexpected renderer abi_version: {renderer.abi_version}")
        if renderer.struct_size != ctypes.sizeof(RendererMetadata):
            raise RuntimeError(f"unexpected renderer struct_size: {renderer.struct_size}")

        print("terminal ffi abi mismatch regression ok")
        print(
            f"snapshot={snapshot_result} "
            f"scrollback={scrollback_result} "
            f"metadata={metadata_result} "
            f"renderer=({renderer.abi_version},{renderer.struct_size})"
        )
        return 0
    finally:
        lib.zide_terminal_destroy(handle)


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--lib", default="zig-out/lib/libzide-terminal-ffi.so")
    parser.add_argument("--scenario", choices=("baseline", "mock-service", "abi-mismatch"), default="baseline")
    args = parser.parse_args()

    lib_path = Path(args.lib)
    if not lib_path.exists():
        print(f"missing library: {lib_path}", file=sys.stderr)
        return 2

    try:
        if args.scenario == "mock-service":
            return run_mock_service_smoke(lib_path)
        if args.scenario == "abi-mismatch":
            return run_abi_mismatch_smoke(lib_path)
        return run_smoke(lib_path)
    except Exception as exc:
        print(f"ffi smoke failed: {exc}", file=sys.stderr)
        return 1


if __name__ == "__main__":
    raise SystemExit(main())
