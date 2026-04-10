# UI Work Queues

This folder holds active UI and renderer implementation queues.

Use it for:

- renderer backend abstraction execution
- widget modularization
- font-rendering execution work
- terminal-specific UI polish lanes

Current high-signal entrypoints:

- `renderer.md` — active renderer contract execution board, including review
  chunks and stop markers
- `rendering_scrutiny.md` — supporting SDL3/OpenGL renderer-center scrutiny queue
- `window_scale_geometry.md` — active app-wide scale/geometry ownership lane
- `terminal_special_glyphs.md` — sprite/special-glyph quality lane
- `font_rendering.md` — remaining text-rendering quality work

Maintenance or supporting queues:

- `widget_modularization.md` — mostly-complete extraction queue with a few remaining boundary/verification items
- `terminal_ligatures.md` — focused future quality lane, not active baseline hardening

Durable UI architecture and rendering direction live under
`app_architecture/ui/`.
