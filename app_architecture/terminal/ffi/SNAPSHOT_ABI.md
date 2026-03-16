# Terminal FFI Snapshot ABI

Date: 2026-02-27

Purpose: define the first exported terminal snapshot contract for foreign hosts.

Status: milestone-1 baseline. This document describes the snapshot shape currently implemented by `src/terminal/ffi/bridge.zig`.

Current maturity note:

- milestone-1 still uses full-copy cells as the implemented baseline
- snapshot acquire is now request-based for cold copied strings
- metadata acquire is now also request-based for cold copied strings
- the next likely performance/maturity step is not "make snapshots cleverer at
  any cost"
- it is to separate hot latest-state scalars from cold copied strings more
  deliberately, without forcing hosts to stitch terminal truth together from a
  pile of tiny calls

## Goals

- Give foreign hosts a simple, explicit, render-friendly snapshot.
- Keep ownership rules obvious.
- Avoid hidden borrows across FFI boundaries.
- Prefer correctness and debuggability over zero-copy cleverness.

## Milestone 1 decision

Milestone 1 uses copied full snapshots with request-based string inclusion.

That means:
- snapshot acquisition allocates bridge-owned memory
- cell data is copied out of the internal terminal snapshot
- title and cwd strings are copied into bridge-owned memory only when requested
- the host must call `zide_terminal_snapshot_release()` exactly once per acquired snapshot

This is slower than a zero-copy design, but it is much safer for the first bridge.

Current hot-path reading:

- `snapshot_acquire(...)` still always copies the flat cell buffer
- `snapshot_acquire(...)` reads the published render cache and optional
  title/cwd in one locked pass
- `snapshot_acquire(...)` only copies title/cwd when requested
- `metadata_acquire(...)` always fills hot scalar latest-state and only copies
  title/cwd when requested

## Exported types

Current exported snapshot surface lives in:
- `src/terminal/ffi/bridge.zig`
- `src/terminal/ffi/c_api.zig`

Primary structs:
- `ZideTerminalCell`
- `ZideTerminalSnapshot`
- `ZideTerminalSnapshotRequest`

Snapshot header:
- `abi_version`
- `struct_size`

Current header values:
- `abi_version = 1`
- `struct_size = sizeof(ZideTerminalSnapshot)` for the library that produced it

Current scalar version query:
- `zide_terminal_snapshot_abi_version() -> 1`

Related renderer metadata helper:
- `zide_terminal_renderer_metadata_abi_version() -> 1`
- `zide_terminal_renderer_metadata(codepoint, &metadata)`

### `ZideTerminalCell`

Fields:
- codepoint
- combining_len
- width
- height
- x
- y
- combining_0
- combining_1
- fg
- bg
- underline_color
- bold
- blink
- blink_fast
- reverse
- underline
- link_id

Notes:
- this is intentionally flat and value-based
- it mirrors the internal cell model closely enough for host rendering or inspection
- it does not expose internal pointers

### `ZideTerminalSnapshot`

Fields:
- abi_version
- struct_size
- rows
- cols
- generation
- cell_count
- cells
- cursor_row
- cursor_col
- cursor_visible
- cursor_shape
- cursor_blink
- alt_active
- screen_reverse
- has_damage
- damage_start_row
- damage_end_row
- damage_start_col
- damage_end_col
- title_ptr/title_len
- cwd_ptr/cwd_len
- internal context pointer used only by release

Notes:
- hosts must validate `abi_version` before assuming the rest of the layout
- `struct_size` allows future append-only expansion without guessing which build produced the snapshot
- `cells` points to a flat array of `rows * cols` cells
- row-major order
- `title_ptr` and `cwd_ptr` are optional and may be null when len is zero
- `_ctx` is opaque release bookkeeping and not host data

## Ownership contract

Acquisition:
- host calls `zide_terminal_snapshot_acquire(handle, &request, &snapshot)`
- on success, the bridge owns all pointed-to memory until release
- the returned header identifies the snapshot layout that was filled

Release:
- host must call `zide_terminal_snapshot_release(&snapshot)`
- after release, all pointers inside the snapshot are invalid
- release zeroes the snapshot struct as a defensive measure

Invalid usage:
- retaining `cells`, `title_ptr`, or `cwd_ptr` after release
- mutating bridge-owned memory
- calling release twice on the same live snapshot without reacquiring

## Why copied snapshots were chosen first

The internal terminal snapshot is currently a borrowed-slice contract:
- valid for internal immediate use
- not suitable as-is for foreign callers

A copy-based export avoids these risks:
- host reads from stale internal memory after poll
- host retains pointers across backend mutation
- implicit allocator ownership leaks into the foreign API

This is the right tradeoff for the first host boundary.

## Damage semantics

Milestone 1 exports coarse damage metadata only:
- `has_damage`
- row/col bounds

Important:
- damage metadata is advisory
- the host must treat the full snapshot as authoritative
- hosts may ignore damage and redraw from the full cell buffer

Shared semantic authority now lives in:
- `app_architecture/terminal/rendering/RENDER_PUBLICATION_CONTRACT.md`

Snapshot `generation` remains publication truth only. It is intentionally kept
separate from host acknowledgement/presentation semantics.

Update:
- the first host-facing acknowledgement slice is now landed as explicit bridge
  calls:
  - `zide_terminal_present_ack(handle, generation)`
  - `zide_terminal_acknowledged_generation(handle, &generation)`
- the bridge now also exposes `zide_terminal_published_generation(handle, &generation)`
  so hosts can compare published vs acknowledged generation without forcing a
  snapshot acquire
- `zide_terminal_redraw_state(handle, &state)` so hosts can acquire both
  generations plus `needs_redraw` atomically in one cheap getter
- `zide_terminal_redraw_state_abi_version()` so redraw-state ABI validation
  follows the same query pattern as snapshot/event/scrollback/metadata surfaces
- and `zide_terminal_needs_redraw(handle)` so hosts can ask the cheap
  level-triggered question directly instead of deriving it themselves from
  multiple calls
- snapshot ABI itself is unchanged; the acknowledged-generation contract lives
  alongside snapshot acquisition instead of mutating the snapshot struct in
  milestone 1

This keeps the snapshot usable even while damage tracking evolves.

## Deliberate omissions in milestone 1

Not exported yet:
- dirty row arrays
- scrollback row-by-row diff payloads
- selection ranges
- hyperlink URI tables
- kitty image blobs or placement payloads

Reason:
- these are either not yet normalized for FFI or would expand scope beyond the first useful bridge slice

Note:
- explicit copied scrollback export is now provided via the dedicated buffer API
  (`zide_terminal_metadata_acquire`, `zide_terminal_scrollback_acquire`, `zide_terminal_scrollback_release`)
  so snapshot ABI remains viewport-only while hosts can consume history through a separate ownership contract.
- this structured history path is the authoritative history surface; the text
  exports (`selection_text`, `scrollback_plain_text`, `scrollback_ansi_text`)
  are convenience views for copied text, not replacements for structured
  history state
- those copied text buffers now also carry inline `abi_version` /
  `struct_size`, matching the stronger ABI discipline used by the other
  exported output surfaces
- likewise, `selection_text` is a copied-text convenience export because
  milestone 1 does not yet ship structured selection geometry/ranges as an
  authoritative bridge surface

## Renderer metadata helper (beta-safe extension)

To reduce host-side heuristics without changing snapshot or cell layout, bridge exports
an independent metadata query:
- input: one Unicode codepoint
- output: `ZideTerminalRendererMetadata` with:
  - glyph class flags (`box`, `box_rounded`, `graph`, `braille`, `powerline`, `powerline_rounded`)
  - damage policy flags (`advisory_bounds`, `full_redraw_safe_default`)

This keeps snapshot ABI stable while giving foreign renderers explicit routing hints for
special glyph paths and conservative damage handling.

## Host guidance

Recommended host behavior:
1. call `poll()`
2. query `zide_terminal_redraw_state(...)` and require `needs_redraw == 1`
3. acquire snapshot
4. verify `abi_version` and `struct_size`
5. render or inspect all rows
6. optionally use damage as a redraw hint
7. acknowledge the published generation with `zide_terminal_present_ack(...)`
8. verify redraw state cools off
9. release snapshot

If the host also needs lifecycle/title/cwd/scrollback latest-state truth, it
should use `zide_terminal_metadata_acquire(...)` instead of reconstructing that
state from multiple narrow getters alongside the snapshot.

Do not:
- cache raw snapshot pointers between polls
- assume any pointer remains valid after release

## Follow-on work

After the baseline copy-based path is proven, consider:
- diff-oriented row exports
- optional zero-copy pinned snapshot handles
- hyperlink and selection side tables
- kitty image metadata export if a real host needs it

These are extensions, not prerequisites for the first bridge.

## Current Maturity Direction

The current bridge now has enough real-host validation that the next snapshot
review can stay narrow and explicit.

Current behavior:

- `snapshot_acquire(...)` copies the flat cell buffer every time
- `snapshot_acquire(...)` now avoids both:
  - the old temporary published-`RenderCache` copy
  - the old snapshot-title/cwd bounce through `copyMetadata(...)`
- `snapshot_acquire(...)` duplicates title/cwd only when the request include
  flags ask for them
- `metadata_acquire(...)` always fills hot scalar latest-state such as:
  - `scrollback_count`
  - `scrollback_offset`
  - `alive`
  - `exit_code`
- `metadata_acquire(...)` duplicates title/cwd only when the request include
  flags ask for them

What should not happen next:

- do not add per-row or per-cell convenience queries
- do not split latest-state into many tiny getters that force host-side truth
  reconstruction
- do not widen the snapshot ABI just because native can reach internal fields
  more directly

What the next ABI-maturity step should optimize for instead:

1. keep `redraw_state(...) -> snapshot_acquire(...) -> present_ack(...)` as the
   authoritative render loop
2. keep `metadata_acquire(...)` as the authoritative latest-state summary
3. reduce avoidable cold-string copy pressure where possible
4. preserve one coherent latest-state surface instead of encouraging stitched
   host usage

So the live direction is:

- hot scalars should become cheaper to read
- cold copied strings should remain explicit and honest
- the bridge should only change shape if that lowers host call count or
  allocation pressure without weakening authority

### Next Snapshot Cost Decision

After the recent cleanup cuts, the next real snapshot-cost question is no
longer about cold strings. It is about the copied cell buffer itself.

The two leading directions worth comparing are:

1. diff-oriented export
2. pinned-handle full-snapshot reuse

Both should be judged against the same rules:

- no extra hot-path host chatter
- no weakening of the redraw-driven acquire/ack loop
- no host-side truth stitching
- no renderer-private assumptions leaking into the public bridge

### Candidate Comparison: Diff Export vs Pinned Snapshot Handle

#### Candidate A: Diff-Oriented Export

Shape:

- keep the current redraw gate
- add a new exported shape that returns changed rows/spans or a similar delta
  form instead of a full flat cell buffer on every acquire

Strengths:

- can reduce copied cell volume significantly when damage is small
- matches the intuition behind the current backend damage work

Main risks:

- easy to turn into a chatty or multi-call host contract
- easy to force hosts to keep more local reconstruction state
- harder to keep one obvious authoritative visible-state surface
- more likely to diverge between "fast path" and "full truth" semantics

Host impact:

- strongest risk is increased complexity in Flutter/Python/native host loops
- especially dangerous if hosts need both:
  - a diff stream for hot paint
  - a separate full snapshot or metadata path for authoritative truth

Judgment so far:

- promising only if it stays one acquire, one owned result, and one obvious
  visible-state authority
- high risk of violating the current "no extra host chatter, no stitched
  truth" rule if done casually

#### Candidate A Code-Reality Note

The current publication path already carries much of the raw material a diff
export would want:

- per-row dirty flags
- per-row dirty spans
- dirty column unions
- coarse damage bounds
- viewport shift hints
- visible-history-generation tracking
- row hashes for refinement

That means diff export is not blocked by an absence of backend change data.

What it is blocked by is contract shape:

- today the host consumes one authoritative visible snapshot
- a diff export becomes dangerous if it turns that into:
  - "sometimes read diffs"
  - "sometimes reacquire full truth"
  - "sometimes stitch local retained state yourself"

So the promising narrow version of diff export would have to look like:

- one acquire
- one owned diff result
- one generation
- enough data to deterministically update the previously rendered visible
  state
- an explicit fallback bit that says "this generation must be treated as a full
  visible refresh"

The unpromising version would look like:

- per-row follow-up calls
- row getters keyed by damage ranges
- separate calls for shift metadata, dirty spans, and replacement cells
- host-maintained truth that is more authoritative than the bridge result

Current code-oriented judgment:

- diff export now looks more plausible than it did on paper alone, because the
  backend already computes rich publication damage information
- its main risk is contract complexity, not backend data availability

#### Smallest Credible Diff Shape

The smallest plausible diff result should look more like a coarse publication
packet than a row-query protocol.

Conceptually:

```c
typedef struct ZideTerminalSnapshotDiffRequest {
    uint32_t abi_version;
    uint32_t struct_size;
    uint64_t base_generation;
    uint32_t reserved0;
    uint32_t reserved1;
} ZideTerminalSnapshotDiffRequest;

typedef struct ZideTerminalSnapshotDiffRow {
    uint32_t row;
    uint16_t span_count;
    uint8_t span_overflow;
    uint8_t reserved0;
    uint32_t first_span_index;
    uint32_t first_cell_index;
    uint32_t cell_count;
} ZideTerminalSnapshotDiffRow;

typedef struct ZideTerminalSnapshotDiffSpan {
    uint16_t start_col;
    uint16_t end_col;
} ZideTerminalSnapshotDiffSpan;

typedef struct ZideTerminalSnapshotDiff {
    uint32_t abi_version;
    uint32_t struct_size;
    uint64_t generation;
    uint64_t base_generation;
    uint32_t rows;
    uint32_t cols;
    uint8_t full_refresh_required;
    uint8_t alt_active;
    uint8_t screen_reverse;
    uint8_t has_damage;
    uint32_t damage_start_row;
    uint32_t damage_end_row;
    uint32_t damage_start_col;
    uint32_t damage_end_col;
    int32_t viewport_shift_rows;
    uint8_t viewport_shift_exposed_only;
    uint8_t reserved1[3];
    const ZideTerminalSnapshotDiffRow *rows_ptr;
    size_t row_count;
    const ZideTerminalSnapshotDiffSpan *spans_ptr;
    size_t span_count;
    const ZideTerminalCell *cells_ptr;
    size_t cell_count;
    void *_ctx;
} ZideTerminalSnapshotDiff;

int zide_terminal_snapshot_diff_acquire(
    ZideTerminalHandle *handle,
    const ZideTerminalSnapshotDiffRequest *request,
    ZideTerminalSnapshotDiff *out_diff);

void zide_terminal_snapshot_diff_release(ZideTerminalSnapshotDiff *diff);
```

Intended semantics:

- `base_generation` is the visible generation the host believes it has already
  rendered
- success always returns one owned diff result
- `full_refresh_required = 1` means:
  - ignore row/span delta application
  - treat `cells_ptr` as a full visible replacement for `generation`
- `full_refresh_required = 0` means:
  - rows/spans/cells deterministically update the previously rendered visible
    state from `base_generation` to `generation`

#### Base-Generation Admission Rule

The first diff cut should not invent a vague "best effort" admission rule.

Current preferred rule:

- `base_generation == 0` means the host does not currently claim a reusable
  visible base
- in that case the backend may still return a diff result, but it must set:
  - `full_refresh_required = 1`
- hosts should normally establish initial visible truth through the existing
  full snapshot path before relying on granular diff application

Why this is better than trying to be clever:

- it avoids hidden assumptions about host-local retained state
- it keeps the diff contract honest when the backend cannot trust the host's
  prior visible generation
- it avoids a second admission handshake API

So the first diff lane should treat these as equivalent triggers for fallback:

- host provides no usable base generation
- host provides a stale/unknown base generation
- backend decides granular diff packaging is not worth it for this transition

#### Full-Refresh Fallback Semantics

`full_refresh_required` must stay boring and deterministic.

Meaning:

- the backend is explicitly saying:
  - "do not trust row/span delta application for this generation"
  - "replace the host's visible state outright for `generation`"

Host rule:

1. if `full_refresh_required = 1`, ignore diff-row/span application entirely
2. treat `cells_ptr` as a full visible replacement payload
3. replace local visible state for `generation`
4. `present_ack(generation)`
5. release the diff result

Backend rule:

- fallback is allowed whenever the backend decides diff packaging would be
  larger, more complex, or less authoritative than a full visible replacement
- fallback must not require a second acquire
- fallback must not require a second result type
- fallback must not force the host to call back for "the real full snapshot"

This is what keeps diff export from degenerating into a two-surface protocol.

Current first-cut fallback triggers should be explicit:

1. `base_generation == 0`
2. `base_generation !=` the backend's current acknowledged/published visible
   base expectation for the requesting host
3. visible geometry changed
4. alt-screen transition occurred
5. visible-history generation or scrollback-offset transition makes the visible
   base relationship non-trivial
6. viewport-shift publication metadata would be required to describe the update
   honestly
7. computed diff packaging would be larger than, or close enough to, a full
   visible replacement that the complexity is not justified
8. row-span overflow / damage shape would make the granular packet misleading
   or too broad

These triggers do not need to stay permanent forever, but the first diff cut
should bias toward falling back too often rather than shipping a fragile diff
packet that hosts cannot trust.

#### Viewport-Shift Rule

The current backend publication path already tracks:

- `viewport_shift_rows`
- `viewport_shift_exposed_only`

That does not mean the first diff ABI should expose and rely on them.

Current preferred first-cut rule:

- if a transition depends on viewport-shift semantics to stay efficient or
  correct, set `full_refresh_required = 1`
- do not make hosts implement shift-aware patching in the first diff cut

Why:

- shift-aware diff is a second layer of contract complexity
- it is easier to add later than to remove after hosts depend on it
- the first diff ABI should prove row/span replacement first, not movement
  semantics

So:

- viewport-shift metadata may stay in research vocabulary
- but it should not be part of the first implementation's success path

#### Alt-Screen And Visible-History Transition Rule

Current preferred first-cut rule:

- entering alt-screen: fallback
- leaving alt-screen: fallback
- transitions that change `visible_history_generation`: fallback
- scrollback pin/follow-live transitions that invalidate the assumed visible
  base: fallback

Why:

- these transitions are exactly where "one obvious visible-state story" is
  easiest to lose
- full refresh is cheap insurance against a first diff ABI that becomes
  semantically subtle too early

This means the first diff cut is deliberately narrower than the backend's
internal publication logic:

- normal same-mode visible-state updates may use granular diff
- mode or viewport-identity transitions should bias toward full replacement

#### String Policy

Current preferred rule is stronger now:

- first diff cut should omit title/cwd entirely
- lifecycle/title/cwd latest-state remains owned by `metadata_acquire(...)`
- diff export should stay focused on visible cell-state transition only

Why:

- title/cwd are not part of visible cell-delta authority
- including them weakens the hot-path discipline we just recovered in metadata
  and snapshot request shapes
- omitting them entirely makes the first diff cut easier to reason about and
  easier to keep cheap

If a later diff-adjacent debug surface needs copied strings, it should be
argued separately instead of riding along in the first diff ABI.

#### Replacement Cell Ordering

Replacement cell order must be fully deterministic.

Rule:

- `rows_ptr` defines the outer ordering
- each row consumes spans from `spans_ptr[first_span_index .. first_span_index + span_count]`
- replacement cells for that row are packed in exactly that span order
- within each span, replacement cells are packed left-to-right from
  `start_col` through `end_col`

That means a host can apply the packet with one linear walk:

1. iterate diff rows in `rows_ptr` order
2. for each row, iterate its spans in `spans_ptr` order
3. consume replacement cells in the same order

No host-side searching or re-sorting should ever be required.

Important constraint:

- the host still gets one acquire and one release
- it does not ask follow-up questions per row
- the diff result itself must be sufficient to update visible truth or to say
  "fallback to full visible refresh now"

#### Why This Shape Is Narrow Enough To Judge

This shape tries to spend complexity inside one owned result instead of across
many calls:

- rows identify which visible rows changed
- spans describe the changed regions inside those rows
- cells provide the replacement visible cells in row/span order
- coarse damage and viewport-shift metadata stay alongside the same result
- the full-refresh fallback bit avoids pretending diff can represent every
  generation cheaply

That keeps the host loop conceptually stable:

1. `poll(...)`
2. `redraw_state(...)`
3. one diff acquire
4. either:
   - apply diff to local visible state
   - or replace visible state from the fallback full refresh payload
5. `present_ack(...)`
6. release diff result

#### Main Review Gate For Diff

Do not implement diff export unless this stays true:

1. one acquire
2. one owned result
3. one release
4. no row-follow-up getters
5. no second authoritative visible-state path outside the diff result itself
6. full-refresh fallback remains explicit and boring when the diff path is not
   worth it
7. title/cwd stay out of the first diff ABI entirely
8. replacement cell ordering is fully deterministic from the packet alone
9. no trusted base generation means explicit fallback, not best-effort diff
10. viewport-shift and alt/history transitions may fall back instead of forcing
    movement-aware diff semantics into the first cut
11. freshly started PTY/session output may stay on full-refresh fallback until
    the startup full-dirty baseline has actually been presented and retired
12. if a newer visible-state update is still chained to an unretired full-dirty
    publication, full-refresh fallback remains correct even when the latest row
    rewrite itself looks granular in isolation

#### Candidate B: Pinned Snapshot Handle

Shape:

- keep the redraw-driven loop
- acquire a pinned snapshot handle over published state
- release invalidates all interior pointers explicitly
- host reads a full visible snapshot shape without paying a flat cell copy on
  every acquire

Strengths:

- preserves the current full-snapshot mental model better
- keeps one authoritative visible-state surface
- lower risk of turning the host API into many narrow calls
- aligns more naturally with the existing acquire/release ownership pattern

Main risks:

- lifetime and mutation rules must stay extremely explicit
- backend publication/present sequencing must not let hosts observe unstable or
  concurrently mutating memory
- may increase pinning/retention pressure if hosts misuse the handle lifetime

Host impact:

- lower host-loop complexity than diff export if the acquire/release contract
  stays boring
- better fit for current Flutter/Python usage because the render loop remains
  "one redraw gate, one acquire, one render, one ack"

Judgment so far:

- structurally closer to the current successful host contract
- currently the safer-looking direction if the implementation can keep
  lifetimes explicit and published-state pinning honest

### Current Preference

Current provisional preference is now:

1. diff-oriented export first
2. pinned snapshot handle second

Reason:

- diff export already matches data the backend computes today
- pinned snapshots now carry two separate implementation risks:
  - retained-generation pressure
  - per-generation FFI cell remap pressure
- a disciplined diff packet can still preserve one acquire, one owned result,
  and one authoritative visible-state story without asking the backend to grow
  a retained published-generation store first

What would change that preference back:

- a pinned design that proves one retained generation is enough
- and avoids most per-generation cell remap cost in real code
- or a diff design that cannot stay self-contained without creating a forked
  "fast diff path" versus "real full snapshot truth" model

### Candidate B Contract Sketch: Pinned Snapshot Handle

If the bridge takes the pinned-snapshot route, the smallest credible shape
should still preserve the current host loop:

1. `poll(...)`
2. `redraw_state(...)`
3. acquire visible snapshot state once
4. render
5. `present_ack(...)`
6. release any pinned snapshot handle

The point is not to invent a second render loop. The point is to stop paying
the flat visible-cell copy when a host can safely read the already-published
visible snapshot.

#### Intended Shape

Conceptually:

```c
typedef struct ZideTerminalPinnedSnapshotRequest {
    uint32_t abi_version;
    uint32_t struct_size;
    uint32_t include_flags;
    uint32_t reserved0;
} ZideTerminalPinnedSnapshotRequest;

typedef struct ZideTerminalPinnedSnapshot {
    uint32_t abi_version;
    uint32_t struct_size;
    uint32_t generation;
    uint32_t rows;
    uint32_t cols;
    uint32_t cell_count;
    const ZideTerminalCell *cells;
    uint32_t cursor_row;
    uint32_t cursor_col;
    uint8_t cursor_visible;
    uint8_t cursor_shape;
    uint8_t cursor_blink;
    uint8_t alt_active;
    uint8_t screen_reverse;
    uint8_t has_damage;
    uint32_t damage_start_row;
    uint32_t damage_end_row;
    uint32_t damage_start_col;
    uint32_t damage_end_col;
    const uint8_t *title_ptr;
    size_t title_len;
    const uint8_t *cwd_ptr;
    size_t cwd_len;
    void *_ctx;
} ZideTerminalPinnedSnapshot;

int zide_terminal_snapshot_pin(
    ZideTerminalHandle *handle,
    const ZideTerminalPinnedSnapshotRequest *request,
    ZideTerminalPinnedSnapshot *out_snapshot);

void zide_terminal_snapshot_unpin(ZideTerminalPinnedSnapshot *snapshot);
```

Notes:

- request flags should stay the same coarse string-inclusion model used by the
  copied snapshot surface
- `cells` should point at a publication-owned visible snapshot, not live screen
  state
- this should be a sibling replacement candidate for `snapshot_acquire(...)`,
  not an excuse to keep adding parallel snapshot families forever

#### Lifetime Rules

Pinned snapshot safety has to be stricter than the current copied snapshot
surface.

Required rules:

- pin always binds to one already-published visible generation
- the host must not retain any pointer from the pinned snapshot after unpin
- a pinned snapshot must not expose mutable or in-progress publication state
- publication of a newer generation must not invalidate a still-pinned older
  snapshot until unpin
- title/cwd, when requested, must obey the same lifetime as the pinned
  snapshot handle itself

Host-visible rule:

- `generation` remains the published generation being rendered
- `present_ack(...)` still acknowledges that generation
- `snapshot_unpin(...)` releases read ownership of the published visible data

This means `present_ack(...)` and `snapshot_unpin(...)` are different:

- `present_ack(...)` is presentation contract truth
- `snapshot_unpin(...)` is memory/lifetime release

They may happen in either order, but hosts should normally:

1. render from the pinned snapshot
2. `present_ack(generation)`
3. `snapshot_unpin(...)`

That keeps the current loop boring and explicit.

#### Publication Interaction

For this shape to stay credible, publication ownership must remain simple:

- publication still produces one authoritative visible snapshot per generation
- redraw still means "a newer published generation exists than the one the host
  has acknowledged"
- pinning a published generation must not require the host to hold the session
  lock while reading cells
- backend publication may need small retention pressure, but not host-visible
  staging complexity

The expected backend implication is:

- keep a bounded publication-owned snapshot/cache generation alive while pinned
- reject any design that turns one pin into unbounded retention or deep
  generation history

Current code-reality note:

- today publication is centered on the active render-cache slot selected by
  `render_cache_index`
- visible-state publication is refreshed by `view_cache.updateViewCacheNoLock`
  into one of the session-owned render caches
- `snapshot_acquire(...)` can read that published cache directly because it
  immediately copies cells into FFI-owned memory
- pinned reuse is harder because the current publication path does not yet
  expose an obvious retained generation store; it exposes the currently
  published cache plus copy-based handoff

So the likely implementation consequence is:

- pinned snapshots would probably need one additional retained publication slot
  or another bounded generation-retention mechanism
- if that requires more than a small bounded extension of the current
  publication cache ownership model, the design stops looking "narrow"
  quickly

Current judgment after the code read:

- pinned handles remain viable
- but they are no longer the leading candidate
- the next review would have to prove that "one retained published generation
  while pinned" is enough and still materially better than the diff path

### Smallest Retained-Generation Extension

The most plausible narrow implementation shape now looks like this:

1. keep the current two render caches as the active publication flip path
2. add at most one extra retained published snapshot/cache slot for pinning
3. only populate that retained slot when a host actually pins a generation that
   would otherwise be overwritten by the next publication flip
4. free that retained slot as soon as the last pin on that generation is
   released

Why this is the smallest believable extension:

- `view_cache.updateViewCacheNoLockTagged(...)` already publishes by writing
  into the inactive render cache and then flipping `render_cache_index`
- that means the active published view is cheap to read, but the previously
  published generation is not guaranteed to survive another publication flip
- one bounded retained slot would let the bridge preserve a still-pinned
  visible generation without pretending it has a general publication history

What this design should not become:

- a ring of many retained published generations
- host-visible generation-retention policy
- several pin classes or pin-time filtering options
- a second visible-state authority separate from the current published view

The resulting backend rule would be:

- zero pins: existing publication path unchanged
- one pinned old generation: retain one extra published snapshot/cache until
  unpin
- anything beyond that should be treated as evidence that the design is no
  longer narrow enough

### Practical Review Questions

Before implementation, the next code-oriented review should answer:

1. Can one retained slot actually cover the worst legal host ordering?
   Example:
   - host pins generation `N`
   - backend publishes `N+1`
   - host has not unpinned `N` yet
2. Can the retained slot be filled without copying more total data than the
   current exported full-snapshot copy path would have?
3. Does alt-screen or viewport-pinned publication need any different retention
   treatment, or can it use the same retained visible-cache rule?
4. Can the bridge reject or serialize multiple simultaneous pins cleanly if
   needed, instead of silently growing retention complexity?

If the answers trend toward "needs more than one retained slot" or "still
copies almost as much as the current full export path," the pinned direction
should lose priority quickly.

### Cell Layout Reality

There is one more non-trivial pressure point in the current code:

- published render caches store internal `types.Cell`
- the public FFI snapshot surface exports `shared.Cell`
- current snapshot export bridges that difference explicitly through
  `mapCell(...)`

That means a pinned design only avoids the current hot-path cost if one of
these becomes true:

1. the bridge exposes pinned internal cells directly, which is a much riskier
   ABI coupling and not the current preference
2. the backend maintains a retained FFI-shaped cell buffer per published
   generation, which still requires one full visible-cell mapping pass per
   generation

Current implication:

- if disciplined hosts only acquire one visible snapshot per published
  generation, a retained FFI-shaped pinned snapshot may not beat the current
  full-copy baseline by much
- it would mainly help if hosts reread the same generation multiple times or
  if it enables some future reuse strategy that is still narrower than a diff
  export

Current judgment after the layout check:

- pinned handles are still viable
- but they no longer have an obvious cost advantage unless they avoid not only
  retention sprawl, but also most of the per-generation cell remap work
- that is enough to move them behind diff export provisionally

### Updated Preference

Current head-to-head read now favors diff export provisionally:

- diff export already fits the backend's publication data better
- pinned snapshots require more structural change before they clearly reduce
  total hot-path cost
- both candidates can still lose if they violate the same three rules:
  - one acquire
  - one owned result
  - one obvious authoritative visible-state story

Current tie-breaker to watch:

- diff keeps the lead if the diff packet can stay self-contained with an
  explicit full-refresh fallback
- pinned can retake the lead only if it proves both:
  - one retained generation is enough
  - per-generation cell remap pressure falls enough to matter

#### Why This Still Beats Diff On Paper

Pinned snapshots still look better than diff export if they can preserve these
properties:

- one redraw gate
- one visible-state acquire
- one obvious authoritative visible surface
- no host-side reconstruction of terminal truth

If the only way to make pinned snapshots work is to expose several competing
snapshot buffers, complicated generation fences, or host-managed retention
policy, that advantage disappears quickly.

#### Review Gate

Do not implement this shape unless the paper contract can still answer "yes" to
all of these:

1. Can a Flutter host keep the same redraw-driven loop shape?
2. Can a Python smoke host consume the surface without tricky lifetime glue?
3. Can the bridge avoid turning publication into multi-generation retention
   sprawl?
4. Does one pin still correspond to one obvious authoritative visible
   generation?
5. Is host call count still effectively:
   - `poll`
   - `redraw_state`
   - one snapshot acquire/pin
   - `present_ack`
   - one snapshot release/unpin

If any of those answers turns into "only with extra helper chatter," this
candidate should lose its current preference.

### Smallest Credible Future Shape

If the bridge evolves this lane, the first useful shape should be small and
authority-preserving.

Good direction:

- keep `ZideTerminalMetadata` as the one authoritative latest-state summary
- introduce an append-only way to separate:
  - hot scalar latest-state
  - cold copied strings
- let hosts read hot latest-state without forcing title/cwd duplication every
  time

Bad direction:

- replacing `metadata_acquire(...)` with many tiny getters
- making hosts reconstruct lifecycle/title/cwd/scrollback truth from separate
  calls
- mutating the host render loop so snapshot pulls become the only way to read
  lifecycle or scrollback scalar state

So the next shape, if it happens, should still preserve:

1. one authoritative redraw gate:
   - `redraw_state(...)`
2. one authoritative latest-state summary:
   - request-based `metadata_acquire(...)`
3. one authoritative presentation acknowledgement:
   - `present_ack(...)`

The question is not whether latest-state should fragment. The question is how to
let hot scalars get cheaper while the host still sees one coherent latest-state
surface.

### Current ABI Constraint

The current `ZideTerminalMetadata` layout already includes:

- hot scalars:
  - `scrollback_count`
  - `scrollback_offset`
  - `alive`
  - `has_exit_code`
  - `exit_code`
- cold copied strings:
  - `title_ptr/title_len`
  - `cwd_ptr/cwd_len`

That means a simple append-only tail on the existing struct is not enough, by
itself, to remove current cold-string duplication cost.

Why:

- `metadata_acquire(...)` currently implies one full latest-state fill
- title/cwd are already part of that baseline filled contract
- adding more fields at the tail can extend the shape, but it cannot on its own
  tell the backend "hot scalars only for this acquire"

So the first credible evolution, if needed, was more likely to be:

1. a replacement acquire shape with explicit options or flags for string
   inclusion
2. not a simple append-only struct tail pretending to solve the cold-string
   cost problem

What should still be avoided:

- separate title getter + cwd getter + lifecycle getter + scrollback getter as
  the normal host loop
- making hosts branch between several competing "real metadata" surfaces

The important design constraint is:

- one authoritative latest-state surface should remain obvious
- cheaper hot-state reads should come from a controlled successor shape, not
  from accidental getter proliferation

### Historical Candidate Successor Shapes

Before the request-based metadata cut landed, the two main candidates were:

#### Candidate A: Metadata Acquire V2 With Inclusion Flags

Shape:

- keep the current `metadata_acquire(...)` role
- add a successor acquire entrypoint that accepts explicit inclusion flags, for
  example:
  - hot scalars only
  - include title
  - include cwd
- return one owned metadata result with the same latest-state authority role

Why this is attractive:

- keeps one coherent latest-state acquire surface
- lets hosts pay for cold strings only when they actually need them
- fits the current host guidance well:
  - redraw-driven snapshot loop stays unchanged
  - metadata remains the summary/state authority when needed

Main risk:

- this is not a free append-only struct tweak; it is a deliberate successor
  acquire shape and therefore needs careful naming/ownership/docs

#### Candidate B: Keep Current Metadata And Add Narrow Hot-State Getter

Shape:

- leave `metadata_acquire(...)` unchanged
- add one separate hot-state getter for the scalar subset only

Why it is tempting:

- cheap to explain
- likely smaller ABI delta

Why it is weaker:

- creates two competing latest-state paths too early
- increases the risk that hosts start stitching lifecycle/scrollback/title/cwd
  truth together conditionally
- is much closer to the getter proliferation pattern we already want to avoid

### Current Result

Candidate A won and is now the active shape on `main`.

Reason:

- it preserves one authoritative latest-state surface better
- it aligns better with the reference bias from Ghostty/WezTerm/Kitty:
  - explicit boundary
  - narrow hot path
  - no chatty convenience explosion

Current non-goal:

- do not reopen Candidate B unless the shared-host contract changes materially

Beta-stage release rule:

- the bridge is still early beta and should not preserve the first metadata
  acquire shape purely out of inertia
- if Candidate A is clearly better, it is acceptable to replace the initial
  shape directly rather than carry both forms indefinitely
- what still matters is not compatibility theater, but keeping the cut narrow,
  explicit, and easy for real hosts to adopt

### Landed Request-Based Metadata Shape

The landed metadata shape now looks like this conceptually:

1. new acquire request struct
   - `abi_version`
   - `struct_size`
   - `include_flags`
2. metadata acquire entrypoint
   - `metadata_acquire(handle, request, out_metadata)`
3. metadata result
   - preserves the current hot scalar fields
   - preserves one owned-result release model
   - includes title/cwd only when requested

Suggested inclusion flags:

- `ZIDE_TERMINAL_METADATA_INCLUDE_TITLE`
- `ZIDE_TERMINAL_METADATA_INCLUDE_CWD`
- `ZIDE_TERMINAL_METADATA_INCLUDE_ALL_STRINGS`

Default intended host usage:

- hot latest-state polling path:
  - request no string flags
- title/cwd refresh path:
  - request title/cwd only when the host actually needs them
- broad one-shot inspection/debug path:
  - request all strings explicitly

Guardrails:

- no flags for tiny scalar subsets; hot scalars remain one coherent block
- no flags that mutate redraw/publication semantics
- no host expectation that `metadata_acquire(...)` belongs in the render
  loop
- release semantics should stay exactly as boring as the current acquire/release
  model

This keeps the design narrow:

- one latest-state authority surface
- one owned release model
- one explicit opt-in for cold copied strings

If this ships during the current beta phase, the preferred landing shape is:

- replace the original metadata acquire path cleanly
- update hosts to the new explicit request/result form
- avoid carrying both the old and new forms unless the overlap is temporary and
  actively being removed

### Landed ABI Sketch

The landed shape is:

```c
typedef struct ZideTerminalMetadataRequest {
    uint32_t abi_version;
    uint32_t struct_size;
    uint32_t include_flags;
    uint32_t reserved0;
} ZideTerminalMetadataRequest;

typedef struct ZideTerminalMetadata {
    uint32_t abi_version;
    uint32_t struct_size;
    uint32_t scrollback_count;
    uint32_t scrollback_offset;
    uint8_t alive;
    uint8_t has_exit_code;
    uint8_t _padding0[2];
    int32_t exit_code;
    const uint8_t *title_ptr;
    size_t title_len;
    const uint8_t *cwd_ptr;
    size_t cwd_len;
    void *_ctx;
} ZideTerminalMetadataV2;

int zide_terminal_metadata_acquire(
    ZideTerminalHandle *handle,
    const ZideTerminalMetadataRequest *request,
    ZideTerminalMetadata *out_metadata);

void zide_terminal_metadata_release(ZideTerminalMetadata *metadata);
```

Suggested flags:

```c
enum {
    ZIDE_TERMINAL_METADATA_INCLUDE_TITLE = 1u << 0,
    ZIDE_TERMINAL_METADATA_INCLUDE_CWD = 1u << 1,
    ZIDE_TERMINAL_METADATA_INCLUDE_ALL_STRINGS =
        ZIDE_TERMINAL_METADATA_INCLUDE_TITLE |
        ZIDE_TERMINAL_METADATA_INCLUDE_CWD,
};
```

Expected semantics:

- hot scalar fields are always filled
- `title_ptr/title_len` are only populated when `INCLUDE_TITLE` is requested
- `cwd_ptr/cwd_len` are only populated when `INCLUDE_CWD` is requested
- omitted strings must come back as:
  - `ptr = null`
  - `len = 0`
- release remains unconditional and boring even when no strings were requested

Why this sketch is intentionally conservative:

- the result shape still looks familiar to current hosts
- the request shape is coarse and stable
- there is no per-field scalar flag soup
- ownership stays acquire/release, not borrowed conditional pointers

Current rule:

- request-based `metadata_acquire(...)` is now the only metadata latest-state
  surface
- the original no-request acquire form is gone

It does not create:

- separate title and cwd getter APIs
- per-field opt-in churn
- another redraw gate
- another event family

### Landed Request-Based Snapshot Shape

The landed snapshot shape now also uses a request:

1. new acquire request struct
   - `abi_version`
   - `struct_size`
   - `include_flags`
2. snapshot acquire entrypoint
   - `snapshot_acquire(handle, request, out_snapshot)`
3. snapshot result
   - preserves the current copied cell buffer
   - preserves one owned-result release model
   - includes title/cwd only when requested

Suggested inclusion flags:

- `ZIDE_TERMINAL_SNAPSHOT_INCLUDE_TITLE`
- `ZIDE_TERMINAL_SNAPSHOT_INCLUDE_CWD`
- `ZIDE_TERMINAL_SNAPSHOT_INCLUDE_ALL_STRINGS`

Default intended host usage:

- hot redraw-driven path:
  - request no string flags
- title/cwd-aware inspection path:
  - request title/cwd only when the host actually wants them in the snapshot

Expected semantics:

- rows/cols/cells/cursor/damage/generation are always filled
- `title_ptr/title_len` are only populated when `INCLUDE_TITLE` is requested
- `cwd_ptr/cwd_len` are only populated when `INCLUDE_CWD` is requested
- omitted strings must come back as:
  - `ptr = null`
  - `len = 0`
- release remains unconditional and boring even when no strings were requested

This keeps the snapshot cut narrow:

- no per-row/per-cell micro-queries
- no separate title/cwd snapshot getters
- no redraw contract change
- no second snapshot surface carried in parallel during beta
