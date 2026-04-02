# Terminal War 3 Closure 2026-04-02

## Decision

War 3 is closed.

## Why

War 3 started with a clear goal:

- make the live terminal stack read like a serious `zide-vt` extraction target

That goal materially landed.

At the start of War 3, the strongest contradictions were:

- publication reading like a competing center
- runtime reading like a competing center
- the aggregate session object reading like a flat broad center
- the public root identity still pointing at `PtyTerminalRuntime`

Those contradictions are no longer the default first-glance read.

Current state:

- publication reads much closer to an export edge
- runtime reads much closer to a shell
- aggregate session state is grouped under one `session` slab
- the owning session type lives in
  [terminal_session.zig](/home/home/personal/zide/src/terminal/core/session/terminal_session.zig)
- the public root exports `TerminalSession` directly
- `PtyTerminalRuntime` is reduced to compatibility residue

## Why War 3 Stops Here

The remaining gap is real but different:

- `TerminalCore` still reads more like the dominant field inside
  `TerminalSession` than the fully sufficient public center in its own right

That is no longer an obvious local contradiction.

It is an object-model design question.

Continuing with local cuts from here would be architecture theater unless that
deeper design is first made explicit.

## Outcome

War 3 succeeded at its intended scope:

- it removed the strongest visible contradictions to a serious library boundary
- it left the stack in a much stronger extraction-ready shape
- it exposed the next remaining question honestly instead of hiding it behind
  more cleanup

## What Comes Next

The next war should start from the new baseline and ask:

- what is now the strongest remaining architecture problem in the repo?

If the answer is still terminal, it should be a new deliberate design campaign,
not a continuation of War 3 by momentum.
