Date: 2026-03-14

Purpose: define the shared redraw/publication/present contract that both the
native Linux GUI path and the FFI/embedded host path must satisfy.

This document replaces the older "future redraw lane" framing. The contract is
now active design authority for:

- native renderer-owned scene submission
- FFI host-facing publication and present acknowledgement
- later convergence work toward one honest host-facing engine contract

## Quality Bar

This contract exists to support a quality target in the same band as
`kitty` / `ghostty` for:

- correctness
- smoothness
- steady-state cost
- host/embed portability

The native GUI is the proving ground. The FFI/embedded path is expected to
catch up to the same semantics, not invent a lower-grade side path.

## Reference Direction

Reference read, local snapshots:

- Ghostty:
  - explicit host/runtime boundary
  - renderer wake and render ownership stay outside VT core
  - embedded host surface is narrow and explicit
- WezTerm:
  - render-facing state is monotonic and sequence-driven
  - host/render side consumes explicit latest state instead of inferring it
- Foot / Kitty:
  - terminal-side truth and render-side scheduling stay cleanly separated
  - correctness does not depend on accidental compositor/default-buffer behavior

Shared lesson:

- terminal/backend owns publication truth
- host owns scheduling and presentation
- acknowledgement is explicit
- wake and present are not the same contract

## Contract Goals

1. One publication truth.
   Terminal/backend state changes must collapse into one authoritative published
   generation plus damage metadata.

2. One acknowledgement truth.
   Hosts must explicitly communicate which published generation they have
   actually presented/consumed.

3. Wake is advisory, not authoritative.
   Wake signals say "go look again"; they do not define what is dirty.

4. Native and FFI stay semantically aligned.
   The native path may have richer renderer internals, but it must not rely on
   weaker or different publication/present semantics than foreign hosts.

## Ownership Model

### Terminal Core / Backend

Owns:

- model mutation truth
- published generation truth
- published damage truth
- stable render-facing snapshot/view truth

Does not own:

- frame pacing
- present timing
- swap/default-framebuffer semantics
- host-local draw scheduling

### Host

Owns:

- wake handling and scheduling
- actual drawing/presentation
- explicit acknowledgement of presented/consumed generations

Hosts include:

- native renderer/widget/frame loop
- FFI/embedded hosts such as a future Flutter runtime

### Renderer

Native-only specialization of host responsibilities:

- owns authoritative scene composition before swap
- owns renderer submission identity
- owns renderer-side present diagnostics

It does not become publication truth.

## Shared State Model

Every host path should be explainable in terms of these states:

1. Model dirty state
- backend mutation truth only

2. Published state
- stable render-facing state
- authoritative `published_generation`
- authoritative damage/full-redraw reason

3. Acknowledged state
- latest generation the host says it has actually presented/consumed
- optimization and retirement input
- never a second publication truth

4. Wake state
- advisory signal that fresh published state may exist
- host may coalesce wakes
- host must still consult published/acknowledged state

## Required Shared Semantics

### A. Published generation is authoritative

Hosts answer "is there newer terminal content?" from published generation
truth, not widget-local flags or ad hoc side channels.

### B. Acknowledged generation is monotonic

Hosts may only acknowledge:

- the current published generation, or
- an older published generation not older than the current acknowledged one

In practice we reject backward acknowledgement because it blurs ownership and
does not help optimization.

### C. Wake does not mean present

Wake semantics must remain separate from presentation semantics:

- wake/`redraw_ready` means "fetch fresh published state"
- it does not mean "the host has now presented generation N"

### D. Damage is advisory to the host, authoritative from the backend

Backend owns the damage/full-redraw decision. Hosts may choose how to draw from
that information, but must not invent their own notion of whether backend state
is really dirty.

### E. Present acknowledgement is optimization-only feedback

Presented/acknowledged generation influences:

- retirement
- redraw cooling
- later optimization/refinement

It must not become the reason published damage or correctness is lost.

## Native Mapping

Current native path on `main`:

- terminal draw stages presentation feedback during widget/render-input work
- renderer owns authoritative scene composition
- renderer submission now has:
  - `succeeded`
  - monotonic submission `sequence`
- terminal presentation feedback flushes only after successful renderer
  submission

That means the native path now distinguishes:

- latest published generation
- latest successfully submitted renderer scene
- latest terminal presentation feedback flushed after submission

This is the stronger host-side contract the FFI path is catching up to.

## FFI Mapping

Current FFI path now exposes the minimal shared contract explicitly:

- `zide_terminal_published_generation(handle, &generation)`
- `zide_terminal_present_ack(handle, generation)`
- `zide_terminal_acknowledged_generation(handle, &generation)`
- `zide_terminal_needs_redraw(handle)`
- `redraw_ready` event remains wake-only

Current FFI meaning:

- `published_generation` is publication truth
- `acknowledged_generation` is host-consumption truth
- `needs_redraw == (published_generation != acknowledged_generation)`
- `redraw_ready` is an edge-triggered wake hint for snapshot pull

This keeps the FFI bridge aligned with native semantics without exporting
native renderer details.

## Current Convergence Point

Native and FFI are not on the same implementation path yet, but they are now
converging on the same host-facing semantics:

- backend publishes authoritative generations
- hosts consume/present explicitly
- hosts acknowledge explicitly
- wake remains advisory and cheap

That is the contract a future embedded/mobile host should inherit.

## Non-Goals

This contract does not require:

- exporting native renderer internals into FFI
- preserving old widget-local correctness heuristics
- making `redraw_ready` into a present event
- forcing native and FFI to share the same concrete rendering code today

## Follow-On Work

1. Keep tightening native present ownership around renderer-owned submission
   truth.
2. Decide whether future FFI metadata/event surfaces need to expose additional
   acknowledged-generation-aware state beyond the current getter pair.
3. Keep `view_cache` / publication cleanup aligned with this shared contract,
   not with widget-local historical behavior.
4. When native and FFI are mature enough, collapse toward one explicit
   host-facing engine contract wherever that unification remains honest and
   cheap.
