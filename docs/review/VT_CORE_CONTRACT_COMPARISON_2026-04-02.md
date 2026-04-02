# VT Core Contract Comparison 2026-04-02

## Purpose

Compare the directly relevant VT-core contract shape across:

- Zide
- Ghostty / `libghostty-vt`
- WezTerm

This review is for the `vt-sprint` lane.
The question is not renderer style or app structure.
The question is:

- how close is Zide to a serious swappable VT library boundary?

## Inputs Reviewed

Zide:

- [terminal_core.zig](/home/home/personal/zide/src/terminal/core/terminal_core.zig)
- [terminal_session.zig](/home/home/personal/zide/src/terminal/core/session/terminal_session.zig)
- [terminal_runtime.zig](/home/home/personal/zide/src/terminal/core/terminal_runtime.zig)
- [VT_CORE_DESIGN.md](/home/home/personal/zide/app_architecture/terminal/VT_CORE_DESIGN.md)
- [TERMINAL_ARCHITECTURE_COMPARISON.md](/home/home/personal/zide/app_architecture/terminal/TERMINAL_ARCHITECTURE_COMPARISON.md)

References:

- [Ghostty Terminal.zig](/home/home/personal/zide/dev_references/terminals/ghostty/src/terminal/Terminal.zig)
- [Ghostty Termio.zig](/home/home/personal/zide/dev_references/terminals/ghostty/src/termio/Termio.zig)
- [libghostty-vt vt.h](/home/home/personal/zide/dev_references/terminals/ghostty/include/ghostty/vt.h)
- [WezTerm terminal.rs](/home/home/personal/zide/dev_references/terminals/wezterm/term/src/terminal.rs)
- [WezTerm terminalstate/mod.rs](/home/home/personal/zide/dev_references/terminals/wezterm/term/src/terminalstate/mod.rs)

## What Is Directly Comparable

These three implementations are directly comparable at the VT-core contract
level:

- the primary terminal object
- the parser/state relationship
- the runtime shell around that object
- the host/export boundary
- what the host can observe and mutate without becoming the semantic owner

They are not directly comparable at:

- renderer specifics
- windowing/runtime framework details
- app shell organization

## Reference Shape

Ghostty and WezTerm both make one thing obvious at first glance:

- there is one object that is plainly "the terminal"

Ghostty:

- `terminal/Terminal.zig` is the terminal engine object
- `termio/Termio.zig` is the runtime/IO shell around it
- `libghostty-vt` keeps the public library face intentionally narrow

WezTerm:

- `term::Terminal` is the terminal object
- it owns parser plus `TerminalState`
- state richness lives under that center instead of beside it

The references differ in runtime, host, and public ABI decisions, but they
share one crucial property:

- the core mental model begins with a single unmistakable VT object

## Zide Current Shape

Zide is much stronger than it was before War 3:

- `terminal_publication.zig` no longer reads like a competing center
- `session/runtime.zig` no longer reads like a competing center
- `TerminalSession` is cleaner and grouped
- the root now exports `TerminalSession` directly

But Zide still does not match the same first-glance contract shape.

Current read:

- [TerminalCore](/home/home/personal/zide/src/terminal/core/terminal_core.zig) is the semantic/state center
- [TerminalSession](/home/home/personal/zide/src/terminal/core/session/terminal_session.zig) is the public owning object
- [terminal_runtime.zig](/home/home/personal/zide/src/terminal/core/terminal_runtime.zig) still keeps the compatibility alias `PtyTerminalRuntime = TerminalSession`

That means the current public story is still split:

- `TerminalCore` looks like the real engine
- `TerminalSession` looks like the object hosts are actually supposed to use

## Strongest Remaining Mismatch

The strongest remaining mismatch against Ghostty and WezTerm is now explicit:

- Zide still lacks one object that is both:
  - obviously the terminal engine
  - obviously the public VT library contract

In practice:

- `TerminalCore` owns a lot of real terminal truth:
  - screens
  - history
  - parser
  - palette
  - title/cwd
  - hyperlink/user-var/progress state
  - scrollback/view access
- but `TerminalCore` is not the main host-facing object
- `TerminalSession` still owns the surface hosts actually grab:
  - init
  - lock/unlock
  - PTY writer access
  - content/selection host helpers
  - snapshot export

So the contradiction is no longer file sprawl.
It is contract identity.

## Why This Matters For Plug-And-Play

This is the main thing still holding back a credible `zide-vt` story.

As long as the public contract is split between:

- "the semantic engine object"
- and "the thing hosts actually instantiate and call"

Zide remains harder to read as a swappable VT library than Ghostty or WezTerm.

This does not mean Zide lacks capability.
It means the center is still less boring and less obvious than it should be.

## Current Judgment

The direct comparison says:

- yes, VT-core contract is now the right cross-implementation battlefield
- the biggest remaining contradiction is not publication or runtime helper
  weight
- the biggest remaining contradiction is that `TerminalCore` and
  `TerminalSession` still split "real engine" and "real public object"

## First Sprint Cut

The first real `vt-sprint` move is now identified and should be judged by this
bar:

- move immutable scrollback/export reads onto `TerminalCore`
- stop advertising that read-only slab from `TerminalSession`

Why this is the right opener:

- it is already core-owned in substance
- it is host-facing
- it does not depend on PTY/runtime shell behavior
- it makes hosts reach the engine object directly for immutable terminal
  content instead of treating `TerminalSession` as the only real export face

Progress note, later on 2026-04-02:

- the immutable selection-text export path now moved the same way
- `TerminalCore` now owns:
  - `selectionPlainTextAlloc(...)`
  - `scrollbackInfo(...)`
  - `copyScrollbackRange(...)`
  - `scrollbackPlainTextAlloc(...)`
  - `scrollbackAnsiTextAlloc(...)`
- `TerminalSession` no longer advertises that immutable export slab as if it
  were session-shell identity

The next same-class move also now reads clearly:

- simple engine metadata reads like title, cwd, and alt-screen state should be
  taken from `TerminalCore` directly where possible
- session-level host-query helpers should stay only where they actually add
  runtime-shell meaning, such as transport liveness or foreground-process
  aggregation

Identity progress, later on 2026-04-02:

- the root VT surface now exports `TerminalCore` directly alongside
  `TerminalSession`
- this does not finish the object-identity war, but it removes one more signal
  that the engine object is only an internal field instead of part of the real
  library face
- app/UI/FFI consumers now speak `TerminalSession` directly instead of the
  compatibility alias `PtyTerminalRuntime`
- `PtyTerminalRuntime` is now reduced to VT-root compatibility residue rather
  than the preferred owning type name in the live stack
- internal host/runtime infrastructure now follows that same identity:
  workspace and replay-harness code speak `TerminalSession` directly too

## Sprint Target

The next `vt-sprint` question should be:

- which object is the actual `zide-vt` library object?

There are only two serious answers:

1. `TerminalCore` becomes sufficiently public and host-facing that
   `TerminalSession` is plainly just runtime shell / host adapter.
2. `TerminalSession` is explicitly accepted as the library object, and
   `TerminalCore` is treated as internal engine state rather than the would-be
   public center.

What should not continue:

- ambiguity between those two stories
- local cleanup that avoids choosing one

## Bottom Line

Zide is closer now, but still not plug-and-play close.

The next real step is no longer another cleanup wave.
It is an explicit object-identity decision for the VT library boundary.
