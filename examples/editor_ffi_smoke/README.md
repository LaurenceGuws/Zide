# Editor FFI Smoke

Purpose: mirror the terminal FFI smoke pattern for the editor/text-engine bridge.

This host is intentionally small and disposable. It verifies:
- shared library loading
- opaque handle lifecycle
- text set/get ownership (`text_alloc`/`string_free`)
- inline editor string ABI header validation (`abi_version` / `struct_size`)
- range edits + grouped undo/redo
- multicursor caret set/get
- search/replace flow (literal + regex)

## Why Python

Same reason as terminal smoke:
- low friction for ABI iteration
- easy ctypes struct inspection
- catches ownership/signature mistakes quickly

## Run

1. `zig build build-editor-ffi`
2. `python3 examples/editor_ffi_smoke/main.py --lib zig-out/lib/libzide-editor-ffi.so`

Invalid-argument regression scenario:
1. `zig build build-editor-ffi`
2. `python3 examples/editor_ffi_smoke/main.py --scenario invalid-args --lib zig-out/lib/libzide-editor-ffi.so`

Installed bridge artifacts:
- `zig-out/lib/libzide-editor-ffi.so`
- `zig-out/include/zide_editor_ffi.h`

Shared Python host boot helpers:
- `examples/common/ffi_host_boot.py`

Host migration checklist:
- if a host owns both bridges, run one terminal pump tick before editor-side mutations/queries
- free editor-owned strings after each query scope instead of caching borrowed pointers
- keep the editor bridge independent of PTY/session assumptions
