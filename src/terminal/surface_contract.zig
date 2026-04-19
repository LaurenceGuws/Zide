//! Terminal **surface contract** seam: logical published vs host-acknowledged
//! generation pairing for shared-GPU presentation (`TERMINAL_SURFACE_CONTRACT.md`).
//! VT core FFI continues to own the extern `RedrawState` ABI; this module is the
//! naming center for generation pairing (`TERMINAL_SURFACE_CONTRACT.md`).
//!
//! **Layering (no duplicate policy paths):**
//! - **Primitive predicates:** `needsRedrawFromPair` (pair inequality); widget
//!   legs `publicationGenerationDiffersFromLastSurfaceRender` and
//!   `clearGenerationDiffersFromLastSurfaceRenderClear` (same core).
//! - **Widget composite:** `publicationClearPairMismatchesFromLastSurfaceRender` /
//!   `publicationClearPairMatchesLastSurfaceRender` — sole composite shape for
//!   terminal widget publication/clear vs last surface draw (`presentationUpdateDelta`,
//!   present-plan reuse).
//! - **FFI exports:** `ffiRedrawStateFill`, `ffiNeedsRedrawU8`,
//!   `ffiPresentAckGenerationAdmissible` — sole `core_api` seam for redraw bundle,
//!   needs-redraw byte, and present-ack gate (`core_api`).
//! - **Bundle fill:** `fillRedrawState` implements `RedrawState`; `ffiRedrawStateFill`
//!   delegates here (`CZH-S13`, `CZH-S14`).
//! - **Host attachment (pipeline ∧ target):** `surface_attachment_contract` (`CZH-S15`).
//!
//! **`CZH-S16`:** `presentationUpdateDelta.presentable_ready` in the widget is the
//! attachment **pipeline leg** only; composite publication/clear fields remain
//! generation-owned via `publicationClearPair*` above.
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
/// VT FFI uses `ffiPresentAckGenerationAdmissible` as the named export gate.
pub fn presentAckGenerationAdmissible(
    generation: u64,
    published_generation: u64,
    last_acknowledged_generation: u64,
) bool {
    return generation <= published_generation and generation >= last_acknowledged_generation;
}

/// VT core FFI `present_ack`: admissibility gate before updating last
/// acknowledged generation (`core_api.presentAck`).
pub fn ffiPresentAckGenerationAdmissible(
    generation: u64,
    published_generation: u64,
    last_acknowledged_generation: u64,
) bool {
    return presentAckGenerationAdmissible(generation, published_generation, last_acknowledged_generation);
}

/// Widget draw: one leg of publication/clear vs last surface draw; same core as
/// `needsRedrawFromPair`. Used by `publicationClearPairMismatchesFromLastSurfaceRender`
/// (`TERMINAL_SURFACE_CONTRACT.md`, `CZH-S12`).
pub fn publicationGenerationDiffersFromLastSurfaceRender(
    publication_generation: u64,
    last_surface_render_generation: u64,
) bool {
    return needsRedrawFromPair(publication_generation, last_surface_render_generation);
}

/// Widget draw: clear-generation leg of publication/clear vs last surface draw;
/// same core as `needsRedrawFromPair`. Used by `publicationClearPairMismatchesFromLastSurfaceRender`
/// (`TERMINAL_SURFACE_CONTRACT.md`, `CZH-S12`).
pub fn clearGenerationDiffersFromLastSurfaceRenderClear(
    publication_clear_generation: u64,
    last_surface_render_clear_generation: u64,
) bool {
    return needsRedrawFromPair(publication_clear_generation, last_surface_render_clear_generation);
}

/// Pairwise mismatch flags for publication generation and clear generation vs the
/// last generations recorded for the terminal surface draw (`CZH-S12`).
pub const PublicationClearPairMismatches = struct {
    publication_mismatch: bool,
    clear_mismatch: bool,
};

/// Widget draw: publication and clear generation together vs last surface-render
/// pair. Decomposes to `publicationGenerationDiffersFromLastSurfaceRender` and
/// `clearGenerationDiffersFromLastSurfaceRenderClear` with no extra policy.
pub fn publicationClearPairMismatchesFromLastSurfaceRender(
    publication_generation: u64,
    clear_generation: u64,
    last_surface_render_generation: u64,
    last_surface_render_clear_generation: u64,
) PublicationClearPairMismatches {
    return .{
        .publication_mismatch = publicationGenerationDiffersFromLastSurfaceRender(
            publication_generation,
            last_surface_render_generation,
        ),
        .clear_mismatch = clearGenerationDiffersFromLastSurfaceRenderClear(
            clear_generation,
            last_surface_render_clear_generation,
        ),
    };
}

/// Present-plan reuse: publication and clear generations both match what the
/// surface last recorded for draw (conjunction of the two non-mismatch cases).
pub fn publicationClearPairMatchesLastSurfaceRender(
    publication_generation: u64,
    clear_generation: u64,
    last_surface_render_generation: u64,
    last_surface_render_clear_generation: u64,
) bool {
    const m = publicationClearPairMismatchesFromLastSurfaceRender(
        publication_generation,
        clear_generation,
        last_surface_render_generation,
        last_surface_render_clear_generation,
    );
    return !m.publication_mismatch and !m.clear_mismatch;
}

/// Fills the VT FFI `RedrawState` from publication truth + last acknowledged generation.
/// `ffiRedrawStateFill` delegates here; both describe the same bundle (`CZH-S13`).
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

/// VT core FFI `redraw_state`: fill `RedrawState` from publication vs last
/// `present_ack` generation (`core_api.redrawState`).
pub fn ffiRedrawStateFill(
    published_generation: u64,
    last_acknowledged_generation: u64,
    out_state: *shared.RedrawState,
) void {
    fillRedrawState(published_generation, last_acknowledged_generation, out_state);
}

/// VT core FFI `needs_redraw` byte: non-zero iff publication differs from last
/// acknowledged (`core_api.needsRedraw`).
pub fn ffiNeedsRedrawU8(published_generation: u64, last_acknowledged_generation: u64) u8 {
    return @intFromBool(needsRedrawFromPair(published_generation, last_acknowledged_generation));
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

test "CZH-S12: publicationClearPairMismatchesFromLastSurfaceRender matches decomposed primitives" {
    const cases = [_]struct { pg: u64, cg: u64, lr: u64, lrc: u64 }{
        .{ .pg = 1, .cg = 2, .lr = 1, .lrc = 2 },
        .{ .pg = 0, .cg = 0, .lr = 1, .lrc = 0 },
        .{ .pg = 1 << 40, .cg = 0, .lr = 0, .lrc = 1 << 39 },
    };
    for (cases) |c| {
        const m = publicationClearPairMismatchesFromLastSurfaceRender(c.pg, c.cg, c.lr, c.lrc);
        try std.testing.expectEqual(
            publicationGenerationDiffersFromLastSurfaceRender(c.pg, c.lr),
            m.publication_mismatch,
        );
        try std.testing.expectEqual(
            clearGenerationDiffersFromLastSurfaceRenderClear(c.cg, c.lrc),
            m.clear_mismatch,
        );
    }
}

test "publicationClearPairMatchesLastSurfaceRender is conjunction of primitive non-mismatch" {
    try std.testing.expect(publicationClearPairMatchesLastSurfaceRender(5, 5, 5, 5));
    try std.testing.expect(!publicationClearPairMatchesLastSurfaceRender(5, 5, 5, 6));
    try std.testing.expect(!publicationClearPairMatchesLastSurfaceRender(5, 6, 5, 5));
}

test "CZH-S14: composite pair mismatch fields mirror per-coordinate inequality" {
    const m = publicationClearPairMismatchesFromLastSurfaceRender(1, 2, 3, 4);
    try std.testing.expectEqual(1 != 3, m.publication_mismatch);
    try std.testing.expectEqual(2 != 4, m.clear_mismatch);
}

test "CZH-S16: composite mismatch legs match planUpdate surface_contract primitives" {
    const pg: u64 = 9;
    const cg: u64 = 3;
    const lr: u64 = 8;
    const lrc: u64 = 3;
    const mm = publicationClearPairMismatchesFromLastSurfaceRender(pg, cg, lr, lrc);
    try std.testing.expectEqual(
        publicationGenerationDiffersFromLastSurfaceRender(pg, lr),
        mm.publication_mismatch,
    );
    try std.testing.expectEqual(
        clearGenerationDiffersFromLastSurfaceRenderClear(cg, lrc),
        mm.clear_mismatch,
    );
}

test "CZH-S13: ffiRedrawStateFill matches fillRedrawState" {
    var via_ffi: shared.RedrawState = undefined;
    var direct: shared.RedrawState = undefined;
    ffiRedrawStateFill(10, 7, &via_ffi);
    fillRedrawState(10, 7, &direct);
    try std.testing.expectEqual(direct.abi_version, via_ffi.abi_version);
    try std.testing.expectEqual(direct.struct_size, via_ffi.struct_size);
    try std.testing.expectEqual(direct.published_generation, via_ffi.published_generation);
    try std.testing.expectEqual(direct.acknowledged_generation, via_ffi.acknowledged_generation);
    try std.testing.expectEqual(direct.needs_redraw, via_ffi.needs_redraw);
}

test "CZH-S13: ffiNeedsRedrawU8 matches needsRedrawFromPair" {
    const pairs = [_]struct { a: u64, b: u64 }{
        .{ .a = 0, .b = 1 },
        .{ .a = 9, .b = 9 },
    };
    for (pairs) |p| {
        try std.testing.expectEqual(
            @as(u8, @intFromBool(needsRedrawFromPair(p.a, p.b))),
            ffiNeedsRedrawU8(p.a, p.b),
        );
    }
}

test "CZH-S13: ffiPresentAckGenerationAdmissible matches presentAckGenerationAdmissible" {
    try std.testing.expectEqual(
        presentAckGenerationAdmissible(5, 10, 3),
        ffiPresentAckGenerationAdmissible(5, 10, 3),
    );
    try std.testing.expectEqual(
        presentAckGenerationAdmissible(10, 10, 10),
        ffiPresentAckGenerationAdmissible(10, 10, 10),
    );
    try std.testing.expectEqual(
        presentAckGenerationAdmissible(11, 10, 3),
        ffiPresentAckGenerationAdmissible(11, 10, 3),
    );
}
