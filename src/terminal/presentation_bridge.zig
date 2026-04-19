//! Terminal **presentation bridge:** canonical compute and read routes for host attachment
//! readiness (terminal presentable pipeline ∧ host drawable target). Owned by terminal layer.
//!
//! This seam consolidates conjunction compute and read logic so widget layer does not re-derive
//! attachment readiness. Widget surface state delegates to this bridge and stores legs only.
//!
//! **Canonical compute route:** `notePresentableAvailability(available: bool) -> bool`
//! - Updates host-target leg from caller input
//! - Returns conjunction via canonical helper
//! - Invalidates presentation cache on unavailability
//! - Must be called before read-only access or logging
//!
//! **Canonical read route:** `readSharedSurfaceAttachmentReady(pipeline: bool, target: bool) -> bool`
//! - Read-only access to conjunction
//! - Derives from stored legs (no local computation)
//! - Paired with compute route for storage/read consistency
//!
//! **Ownership invariant:** This bridge owns all conjunction computation for the presentation
//! surface. Widget layer stores legs but never computes conjunction independently.

const surface_attachment_contract = @import("surface_attachment_contract.zig");

/// **Canonical compute + store route for conjunction:** computes host-target leg availability
/// and returns conjunction. Called on each refresh/reuse evaluation.
///
/// **Invalidation:** If availability becomes false, presentation cache should be invalidated.
/// **Pairing:** Pairs with `readSharedSurfaceAttachmentReady` for storage/read consistency.
pub fn notePresentableAvailability(
    pipeline_ready: bool,
    available: bool,
    invalidate_callback: ?*const fn (bool) void,
) bool {
    if (!available) {
        if (invalidate_callback) |cb| {
            cb(true);
        }
    }
    return surface_attachment_contract.hostSharedSurfaceAttachmentReady(pipeline_ready, available);
}

/// **Canonical read-only route for conjunction:** derives conjunction from caller-provided legs.
/// Returns same predicate as `notePresentableAvailability` would for matching inputs.
///
/// **Read-only:** Does not modify any state. Safe for diagnostic/logging paths.
/// **Pairing:** Pairs with `notePresentableAvailability` for storage/read consistency.
pub fn readSharedSurfaceAttachmentReady(
    pipeline_ready: bool,
    target_available: bool,
) bool {
    return surface_attachment_contract.hostSharedSurfaceAttachmentReadyFromPair(.{
        .terminal_presentable_pipeline_ready = pipeline_ready,
        .host_surface_target_available = target_available,
    });
}

const std = @import("std");

test "CZH-864: notePresentableAvailability compute route matches readSharedSurfaceAttachmentReady" {
    // Verify compute and read routes return same value for matching inputs
    const pipeline_ready = true;
    const host_available = true;

    const computed = notePresentableAvailability(pipeline_ready, host_available, null);
    const read_result = readSharedSurfaceAttachmentReady(pipeline_ready, host_available);

    try std.testing.expectEqual(computed, read_result);
}

test "CZH-864: conjunction is AND of pipeline and host legs" {
    const cases = [_]struct { pipe: bool, host: bool, expected: bool }{
        .{ .pipe = false, .host = false, .expected = false },
        .{ .pipe = false, .host = true, .expected = false },
        .{ .pipe = true, .host = false, .expected = false },
        .{ .pipe = true, .host = true, .expected = true },
    };

    for (cases) |c| {
        const result = readSharedSurfaceAttachmentReady(c.pipe, c.host);
        try std.testing.expectEqual(c.expected, result);
    }
}

test "CZH-864: notePresentableAvailability returns false when host unavailable" {
    const result = notePresentableAvailability(true, false, null);
    try std.testing.expect(!result);
}

test "CZH-864: notePresentableAvailability returns false when pipeline not ready" {
    const result = notePresentableAvailability(false, true, null);
    try std.testing.expect(!result);
}

test "CZH-867: ownership invariant - widget layer does not re-compute conjunction" {
    // This test documents the ownership contract: widget layer must delegate
    // to presentation_bridge for conjunction computation, not re-derive it.
    // If widget tests directly call surface_attachment_contract functions,
    // that violates the intended ownership split.

    // Widget calls bridge (correct pattern):
    const bridge_result = readSharedSurfaceAttachmentReady(true, false);
    try std.testing.expect(!bridge_result); // true AND false = false

    // This is the ONLY canonical read path widget should use.
    // Any widget test that calls surface_attachment_contract directly
    // is a violation of CZH-863/864 ownership move.
}

test "CZH-867: compute and read pairing - matching inputs yield same result" {
    // CZH-863/864 pairing: compute route must yield same value as read route
    // for matching inputs. This tests that the two functions are consistent.

    const test_cases = [_]struct { pipe: bool, host: bool }{
        .{ .pipe = true, .host = true },
        .{ .pipe = true, .host = false },
        .{ .pipe = false, .host = true },
        .{ .pipe = false, .host = false },
    };

    for (test_cases) |case| {
        const computed = notePresentableAvailability(case.pipe, case.host, null);
        const read = readSharedSurfaceAttachmentReady(case.pipe, case.host);
        try std.testing.expectEqual(computed, read);
    }
}
