# VT Core Rearchitecture TODO

## Scope

Continue the post-rewrite split that makes the terminal core the architectural center, with PTY, workspace, UI, and FFI layered around it.

## Constraints

- Preserve current desktop behavior while moving ownership.
- Keep the terminal core renderer-agnostic.
- Keep FFI aligned to the core boundary, not to desktop-only session structure.
- Prefer clean ownership cuts over compatibility sludge.

## Current Direction

The main invention phase is over. Active work is bug hunting, compatibility hardening, and native/FFI convergence on top of the rewritten architecture. The renderer-owned scene path is now the live direction, and the remaining terminal core work is about finishing boundary cleanup and publication ownership rather than reopening the old architecture.

## Priority Now

Highest-value remaining items:

- `VTCORE-01` shrink `TerminalSession` further toward a true host/runtime wrapper
- `VTCORE-02` keep the FFI boundary aligned with the stronger native contract
- `VTCORE-06` keep input encoding transport-agnostic as the host/runtime split finishes

Supporting cleanup:

- `VTCORE-03` transport is already real; remaining work is cleanup and contract tightening
- `VTCORE-04` main protocol/core relocation is already real; remaining work is session-owned residue
- `VTCORE-05` renderer/publication architecture is already live; remaining work is hardening and keeping the contract honest
- `VTCORE-07` remains a guardrail, not a separate invention lane

## TODO

- [x] `VTCORE-00` Define the terminal core boundary.
  Notes: the concrete boundary and target types now live in `app_architecture/terminal/VT_CORE_DESIGN.md`.
- [ ] `VTCORE-01` Separate VT core from host session/runtime.
  Notes: `TerminalCore`, `session_runtime`, debug helpers, render/query/runtime splits, and several root-session delegations are already landed; the remaining work is shrinking `TerminalSession` into a thinner host wrapper. Latest slice: input-mode snapshot state now lives in `src/terminal/core/session_input_snapshot.zig` instead of being defined inline in `terminal_session.zig`.
- [ ] `VTCORE-02` Make FFI a first-class core interface.
  Notes: shared FFI state plus `host_api` and `core_api` splits are landed; remaining work is maturity and convergence, not proving the shape.
- [ ] `VTCORE-03` Introduce transport-agnostic host integration.
  Notes: transport contracts, writer/read boundaries, external transport, replay-harness use, no-PTY host support, and shared redraw/alive wake behavior are landed; remaining work is deeper cleanup rather than first transport abstraction.
- [ ] `VTCORE-04` Move protocol execution onto core/model contracts.
  Notes: the main core-side dispatch, feed, mode, reset, and protocol helper slices are landed; remaining work is finishing the session-owned residue.
- [ ] `VTCORE-05` Simplify snapshot and render publication.
  Notes: publication planning has been heavily split and hardened, replay authority is broad, multi-span row damage now survives through backend and renderer planning, the scene-owned presentation path is live, and present-ack ownership moved later in submission. The active work is now narrower: keep the new publication/present contract honest, continue redraw/perf hardening, and avoid reopening old default-framebuffer assumptions.
- [ ] `VTCORE-06` Keep input encoding as a peer subsystem.
  Notes: transport-agnostic writer-based encoding and fake-writer regression coverage are in place; remaining work is keeping the subsystem decoupled as the rest of the split finishes.
- [ ] `VTCORE-07` Preserve desktop Zide behavior while opening the embedding path.

## Active Focus Inside VTCORE-05

- [ ] Keep replay/manual authority current for redraw and present behavior.
- [ ] Continue post-rewrite compatibility hardening on real workloads.
- [ ] Keep recent-input publication mitigation and scene-target ownership aligned with the current Wayland/present plan.
- [ ] Avoid reintroducing session-centered or default-framebuffer-centered assumptions.
