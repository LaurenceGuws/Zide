# Decision Log

## 2026-01-15 — Compositor-aware mouse scaling on Wayland

**Context**
Wayland fractional scaling (e.g., Hyprland scale 1.6) produces mismatched input coordinates when using raylib/GLFW. `GetWindowScaleDPI()` often reports 1.0, and `GetScreenWidth/Height` == `GetRenderWidth/Height`, so the usual `render/screen` correction cannot detect the scale. This is a legacy constraint until the SDL2-based UI stack described in `app_architecture/ui/DEVELOPMENT_JOURNEY.md` replaces raylib.

**Decision**
Add a compositor-aware scaling helper with a small abstraction layer. Start with:
- **Hyprland:** query `hyprctl -j monitors` and parse `scale` for the active monitor.
- **KDE:** use `kscreen-doctor` (preferred) as the compositor-specific source.

Use this compositor-provided scale as the default mouse scale on Wayland. Keep `ZIDE_MOUSE_SCALE` as an override/escape hatch.

**Consequences**
- Accurate mouse hit-testing on fractional scaling without hardcoding a global scale.
- Requires optional external tools (`hyprctl`, `kscreen-doctor`) when running on those compositors.
- Adds a small platform detection layer with clear fallbacks.

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
