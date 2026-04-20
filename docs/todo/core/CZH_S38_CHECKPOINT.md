# CZH-S38 Checkpoint — Outcome Carrier Simplification + Boundary De-duplication

**Sprint:** CZH-S38  
**Batch:** CZH-B43  
**Gate:** CZH-GATE-97  
**Date:** 2026-04-20  
**Status:** review_gate (awaiting Architect)

## Sprint Outcome

Tickets `CZH-921` through `CZH-930` were executed in strict order with one commit per ticket.
This sprint remained behavior-neutral and preserved all hard constraints:

- behavior freeze maintained
- no host ABI/C export changes
- no compatibility/fallback branches introduced
- no ticket/sprint lineage added to source comments
- widget remained integration facade while terminal-owned decision/fold semantics were tightened

## Commit Ladder

| Ticket | Commit | Description |
|--------|--------|-------------|
| CZH-921 | `602e977e` | Carrier-flow audit + de-dup map |
| CZH-922 | `8c72dd32` | Authority tightening (doc-only) |
| CZH-923 | `3627c76e` | Refresh outcome carrier simplification (inline conjunction carrier + folded path simplification) |
| CZH-924 | `8c24955f` | Reuse outcome carrier simplification (removed redundant `reused` field transport; outcome enum is canonical) |
| CZH-925 | `0fea268b` | Direct-present outcome carrier simplification (canonical direct fold helper; callsite de-dup) |
| CZH-926 | `edd8ef1e` | Widget/runtime boundary de-dup cut (removed duplicate fold glue and stale boundary phrasing) |
| CZH-927 | `a1d756b1` | Helper-level invariants (carrier-path helper tests tightened for refresh/direct semantics) |
| CZH-928 | `24effe28` | Integration invariants (widget/terminal boundary parity tests for inline refresh + direct fold helper) |
| CZH-929 | `a46ac4dd` | Hygiene sweep (no remaining stale carrier-comment residue in touched seams) |
| CZH-930 | `017ade77` | Validation packet + gate handoff |

## Validation

### Required ladder

- `zig build` — **PASS**
- `zig build test` — **PASS**
- `zig build -Dmode=terminal` — **PASS**
- `zig build -Dmode=editor` — **PASS**
- `timeout 3s zig build run -- --mode terminal` — **PASS (bounded smoke; command exits by timeout as intended after startup banner)**
- `python3 ops/android_terminal_host.py deploy` — **PASS**
- `adb logcat -c && adb shell am start -n uk.laurencegouws.zide/uk.laurencegouws.terminal.ZideActivity && adb logcat -d -s AndroidRuntime:E` — **PASS (no AndroidRuntime:E output)**

## Key Changes (Behavior-Neutral)

### 1) Refresh carrier path simplification

- `RefreshOutcomeState` now carries `shared_surface_attachment_ready` inline.
- `classifyRefreshOutcome(...)` now receives and stores conjunction in the refresh outcome state.
- `presentResultFromRefreshOutcomeState(...)` reads conjunction from outcome state directly (no separate argument hop).

### 2) Reuse carrier path simplification

- Removed duplicate `reused` boolean transport from `ReusePresentOutcomeState`.
- Reuse success/fold/hardening now key off canonical `outcome == .reused`.

### 3) Direct-present carrier path simplification

- Added canonical helper `presentResultFromDirectPresentOutcomeState(...)`.
- Direct callsites now fold through this helper instead of reconstructing generic-fold parameter bundles locally.

### 4) Boundary de-duplication

- Widget presentation runtime now consumes terminal-owned carrier helpers with fewer duplicate boundary hops.
- Integration facade role remains intact; semantic classification/folding stays terminal-owned.

### 5) Invariant lock coverage

- Helper-level tests lock inline refresh carrier semantics and direct canonical fold parity.
- Integration tests lock widget/terminal parity for refresh and direct carrier paths.

## Board / Gate Notes

- Per board rules, movement into `review_gate`/`done` is Architect-owned.
- This document is the engineer gate packet for `CZH-GATE-97`.

## Files touched in this sprint window

- `app_architecture/terminal/TERMINAL_SURFACE_CONTRACT.md`
- `src/terminal/presentation_runtime.zig`
- `src/terminal/test_presentation_runtime.zig`
- `src/ui/widgets/terminal_widget_presentation_runtime.zig`
- `src/ui/widgets/test_presentation_runtime_integration.zig`
