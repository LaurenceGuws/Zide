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

Current paper preference is:

1. pinned snapshot handle first
2. diff-oriented export second

Reason:

- it preserves the current authority model better
- it is less likely to raise host call count
- it is less likely to force hosts into local truth reconstruction

What would change that preference:

- strong evidence that pinned snapshots create unacceptable publication
  lifetime pressure or lock/retention hazards
- or a diff design that stays one acquire, one owned result, and one obvious
  visible-state authority without bifurcating the host loop

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
