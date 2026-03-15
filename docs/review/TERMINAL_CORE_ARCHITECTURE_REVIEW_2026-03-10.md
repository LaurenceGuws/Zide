# Terminal Core Architecture Review

Date: 2026-03-10

## Scope

This review re-ranks Zide's remaining terminal-core architectural issues after the
repo-structure cleanup lane. It focuses on:

1. VT core ownership
2. FFI-first embeddability
3. transport/PTY separation
4. renderer/snapshot boundary quality

Reference baselines used:

- `reference_repos/terminals/ghostty/include/ghostty/vt.h`
- `reference_repos/terminals/ghostty/src/terminal/Terminal.zig`
- `reference_repos/terminals/ghostty/src/terminal/Screen.zig`
- `reference_repos/terminals/ghostty/src/input/key_encode.zig`
- `reference_repos/terminals/kitty/kitty/vt-parser.c`
- `reference_repos/terminals/kitty/kitty/screen.c`
- `reference_repos/terminals/foot/vt.c`
- `reference_repos/terminals/foot/terminal.c`

## Main Conclusion

Zide is no longer blocked by parser spaghetti or random helper sludge.

The main remaining problem is architectural center of gravity:

- Zide still centers terminal emulation around `TerminalSession`
- Ghostty centers terminal emulation around a terminal engine

That is the real gap now.

The useful lesson from `libghostty-vt` is not "copy the current C ABI surface."
The useful lesson is: make terminal emulation the product, and make PTY/UI/FFI
consumers sit around it.

Nuance after the recent FFI/core work:

- Zide is no longer obviously behind on host-facing contract richness.
- In some ways it is ahead of Ghostty's current public C umbrella:
  - explicit snapshot export
  - metadata latest-state export
  - redraw/publication acknowledgement
  - backend-owned viewport control
  - external transport input/output seams
- The remaining Ghostty advantage is still the more obvious engine-first center
  of gravity, not a strictly broader public host ABI.

## What Ghostty Gets Right

### 1. The engine is obviously the engine

Ghostty's center is:

- `reference_repos/terminals/ghostty/src/terminal/Terminal.zig`
- `reference_repos/terminals/ghostty/src/terminal/Screen.zig`

That layer owns:

- screen sets
- scrollback
- modes
- colors
- cursor and tabstops
- protocol behavior
- terminal state transitions

It reads as a terminal emulator, not as a host session wrapper.

### 2. Input encoding is a peer subsystem

`reference_repos/terminals/ghostty/src/input/key_encode.zig` is clearly
separate from renderer and session/runtime concerns. It consumes terminal mode
state but is not structurally owned by a session object.

### 3. Rendering consumes terminal state from outside

Ghostty's renderer is not the owner of terminal core logic. The renderer reads
terminal state. The terminal core does not become a UI/session abstraction.

### 4. The public ABI is being extracted as clean sub-libraries

The current local `libghostty-vt` umbrella header is still narrow and evolving,
but the extraction direction is strong:

- small embeddable VT-oriented modules
- narrow C ownership contracts
- no requirement to embed a GUI/session object to consume useful terminal logic

## Zide's Remaining Core Problems

Status note after the recent `TerminalCore` and FFI cleanup wave:

- This review is still directionally right, but some of the older wording now
  overstates how much raw VT semantics still live on `TerminalSession`.
- The stronger remaining gap today is more specifically runtime/publication
  center-of-gravity around:
  - `src/terminal/core/session_runtime.zig`
  - `src/terminal/core/session_rendering.zig`
  - `src/terminal/core/session_rendering_retirement.zig`
- `TerminalSession` is still heavy, but increasingly as the assembly shell
  around those lanes rather than as the place where the core semantics
  themselves still primarily live.

### 1. `TerminalSession` is still the real kernel

Primary file:

- `src/terminal/core/terminal_session.zig`

It still owns too much at once:

- PTY lifecycle
- parser state
- primary/alt screens
- history
- input mode state
- OSC state
- kitty state
- render publication
- threads and locks
- host-facing query APIs
- FFI-facing behavior

Even after good extraction work, the architecture is still session-shaped, not
terminal-engine-shaped. The most important remaining reason is no longer
"random VT behavior still lives in the root session type"; it is that runtime
and publication ownership are still centered around the session side of the
boundary.

### 2. The model layer is not authoritative enough

Relevant files:

- `src/terminal/model/screen/screen.zig`
- `src/terminal/model/history.zig`
- `src/terminal/model/selection_semantics.zig`
- `src/terminal/model/scrollback.zig`

These modules exist and are cleaner than before, but too much mutation and
policy still routes through `src/terminal/core/session_*` helpers instead of a
single core terminal owner over model state.

### 3. Protocol still executes against session services

Relevant files:

- `src/terminal/protocol/csi.zig`
- `src/terminal/protocol/csi_exec.zig`
- `src/terminal/protocol/csi_mode_mutation.zig`
- `src/terminal/protocol/csi_mode_query.zig`
- `src/terminal/protocol/csi_reply.zig`
- `src/terminal/core/parser_hooks.zig`
- `src/terminal/core/session_protocol.zig`

The typed seam work materially improved quality, but this is no longer as
strong a hotspot as the original review implied. Recent work moved substantial
parser/reset/selection/OSC ownership behind `TerminalCore`, so protocol-target
cleanup is now more of a residue lane than the main structural gap.

### 4. FFI is still session-backed, not core-backed

Relevant files:

- `src/terminal/ffi/bridge.zig`
- `src/terminal/ffi/c_api.zig`
- `src/terminal/core/terminal.zig`

The embeddable API is still structurally tied to the session/backend shape. For
`cwatch` and other consumers, that is the wrong long-term center.

The desired center is:

- terminal emulation core
- stable snapshot/damage query surface
- input encoding
- host transport hooks

### 5. PTY and external transport are not first-class peers yet

Relevant files:

- `src/terminal/core/session_runtime.zig`
- `src/terminal/core/pty_io.zig`
- `src/terminal/io/pty.zig`
- `src/terminal/io/pty_unix.zig`
- `src/terminal/io/pty_windows.zig`

Desktop PTY ownership is well developed, but the architecture still assumes
session-owned runtime assembly as the center. Transport itself is now more real
than this older section implied; the stronger remaining issue is that
`session_runtime.zig` still owns thread lifecycle, parse/read loop assembly,
PTY/external switching, and child-exit truth assembly around that transport
split.

This matters directly for:

- Flutter embedding
- mobile SSH-style hosts
- externally supplied byte streams and resize signals

### 6. Snapshot/render publication is still heavier than ideal

Relevant files:

- `src/terminal/core/snapshot.zig`
- `src/terminal/core/render_cache.zig`
- `src/terminal/core/view_cache.zig`
- `src/terminal/core/session_rendering.zig`

The current publication pipeline works, but it still reads like session/cache
choreography rather than a clean terminal snapshot contract consumed by
renderers. This has become one of the strongest remaining architectural gaps:
`session_rendering.zig` and `session_rendering_retirement.zig` still own
published/presented generation bookkeeping, render-cache handoff, view-cache
update sequencing, and sync-update publication behavior.

## Re-ranked Hotspots

Ordered by architectural impact:

1. runtime ownership in `src/terminal/core/session_runtime.zig`
2. publication/present ownership in `src/terminal/core/{session_rendering,session_rendering_retirement,view_cache,render_cache}.zig`
3. `src/terminal/core/terminal_session.zig` as the remaining assembly shell
4. FFI/session/core boundary in `src/terminal/ffi/*` and `src/terminal/core/terminal.zig`
5. protocol residue in `src/terminal/protocol/*` and `src/terminal/core/parser_hooks.zig`

## Target Architecture

### A. VT Core

Owns:

- parser feed + protocol execution
- screen state
- scrollback/history
- selection semantics
- terminal modes
- OSC/CSI/DCS/APC behavior
- input encoding options derived from terminal state
- damage/snapshot generation

Does not own:

- PTY
- UI widget code
- renderer
- workspace/tab management
- app runtime

### B. Transport Layer

Owns:

- optional PTY integration
- read/write pumping
- child lifecycle
- host resize delivery
- external stream/socket adapters

This must support both:

- desktop PTY-backed sessions
- externally supplied transports for Flutter/mobile/SSH-style hosts

### C. Snapshot Interface

Owns:

- stable frame/snapshot contract
- damage regions
- cursor/style metadata
- selection state
- kitty image placement metadata that renderers can consume

This should be renderer-agnostic and FFI-friendly.

### D. FFI Layer

Must be first-class, not accidental.

It should expose:

- core lifecycle
- feed bytes
- encode/send input
- resize
- snapshot/damage access
- optional transport callbacks/hooks

It should not require consumers to adopt Zide desktop session structure.

### E. Host Session

`TerminalSession` should become one host implementation, not the engine.

Its future role should be closer to:

- desktop session glue
- PTY-backed host runtime
- thread/poll integration
- UI-facing convenience wrapper

Not:

- the terminal core itself

## Practical Direction

The next step is not to rewrite everything at once.

The next step is to define a new core boundary and begin moving ownership
toward it in behavior-preserving slices.

That work is tracked in:

- `docs/todo/terminal/vt_core_rearchitecture.md`
