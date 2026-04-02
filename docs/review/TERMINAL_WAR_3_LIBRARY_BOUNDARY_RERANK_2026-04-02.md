# Terminal War 3 Library Boundary Re-Rank 2026-04-02

## Purpose

Open War 3 on the next terminal question that actually matters:

- how far are we from a real `zide-vt` library boundary
- and what must change before that boundary is honest enough to compare
  directly against `libghostty-vt`

This is not an extraction plan yet.

It is the campaign opener for the next terminal war.

## Starting Point

The current live code is materially stronger than it was at the start of War 1:

- publication is narrower
- host aggregation is narrower
- widget/render ownership is flatter
- parser/protocol routing is flatter
- the present acknowledgement contract is stronger

But the main remaining gap is now clearer too:

- Zide still does not present one unmistakable engine/library center
- Ghostty is still cleaner at first glance as a VT library boundary

That is the real next war.

## Current Comparison Read

From the live authority:

- [VT_CORE_DESIGN.md](/home/home/personal/zide/app_architecture/terminal/VT_CORE_DESIGN.md)
  says the gap is now center-of-gravity and ownership clarity, not missing host
  API volume
- [TERMINAL_ARCHITECTURE_COMPARISON.md](/home/home/personal/zide/app_architecture/terminal/TERMINAL_ARCHITECTURE_COMPARISON.md)
  says `ghostty-vt` is cleaner today as a VT library boundary, while Zide is
  richer at the host-contract layer
- [BRIDGE_DESIGN.md](/home/home/personal/zide/app_architecture/terminal/ffi/BRIDGE_DESIGN.md)
  says the bridge is already a real embeddable host boundary, but that does
  not automatically mean the engine/library center itself is clean enough

So the key distinction is:

- Zide is no longer blocked by lack of host contract
- Zide is still blocked by lack of one indisputable engine/library center

## War 3 Enemy

War 3 is not:

- more widget cleanup
- more publication helper shaving
- more stale present bug hunting

War 3 is:

- making the engine/library center unmistakable

More concretely:

- `TerminalCore` must become the obvious semantic center
- the runtime shell around it must read like runtime shell, not "the terminal"
- publication/export state must read like a boundary of the engine, not a
  second center
- the native host must read like the cleanest reference host over that same
  engine/library boundary

## Plug-and-Play Bar

The relevant goal is not literal drop-in interchangeability tomorrow.

The relevant goal is:

- a serious `zide-vt` boundary that could be extracted without dragging native
  widget/runtime assumptions with it

Only after that becomes true does it make sense to talk seriously about a more
normalized common host abstraction across `zide-vt` and `libghostty-vt`.

## Current Judgment

We are:

- much closer than before to a credible `zide-vt`
- still not close to real plug-and-play interchangeability with
  `libghostty-vt`

The remaining blocker is architecture shape, not capability volume.

## Best Next Question

What is the target `zide-vt` shape in concrete terms, and what is the single
largest contradiction still blocking it?

That target shape is:

- engine/library center
- runtime shell around it
- host boundary over it

The next move is not to "reduce files a bit more."

The next move is:

1. state that target shape explicitly
2. identify the largest current violation of it
3. delete that violation in one whole-slab cut

## Bottom Line

War 3 should open on the engine/library boundary itself.

The standard is no longer "is the host contract rich enough?"

The standard is:

- could a strong terminal maintainer open the live code and immediately believe
  that `zide-vt` is extractable as a serious library center?
