# VT Post CSI Reply Query Rerank

Date: 2026-04-03

## Purpose

Rerank VT scrutiny after the full writer-driven CSI reply/query wave:

- DSR
- DA
- bounded window-op replies
- DECRQM replies

The question is:

- what most directly still keeps Zide behind Ghostty/WezTerm on VT maturity
  now?

## What This Wave Actually Removed

This wave materially flattened one real protocol-execution contradiction.

Before:

- `src/terminal/protocol/csi.zig` still completed major reply/query families by
  grabbing a raw PTY writer
- reply assembly still felt shell-finished
- CSI reply/query handling still taught a shell-completion story even after
  state ownership had improved

Now:

- the major CSI reply/query family no longer grabs a raw writer in `csi.zig`
- reply bytes are assembled explicitly by reply/query owners
- emission goes through the named protocol reply sink

That is real progress on:

- completion item 1
- completion item 3
- completion item 7

## What Is No Longer The Main Problem

The following no longer deserve default-war status:

### 1. Generic shell cleanup

- constructor identity is flatter
- handle identity is flatter
- broad lock gravity is flatter
- shell survival is still under scrutiny, but no longer the loudest problem

### 2. Broad CSI reply/query discomfort

- the remaining CSI reply/query family is no longer shell-finished in the old
  raw-writer way
- continuing that lane by symmetry would now risk faux progress

### 3. Sink uniformity

- byte-oriented sink work paid off where it was honest
- forcing all remaining protocol families into one sink shape is not the bar

## Current Top Pressure

The strongest remaining pressure returns to broader `TerminalCore` sufficiency
and protocol-execution maturity.

More specifically:

- does protocol execution now terminate on core-side semantic owners often
  enough that `TerminalCore` feels like the terminal object?
- or is there still one remaining semantic protocol cluster that reads
  protocol-owned first and terminal-owned second?

## Strongest Current Suspects

From this baseline, the strongest suspects are:

1. broader CSI / ANSI execution beyond reply/query state
2. deeper parser-owner maturity around protocol execution termination
3. public contract normalization at the host edge, if no new semantic protocol
   cluster cleanly outranks it

The wrong next move would be:

- more CSI cleanup because CSI still has files
- more shell cleanup because the shell still exists
- more sink work because sink work feels tidy

## Current Judgment

The next active front should not be:

- reply sinks continued
- CSI reply/query continued
- shell cleanup continued

The next active front should be:

- one exact remaining `TerminalCore` protocol-execution sufficiency
  contradiction

If that cannot be named cleanly, then VT should pause rather than inventing one
more local slice.

## Decision

The CSI reply/query wave is at a stop-marker.

The next move must name one broader semantic execution cluster or one host
contract weakness that directly outranks everything else now.
