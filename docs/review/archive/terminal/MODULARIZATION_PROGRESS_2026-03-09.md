# Terminal Modularization Progress Archive

This file preserves the deeper hotspot review, strict cleanup queue, and
sequencing notes that previously lived inline in
`docs/todo/terminal/modularization.md`.

Use it as historical rationale and progress evidence, not as the active queue.

## What this archive holds

- 2026-03-09 hotspot review snapshots
- the strict cleanup queue from that review pass
- the recommended sequencing notes for that lane

## Still-useful conclusions

- `TerminalSession` remained the main god-object risk after the first
  modularization wave.
- publication/presentation ownership, PTY write serialization, workspace/runtime
  scheduling, and protocol typing were the main remaining cleanup seams.
- kitty graphics was correctly identified as a concentrated risk surface before
  its later subsystem split.

## Historical note

The detailed queue/progress ledger was removed from the active todo because it
had become too large and was mixing active work with historical execution logs.
