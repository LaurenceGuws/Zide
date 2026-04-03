# VT Post OSC Rerank

Date: 2026-04-03

## Purpose

Rerank VT maturity after the OSC semantic effects war reached its stop-marker.

The question is:

- what protocol-execution contract now gives the strongest next improvement to
  `TerminalCore` maturity?

## What Improved

The OSC family now has two real core-side semantic owners:

- [terminal_core_osc_metadata.zig](/home/home/personal/zide/src/terminal/core/protocol/terminal_core_osc_metadata.zig)
- [terminal_core_osc_semantic.zig](/home/home/personal/zide/src/terminal/core/protocol/terminal_core_osc_semantic.zig)

That means OSC no longer reads like the strongest remaining example of
protocol-local semantic ownership.

## What Does Not Win Next

### 1. More OSC work

This does not win.

Reason:

- the two meaningful semantic slabs are already moved
- what remains in OSC is routing, hyperlink handling, and clipboard-family
  behavior
- that no longer reads like one omitted core-side semantic owner

### 2. More reply sink work

This does not win.

Reason:

- the remaining CSI family would need a second sink shape
- that is not the strongest maturity pressure from this baseline

### 3. Broad parser-owner extraction

This still does not win directly.

Reason:

- the parser-owner discomfort is still real
- but it still needs one named semantic cluster instead of a vague extraction
  push

## What Rises Next

### 1. CSI / ANSI mode semantics and screen effects

This now wins.

Concrete evidence:

- [csi_mode_mutation.zig](/home/home/personal/zide/src/terminal/protocol/csi_mode_mutation.zig)
  still directly mixes:
  - core screen-mode mutations
  - input-mode decisions
  - host-contract flag mutation
  - alt-screen entry/exit effects
- [csi_mode_query.zig](/home/home/personal/zide/src/terminal/protocol/csi_mode_query.zig)
  still reflects the same mixed execution neighborhood

This is now the strongest remaining protocol family where:

- true terminal mode semantics are still not obviously grouped behind one
  clearer core-side contract
- but the state-classification groundwork from the CSI interaction war is
  already in place

### 2. DECRQSS / query assembly sufficiency

This is second.

Why:

- it still matters for maturity feel
- but it looks narrower than the remaining mode/effects cluster

## Decision

The next VT war should be:

- CSI / ANSI mode semantics and screen effects

Not:

- OSC continued
- reply sink symmetry
- vague parser-owner extraction

## Bottom Line

Post-OSC, the strongest remaining VT maturity pressure is now the CSI/ANSI
mode-and-effects cluster.
