# VT Sprint Post-Shell Rerank

Date: 2026-04-02

## Current Read

The `vt-sprint` lane has now crossed its original bar:

- `TerminalSession` is deleted from live code
- `PtyTerminalRuntime` is deleted from live code
- the live VT shape is now:
  - [TerminalCore](/home/home/personal/zide/src/terminal/core/terminal_core.zig)
  - [TerminalRuntimeShell](/home/home/personal/zide/src/terminal/core/session/terminal_runtime_shell.zig)

That is materially better than the earlier split where a second object still
looked like the real public terminal.

## What Is No Longer The Main Problem

The main problem is no longer naming drift.

Specifically:

- there is no longer a live `TerminalSession`
- there is no longer a live `PtyTerminalRuntime`
- the outer shell is now named as a shell

So the sprint should stop spending energy on alias cleanup.

## What The References Still Pressure

Ghostty and WezTerm still win one important first-glance property:

- the engine object feels fully sufficient under the runtime shell

Zide is closer now, but the next pressure point is subtler:

- do hosts depend on `TerminalRuntimeShell` because they truly need runtime
  shell behavior
- or because `TerminalCore` is still not sufficient enough as the engine
  contract below it

That is a better question than:

- "should we keep deleting names?"

## Strongest Remaining Candidate

The strongest remaining plug-and-play question is now:

- `TerminalCore` sufficiency versus the outer shell contract

More concretely:

- if a host only needs terminal truth, immutable export, and semantic mutation,
  how often should it need the shell at all
- if a host needs synchronization, transport, or PTY writes, can that remain
  clearly shell-owned without weakening the library-center story

## Current Lean

The current live code suggests the next blocker is more likely
`TerminalCore` sufficiency than shell naming.

Why:

- the shell is already narrow:
  - init
  - lock / tryLock / unlock
  - PTY writer access
- the shell no longer pretends to be the engine
- the remaining question is whether more host-facing truth should bypass the
  shell entirely and land directly on `TerminalCore`

## What Should Not Happen Next

Do not:

- reopen alias cleanup
- rename more files just because the new shape is cleaner
- force shell deletion; a real VT library can legitimately have a runtime shell

## Best Next Move

The next honest step is a focused `TerminalCore` sufficiency review.

That review should answer:

1. Which remaining host-facing operations still require
   [TerminalRuntimeShell](/home/home/personal/zide/src/terminal/core/session/terminal_runtime_shell.zig)
   but should really be engine-facing instead.
2. Which shell-owned responsibilities are legitimately shell-owned and should
   stay there.
3. Whether the final plug-and-play blocker is:
   - insufficient `TerminalCore` surface
   - or too much host dependence on locking/shell access patterns

## Bottom Line

The object-identity war is materially won.

The next blocker is no longer "what is the terminal called?"
It is:

- is `TerminalCore` sufficient enough beneath the shell to read like a serious
  swappable VT library center?
