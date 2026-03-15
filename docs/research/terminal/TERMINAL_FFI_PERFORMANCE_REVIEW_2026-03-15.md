# Terminal FFI Performance Review

Date: 2026-03-15

Status: current checkpoint after the VT/FFI growth phase stabilized across the
native reference host and the downstream Flutter host.

Purpose: record the current hot-path performance judgment for the terminal FFI
contract before more surface hardens.

## Reference Bias

The relevant reference repos/docs reinforce the current direction:

1. Ghostty
   - Ghostty explicitly treats `libghostty` / `libghostty-vt` as an embeddable
     terminal-library goal, separate from the standalone app surface.
   - That strongly supports keeping engine truth and host boundary shape clean,
     instead of letting the native app become the only efficient semantic path.
   - Source:
     - https://github.com/ghostty-org/ghostty

2. WezTerm
   - WezTerm distinguishes between a live pane handle and lighter snapshot-like
     information for synchronous UI paths.
   - That supports our bias that hot-path host/UI work should consume a narrow,
     cheap authority surface rather than pull broad state repeatedly.
   - Sources:
     - https://wezterm.org/config/lua/pane/index.html
     - https://wezterm.org/config/lua/PaneInformation.html
     - https://wezterm.org/config/lua/pane/get_metadata.html

3. Kitty
   - Kitty continues to extend terminal behavior with targeted protocol
     additions rather than turning the host/runtime contract into a chatty pile
     of micro-surfaces.
   - That supports being disciplined about new bridge exports: add narrow,
     high-value semantics when needed, but avoid convenience growth that raises
     call count or weakens authority.
   - Source:
     - https://sw.kovidgoyal.net/kitty/protocol-extensions/
     - https://sw.kovidgoyal.net/kitty/unscroll/

These references do not imply that Zide must copy any one implementation
verbatim. They do reinforce three design biases:

- keep the engine boundary explicit and hostable
- keep hot-path state consumption narrow and cheap
- prefer targeted extensions over chatty surface growth

## Scope

This review is about the host boundary itself:

- call shape
- allocation/copy cost
- redraw/publication/present pacing
- external transport batching
- latest-state authority surfaces

It is not a review of renderer performance or widget-level efficiency.

## Current Contract Judgment

Direction is still sound.

The current bridge is good enough to keep building on, but the remaining
boundary-cost risk is concentrated:

1. `snapshot_acquire(...)` is still the dominant medium-term cost surface.
2. cold-string churn on the hot paths is materially narrower now:
   - `metadata_acquire(...)` is request-based
   - `snapshot_acquire(...)` is now also request-based for title/cwd
3. redraw/publication/present is still the right host loop, but only if hosts
   treat `redraw_state(...)` as the gate and avoid speculative snapshot pulls.
4. `pending_input_acquire(...)` is now the correct outbound batching seam for
   external transport and its avoidable extra copy has already been removed.

Downstream validation now supports that judgment too:

- Flutty adopted the request-based metadata shape cleanly
- Flutty adopted the request-based snapshot shape cleanly
- viewport-pinned snapshots now change visible snapshot content correctly on
  current `main`
- no widget/runtime fork or host-side workaround was needed for those cuts

## Hot-Path Findings

### 1. Snapshot Acquire Is The Main Remaining Boundary Cost

Current shape in [core_api.zig](/home/home/personal/zide/src/terminal/ffi/core_api.zig):

- allocates a `SnapshotOwner`
- allocates a copied flat cell array
- maps directly from the published render cache into the exported FFI cell
  buffer
- copies title only when requested
- copies cwd only when requested

Recent improvement:

- the earlier temporary published-`RenderCache` copy inside
  `snapshot_acquire(...)` is now gone
- snapshot export now also gathers optional title/cwd in the same locked pass
  as the published render-cache read instead of bouncing through
  `copyMetadata(...)`
- the dominant remaining cost is the one explicit flat FFI cell-buffer copy,
  not extra intermediate snapshot or metadata-copy passes before the final
  export

This is acceptable for the current milestone because it is explicit and easy to
bind, but it remains the biggest cost center on the host boundary.

Implication:

- do not widen snapshot use
- do not add “helpful” per-row/per-cell snapshot-side queries
- any future snapshot/diff work should be judged first by host call count and
  allocation pressure, not by ABI cleverness alone

### 2. Metadata Acquire Must Stay Latest-State, Not Per-Frame Habit

`metadata_acquire(...)` is structurally correct as the authoritative latest-state
summary, and it is now materially better for hot-path discipline because title
and cwd are opt-in through the request shape.

That is acceptable if hosts use it as intended:

- lifecycle/title/cwd/scrollback summary when needed
- not a per-frame scalar polling habit

Implication:

- current docs should keep steering hosts away from high-frequency metadata
  polling
- any future split beyond the current request-based shape should still be
  treated as an ABI-maturity step, not an excuse to widen the public surface
  casually
- the target should be "cheaper hot latest-state without stitched truth", not
  "many small convenience getters"

### 3. Redraw/Present Contract Is Still The Right Host Loop

The current narrow host loop is still the correct one:

1. `poll(...)`
2. `redraw_state(...)`
3. `snapshot_acquire(...)` only when redraw is pending
4. render
5. `present_ack(...)`

This remains the narrowest credible host boundary for a serious embedded host.

What would make it bad is not the model itself, but hosts layering extra calls
around it “just in case.”

Implication:

- `redraw_state(...)` stays the hot-path authority
- `needs_redraw(...)`, published-generation getters, and similar helpers should
  remain secondary/convenience surfaces, not the main loop contract

### 4. Pending Input Is Now The Right External-Transport Seam

External transport now has the correct shape:

- host-owned transport feeds backend output through `feed_output(...)`
- host-owned transport closes input through `close_input(...)`
- backend-owned outbound input/report traffic drains through:
  - `pending_input_acquire(...)`
  - `pending_input_release(...)`

The earlier extra copy inside `pending_input_acquire(...)` is now removed.

Implication:

- keep `pending_input` coarse and destructive
- do not let this drift into callback-style micro-notifications or per-key
  drain expectations

### 5. Event/Getter Overlap Must Stay Disciplined

The current contract is workable because latest-state truth is explicit:

- `metadata_acquire(...)`
- `redraw_state(...)`
- `close_confirm_signals(...)`
- `child_exit_status(...)`
- `clipboard_write(...)`

Events should remain wake/edge signals, not the primary state database.

Implication:

- do not add overlapping convenience APIs unless they clearly avoid host churn
- do not let downstream hosts reconstruct terminal truth by polling many narrow
  helpers every tick

## Rules For Future FFI Changes

1. Never require per-cell or per-row host calls on the visible hot path.
2. New hot-path exports must justify allocation behavior explicitly.
3. `redraw_state(...)` remains the gate for snapshot work.
4. `metadata_acquire(...)` remains latest-state, not a per-frame habit.
5. `pending_input(...)` remains the coarse outbound batching seam for external
   transport.
6. Events should wake hosts, not replace authoritative latest-state getters.
7. Snapshot/diff evolution should optimize host call count and allocation
   pressure first.
8. Do not widen the bridge just because native can reach an internal value more
   directly.
9. Prefer one authoritative getter over several overlapping convenience
   getters.
10. Any future ABI split between hot scalars and cold strings must improve
    boundary efficiency without forcing hosts into stitched truth.

## Immediate Next Step

The next bridge-performance lane should stay narrow:

- review snapshot transport shape
- define the hot-scalar vs cold-string maturity direction more explicitly
- compare one coherent successor acquire shape against one narrower getter-based
  alternative and reject the weaker one before coding
- if the coherent successor shape wins, keep it coarse:
  - one request struct
  - one owned result
  - string inclusion flags only
- because the bridge is still beta, do not preserve the first metadata surface
  just for compatibility aesthetics if the replacement is clearly better
- the current leading sketch is now explicit:
  - scalar metadata always filled
  - title/cwd behind inclusion flags
  - unconditional acquire/release ownership
- that request-based replacement is now the active metadata shape on `main`
- keep the public loop discipline explicit
- avoid widening the bridge until snapshot/diff direction is better defined

This means:

- no rushed diff ABI yet
- no callback expansion
- no convenience surfaces that make hosts chattier

The implied execution order is:

1. keep the current request-based metadata and snapshot shapes stable
2. treat full copied snapshot cells as the main remaining boundary-cost target
3. only widen the ABI again if a successor shape lowers cost without raising
   host call count or weakening authority

The next comparison should therefore stay narrow:

- diff-oriented export
- pinned-handle full-snapshot reuse

and reject anything that:

- increases hot-path host call count
- weakens the redraw-driven authority loop
- makes hosts reconstruct truth from multiple partial surfaces

Current paper preference:

- pinned-handle full-snapshot reuse is the better-looking next candidate
  today
- diff export still has more downside risk around host complexity and stitched
  truth unless it stays unusually disciplined

Current execution rule for that preference:

- do not treat "pinned" as permission to add a second render loop
- the candidate only stays attractive if hosts can keep the same hot loop:
  - `poll`
  - `redraw_state`
  - one visible acquire/pin
  - render
  - `present_ack`
  - one release/unpin
- `present_ack(...)` and snapshot release must stay distinct responsibilities:
  - presentation acknowledgement
  - memory/lifetime release
- reject the pinned direction if it requires extra helper chatter, host-managed
  generation fences, or deep publication-retention policy leaking into the
  public contract

Current implementation-oriented caution:

- the current publication path is built around the active render-cache slot and
  copy-based handoff, not a retained published-generation store
- that means pinned reuse is still plausible, but it is not yet "obviously
  cheap" in the existing ownership model
- if the real code path needs more than a small bounded retained-generation
  extension, the preference for pinned handles should be re-evaluated instead
  of forced

Current narrowest plausible implementation story:

- keep the current double-buffered publication flip path
- allow at most one extra retained published generation while pinned
- treat anything heavier than that as a sign that pinned reuse may no longer be
  the right next step

## Current Conclusion

The current redesign is performance-safe enough to continue building on.

The main remaining boundary-cost pressure point is now even more clearly:

- `snapshot_acquire(...)` flat cell-buffer allocation/copy cost

Everything else should be judged around that fact instead of broadening the
bridge in unrelated directions.
