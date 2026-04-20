# CZH-1131: Regression/Integration Governance Locks

Date: 2026-04-20  
Scope: Establish regression and integration governance locks for post-seal drift detection

## Regression Vectors Addressed

CZH-S59 sealed the contract. CZH-S60 establishes guards to prevent post-seal drift through 4 regression vectors:

1. **Test-Only Surface Leak** — Production code calls test helpers
2. **Outcome State Mutation** — Widget/helper code modifies outcome state after production
3. **Widget Bypass Attempt** — Widget constructs outcomes or calls fold helpers directly
4. **No-Bypass Invariant Drift** — Widget calls private helpers or alternate entry routes

## Regression Lock 1: Test-Only Surface Isolation

**Risk:** Production code calls test-only assertions or helpers (e.g., production code uses `assertRefreshOutcomeConsistency` for validation logic, not just testing).

**Guard:** Test-only surface physically isolated from production code paths.

**Implementation:**
- `assertRefreshOutcomeConsistency` (line 259) — test-only, called from test blocks + `foldRefreshOutcomeToPresent`
- `assertReuseOutcomeConsistency` (line 249) — test-only, called from test blocks + `foldReuseOutcomeToPresent`
- No production code directly calls these functions
- No production code depends on assertion side effects

**Verification:**
- Code review: No production functions call test-only assertions
- Test coverage: All test assertions covered by test execution
- No assertion result used for production control flow

**Enforcement:** Code review + test coverage + architecture review

**Regression detection:** Any PR adding production calls to test assertions is blocked by code review

## Regression Lock 2: Outcome State Immutability

**Risk:** Widget or helper code modifies `RefreshOutcomeState`, `ReusePresentOutcomeState`, or `DirectPresentOutcomeState` after canonical entry produces it.

**Guard:** Outcome states immutable after production; no modification possible post-generation.

**Implementation:**
- Outcome structures defined in terminal layer (`src/terminal/presentation_runtime.zig`)
- Widget code receives only `TerminalPresentResult` (derived from outcomes)
- No outcome state stored or cached at widget layer
- Outcome flows directly: classification → folding → result

**Verification:**
- No widget code constructs outcome states
- No widget code stores outcome state references
- All outcome-to-result transformations happen in canonical entries
- No outcome state visible outside terminal layer

**Enforcement:** Type system + code review

**Regression detection:** Type checker prevents construction; code review catches storage/mutation attempts

## Regression Lock 3: Widget Bypass Prevention

**Risk:** Widget code discovers and calls private fold helpers or constructs outcome states (e.g., via casting or unsafe code).

**Guard:** Private helpers uncallable from widget; outcome types internal to terminal layer.

**Implementation:**
- `foldRefreshOutcomeToPresent` (line 143) — private `fn`
- `foldReuseOutcomeToPresent` (line 170) — private `fn`
- `foldDirectOutcomeToPresent` (line 220) — private `fn`
- Outcome types not exported to widget imports
- `presentResultFromOutcomeState` (line 125) — private `fn`

**Verification:**
- Compile-time: Type checker prevents widget code from calling private functions
- Code review: No widget code references private helpers
- No unsafe code bypasses privacy constraints

**Enforcement:** Type system (compile-time) + code review

**Regression detection:** Compilation fails if widget attempts to call private fold helpers

## Regression Lock 4: No-Bypass Invariant Maintenance

**Risk:** Widget code finds alternate route to present (e.g., constructs outcome, calls helper directly, or intermediate composition) instead of calling canonical entry.

**Guard:** No alternate routes possible; canonical entries only entry points.

**Implementation - Refresh Path:**
- Only entry: `refreshPresentEntry` (line 155)
- No alternate outcome classification outside canonical entry
- No direct outcome folding from widget
- Verified call site: line 908 (widget refresh hook)

**Implementation - Reuse Path:**
- Only entry: `reuseEligibilityEntry` (line 182)
- No alternate outcome construction outside canonical entry
- No direct outcome folding from widget
- Verified call site: line 1404 (widget reuse dispatch)

**Implementation - Direct Path:**
- Only entry: `directPresentEntry` (line 229)
- No alternate outcome classification outside canonical entry
- No direct outcome folding from widget
- Verified call site: line 1223 (widget direct dispatch)

**Verification:**
- Compile-time: Private fold helpers cannot be called directly
- Code review: All outcome production routes through canonical entries
- No intermediate composition helpers exposed

**Enforcement:** Type system + code review + widget seam enforcement

**Regression detection:** Type checker + code review catch bypass attempts; unit/integration tests verify routing

## Regression Lock 5: Attachment State Consistency

**Risk:** Widget code recomputes attachment state independently instead of using canonical path, diverging from terminal-layer computation.

**Guard:** Attachment state computed canonically; widget never re-derives.

**Implementation:**
- Canonical computation: `computeHostSurfaceAttachmentState(...)` (line 269)
- Calls `TerminalPresentationBridge` for conjunction
- Widget receives computed state, never constructs independently

**Verification:**
- No widget code calls `TerminalPresentationBridge` directly
- No widget code re-derives attachment state computation
- All attachment state used in widget comes from canonical computation

**Enforcement:** Code review + widget boundary enforcement

**Regression detection:** Code review catches any widget re-computation; integration tests verify state consistency

## Integration Governance Checklist

- ✓ Test-only surface physically isolated (test assertions not called from production)
- ✓ Outcome state immutable (no post-production modification possible)
- ✓ Widget bypass impossible (fold helpers private, outcome types internal)
- ✓ Canonical entries single-path (no alternate routing)
- ✓ Attachment state canonical (only one computation path)
- ✓ All paths converge at TerminalPresentResult (unified result type)
- ✓ No test assertions in production control flow
- ✓ All outcome production through canonical entries verified

## Post-Seal Regression Response

**If regression vector detected:**

1. **Test-only surface leak:** Block PR, move code to test-only module, verify no production calls
2. **Outcome mutation:** Block PR, verify immutability, remove post-production modifications
3. **Widget bypass:** Block PR, type checker already prevents; if occurs, unsafe code involved
4. **No-bypass drift:** Block PR, verify routing through canonical entries, code review
5. **Attachment drift:** Block PR, replace with canonical computation call, verify state consistency

**Escalation:** Any regression vector reaching production requires post-release patch and architect review

**Regression/integration governance:** ✓ LOCKED

Next: CZH-1132 hygiene sweep + validation packet + gate handoff
