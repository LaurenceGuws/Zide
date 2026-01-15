# Decision Log

## 2026-01-15 — Compositor-aware mouse scaling on Wayland

**Context**
Wayland fractional scaling (e.g., Hyprland scale 1.6) produces mismatched input coordinates when using raylib/GLFW. `GetWindowScaleDPI()` often reports 1.0, and `GetScreenWidth/Height` == `GetRenderWidth/Height`, so the usual `render/screen` correction cannot detect the scale.

**Decision**
Add a compositor-aware scaling helper with a small abstraction layer. Start with:
- **Hyprland:** query `hyprctl -j monitors` and parse `scale` for the active monitor.
- **KDE:** use `kscreen-doctor` (preferred) as the compositor-specific source.

Use this compositor-provided scale as the default mouse scale on Wayland. Keep `ZIDE_MOUSE_SCALE` as an override/escape hatch.

**Consequences**
- Accurate mouse hit-testing on fractional scaling without hardcoding a global scale.
- Requires optional external tools (`hyprctl`, `kscreen-doctor`) when running on those compositors.
- Adds a small platform detection layer with clear fallbacks.
