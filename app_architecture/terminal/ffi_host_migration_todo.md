# Terminal + Editor FFI Host Migration Todo

- [x] Add one shared FFI host boot helper (`examples/common/ffi_host_boot.py`) that loads both `libzide-terminal-ffi` and `libzide-editor-ffi` with shared Python host setup.
- [x] Define a tiny cross-surface event pump contract doc (`poll_terminal_then_editor_once`) and wire it in both smoke hosts.
- [x] Add terminal+editor combined smoke script (`examples/ffi_host_combo_smoke/main.py`) that runs: publish terminal content, confirm redraw truth, acquire snapshot, acknowledge presentation, then run editor work and clean shutdown.
- [x] Extract shared terminal publication consumption helper (`consume_terminal_publication_once(...)`) so mixed hosts do not hand-roll redraw-state and present-ack sequencing.
- [x] Move the standalone terminal smoke onto the same shared publication helper so dedicated and mixed hosts validate the same redraw/present contract.
- [x] Extract shared terminal metadata consumption helper (`consume_terminal_metadata_once(...)`) so Python hosts do not duplicate metadata acquire/release ownership boilerplate.
- [x] Extract shared terminal event consumption helper (`consume_terminal_events_once(...)`) so Python hosts do not duplicate `event_drain(...)` / `events_free(...)` ownership boilerplate.
- [x] Tighten the mixed terminal+editor smoke so it validates authoritative terminal metadata state, not snapshot publication alone.
- [x] Tighten the mixed terminal+editor smoke so it validates terminal event ownership as part of the same shared host tick.
- [x] Tighten the mixed terminal+editor smoke so it validates editor string-buffer ABI headers too, not just text content.
- [x] Add ABI-shape regression coverage per bridge.
  - [x] Terminal Python smoke now verifies bad prefilled `abi_version` / `struct_size` inputs are overwritten with canonical values on all ABI-versioned output structs.
  - [x] Editor Python smoke now verifies deterministic `invalid_argument` behavior for bad bridge calls.
  - [x] Editor string buffers now also carry inline `abi_version` / `struct_size`, and the editor Python smoke validates both normal acquire and bad-prefilled ABI mismatch overwrite behavior.
- [x] Add a host-migration checklist section in both smoke READMEs describing minimum required calls and resource free order.
- [x] Add a single `zig build` step that runs the combo smoke in non-interactive mode (no PTY dependency) to verify dual-bridge loading/lifetime.
- [x] Add a mock external-service scenario to `examples/terminal_ffi_smoke/main.py` so the no-PTY host path can stream chunks incrementally instead of only doing one-shot feed smoke.

Cross-surface event pump contract:
- `poll_terminal_then_editor_once(...)` is the minimal shared host tick for mixed terminal/editor embedders.
- `consume_terminal_publication_once(...)` is the shared terminal-side publication step inside that tick.
- `consume_terminal_metadata_once(...)` is the shared terminal-side latest-state metadata step for Python hosts.
- `consume_terminal_events_once(...)` is the shared terminal-side event ownership step for Python hosts.
- Terminal-side publication/drain work runs first.
- Terminal-side redraw truth and presentation acknowledgement are resolved before editor-side work.
- Editor-side mutations/queries run second.
- Any snapshot/string/event buffers acquired during the tick are freed before the tick returns.
