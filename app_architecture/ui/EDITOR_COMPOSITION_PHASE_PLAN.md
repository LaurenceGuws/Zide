# Editor Composition Phase Plan

Purpose: define the narrow editor-side renderer gate-5 cut after chrome-band
and terminal overlay/progress composition were separated.

This is editor-owned composition work. It does not change editor behavior or
try to redesign the editor renderer.

## Goal

Keep editor row/base/overlay immediate paths behind the existing editor
row-band owner instead of letting segment paint and widget draw code reach
directly into renderer surface/text hosts.

## Scope

Initial scope:

- editor pane/base immediate helper calls
- editor row/base immediate helper calls
- search overlay rects
- text decoration rects
- composing underline and editor scrollbar flush handoff

Non-goals:

- no editor render-cache redesign
- no semantic change to selection/search/cursor drawing
- no terminal renderer changes
- no Android backend bootstrap

## Current Checkpoint (2026-04-11)

- `segment_paint.zig` no longer imports renderer surface/text hosts directly
- immediate editor pane/row/search helpers route through
  `editor_widget_draw_overlay.zig`
- text-decoration rects and composing underline route through the same editor
  overlay owner
- explicit surface-flush handoffs now call the editor overlay owner instead of
  raw renderer surface flushes from unrelated editor draw files

## Next Pressure

The remaining scanned direct draw pressure is now mostly:

- direct renderer calls inside `editor_widget_draw_overlay.zig`, which is the
  current editor overlay/row-band owner
- common tooltip overlay composition
- lower-level editor text emission, which still needs a separate text-specific
  design if it becomes the next blocker
