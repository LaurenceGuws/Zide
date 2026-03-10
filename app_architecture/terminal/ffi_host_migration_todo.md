# Terminal + Editor FFI Host Migration Todo

- [x] Add one shared FFI host boot helper (`examples/common/ffi_host_boot.py`) that loads both `libzide-terminal-ffi` and `libzide-editor-ffi` with shared Python host setup.
- [x] Define a tiny cross-surface event pump contract doc (`poll_terminal_then_editor_once`) and wire it in both smoke hosts.
- [x] Add terminal+editor combined smoke script (`examples/ffi_host_combo_smoke/main.py`) that runs: start terminal, acquire snapshot, create editor, set text, query cursor, clean shutdown.
- [~] Add ABI-shape regression coverage per bridge.
  - [x] Terminal Python smoke now verifies bad prefilled `abi_version` / `struct_size` inputs are overwritten with canonical values on all ABI-versioned output structs.
  - [x] Editor Python smoke now verifies deterministic `invalid_argument` behavior for bad bridge calls.
  - [ ] If editor FFI later gains ABI-versioned structs, add the same `abi_version` / `struct_size` mismatch regression there.
- [x] Add a host-migration checklist section in both smoke READMEs describing minimum required calls and resource free order.
- [x] Add a single `zig build` step that runs the combo smoke in non-interactive mode (no PTY dependency) to verify dual-bridge loading/lifetime.
- [x] Add a mock external-service scenario to `examples/terminal_ffi_smoke/main.py` so the no-PTY host path can stream chunks incrementally instead of only doing one-shot feed smoke.

Cross-surface event pump contract:
- `poll_terminal_then_editor_once(...)` is the minimal shared host tick for mixed terminal/editor embedders.
- Terminal-side publication/drain work runs first.
- Editor-side mutations/queries run second.
- Any snapshot/string/event buffers acquired during the tick are freed before the tick returns.
