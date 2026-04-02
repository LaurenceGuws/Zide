# Terminal War 2 Post-Parser Re-Rank 2026-04-02

## Purpose

Re-rank War 2 after the first parser / text boundary wave.

This is the next top-level decision point after:

- the present-invariant wave
- the publication-boundary wave
- the host-aggregation wave
- the first widget / retained-render wave
- the first parser / text boundary wave

The question now is:

- what is the strongest remaining terminal false center or quality gap after
  those five waves?

## Current Read

The first parser wave was worth doing.

It removed two real parser-side slabs:

- ESC semantic effects now live in
  [esc_effects.zig](/home/home/personal/zide/src/terminal/core/protocol/esc_effects.zig)
- decoded parser dispatch now lives in
  [parser_dispatch.zig](/home/home/personal/zide/src/terminal/core/protocol/parser_dispatch.zig)

The live shape now looks like this:

- [terminal_publication.zig](/home/home/personal/zide/src/terminal/core/publication/terminal_publication.zig):
  425 lines
- [workspace.zig](/home/home/personal/zide/src/terminal/core/workspace.zig):
  299 lines
- [workspace_host.zig](/home/home/personal/zide/src/terminal/core/workspace_host.zig):
  247 lines
- [terminal_widget.zig](/home/home/personal/zide/src/ui/widgets/terminal_widget.zig):
  497 lines
- [terminal_widget_draw.zig](/home/home/personal/zide/src/ui/widgets/terminal_widget_draw.zig):
  690 lines
- [parser.zig](/home/home/personal/zide/src/terminal/parser/parser.zig):
  342 lines
- [parser_dispatch.zig](/home/home/personal/zide/src/terminal/core/protocol/parser_dispatch.zig):
  36 lines
- [esc_effects.zig](/home/home/personal/zide/src/terminal/core/protocol/esc_effects.zig):
  38 lines
- [visible_terminal_frame_hooks_runtime.zig](/home/home/personal/zide/src/app/terminal/visible_terminal_frame_hooks_runtime.zig):
  193 lines

The important point is not just the size.

It is that the obvious structural War 2 enemies have all been materially
flattened once already.

## What No Longer Looks Like The Main Enemy

### Publication by default

Publication still reads like a boundary, not the obvious second center.

### Host aggregation by default

The host path is much flatter and should remain paused unless a new large
false center appears.

### Parser/text semantics by default

This lane improved materially.

`parser.zig` now reads much closer to parser-local state plus state-machine
flow over a narrower engine-owned dispatch surface.

### Widget/render by default

This lane is still heavy, but the first wave removed the clearest non-draw
secondary slabs.

It is no longer obviously the next default structural enemy by momentum alone.

## Strongest Remaining Candidates

### Candidate A: Concrete Present Composition Omission Bug

This now looks like the strongest remaining candidate.

Why:

- the broad structural false centers have all been materially reduced
- the handoff still records a live native present seam:
  some cleared frames still submit with `terminal_texture_draws=0`
- if that seam still reproduces, it is now a more serious remaining weakness
  than another speculative structural split
- compared with foot / Rio / WezTerm pressure, an omitted-terminal-surface
  present path is a worse final embarrassment than another round of
  architecture grooming

This is now the likely next War 2 opener.

### Candidate B: One More Widget/Retained-Surface Owner Cut

Still possible, but no longer the default answer.

If one more unmistakable retained-surface owner boundary appears inside
`terminal_widget_draw.zig`, it could still be worth taking.

But it should not be assumed ahead of a real live present-risk review.

### Candidate C: Another parser/protocol semantic cut

Still possible, but no longer the default answer either.

The first parser wave got the lane close enough to a stop-marker that another
cut now needs stronger evidence than before.

## Current Judgment

After the first parser wave, the strongest remaining War 2 candidate is now
the concrete present composition omission bug path.

More concretely:

- the structural false-center wars are no longer the obvious default move
- the next best question is whether the live native present path is now truly
  airtight
- if not, that correctness lane should reopen immediately

## Best Next Review Question

Does the native terminal present path still allow a cleared submitted scene to
omit the authoritative retained terminal surface?

More concretely:

- can the scene clear and still submit with terminal surface draws omitted
- what exact path still permits that
- and what renderer-proven contract should forbid it completely

## Bottom Line

After the parser wave, War 2 should likely pivot back to a concrete present
composition omission bug hunt.
