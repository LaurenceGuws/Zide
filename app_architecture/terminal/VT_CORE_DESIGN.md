# VT Core Design

Date: 2026-03-10

Purpose: define the exact ownership split for the next terminal-core redesign
lane so code changes do not drift between "session cleanup", "FFI cleanup", and
"embed-friendly cleanup".

This doc is the concrete follow-up to:

- `app_architecture/review/TERMINAL_CORE_ARCHITECTURE_REVIEW_2026-03-10.md`
- `app_architecture/terminal/vt_core_rearchitecture_todo.yaml`

## Main Goal

Turn Zide's terminal backend into a real embeddable VT engine with:

- a pure terminal emulation core
- a first-class FFI boundary
- transport-agnostic host integration
- renderer-agnostic snapshots and damage

Desktop PTY-backed Zide remains a supported host, but it must stop defining the
architectural center.

## Target Types

### 1. `TerminalCore`

This becomes the engine-owned center.

It owns:

- parser state
- protocol execution
- primary/alt screens
- history/scrollback
- selection semantics
- terminal modes
- OSC/CSI/DCS/APC state
- kitty graphics state
- title/cwd/semantic prompt/backend metadata that belongs to terminal semantics
- damage generation
- snapshot generation

It does not own:

- PTY
- host threads
- workspace tabs
- SDL/widget/render state
- process lifecycle policy

Expected direction:

- `src/terminal/core/terminal_session.zig` stops being the owner of the above
- the future public engine center should live under `src/terminal/core/` or
  `src/terminal/engine/`

### 2. `TerminalTransport`

This is the byte-stream boundary around the core.

It owns host-specific delivery of:

- input bytes into the terminal
- output bytes from the host side into the core
- resize notifications
- host lifecycle/wakeup integration

There should be multiple implementations:

- PTY transport
- external transport adapter
- test/replay transport

This is the key requirement for:

- Flutter hosts
- mobile SSH-backed sessions
- non-PTY embedded environments

`TerminalTransport` should not own terminal semantics. It only moves bytes and
host signals.

### 3. `PtyTerminalSession`

This is the desktop-host runtime wrapper.

It owns:

- PTY creation/start/stop
- read/write pumping
- child exit observation
- optional threads
- host polling and pressure hints

It wraps:

- `TerminalCore`
- one PTY transport implementation

This is the likely future role of today's `TerminalSession`.

### 4. `TerminalSnapshot`

This remains renderer-agnostic and becomes more explicitly core-owned.

It should expose:

- rows/cols
- flat cell state
- cursor state
- damage summary
- title/cwd metadata needed by hosts
- selection state needed by hosts/renderers
- kitty image placement metadata needed by renderers

The snapshot contract should be valid for:

- SDL/OpenGL renderer
- Flutter renderer
- FFI consumers
- replay/test tooling

### 5. `TerminalInputEncoder`

This remains a peer subsystem.

It consumes:

- terminal mode state
- key/mouse/text events

It emits:

- encoded terminal input bytes

It should be usable:

- from PTY-backed desktop hosts
- from FFI hosts
- without pulling in session/runtime code

## Ownership Map

### Core-owned behavior

These behaviors must move toward `TerminalCore` ownership:

- parser feed
- protocol dispatch
- screen mutation
- history/scrollback mutation
- selection mutation semantics
- alt-screen behavior
- terminal mode state
- protocol-triggered title/cwd/clipboard metadata
- kitty graphics protocol state
- snapshot generation

### Host/runtime-owned behavior

These must stay outside the core:

- PTY open/start/stop
- thread creation
- child process shutdown
- desktop polling cadence
- workspace tab management
- SDL widget gesture orchestration
- GPU upload policy

### Shared boundary behavior

These must be explicit contracts:

- feed terminal output bytes into the core
- request encoded input bytes from host events
- consume snapshots and damage
- drain host-visible events
- resize core state

## Event Model

The core should own a narrow event queue for host-visible state changes.

Candidate core-visible events:

- title changed
- cwd changed
- clipboard write request
- bell
- child exit observed by host wrapper
- wake/dirty

Important distinction:

- `bell`, `title`, `cwd`, `clipboard` are terminal/core-facing semantics
- `child exit` is host/runtime-facing and may be injected into the same exported
  event stream by a host wrapper

## FFI Direction

The current `zide_terminal_ffi.h` surface is still effectively session-backed.

Future shape:

### Core-facing operations

- create/destroy core-backed handle
- feed output bytes
- resize
- encode/send key/mouse/text
- snapshot acquire/release
- scrollback acquire/release
- event drain/free
- state getters

### Optional host/runtime operations

- create PTY-backed host session
- start child
- poll runtime
- query child exit

This should become two layers in the API model even if they are initially
exported from one shared library:

- core API
- optional PTY host API

That keeps Flutter and mobile consumers from depending on PTY/session semantics
they do not need.

### 2026-03-10 first internal split

The first code cut for that FFI direction is now landed:

- shared terminal FFI ABI types, handle state, event/string helpers, and
  glyph-class metadata helpers live in `src/terminal/ffi/shared.zig`
- PTY-host/runtime-facing operations live in `src/terminal/ffi/host_api.zig`
- core-facing snapshot/scrollback/metadata/event/text-export operations live in
  `src/terminal/ffi/core_api.zig`
- `src/terminal/ffi/bridge.zig` is now a thin facade over `core_api` +
  `host_api`

The exported C ABI is unchanged in this slice. The gain is internal ownership:
host/runtime operations are no longer mixed inline with snapshot/scrollback/
metadata/event export logic in one large bridge implementation.

### 2026-03-10 no-PTY transport-backed FFI feed path

The first non-PTY transport shape is now also landed internally:

- `src/terminal/core/terminal_transport.zig` now has an in-memory external
  transport implementation alongside the PTY-backed transport facade
- FFI-created terminal sessions attach that external transport by default
- `zide_terminal_feed_output(...)` now enqueues bytes into that transport and
  runs the normal session poll path, instead of bypassing backend transport
  ownership through a direct parser-only shortcut

This keeps the no-PTY host path closer to the future embed/mobile shape while
preserving the existing exported FFI API.

That path is now also core-tested:

- terminal session tests cover external transport enqueue/poll
- metadata/aliveness are asserted through the same core session surface used by
  other hosts
- external transport now has an explicit "closed" state instead of only
  "attached vs detached"

It is also no longer FFI-only:

- the replay harness now uses external transport for normal non-reply fixtures
- PTY attachment remains only for the reply-capture subset that genuinely needs
  a writable transport sink
- higher-level callers now go through `TerminalSession` host-wrapper methods for
  external transport attach/enqueue/close instead of reaching into
  `terminal_transport` directly for that path
- reply-capture PTY attachment in the replay harness now also goes through
  `TerminalSession` host-wrapper methods instead of raw transport assembly
- at this point higher-level setup callers no longer need raw
  `terminal_transport.attach*/detach*` for normal session assembly paths

The external-host lifecycle contract also moved forward:

- terminal FFI now exposes `zide_terminal_close_input(...)` for no-PTY hosts
  that want to signal end-of-stream without destroying the terminal
- the derived event contract now includes `alive_changed`
- the mock-service Python smoke now validates that closing external input:
  - flips metadata `alive` to false
  - emits an `alive_changed` event
  - preserves snapshot readability for final rendered content

Embedded-host wake semantics also moved forward:

- the derived terminal event stream now emits `redraw_ready` whenever terminal
  snapshot generation advances
- this gives non-PTY hosts a minimal "pull snapshot now" wake signal without
  inventing a second damage model in the FFI layer
- damage and generation still remain authoritative in snapshot acquisition;
  `redraw_ready` is only a scheduling hint for host event loops
- host-side `resize(...)` now also goes through that derived wake path, so
  PTY-backed foreign hosts and no-PTY embedded hosts both get an immediate
  redraw signal after visible size changes

This matches the general shape used by stronger reference terminals:

- Ghostty's termio/renderer split wakes the renderer after stream-handling and
  mailbox publication, not just at process start
- Alacritty marks the terminal/window dirty and requests redraw after actual
  visible-state changes, especially resize and PTY-driven updates

So the current Zide FFI direction is:

- no synthetic wake on `start(...)` alone
- wake on visible-state transitions such as streamed output, poll-driven PTY
  updates, and resize

The `TerminalSession` root also shed another non-runtime owner:

- the input-mode query/toggle surface now routes through
  `src/terminal/core/session_interaction.zig`
- the root session facade still exports the same API, but it no longer carries
  that interaction/mode-management block inline

Protocol execution also moved another step toward core ownership:

- saved-cursor restore and alt-screen core state transitions now live behind
  `src/terminal/core/terminal_core_modes.zig`
- `session_protocol.zig` now only layers the remaining session-owned side
  effects around that core transition, such as selection clearing and input
  snapshot publication
- RIS/reset core mutation now also lives behind
  `src/terminal/core/terminal_core_reset.zig`, with `session_protocol.zig`
  keeping only the session-owned input-mode snapshot republish step
- hyperlink allocation, kitty image clearing, and scroll-region mutation now
  also live behind `src/terminal/core/terminal_core_protocol.zig`, leaving
  `session_protocol.zig` closer to a session-owned publication/selection wrapper
  instead of another mixed core-mutation owner
- the remaining session-owned alt-screen/reset side effects now also live in
  `src/terminal/core/session_mode_effects.zig`, making those selection/input-
  snapshot/presentation consequences explicit instead of leaving them embedded
  inline in `session_protocol.zig`
- alt-screen exit presentation timing now also routes through
  `src/terminal/core/session_rendering.zig`, so mode-side effects no longer
  mutate render/publication timing state inline

## Compatibility Strategy

We do not go from zero to hero in one patch.

Migration approach:

1. define `TerminalCore` contract in docs
2. introduce a new internal core type without changing behavior
3. make current `TerminalSession` wrap that core
4. move protocol execution and state ownership onto the core
5. move FFI to target the core boundary first
6. keep PTY-backed desktop behavior working through the wrapper

## Progress

### 2026-03-10 first code cut

The first `VTCORE-01` extraction is now landed internally:

- `src/terminal/core/terminal_core.zig` owns the engine-centered terminal state
- `TerminalSession` now wraps `core: TerminalCore`
- PTY/runtime/thread/render-publication ownership stays in `TerminalSession` for now

This first cut moved these owners under `TerminalCore` without changing behavior:

- primary/alt screens and active-screen state
- history/scrollback
- parser state
- OSC title/cwd/clipboard/hyperlink state
- semantic prompt and user vars
- kitty image state
- palette/default-color state
- saved charset and clear-generation state

This is intentionally not the end-state. Protocol execution and FFI still route
through `TerminalSession`, but they now do so against a real internal core owner
instead of one flat session struct.

Session construction also moved one step toward host-wrapper ownership:

- `src/terminal/core/session_runtime.zig` now owns the `TerminalSession`
  allocation + runtime-state assembly path
- `terminal_session.zig` now delegates `initWithOptions(...)` to that runtime
  owner instead of constructing the whole session inline
- replay/test-only debug helpers now also live in
  `src/terminal/core/terminal_session_debug.zig`, so that non-runtime surface is
  no longer embedded directly in the root session file
- dead root-session local helper residue has also started disappearing: unused
  screen-mode/hash/inactive-screen helpers are gone, and the remaining
  test-facing view-cache shim now delegates through
  `src/terminal/core/session_rendering.zig`
- the remaining scroll-refresh and OSC clipboard copy wrappers also now
  delegate through `src/terminal/core/session_rendering.zig` and
  `src/terminal/core/session_queries.zig`, instead of carrying that
  orchestration inline in `terminal_session.zig`
- backlog hinting now also routes through `src/terminal/core/session_runtime.zig`
  instead of `session_rendering.zig`, so render/publication ownership no longer
  depends on transport ingress state
- host-facing metadata, liveness, and close-confirm signal queries now also
  live under `src/terminal/core/session_host_queries.zig`, leaving
  `session_queries.zig` focused on terminal-data query surfaces such as OSC
  clipboard and hyperlink export
- workspace/runtime input-pressure hinting now also routes through
  `src/terminal/core/session_runtime.zig` instead of staying inline in the root
  session facade
- the first explicit `view_cache` split is now landed too: pure publication/diff
  helpers live under `src/terminal/core/view_cache_publication.zig`, so
  `view_cache.zig` is beginning to separate projection from publication
  planning without changing behavior
- selection projection now also lives under
  `src/terminal/core/view_cache_selection.zig`, so `view_cache.zig` is no
  longer carrying both selection projection and publication/diff helpers inline
- viewport-shift and full-vs-partial publication planning now also lives under
  `src/terminal/core/view_cache_plan.zig`, so `view_cache.zig` is losing more
  publication-policy ownership instead of keeping it mixed with projection
- row-hash refinement now also lives under
  `src/terminal/core/view_cache_refinement.zig`, making that optional
  publication-narrowing step explicit instead of leaving it embedded in the
  base view-cache update path
- selection-change dirty expansion now also lives under
  `src/terminal/core/view_cache_selection_dirty.zig`, so selection-driven
  damage widening is no longer embedded in the base `view_cache` update path
- base dirty/damage assignment and partial-damage widening now also lives under
  `src/terminal/core/view_cache_damage.zig`, so `view_cache.zig` is closer
  again to projection/orchestration than publication policy
- presented-generation acknowledgement and damage retirement now also lives
  under `src/terminal/core/session_rendering_retirement.zig`, so
  `session_rendering.zig` no longer mixes capture/feedback with retirement
  policy inline
- replay-backed redraw-contract coverage has now started too: the replay
  harness supports a presented baseline phase plus explicit damage assertions,
  and the first fixtures lock narrow partial publication for gutter rewrites
  and indent-guide rewrites instead of leaving those redraw shapes covered only
  by unit tests
- replay-backed redraw coverage now also includes dense clear+repaint loops,
  locking the current contract that `ED 2` plus a full visible repaint stays on
  the partial path with full-width viewport damage after a presented baseline
- stale private root-session shims for SGR application and key-mode flag reads
  are now removed too, keeping the root session file closer to a real facade
  instead of a pile of dead internal forwarding

### 2026-03-10 protocol split follow-up

The next extraction-only step moved pure engine-side protocol helpers behind
`src/terminal/core/terminal_core_protocol.zig`.

This module currently owns the protocol behaviors that are already clearly
core/model-centered:

- screen erase/insert/delete helpers
- palette lookups
- core cursor and cell queries
- cursor style changes
- tab-stop-at-cursor
- DECRQSS reply formatting that only depends on core state

`session_protocol.zig` now remains focused on the still session-coupled pieces:

- parser feed/dispatch entrypoints
- alt-screen transitions
- selection/cache invalidation coordination
- runtime-facing protocol side effects

### 2026-03-10 dispatch split follow-up

Parser/control dispatch ownership is now partially split again:

- `src/terminal/core/terminal_core_dispatch.zig` owns control, CSI, OSC, APC,
  DCS, codepoint, and ASCII dispatch entry helpers
- `session_protocol.zig` now keeps the session-coupled pieces that still depend
  on session-owned locking and publication

The main remaining reason parser feed still lives in `session_protocol.zig` is
that byte feed currently owns:

- state mutex acquisition
- output generation increments
- view-cache publication updates

That is the next real boundary to cleanly separate if we want parser feed to
become fully core-owned.

### 2026-03-10 feed split follow-up

Parser byte feed is now split one step further:

- `src/terminal/core/terminal_core_feed.zig` owns the actual parser feed call
- `src/terminal/core/terminal_core_feed.zig` now also returns an explicit
  `FeedResult` carrying publication-relevant state
- `session_protocol.zig` now only wraps that feed with:
  - state mutex ownership
  - delegation of generation/view-cache publication to
    `src/terminal/core/session_rendering.zig`

This makes the remaining session-owned part of parser feed explicit: it is not
parsing anymore, it is lock and publication choreography.

### 2026-03-10 first transport contract

The first internal `TerminalTransport` contract is now landed in
`src/terminal/core/terminal_transport.zig`.

Current scope:

- PTY open/start wiring
- transport resize delivery
- has-data checks
- child-exit polling
- aliveness checks
- foreground-process label and close-confirm metadata
- transport deinit

Current PTY-backed runtime code now consumes that contract in:

- `session_runtime.zig`
- `resize_reflow.zig`
- `session_queries.zig`

This was intentionally not the final transport split at first: host lifecycle
and metadata were moved behind the contract before byte IO.

### 2026-03-10 writer contract follow-up

The transport boundary now also owns the main locked writer contract:

- `terminal_transport.Writer` replaces the old raw `Pty` writer guard
- input send paths now call transport-owned writer methods for:
  - key actions
  - key action events
  - keypad sends
  - char actions
  - char action events
  - mouse reports
  - plain text sends
  - raw byte writes

This means the common protocol/input write surface no longer depends on a raw
`Pty*` shape.

What still remains PTY-direct:

- a smaller set of transport setup/existence paths

### 2026-03-10 read path follow-up

The transport boundary now also owns the common read side:

- `terminal_transport.Transport.read(...)`
- `terminal_transport.Transport.waitForData(...)`

Current PTY-backed runtime code now uses those methods in:

- `io_threads.zig`
- `pty_io.zig`

This means the main byte pump no longer depends on raw `Pty` ownership in the
runtime helpers. The remaining PTY-direct uses are narrower and mostly about
transport existence checks plus setup paths that have not been re-cut yet.

### 2026-03-10 transport presence follow-up

The remaining low-risk presence gates are now also routed through
`terminal_transport` helpers:

- `terminal_transport.Writer.exists(...)`
- `terminal_transport.Transport.exists(...)`

Current session-side users no longer peek at `self.pty` directly just to answer
"is there a writable transport?" for the mouse-report and OSC 5522 paste-event
paths.

The protocol-side OSC 5522 reply/read path now also uses the locked transport
writer contract instead of reaching into raw `self.pty` ownership directly.

### 2026-03-10 attach/detach follow-up

PTY setup now also has a transport-owned attach/detach seam:

- `terminal_transport.attachPty(...)`
- `terminal_transport.detachPty(...)`

Current users:

- `terminal_transport.openPty(...)`
- `replay_harness.zig` reply-capture setup

That removes another direct `session.pty = ...` / `session.pty = null` setup
pair from callers outside the transport owner.

## Immediate Naming Direction

These names are recommended to avoid ambiguity:

- `TerminalCore`
- `TerminalCoreSnapshot`
- `TerminalCoreEvent`
- `TerminalTransport`
- `PtyTerminalSession`

Avoid continuing to use `TerminalSession` as the name of the engine center once
the new boundary exists.

## Non-goals

- no Flutter-specific rendering API
- no renderer rewrite in this lane
- no protocol behavior change just to fit the new names
- no broad workspace/UI redesign mixed into the core move

## First Code-Cut Intent

The first implementation slice should be:

- introduce a new internal `TerminalCore` owner
- move no UI behavior
- keep current PTY-backed session behavior identical
- leave FFI surface stable for that slice

That gives the redesign a real center without forcing a full bridge rewrite in
the same patch.
