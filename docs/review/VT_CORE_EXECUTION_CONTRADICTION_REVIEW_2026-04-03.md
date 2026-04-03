# VT Core Execution Contradiction Review

Date: 2026-04-03

## Purpose

Name the next exact `TerminalCore` maturity contradiction from the new VT
baseline.

The question is no longer:

- "is there another easy core sufficiency cut?"

The question is:

- what concrete dependency still keeps
  [TerminalCore](/home/home/personal/zide/src/terminal/core/terminal_core.zig)
  from feeling like a self-sufficient terminal object?

## Current Answer

The strongest remaining contradiction is now explicit:

- major core behaviors still depend on outer owner/publication choreography to
  become complete host-visible terminal behavior

This is stronger than:

- low-level title/cwd assembly exposure
- kitty cleanup dependence by itself
- any remaining shell file size discomfort

## Ranked Candidate List

### 1. Core execution still depends on outer owner/publication choreography

This is the top blocker.

Concrete evidence:

- [terminal_core.zig](/home/home/personal/zide/src/terminal/core/terminal_core.zig)
  still exposes major semantic verbs through owner-shaped calls:
  - `feedOutputBytesLocked(self, owner, bytes)`
  - `resizeLocked(_, owner, rows, cols)`
  - `resetState(self, owner)`
- [terminal_core_feed.zig](/home/home/personal/zide/src/terminal/core/protocol/terminal_core_feed.zig)
  still turns the core feed result into host-visible behavior by calling
  [publication_flow.publishFeedResultLocked(...)](/home/home/personal/zide/src/terminal/core/publication/publication_flow.zig)
- [selection.zig](/home/home/personal/zide/src/terminal/core/selection.zig)
  still wraps core selection mutation with
  `requestViewRefreshLocked(...)`
- [scrollback_view.zig](/home/home/personal/zide/src/terminal/core/scrollback_view.zig)
  still wraps core viewport mutation with
  `refreshScrollViewForOffsetChangeLocked(...)`
- [resize_reflow.zig](/home/home/personal/zide/src/terminal/core/resize_reflow.zig)
  still combines:
  - shell locking
  - optional cell metric staging
  - core resize
  - transport resize reporting

Why this is the top contradiction:

- Ghostty and WezTerm both make the terminal object feel more directly
  sufficient at the point where semantic work happens
- Zide already moved many semantic decisions into core
- what still weakens the first-glance story is that major core behavior still
  relies on adjacent owner choreography to become complete

### 2. Low-level protocol assembly still leaks through the core surface

This is real, but second-order.

Concrete evidence:

- [terminal_core.zig](/home/home/personal/zide/src/terminal/core/terminal_core.zig)
  still exposes:
  - `clearTitleBuffer(...)`
  - `appendTitleSlice(...)`
  - `publishTitleBuffer(...)`
  - `clearCwdBuffer(...)`
  - `appendCwdByte(...)`
  - `appendCwdSlice(...)`
  - `publishCwdBuffer(...)`
  - `truncateCwdBuffer(...)`
  - `cwdBufferLast(...)`

Why it is not first:

- this weakens the mature-library feel
- but it does not block the core as strongly as the execution-contract problem

### 3. Kitty/image cleanup still needs outer owner shape

This is narrower than the execution issue.

Concrete evidence:

- [terminal_core.zig](/home/home/personal/zide/src/terminal/core/terminal_core.zig)
  `deinit(...)` and `resetState(...)` still take an outer owner partly to
  clear kitty state
- [terminal_core_modes.zig](/home/home/personal/zide/src/terminal/core/terminal_core_modes.zig)
  still calls `kitty_mod.clearKittyImages(self)`

Why it is not first:

- this is a real dependency
- but it looks more like one subsystem-specific owner seam
- the broader contradiction is that multiple major semantic paths still depend
  on outer choreography, not just kitty

## What This Means

The next VT war should not be:

- "make the shell smaller"

It should be:

- make major terminal-semantic operations on `TerminalCore` stop needing outer
  owner/publication choreography as their completion story

That is the right bar because it changes the terminal-object feel, not just
the file layout.

## Replacement Shape Bar

The replacement must satisfy all of these:

1. `TerminalCore` owns the semantic operation result
2. outer layers consume explicit effects, rather than completing the operation
   implicitly through owner reach-through
3. locking remains outside core
4. transport/reporting remains outside core
5. publication refresh remains an explicit consumer of core effects, not an
   invisible part of core mutation

In other words:

- do not pull shell/runtime concerns into core
- do stop making the core depend on a generic outer owner to finish major work

## Best Opening Target

The best first target in this category looks like the feed/apply publication
path.

Why:

- the semantic feed verb is already on core
- the remaining contradiction is now sharply visible in
  [terminal_core_feed.zig](/home/home/personal/zide/src/terminal/core/protocol/terminal_core_feed.zig)
  and [publication_flow.zig](/home/home/personal/zide/src/terminal/core/publication/publication_flow.zig)
- it is narrower and more uniform than the whole resize or viewport/selection
  refresh story

Fallback target:

- selection/viewport refresh choreography

That lane has the same shape, but feed/apply is the more central terminal
behavior.

## Bottom Line

The next real VT maturity war is no longer vague `TerminalCore` discomfort.

It is this exact contradiction:

- `TerminalCore` still depends on outer owner/publication choreography for
  major semantic operations

That is the next thing worth deleting.
