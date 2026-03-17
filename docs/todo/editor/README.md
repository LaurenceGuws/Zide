# Editor Work Queues

This folder holds active editor implementation queues.

Use it for:

- widget/features execution
- text-engine and editing semantics follow-up
- modularization and boundary cleanup
- tree-sitter and grammar-pack rollout work

Current priority order:

- Notepad-grade editor usability and basic editor-only chrome first
- editor config / CLI friendliness as part of that baseline
- modularization only where it keeps the feature work clean or removes bad ownership
- optimization and reference-repo comparison after the common editor feature baseline lands

Current high-signal entrypoints:

- `widget.md` — editor widget/features queue
- `protocol.md` — text-engine and editing semantics queue
- `modularization.md` — editor modularization and boundary cleanup
- `treesitter.md` — tree-sitter integration queue
- `treesitter_dynamic_roadmap.md` — dynamic grammar-pack rollout order

Durable editor architecture lives under `app_architecture/editor/`.
