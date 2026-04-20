# CZH-951 Alias/Vocabulary Audit Map — Boundary Alias Pruning + Surface Contract Narrowing

**Ticket:** `CZH-951`  
**Sprint:** `CZH-S41`  
**Batch:** `CZH-B46`  
**Gate:** `CZH-GATE-100`  
**Date:** 2026-04-20  
**Scope:** behavior-neutral audit and pruning map only (no product behavior/ABI change)

---

## Purpose

Record the current boundary alias/vocabulary spread across terminal/widget presentation seams, define canonical term replacements, and provide the execution map for `CZH-952`..`CZH-960`.

S41 objective:

- prune remaining boundary aliases
- narrow surface-contract vocabulary to canonical transport terms
- preserve terminal-owned decision/fold semantics and widget integration-facade role

---

## Hard constraints (normative)

- Behavior freeze.
- No host ABI/C export changes.
- No compatibility/fallback branches.
- No ticket/sprint lineage in source comments.
- No stale debug/probe residue.
- Source comments remain present-tense ownership/invariant statements only.

---

## Canonical vocabulary set (authoritative for S41)

Use these as the contract dictionary for boundary-facing transport semantics:

### Ownership + role terms
- **terminal-owned canonical fold path**
- **widget integration facade**
- **host-facing result transport**
- **execution-local carrier**
- **boundary helper**

### Refresh terms
- **refresh cycle result**
- **refreshed presentation result**
- **refresh boundary helper**
- **refresh folded result**

### Reuse terms
- **reuse attempt outcome**
- **reuse boundary helper**
- **reuse folded result**
- **canonical reuse success signal** (`outcome == .reused`)

### Direct/fold terms
- **direct timing carrier**
- **direct folded result**
- **canonical fold route**

### Contract terms
- **single-path transport**
- **canonical entrypoint**
- **no re-derivation boundary rule**
- **transport parity invariants**

---

## Audited alias patterns to prune

### A1 — “wrapper” vs “boundary helper” drift
**Observed drift:** helper naming and comments alternate between “wrapper”, “helper”, “route”, “path” without stable contract meaning.

**Canonical replacement:**  
- use **boundary helper** for functions that convert boundary execution carriers into host-facing result transport  
- use **canonical entrypoint** for stable public fold/classification routes

---

### A2 — refresh transport wording split
**Observed drift:** refresh terms appear as mixed “timing helper”, “refresh result helper”, “cycle helper”, “presentation helper” in ways that blur where host-facing result is finalized.

**Canonical replacement:**  
- use **refresh boundary helper** for `refreshedPresentationResultFromCycle(...)` semantics  
- use **refresh folded result** for the resulting host-facing folded payload

---

### A3 — reuse transport wording split
**Observed drift:** “reuse fold helper”, “reuse wrapper”, “reuse attempt fold”, and “present result from reuse” used interchangeably.

**Canonical replacement:**  
- use **reuse boundary helper** for `foldReuseAttemptResultToPresent(...)`  
- use **reuse folded result** for output host-facing transport  
- preserve **canonical reuse success signal** wording for `outcome == .reused`

---

### A4 — generic “result” ambiguity
**Observed drift:** “result” used for execution-local carriers and host-facing folded transport without qualifier.

**Canonical replacement:**  
- use **execution-local carrier** for non-host-facing intermediate structs  
- use **host-facing result transport** for folded output

---

### A5 — direct/fold transport naming fuzziness
**Observed drift:** direct path timing/result terms occasionally mirror refresh/reuse labels.

**Canonical replacement:**  
- use **direct timing carrier** for timing-only transport  
- use **direct folded result** for host-facing folded output

---

## Surface-contract narrowing plan (S41)

### Target T1 — Document authority narrowing (`CZH-952`)
Narrow architecture docs to canonical vocabulary only for refresh/reuse/direct boundary semantics.

### Target T2 — Refresh alias pruning (`CZH-953`)
Rename/retarget refresh boundary commentary and helper references to canonical refresh terms.

### Target T3 — Reuse alias pruning (`CZH-954`)
Rename/retarget reuse boundary commentary and helper references to canonical reuse terms.

### Target T4 — Direct/fold alias pruning (`CZH-955`)
Prune direct/fold terminology drift and lock canonical direct/fold terms.

### Target T5 — Widget/runtime boundary cleanup (`CZH-956`)
Remove stale alias glue and wording leftover after vocabulary narrowing.

### Target T6 — Contract locks (`CZH-957`, `CZH-958`)
Add helper and integration invariants that use canonical vocabulary routes and assert behavior parity.

### Target T7 — Hygiene + gate packet (`CZH-959`, `CZH-960`)
Clean residual stale terms/probe residue, then publish validation/gate docs.

---

## Canonical term mapping table

| Legacy/alias phrasing | Canonical phrasing |
|---|---|
| refresh timing helper | refresh boundary helper |
| refresh wrapper result | refresh folded result |
| reuse wrapper | reuse boundary helper |
| reuse fold wrapper | reuse boundary helper |
| reuse helper result | reuse folded result |
| reused flag semantics | canonical reuse success signal |
| direct helper timing map | direct timing carrier |
| direct result fold route | direct folded result / canonical fold route |
| result helper (ambiguous) | execution-local carrier or host-facing result transport (choose one explicitly) |
| path/route (ambiguous) | single-path transport or canonical entrypoint (as applicable) |

---

## Invariants to lock with terminology (behavior-neutral)

1. **Single-path refresh transport invariant**  
   Refresh boundary helper returns folded host-facing result transport through terminal-owned canonical route.

2. **Single-path reuse transport invariant**  
   Reuse boundary helper folds both reused and non-reused attempts through one canonical helper route.

3. **Canonical success signal invariant**  
   Reuse success semantics remain `outcome == .reused`; no auxiliary success alias terms.

4. **No re-derivation boundary invariant**  
   Widget boundary terminology reflects integration/execution ownership only; no semantic fold ownership wording at widget layer.

5. **Direct/fold parity invariant**  
   Direct timing carrier + canonical fold route vocabulary remains explicit and non-overlapping with refresh/reuse boundary terms.

---

## Non-goals

- No semantic runtime behavior changes.
- No API/ABI changes.
- No architectural reshaping beyond vocabulary/alias pruning in this sprint.
- No compatibility shims.
- No historical-progress comments in source.

---

## Validation expectation for sprint closure (`CZH-960`)

- `zig build`
- `zig build test`
- `zig build -Dmode=terminal`
- `zig build -Dmode=editor`
- `timeout 3s zig build run -- --mode terminal`
- `python3 ops/android_terminal_host.py deploy`
- `adb logcat -c && adb shell am start -n uk.laurencegouws.zide/uk.laurencegouws.terminal.ZideActivity && adb logcat -d -s AndroidRuntime:E`

---

## Audit conclusion

S40 established consolidated refresh/reuse boundary transport routes.  
S41 should now prune residual alias vocabulary and tighten surface-contract language so boundary semantics are described with one canonical dictionary across docs, code comments, and invariants—without changing behavior or ABI.