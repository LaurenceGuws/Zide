//! Terminal **surface contract** seam: logical published vs host-acknowledged
//! generation pairing for shared-GPU presentation (`TERMINAL_SURFACE_CONTRACT.md`).
//! VT core FFI continues to own the extern `RedrawState` ABI; this module names
//! the frozen contract center and centralizes how that bundle is filled — one
//! truth source for `needs_redraw` derivation.
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
