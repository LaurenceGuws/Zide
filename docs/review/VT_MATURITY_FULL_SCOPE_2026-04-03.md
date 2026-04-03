# VT Maturity Full Scope

Date: 2026-04-03

## Purpose

Replace piecemeal VT discomfort with one ranked full-scope view of what still
separates `zide-vt` from a mature, reference-grade library center.

This review is not another seam queue.
It is the comprehensive focus filter for all future VT work.

## Inputs

Zide:

- [TerminalCore](/home/home/personal/zide/src/terminal/core/terminal_core.zig)
- [TerminalRuntimeShell](/home/home/personal/zide/src/terminal/core/session/terminal_runtime_shell.zig)
- [runtime.zig](/home/home/personal/zide/src/terminal/core/session/runtime.zig)
- [input.zig](/home/home/personal/zide/src/terminal/core/session/input.zig)
- [host_queries.zig](/home/home/personal/zide/src/terminal/core/session/host_queries.zig)
- [core_api.zig](/home/home/personal/zide/src/terminal/ffi/core_api.zig)
- [host_api.zig](/home/home/personal/zide/src/terminal/ffi/host_api.zig)
- [shared.zig](/home/home/personal/zide/src/terminal/ffi/shared.zig)

References:

- [Ghostty Terminal.zig](/home/home/personal/zide/dev_references/terminals/ghostty/src/terminal/Terminal.zig)
- [Ghostty Termio.zig](/home/home/personal/zide/dev_references/terminals/ghostty/src/termio/Termio.zig)
- [libghostty-vt vt.h](/home/home/personal/zide/dev_references/terminals/ghostty/include/ghostty/vt.h)
- [WezTerm terminal.rs](/home/home/personal/zide/dev_references/terminals/wezterm/term/src/terminal.rs)
- [WezTerm terminalstate/mod.rs](/home/home/personal/zide/dev_references/terminals/wezterm/term/src/terminalstate/mod.rs)

## Executive Read

Zide is no longer blocked by false-center sludge.

The live shape is now serious:

- engine center:
  [TerminalCore](/home/home/personal/zide/src/terminal/core/terminal_core.zig)
- outer shell:
  [TerminalRuntimeShell](/home/home/personal/zide/src/terminal/core/session/terminal_runtime_shell.zig)

That means the remaining gap is not "find the next extraction."

The remaining gap is now maturity quality across a small number of categories:

1. `TerminalCore` sufficiency as the undeniable library object
2. public contract normalization and object identity at the host edge
3. only then any new semantic interaction or mutation contradiction

## Ranked Full-Scope Matrix

### 1. `TerminalCore` sufficiency is the top blocker

This is now the strongest remaining gap under both Ghostty and WezTerm
pressure.

Why:

- Ghostty still makes `Terminal` feel more directly like the library center.
- WezTerm still makes `Terminal` feel more fully sufficient as the terminal
  object.
- Zide improved the shell and semantic ownership, but core still does not feel
  fully self-sufficient enough at first glance.

Concrete pressure points:

- [terminal_core.zig](/home/home/personal/zide/src/terminal/core/terminal_core.zig)
  still relies on outer-owner shaped execution for several major operations:
  - `deinit(...)`
  - `feedOutputBytesLocked(...)`
  - `resizeLocked(...)`
- [terminal_core_feed.zig](/home/home/personal/zide/src/terminal/core/protocol/terminal_core_feed.zig)
  and [resize_reflow.zig](/home/home/personal/zide/src/terminal/core/resize_reflow.zig)
  still show the core depending on adjacent owner/publication machinery for
  complete host-visible behavior.
- core still exposes some low-level protocol assembly surfaces directly, such
  as title/cwd buffer manipulation, which weakens its "finished terminal
  object" feel.

What this category means:

- not "move more random methods onto core"
- but "make the terminal object itself feel more self-sufficient and mature"

### 2. Public contract normalization is the next major gap

The contract is now much healthier, but it is still more bespoke than a boring
swappable VT-library edge.

This does not mean "copy Ghostty's narrow ABI."
It means:

- categories should feel deliberate
- the host should not learn two stories for one operation
- shell identity should not overshadow terminal identity at the public edge

Concrete pressure points:

- [core_api.zig](/home/home/personal/zide/src/terminal/ffi/core_api.zig)
- [host_api.zig](/home/home/personal/zide/src/terminal/ffi/host_api.zig)
- [shared.zig](/home/home/personal/zide/src/terminal/ffi/shared.zig)
- [host_queries.zig](/home/home/personal/zide/src/terminal/core/session/host_queries.zig)

Current read:

- the FFI handle is opaque and terminal-named, which is better than it first
  looked
- but the live edge is still broad and publication-shaped
- the handle still stores the shell, and the create/export path still teaches
  a shell-centered host entry story more than an obviously terminal-centered
  one
- `host_queries.zig` is no longer a fake center, but it is still the clearest
  mixed host convenience package

### 3. Shell legitimacy is mostly healthy now

This category should stay under surveillance, but it is no longer the active
war.

Why:

- [terminal_runtime_shell.zig](/home/home/personal/zide/src/terminal/core/session/terminal_runtime_shell.zig)
  now reads mostly like honest lock/transport/lifecycle ownership
- most native and workspace callers now use the shell for synchronization or
  runtime aggregation, not because it feels like the real terminal

The remaining suspicious shell-centeredness is mostly inside FFI handle and
constructor identity, which belongs under public contract normalization rather
than generic shell cleanup.

### 4. Terminal-driving interaction ownership is materially healthier

This was the strongest recent war and it paid off.

Recent wins:

- output feed/apply semantics
- resize semantics
- key/keypad/alternate-scroll/char semantic dispatch

What remains in [input.zig](/home/home/personal/zide/src/terminal/core/session/input.zig)
is now mostly:

- writer-shaped
- reporting-shaped
- transport-shaped

That means this category should stay paused unless a future named semantic slab
appears that is genuinely terminal-owned.

### 5. Mutation/publication maturity is materially healthier

This is no longer a default-war category either.

Why:

- viewport and selection mutation truth is now more obviously core-owned
- the remaining wrappers now read mostly like:
  - lock ownership
  - publication refresh
  - host-facing normalization

That is honest enough to stop by default.

### 6. ABI breadth remains a difference, but not the top blocker

Zide still exposes a much richer host contract than Ghostty.

That matters, but the current pressure is not simply "make it smaller."
The current pressure is:

- make the richer contract feel convincingly centered on a mature terminal
  object

If that story is strong enough, breadth becomes a tradeoff rather than a
symptom.

## Category Judgment Table

| Category | Current Rank | State | Default Action |
|---|---:|---|---|
| `TerminalCore` sufficiency | 1 | strongest remaining gap | design-first war |
| Public contract normalization | 2 | still broad/bespoke | targeted review only |
| Shell legitimacy | 3 | mostly honest now | guardrail only |
| Interaction ownership | 4 | materially improved | paused unless new semantic slab appears |
| Mutation/publication maturity | 5 | materially improved | paused unless new contradiction appears |
| ABI breadth | 6 | different but not fatal | do not optimize for narrowness alone |

## What Must Stop

These are now anti-progress by default:

- chipping away at whichever file still feels heavy
- reopening already-flattened local lanes because they are easy to touch
- equating smaller shell surface with higher maturity
- treating publication- or FFI-richness itself as the top problem without
  first proving it weakens terminal identity

## What Must Happen Next

The next valid VT campaign must start from category 1 or 2 only.

That means:

1. name one exact `TerminalCore` sufficiency gap
2. or name one exact host-edge contract weakness
3. compare that gap directly against Ghostty and WezTerm
4. then cut the full semantic slice

If that exact gap cannot be named, VT should stay paused.

## Bottom Line

The full scope is now clear:

- `zide-vt` is credible
- `zide-vt` is still not plug-and-play with `libghostty-vt`
- the main blocker is no longer architecture cleanup
- the main blocker is whether `TerminalCore` feels unquestionably sufficient
  and whether the host edge reinforces that story cleanly
