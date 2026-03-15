# UI Work Queues

This folder holds active UI and renderer implementation queues.

Use it for:

- renderer modularization and OS abstraction execution
- widget modularization
- font-rendering execution work
- SDL3 migration cleanup
- terminal-specific UI polish lanes

Current high-signal entrypoints:

- `renderer.md` — renderer boundary and modularization queue
- `widget_modularization.md` — widget extraction/execution queue
- `font_rendering.md` — font-rendering execution work
- `terminal_special_glyphs.md` — sprite/special-glyph quality lane

Durable UI architecture and rendering direction live under
`app_architecture/ui/`.
