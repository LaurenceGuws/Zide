#!/usr/bin/env python3
import argparse
import ctypes
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
if str(ROOT) not in sys.path:
    sys.path.insert(0, str(ROOT))

from examples.common.ffi_host_boot import as_bytes, load_cdll, STATUS_OK  # noqa: E402


class ZideEditorHandle(ctypes.Structure):
    pass


class StringBuffer(ctypes.Structure):
    _fields_ = [
        ("abi_version", ctypes.c_uint32),
        ("struct_size", ctypes.c_uint32),
        ("ptr", ctypes.POINTER(ctypes.c_uint8)),
        ("len", ctypes.c_size_t),
        ("_ctx", ctypes.c_void_p),
    ]


class CaretOffset(ctypes.Structure):
    _fields_ = [("offset", ctypes.c_size_t)]


class SearchMatch(ctypes.Structure):
    _fields_ = [("start", ctypes.c_size_t), ("end", ctypes.c_size_t)]


HandlePtr = ctypes.POINTER(ZideEditorHandle)

def load_library(path: Path):
    lib = load_cdll(path)
    lib.zide_editor_create.argtypes = [ctypes.POINTER(HandlePtr)]
    lib.zide_editor_create.restype = ctypes.c_int
    lib.zide_editor_destroy.argtypes = [HandlePtr]
    lib.zide_editor_destroy.restype = None
    lib.zide_editor_set_text.argtypes = [HandlePtr, ctypes.POINTER(ctypes.c_uint8), ctypes.c_size_t]
    lib.zide_editor_set_text.restype = ctypes.c_int
    lib.zide_editor_insert_text.argtypes = [HandlePtr, ctypes.POINTER(ctypes.c_uint8), ctypes.c_size_t]
    lib.zide_editor_insert_text.restype = ctypes.c_int
    lib.zide_editor_replace_range.argtypes = [HandlePtr, ctypes.c_size_t, ctypes.c_size_t, ctypes.POINTER(ctypes.c_uint8), ctypes.c_size_t]
    lib.zide_editor_replace_range.restype = ctypes.c_int
    lib.zide_editor_delete_range.argtypes = [HandlePtr, ctypes.c_size_t, ctypes.c_size_t]
    lib.zide_editor_delete_range.restype = ctypes.c_int
    lib.zide_editor_begin_undo_group.argtypes = [HandlePtr]
    lib.zide_editor_begin_undo_group.restype = ctypes.c_int
    lib.zide_editor_end_undo_group.argtypes = [HandlePtr]
    lib.zide_editor_end_undo_group.restype = ctypes.c_int
    lib.zide_editor_text_alloc.argtypes = [HandlePtr, ctypes.POINTER(StringBuffer)]
    lib.zide_editor_text_alloc.restype = ctypes.c_int
    lib.zide_editor_string_free.argtypes = [ctypes.POINTER(StringBuffer)]
    lib.zide_editor_string_free.restype = None
    lib.zide_editor_string_abi_version.argtypes = []
    lib.zide_editor_string_abi_version.restype = ctypes.c_uint32
    lib.zide_editor_set_cursor_offset.argtypes = [HandlePtr, ctypes.c_size_t]
    lib.zide_editor_set_cursor_offset.restype = ctypes.c_int
    lib.zide_editor_primary_caret_offset.argtypes = [HandlePtr, ctypes.POINTER(ctypes.c_size_t)]
    lib.zide_editor_primary_caret_offset.restype = ctypes.c_int
    lib.zide_editor_aux_caret_count.argtypes = [HandlePtr, ctypes.POINTER(ctypes.c_size_t)]
    lib.zide_editor_aux_caret_count.restype = ctypes.c_int
    lib.zide_editor_aux_caret_get.argtypes = [HandlePtr, ctypes.c_size_t, ctypes.POINTER(ctypes.c_size_t)]
    lib.zide_editor_aux_caret_get.restype = ctypes.c_int
    lib.zide_editor_clear_selections.argtypes = [HandlePtr]
    lib.zide_editor_clear_selections.restype = ctypes.c_int
    lib.zide_editor_set_carets.argtypes = [HandlePtr, ctypes.c_size_t, ctypes.POINTER(CaretOffset), ctypes.c_size_t]
    lib.zide_editor_set_carets.restype = ctypes.c_int
    lib.zide_editor_cursor_offset.argtypes = [HandlePtr, ctypes.POINTER(ctypes.c_size_t)]
    lib.zide_editor_cursor_offset.restype = ctypes.c_int
    lib.zide_editor_undo.argtypes = [HandlePtr, ctypes.POINTER(ctypes.c_uint8)]
    lib.zide_editor_undo.restype = ctypes.c_int
    lib.zide_editor_redo.argtypes = [HandlePtr, ctypes.POINTER(ctypes.c_uint8)]
    lib.zide_editor_redo.restype = ctypes.c_int
    lib.zide_editor_line_count.argtypes = [HandlePtr, ctypes.POINTER(ctypes.c_size_t)]
    lib.zide_editor_line_count.restype = ctypes.c_int
    lib.zide_editor_total_len.argtypes = [HandlePtr, ctypes.POINTER(ctypes.c_size_t)]
    lib.zide_editor_total_len.restype = ctypes.c_int
    lib.zide_editor_search_set_query.argtypes = [HandlePtr, ctypes.POINTER(ctypes.c_uint8), ctypes.c_size_t, ctypes.c_uint8]
    lib.zide_editor_search_set_query.restype = ctypes.c_int
    lib.zide_editor_search_match_count.argtypes = [HandlePtr, ctypes.POINTER(ctypes.c_size_t)]
    lib.zide_editor_search_match_count.restype = ctypes.c_int
    lib.zide_editor_search_match_get.argtypes = [HandlePtr, ctypes.c_size_t, ctypes.POINTER(SearchMatch)]
    lib.zide_editor_search_match_get.restype = ctypes.c_int
    lib.zide_editor_search_active_index.argtypes = [HandlePtr, ctypes.POINTER(ctypes.c_size_t), ctypes.POINTER(ctypes.c_uint8)]
    lib.zide_editor_search_active_index.restype = ctypes.c_int
    lib.zide_editor_search_next.argtypes = [HandlePtr, ctypes.POINTER(ctypes.c_uint8)]
    lib.zide_editor_search_next.restype = ctypes.c_int
    lib.zide_editor_search_prev.argtypes = [HandlePtr, ctypes.POINTER(ctypes.c_uint8)]
    lib.zide_editor_search_prev.restype = ctypes.c_int
    lib.zide_editor_search_replace_active.argtypes = [HandlePtr, ctypes.POINTER(ctypes.c_uint8), ctypes.c_size_t, ctypes.POINTER(ctypes.c_uint8)]
    lib.zide_editor_search_replace_active.restype = ctypes.c_int
    lib.zide_editor_search_replace_all.argtypes = [HandlePtr, ctypes.POINTER(ctypes.c_uint8), ctypes.c_size_t, ctypes.POINTER(ctypes.c_size_t)]
    lib.zide_editor_search_replace_all.restype = ctypes.c_int
    lib.zide_editor_status_string.argtypes = [ctypes.c_int]
    lib.zide_editor_status_string.restype = ctypes.c_char_p
    return lib


def to_buf(data: bytes):
    if not data:
        return None, 0
    arr = (ctypes.c_uint8 * len(data)).from_buffer_copy(data)
    return arr, len(data)


def expect_invalid_argument(status: int, context: str) -> None:
    if status != STATUS_OK + 1:
        raise RuntimeError(f"{context} expected invalid_argument, got {status}")


def run_smoke(lib_path: Path) -> int:
    lib = load_library(lib_path)
    handle = HandlePtr()
    status = lib.zide_editor_create(ctypes.byref(handle))
    if status != STATUS_OK:
        raise RuntimeError(f"create failed: {status}")

    try:
        data, data_len = to_buf(b"foo bar foo\nline two\n")
        if lib.zide_editor_set_text(handle, data, data_len) != STATUS_OK:
            raise RuntimeError("set_text failed")

        if lib.zide_editor_set_cursor_offset(handle, 4) != STATUS_OK:
            raise RuntimeError("set_cursor_offset failed")
        ins, ins_len = to_buf(b"ZZ ")
        if lib.zide_editor_insert_text(handle, ins, ins_len) != STATUS_OK:
            raise RuntimeError("insert_text failed")
        if lib.zide_editor_replace_range(handle, 0, 3, *to_buf(b"hey")) != STATUS_OK:
            raise RuntimeError("replace_range failed")
        if lib.zide_editor_delete_range(handle, 3, 4) != STATUS_OK:
            raise RuntimeError("delete_range failed")

        if lib.zide_editor_begin_undo_group(handle) != STATUS_OK:
            raise RuntimeError("begin_undo_group failed")
        if lib.zide_editor_replace_range(handle, 0, 3, *to_buf(b"YO")) != STATUS_OK:
            raise RuntimeError("replace_range grouped failed")
        if lib.zide_editor_replace_range(handle, 5, 7, *to_buf(b"XX")) != STATUS_OK:
            raise RuntimeError("replace_range grouped failed")
        if lib.zide_editor_end_undo_group(handle) != STATUS_OK:
            raise RuntimeError("end_undo_group failed")

        changed = ctypes.c_uint8(0)
        if lib.zide_editor_undo(handle, ctypes.byref(changed)) != STATUS_OK or changed.value == 0:
            raise RuntimeError("undo failed")
        if lib.zide_editor_redo(handle, ctypes.byref(changed)) != STATUS_OK or changed.value == 0:
            raise RuntimeError("redo failed")

        aux = (CaretOffset * 2)(CaretOffset(2), CaretOffset(8))
        if lib.zide_editor_set_carets(handle, 1, aux, 2) != STATUS_OK:
            raise RuntimeError("set_carets failed")
        primary = ctypes.c_size_t(0)
        if lib.zide_editor_primary_caret_offset(handle, ctypes.byref(primary)) != STATUS_OK:
            raise RuntimeError("primary_caret_offset failed")
        aux_count = ctypes.c_size_t(0)
        if lib.zide_editor_aux_caret_count(handle, ctypes.byref(aux_count)) != STATUS_OK:
            raise RuntimeError("aux_caret_count failed")

        if lib.zide_editor_search_set_query(handle, *to_buf(b"foo"), ctypes.c_uint8(0)) != STATUS_OK:
            raise RuntimeError("search_set_query failed")
        match_count = ctypes.c_size_t(0)
        if lib.zide_editor_search_match_count(handle, ctypes.byref(match_count)) != STATUS_OK:
            raise RuntimeError("search_match_count failed")
        activated = ctypes.c_uint8(0)
        if lib.zide_editor_search_next(handle, ctypes.byref(activated)) != STATUS_OK:
            raise RuntimeError("search_next failed")
        replaced = ctypes.c_uint8(0)
        if lib.zide_editor_search_replace_active(handle, *to_buf(b"qq"), ctypes.byref(replaced)) != STATUS_OK:
            raise RuntimeError("search_replace_active failed")
        replaced_all = ctypes.c_size_t(0)
        if lib.zide_editor_search_replace_all(handle, *to_buf(b"R"), ctypes.byref(replaced_all)) != STATUS_OK:
            raise RuntimeError("search_replace_all failed")

        text = StringBuffer()
        if lib.zide_editor_text_alloc(handle, ctypes.byref(text)) != STATUS_OK:
            raise RuntimeError("text_alloc failed")
        try:
            if text.abi_version != lib.zide_editor_string_abi_version():
                raise RuntimeError(f"unexpected string abi_version: {text.abi_version}")
            if text.struct_size != ctypes.sizeof(StringBuffer):
                raise RuntimeError(f"unexpected string struct_size: {text.struct_size}")
            text_value = as_bytes(text.ptr, text.len).decode("utf-8", errors="replace")
        finally:
            lib.zide_editor_string_free(ctypes.byref(text))

        line_count = ctypes.c_size_t(0)
        total_len = ctypes.c_size_t(0)
        if lib.zide_editor_line_count(handle, ctypes.byref(line_count)) != STATUS_OK:
            raise RuntimeError("line_count failed")
        if lib.zide_editor_total_len(handle, ctypes.byref(total_len)) != STATUS_OK:
            raise RuntimeError("total_len failed")

        print("editor ffi smoke ok")
        print(
            f"status_ok={lib.zide_editor_status_string(0).decode()} "
            f"status_unknown={lib.zide_editor_status_string(99).decode()} "
            f"string_abi={lib.zide_editor_string_abi_version()}"
        )
        print(f"primary={primary.value} aux_count={aux_count.value} matches={match_count.value} replaced_all={replaced_all.value}")
        print(f"line_count={line_count.value} total_len={total_len.value}")
        print(f"text={text_value!r}")
        return 0
    finally:
        lib.zide_editor_destroy(handle)


def run_invalid_argument_smoke(lib_path: Path) -> int:
    lib = load_library(lib_path)

    out_count = ctypes.c_size_t(0)
    expect_invalid_argument(
        lib.zide_editor_total_len(HandlePtr(), ctypes.byref(out_count)),
        "total_len(null handle)",
    )

    expect_invalid_argument(
        lib.zide_editor_replace_range(HandlePtr(), 5, 3, *to_buf(b"x")),
        "replace_range(end<start)",
    )

    handle = HandlePtr()
    status = lib.zide_editor_create(ctypes.byref(handle))
    if status != STATUS_OK:
        raise RuntimeError(f"create failed: {status}")
    try:
        expect_invalid_argument(
            lib.zide_editor_search_match_get(handle, 0, ctypes.byref(SearchMatch())),
            "search_match_get(out of bounds)",
        )
        expect_invalid_argument(
            lib.zide_editor_aux_caret_get(handle, 0, ctypes.byref(ctypes.c_size_t(0))),
            "aux_caret_get(out of bounds)",
        )
        print("editor ffi invalid argument regression ok")
        print("cases=null-handle,replace-range-order,search-match-oob,aux-caret-oob")
        return 0
    finally:
        lib.zide_editor_destroy(handle)


def run_abi_mismatch_smoke(lib_path: Path) -> int:
    lib = load_library(lib_path)
    handle = HandlePtr()
    status = lib.zide_editor_create(ctypes.byref(handle))
    if status != STATUS_OK:
        raise RuntimeError(f"create failed: {status}")

    try:
        data, data_len = to_buf(b"editor abi string\n")
        if lib.zide_editor_set_text(handle, data, data_len) != STATUS_OK:
            raise RuntimeError("set_text failed")

        text = StringBuffer()
        text.abi_version = 999
        text.struct_size = 1
        if lib.zide_editor_text_alloc(handle, ctypes.byref(text)) != STATUS_OK:
            raise RuntimeError("text_alloc failed")
        try:
            if text.abi_version != lib.zide_editor_string_abi_version():
                raise RuntimeError(f"unexpected string abi_version: {text.abi_version}")
            if text.struct_size != ctypes.sizeof(StringBuffer):
                raise RuntimeError(f"unexpected string struct_size: {text.struct_size}")
            text_result = (text.abi_version, text.struct_size)
        finally:
            lib.zide_editor_string_free(ctypes.byref(text))

        print("editor ffi abi mismatch regression ok")
        print(f"string={text_result}")
        return 0
    finally:
        lib.zide_editor_destroy(handle)


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument(
        "--lib",
        default="zig-out/lib/libzide-editor-ffi.so",
        help="Path to editor ffi shared library",
    )
    parser.add_argument(
        "--scenario",
        choices=("baseline", "invalid-args", "abi-mismatch"),
        default="baseline",
    )
    args = parser.parse_args()
    if args.scenario == "invalid-args":
        return run_invalid_argument_smoke(Path(args.lib))
    if args.scenario == "abi-mismatch":
        return run_abi_mismatch_smoke(Path(args.lib))
    return run_smoke(Path(args.lib))


if __name__ == "__main__":
    raise SystemExit(main())
