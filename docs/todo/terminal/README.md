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
- `ffi_bridge.md` — embeddable terminal bridge plan
- `ffi_host_migration.md` — host migration follow-up
- `tabs.md` — backend workspace / tab follow-up for terminal mode and future FFI

Maintenance or supporting queues:

- `protocol.md` — protocol parity follow-up after the main backlog closure
- `damage_tracking.md` — narrower redraw/publication cleanup after the main rewrite/hardening work
- `modularization.md` — mostly historical extraction record; active structural work now lives in `vt_core_rearchitecture.md`
- `widget.md` — mostly historical terminal-widget backlog; active UI rendering follow-up now lives under `docs/todo/ui/`

Do not treat this folder as architecture authority. Durable design ownership
lives under `app_architecture/terminal/`.
