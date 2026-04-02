# VT War 4 Stop Marker

Date: 2026-04-03

## Purpose

Mark the honest stopping point for the current War 4 implementation wave.

War 4 was opened to answer whether one real host-to-terminal interaction
contradiction still blocked a stronger `zide-vt` library story.

That question has now produced real results.

## What Landed

### 1. Output feed / apply

- [TerminalCore](/home/home/personal/zide/src/terminal/core/terminal_core.zig)
  now owns the semantic `feedOutputBytesLocked(...)` verb
- runtime/debug parse paths now use that same core-owned verb
- locking and publication stayed outside core

### 2. Resize / report contract

- [TerminalCore](/home/home/personal/zide/src/terminal/core/terminal_core.zig)
  now owns the semantic `resizeLocked(...)` verb
- [resize_reflow.zig](/home/home/personal/zide/src/terminal/core/resize_reflow.zig)
  still owns shell locking and transport/reporting

These are real interaction-ownership wins, not cosmetic shuffles.

## What Did Not Produce A Clean Immediate Cut

The third candidate, encoded host input semantics, did not yield a safe direct
move from this baseline.

Current read:

- text/byte send is too writer-shaped
- focus/color-scheme reporting is too report-to-writer shaped
- mouse reporting is tightly coupled to writer protocol encoding
- the only plausible next candidate is key/char semantic dispatch before
  writer encoding

But that still needs a deeper design step before code.

## Current Judgment

War 4 should stop here unless we explicitly choose to open that deeper design
step for key/char semantic dispatch.

Why:

- the first two slabs were real and clean
- the next one is not yet clean enough
- continuing by momentum would likely create a weaker abstraction than the
  contradictions we already removed

## Bottom Line

War 4 is now at a legitimate stop-marker.

Continue only if the next move is explicitly:

- a design-first key/char semantic-dispatch review

That deeper design step is now captured in:

- [VT_WAR_4_KEYCHAR_DISPATCH_REVIEW_2026-04-03.md](/home/home/personal/zide/docs/review/VT_WAR_4_KEYCHAR_DISPATCH_REVIEW_2026-04-03.md)
- [VT_WAR_4_KEYCHAR_RESULT_SHAPE_2026-04-03.md](/home/home/personal/zide/docs/review/VT_WAR_4_KEYCHAR_RESULT_SHAPE_2026-04-03.md)
- [VT_WAR_4_KEYCHAR_DECISION_2026-04-03.md](/home/home/personal/zide/docs/review/VT_WAR_4_KEYCHAR_DECISION_2026-04-03.md)

Otherwise, rerank from this stronger baseline instead of forcing a third input
cut.
