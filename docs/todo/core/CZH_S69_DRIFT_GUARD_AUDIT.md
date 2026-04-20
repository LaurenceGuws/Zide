# CZH-1197: Enforcement Matrix Drift-Guard Audit + Gap Map

Date: 2026-04-21  
Scope: Audit remaining drift vectors after determinism hardening; identify gaps in drift prevention

## Drift-Guard Audit Overview

After CZH-S68 hardened determinism format for all 14 claims, this audit identifies what drift could still occur during maintenance and what guards could prevent it.

**Distinction:**
- **Determinism (CZH-S68):** Claims are unambiguous NOW (standardized format, explicit layers, test binding citations)
- **Drift-guards (CZH-S69):** Prevent future violations of determinism rules through maintenance

**Drift scenarios to guard against:**
1. New claims added without standardized naming/format
2. Existing claims updated with non-standard lock details
3. Test bindings changed to vague/ambiguous citations
4. Layer coverage made implicit instead of explicit
5. Cross-path relationships lost or obscured
6. Authority document out of sync with per-path docs

## Drift Vectors Identified

### Vector 1: New Claim Addition Without Format

**Scenario:** Engineer adds Claim 15 (hypothetical) without following standardized format.

**Current state after CZH-S68:** 14 claims hardened, authority defines 6 criteria, but no explicit gate preventing malformed claims.

**Drift risk:** MEDIUM
- No compile-time check (claims are documentation only)
- No automated linter for claim format
- Code review could miss format violations if reviewer doesn't know the 6 criteria

**Guard candidates:**
- Authority policy: "All new claims must follow 6 determinism criteria or require architect pre-approval"
- Code review gate: explicit format checklist for claim additions
- Documentation template: required format for new claims (name, lock, layer coverage, test binding, cross-refs)

---

### Vector 2: Existing Claim Updated with Non-Standard Lock Detail

**Scenario:** Engineer updates Claim 5 (eligibility immutability) lock detail from `reuseSuccessOutcome():112` to `reuseSuccessOutcome()` (loses line number).

**Current state:** Lock detail format standardized in audit + per-path docs, but no policy preventing regression.

**Drift risk:** MEDIUM
- Format is documented but not enforced
- Change could slip through code review if reviewer doesn't cross-check against authority format
- Future readers would see mixed formats (some with line numbers, some without)

**Guard candidates:**
- Policy: "All lock details must include line numbers or artifact properties per Criterion 2"
- Verification gate: cross-reference lock details against authority before merge
- Blame/ownership: mark who last modified each claim to enable reviewer-to-expert routing

---

### Vector 3: Test Binding Citation Becomes Vague

**Scenario:** Engineer changes test citation from `test_presentation_runtime.zig:14-28 "outcome classification pure"` to `"outcome tests"` without defining the category.

**Current state:** Test citations standardized, but category definitions aren't formally enforced.

**Drift risk:** MEDIUM-HIGH
- Category definitions are implicit (found in authority document)
- New engineer might not know that "outcome tests" has a defined meaning
- Test binding verification becomes difficult without line ranges

**Guard candidates:**
- Policy: "All test citations must be file:RANGE \"name\" format OR reference an explicitly defined category"
- Authority policy: "Generic test categories must be registered in authority document with examples"
- Verification gate: validate test citation against file (fail if file/line not found)

---

### Vector 4: Layer Coverage Made Implicit

**Scenario:** Engineer removes explicit layer coverage table from Claim 3 and replaces with prose: "This is enforced by runtime logic."

**Current state:** Layer explicitness is documented in per-path docs, but no gate prevents backsliding to implicit coverage.

**Drift risk:** MEDIUM
- Implicit coverage hides what's actually verified vs. assumed
- Future readers can't quickly see which 4 layers apply
- Maintenance becomes harder if layers are unclear

**Guard candidates:**
- Policy: "All claims must have explicit layer coverage table (CT/RT/Test/CR) or explicit 'not applicable'"
- Template: required layer coverage format for all claim documentation
- Code review checklist: verify layer coverage is explicit, not hidden in prose

---

### Vector 5: Cross-Path Relationship Obscured

**Scenario:** Engineer documents two refresh-specific claims that actually share the same lock (e.g., both about outcome type freezing) without cross-referencing each other or using variant notation.

**Current state:** Cross-path grouping is standardized (variant notation, grouping tables), but no policy prevents future confusion.

**Drift risk:** MEDIUM
- Reviewers might not recognize that two similarly-named claims are instances of the same principle
- Future refactoring might miss the relationship and inadvertently violate one claim while updating the other
- Duplication/redundancy hard to spot

**Guard candidates:**
- Policy: "All cross-path claims must explicitly state their relationship (variant of principle X, or distinct principle)"
- Cross-reference table: mandatory for any claim appearing in multiple paths
- Naming convention: enforce variant notation in claim names where applicable

---

### Vector 6: Authority Document Out of Sync with Per-Path

**Scenario:** Engineer updates authority document to add a new determinism criterion, but forgets to update per-path docs to reference or apply it.

**Current state:** Authority and per-path docs are synchronized post-CZH-S68, but no gate prevents divergence.

**Drift risk:** HIGH
- Authority as "single source of truth" becomes unreliable if per-path docs diverge
- Different reviewers might reference different versions
- Maintenance becomes chaotic with multiple inconsistent sources

**Guard candidates:**
- Policy: "Authority document is immutable without per-path doc updates; changes to criteria require synchronized updates across all 4 paths"
- Verification gate: diff check authority vs. per-path docs (fail if claims don't match)
- Code review routing: require both authority AND per-path maintainers to approve changes

---

### Vector 7: Claim Renaming Without Cross-Reference Update

**Scenario:** Claim 2 renamed from "Outcome Type Freeze (Refresh Variant)" to "Type Invariant (Refresh)" without updating cross-reference tables or grouping maps.

**Current state:** Claims are named with variant notation, but no gate prevents breaking cross-references.

**Drift risk:** MEDIUM
- Cross-reference tables and grouping maps become stale
- Future readers can't find related claims by name
- Relationships become invisible

**Guard candidates:**
- Policy: "Claim renames require update to all cross-reference tables and grouping maps"
- Verification gate: validate all cross-references resolve to correct claims
- Ownership: assign someone to maintain cross-reference tables

---

### Vector 8: Test Binding File/Line Becomes Stale

**Scenario:** Test function is renamed/moved, but documentation isn't updated. Citation stays as `test_presentation_runtime.zig:14-28 "outcome classification pure"` but line 14-28 now contains a different test.

**Current state:** Test bindings are standardized with file/line, but no automated verification that cited lines still contain cited test.

**Drift risk:** MEDIUM
- Test citations become unreliable over time as code evolves
- Readers can't verify the binding exists
- Future maintenance assumes test exists when it may not

**Guard candidates:**
- Verification gate: validate test binding citation (attempt to find exact test function at cited line)
- Policy: "Any test function rename/move requires citation update across all claim documentation"
- Automated check: script to verify all test bindings resolve to actual functions

---

## Drift-Guard Coverage Gap Analysis

**Vectors identified: 8**

**Current guard coverage (post-CZH-S68):**
- Documentation standards: 6 criteria defined (naming, detail, layer coverage, test binding, cross-path grouping, layer explicitness)
- Code review gates: architect approval required for sealed claims
- Cross-references: authority document as source of truth

**Coverage gaps:**
1. No enforcement for new claims (must follow format but no gate prevents violations)
2. No verification for lock detail format compliance
3. No validation for test binding verifiability
4. No enforcement for explicit layer coverage (only documentation standard)
5. No mechanism to track cross-path relationships
6. No sync verification between authority and per-path docs
7. No check for cross-reference staleness
8. No validation that test citations still resolve to correct tests

**Total gaps: 8** (one per drift vector)

---

## Drift-Guard Tightening Recommendations

### Phase 1: Authority Tightening (CZH-1198)

Define explicit drift-guard policies in TERMINAL_SURFACE_CONTRACT.md:

1. **New Claim Policy:** "All new enforcement claims must follow 6 determinism criteria (naming, lock detail, layer coverage, test binding, cross-path grouping, layer explicitness) or require architect pre-approval"

2. **Lock Detail Immutability Policy:** "Lock details must not be updated without corresponding format verification. Format: artifact:line[property] for compile-time, artifact():LINE for runtime. Updates require architect review"

3. **Test Binding Verifiability Policy:** "All test bindings must be file:RANGE \"test_name\" format or reference explicitly defined category. Unverifiable citations require architect pre-approval"

4. **Layer Explicitness Policy:** "All claims must have explicit layer coverage (CT/RT/Test/CR documented or marked not applicable). Implicit layer coverage prohibited. Code review gate: mandatory layer table per claim"

5. **Cross-Path Relationship Policy:** "Any claim appearing in multiple paths must be explicitly labeled as 'variant of [principle]' or 'distinct principle [name]'. Relationships tracked in authority grouping table. Updates to grouping require architect review"

6. **Authority-Per-Path Sync Policy:** "Authority document and per-path enforcement docs must remain synchronized. Changes to determinism criteria in authority require synchronized updates across all 4 per-path docs. Verification gate: diff check mandatory before merge"

7. **Cross-Reference Maintenance Policy:** "Cross-reference tables (lock → claims mapping) are maintained in authority document. Any claim addition/rename/deletion requires cross-reference update. Code review gate: explicit cross-ref table verification"

8. **Test Binding Staleness Policy:** "Test bindings are point-in-time citations. When test function is renamed/moved, ALL documentation must be updated. Verification gate: script validates test binding resolution (attempt to locate test at cited line)"

### Phase 2: Per-Path Drift-Guard Implementation (CZH-1199..1202)

Update per-path enforcement docs (refresh, reuse, direct, shared) to add explicit drift-guards:
- Add "Drift-Guard Summary" section per path
- Map drift vectors to specific guards per path
- Document what changes require architect review
- Add regression guards for claim/lock relationship integrity

### Phase 3: Verification (CZH-1203)

Verify all 8 drift vectors have corresponding guards:
- New claim gate: policy + code review checklist
- Lock detail guard: format verification policy
- Test binding guard: verifiability policy + script
- Layer coverage guard: explicit table requirement
- Cross-path guard: variant notation + grouping table
- Authority sync guard: synchronized update policy
- Cross-reference guard: table maintenance + verification
- Test staleness guard: citation validation + update policy

---

## Drift-Guard Audit Checklist

- ✓ Audited claim documentation for remaining drift vectors
- ✓ Identified 8 drift vectors remaining after determinism hardening
- ✓ Assessed drift risk per vector (MEDIUM to HIGH)
- ✓ Developed guard candidates per vector
- ✓ Identified coverage gaps (8 gaps, 8 vectors)
- ✓ Designed Phase 1 authority tightening (8 policies)
- ✓ Identified Phase 2 per-path implementation scope
- ✓ Identified Phase 3 verification scope

**Audit complete. Ready for authority tightening (CZH-1198).**

**Drift risk post-CZH-S68:** MEDIUM (determinism format locked but no enforcement prevents violations)
**Drift risk post-CZH-S69:** LOW (drift-guards will close 8/8 gaps, enforcement enabled)
