# Rope Text Model Design (Draft)

Goal: replace the current flat piece table with a balanced rope/piece-tree to
achieve O(log n) edits and O(log n) offset/line queries for large files, while
supporting cheap snapshots and low memory overhead.

Status (2026-01-21):
- Implemented core rope ops in `src/editor/rope.zig` (split/join/insert/delete/read).
- Added `TextStore` adapter in `src/editor/text_store.zig`; `Editor` + syntax
  highlighter now depend on the adapter and can switch implementations via
  `TextStoreKind` (default rope).
- Rope undo/redo implemented with per-op text snapshots (matches current
  piece-table behavior).
- Basic undo batching: adjacent inserts merge into a single undo op; adjacent
  deletes at the same position or just before the previous delete also merge.

## Current state (summary)
- Text buffer is a piece table with a flat `pieces` array.
- `findPiece` is linear (with a small cache), and insert/delete shift arrays.
- Line index is `line_starts` rebuilt or incrementally updated, with a
  background thread for file-backed buffers.

## Proposed rope model

### Structure
- A balanced binary tree of nodes (rope/piece-tree style).
- Leaf nodes store a slice of a backing buffer (`original` or `add`).
- Internal nodes store aggregate metadata for their subtrees.

### Node types
- `Leaf`: points to a backing buffer + start + len.
- `Internal`: left/right children + aggregates.

### Aggregates (per node)
- `byte_len`: total bytes in subtree.
- `line_breaks`: number of '\n' bytes in subtree.
- Future: `utf16_units`, `grapheme_count` (for caret/selection semantics).

These allow:
- byte offset -> (node, local offset) via descending by `byte_len`.
- line index -> byte offset via descending by `line_breaks`.

### Chunk sizing
- Target leaf payload size: 1–4 KiB (tunable).
- Splitting/merging keeps leaves near target size.
- Keeps per-edit work bounded and tree depth small.

### Balancing strategy
- Weight-balanced or AVL-style rotations.
- Keep it simple and deterministic (avoid complex rebalancing cost spikes).
- Store `height` (or `weight`) per node for balancing decisions.

### Backing buffers
- `original` = initial file contents (optional mmap later).
- `add` = append-only buffer for inserted bytes.
- Leaves reference either buffer by kind + range.

### Operations
- `split(node, offset) -> (left, right)`
- `concat(left, right) -> node` (with rebalance)
- `insert(offset, bytes)` = split + new leaf + concat
- `delete(range)` = split at start/end + drop middle + concat
- `read(range)` = traverse leaves and copy into output
- `line_count()` = 1 + root.line_breaks
- `line_start(line)` = descend by line_breaks to find byte offset

### Concurrency
- Single-writer. Optional snapshots via structural sharing (copy-on-write).
- Can add `Arc`-like refcounts later for cheap clones.

## Migration plan (phases)

Phase 0: Design + scaffolding
- Add `src/editor/rope.zig` with structs and APIs.
- Do not integrate with Editor yet.

Phase 1: Minimal rope backing
- Implement insert/delete/read/len.
- Build in-tree aggregates for byte_len + line_breaks.
- Keep editor working by swapping buffer implementation.

Phase 2: Indexing upgrades
- Add fast byte<->line conversions using aggregates.
- Remove `line_starts` array and background index thread.

Phase 3: Unicode-aware indices
- Track UTF-16 units and grapheme boundaries per node.
- Provide caret-safe movement and selections.

Phase 4: Snapshots + history
- Add copy-on-write snapshots for undo/redo batching.
- Enable cheap background saves and analysis tasks.

## Open decisions
- Balance strategy (AVL vs weight-balanced) based on implementation effort.
- Leaf chunk size target and merge thresholds.
- Whether to keep a tiny cursor cache (like current `last_piece`).
