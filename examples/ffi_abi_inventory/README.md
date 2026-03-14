# FFI ABI Inventory

Purpose: load both shipped FFI bridges and print the current exported ABI-version
inventory in one non-interactive place.

This verifier is intentionally narrow. It does not exercise behavior. It answers
the simpler embedded-host question:
- did both shared libraries load
- which ABI-versioned surfaces do they currently export

## Run

1. `zig build build-terminal-ffi`
2. `zig build build-editor-ffi`
3. `python3 examples/ffi_abi_inventory/main.py --terminal-lib zig-out/lib/libzide-terminal-ffi.so --editor-lib zig-out/lib/libzide-editor-ffi.so`

Current printed inventory:
- terminal snapshot ABI
- terminal event ABI
- terminal scrollback ABI
- terminal metadata ABI
- terminal redraw-state ABI
- terminal string ABI
- terminal renderer-metadata ABI
- editor string ABI
