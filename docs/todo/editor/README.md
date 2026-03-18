# Editor Work Queues

This folder holds active editor implementation queues.

Use it for:

- active editor/app feature work
- text-engine and editing semantics follow-up
- tree-sitter and grammar-pack rollout work
- modularization and boundary cleanup when it materially supports the feature lane

Current priority order:

- Notepad-grade editor usability and basic editor-only chrome first
- editor config / CLI friendliness as part of that baseline
- modularization only where it keeps the feature work clean or removes bad ownership
- optimization and reference-repo comparison after the common editor feature baseline lands

Current high-signal entrypoints:

- `app_baseline.md` — primary editor execution queue for Notepad-grade app/editor behavior
- `editor_action_baseline_register.md` — action-centric baseline checklist with reference bindings from common editors
- `protocol.md` — text-engine and editing semantics queue after the common app baseline
- `stress_and_reference.md` — editor stress-testing and cross-reference comparison queue
- `treesitter.md` — tree-sitter query/highlight integration queue
- `treesitter_dynamic_roadmap.md` — dynamic grammar-pack rollout order
- `theme_import.md` — resolved-theme export/import and schema-pressure queue

Maintenance or supporting queues:

- `widget.md` — mostly widget-specific follow-up after the current app-baseline lane
- `modularization.md` — structural cleanup only when it keeps the feature lane clean or removes bad ownership

Do not treat this folder as architecture authority. Durable design ownership
lives under `app_architecture/editor/`.

Current editor architecture authority entrypoints:

- `app_architecture/editor/DESIGN.md`
- `app_architecture/editor/FFI_DESIGN.md`
- `app_architecture/editor/RESOLVED_THEME_EXPORT_CONTRACT.md`
- `app_architecture/editor/LSP_THEME_OVERLAY_BOUNDARY.md`
