# CZH-1139: Regression/Integration Lock Expansion

Date: 2026-04-20  
Scope: Integration enforcement locks covering new tightened governance

## Integration Enforcement Locks (Post-CZH-S60 Baseline)

### Test-Only Surface Leak Prevention
- Verify: No production code imports or calls test assertions
- Mechanism: Test assertions (assertRefreshOutcomeConsistency, assertReuseOutcomeConsistency) are public but isolated
- Enforcement: Code review + test coverage
- Status: ✓ LOCKED

### Outcome State Mutation Prevention
- Verify: Outcome state flows directly from classification → folding → result
- No intermediate storage or modification points
- Mechanism: Private fold helpers prevent alternate routes
- Enforcement: Type system + code review
- Status: ✓ LOCKED

### Widget Bypass Prevention
- Verify: Widget cannot construct outcomes or call fold helpers
- Mechanism: Outcome types internal, fold helpers private
- Enforcement: Compile-time (type system prevents construction)
- Status: ✓ LOCKED

### No-Bypass Invariant Maintenance
- Verify: All canonical entries called from single verified sites in widget
- Mechanism: Private fold helpers enforce single routing
- Enforcement: Code review + call site verification
- Status: ✓ LOCKED

### Attachment State Consistency
- Verify: Attachment state computed canonically, not re-derived in widget
- Mechanism: `computeHostSurfaceAttachmentState()` is only attachment computation
- Enforcement: Code review + widget boundary
- Status: ✓ LOCKED

### Transport Routing Immutability
- Verify: All transport fields set deterministically in fold helpers
- No conditional field logic or post-production modifications
- Mechanism: Private `refreshTransportFromResult`, `reuseTransportFromOutcome`, `directTransportFromUpdated`
- Enforcement: Code review + type system
- Status: ✓ LOCKED

**Integration enforcement: EXPANDED AND COMPLETE**

All 5 regression vectors + 4 extension vectors protected by enforcement stack.
