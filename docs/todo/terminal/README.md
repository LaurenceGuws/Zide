# Terminal Work Queues

This folder holds active terminal implementation queues.

Use it for:

- active terminal maturity and contract work
- host/FFI migration steps
- rendering/present follow-up
- terminal-only feature queues

Current default rule:

- do not treat this folder as a buffet of unrelated terminal seams
- the indefinite default priority is VT maturity purity
- use
  [VT_MATURITY_PURITY_CAMPAIGN.md](/home/home/personal/zide/app_architecture/terminal/VT_MATURITY_PURITY_CAMPAIGN.md)
  as the authority for what terminal work counts
- only continue `vt_core_rearchitecture.md` when one named maturity
  contradiction is explicit

Current high-signal entrypoints:

- `vt_core_rearchitecture.md` — active VT maturity purity queue and checkpoint
  record
- `wayland_present.md` — present-path execution queue and validation lane
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
