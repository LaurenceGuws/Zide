# Rope Text Model Design

Goal: use a balanced rope/piece‑tree to achieve O(log n) edits and O(log n)
offset/line queries for large files, while supporting cheap snapshots and low
memory overhead.

Status (2026-01-27):
- Rope is the sole text model (`src/editor/rope.zig` + `src/editor/text_store.zig`).
- Rope undo/redo is implemented with per-op text snapshots.
- Undo batching merges adjacent inserts/deletes; undo groups are supported.
- File-open path now transfers ownership of the loaded file buffer into rope
  (`Rope.initOwnedOriginal`) to avoid duplicating large initial contents.
- File-open path now uses threshold-based mmap on supported platforms, with
  read-to-alloc fallback.
- Rope line-start lookups now use a bounded cache with eviction and edit-time
  invalidation to reduce repeated line offset traversals.
- Initial rope construction now chunks the original buffer into balanced
  ~2KiB leaves, avoiding pathological large-leaf line scanning during
  `lineStart`/offset queries.

## Current state (summary)
- Text buffer is a rope/piece‑tree with per-node aggregates for byte length and
  line breaks.
- Line/offset queries use rope aggregates (no background indexing thread).
- The editor uses `TextStore` as the single text interface.

## Rope model (implemented)

### Structure
- Balanced binary tree of nodes (rope/piece‑tree style).
- Leaf nodes store a slice of a backing buffer (`original` or `add`).
- Internal nodes store aggregate metadata for subtrees.

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
- Weight-balanced or AVL-style rotations (implementation-specific).
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

## Remaining work
- Unicode-aware indices (UTF‑16 units, grapheme boundaries).
- Snapshot optimizations (structural sharing / COW) for cheaper cloning.
- Optional mmap for large file reads.

## Open decisions
- Balance strategy (AVL vs weight-balanced) based on implementation effort.
- Leaf chunk size target and merge thresholds.
- Whether to keep a tiny cursor cache (like current `last_piece`).
