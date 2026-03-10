# Terminal + Editor FFI Host Migration Todo

- [ ] Add one shared FFI host boot helper (`examples/common/ffi_host_boot.py`) that loads both `libzide-terminal-ffi` and `libzide-editor-ffi` with version/struct-size checks.
- [ ] Define a tiny cross-surface event pump contract doc (`poll_terminal_then_editor_once`) and wire it in both smoke hosts.
- [ ] Add terminal+editor combined smoke script (`examples/ffi_host_combo_smoke/main.py`) that runs: start terminal, acquire snapshot, create editor, set text, query cursor, clean shutdown.
- [ ] Add one ABI mismatch regression test per bridge (bad `abi_version`, bad `struct_size`) that asserts deterministic error codes.
- [ ] Add a host-migration checklist section in both smoke READMEs describing minimum required calls and resource free order.
- [ ] Add a single `zig build` step that runs the combo smoke in non-interactive mode (no PTY dependency) to verify dual-bridge loading/lifetime.
- [x] Add a mock external-service scenario to `examples/terminal_ffi_smoke/main.py` so the no-PTY host path can stream chunks incrementally instead of only doing one-shot feed smoke.
