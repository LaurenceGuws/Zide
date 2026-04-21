//! Terminal widget **surface** state: kitty + cached presentation draw metadata.
//!
//! **Vocabulary:** generation pairing vs last draw uses `surface_contract`; pipeline leg
//! (`terminal_presentable_pipeline_ready`) and host target leg (`host_surface_target_available`)
//! represent the two components of shared surface attachment readiness; full attachment uses
//! `presentation_bridge` (delegates to `surface_attachment_contract`) via `notePresentableAvailability` /
//! `readSharedSurfaceAttachmentReady`.
//!
//! **Operability:** operator logs use the same identifiers as the getters
//! (`terminalPresentablePipelineReady`, `hostSurfaceTargetAvailable`, `readSharedSurfaceAttachmentReady`)
//! when surfacing pipeline vs target vs full attachment — no paraphrased synonyms on those legs.
//!
//! **Ownership:** `readSharedSurfaceAttachmentReady` is the only single-bool “full attachment” predicate here;
//! `hostSurfaceTargetAvailable` remains host-target leg only. `TerminalPresentResult` carries
//! the parallel leg + conjunction result shape for host export, distinct from this widget storage.
//!
//! **Conjunction computation:** This module does NOT compute conjunction directly. Widget delegates
//! both compute and read paths to `presentation_bridge` in terminal layer. **Store** legs on
//! `PresentationState` only; conjunction is computed on-demand via bridge for consistency.
//!
//! **Reporting-carrier:** **`readSharedSurfaceAttachmentReady`** is the dominant widget-surface
//! **report** for conjunction when no `PresentationPresentState` snapshot applies (e.g., diagnostics
//! outside the refreshed-present path). The canonical conjunction is `PresentationPresentState.shared_surface_attachment_ready`.
const kitty_mod = @import("terminal_widget_kitty.zig");
const presentation_state_mod = @import("terminal_widget_presentation_cache_state.zig");
const view_state = @import("terminal_widget_view_state.zig");
const terminal_types = @import("../../terminal/model/types.zig");
const std = @import("std");
const surface_contract = @import("../../terminal/surface_contract.zig");
const terminal_publication = @import("../../terminal/core/publication/terminal_publication.zig");
const presentation_bridge = @import("../../terminal/presentation_bridge.zig");

const KittyState = kitty_mod.KittyState;
const PresentationState = presentation_state_mod.PresentationState;
const CursorPos = terminal_publication.CursorPos;
const InvalidationFlags = PresentationState.InvalidationFlags;

pub const TerminalWidgetSurfaceState = struct {
    pub const PresentationUpdateDelta = struct {
        cell_metrics_changed: bool,
        render_scale_changed: bool,
        /// Same predicate as `surface_contract.publicationGenerationDiffersFromLastSurfaceRender`
        /// for `(publication_generation, last_surface_render_generation)`.
        generation_changed: bool,
        /// Same predicate as `surface_contract.clearGenerationDiffersFromLastSurfaceRenderClear`
        /// for `(clear_generation, last_surface_render_clear_generation)`.
        clear_generation_changed: bool,
        /// Terminal presentable **pipeline** ready (same bool as `terminalPresentablePipelineReady()`); not
        /// full `surface_attachment_contract.hostSharedSurfaceAttachmentReady`.
        terminal_presentable_pipeline_ready: bool,
        cursor_changed: bool,
        invalidation_flags: InvalidationFlags,
    };

    kitty: KittyState,
    presentation: PresentationState,

    pub fn init(allocator: anytype) TerminalWidgetSurfaceState {
        return .{
            .kitty = KittyState.init(allocator),
            .presentation = PresentationState.init(),
        };
    }

    pub fn deinit(self: *TerminalWidgetSurfaceState, allocator: anytype) void {
        self.presentation.deinit(allocator);
        self.kitty.deinit(allocator);
    }

    pub fn invalidatePresentationCache(self: *TerminalWidgetSurfaceState, flags: InvalidationFlags) void {
        self.presentation.invalidatePresentationCache(flags);
    }

    pub fn invalidatePresentationGeometry(self: *TerminalWidgetSurfaceState) void {
        self.invalidatePresentationCache(.{ .geometry = true });
    }

    pub fn invalidatePresentationContent(self: *TerminalWidgetSurfaceState) void {
        self.invalidatePresentationCache(.{ .content = true });
    }

    pub fn invalidatePresentationOverlay(self: *TerminalWidgetSurfaceState) void {
        self.invalidatePresentationCache(.{ .overlay = true });
    }

    pub fn lifecycleTransition(
        self: *TerminalWidgetSurfaceState,
        terminal_view: view_state.TerminalViewModel,
    ) view_state.LifecycleTransitionInfo {
        const transition = terminal_view.lifecycleTransition(self.presentation.last_alt_active);
        self.presentation.last_alt_active = transition.current_alt_active;
        return transition;
    }

    pub fn prepareKittyForDraw(
        self: *TerminalWidgetSurfaceState,
        allocator: anytype,
        shell: anytype,
        terminal_view: view_state.TerminalViewModel,
    ) bool {
        return self.kitty.prepareForDraw(
            allocator,
            shell,
            terminal_view.rows,
            terminal_view.cols,
            terminal_view.kitty_images,
            terminal_view.kitty_placements,
        );
    }

    pub fn finishDraw(
        self: *TerminalWidgetSurfaceState,
        allocator: anytype,
        generation: u64,
        has_kitty: bool,
    ) void {
        self.kitty.finishDraw(allocator, generation, has_kitty);
    }

    pub fn lastRenderGeneration(self: *const TerminalWidgetSurfaceState) u64 {
        return self.presentation.last_render_generation;
    }

    pub fn lastRenderClearGeneration(self: *const TerminalWidgetSurfaceState) u64 {
        return self.presentation.last_render_clear_generation;
    }

    /// **Leg read:** pipeline only — not conjunction; pairs with `hostSurfaceTargetAvailable`
    /// for `readSharedSurfaceAttachmentReady`.
    pub fn terminalPresentablePipelineReady(self: *const TerminalWidgetSurfaceState) bool {
        return self.presentation.terminal_presentable_pipeline_ready;
    }

    /// **Leg read:** host drawable target only — not conjunction; pairs with
    /// `terminalPresentablePipelineReady` for `readSharedSurfaceAttachmentReady`.
    ///
    /// Host **drawable target** leg for `surface_attachment_contract` (same field as
    /// `SharedSurfaceAttachmentPipelinePair.host_surface_target_available`).
    pub fn hostSurfaceTargetAvailable(self: *const TerminalWidgetSurfaceState) bool {
        return self.presentation.host_surface_target_available;
    }

    /// Presentation invalidation delta vs last recorded surface draw; publication/clear
    /// generation fields use `surface_contract.publicationClearPairMismatchesFromLastSurfaceRender`.
    pub fn presentationUpdateDelta(
        self: *const TerminalWidgetSurfaceState,
        terminal_view: view_state.TerminalViewModel,
        surface_geometry: anytype,
        draw_cursor: bool,
        cursor: CursorPos,
        cursor_style: terminal_types.CursorStyle,
    ) PresentationUpdateDelta {
        const publication_clear_pair_mismatches = surface_contract.publicationClearPairMismatchesFromLastSurfaceRender(
            terminal_view.generation,
            terminal_view.clear_generation,
            self.presentation.last_render_generation,
            self.presentation.last_render_clear_generation,
        );
        return .{
            .cell_metrics_changed = surface_geometry.cell_w_i != self.presentation.last_cell_w_i or
                surface_geometry.cell_h_i != self.presentation.last_cell_h_i,
            .render_scale_changed = surface_geometry.render_scale != self.presentation.last_render_scale,
            .generation_changed = publication_clear_pair_mismatches.publication_mismatch,
            .clear_generation_changed = publication_clear_pair_mismatches.clear_mismatch,
            .terminal_presentable_pipeline_ready = self.terminalPresentablePipelineReady(),
            .cursor_changed = self.cursorPresentationChanged(draw_cursor, cursor, cursor_style),
            .invalidation_flags = self.presentation.invalidation_flags,
        };
    }

    pub fn cursorPresentationChanged(
        self: *const TerminalWidgetSurfaceState,
        draw_cursor: bool,
        cursor: CursorPos,
        cursor_style: terminal_types.CursorStyle,
    ) bool {
        if (self.presentation.last_cursor_visible != draw_cursor) return true;
        if (!draw_cursor) return false;
        return self.presentation.last_cursor_row != @as(u16, @intCast(cursor.row)) or
            self.presentation.last_cursor_col != @as(u16, @intCast(cursor.col)) or
            self.presentation.last_cursor_shape != @as(u8, @intFromEnum(cursor_style.shape));
    }

    pub fn overlayPresentationChanged(
        self: *const TerminalWidgetSurfaceState,
        hover_link_id: u32,
        composing_active: bool,
        composing_hash: u64,
    ) bool {
        if (self.presentation.last_hover_link_id != hover_link_id) return true;
        if (self.presentation.last_composing_active != composing_active) return true;
        if (self.presentation.last_composing_hash != composing_hash) return true;
        return false;
    }

    pub fn notePresentationUpdated(
        self: *TerminalWidgetSurfaceState,
        terminal_view: view_state.TerminalViewModel,
        surface_geometry: anytype,
        draw_cursor: bool,
        cursor: CursorPos,
        cursor_style: terminal_types.CursorStyle,
        hover_link_id: u32,
        composing_active: bool,
        composing_hash: u64,
    ) void {
        self.presentation.terminal_presentable_pipeline_ready = true;
        self.presentation.host_surface_target_available = true;
        self.presentation.clearInvalidationFlags();
        self.presentation.last_render_generation = terminal_view.generation;
        self.presentation.last_render_clear_generation = terminal_view.clear_generation;
        self.presentation.last_cell_w_i = surface_geometry.cell_w_i;
        self.presentation.last_cell_h_i = surface_geometry.cell_h_i;
        self.presentation.last_render_scale = surface_geometry.render_scale;
        self.presentation.last_cursor_visible = draw_cursor;
        if (draw_cursor) {
            self.presentation.last_cursor_row = @intCast(cursor.row);
            self.presentation.last_cursor_col = @intCast(cursor.col);
            self.presentation.last_cursor_shape = @intFromEnum(cursor_style.shape);
        }
        self.presentation.last_hover_link_id = hover_link_id;
        self.presentation.last_composing_active = composing_active;
        self.presentation.last_composing_hash = composing_hash;
    }

    /// **Canonical compute+store route for conjunction (delegates to terminal presentation bridge):**
    /// writes the host-target leg and returns the conjunction. Invalidates presentation cache on
    /// unavailability. Must be called before `readSharedSurfaceAttachmentReady` or operator-log
    /// recording uses the conjunction. **Only** call this to compute leg+conjunction;
    /// do not re-derive conjunction outside this path.
    /// **Initialization contract:** reads the pipeline leg (set by `notePresentationUpdated` when
    /// presentation occurs) and writes the host-target leg; both legs have sensible defaults (false)
    /// on first initialization. **Pairing:** maintains storage/read consistency with `readSharedSurfaceAttachmentReady`.
    /// **Delegation:** Terminal-owned bridge (`presentation_bridge`) computes the conjunction;
    /// widget storage delegates and does not re-derive.
    pub fn notePresentableAvailability(self: *TerminalWidgetSurfaceState, available: bool) bool {
        if (!available) self.presentation.invalidatePresentationCache(.{ .availability = true });
        self.presentation.host_surface_target_available = available;
        return presentation_bridge.notePresentableAvailability(
            self.presentation.terminal_presentable_pipeline_ready,
            available,
        );
    }

    /// **Canonical read-only route for conjunction (delegates to terminal presentation bridge):**
    /// derives conjunction from stored legs. Returns same predicate as `notePresentableAvailability`’s
    /// return. Dominant widget-surface **report** when `PresentationPresentState` is not in scope;
    /// not the canonical conjunction (which is `PresentationPresentState.shared_surface_attachment_ready`).
    /// **Pairing:** maintains storage/read consistency with `notePresentableAvailability`.
    /// **Delegation:** Terminal-owned bridge (`presentation_bridge`) computes the conjunction;
    /// widget storage delegates and does not re-derive.
    pub fn readSharedSurfaceAttachmentReady(self: *const TerminalWidgetSurfaceState) bool {
        return presentation_bridge.readSharedSurfaceAttachmentReady(
            self.presentation.terminal_presentable_pipeline_ready,
            self.presentation.host_surface_target_available,
        );
    }

    pub fn ensurePartialDrawPlan(
        self: *TerminalWidgetSurfaceState,
        allocator: anytype,
        rows: usize,
    ) ?PresentationState.PresentationPartialDrawPlan {
        return self.presentation.ensurePartialDrawPlan(allocator, rows);
    }
};

test "cursorPresentationChanged tracks visible/position/shape transitions" {
    var state = TerminalWidgetSurfaceState.init(std.testing.allocator);
    defer state.deinit(std.testing.allocator);

    const block_style = terminal_types.CursorStyle{ .shape = .block, .blink = true };
    const bar_style = terminal_types.CursorStyle{ .shape = .bar, .blink = true };
    const cursor_a = CursorPos{ .row = 2, .col = 4 };
    const cursor_b = CursorPos{ .row = 2, .col = 5 };

    // No cached cursor yet, first visible draw must invalidate.
    try std.testing.expect(state.cursorPresentationChanged(true, cursor_a, block_style));

    state.presentation.last_cursor_visible = true;
    state.presentation.last_cursor_row = @intCast(cursor_a.row);
    state.presentation.last_cursor_col = @intCast(cursor_a.col);
    state.presentation.last_cursor_shape = @intFromEnum(block_style.shape);
    try std.testing.expect(!state.cursorPresentationChanged(true, cursor_a, block_style));
    try std.testing.expect(state.cursorPresentationChanged(true, cursor_b, block_style));
    try std.testing.expect(state.cursorPresentationChanged(true, cursor_a, bar_style));

    // Visibility transitions must invalidate too.
    state.presentation.last_cursor_visible = false;
    try std.testing.expect(state.cursorPresentationChanged(true, cursor_a, block_style));
}

test "overlayPresentationChanged tracks hover and composing signature" {
    var state = TerminalWidgetSurfaceState.init(std.testing.allocator);
    defer state.deinit(std.testing.allocator);

    state.presentation.last_hover_link_id = 17;
    state.presentation.last_composing_active = true;
    state.presentation.last_composing_hash = 0xABCD;

    try std.testing.expect(!state.overlayPresentationChanged(17, true, 0xABCD));
    try std.testing.expect(state.overlayPresentationChanged(18, true, 0xABCD));
    try std.testing.expect(state.overlayPresentationChanged(17, false, 0xABCD));
    try std.testing.expect(state.overlayPresentationChanged(17, true, 0x1234));
}

test "CZH-S15: notePresentableAvailability matches readSharedSurfaceAttachmentReady" {
    var state = TerminalWidgetSurfaceState.init(std.testing.allocator);
    defer state.deinit(std.testing.allocator);

    state.presentation.terminal_presentable_pipeline_ready = true;
    try std.testing.expect(state.notePresentableAvailability(true));
    try std.testing.expect(state.readSharedSurfaceAttachmentReady());

    try std.testing.expect(!state.notePresentableAvailability(false));
    try std.testing.expect(!state.readSharedSurfaceAttachmentReady());
}

test "CZH-777: widget surface exposes leg getters and conjunction reporting bridge" {
    comptime {
        const T = TerminalWidgetSurfaceState;
        if (!@hasDecl(T, "readSharedSurfaceAttachmentReady")) @compileError("CZH-777: bridge missing");
        if (!@hasDecl(T, "hostSurfaceTargetAvailable")) @compileError("CZH-777: host leg missing");
        if (!@hasDecl(T, "terminalPresentablePipelineReady")) @compileError("CZH-777: pipeline leg missing");
    }
}

test "CZH-767: conjunction compute return matches stored legs and report read" {
    var state = TerminalWidgetSurfaceState.init(std.testing.allocator);
    defer state.deinit(std.testing.allocator);

    state.presentation.terminal_presentable_pipeline_ready = true;
    const computed = state.notePresentableAvailability(true);
    try std.testing.expectEqual(
        computed,
        presentation_bridge.readSharedSurfaceAttachmentReady(
            state.presentation.terminal_presentable_pipeline_ready,
            state.presentation.host_surface_target_available,
        ),
    );
    try std.testing.expectEqual(computed, state.readSharedSurfaceAttachmentReady());
}

test "CZH-S17: readSharedSurfaceAttachmentReady matches FromPair on presentation legs" {
    var state = TerminalWidgetSurfaceState.init(std.testing.allocator);
    defer state.deinit(std.testing.allocator);

    state.presentation.terminal_presentable_pipeline_ready = true;
    state.presentation.host_surface_target_available = false;
    try std.testing.expectEqual(
        state.readSharedSurfaceAttachmentReady(),
        presentation_bridge.readSharedSurfaceAttachmentReady(
            state.presentation.terminal_presentable_pipeline_ready,
            state.presentation.host_surface_target_available,
        ),
    );
}

test "CZH-S18: terminalPresentablePipelineReady mirrors terminal_presentable_pipeline_ready field" {
    var state = TerminalWidgetSurfaceState.init(std.testing.allocator);
    defer state.deinit(std.testing.allocator);

    state.presentation.terminal_presentable_pipeline_ready = false;
    try std.testing.expect(!state.terminalPresentablePipelineReady());
    state.presentation.terminal_presentable_pipeline_ready = true;
    try std.testing.expect(state.terminalPresentablePipelineReady());
}

test "CZH-S19: readSharedSurfaceAttachmentReady matches pipeline and target getters" {
    const cases = [_]struct { pipe: bool, tgt: bool }{
        .{ .pipe = false, .tgt = false },
        .{ .pipe = false, .tgt = true },
        .{ .pipe = true, .tgt = false },
        .{ .pipe = true, .tgt = true },
    };

    var state = TerminalWidgetSurfaceState.init(std.testing.allocator);
    defer state.deinit(std.testing.allocator);

    for (cases) |c| {
        state.presentation.terminal_presentable_pipeline_ready = c.pipe;
        state.presentation.host_surface_target_available = c.tgt;
        try std.testing.expectEqual(
            state.readSharedSurfaceAttachmentReady(),
            state.terminalPresentablePipelineReady() and state.hostSurfaceTargetAvailable(),
        );
    }
}

test "CZH-S16: pipeline leg ready without host target splits pipeline getter vs attachment" {
    var state = TerminalWidgetSurfaceState.init(std.testing.allocator);
    defer state.deinit(std.testing.allocator);

    state.presentation.terminal_presentable_pipeline_ready = true;
    state.presentation.host_surface_target_available = false;
    try std.testing.expect(state.terminalPresentablePipelineReady());
    try std.testing.expect(!state.readSharedSurfaceAttachmentReady());
}

test "CZH-S20: presentation delta pipeline field matches stored PresentationState leg naming" {
    comptime {
        const delta_fields = @typeInfo(TerminalWidgetSurfaceState.PresentationUpdateDelta).@"struct".fields;
        const pres_fields = @typeInfo(PresentationState).@"struct".fields;
        var delta_pipe: usize = 0;
        var delta_host: usize = 0;
        var pres_pipe: usize = 0;
        var pres_host: usize = 0;
        for (delta_fields) |f| {
            if (std.mem.eql(u8, f.name, "terminal_presentable_pipeline_ready")) delta_pipe += 1;
            if (std.mem.eql(u8, f.name, "host_surface_target_available")) delta_host += 1;
        }
        for (pres_fields) |f| {
            if (std.mem.eql(u8, f.name, "terminal_presentable_pipeline_ready")) pres_pipe += 1;
            if (std.mem.eql(u8, f.name, "host_surface_target_available")) pres_host += 1;
        }
        std.debug.assert(delta_pipe == 1 and pres_pipe == 1 and pres_host == 1);
        std.debug.assert(delta_host == 0);
    }
}

test "CZH-S14: composite pair mismatch matches per-leg inequality (widget seam shape)" {
    const mm = surface_contract.publicationClearPairMismatchesFromLastSurfaceRender(10, 20, 10, 30);
    try std.testing.expect(!mm.publication_mismatch);
    try std.testing.expect(mm.clear_mismatch);
    try std.testing.expectEqual(mm.publication_mismatch, 10 != 10);
    try std.testing.expectEqual(mm.clear_mismatch, 20 != 30);

    const mm2 = surface_contract.publicationClearPairMismatchesFromLastSurfaceRender(1, 2, 0, 2);
    try std.testing.expect(mm2.publication_mismatch);
    try std.testing.expect(!mm2.clear_mismatch);
    try std.testing.expectEqual(mm2.publication_mismatch, 1 != 0);
    try std.testing.expectEqual(mm2.clear_mismatch, 2 != 2);
}

test "CZH-787: cached PresentationState omits conjunction field present on TerminalPresentResult" {
    const presentable_contract = @import("../renderer/presentable_contract.zig");
    comptime {
        for (@typeInfo(PresentationState).@"struct".fields) |f| {
            if (std.mem.eql(u8, f.name, "shared_surface_attachment_ready")) {
                @compileError("CZH-787: conjunction is not stored on PresentationState");
            }
        }
        var conj: usize = 0;
        for (@typeInfo(presentable_contract.TerminalPresentResult).@"struct".fields) |f| {
            if (std.mem.eql(u8, f.name, "shared_surface_attachment_ready")) conj += 1;
        }
        std.debug.assert(conj == 1);
    }
}

test "CZH-S31: initialization contract - first call without prior pipeline leg setup" {
    var state = TerminalWidgetSurfaceState.init(std.testing.allocator);
    defer state.deinit(std.testing.allocator);

    // On first initialization, both legs default to false. This test verifies that
    // notePresentableAvailability and readSharedSurfaceAttachmentReady work correctly
    // without requiring prior notePresentationUpdated call.
    //
    // Pipeline leg: false (default, not yet updated by presentation)
    // Host target leg: will be set by notePresentableAvailability
    //
    // Expected: conjunction is false (false AND any_value = false)
    const first_call_result = state.notePresentableAvailability(true);
    try std.testing.expect(!first_call_result); // false (pipeline) AND true (host target) = false

    const read_result = state.readSharedSurfaceAttachmentReady();
    try std.testing.expect(!read_result); // should match compute result

    // Now simulate notePresentationUpdated being called (pipeline ready)
    state.presentation.terminal_presentable_pipeline_ready = true;
    const second_call_result = state.notePresentableAvailability(true);
    try std.testing.expect(second_call_result); // true (pipeline) AND true (host target) = true

    const second_read_result = state.readSharedSurfaceAttachmentReady();
    try std.testing.expect(second_read_result); // should match compute result
}

test "CZH-S31: leg defaults enable first call without pre-initialization" {
    var state = TerminalWidgetSurfaceState.init(std.testing.allocator);
    defer state.deinit(std.testing.allocator);

    // Verify that both legs have sensible defaults (false) that work correctly
    // on first refresh path where notePresentableAvailability is called before
    // notePresentationUpdated.
    try std.testing.expect(state.presentation.terminal_presentable_pipeline_ready == false);
    try std.testing.expect(state.presentation.host_surface_target_available == false);

    // First call to notePresentableAvailability should work without assertion
    // (removed spurious assertLegsInitialized check)
    const result = state.notePresentableAvailability(false);
    try std.testing.expect(!result); // false AND false = false
}
