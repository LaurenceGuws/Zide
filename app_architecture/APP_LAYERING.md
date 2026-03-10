# App Layering Split

Date: 2026-01-25

Goal: keep Zide’s major components loosely coupled and independently testable while preserving
the UI rendering stack defined in `app_architecture/ui/DEVELOPMENT_JOURNEY.md`.

## Target Components
1) **Text Engine (Zig)**
   - Pure text model + edit operations + undo/redo + syntax hooks.
   - No UI, no renderer, no platform IO.
2) **Terminal Backend (Zig)**
   - PTY + protocol + screen model + snapshot API.
   - No UI, no renderer.
3) **UI Terminal Widget**
   - Renders terminal snapshots + handles input, IME, selection, scroll.
4) **UI Editor Widget**
   - Renders editor view + handles input, selection, scroll, IME.
5) **Core App Logic**
   - Entry point, workspace state, cache, tooling, LSP, config.
6) **UI Shell**
   - Window lifecycle, global input dispatch, layout + docking + theme.

## Mode Layer Refocus (2026-03)

To support focused binaries with minimal coupling, mode orchestration is being split into three layers:

1) **Shared public mode layer** (`src/app/modes/shared/`)
   - Host-agnostic contracts, action DTOs, and lifecycle interfaces.
   - Must not depend on IDE composition details.
2) **Backend mode layer** (`src/app/modes/backend/`)
   - Concrete editor and terminal mode implementations.
   - Bridges shared contracts to current backend ownership (Editor/TerminalWorkspace/Session).
3) **IDE composition layer** (`src/app/modes/ide/`)
   - Thin assembly of backend modes for full IDE behavior.
   - IDE-specific policy only; no backend ownership logic.

### Mode-layer import constraints (authoritative)

`src/app/modes/shared/*`
- Allowed imports:
  - `std`
  - shared type/contract modules under `src/app/modes/shared/*`
  - shared stable types under `src/types/*`
- Forbidden imports:
  - `src/app/modes/backend/*`
  - `src/app/modes/ide/*`
  - `src/main.zig`
  - `src/ui/*` (including renderer/widgets)
  - `src/terminal/*`
  - `src/editor/*`

`src/app/modes/backend/*`
- Allowed imports:
  - `src/app/modes/shared/*`
  - backend runtime integrations needed for mode ownership:
    - `src/terminal/*`
    - `src/editor/*`
    - selected app host glue modules under `src/app/*` (non-IDE layer)
- Forbidden imports:
  - `src/app/modes/ide/*`
  - direct renderer/widget imports under `src/ui/widgets/*` and `src/ui/renderer.zig`
  - `src/main.zig` ownership logic

`src/app/modes/ide/*`
- Allowed imports:
  - `src/app/modes/shared/*`
  - `src/app/modes/backend/*`
  - IDE policy/assembly glue under `src/app/*`
- Forbidden imports:
  - direct `src/terminal/*` ownership dependencies
  - direct `src/editor/*` ownership dependencies
  - direct UI renderer/widget ownership dependencies

Review/enforcement policy:
- These constraints are mandatory during refactor slices even when not yet fully tool-enforced.
- `zig build check-app-imports` now includes explicit mode-layer boundary checks for `src/app/modes/shared`, `backend`, and `ide`.

Execution authority for this split is tracked in:
- `app_architecture/app_mode_layering_todo.yaml`

Regression policy for this split:
- Run compatibility gates after every extraction slice (unit + import checks + mode smokes + terminal replay).
- Do not proceed to the next layer slice when current-layer gates fail.
- Keep extraction-only semantics until compatibility matrix is stable.

## Current Anchors
- **Editor modularization plan**: `app_architecture/editor/MODULARIZATION_PLAN.md`.
- **Terminal modularization plan**: `app_architecture/terminal/MODULARIZATION_PLAN.md`.
- **Terminal API + layering rules**: `app_architecture/terminal/TERMINAL_API.md`.

## Layer Boundaries (import rules)
- **UI shell** → may import core app logic + widgets only.
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
- `zig build check-input-imports` now scans `src/input/` for forbidden imports.
- `zig build check-app-imports` now scans `src/ui/` (excluding widgets + renderer) for forbidden imports.

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
- UI editor widget
  - `src/ui/widgets/editor_widget*.zig`
  - `src/editor/view/*`
  - `src/editor/render/*`
- UI terminal widget
  - `src/ui/widgets/terminal_widget.zig`
- Core app logic
  - `src/main.zig`
  - `src/config/*`
  - `tools/*` (repo tooling only; not product/runtime modules)
- UI shell
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

Shared types entry point:
- `src/types/mod.zig` re-exports shared input/actions/layout/snapshot types.
- `EditorSnapshot.text_owned` indicates whether `text` must be freed by the caller.
- Terminal snapshots and render caches carry full grid state; widgets should treat these as immutable, per-frame view data.
- `InputBatch` now captures per-frame key/mouse state + text events and is used by main + widgets.
- Terminal hover state is updated during input handling; draw reads cached hover info.
- Top bars (options/tab/side/status) update hover state during input; draw uses cached state.

## Interface Contracts (initial targets — not fully implemented)
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

UI editor widget:
- `EditorWidget.draw(shell, snapshot, layout)` → draws only from snapshot.
- `EditorWidget.handleInput(shell, events, layout)` → returns `EditorWidgetActions` (scroll, cursor move, command intents).
- No direct mutation of `EditorSession` internals.

UI terminal widget:
- `TerminalWidget.draw(shell, snapshot, layout)` → draws only from snapshot.
- `TerminalWidget.handleInput(shell, events, layout)` → returns `TerminalWidgetActions` (input bytes, selection copy, open link).
- No direct mutation of `TerminalSession` internals.

Core app logic:
- Owns `EditorSession` + `TerminalSession` lifetimes and caches.
- Translates widget actions into engine/backend commands.
- Manages workspace + config + LSP + persistence.

UI shell:
- Owns window lifecycle + input polling + frame timing.
- Dispatches inputs to core; renders via widgets.
- Exposes `app_shell.Shell` surface only.
- CLI mode flag can launch IDE/editor/terminal-only shells (`--mode terminal|editor|ide`).

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
4) **Introduce an AppShell façade** to isolate `main.zig` from renderer/platform API calls.
5) **Add harnesses** for text engine + terminal backend to lock behavior (reuse existing terminal/editor harnesses).

## Non-goals
- No renderer work outside the UI journey plan.
- No feature changes without tests.
- No large file moves before baseline tests exist.
