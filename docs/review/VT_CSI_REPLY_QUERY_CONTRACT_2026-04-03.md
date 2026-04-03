# VT CSI Reply Query Contract

Date: 2026-04-03

## Why This Front Exists

After the shell-cleanup wave, the strongest remaining VT scrutiny pressure is
broader `TerminalCore` sufficiency and protocol-execution maturity, not more
shell thinning.

Inside that broader pressure, the next exact cluster is writer-driven CSI
reply/query assembly.

This front exists to stop vague "parser-owner discomfort" and name the real
remaining contradiction:

- CSI semantics are cleaner than before
- CSI mode state is cleaner than before
- CSI reply/read snapshots are cleaner than before
- but several important CSI reply/query paths still become complete host-visible
  terminal behavior only at the writer-anchored shell edge

That is now the next direct maturity contradiction against Ghostty/WezTerm.

## The Exact Contradiction

`src/terminal/protocol/csi.zig` still owns multiple branches that do all of the
following inline:

- acquire a PTY writer through `lockPtyWriter()`
- collect reply/query state
- choose a reply family
- emit the reply bytes

That keeps the execution story reading like:

- CSI protocol branch
- shell writer lock
- ad hoc reply completion

instead of:

- terminal/protocol contract decides the reply intent or reply assembly
- runtime writer mechanics consume that explicit contract

## The Cluster

The cluster is the writer-driven CSI reply/query family in:

- `src/terminal/protocol/csi.zig`
- `src/terminal/protocol/csi_reply.zig`
- `src/terminal/protocol/csi_mode_query.zig`

The concrete subfamilies are:

1. DSR replies
2. DA primary reply
3. bounded window-op replies
4. DECRQM replies

## What Improved Already

This front is not starting from zero.

Already true:

- CSI mode mutation and DECRQM state ownership are much cleaner
- mode state now has explicit owners:
  - terminal mode state
  - input protocol mode state
  - host-contract state
  - derived snapshot state
- CSI reply/report snapshotting already has an explicit snapshot owner in
  `src/terminal/protocol/csi_reply.zig`
- byte-oriented non-CSI reply families already use an explicit reply sink

So the remaining contradiction is narrower now:

- not generic CSI cleanup
- not generic sink uniformity
- specifically the writer-driven CSI reply/query family

## Why This Still Loses On Maturity

Against peer pressure, this still reads too shell-finished:

- the semantic CSI branch still decides and emits replies only after grabbing a
  runtime writer
- `csi_reply.zig` still exposes writer-shaped helpers rather than a clearer
  contract shape above writer mechanics
- `csi_mode_query.zig` still finishes DECRQM as a writer call, not just as
  reply state/intent

That weakens both:

- completion list item 1:
  `TerminalCore` feels less fully sufficient because terminal-facing protocol
  execution still completes at the shell writer edge
- completion list item 3:
  protocol execution does not yet terminate on a contract that feels terminal-
  centered enough
- completion list item 7:
  reply/report behavior still risks reinforcing shell anchoring

## The Required Bar

The next move must not be:

- more local CSI cleanup
- more helper shaving in `csi.zig`
- forcing CSI into the existing byte-oriented sink just for symmetry

The required bar is:

- the CSI reply/query family must terminate on a clearer contract than
  "writer available, now emit bytes inline"
- writer acquisition and write failure handling stay outside core
- but reply/query assembly stops reading like it is completed ad hoc inside
  each `csi.zig` branch

## Likely First Slice

The strongest opening slice appears to be:

- DSR
- bounded window-op replies

Why:

- they already share one explicit snapshot owner
- they are state-driven replies, not mode-table lookups
- they are easier to group without prematurely forcing DA and DECRQM into the
  same exact shape

DA and DECRQM remain in the same cluster, but may not need to be the first cut
if doing so muddies the contract.

## Progress

The first slice is now landed.

What changed:

- `src/terminal/protocol/csi_reply.zig` now exposes explicit byte-assembly
  helpers for:
  - DSR replies
  - color-scheme preference reply
  - bounded window-op replies
- `src/terminal/protocol/csi.zig` no longer acquires a raw writer for those
  branches
- those replies now emit through the named protocol reply sink instead

What this improves:

- DSR and bounded window-op handling now reads less like ad hoc writer-finished
  completion inside `csi.zig`
- CSI reply assembly is more explicit without dragging runtime writer mechanics
  into `TerminalCore`

What remains:

- the remaining DA and DECRQM slice is now landed too
- DA now emits through the named protocol reply sink from an explicit byte
  reply contract
- DECRQM now formats reply bytes through `decrqmReplyInto(...)` and emits them
  through the named protocol reply sink instead of taking a raw writer in
  `csi.zig`
- this front is now materially flatter as a whole

## What Must Stay Outside

The following should remain explicitly outside the terminal/core-side contract:

- PTY writer locking
- transport write failure handling
- runtime writer availability

If the next move drags those into `TerminalCore`, it is the wrong move.

## Current Judgment

The shell is no longer the obvious enemy.

The next exact VT scrutiny front is writer-driven CSI reply/query assembly.

Do not reopen generic shell cleanup or generic CSI cleanup before this cluster
is judged.

## Stop Marker

This cluster is now close to a real stop-marker.

Remaining differences here are no longer:

- raw writer grabs in `csi.zig`
- ad hoc CSI reply completion branches for the major reply/query family

If this lane reopens, it should reopen only for one new explicit reply/query
contract contradiction, not because CSI still has files.
