# App Layering Split

Date: 2026-01-25

Goal: keep Zide’s major components loosely coupled and independently testable while preserving
current Raylib-based rendering.

## Target Components
1) **Text Engine (Zig)**
   - Pure text model + edit operations + undo/redo + syntax hooks.
   - No UI, no Raylib, no platform IO.
2) **Terminal Backend (Zig)**
   - PTY + protocol + screen model + snapshot API.
   - No UI, no Raylib.
3) **Raylib Terminal Widget**
   - Renders terminal snapshots + handles input, IME, selection, scroll.
4) **Raylib Editor Widget**
   - Renders editor view + handles input, selection, scroll, IME.
5) **Core App Logic**
   - Entry point, workspace state, cache, tooling, LSP, config.
6) **Raylib IDE Shell**
   - Window lifecycle, global input dispatch, layout + docking + theme.

## Current Anchors
- **Editor modularization plan**: `app_architecture/editor/MODULARIZATION_PLAN.md`.
- **Terminal modularization plan**: `app_architecture/terminal/MODULARIZATION_PLAN.md`.
- **Terminal API + layering rules**: `app_architecture/terminal/TERMINAL_API.md`.

## Layer Boundaries (import rules)
- **Raylib IDE shell** → may import core app logic + widgets only.
- **Core app logic** → may import text engine + terminal backend (and shared types) only.
- **Editor widget** → may import editor view/core/render helpers only (no terminal core).
- **Terminal widget** → may import terminal core + snapshot types only (no editor core).
- **Text engine** → may not import UI or platform code.
- **Terminal backend** → may not import UI or editor code.
- **Main entry** should use `src/app_shell.zig` instead of importing `src/ui/renderer.zig` directly.
- **Renderer** (`src/ui/renderer.zig`) must not import terminal core code.

AppShell interface:
- `src/app_shell.zig` exposes a narrow `Shell` surface (init/draw/input accessors).

Enforcement:
- `zig build check-app-imports` (widget cross-imports + main/renderer boundary guard).

## Proposed Module Map (incremental)
- Text engine
  - `src/editor/rope.zig`
  - `src/editor/text_store.zig`
  - `src/editor/editor.zig`
  - `src/editor/syntax.zig`
  - `src/editor/types.zig`
- Terminal backend
  - `src/terminal/core/*`
  - `src/terminal/model/*`
  - `src/terminal/protocol/*`
  - `src/terminal/io/*`
- Raylib editor widget
  - `src/ui/widgets/editor_widget*.zig`
  - `src/editor/view/*`
  - `src/editor/render/*`
- Raylib terminal widget
  - `src/ui/widgets/terminal_widget.zig`
- Core app logic
  - `src/main.zig`
  - `src/config/*`
  - `src/tools/*`
- Raylib IDE shell
  - `src/ui/renderer.zig`
  - `src/ui/*` (excluding widgets)
  - `src/platform/*`

## Minimal API Surfaces (directional)
- Text engine
  - `EditorSession` (commands, undo/redo, diagnostics, syntax hooks)
  - `EditorSnapshot` (immutable, render-ready view data)
- Terminal backend
  - `TerminalSession` (PTY lifecycle, input, resize)
  - `TerminalSnapshot` (immutable, render-ready grid + attrs)
- Widgets
  - Accept snapshots + input events; return actions for core app (open file, spawn terminal, etc.).

## Interface Contracts (initial targets)
Text engine (pure Zig):
- `EditorSession.init(allocator, grammar_manager)` → owns text + undo + syntax state.
- `EditorSession.apply(EditCommand)` → returns `EditResult` (dirty ranges, selection changes).
- `EditorSession.snapshot(viewport)` → `EditorSnapshot` (text slices, tokens, cursor/selection, gutters).
- `EditorSession.serialize/deserialize` → for cache + session restore.

Terminal backend (pure Zig):
- `TerminalSession.init(allocator, shell_cmd, env)` → owns PTY + protocol state.
- `TerminalSession.apply(InputEvent)` → returns `TerminalActions` (bell, title change, open path).
- `TerminalSession.resize(cols, rows)` → returns `ResizeResult` (needs redraw, scrollback trims).
- `TerminalSession.snapshot(viewport)` → `TerminalSnapshot` (cells, attrs, cursor, selections).

Raylib editor widget:
- `EditorWidget.draw(shell, snapshot, layout)` → draws only from snapshot.
- `EditorWidget.handleInput(shell, events, layout)` → returns `EditorWidgetActions` (scroll, cursor move, command intents).
- No direct mutation of `EditorSession` internals.

Raylib terminal widget:
- `TerminalWidget.draw(shell, snapshot, layout)` → draws only from snapshot.
- `TerminalWidget.handleInput(shell, events, layout)` → returns `TerminalWidgetActions` (input bytes, selection copy, open link).
- No direct mutation of `TerminalSession` internals.

Core app logic:
- Owns `EditorSession` + `TerminalSession` lifetimes and caches.
- Translates widget actions into engine/backend commands.
- Manages workspace + config + LSP + persistence.

Raylib IDE shell:
- Owns window lifecycle + input polling + frame timing.
- Dispatches inputs to core; renders via widgets.
- Exposes `app_shell.Shell` surface only.

## Data Flow (directional)
- Input → IDE shell → core app → (session apply) → snapshot → widget draw.
- Widgets emit action intents; core decides and mutates sessions.
- Snapshots are immutable and owned by core app (widgets treat as read-only).

## Ownership + Lifecycle
- Core app owns all long-lived state (sessions, caches, tools).
- Widgets are ephemeral views; no persistent state beyond UI affordances (hover, drag, local cache).
- App shell owns rendering resources; widgets must not retain renderer handles.

## Event + Action Types (sketch)
- `InputEvent` (key, mouse, scroll, text) from shell to core.
- `EditorWidgetActions` (edit intent, selection intent, scroll intent).
- `TerminalWidgetActions` (pty input bytes, selection copy, open-link intent).

## Migration Steps (small, testable)
1) **Codify import rules** in a single document (this file) and align per-module checks.
2) **Add core → widget boundaries** by introducing snapshot types and reducing direct data access.
3) **Pull shared UI-agnostic types** into `src/types/` (if needed) to avoid cyclic imports.
4) **Introduce an AppShell façade** to isolate `main.zig` from Raylib API calls.
5) **Add harnesses** for text engine + terminal backend to lock behavior (reuse existing terminal/editor harnesses).

## Non-goals
- No renderer swap.
- No feature changes without tests.
- No large file moves before baseline tests exist.
