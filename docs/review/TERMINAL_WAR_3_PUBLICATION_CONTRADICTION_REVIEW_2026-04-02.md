# Terminal War 3 Publication Contradiction Review 2026-04-02

## Purpose

Choose the first concrete War 3 contradiction to the target `zide-vt` shape.

Target shape:

- `TerminalCore` is the library center
- `session/runtime.zig` is runtime shell only
- `terminal_publication.zig` is export boundary only

## Current Read

The first concrete contradiction is not evenly split across runtime and
publication.

It is publication.

Why:

- [session/runtime.zig](/home/home/personal/zide/src/terminal/core/session/runtime.zig)
  is now relatively narrow and reads mostly like:
  - init/boot assembly
  - transport attach/open/close
  - thread and backlog lifecycle
  - PTY writer and resize
- [terminal_publication.zig](/home/home/personal/zide/src/terminal/core/publication/terminal_publication.zig)
  still reads like more than an export edge

It still owns a broad mixed slab of:

- generation state mutation
- view-refresh request/choreography
- cache publication flow
- render-cache access
- snapshot capture/export
- host-facing frame/generation summaries

That is too much gravity for something that is supposed to read like a boring
engine export boundary.

## Why This Matters

Against the War 3 target shape, the current live stack still reads like:

- engine center
- plus publication center
- plus runtime shell

instead of:

- engine center
- runtime shell
- export edge

That means publication is still the clearest blocker to first-glance
extractability of a serious `zide-vt`.

## Current Judgment

The first War 3 cut should start from publication, not runtime.

More specifically:

- the next move should identify the largest slab in
  [terminal_publication.zig](/home/home/personal/zide/src/terminal/core/publication/terminal_publication.zig)
  that is still engine-adjacent choreography rather than export boundary
- then remove that slab in one whole move

## Best Next Question

Which current publication slab is the biggest contradiction to "publication as
export boundary only"?

Current candidates:

1. generation mutation plus view-refresh choreography
2. render-cache storage/query center
3. snapshot capture/preparation center
4. host-facing summary packaging

## Bottom Line

War 3's first concrete contradiction is publication still reading like a real
center, not a boring edge.

Status note, later on 2026-04-02:

- the first whole-slab cut is now in
- generation mutation, view-refresh choreography, and output-pending flow no
  longer live in `terminal_publication.zig`
- that slab now lives in
  [publication_flow.zig](/home/home/personal/zide/src/terminal/core/publication/publication_flow.zig)
- callers were rewired directly to that owner instead of preserving
  `terminal_publication.zig` as the universal choreography surface

Status note, later on 2026-04-02 again:

- the second whole-slab cut is now in
- widget presentation capture/preparation no longer lives in
  `terminal_publication.zig`
- that slab now lives in
  [publication_capture.zig](/home/home/personal/zide/src/terminal/core/publication/publication_capture.zig)
- [terminal_widget.zig](/home/home/personal/zide/src/ui/widgets/terminal_widget.zig)
  now uses that owner directly for latest-presentation preparation
- publication now reads less like an active widget handoff center and more
  like a narrower export edge

Status note, later on 2026-04-02 once more:

- the third whole-slab cut is now in
- host-facing generation/frame summary packaging no longer lives in
  `terminal_publication.zig`
- that slab now lives in
  [publication_state.zig](/home/home/personal/zide/src/terminal/core/publication/publication_state.zig)
- host-facing consumers now use that owner directly:
  - [workspace_host.zig](/home/home/personal/zide/src/terminal/core/workspace_host.zig)
  - [terminal_poll_runtime.zig](/home/home/personal/zide/src/app/terminal/terminal_poll_runtime.zig)
- [workspace_polling.zig](/home/home/personal/zide/src/terminal/core/workspace_polling.zig)
  - FFI redraw-generation paths
- publication is now closer again to a render-cache/snapshot export edge than a
  host-summary center

Rerank point, later on 2026-04-02:

- `terminal_publication.zig` is now down to a much narrower shape
- the broad mixed-center contradiction is materially reduced
- what remains now reads mostly like:
  - snapshot/render-cache export
  - render-cache lookup for snapshot diff paths
  - sync-updates bridge logic
- the next honest question is no longer "is publication still a huge false
  center?"
- it is whether sync-updates belongs here at all, or is now a separate semantic
  ownership problem below the export boundary
- that means the next move should be a fresh War 3 rerank, not blind
  continuation inside publication by momentum

Status note, later on 2026-04-02 again after rerank:

- sync-updates no longer lives on the publication export edge
- that slab now lives in
  [sync_updates.zig](/home/home/personal/zide/src/terminal/core/protocol/sync_updates.zig)
- protocol callers and runtime tests now use that semantic owner directly
- `terminal_publication.zig` now reads even more narrowly as:
  - snapshot/render-cache export
  - render-cache lookup for snapshot diff paths
  - presentation feedback aliases
- publication is no longer the sync-updates semantic owner by habit
