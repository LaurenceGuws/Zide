# CZH-921 Carrier-Flow Audit Map — Outcome Carrier Simplification + Boundary De-dup Targets

**Ticket:** `CZH-921`  
**Sprint:** `CZH-S38`  
**Batch:** `CZH-B43`  
**Gate:** `CZH-GATE-97`  
**Date:** 2026-04-20  
**Scope:** behavior-neutral audit only (no product semantics changes)

---

## Purpose

Document the pre-simplification and target-simplified outcome carrier flow across terminal/widget presentation boundaries, then identify precise de-duplication targets for `CZH-922`..`CZH-930` execution.

This audit locks one ownership rule:

- **Terminal layer owns outcome classification + fold semantics.**
- **Widget layer remains integration facade (execution/context wiring) only.**

---

## Hard constraints (audit authority)

- Behavior freeze (no semantic product behavior change).
- No host ABI/C export changes.
- No compatibility/fallback branches.
- No source-ticket lineage comments in product source.
- Widget remains integration facade; terminal owns decision/fold semantics.

---

## Outcome carrier inventory (audited surfaces)

### Canonical carrier structs (terminal-owned)

- `RefreshOutcomeState`
- `ReusePresentOutcomeState`
- `DirectPresentOutcomeState`
- `TerminalPresentResult` (host-facing folded aggregate)

### Carrier helpers (terminal-owned)

- `classifyRefreshOutcome(...)`
- `classifyDirectPresentOutcome(...)`
- `reuseSuccessOutcome()`
- `presentResultFromRefreshOutcomeState(...)`
- `presentResultFromReuseOutcomeState(...)`
- `presentResultFromOutcomeState(...)` (generic fold hub)

### Widget boundary usage points (integration facade)

- Refresh execution wrapper and handoff path
- Reuse fast-path eligibility/execution wrapper
- Direct-present execution path fold callsite
- Widget integration/helper tests that lock boundary parity

---

## Observed pre-cut duplication patterns

### Pattern A — Refresh conjunction transport split across two arguments
**Observation:** Refresh fold path transported conjunction as a separate argument instead of carrying it inside refresh outcome state.

**Risk:** Duplicate transport hop increased callsite glue and made carrier contract less explicit.

**Target:** Inline conjunction in refresh outcome state and fold from that single carrier.

---

### Pattern B — Reuse success encoded twice (`reused` flag + `outcome == .reused`)
**Observation:** Reuse state carried both a dedicated boolean and canonical outcome enum signal.

**Risk:** Redundant truth surface; potential drift if fields diverge.

**Target:** Keep one canonical success signal: `outcome == .reused`.

---

### Pattern C — Direct-present fold reconstructed ad hoc at widget boundary
**Observation:** Direct-present execution path assembled generic fold parameters at callsite.

**Risk:** Boundary-level duplication of fold transport shape.

**Target:** Add/use direct canonical fold helper so callsites pass one direct carrier object + timing.

---

### Pattern D — Widget boundary comments/phrasing lagging carrier ownership
**Observation:** Some boundary notes still described split or separately-threaded conjunction transport after consolidation intent.

**Risk:** Documentation drift causing future reintroduction of duplicate glue.

**Target:** Keep comments present-tense and aligned with canonical carrier routes only.

---

## Canonical target flow map (post-simplification intent)

### Refresh path
1. Widget executes refresh cycle/presentation integration work.
2. Widget passes refresh enum + attachment conjunction once to terminal classifier.
3. Terminal returns `RefreshOutcomeState` with inline conjunction.
4. Terminal folds via refresh canonical helper into `TerminalPresentResult`.

### Reuse path
1. Widget computes integration prerequisites and delegates eligibility to terminal helper.
2. On success, terminal reuse outcome constructor returns canonical reuse carrier.
3. Terminal folds reuse carrier through canonical reuse fold helper.

### Direct-present path
1. Widget executes direct-present integration work.
2. Terminal classifier returns direct outcome carrier.
3. Terminal direct canonical fold helper produces `TerminalPresentResult`.

---

## De-duplication cut plan linked to ticket sequence

- `CZH-922` — Authority docs align to canonical carrier ownership/transport.
- `CZH-923` — Refresh carrier simplification (inline conjunction + fold signature cleanup).
- `CZH-924` — Reuse carrier simplification (remove duplicate success flag transport).
- `CZH-925` — Direct-present carrier simplification (canonical direct fold helper route).
- `CZH-926` — Widget/runtime boundary de-dup removal tied to simplified carrier flow.
- `CZH-927` — Helper-level invariants lock canonical carrier semantics.
- `CZH-928` — Integration invariants lock widget/terminal parity.
- `CZH-929` — Hygiene sweep for residual stale boundary phrasing/probe residue.
- `CZH-930` — Validation packet + checkpoint + gate handoff.

---

## Invariants to lock (behavior-neutral)

1. Refresh followup coupling remains valid:
   - `followup_required == true` implies `followup_reason != .none`
   - `followup_required == false` implies `followup_reason == .none`
2. Reuse success canonicalization:
   - `outcome == .reused` implies cache advanced + host target available + attachment ready.
3. Direct-present invariants:
   - cache advanced and host target leg true.
   - conjunction field remains direct-path contract value.
4. Fold parity:
   - outcome carrier fields and folded host-facing result remain coherent without boundary re-derivation.

---

## Non-goals (explicit)

- No renderer/backend redesign.
- No host contract/ABI changes.
- No changes to terminal semantic behavior.
- No compatibility shim introduction.
- No ticket history embedded in product source comments.

---

## Validation expectation for downstream tickets

The following ladder is required at sprint closure (`CZH-930`), after applying the simplification cuts:

- `zig build`
- `zig build test`
- `zig build -Dmode=terminal`
- `zig build -Dmode=editor`
- `timeout 3s zig build run -- --mode terminal`
- `python3 ops/android_terminal_host.py deploy`
- `adb logcat -c && adb shell am start -n uk.laurencegouws.zide/uk.laurencegouws.terminal.ZideActivity && adb logcat -d -s AndroidRuntime:E`

---

## Audit conclusion

Carrier ownership is already terminal-centered in structure, but refresh/reuse/direct paths had remaining transport duplication at boundary seams.  
The planned `CZH-S38` sequence is sufficient to collapse those duplicate hops while preserving behavior, ABI, and facade boundaries.