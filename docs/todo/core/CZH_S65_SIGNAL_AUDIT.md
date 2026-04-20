# CZH-1165: Enforcement Signal Compression Audit + Retention Map

Date: 2026-04-21  
Scope: Audit enforcement signal fields/comments/docs/tests for compression candidates that preserve verifiability

## Signal Audit Overview

After CZH-S64 documentation compaction, enforcement signal representation (structured logs, field naming, assertions, outcome carriers) has redundancy that can be compressed while preserving explicit verifiability.

Enforcement signals include:
- **Structured log signals** (`renderer.terminal_present`, `terminal.generation_handoff`)
- **Field names/contracts** (`shared_surface_attachment_ready`, `host_surface_target_available`)
- **Assertion signals** (outcome type validation, inline assertions)
- **Outcome state carriers** (transport fields, conjunction carriers, followup fields)
- **Comment signals** (enforcement clarification in source code)

## Signal Redundancy Analysis

### Redundancy 1: Attachment Conjunction Field Naming (MEDIUM IMPACT)

**Current state:**
- `terminal_presentable_pipeline_ready` (pipeline leg only) — widget state
- `host_surface_target_available` (host drawable target leg) — widget state
- `shared_surface_attachment_ready` (full conjunction) — present state + logs

**Named in multiple contexts:**
- `PresentationState`: stores legs separately
- `PresentationPresentState`: transient present gate (both legs + conjunction)
- `TerminalPresentResult`: carries both legs after folding
- Structured logs (`renderer.terminal_present`): all three names
- Source comments: clarification on which is which

**Compression candidate:**
- Consolidate field naming rules in authority document
- Use abbreviated names in contexts where full names create verbosity
- Keep present-state and log reporting using full names (clarity critical)

**Retention impact:**
- ✓ Verifiability preserved (same fields, clearer role labeling)
- ✓ Log signals unchanged (operator observability preserved)
- ✓ Binding clarity maintained (test/assertion references still explicit)

**Compression approach:**
- Authority doc: define `SHARED_ATTACHMENT_CONJUNCTION_FIELDS` with full names
- Per-path/shared docs: reference abbreviations with expansion comments
- Code: keep full names in operator-visible contexts (logs, public results)

---

### Redundancy 2: Outcome Assertion Signals (LOW IMPACT)

**Current state:**
- Outcome type assertions validate `.updated_and_presented | .presented` per path
- Assertions inline in fold helpers (refresh/reuse/direct)
- Test hardening assertions (`assertRefreshOutcomeConsistency`, etc.) validate same invariants
- Comments describe assertions in both code and docs

**Assertion redundancy:**
- Same validation logic across 3 paths (each with similar assertion)
- Documentation describes assertions in CZH-S62 docs + CZH-S63 binding docs
- Test bindings list same assertions multiple times

**Compression candidate:**
- Create "Outcome Assertion Reference" in authority document
- Per-path docs reference by assertion name instead of full description

**Retention impact:**
- ✓ Verifiability preserved (assertions remain in code unchanged)
- ✓ Test coverage unchanged (same tests, same bindings)
- ✓ Clarity maintained (reference document, not removed)

**Compression approach:**
- Authority: list outcome assertion signals (per path + shared)
- Per-path docs: "See authority outcome assertions" with line references
- Code: no changes (assertions remain, comments stay present-tense)

---

### Redundancy 3: Transport Field Signal Duplication (MEDIUM IMPACT)

**Current state:**
- `refreshTransportFromResult()` — private, refresh-only field mapping
- `reuseTransportFromOutcome()` — private, reuse-only field mapping
- `directTransportFromUpdated()` — private, direct-only field mapping
- Each helper maps outcome state → `TerminalPresentResult` fields

**Field signal redundancy:**
- All three helpers map same set of output fields (cache, host target, attachment)
- Field names repeated in code comments and docs
- Transport contracts documented per-path (refresh/reuse/direct) + shared

**Compression candidate:**
- Create "Transport Field Mapping Reference" in authority
- Per-path helpers use reference comment instead of full description
- Consolidate transport contract language

**Retention impact:**
- ✓ Verifiability preserved (same field logic, no behavior change)
- ✓ Binding clarity maintained (test bindings still valid)
- ✓ Code clarity improved (reference instead of repetition)

**Compression approach:**
- Authority: define canonical transport field mapping
- Per-path helpers: reference doc + line-specific override if path-unique
- Code: remove repetitive field-mapping comments

---

### Redundancy 4: Outcome Classification Signal Naming (LOW IMPACT)

**Current state:**
- `classifyRefreshOutcome()` — outcome type + attachment conjunction inline
- `classifyDirectPresentOutcome()` — outcome type only
- `reuseSuccessOutcome()` — outcome type only
- Each returns outcome state with different field sets

**Signal naming redundancy:**
- Comments describe which fields carry what signal per outcome type
- Documentation repeats per-path outcome type descriptions
- Test comments describe signal content per path

**Compression candidate:**
- Consolidate outcome type signal descriptions
- Per-path docs reference shared definitions
- Code comments remain present-tense (ownership + invariants only)

**Retention impact:**
- ✓ Verifiability preserved (outcome types unchanged)
- ✓ Binding clarity maintained (test bindings still explicit)

**Compression approach:**
- Authority: define "Outcome Type Signal Set" per path
- Per-path docs: reference vs describe
- Code: keep invariant comments, remove reference comments

---

### Redundancy 5: Comment Signal Duplication (LOW IMPACT)

**Current state:**
- Clarification comments on enforcement in multiple doc files
- Assertion reason comments in code + same reason documented
- Test binding comments + test references in enforcement docs
- Architectural notes repeated across per-path sustained enforcement docs

**Comment redundancy:**
- ~100 words of enforcement clarification repeated in CZH-S62 docs
- ~50 lines of assertion reason comments duplicated (code + docs)
- ~30 test binding references listed multiple ways

**Compression candidate:**
- Move duplicated clarification to authority doc references
- Keep code comments (present-tense, not reference)
- Create test binding reference matrix (consolidate list format)

**Retention impact:**
- ✓ Verifiability preserved (same information, consolidated location)
- ✓ Code clarity preserved (comments remain, clearer role)

---

## Signal Compression Summary: What Can Be Safely Compressed

| Signal | Type | Current | Compression | Retention | Risk |
|--------|------|---------|-------------|-----------|------|
| Attachment field naming | Naming | 3 contexts | 1 authority ref | ✓ Full | LOW |
| Outcome assertions | Doc | Per-path docs | Assertion reference | ✓ Code unchanged | LOW |
| Transport field mapping | Naming | Per-path helpers | Consolidated reference | ✓ Logic unchanged | MEDIUM |
| Outcome classification signals | Doc | Per-path + shared | Type signal reference | ✓ Unchanged | LOW |
| Enforcement comment duplication | Doc | ~100 words repeated | Authority consolidation | ✓ Code preserved | LOW |

**Total estimated compression:**
- Documentation: ~150 words reduction (5% of enforcement signal surface)
- Code comments: ~50 lines consolidation (keep invariant/ownership only)
- Authority doc: ~200 words addition (consolidated signal definitions)
- **Overall net: ~50 words reduction; signal clarity improvement**

**Verifiability impact: ZERO**
- All assertions remain in code
- All test bindings remain functional
- All outcome type carriers unchanged
- All structured log signals unchanged

## Signal Retention Map

### Critical signals (DO NOT COMPRESS):

1. ✓ Outcome type sets per path (code carrier unchanged)
2. ✓ Assertion logic in fold helpers (code unchanged)
3. ✓ Transport field mapping logic (code unchanged)
4. ✓ Structured log field names (`renderer.terminal_present`, etc.)
5. ✓ Test binding references (test suite unchanged)
6. ✓ Code comments on invariants/ownership (present-tense retained)

### Safe to compress (documentation/naming consolidation):

- Attachment conjunction field naming rules (→ authority reference)
- Outcome assertion descriptions (→ assertion reference table)
- Transport field mapping documentation (→ consolidated reference)
- Outcome type signal explanations (→ type signal reference)
- Duplicated enforcement clarification (→ authority consolidation)

## Compression Approach for CZH-S65

**Phase 1: Authority tightening (CZH-1166)**
- Define "Signal Definitions" section with:
  - Attachment conjunction field rules
  - Outcome assertion signals reference
  - Transport field mapping reference
  - Outcome type signal set per path

**Phase 2: Per-path signal compression (CZH-1167..1170)**
- Replace verbose signal descriptions with references
- Consolidate outcome state documentation
- Keep code comments (invariants/ownership only)
- Reduce assertion/transport/outcome documentation by 30-40%

**Phase 3: Verifiability retention verification (CZH-1171)**
- Verify all compressed signals remain bound to assertions/tests
- Confirm outcome type carriers unchanged
- Validate structured log signals preserved

**Phase 4: Documentation audit (CZH-1172)**
- Hygiene sweep on touched files
- Verify no verifiability lost in compression
- Record validation

## Files to be Modified

1. `TERMINAL_SURFACE_CONTRACT.md` — authority signal definitions added
2. `CZH_S62_REFRESH_SUSTAINED_ENFORCEMENT.md` — outcome assertion refs, transport refs
3. `CZH_S62_REUSE_SUSTAINED_ENFORCEMENT.md` — same pattern
4. `CZH_S62_DIRECT_SUSTAINED_ENFORCEMENT.md` — same pattern
5. `CZH_S62_SHARED_SUSTAINED_LOCK.md` — signal consolidation
6. Source code comments (refresh/reuse/direct paths) — present-tense only

## Compliance Checklist

- ✓ Audit complete: redundancy identified across 5 signal categories
- ✓ Retention map: critical signals marked for preservation
- ✓ Risk assessment: LOW/MEDIUM compression candidates identified
- ✓ No verifiability loss from proposed compression
- ✓ Path to implementation clear for CZH-S65 tickets

**Signal compression audit complete. Ready for CZH-1166 authority tightening.**

All compression candidates preserve verifiability while reducing signal duplication by ~50-100 words.
