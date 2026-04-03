# VT Post Protocol Owner Rerank

Date: 2026-04-03

## Purpose

Rerank VT scrutiny after the full `terminal_core_protocol.zig` owner wave.

This front landed the only whole slabs that still mattered there:

- edit/erase semantics
- scroll/newline/reverse-index semantics
- DECRQSS state/query assembly

The question is:

- what now most directly keeps Zide behind Ghostty/WezTerm on VT maturity?

## What Is No Longer The Main Problem

`src/terminal/core/protocol/terminal_core_protocol.zig` no longer reads like a
parallel semantic center in the old damaging sense.

What remains there now is mostly:

- narrow helper forwarding
- palette lookup
- cell/cursor read helpers
- cursor/tab convenience forwarding
- kitty-image clearing forwarding
- scrolling helper forwarding

That is not nothing, but it is no longer the next war.

## Current Judgment

The active pressure returns to broader `TerminalCore` sufficiency again.

More specifically:

- `TerminalCore` is much stronger than before
- the shell is much quieter than before
- the old protocol owner seams are much flatter than before
- so the next contradiction will likely be broader and more object-model or
  contract-quality shaped, not another obvious local semantic file center

## What This Means

The next move should not be:

- more `terminal_core_protocol.zig` tidying
- more helper peeling by momentum
- reopening old shell or CSI fronts

The next move should be:

- name the next exact broader `TerminalCore` sufficiency or host-contract
  normalization contradiction from this stronger baseline

## Decision

Park the protocol-owner front.

Return to the top-ranked VT maturity question from the completion list instead
of farming this file for scraps.
