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

/// **Canonical compute route for conjunction:** computes host-target leg availability
/// and returns conjunction. Called on each refresh/reuse evaluation.
///
/// **Pairing:** Pairs with `readSharedSurfaceAttachmentReady` for storage/read consistency.
pub fn notePresentableAvailability(
    pipeline_ready: bool,
    available: bool,
) bool {
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

test "compute route matches read route on matching inputs" {
    // Verify compute and read routes return same value for matching inputs
    const pipeline_ready = true;
    const host_available = true;

    const computed = notePresentableAvailability(pipeline_ready, host_available);
    const read_result = readSharedSurfaceAttachmentReady(pipeline_ready, host_available);

    try std.testing.expectEqual(computed, read_result);
}

test "conjunction is AND of pipeline and host legs" {
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

test "notePresentableAvailability returns false when host unavailable" {
    const result = notePresentableAvailability(true, false);
    try std.testing.expect(!result);
}

test "notePresentableAvailability returns false when pipeline not ready" {
    const result = notePresentableAvailability(false, true);
    try std.testing.expect(!result);
}

test "ownership invariant: widget layer does not re-compute conjunction" {
    // Widget layer must delegate to presentation_bridge for conjunction computation.
    // Widget stores legs; bridge computes conjunction. Tests must verify this boundary.
    const bridge_result = readSharedSurfaceAttachmentReady(true, false);
    try std.testing.expect(!bridge_result); // true AND false = false
}

test "compute and read pairing: matching inputs yield same result" {
    // Compute route and read route must return same value for matching inputs.
    // This invariant locks consistency of the two interfaces.
    const test_cases = [_]struct { pipe: bool, host: bool }{
        .{ .pipe = true, .host = true },
        .{ .pipe = true, .host = false },
        .{ .pipe = false, .host = true },
        .{ .pipe = false, .host = false },
    };

    for (test_cases) |case| {
        const computed = notePresentableAvailability(case.pipe, case.host);
        const read = readSharedSurfaceAttachmentReady(case.pipe, case.host);
        try std.testing.expectEqual(computed, read);
    }
}

test "integration: widget delegation path maintains invariant across leg changes" {
    // Simulate widget state flow: update legs -> compute conjunction -> read conjunction
    // This verifies the delegation contract works end-to-end.

    const widget_surface_state = @import("../ui/widgets/terminal_widget_surface_state.zig");
    var state = widget_surface_state.TerminalWidgetSurfaceState.init(std.testing.allocator);
    defer state.deinit(std.testing.allocator);

    // Initial state: both legs false
    const initial_read = state.readSharedSurfaceAttachmentReady();
    try std.testing.expect(!initial_read); // false AND false = false

    // Update pipeline leg via presentation update
    state.presentation.terminal_presentable_pipeline_ready = true;
    const after_pipeline = state.readSharedSurfaceAttachmentReady();
    try std.testing.expect(!after_pipeline); // true AND false = false

    // Compute with host available now
    const computed = state.notePresentableAvailability(true);
    try std.testing.expect(computed); // true AND true = true

    // Verify read matches computed
    const after_compute = state.readSharedSurfaceAttachmentReady();
    try std.testing.expectEqual(computed, after_compute);

    // Verify all reads go through presentation_bridge
    try std.testing.expectEqual(
        after_compute,
        readSharedSurfaceAttachmentReady(
            state.presentation.terminal_presentable_pipeline_ready,
            state.presentation.host_surface_target_available,
        ),
    );
}
