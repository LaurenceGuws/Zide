const kitty_mod = @import("terminal_widget_kitty.zig");
const retained_state_mod = @import("terminal_widget_retained_state.zig");
const view_state = @import("terminal_widget_view_state.zig");

const KittyState = kitty_mod.KittyState;
const RetainedState = retained_state_mod.RetainedState;

pub const TerminalWidgetSurfaceState = struct {
    pub const PresentationUpdateDelta = struct {
        cell_metrics_changed: bool,
        render_scale_changed: bool,
        generation_changed: bool,
        clear_generation_changed: bool,
        presentable_ready: bool,
    };

    kitty: KittyState,
    retained: RetainedState,

    pub fn init(allocator: anytype) TerminalWidgetSurfaceState {
        return .{
            .kitty = KittyState.init(allocator),
            .retained = RetainedState.init(),
        };
    }

    pub fn deinit(self: *TerminalWidgetSurfaceState, allocator: anytype) void {
        self.retained.deinit(allocator);
        self.kitty.deinit(allocator);
    }

    pub fn invalidateTextureCache(self: *TerminalWidgetSurfaceState) void {
        self.retained.invalidateTextureCache();
    }

    pub fn lifecycleTransition(
        self: *TerminalWidgetSurfaceState,
        terminal_view: view_state.TerminalViewModel,
    ) view_state.LifecycleTransitionInfo {
        const transition = terminal_view.lifecycleTransition(self.retained.last_alt_active);
        self.retained.last_alt_active = transition.current_alt_active;
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
        return self.retained.last_render_generation;
    }

    pub fn presentableReady(self: *const TerminalWidgetSurfaceState) bool {
        return self.retained.terminal_presentable_ready;
    }

    pub fn presentationUpdateDelta(
        self: *const TerminalWidgetSurfaceState,
        terminal_view: view_state.TerminalViewModel,
        surface_geometry: anytype,
    ) PresentationUpdateDelta {
        return .{
            .cell_metrics_changed = surface_geometry.cell_w_i != self.retained.last_cell_w_i or
                surface_geometry.cell_h_i != self.retained.last_cell_h_i,
            .render_scale_changed = surface_geometry.render_scale != self.retained.last_render_scale,
            .generation_changed = terminal_view.generation != self.retained.last_render_generation,
            .clear_generation_changed = terminal_view.clear_generation != self.retained.last_render_clear_generation,
            .presentable_ready = self.retained.terminal_presentable_ready,
        };
    }

    pub fn notePresentationUpdated(
        self: *TerminalWidgetSurfaceState,
        terminal_view: view_state.TerminalViewModel,
        surface_geometry: anytype,
    ) void {
        self.retained.terminal_presentable_ready = true;
        self.retained.last_render_generation = terminal_view.generation;
        self.retained.last_render_clear_generation = terminal_view.clear_generation;
        self.retained.last_cell_w_i = surface_geometry.cell_w_i;
        self.retained.last_cell_h_i = surface_geometry.cell_h_i;
        self.retained.last_render_scale = surface_geometry.render_scale;
    }

    pub fn notePresentableAvailability(self: *TerminalWidgetSurfaceState, available: bool) bool {
        if (!available) self.retained.terminal_presentable_ready = false;
        return self.retained.terminal_presentable_ready and available;
    }

    pub fn ensurePartialDrawPlan(
        self: *TerminalWidgetSurfaceState,
        allocator: anytype,
        rows: usize,
    ) ?RetainedState.PartialDrawPlan {
        return self.retained.ensurePartialDrawPlan(allocator, rows);
    }
};
