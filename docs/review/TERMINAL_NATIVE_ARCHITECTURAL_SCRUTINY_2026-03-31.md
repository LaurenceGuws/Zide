# Terminal Native Architectural Scrutiny

Date: 2026-03-31

Scope:

- current native terminal implementation on `main`
- engine/host/publication/presentation boundaries
- fallback-path, compatibility-residue, and hack-shaped ownership smells

This is a high-level architectural audit, not a bug diary.
It is written against the current authority docs and the strongest local
references:

- `ghostty`
- `wezterm`
- `alacritty`
- `kitty`

The standard applied here is intentionally strict:

- DRY
- loosely coupled
- one obvious owner per behavior
- minimal compatibility residue
- native path proves the engine contract, not a privileged semantic path

## Executive Judgment

Zide's native terminal architecture is no longer in the "rewrite chaos" phase.
It already has a real engine center, a real transport split, and a real
publication/presentation vocabulary. The remaining issues are now higher-order:

- too much public/root-shell surface area
- too much semantic work still living in host-facing glue seams
- too much duplicated published state
- too much native-path coordination still depending on session/export shells

The main structural problem is no longer "raw VT semantics are scattered
everywhere." The main structural problem is that the system still has too many
coordination shells and mirrors around the true engine.

In short:

- `TerminalCore` is real
- but it is still not obviously the only center
- `TerminalSession` still reads as a broad assembly/export shell
- widget/render code is still too large and too intimate with publication
  details
- publication still duplicates more state than a best-in-class engine boundary
  should

## Sequential Findings

### 1. `TerminalSession` is still too large to be the right public center

Primary files:

- `src/terminal/core/terminal_session.zig`
- `src/terminal/core/terminal_runtime.zig`
- `src/terminal/core/terminal_publication.zig`
- `src/terminal/core/terminal_debug.zig`

Evidence:

- `terminal_session.zig` is still `791` lines and acts as the root public
  facade for:
  - runtime
  - input
  - protocol
  - rendering/publication
  - content queries
  - selection
  - host queries
  - debug helpers
- the old `terminal.zig` root barrel was deleted after the explicit runtime and
  publication surfaces took over native/widget/FFI/replay/test/smoke call
  paths

Judgment:

- this is cleaner than the older monolith, but still not best-in-class
- the system still reads as "many focused helpers behind one broad god-facade"
  rather than "engine plus narrow host wrapper"
- the newly introduced explicit surfaces
  - `src/terminal/core/terminal_runtime.zig`
  - `src/terminal/core/terminal_publication.zig`
  - `src/terminal/core/terminal_debug.zig`
  are the right direction because they give native/replay/FFI/widget consumers
  an enforced explicit entrypoint instead of a broad root barrel
- the old mixed alias hub `src/terminal/core/session_public_types.zig` is also
  gone, which is an honest improvement: `terminal_session.zig` now imports
  direct owners instead of hiding public-facing types behind one more helper
  facade
- `src/terminal/core/session_runtime_api.zig` and
  `src/terminal/core/session_publication_api.zig` now carry the runtime and
  publication/present method groups that were previously written inline on
  `terminal_session.zig`
- `src/terminal/core/session_input_api.zig` now carries the host input
  send/report method group that was previously written inline on
  `terminal_session.zig`
- `src/terminal/core/session_protocol_api.zig` now carries the protocol/VT
  mutation method group that was previously written inline on
  `terminal_session.zig`
- but they are only the first strike, not the kill:
  `terminal_session.zig` still owns too much behavior

Why it matters:

- the broad facade makes accidental privileged reach-through cheap
- it hides which contracts are actually stable and narrow
- it keeps native and FFI tempted to depend on the same broad shell instead of
  a more explicit engine/publication boundary

### 2. Printable-text semantics still live above the engine boundary

Primary files:

- `src/terminal/core/parser_hooks.zig`
- `src/terminal/core/terminal_core_dispatch.zig`

Evidence:

- `parser_hooks.zig` still owns meaningful text-write behavior:
  - ASCII slice handling
  - codepoint write preparation loops
  - DEC special charset mapping during writes
  - hyperlink attr injection
  - insert-mode write behavior
  - wrap/newline coordination

Reference comparison:

- Ghostty drives parser actions more directly into terminal methods
- Zide still routes parser output through a session-facing hook seam that owns
  semantic write behavior

Judgment:

- this is one of the strongest remaining "wrong layer" smells
- even if it is not the current root cause of any specific bug, it is not the
  cleanest engine shape

### 3. Publication state is duplicated and mirrored too broadly

Primary files:

- `src/terminal/core/render_cache.zig`
- `src/terminal/core/view_cache.zig`
- `src/terminal/core/session_rendering.zig`
- `src/terminal/core/session_presentation_handoff.zig`

Evidence:

- `snapshot()` sometimes returns direct screen-owned state and sometimes a
  render-cache view
- `RenderCache` duplicates a large amount of terminal-visible state:
  - cells
  - dirty rows
  - dirty spans
  - cursor
  - selection projection
  - kitty state
  - scrollback/publication metadata
- `capturePresentation(...)` and `copyPublishedRenderCache(...)` still copy
  large cache snapshots under the session shell

Judgment:

- the publication contract is now explicit, which is good
- but the implementation still feels heavier than ideal because published state
  is mirrored, copied, and coordinated in several places

Why it matters:

- duplication increases the number of "truth-shaped" surfaces
- it makes retirement/ack/damage bugs more likely
- it keeps native rendering tightly coupled to publication internals

### 4. Native widget draw is still too large and too privileged

Primary files:

- `src/ui/widgets/terminal_widget_draw.zig`
- `src/ui/widgets/terminal_widget.zig`

Evidence:

- `terminal_widget_draw.zig` is `1731` lines
- it owns:
  - draw prep
  - texture update planning
  - capture/presentation handoff participation
  - frame metrics
  - generation summaries
  - investigation logging
  - terminal-specific rendering heuristics

Judgment:

- this is not just "renderer glue"
- it is a large native-host coordination shell with too much intimate
  knowledge of terminal publication state

Why it matters:

- oversized widget draw code is a recurring place for native-only truths to
  creep back in
- it makes the presentation layer harder to reason about as a pure host
  consumer of published state

### 5. The current publication/present split is improved, but still too
session-centered

Primary files:

- `src/terminal/core/session_publication_state.zig`
- `src/terminal/core/session_publication_updates.zig`
- `src/terminal/core/session_presentation_handoff.zig`

Evidence:

- these are now nicely split, but still fundamentally operate as helper seams
  over session-owned caches and locks
- acknowledgement, damage retirement, and view-cache refresh still depend on
  the session shell as the coordination center

Judgment:

- this is better than the old blob
- but it is still "session-centered publication split into files," not yet the
  cleanest engine-centered publication object model

### 6. `snapshot_adapter.zig` is an explicit unfinished seam

Primary file:

- `src/terminal/core/snapshot_adapter.zig`

Evidence:

- the adapter returns an almost-empty placeholder shared snapshot
- it contains an explicit TODO saying the mapping waits on widget/core split

Judgment:

- this is honest, but architecturally weak
- unfinished adapters are where duplicate contracts and long-lived temporary
  surfaces tend to accumulate

Why it matters:

- if Zide wants native and FFI to sit on one engine truth, the shared snapshot
  seam cannot stay stub-shaped for long

### 7. Re-export patterns still blur the intended contract

Primary files:

- `src/terminal/core/terminal_runtime.zig`
- `src/terminal/core/terminal_publication.zig`
- `src/terminal/core/terminal_session.zig`

Evidence:

- public types and methods are re-exported through multiple files
- the remaining re-export surfaces can still hide whether callers are using:
  - engine truth
  - host wrapper convenience
  - publication surface
  - debug/replay surface

Judgment:

- this is not a correctness bug
- it is contract blur, and contract blur creates architectural drift

### 8. Runtime/transport is acceptably split, but still assembled as a shell

Primary files:

- `src/terminal/core/session_runtime.zig`
- `src/terminal/core/session_transport_runtime.zig`
- `src/terminal/core/session_thread_runtime.zig`
- `src/terminal/core/pty_io.zig`

Evidence:

- runtime and transport ownership are much improved
- but they still read as an extracted assembly shell around `TerminalSession`,
  not as a more self-contained host/runtime boundary object

Judgment:

- this is no longer the worst problem
- but it is still a center-of-gravity issue

### 9. Debug and investigation hooks are still embedded in live native seams

Primary files:

- `src/ui/widgets/terminal_widget_draw.zig`
- `src/terminal/parser/parser.zig`
- `src/debug/capture_burst.zig`

Evidence:

- Scroll Lock capture and parser-side burst logging now live in production-path
  files
- they are gated, but the live path still carries ad hoc investigation seams

Judgment:

- good for short-term debugging
- not good as a long-term architectural habit

Why it matters:

- deep live-path probes become invisible structural debt if they are not
  retired quickly

### 10. There are still compatibility mirrors and dual surfaces in the
publication contract

Primary files/docs:

- `app_architecture/terminal/VT_CORE_DESIGN.md`
- `src/terminal/core/render_cache.zig`
- `src/terminal/core/snapshot.zig`

Evidence:

- the docs already acknowledge compatibility/export mirrors
- publication exposes both detailed span state and older union-style fields
- snapshot/render-cache/publication state still contains signs of evolutionary
  layering rather than one final clean contract

Judgment:

- some of this is intentional
- but best-in-class quality eventually means deleting the mirrors, not merely
  documenting them

## Largest Potential Changes For Maximum Payoff

1. Make `TerminalCore` plus an explicit publication object the true public
   center, and shrink `TerminalSession` into a narrow host/runtime wrapper.
2. Delete parser-owned semantic text handling from `parser_hooks.zig` by moving
   printable write behavior fully below the VT action boundary.
3. Keep shrinking `terminal_session.zig` now that `terminal.zig` is dead, and
   stop re-exporting broad mixed ownership through runtime/publication helper
   surfaces where direct ownership types would be clearer.
4. Collapse duplicated publication state so one canonical published snapshot
   shape exists, instead of parallel screen/view-cache/render-cache truths.
5. Split native widget draw into smaller renderer-facing units and stop letting
   widget draw participate so directly in terminal publication choreography.
6. Replace the current session-centered publication helpers with a more
   explicit publication/present state object that owns generation, pending, and
   retirement logic directly.
7. Finish the shared snapshot adapter seam so native and shared/FFI consumers
   stop depending on separate snapshot-shaped contracts.
8. Remove remaining compatibility mirrors from publication fields once replay
   and FFI authority can cover the cut.
9. Move investigation/debug capture plumbing out of hot production files into a
   reusable debug instrumentation seam.
10. Re-audit the native widget surface and forbid new terminal semantics from
    landing there unless they are clearly host chrome or input mapping.

## Priority Order

If the goal is maximum architectural payoff rather than minimum risk, the best
order is:

1. shrink the public/root surface
2. move printable semantics below the VT boundary
3. collapse publication duplication
4. shrink widget draw and native present choreography
5. retire mirrors and stubs

If the goal is safer incremental execution, the order is:

1. shared snapshot/public contract cleanup
2. root facade reduction
3. widget draw decomposition
4. parser-hook printable-write migration
5. publication object cleanup

## Recommended Near-Term Rule Changes

These should be treated as explicit architecture rules for future terminal
work:

- no new terminal semantics in widget files
- no new host-policy convenience in `TerminalSession`
- no new publication mirrors unless they are temporary and deletion is planned
- no parser-hook behavior that mutates terminal semantics if the engine can own
  it directly
- no investigation scaffolding left in hot files after the owning bug lane
  cools

## Final Assessment

The terminal architecture is no longer suffering from lack of direction.
It is suffering from incomplete convergence.

The biggest payoff is no longer another round of helper extraction for its own
sake. The biggest payoff is to stop tolerating multiple "almost-centers":

- root facade
- parser hook seam
- publication/cache shell
- oversized native widget draw shell

Until those converge further, Zide will keep feeling stronger than average at
the contract level, but weaker than the best references at obvious ownership.
