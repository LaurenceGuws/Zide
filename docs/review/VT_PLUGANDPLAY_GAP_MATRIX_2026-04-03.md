# VT Plug-and-Play Gap Matrix

Date: 2026-04-03

## Purpose

Give one comprehensive ranked comparison of the current VT-core contract across:

- Zide
- Ghostty / `libghostty-vt`
- WezTerm

The goal is not another local cleanup queue.
The goal is to identify, in one uninterrupted list, what still blocks credible
plug-and-play parity between `zide-vt` and `libghostty-vt`.

## Compared Inputs

Zide:

- [TerminalCore](/home/home/personal/zide/src/terminal/core/terminal_core.zig)
- [TerminalRuntimeShell](/home/home/personal/zide/src/terminal/core/session/terminal_runtime_shell.zig)
- [session/runtime.zig](/home/home/personal/zide/src/terminal/core/session/runtime.zig)
- [session/input.zig](/home/home/personal/zide/src/terminal/core/session/input.zig)
- [session/content.zig](/home/home/personal/zide/src/terminal/core/session/content.zig)
- [session/selection.zig](/home/home/personal/zide/src/terminal/core/session/selection.zig)
- [session/host_queries.zig](/home/home/personal/zide/src/terminal/core/session/host_queries.zig)
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

The live shape is now credible:

- engine object:
  [TerminalCore](/home/home/personal/zide/src/terminal/core/terminal_core.zig)
- outer shell:
  [TerminalRuntimeShell](/home/home/personal/zide/src/terminal/core/session/terminal_runtime_shell.zig)

That is a major win.

But credible extraction is not the same thing as plug-and-play parity.

The remaining gap is now design quality, not cleanup residue.

## Ranked Gap List

### 1. Host-driving input semantics were the top blocker, and are now materially lower

Current Zide shape:

- [session/input.zig](/home/home/personal/zide/src/terminal/core/session/input.zig)
  is still the main entrypoint for:
  - key
  - char
  - keypad
  - mouse
  - focus/color-scheme reporting
  - raw text/byte send
- FFI host input in [host_api.zig](/home/home/personal/zide/src/terminal/ffi/host_api.zig)
  terminates there too

Why this was the top blocker:

- Ghostty and WezTerm both make terminal-driving interaction feel more
  terminal-owned
- Zide already fixed output feed/apply and resize semantics enough to expose
  the remaining pressure clearly
- the input semantics war then landed the clean semantic slices:
  - key action dispatch
  - keypad action dispatch
  - alternate-scroll mapping
  - char action dispatch

What matters:

- the remaining input surface is now mostly writer/reporting-shaped
- so input no longer deserves default-war status from the new baseline

### 2. `TerminalCore` still does not feel fully sufficient as the terminal object

Current Zide shape:

- [TerminalCore](/home/home/personal/zide/src/terminal/core/terminal_core.zig)
  owns a lot of real truth:
  - parser
  - screens
  - history
  - metadata/activity summaries
  - scrollback/selection export
  - feed/apply semantic verb
  - resize semantic verb
- but those semantic verbs still take an external owner context, and several
  live host interactions still terminate outside the core

Why it matters:

- WezTerm’s `Terminal` and Ghostty’s `Terminal` both feel more self-contained
  at first glance
- Zide is now close enough that this is a sufficiency problem, not a structural
  sludge problem

This is now the strongest remaining blocker because:

- input semantics are materially cleaner now
- this category is again the clearest remaining pressure

### 3. Public resize was a real gap, and is now materially lower

Current Zide shape:

- core owns `resizeLocked(...)`
- public resize still enters through:
  - [session/runtime.zig](/home/home/personal/zide/src/terminal/core/session/runtime.zig)
  - [transport_runtime.zig](/home/home/personal/zide/src/terminal/core/session/transport_runtime.zig)
  - [host_api.zig](/home/home/personal/zide/src/terminal/ffi/host_api.zig)

Why it mattered:

- the semantic cut was real
- the public story used to split host-supplied cell metrics from resize itself
- the unified `resizeWithCellSize(...)` contract now materially reduces that
  parity gap

This category is now lower pressure from the new baseline.

### 4. Viewport and selection mutation still look more shell-surfaced than core-surfaced

Current Zide shape:

- mutation truth largely lives on core
- active callers still commonly go through:
  - [session/content.zig](/home/home/personal/zide/src/terminal/core/session/content.zig)
  - [session/selection.zig](/home/home/personal/zide/src/terminal/core/session/selection.zig)

Why it matters:

- this is no longer the center of gravity
- but it still weakens the “hosts obviously drive the terminal object” story

This is now a second-order gap, not the next default war.

### 5. Host metadata/activity packaging is still mixed, but now mostly honestly mixed

Current Zide shape:

- [host_queries.zig](/home/home/personal/zide/src/terminal/core/session/host_queries.zig)
  still combines:
  - core truth
  - liveness
  - exit state
  - foreground-process aggregation

Why it is no longer the war:

- this is now mostly legitimate host/runtime aggregation
- both reference pressure and the live caller map say it is not the main false
  center anymore

So this category matters mainly as a guardrail:

- do not reopen it by momentum

### 6. Public ABI normalization still differs sharply from Ghostty

Current Zide shape:

- broad FFI surface:
  - snapshot
  - diff
  - metadata
  - redraw state
  - event drain
  - text export
  - host input/control

Ghostty shape:

- very narrow `vt.h` umbrella

Why this is not a simple “Zide should be narrower” conclusion:

- Zide’s host contract is richer on purpose
- the main issue is not raw breadth
- the main issue is whether that breadth is anchored on a convincing engine
  center

So this remains a difference, but not the top blocker.

## Category Matrix

| Category | Zide | Ghostty | WezTerm | Current Judgment |
|---|---|---|---|---|
| Primary object identity | `TerminalCore` plus `TerminalRuntimeShell` | `Terminal` plus `Termio` | `Terminal` plus internal state | Zide is improved, but still slightly less obvious |
| Engine state ownership | strong on `TerminalCore` | strong on `Terminal` | strong on `Terminal`/`TerminalState` | near parity |
| Output feed/apply | core semantic verb now exists | terminal-centered | terminal-centered | materially improved |
| Resize semantics | unified host-facing resize contract over core semantic verb plus shell reporting | terminal-centered with runtime around it | terminal-centered | materially improved |
| Input semantics | still shell-fronted | more terminal-centered in feel | more terminal-centered in feel | biggest gap |
| Immutable metadata/export | mostly core-centered now | terminal-centered | terminal/state-centered | healthy |
| Host runtime shell | mostly honest now | `Termio` is clearly shell | runtime around terminal is clear | mostly healthy |
| Public ABI shape | broad and explicit | narrow and boring | not the same style, but terminal object is obvious | different, but not top blocker |

## What No Longer Deserves Attention

These are no longer the default suspects:

- publication as a competing center
- runtime shell size as a fake center
- immutable query/export ownership
- `host_queries.zig` as a broad false center

That work already paid off.

## What Deserves Uninterrupted Focus

If the goal is plug-and-play pressure, the list from the newer baseline is now:

1. `TerminalCore` sufficiency
2. viewport/selection mutation surface
3. public resize story is now materially lower
4. only then reconsider whether host metadata packaging or ABI normalization
   actually moved back up

## Bottom Line

The direct answer is:

- Zide is now credibly extractable as `zide-vt`
- it is still not near true plug-and-play parity with `libghostty-vt`
- the strongest remaining blocker is no longer architecture sludge
- the strongest remaining blocker is now `TerminalCore` sufficiency from the
  new post-input baseline

If we stay disciplined, the next wars should be judged against this exact list,
not reopened from vague discomfort.
