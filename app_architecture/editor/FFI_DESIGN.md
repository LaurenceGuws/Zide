# Editor FFI Design

This doc is the current authority for the standalone editor FFI boundary.

Code:

- `src/editor/ffi/bridge.zig`
- `src/editor/ffi/c_api.zig`

## Purpose

The editor FFI exists so Zide's editor core can be reused outside the native
app shell.

It is not a widget bridge. It exports editor-core behavior:

- text mutation
- cursor/caret control
- undo/redo
- search/query operations
- string extraction

## Boundary Shape

### Native ownership

Inside the bridge, a handle owns:

- allocator
- grammar manager
- editor instance

That means the FFI boundary exports a complete editor-core instance, not just a
borrowed view over some host-owned state.

### C ABI surface

The exported C layer is intentionally flat:

- `zide_editor_create`
- `zide_editor_destroy`
- text set/insert/replace/delete
- undo-group begin/end
- cursor/caret getters and setters
- text allocation/free
- line count / total length
- search query / match / next / previous / replace

This is a behavior-oriented API, not a direct struct-ABI exposure of editor
internals.

## Ownership Rules

### Handle lifecycle

- host creates a handle with `zide_editor_create`
- host destroys it with `zide_editor_destroy`
- the bridge owns editor and grammar-manager teardown

### String ownership

- text-returning APIs allocate bridge-owned memory
- ownership is passed back through `StringBuffer`
- host must return that memory with `zide_editor_string_free`

The string ABI is versioned with `ZIDE_EDITOR_STRING_ABI_VERSION`.

## Current ABI Types

Bridge-owned exported types include:

- `ZideEditorHandle`
- `ZideEditorStringBuffer`
- `ZideEditorCaretOffset`
- `ZideEditorSearchMatch`
- `ZideEditorStatus`

Status model:

- `ok`
- `invalid_argument`
- `out_of_memory`
- `backend_error`

## Current Capability Surface

### Text operations

- set full text
- insert text at current caret(s)
- replace/delete byte ranges
- grouped undo editing

### Cursor and carets

- set cursor offset
- query primary caret offset
- query auxiliary caret count
- get auxiliary caret offsets
- clear selections
- set caret set from offsets

### Undo/redo

- undo
- redo
- explicit undo-group control

### Search

- set search query
- enumerate matches
- inspect active match
- move to next/previous match
- replace active match
- replace all matches

## Deliberate Non-Goals

The current editor FFI does not try to export:

- widget rendering or paint commands
- native app-shell prompts
- tab/session/app lifecycle
- Lua keybinding/config policy
- the full syntax/highlight publication graph

Those are different subsystem boundaries.

## Current Risks / Gaps

- the FFI surface is real, but its contract is still code-led more than doc-led
- ABI versioning is currently explicit for strings, but broader surface
  versioning policy is still thin
- search and caret operations are exported, but richer editor state snapshots are
  not yet formalized as a separate ABI
- there is no dedicated editor-FFI test/contract doc at the same maturity level
  as the terminal bridge docs yet

## Design Rules

- keep the exported API behavior-oriented
- do not leak internal editor struct layout across the boundary
- preserve explicit memory ownership for host-facing allocated results
- prefer adding focused exported operations over exposing broad mutable structs
- keep native-app routing concerns out of the editor FFI

## Relationship To Native App

The native app should use the same editor-core semantics that the FFI exports,
but it should not be forced through the FFI boundary internally.

That means:

- editor core remains the authority
- native app integration may call it directly
- external hosts use the FFI bridge

This is the same architectural direction as terminal:

- strong subsystem core
- app-specific routing outside the exported boundary
- explicit external-host contract when reuse matters
