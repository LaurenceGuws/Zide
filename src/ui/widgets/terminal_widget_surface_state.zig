const kitty_mod = @import("terminal_widget_kitty.zig");
const presentation_state_mod = @import("terminal_widget_presentation_state.zig");
const view_state = @import("terminal_widget_view_state.zig");
const terminal_types = @import("../../terminal/model/types.zig");

const KittyState = kitty_mod.KittyState;
const PresentationState = presentation_state_mod.PresentationState;
const CursorPos = view_state.CursorPos;

pub const TerminalWidgetSurfaceState = struct {
    pub const PresentationUpdateDelta = struct {
        cell_metrics_changed: bool,
        render_scale_changed: bool,
        generation_changed: bool,
        clear_generation_changed: bool,
        presentable_ready: bool,
        cursor_changed: bool,
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

    pub fn invalidatePresentationCache(self: *TerminalWidgetSurfaceState) void {
        self.presentation.invalidatePresentationCache();
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

    pub fn presentationUpdateDelta(
        self: *const TerminalWidgetSurfaceState,
        terminal_view: view_state.TerminalViewModel,
        surface_geometry: anytype,
        draw_cursor: bool,
        cursor: CursorPos,
        cursor_style: terminal_types.CursorStyle,
    ) PresentationUpdateDelta {
        return .{
            .cell_metrics_changed = surface_geometry.cell_w_i != self.presentation.last_cell_w_i or
                surface_geometry.cell_h_i != self.presentation.last_cell_h_i,
            .render_scale_changed = surface_geometry.render_scale != self.presentation.last_render_scale,
            .generation_changed = terminal_view.generation != self.presentation.last_render_generation,
            .clear_generation_changed = terminal_view.clear_generation != self.presentation.last_render_clear_generation,
            .presentable_ready = self.presentation.terminal_presentable_ready,
            .cursor_changed = self.cursorPresentationChanged(draw_cursor, cursor, cursor_style),
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
        if (!available) self.presentation.terminal_presentable_ready = false;
        return self.presentation.terminal_presentable_ready and available;
    }

    pub fn ensurePartialDrawPlan(
        self: *TerminalWidgetSurfaceState,
        allocator: anytype,
        rows: usize,
    ) ?PresentationState.PresentationPartialDrawPlan {
        return self.presentation.ensurePartialDrawPlan(allocator, rows);
    }
};
