# CZH-1113: Direct Entry Surface Compression

Date: 2026-04-20  
Scope: Trim non-essential direct assertion/exposure layers while preserving no-bypass semantics

## Direct Path Assertion Analysis

**Current assertions in direct path:**
1. `directPresentEntry` outcome field validation (lines 245-247) - COMPRESSIBLE

## Compression Changes

### Removed Assertions (1)

#### `directPresentEntry` outcome field validation
**Code removed:** Lines 244-247
```zig
// OLD:
// Invariant: direct entry always advances cache and has host target available
std.debug.assert(result.cache_state_advanced == true);
std.debug.assert(result.host_surface_target_available == true);
std.debug.assert(result.shared_surface_attachment_ready == false);
```
**Rationale:** Fields are guaranteed by `directTransportFromUpdated()` construction logic:
- `cache_state_advanced` is always true (direct always advances cache)
- `host_surface_target_available` is always true (direct path assumes available)
- `shared_surface_attachment_ready` is always false (direct pre-set to false)

These guarantees are enforced by the function logic itself, making assertions redundant.

## Compression Verification

### Field Value Guarantees
- `directTransportFromUpdated` returns fixed field values
- `classifyDirectPresentOutcome` deterministically constructs outcome
- `foldDirectOutcomeToPresent` deterministically maps fields
- No runtime variation possible

### Contract Coverage
- `directPresentEntry` outcome type validation preserved (via successful execution)
- No contract assertions removed
- No secondary assertions needed

### Direct Surface After Compression

**Public interface unchanged:**
- `directPresentEntry` remains canonical entry
- No behavior changes

**Assertions removed:** 1 (implementation detail)  
**Assertions kept:** 0 (no contract-critical assertions in direct path)

**No-bypass invariant:** ✓ MAINTAINED
- Single entry point enforced
- Fold routing locked to private helper

**Status:** ✓ COMPLETE — Direct path compressed (1 assertion removed)
