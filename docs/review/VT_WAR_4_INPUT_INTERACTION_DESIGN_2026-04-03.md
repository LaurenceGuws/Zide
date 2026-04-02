# VT War 4 Input Interaction Design

Date: 2026-04-03

## Purpose

Pressure-test the third War 4 candidate:

- encoded host input semantics

This is not a code queue yet.
The goal is to determine whether one coherent semantic sub-slab exists here, or
whether the remaining input path is too coupled to writer/transport mechanics
for another clean War 4 move right now.

## Current Shape

The live input path is split across:

- [session/input.zig](/home/home/personal/zide/src/terminal/core/session/input.zig)
- [terminal/input/input.zig](/home/home/personal/zide/src/terminal/input/input.zig)
- [terminal_transport.zig](/home/home/personal/zide/src/terminal/core/runtime/terminal_transport.zig)

And it is consumed directly from:

- FFI host API
- widget keyboard/mouse/paste paths
- app helpers and runtime tests

## Candidate Sub-slabs

### 1. Text send / byte send

Pros:

- small surface
- easy to understand

Why it is weak:

- these are almost pure writer/transport verbs
- moving them toward core would likely be cosmetic or wrong

### 2. Focus / color-scheme reporting

Pros:

- conceptually terminal-facing

Why it is weak:

- both are mostly conditional report-to-writer paths
- they still terminate in transport encoding more than engine truth

### 3. Mouse reporting

Pros:

- strong host-facing terminal interaction

Why it is risky:

- tightly coupled to writer protocol encoding and live mouse tracking state
- widget callers are numerous and direct

### 4. Key / char semantic dispatch before writer encoding

Pros:

- this is the strongest candidate inside input
- some decisions here are terminal-semantics flavored:
  - app cursor mode
  - app keypad mode
  - key-mode flags
  - local echo fallback
  - alternate scroll wheel behavior

Why it is still risky:

- the semantic decisions and writer encoding are interleaved line-by-line
- a bad extraction here could create a fake "input facade" instead of a real
  engine-owned contract

## Current Judgment

There is not yet a clean enough sub-slab to justify immediate code.

The strongest candidate is:

- key / char semantic dispatch before writer encoding

But it still needs a stricter design first.

## Decision

Do not open `session/input.zig` by momentum.

Continue only if we can define one design that clearly separates:

- terminal-owned semantic input decisions

from:

- writer protocol encoding
- transport availability
- transport write mechanics

If that line cannot be drawn cleanly, War 4 should stop from the current
baseline.

## Bottom Line

War 4 has likely reached the point where the next input move requires a deeper
design step, not another direct ownership cut.
