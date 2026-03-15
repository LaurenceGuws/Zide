# Terminal Work Queues

This folder holds active terminal implementation queues.

Use it for:

- active redesign and modularization work
- host/FFI migration steps
- rendering/present follow-up
- terminal-only feature queues

Current high-signal entrypoints:

- `vt_core_rearchitecture.md` — engine/core split and transport-first redesign
- `wayland_present.md` — present-path execution authority and validation
- `modularization.md` — terminal modularization queue
- `damage_tracking.md` — redraw correctness and damage/publication follow-up
- `ffi_bridge.md` — embeddable terminal bridge plan
- `ffi_host_migration.md` — host migration follow-up

Do not treat this folder as architecture authority. Durable design ownership
lives under `app_architecture/terminal/`.
