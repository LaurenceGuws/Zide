# VT Core Rearchitecture TODO

## Scope

Continue the post-rewrite split that makes the terminal core the architectural center, with PTY, workspace, UI, and FFI layered around it.

## Constraints

- Preserve current desktop behavior while moving ownership.
- Keep the terminal core renderer-agnostic.
- Keep FFI aligned to the core boundary, not to desktop-only session structure.
- Prefer clean ownership cuts over compatibility sludge.
- Treat the native GUI as the reference host for the engine contract, not as a
  privileged terminal path with different semantics from FFI.
- Use `app_architecture/terminal/TERMINAL_SUBSYSTEM_LAYERS.md` when deciding
  which subsystem layer should own a change; do not infer ownership only from
  file placement or historical session structure.

## Current Direction

The passive cleanup phase is over. The active lane is now a deliberate assault
on every architectural seam that keeps `TerminalCore` from being the obvious
center. This is still iterative work, but it is no longer gentle work. Each
cut should remove a structural lie, not merely rearrange the same center of
gravity into smaller files.

## Priority Now

Highest-value remaining items, ranked against the current `libghostty-vt` comparison:

1. `VTCORE-01` break `TerminalSession` as the architectural center
   Why: this is still the most visible fake center in the native terminal
   stack. As long as it reads like the real terminal, the architecture is
   lying on first glance.
2. `VTCORE-05` replace duplicated publication truth with an explicit engine-owned publication center
   Why: mirror-heavy publication state keeps native rendering and backend
   retirement too tightly coupled, and it weakens the contract story.
3. `VTCORE-04` move the remaining semantic text/protocol ownership below the VT boundary
   Why: parser-hook text semantics are still one of the clearest "wrong layer"
   smells versus the strongest references.
4. `VTCORE-02` keep the FFI boundary aligned with the stronger native contract
   Why: native must become the cleanest reference host over one engine truth,
   not a privileged semantic owner that FFI tries to imitate later.
5. `VTCORE-06` keep input encoding transport-agnostic as the rest of the kill-order proceeds
   Why: this must remain a peer subsystem, not collapse back into session glue.

Supporting cuts:

- `VTCORE-03` transport is already real; keep it narrow and prevent it from
  becoming a second semantic center
- `VTCORE-07` remains a guardrail: native must become the sharpest host, not a
  special host

Focused follow-up lane:

- `docs/review/TERMINAL_NATIVE_ARCHITECTURAL_SCRUTINY_2026-03-31.md`
  Why: this is the current ruthless read on what still looks second-rate at
  first glance and what should be demolished first.

## Current Milestone

Branch:

- `terminal-war`

Milestone rule:

- keep small checkpoint commits on `terminal-war`
- merge back into `main` once this milestone is validated
- do not stack the next milestone on top of an unmerged one

Current milestone: `M3` collapse remaining PTY host-wrapper alias noise

Merge goal:

- the root/public contract should have one obvious PTY host-wrapper name
- workspace internals should stop exporting redundant PTY wrapper aliases
- docs and validation should capture the contract simplification clearly enough
  that the merge to `main` is a real milestone, not a partial scratch state

Checklist:

- [x] unused public `WorkspacePtyTerminalSession` root export removed
- [x] workspace PTY wrapper alias made internal
- [x] milestone validation pass captured
- [ ] milestone merged back into `main`

Validation note, 2026-03-31:

- passed:
  - `zig build test`
  - `zig build check-app-imports`
- contract simplification:
  - the unused public `WorkspacePtyTerminalSession` export is removed from
    `src/terminal/core/terminal.zig`
  - `src/terminal/core/workspace.zig` keeps the PTY wrapper alias internal

## TODO

- [x] `VTCORE-00` Define the terminal core boundary.
  Notes: the concrete boundary and target types now live in `app_architecture/terminal/VT_CORE_DESIGN.md`.
- [ ] `VTCORE-01` Separate VT core from host session/runtime.
  Notes: this is no longer a "trim a few helpers" item. This is the campaign to
  dethrone `TerminalSession` as the visual and practical center of the
  terminal. Prior extractions still matter, but only insofar as they make
  deletion and decomposition easier. Judge every remaining method, re-export,
  and helper by one question: does it still make `TerminalSession` look like
  the real terminal?
  Done when:
  - `TerminalSession` no longer reads like the engine at first glance.
  - the public center is explicit and smaller than the current root facade.
  - remaining host/runtime assembly is narrow enough to justify either a hard
    rename or outright deletion of the current `TerminalSession` shape.
  Current judgment:
  - helper extraction alone is no longer enough
  - the remaining problem is architectural theater: too many smaller files still
    preserve one broad fake center
  - this lane stays hot until that center is broken
  Progress note, 2026-03-31:
  - landed a first public-surface cut at the root terminal module:
    `src/terminal/core/terminal.zig` now exports the PTY-backed host wrapper as
    `PtyTerminalSession`, and native app/runtime, FFI, and replay-harness
    consumers were moved onto that explicit name.
  - this does not finish `VTCORE-01`; `terminal_session.zig` is still broad.
    It does remove one layer of public contract blur by stopping the root
    terminal barrel from presenting the PTY host wrapper as the terminal's
    neutral center.
- [ ] `VTCORE-02` Make FFI a first-class core interface.
  Notes: shared FFI state plus `host_api` and `core_api` splits are landed; remaining work is maturity and convergence, not proving the shape. Recent slices closed real host-facing gaps such as close-confirm signals and backend-owned viewport control.
  Done when:
  - the best host-facing terminal semantics reachable from native are also reachable through an explicit FFI/core contract, unless the difference is purely renderer-local.
  - FFI no longer needs to approximate native-only ownership or reconstruct backend truth from side channels.
  - new host-facing semantics are judged first by whether they belong to the shared engine contract, not by whether native can reach them internally.
- [ ] `VTCORE-03` Introduce transport-agnostic host integration.
  Notes: transport contracts, writer/read boundaries, external transport, replay-harness use, no-PTY host support, and shared redraw/alive wake behavior are landed; remaining work is deeper cleanup rather than first transport abstraction.
- [ ] `VTCORE-04` Move protocol execution onto core/model contracts.
  Notes: the main protocol relocation is landed, but the text path still carries
  a serious smell: `parser_hooks.zig` still owns semantic write behavior that a
  cleaner engine would own below the VT boundary.
- [ ] `VTCORE-05` Simplify snapshot and render publication.
  Notes: publication planning is explicit now, but the implementation still
  mirrors too much truth and still feels too session-centered. This lane is no
  longer about "hardening what exists" alone. It is about crushing duplicated
  publication truth until one obvious published state center remains.
- [ ] `VTCORE-06` Keep input encoding as a peer subsystem.
  Notes: transport-agnostic writer-based encoding, fake-writer regression coverage, and PTY-backed `TerminalSession.sendText(...)` / `sendKey(...)` regressions through the real session writer boundary are in place; remaining work is keeping the subsystem decoupled as the rest of the split finishes.
- [ ] `VTCORE-07` Preserve desktop Zide behavior while opening the embedding path.
  Notes: this means preserving native quality while keeping native and FFI as peer hosts over the same engine truth, with native acting as the lowest-friction reference implementation rather than as a second semantic center.

## Current Kill Order

- [ ] break `TerminalSession` as the false center
- [ ] move printable semantics below the VT boundary
- [ ] replace duplicated publication/cache truth with one explicit center
- [ ] shrink native widget draw into a host/presentation consumer, not a
      publication co-owner
- [ ] delete mirrors, fallback paths, and compatibility residue that survive
      only because nobody has taken the knife to them yet

## Current Audit Result

- The engine-center gap versus `libghostty-vt` is now mostly about obviousness
  and ownership gravity, not lack of subsystems.
- The largest remaining architectural enemies are:
  - `TerminalSession` as a false center
  - parser-hook semantics above the engine
  - duplicated publication truth
  - oversized native widget/render coordination
- The terminal campaign should now judge success by first-glance authority:
  when a strong maintainer opens the code, the engine must obviously be the
  engine.
