# Terminal Parser Text Boundary Review 2026-04-02

## Purpose

Open the next likely War 2 battlefield directly on the live code.

After:

- the present-invariant wave
- the publication-boundary wave
- the host-aggregation wave
- the first widget / retained-render wave

the strongest remaining structural candidate is now parser / text semantics
below the VT boundary.

This review asks:

- what still lives too high above the VT boundary
- and what still makes parser/protocol code look more semantic than the
  strongest references

## Inputs Reviewed

Live code:

- [parser.zig](/home/home/personal/zide/src/terminal/parser/parser.zig)
- [csi.zig](/home/home/personal/zide/src/terminal/protocol/csi.zig)
- [terminal_core_text.zig](/home/home/personal/zide/src/terminal/core/protocol/terminal_core_text.zig)
- [terminal_core_protocol.zig](/home/home/personal/zide/src/terminal/core/protocol/terminal_core_protocol.zig)
- [control_handlers.zig](/home/home/personal/zide/src/terminal/core/protocol/control_handlers.zig)
- [mode_effects.zig](/home/home/personal/zide/src/terminal/core/session/mode_effects.zig)
- [input_modes.zig](/home/home/personal/zide/src/terminal/core/input_modes.zig)
- [osc.zig](/home/home/personal/zide/src/terminal/protocol/osc.zig)
- [dcs_apc.zig](/home/home/personal/zide/src/terminal/protocol/dcs_apc.zig)

Reference pressure:

- Ghostty `Terminal`
- Ghostty `Screen`
- Ghostty `Termio`
- Ghostty `key_encode`

## High-Level Read

This lane is no longer about obvious wrapper theater.

Most of that was already flattened.

The question now is subtler and more important:

- does the parser/protocol stack still read like a place where semantic text
  effects are decided too high above the engine model?

Against Ghostty, the remaining gap is not API volume.

It is whether the engine still looks undeniably like the semantic owner of:

- text insertion behavior
- wrap/newline behavior
- scroll/index effects
- mode-sensitive text consequences

## What Looks Better Now

Several older problems are already materially better:

- the parser’s own `SessionFacade` shell is gone
- parser dispatch no longer routes through dead protocol barrels
- printable text no longer routes through the old `parser_hooks` seam
- `terminal_core_text.zig` already reads core-owned state directly

That means this lane should not be reopened as if nothing improved.

## What Still Looks Structurally Risky

### 1. `parser.zig` still reads like a traffic owner for too many semantic outcomes

Even after the cleanup waves, [parser.zig](/home/home/personal/zide/src/terminal/parser/parser.zig)
still directly decides routing for:

- control handling
- printable text
- DEC reset/save/restore effects
- tab setting
- reverse index
- keypad mode toggles

Some of this is normal parser dispatch.

But some of it still feels closer to semantic effect selection than the
cleanest engine-centered design would.

### 2. ESC-path semantics are more scattered than the CSI path

The CSI lane is flatter now.

But in `parser.zig` itself, the ESC path still directly touches:

- `mode_effects`
- `terminal_core_modes`
- `terminal_core_protocol`
- `input_modes`

That makes the parser look like a coordinator of semantic effects instead of a
thinner decoder handing off to a smaller engine-owned command surface.

### 3. The remaining protocol split still does not read as clean as Ghostty

Ghostty pressure is not about copying APIs.

It is about how quickly a reader can see:

- parser/decoder
- engine state owner
- runtime/transport owner

Zide is much closer than before, but the parser/protocol layer still feels
more hand-routed than the cleanest reference-grade center.

## Strongest Local Candidates

### Candidate A: ESC semantic effect slab

This is the strongest immediate candidate.

Why:

- it is still visibly routed inline from `parser.zig`
- it touches multiple owners directly
- it is small enough to cut as one coherent slab
- and it would make the parser read more like a decoder and less like a
  semantic router

Status update:

- that first cut is now landed
- the remaining semantic ESC effect cluster moved below the parser boundary
  into
  [esc_effects.zig](/home/home/personal/zide/src/terminal/core/protocol/esc_effects.zig)

That does not finish this lane, but it is the right opener because the parser
no longer coordinates those effect owners inline.

### Candidate B: broader text/protocol command surface below parser

This is the larger follow-up candidate.

Why:

- the real long-term answer may be a sharper engine-owned command surface for
  decoded parser effects
- but that is a larger shape decision
- it should follow one concrete first cut, not precede it

Status update:

- that next step is now partially landed too
- decoded parser dispatch now lives under
  [parser_dispatch.zig](/home/home/personal/zide/src/terminal/core/protocol/parser_dispatch.zig)
  instead of being hand-routed inline from `parser.zig`

That is the right kind of move because it makes `parser.zig` read more like a
state machine with parser-local state, not a place that knows every downstream
effect owner directly.

## Current Judgment

The first parser-boundary wave was worth doing.

More concretely:

- the ESC semantic effect slab is out
- decoded parser dispatch is out
- `parser.zig` is now much closer to parser-local state plus state-machine flow

That means this lane is approaching a rerank point too.

The next cut should only happen if one more real semantic slab still sits too
high above the VT boundary.

If not, the honest move is to stop and rerank War 2 again from the top.

## Best Next Review Question

What, if anything, still prevents
[parser.zig](/home/home/personal/zide/src/terminal/parser/parser.zig)
from reading like a parser-local state machine over a narrower engine-owned
dispatch surface?

More concretely:

- is there one more semantic slab above the parser boundary
- or has the lane now improved enough that the next top-level War 2 enemy is
  elsewhere again

## Bottom Line

The first parser/text wave materially improved the boundary.

Do not keep cutting here by momentum unless one more real semantic slab
becomes obvious.
