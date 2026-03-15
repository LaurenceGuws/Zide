# UI Work Queues

This folder holds active UI and renderer implementation queues.

Use it for:

- renderer modularization and OS abstraction execution
- widget modularization
- font-rendering execution work
- SDL3 migration cleanup
- terminal-specific UI polish lanes

Current high-signal entrypoints:

- `terminal_special_glyphs.md` — sprite/special-glyph quality lane
- `font_rendering.md` — remaining text-rendering quality work

Maintenance or supporting queues:

- `renderer.md` — mostly-complete renderer modularization with a small remaining maintenance tail
- `widget_modularization.md` — mostly-complete extraction queue with a few remaining boundary/verification items
- `sdl3_migration.md` — effectively closed except for small cleanup residue
- `terminal_ligatures.md` — focused future quality lane, not active baseline hardening

Durable UI architecture and rendering direction live under
`app_architecture/ui/`.
