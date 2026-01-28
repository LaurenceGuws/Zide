# Zide Performance Review (Dock/Layout)

Date: 2026-01-19 (status updated 2026-01-28)
Scope: UI layout/dock structure and redraw behavior, with a focus on responsiveness and CPU usage.

## Dock/Layout Structure (Current)
- Layout is a fixed vertical stack plus side nav:
  - Options bar (top)
  - Tab bar (below options)
  - Editor pane (center)
  - Terminal pane (bottom, optional; resizable by dragging separator)
  - Status bar (bottom overlay)
  - Side nav (left)
- Terminal is a bottom dock that reduces editor height; there is no split-pane manager beyond this.
- Draw order: options bar → tab bar → editor → terminal (if visible) → side nav → status bar.
- Terminal renders into a cached texture and re-renders only dirty rows (background + glyphs).

## Current Redraw Behavior
- Global `needs_redraw` drives full-frame redraw.
- Mouse actions (down, pressed, wheel) trigger redraw immediately.
- Mouse hover movement triggers redraw for non-terminal areas (throttled to 60 FPS); terminal hover movement is ignored to avoid full redraw.
- Terminal PTY polling happens only when data is available.

## Observed Hotspots / Risks
- Terminal renderer cost scales with dirty rows and glyph density; still heavy during full-screen updates.
- Any animation or continuous hover updates force a full frame redraw, including terminal.
- Terminal width is large (~190+ columns), so full redraw cost scales quickly with window size.
- Terminal resizing is handled in multiple code paths (window resize + drag), which can lead to frequent reflow.

## Recommendations (Priority Order)

### 1) Dirty-Row / Dirty-Rect Rendering for Terminal (DONE)
- Dirty rows are tracked and used to update the cached terminal texture.
- If scrollback offset is unchanged and no dirty rows are present, the terminal does not redraw.

### 2) Render-to-Texture Cache for Editor + Terminal (DONE)
- Terminal is cached in a texture and updated on dirty rows.
- Editor render-to-texture cache + dirty redraw are implemented (see ED-08).

### 3) Event-Driven Layout Invalidation
- Only recompute layout when:
  - window resized
  - terminal height changed
  - side nav width changed
- Avoid repeated layout arithmetic during idle frames.

### 4) Hover Invalidation Granularity
- Only mark redraw when hover state changes (enter/exit), not every pixel movement.
- Maintain per-widget hover state and use edge detection to reduce redraw requests.
  - We already started this by ignoring hover-only mouse movement over the terminal region since it has no hover UX; this reduced CPU spikes and validates the approach.

### 5) Terminal Input + Polling
- PTY polling is gated by `hasData()` (non-blocking).
- Read thread path still wakes on data; deeper event-driven wakeups remain optional.

### 6) Resize Throttling
- Debounce terminal resize while dragging (e.g., apply every N ms) to avoid excessive reflow.
- Keep a “pending size” and apply on drag end to reduce per-move recalculation.

## Suggested Next Actions
1) Add per-widget hover state tracking to limit redraw invalidations.
2) Consider partial-column damage to reduce overdraw for row-local edits.
3) Debounce terminal resize while dragging (apply pending size on drag end).

## Terminal Scrollback Status
- Scrollback is captured when the full screen scrolls and is exposed via a right-side scrollbar with drag and wheel support.
- Scrollback is cleared on column resize.

## Scrollback Next Steps
1) Add selection/copy behavior in scrollback view.
2) Add visual indicators for “scrolled back” state and quick-jump to live output.
3) Ensure scrollback is preserved across resize where possible (optional reflow strategy).

## Notes
- The bottom dock layout is simple and stable; performance issues stem primarily from redraw policy, not the layout structure itself.
- With dirty rendering or caching in place, hover and lightweight animations will be safe even with terminal visible.
