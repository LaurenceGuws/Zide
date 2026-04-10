# Decision Log

Scope note, 2026-03-15:

- This file is a lightweight historical/high-level decision log, not an
  exhaustive architecture authority.
- Current subsystem authority lives in the owning docs under
  `app_architecture/terminal/`, `app_architecture/ui/`, and related active
  plans/todos.
- Review-era and investigation-specific material should live under
  `docs/review/` or subsystem research folders instead of being
  appended here as transient session notes.

## 2026-01-15 — Compositor-aware mouse scaling on Wayland

**Context**
Wayland fractional scaling (e.g., Hyprland scale 1.6) produced mismatched input coordinates in the old pre-SDL3 renderer path. The old fallback could report a scale of 1.0 while render/screen dimensions still matched, so the usual `render/screen` correction could not detect compositor scale.

**Decision**
Add a compositor-aware scaling helper with a small abstraction layer. Start with:
- **Hyprland:** query `hyprctl -j monitors` and parse `scale` for the active monitor.
- **KDE:** use `kscreen-doctor` (preferred) as the compositor-specific source.

Use the platform/renderer-provided scale path directly. Do not preserve
environment-based mouse-scale escape hatches from the pre-SDL3 workaround era.

**Consequences**
- Accurate mouse hit-testing on fractional scaling without hardcoding a global scale.
- Requires optional external tools (`hyprctl`, `kscreen-doctor`) when running on those compositors.
- Adds a small platform detection layer with clear fallbacks.

**Status**
- Resolved by the SDL3 + OpenGL renderer migration (January 28, 2026). The compositor-based scale fallback remains as a safety net for fractional Wayland setups.

## 2026-01-15 — Terminal text rendering quality upgrade path

**Context**
Terminal text rendering uses a custom FreeType/HarfBuzz glyph cache with integer grid snapping and a Linux fontconfig fallback path. LCD/gamma rendering and full grapheme shaping are still pending.

**Decision**
Pursue a terminal-first text pipeline upgrade (UI/editor later). The goal is best-in-class terminal font rendering (Kitty/Alacritty/WezTerm quality). Allow separate fonts for terminal, editor, app text, and icons. Implement improvements incrementally, starting with grid snapping and rasterization quality before adding shaping and fallback.

**Consequences**
- Terminal rendering will become more complex but closer to Kitty/Alacritty quality.
- Rendering config will include multiple font paths and per-layer settings.

## 2026-01-17 — Lua config POC for logging only

**Context**
We want a simple, extensible configuration mechanism like Neovim’s Lua config, but without committing to a full API surface yet. Logging needs a per-component toggle to keep debug output manageable.

**Decision**
Introduce a minimal Lua config loader that only reads logging configuration. The config file should return a table, and `log.enable` can be a list (or `log` can be a string like `all`/`none`). Support per-destination filters (`log.file` and `log.console`). Load order: `assets/config/init.lua` defaults, then user config, then `.zide.lua` overrides.

**Consequences**
- Keeps risk low while establishing the Lua embedding path.
- Allows per-component logging via config or `ZIDE_LOG` fallback.
- The Lua runtime is now a build dependency (system `lua5.4`).
