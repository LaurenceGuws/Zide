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

The main invention phase is over. The bug-hunting-heavy phase did the work it needed to do: the rewritten path is now the baseline, and the active lane has shifted toward cleanup/restructure plus native/FFI convergence. The renderer-owned scene path is the live direction, and the remaining terminal core work is about finishing the engine boundary cleanly rather than reopening the old architecture.

## Priority Now

Highest-value remaining items, ranked against the current `libghostty-vt` comparison:

1. `VTCORE-02` keep the FFI boundary aligned with the stronger native contract
   Why: embeddability is already real, so the remaining work is keeping the public engine boundary honest instead of letting native-only assumptions creep back in. Native should prove the contract, not define a different one. Current nuance against `libghostty-vt`: Ghostty still wins on engine-centered cleanliness, but Zide is no longer obviously behind on host-facing contract richness.
2. `VTCORE-01` shrink `TerminalSession` further toward a true host/runtime wrapper
   Why: this is still the biggest structural gap between Zide and a cleaner engine-first boundary like `libghostty-vt`, but the highest-yield seams have recently narrowed; the remaining cuts should only continue when they remove another real native-only ownership leak rather than mostly internal palette/config bookkeeping.
3. `VTCORE-06` keep input encoding transport-agnostic as the host/runtime split finishes
   Why: Ghostty’s encoder remains a strong reference for a peer subsystem that consumes terminal state without becoming session-owned glue.

Supporting cleanup:

- `VTCORE-03` transport is already real; remaining work is cleanup and contract tightening
- `VTCORE-04` main protocol/core relocation is already real; remaining work is session-owned residue
- `VTCORE-05` renderer/publication architecture is already live; remaining work is hardening and keeping the contract honest
- `VTCORE-07` remains a guardrail, not a separate invention lane

## TODO

- [x] `VTCORE-00` Define the terminal core boundary.
  Notes: the concrete boundary and target types now live in `app_architecture/terminal/VT_CORE_DESIGN.md`.
- [ ] `VTCORE-01` Separate VT core from host session/runtime.
  Notes: `TerminalCore`, `session_runtime`, debug helpers, render/query/runtime splits, and several root-session delegations are already landed; the remaining work is shrinking `TerminalSession` into a thinner host wrapper. Latest slices: input-mode snapshot state now lives in `src/terminal/core/session_input_snapshot.zig`, presentation-feedback structs now live in `src/terminal/core/session_presentation_feedback.zig`, session init options now live in `src/terminal/core/session_init_options.zig`, host-query structs now live in `src/terminal/core/session_host_types.zig`, the remaining session-facing public type aliases now live in `src/terminal/core/session_public_types.zig`, the scrollback/viewport content wrapper now lives behind `src/terminal/core/session_content_api.zig`, the selection wrapper is now aliased directly from `src/terminal/core/session_selection.zig`, the public host/query surface is now aliased directly from `src/terminal/core/session_queries.zig` and `src/terminal/core/session_host_queries.zig`, the interaction/mode surface is now aliased directly from `src/terminal/core/session_interaction.zig`, host metadata/close-confirm queries now consume core-owned accessors instead of reaching straight into raw `self.core` fields, clipboard-related host semantics now mutate engine-owned OSC/OSC5522 buffers through `TerminalCore` methods instead of raw session-side buffer access, sync-update plus scrollback-count/offset rendering and config cache paths now also route through `TerminalCore` accessors/mutators instead of direct session-side field/history access, the backend-owned viewport/scrollback path in `scrollback_view.zig` now also routes through `TerminalCore` scrollback accessors/mutators instead of raw history choreography, save/restore cursor plus saved-charset state now also live on `TerminalCore` instead of session-style helper choreography, parser control/reset state for SO/SI, ESC entry, parser reset, and saved-charset clearing now also route through `TerminalCore` instead of direct parser-field mutation from control/reset helpers, OSC title/cwd buffer clearing, append, and publish/default-title operations now also route through `TerminalCore` instead of direct core-buffer mutation from OSC protocol helpers, selection clear/start/update/finish/read now also route through `TerminalCore` instead of raw history selection mutation from the selection helper path, resize/reflow now also restores or clears selection through `TerminalCore` instead of mutating raw history-selection internals directly, full reset now also lives on `TerminalCore` instead of open-coded core-field mutation in `terminal_core_reset.zig`, column-mode reset/clear-generation semantics now also live behind a core-owned mutator instead of session-side field choreography, default-color / ANSI remap, palette snapshot/reset, and dynamic-color update semantics now also route through `TerminalCore` mutators instead of direct screen/history/palette mutation from `session_config`, child-exit truth polling/reporting now lives behind `src/terminal/core/session_lifecycle.zig` instead of being split between `session_runtime.zig` and host-query code, transport open/attach/close, writer access, external-outgoing drain, and resize-report choreography now lives behind `src/terminal/core/session_transport_runtime.zig` instead of staying bundled inside `session_runtime.zig`, and thread shutdown plus queued-IO/backlog observation now lives behind `src/terminal/core/session_thread_runtime.zig` instead of staying open-coded inside `session_runtime.zig`. This remains the top restructure item because `TerminalSession` is still the main center-of-gravity gap versus the cleaner `libghostty-vt` style engine boundary documented in `docs/review/TERMINAL_CORE_ARCHITECTURE_REVIEW_2026-03-10.md`.
  Done when:
  - `TerminalSession` reads primarily as host/runtime assembly plus narrow host conveniences, not as the place where terminal semantics still live.
  - coherent public method clusters are either owned by `TerminalCore` or forwarded through focused `session_*` boundary modules instead of being hand-written across the root facade.
  - native host code no longer relies on privileged deep-core access patterns that an equivalent FFI host cannot reach through the intended engine contract.
  Current judgment:
  - the highest-yield session/core seams have materially cooled after the recent host-query, clipboard, sync-update, column-mode, and palette/default-color cuts
  - remaining `session_config` seams are increasingly internal core bookkeeping rather than host-contract asymmetries
  - the stronger remaining center-of-gravity issue is no longer mostly raw VT semantics living on the root facade; it is that `session_runtime.zig`, `session_rendering.zig`, the publication-state seam, and the presentation-handoff seam still carry a lot of runtime/publication assembly around `TerminalCore`
  - do not keep pushing this lane for symmetry alone; prefer `VTCORE-02` unless another native-only ownership leak is clearly identified
- [ ] `VTCORE-02` Make FFI a first-class core interface.
  Notes: shared FFI state plus `host_api` and `core_api` splits are landed; remaining work is maturity and convergence, not proving the shape. Recent slices closed real host-facing gaps such as close-confirm signals and backend-owned viewport control.
  Done when:
  - the best host-facing terminal semantics reachable from native are also reachable through an explicit FFI/core contract, unless the difference is purely renderer-local.
  - FFI no longer needs to approximate native-only ownership or reconstruct backend truth from side channels.
  - new host-facing semantics are judged first by whether they belong to the shared engine contract, not by whether native can reach them internally.
- [ ] `VTCORE-03` Introduce transport-agnostic host integration.
  Notes: transport contracts, writer/read boundaries, external transport, replay-harness use, no-PTY host support, and shared redraw/alive wake behavior are landed; remaining work is deeper cleanup rather than first transport abstraction.
- [ ] `VTCORE-04` Move protocol execution onto core/model contracts.
  Notes: the main core-side dispatch, feed, mode, reset, and protocol helper slices are landed; remaining work is finishing the session-owned residue.
- [ ] `VTCORE-05` Simplify snapshot and render publication.
  Notes: publication planning has been heavily split and hardened, replay authority is broad, multi-span row damage now survives through backend and renderer planning, the scene-owned presentation path is live, and present-ack ownership moved later in submission. The active work is now narrower but also more structurally important than the older wording implied: `session_rendering.zig`, the publication-state seam, and the presentation-handoff seam now look like the strongest remaining "session still feels like the center" lane because they still own published/presented generation bookkeeping, render-cache handoff, view-cache update choreography, sync-update publication behavior, and presentation capture/feedback around `TerminalCore`. Keep the new publication/present contract honest, continue redraw/perf hardening, and avoid reopening old default-framebuffer assumptions.
- [ ] `VTCORE-06` Keep input encoding as a peer subsystem.
  Notes: transport-agnostic writer-based encoding, fake-writer regression coverage, and PTY-backed `TerminalSession.sendText(...)` / `sendKey(...)` regressions through the real session writer boundary are in place; remaining work is keeping the subsystem decoupled as the rest of the split finishes.
- [ ] `VTCORE-07` Preserve desktop Zide behavior while opening the embedding path.
  Notes: this means preserving native quality while keeping native and FFI as peer hosts over the same engine truth, with native acting as the lowest-friction reference implementation rather than as a second semantic center.

## Active Focus Inside VTCORE-05

- [ ] Keep replay/manual authority current for redraw and present behavior.
- [ ] Continue post-rewrite compatibility hardening on real workloads.
- [ ] Keep recent-input publication mitigation and scene-target ownership aligned with the current Wayland/present plan.
- [ ] Avoid reintroducing session-centered or default-framebuffer-centered assumptions.

## Current Audit Result

- The engine-center gap versus `libghostty-vt` is smaller than the older docs implied.
- The remaining structural gap is now more specifically runtime/publication center-of-gravity:
  - `session_runtime.zig` still owns thread lifecycle, parse/read loop assembly, PTY/external transport switching, and child-exit truth assembly.
  - `session_rendering.zig`, the publication-state seam, and the presentation-handoff seam still own published/presented generation bookkeeping, render-cache handoff, view-cache update choreography, sync-update publication behavior, and presentation capture/feedback.
  - `terminal_session.zig` is still large, but increasingly as the assembly shell around those runtime/publication lanes rather than as the place where raw VT semantics live.
- That means the next strongest comparison lane against Ghostty is not "trim more facade methods for symmetry"; it is "keep moving runtime/publication ownership toward a clearer engine-centered contract."
