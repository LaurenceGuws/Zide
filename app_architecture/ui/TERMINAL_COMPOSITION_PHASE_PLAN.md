# Terminal Composition Phase Plan

Purpose: define the next narrow renderer gate-5 cut after shell/UI chrome-band
composition stopped being the loudest scanned pressure.

This is terminal-owned composition work, not Android GLES backend bootstrap and
not editor row-band adoption.

## Goal

Keep terminal product overlays and terminal-adjacent visuals from mixing raw
surface/text calls directly into product flow.

The seam must make one terminal-local ordering unit own its fills, outlines,
and dependent text before Android GLES work depends on the same visuals.

## Scope

Initial scope:

- terminal close-confirm modal
- terminal active-tab progress bar
- terminal scrollbar thumb
- terminal surface separator/content-edge visual

Non-goals:

- no terminal cell renderer redesign
- no Android backend bootstrap
- no editor overlay adoption in this cut
- no generic repo-wide text/surface rewrite

## Acceptance Criteria

This cut is met when:

- the scoped terminal overlay/progress/modal visuals route through one
  terminal-owned composition seam
- those call sites no longer mix immediate surface/text calls beside their
  dependent visual work
- docs name the next remaining family without hiding it under this ticket

## Current Checkpoint (2026-04-11)

- `terminal_composition_host.zig` defines the terminal-owned composition seam
- close-confirm modal fills, outlines, and text now draw through that seam
- active-tab progress bar, terminal scrollbar thumb, and terminal separator
  now draw through that seam
- the seam currently reuses the shared band queue/replay machinery underneath;
  terminal ownership is explicit at the call sites so this does not become
  anonymous chrome-band expansion

## Next Pressure

The remaining scanned direct draw pressure is now mainly:

- editor row/overlay composition
- common tooltip overlay composition
- terminal cell/content drawing internals, which are not part of this overlay
  seam
