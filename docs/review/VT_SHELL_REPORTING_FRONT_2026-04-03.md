# VT Shell Reporting Front

Date: 2026-04-03

## Purpose

Take the first real code slice from the shell hostile audit.

The question is:

- can the suspicious reporting bucket be grouped under one explicit owner so
  shell/runtime reporting stops reading like scattered shell residue?

## Decision

Yes.

The first reporting slice is:

- `2031`
- `2048`
- `5522`

as one explicit host-reporting contract owner.

## What Landed

New owner:

- [host_reporting.zig](/home/home/personal/zide/src/terminal/core/session/host_reporting.zig)

That owner now groups:

- CSI reporting-mode mutation for:
  - color-scheme reporting `2031`
  - in-band resize notifications `2048`
  - kitty paste events `5522`
- DECRQM read-side state for the same flags
- runtime-dependent reporting behavior:
  - color-scheme report emission
  - in-band resize report emission
  - kitty paste event emission

## Why This Matters

This does not make reporting core-owned.

It makes reporting explicit instead of leaving it smeared across:

- `csi_mode_mutation.zig`
- `csi_mode_query.zig`
- `transport_runtime.zig`
- `session/input.zig`
- `session/interaction.zig`

That is the right wartime direction:

- shell/runtime responsibilities must justify themselves as one explicit
  boundary
- not survive as scattered historical residue

## Current Judgment

This is a real win for shell scrutiny.

The reporting bucket still exists, but now it reads more like:

- one explicit runtime-reporting contract

and less like:

- shell-shaped leftovers everywhere

## Bottom Line

The first suspicious shell bucket is now materially cleaner:

- reporting has one explicit owner
