const kitty_mod = @import("terminal_widget_kitty.zig");
const presentation_state_mod = @import("terminal_widget_presentation_state.zig");
const view_state = @import("terminal_widget_view_state.zig");
const terminal_types = @import("../../terminal/model/types.zig");
const std = @import("std");
const surface_attachment_contract = @import("../../terminal/surface_attachment_contract.zig");
const surface_contract = @import("../../terminal/surface_contract.zig");
const terminal_publication = @import("../../terminal/core/publication/terminal_publication.zig");

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
        /// Terminal presentable **pipeline** ready (same bool as `presentableReady()`); not
        /// full `surface_attachment_contract.hostSharedSurfaceAttachmentReady`. Field
        /// renamed to `terminal_presentable_pipeline_ready` in `CZH-715`.
        presentable_ready: bool,
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

    pub fn presentableReady(self: *const TerminalWidgetSurfaceState) bool {
        return self.presentation.terminal_presentable_ready;
    }

    pub fn targetAvailable(self: *const TerminalWidgetSurfaceState) bool {
        return self.presentation.target_available;
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
        const gen_clear_mismatch = surface_contract.publicationClearPairMismatchesFromLastSurfaceRender(
            terminal_view.generation,
            terminal_view.clear_generation,
            self.presentation.last_render_generation,
            self.presentation.last_render_clear_generation,
        );
        return .{
            .cell_metrics_changed = surface_geometry.cell_w_i != self.presentation.last_cell_w_i or
                surface_geometry.cell_h_i != self.presentation.last_cell_h_i,
            .render_scale_changed = surface_geometry.render_scale != self.presentation.last_render_scale,
            .generation_changed = gen_clear_mismatch.publication_mismatch,
            .clear_generation_changed = gen_clear_mismatch.clear_mismatch,
            .presentable_ready = self.presentableReady(),
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
        self.presentation.terminal_presentable_ready = true;
        self.presentation.target_available = true;
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

    pub fn notePresentableAvailability(self: *TerminalWidgetSurfaceState, available: bool) bool {
        if (!available) self.presentation.invalidatePresentationCache(.{ .availability = true });
        self.presentation.target_available = available;
        return surface_attachment_contract.hostSharedSurfaceAttachmentReady(
            self.presentation.terminal_presentable_ready,
            self.presentation.target_available,
        );
    }

    /// Read-only: both attachment legs (same conjunction as `notePresentableAvailability` return).
    pub fn readSharedSurfaceAttachmentReady(self: *const TerminalWidgetSurfaceState) bool {
        return surface_attachment_contract.hostSharedSurfaceAttachmentReadyFromPair(.{
            .terminal_presentable_pipeline_ready = self.presentation.terminal_presentable_ready,
            .host_surface_target_available = self.presentation.target_available,
        });
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

    state.presentation.terminal_presentable_ready = true;
    try std.testing.expect(state.notePresentableAvailability(true));
    try std.testing.expect(state.readSharedSurfaceAttachmentReady());

    try std.testing.expect(!state.notePresentableAvailability(false));
    try std.testing.expect(!state.readSharedSurfaceAttachmentReady());
}

test "CZH-S16: pipeline leg ready without host target splits presentableReady vs attachment" {
    var state = TerminalWidgetSurfaceState.init(std.testing.allocator);
    defer state.deinit(std.testing.allocator);

    state.presentation.terminal_presentable_ready = true;
    state.presentation.target_available = false;
    try std.testing.expect(state.presentableReady());
    try std.testing.expect(!state.readSharedSurfaceAttachmentReady());
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
