//! Terminal **surface contract** seam: logical published vs host-acknowledged
//! generation pairing for shared-GPU presentation (`TERMINAL_SURFACE_CONTRACT.md`).
//! VT core FFI continues to own the extern `RedrawState` ABI; this module names
//! the frozen contract center and centralizes how that bundle is filled — one
//! truth source for `needs_redraw` derivation.
//!
//! Widget surface state: `TerminalWidgetSurfaceState.presentationUpdateDelta` uses
//! `publicationGenerationDiffersFromLastSurfaceRender` and
//! `clearGenerationDiffersFromLastSurfaceRenderClear` for its publication and
//! clear-generation mismatch limbs (`CZH-S11`).
const std = @import("std");
const shared = @import("ffi/shared.zig");

/// Logical pairing only (no ABI padding); useful for docs/tests.
pub const LogicalSurfaceFrame = struct {
    published_generation: u64,
    acknowledged_generation: u64,

    pub fn needsRedraw(self: LogicalSurfaceFrame) bool {
        return needsRedrawFromPair(self.published_generation, self.acknowledged_generation);
    }
};

/// `needs_redraw` in `RedrawState`: publication generation differs from last `presentAck`.
pub fn needsRedrawFromPair(published_generation: u64, acknowledged_generation: u64) bool {
    return published_generation != acknowledged_generation;
}

/// Whether `generation` is admissible for host `present_ack`: must not exceed
/// current publication generation or regress before `last_acknowledged_generation`
/// (`TERMINAL_SURFACE_CONTRACT.md` — presentation completion vs Zide truth).
pub fn presentAckGenerationAdmissible(
    generation: u64,
    published_generation: u64,
    last_acknowledged_generation: u64,
) bool {
    return generation <= published_generation and generation >= last_acknowledged_generation;
}

/// Widget draw/presentation: publication generation differs from the last generation
/// the shared presentable recorded for the terminal surface draw (`terminal_widget*`
/// presentation runtime). Same predicate core as `needsRedrawFromPair` — explicit
/// naming for the draw/presentation consumer (`TERMINAL_SURFACE_CONTRACT.md`).
/// Also drives `PresentationUpdateDelta.generation_changed` in
/// `terminal_widget_surface_state.zig` (`CZH-S11`).
pub fn publicationGenerationDiffersFromLastSurfaceRender(
    publication_generation: u64,
    last_surface_render_generation: u64,
) bool {
    return needsRedrawFromPair(publication_generation, last_surface_render_generation);
}

/// Widget draw/presentation: publication **clear** generation differs from the
/// last clear generation the shared presentable recorded for the terminal surface
/// draw. Same predicate core as `needsRedrawFromPair`; pairs with
/// `publicationGenerationDiffersFromLastSurfaceRender` for present-plan reuse
/// eligibility (`TERMINAL_SURFACE_CONTRACT.md`).
/// Also drives `PresentationUpdateDelta.clear_generation_changed` in
/// `terminal_widget_surface_state.zig` (`CZH-S11`).
pub fn clearGenerationDiffersFromLastSurfaceRenderClear(
    publication_clear_generation: u64,
    last_surface_render_clear_generation: u64,
) bool {
    return needsRedrawFromPair(publication_clear_generation, last_surface_render_clear_generation);
}

/// Fills the VT FFI `RedrawState` from publication truth + last acknowledged generation.
pub fn fillRedrawState(
    published_generation: u64,
    last_acknowledged_generation: u64,
    out_state: *shared.RedrawState,
) void {
    out_state.* = .{
        .abi_version = shared.redraw_state_abi_version,
        .struct_size = @sizeOf(shared.RedrawState),
        .published_generation = published_generation,
        .acknowledged_generation = last_acknowledged_generation,
        .needs_redraw = @intFromBool(needsRedrawFromPair(published_generation, last_acknowledged_generation)),
    };
}

test "fillRedrawState sets logical triple" {
    var out: shared.RedrawState = undefined;
    fillRedrawState(10, 7, &out);
    try std.testing.expectEqual(shared.redraw_state_abi_version, out.abi_version);
    try std.testing.expectEqual(@as(u32, @sizeOf(shared.RedrawState)), out.struct_size);
    try std.testing.expectEqual(@as(u64, 10), out.published_generation);
    try std.testing.expectEqual(@as(u64, 7), out.acknowledged_generation);
    try std.testing.expectEqual(@as(u8, 1), out.needs_redraw);

    fillRedrawState(5, 5, &out);
    try std.testing.expectEqual(@as(u8, 0), out.needs_redraw);

    const logical = LogicalSurfaceFrame{ .published_generation = 2, .acknowledged_generation = 1 };
    try std.testing.expect(logical.needsRedraw());
}

test "presentAckGenerationAdmissible matches monotonic window" {
    try std.testing.expect(presentAckGenerationAdmissible(5, 10, 3));
    try std.testing.expect(presentAckGenerationAdmissible(10, 10, 10));
    try std.testing.expect(!presentAckGenerationAdmissible(11, 10, 3));
    try std.testing.expect(!presentAckGenerationAdmissible(2, 10, 5));
}

test "publicationGenerationDiffersFromLastSurfaceRender aliases needsRedrawFromPair" {
    const pairs = [_]struct { a: u64, b: u64 }{
        .{ .a = 0, .b = 1 },
        .{ .a = 9, .b = 9 },
        .{ .a = 1 << 40, .b = 0 },
    };
    for (pairs) |p| {
        try std.testing.expectEqual(
            needsRedrawFromPair(p.a, p.b),
            publicationGenerationDiffersFromLastSurfaceRender(p.a, p.b),
        );
    }
}

test "clearGenerationDiffersFromLastSurfaceRenderClear aliases needsRedrawFromPair" {
    const pairs = [_]struct { a: u64, b: u64 }{
        .{ .a = 0, .b = 1 },
        .{ .a = 9, .b = 9 },
        .{ .a = 1 << 40, .b = 0 },
    };
    for (pairs) |p| {
        try std.testing.expectEqual(
            needsRedrawFromPair(p.a, p.b),
            clearGenerationDiffersFromLastSurfaceRenderClear(p.a, p.b),
        );
    }
}

test "CZH-S11: presentationUpdateDelta generation limbs use publication and clear mismatch helpers" {
    const pub_pairs = [_]struct { view: u64, last: u64 }{
        .{ .view = 1, .last = 2 },
        .{ .view = 5, .last = 5 },
    };
    for (pub_pairs) |p| {
        try std.testing.expectEqual(
            p.view != p.last,
            publicationGenerationDiffersFromLastSurfaceRender(p.view, p.last),
        );
    }
    const clear_pairs = [_]struct { view: u64, last: u64 }{
        .{ .view = 0, .last = 1 },
        .{ .view = 7, .last = 7 },
    };
    for (clear_pairs) |p| {
        try std.testing.expectEqual(
            p.view != p.last,
            clearGenerationDiffersFromLastSurfaceRenderClear(p.view, p.last),
        );
    }
}
