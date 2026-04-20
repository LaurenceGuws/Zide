# CZH-1189: Enforcement Matrix Determinism Audit + Ambiguity Map

Date: 2026-04-21  
Scope: Audit claim-to-lock matrix for order/wording ambiguities that can cause reviewer drift

## Determinism Audit Overview

After CZH-S67 completed claim-to-lock trace hardening with 14 claims unambiguously mapped to locks, this audit identifies potential sources of reviewer drift — inconsistent wording, varying citation formats, ordering ambiguities — that could allow different reviewers to interpret the same claim differently or miss nuanced differences in lock mappings.

**Reviewer drift vectors:**
- Inconsistent claim naming across similar concepts
- Varying lock detail specificity (line number vs function name vs type)
- Mixed lock type ordering (compile-time, runtime, test, code-review)
- Heterogeneous test binding citation formats
- Cross-path claim phrasing differences with subtle semantic variation
- Implicit vs explicit enforcement layer coverage

## Determinism Audit Results

### Vector 1: Claim Naming Consistency

**Current state:** 14 claims use mixed naming conventions.

**Pattern analysis:**

**By path - Refresh:**
- "No-bypass invariant" — semantic quality (what property holds)
- "Outcome type freeze" — mechanism (what freezes)
- "Transport determinism" — quality (property name)
- "Outcome state isolation" — mechanism (isolation property)

**By path - Reuse:**
- "Eligibility decision immutability" — semantic quality
- "Outcome type freeze" — mechanism (same as refresh)
- "Transport consistency" — quality
- "Success signal uniqueness" — semantic uniqueness

**By path - Direct:**
- "Updated flag determinism" — semantic quality
- "Field guarantees" — mechanism (guarantee structure)
- "Outcome type freeze" — mechanism (same as refresh/reuse)

**By path - Shared:**
- "No shared outcome production" — rule (what doesn't happen)
- "Attachment consistency" — property (consistency)
- "Transport routing immutability" — mechanism (immutability)

**Ambiguity risk:** Same concept ("outcome type freeze") appears in 3 paths with identical lock descriptions but inconsistent naming context (appears after different claims, no cross-path labeling). Reviewer might not recognize it as the same fundamental claim.

**Determinism hardening candidate:** Prefix or normalize naming scheme across paths to signal relationships:
- Same lock type → same name prefix
- Different lock type → clearly distinct names
- Cross-path claims → explicit "per-path variant" notation

---

### Vector 2: Lock Detail Specificity Variation

**Current state:** Lock descriptions vary in granularity and reference style.

**Pattern analysis:**

**Line number presence:**
- Claim 2 (Refresh type freeze): "assertion line 168" ✓ explicit
- Claim 10 (Direct field guarantees): "compile/runtime" — no line reference
- Claim 1 (No-bypass): "compile-time" only — no line reference
- Claim 6 (Reuse type freeze): no line reference given

**Function reference style:**
- Claim 3: "`refreshTransportFromResult()` logic" — function name only
- Claim 1: "`foldRefreshOutcomeToPresent` private" — function + type (privacy)
- Claim 5: "`reuseSuccessOutcome()` construction logic" — function + operation
- Claim 13: "`computeHostSurfaceAttachmentState()` is only function" — function + uniqueness claim

**Type references:**
- Claim 2, 6, 11: "Zig enum type" — generic, no specific type name given
- Claim 4: "RefreshOutcomeState internal" — specific type name + property
- Claim 12: "outcome types internal per path" — plural, no specific names

**Ambiguity risk:** Lock "detail" field claims differ in what constitutes a sufficient reference. Some cite line numbers, some function names, some type names, some properties. A reviewer could interpret "detail" inconsistently:
- Does "detail" mean "location" (line number)?
- Or "artifact" (function/type name)?
- Or "enforcement mechanism" (property like "private")?

**Determinism hardening candidate:** Standardize lock detail format:
- Compile-time locks: include artifact (function name, type name, enum variant) + property if needed
- Runtime locks: include function name + line number if possible
- Test locks: include test name + line range if available
- Unified format: `artifact:line lock_property` or `artifact[property]` where property is "private", "enum", "assertion", etc.

---

### Vector 3: Lock Type Ordering and Coverage Variation

**Current state:** Claims specify lock types inconsistently; some are single-layer, some are multi-layer.

**Pattern analysis:**

| Claim | Lock Type | Coverage | Comment |
|-------|-----------|----------|---------|
| 1 | compile-time | single | Only mentions privacy |
| 2 | compile/runtime | multi | Type system + assertion |
| 3 | runtime | single | Only logic |
| 4 | compile-time | single | Only type privacy |
| 5 | runtime | single | Only construction |
| 6 | compile-time | single | Only type enum |
| 7 | runtime | single | Only mapping logic |
| 8 | compile-time | single | Only type set |
| 9 | runtime | single | Only function purity |
| 10 | compile/runtime | multi | Struct + logic |
| 11 | compile-time | single | Only enum |
| 12 | compile-time | single | Only type privacy |
| 13 | compile-time | single | Only function uniqueness |
| 14 | compile-time | single | Only privacy |

**Ambiguity risk:** No standard pattern for "which enforcement layers must a claim specify?"
- Some claims cite only compile-time but presumably also have test coverage (not mentioned)
- Some claims cite multi-layer, others single
- Reviewer might wonder: "Should all claims specify compile-time AND runtime AND test? Or is single-layer sufficient?"
- Different reviewers might add different layers in future hardening, causing inconsistency

**Determinism hardening candidate:** Define explicit layer-citation rule:
- Option A: All claims must specify **minimum** 2 enforcement layers (compile-time + runtime, or compile-time + test)
- Option B: All claims must cite **all applicable** layers (even if some are implicit)
- Option C: Claims cite **the primary lock**, layers are implicit (simpler but less explicit)

---

### Vector 4: Test Binding Citation Format Variation

**Current state:** Test citations use mixed formats.

**Pattern analysis:**

| Claim | Test Citation Format | Style |
|-------|----------------------|-------|
| 1 | "outcome classification from refresh cycle is pure" | quoted string, no line ref |
| 2 | outcome classification test validates types | generic description, no quotes |
| 3 | "Refresh result helper preserves transport fields" | quoted string, no line ref |
| 4 | binding tests validate canonical production | generic, plural, no quotes |
| 5 | "Reuse success outcome invariants hold" | quoted string, no line ref |
| 6 | outcome type tests | generic, minimal |
| 7 | "Reuse fold helper preserves non-reused transport" + boundary test | quoted + generic |
| 8 | "Reuse success outcome invariants" | quoted string |
| 9 | "Direct present outcome classification is pure" | quoted string |
| 10 | field preservation test validates all three | generic description |
| 11 | classification test validates types | generic |
| 12 | outcome type tests validate per-path production | generic + detail |
| 13 | integration tests validate single path | generic + detail |
| 14 | "Fold routes consume contracted transport carrier" | quoted string |

**Ambiguity risk:** No consistent citation format. Quotes suggest a test name; generic descriptions suggest a category. Reviewer cannot easily:
- Find the actual test file/line
- Distinguish between "test category" and "specific test name"
- Verify whether "outcome type tests" is the same as "outcome type tests validate per-path production"

**Determinism hardening candidate:** Standardize test binding format:
- All citations include: test_file.zig:LINE_RANGE "test name" or test_category (explicit)
- Quoted strings must correspond to actual function names in test files
- Generic categories must be defined once in authority document with examples

---

### Vector 5: Cross-Path Claim Phrasing Variation

**Current state:** Same concept appears in multiple paths with different names.

**Identical lock mappings, different names:**

**"Outcome type freeze"** appears in 3 paths:
- Claim 2 (Refresh): "Outcome type freeze: .updated_and_presented | .presented"
- Claim 6 (Reuse): "Outcome type freeze: .reused | .skipped"
- Claim 11 (Direct): "Outcome type freeze: .updated_and_presented | .presented"

Refresh and Direct have identical outcome types but appear separate. Reuse is different.
- Question: Are these "the same claim" (outcome types are frozen per-path)?
- Or "three separate claims" (each path has its own type freeze)?

**Lock mechanism differs subtly:**
- Claim 1 (Refresh no-bypass): lock is `foldRefreshOutcomeToPresent` privacy
- Claim 14 (Shared routing): lock is fold helpers privacy

Both are "fold helper privacy" but framed differently:
- Claim 1 frames it as "no-bypass" (semantic property)
- Claim 14 frames it as "transport routing immutability" (mechanism)

Are these the same lock or different locks?

**Ambiguity risk:** Reviewer cannot determine:
- Whether cross-path "same-name" claims are instances of one principle or separate principles
- Whether two different-name claims with similar locks are redundant or genuinely distinct
- Whether future "outcome type freeze 2.0" claim is a violation or just another path variant

**Determinism hardening candidate:**
- Group claims by lock, not by path (e.g., "outcome type freeze — per-path instantiation")
- Or explicitly mark each cross-path variant with notation: "Claim 2: Outcome type freeze (Refresh variant)"
- Include cross-reference table showing which claims share locks

---

### Vector 6: Implicit vs Explicit Enforcement Layer Coverage

**Current state:** All claims say "✓ NONE" for ambiguity, but enforcement layer completeness is implicit.

**Pattern analysis:**

**Example: Claim 2 (Outcome type freeze - Refresh)**
- Lock: "Zig enum type + assertion line 168 (compile/runtime)"
- Cited layers: compile-time (type), runtime (assertion)
- Implied but uncited: test (test validates types), code-review (architect approval)

**Example: Claim 14 (Transport routing immutability - Shared)**
- Lock: "fold helpers private, prevent alternates (compile-time)"
- Cited layers: compile-time only
- Implied but uncited: runtime (logic ensures no alternates), test (routing test), code-review

**Ambiguity risk:** "Ambiguity: ✓ NONE" means the claim-to-lock mapping is unambiguous, but it doesn't assert that all 4 enforcement layers are present. Reviewer might:
- Assume a single-layer claim means only one layer guards it
- Miss implicit test coverage that validates the claim
- Not understand whether code-review approval is required or just implicit via prior review

**Determinism hardening candidate:**
- Explicit layer coverage table per claim: "Compile-time: ✓, Runtime: ✓, Test: ✓, Code-review: ✓" or explicit "not applicable"
- Or notation: "Ambiguity: ✓ NONE (4/4 layers covered)" or "Ambiguity: ✓ NONE (2/4 layers: CT+RT)"

---

## Determinism Ambiguity Summary Table

| Vector | Current State | Risk | Hardening Candidate |
|--------|---------------|------|---------------------|
| Claim naming | Mixed convention (semantic vs mechanism) | Reviewer misses cross-claim relationships | Prefix scheme or path-variant notation |
| Lock detail | Varies in specificity (line vs function vs type) | Unclear what constitutes "sufficient detail" | Standardized format: `artifact:line[property]` |
| Lock type coverage | Single or multi-layer, no pattern | Unclear which layers must be cited | Explicit minimum-layer or all-layer rule |
| Test binding format | Quoted strings, generic, mixed line refs | Cannot verify or locate tests | Standardized: file:LINE "name" or category (explicit) |
| Cross-path phrasing | Same lock, different names; different locks, similar names | Unclear if redundant or distinct principles | Group by lock with cross-ref table |
| Layer coverage | Implicit 4-layer guarantee in "✓ NONE" | Unclear which layers actually cover claim | Explicit layer coverage notation per claim |

**Total determinism drift vectors identified: 6**

**Impact: Medium**
- Claims are currently unambiguous (14/14 mapped with ✓ NONE)
- But future reviewers could introduce inconsistencies when updating claims
- Without explicit determinism rules, maintenance will accumulate wording drift

---

## Determinism Hardening Recommendations

### Phase 1: Authority Tightening (CZH-1190)

Define explicit determinism criteria in `TERMINAL_SURFACE_CONTRACT.md`:

1. **Claim Naming Consistency Rule**
   - Define naming scheme: Semantic quality (property) vs Mechanism (structure/process)
   - Establish prefix rule: "per-path freeze" vs "transport freeze" convention
   - Require cross-path variant notation where same claim appears multiple times

2. **Lock Detail Standardization Rule**
   - Compile-time locks: `ArtifactName[property]` (e.g., `RefreshOutcomeState[private]`, `OutcomeEnum[frozen]`)
   - Runtime locks: `function_name():LINE` (e.g., `classifyRefreshOutcome():168`)
   - Test locks: `test_file.zig:RANGE "test name"` (e.g., `test_presentation.zig:14-28 "outcome classification pure"`)
   - Consistent order: artifact, then line/range, then property/detail

3. **Lock Type Coverage Rule**
   - Minimum: all claims must cite at least compile-time OR runtime lock + test binding
   - Preferred: all claims cite **all applicable layers** (compile, runtime, test, code-review)
   - Notation: explicit layer coverage per claim for clarity

4. **Test Binding Format Rule**
   - All test citations must include: test_file.zig:LINE-RANGE "test name"
   - Generic categories allowed ONLY if defined once in authority document with examples
   - Test names must correspond to actual test function names in codebase

5. **Cross-Path Claim Grouping Rule**
   - Group claims by lock mechanism, then by path variant
   - Use notation: "Claim N: [Category] - [Path variant description]"
   - Include cross-reference table mapping shared locks to all claims that use them
   - Define when same-named claims are "instances of principle" vs "separate claims"

6. **Enforcement Layer Explicitness Rule**
   - All claims must list coverage: "Compile-time: ✓ [artifact], Runtime: ✓ [function], Test: ✓ [name], Code-review: [approval status]"
   - Or explicitly state "not applicable" for layers that don't apply
   - Ambiguity notation changes: "✓ NONE (4/4 layers)" or "✓ NONE (2 layers: compile+test)"

### Phase 2: Per-Path Determinism Hardening (CZH-1191..1194)

Update per-path enforcement docs (refresh, reuse, direct, shared) to apply standardized determinism format to all claims.

### Phase 3: Verification (CZH-1195)

Verify deterministic mapping remains unambiguous across all paths with new standardization rules applied.

---

## Determinism Audit Checklist

- ✓ Audited all 14 claims for naming consistency
- ✓ Identified 6 determinism drift vectors
- ✓ Analyzed lock detail variation across claims
- ✓ Reviewed test binding citation formats
- ✓ Examined cross-path claim phrasing
- ✓ Assessed enforcement layer coverage explicitness
- ✓ Developed hardening recommendations
- ✓ Identified authority tightening candidates (CZH-1190)
- ✓ Identified per-path hardening scope (CZH-1191..1194)
- ✓ Identified verification scope (CZH-1195)

**Audit complete. Ready for authority tightening (CZH-1190).**

**Determinism drift risk: MEDIUM → minimize via standardized format rules**
