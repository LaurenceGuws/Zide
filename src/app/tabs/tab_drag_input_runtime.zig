const app_bootstrap = @import("../bootstrap.zig");
const app_modes = @import("../modes/mod.zig");
const app_tab_drag_frame = @import("tab_drag_frame.zig");
const app_tab_drag_routing_runtime = @import("tab_drag_routing_runtime.zig");
const shared_types = @import("../../types/mod.zig");
const widgets = @import("../../ui/widgets.zig");

const input_types = shared_types.input;
const layout_types = shared_types.layout;
const TabBar = widgets.TabBar;

pub const Hooks = struct {
    apply_terminal_action: *const fn (*anyopaque, app_modes.shared.actions.TabAction) anyerror!void,
    route_activate_by_tab_id: *const fn (*anyopaque, ?u64) anyerror!void,
    focus_terminal_tab_index: *const fn (*anyopaque, usize) bool,
    apply_editor_action: *const fn (*anyopaque, app_modes.shared.actions.TabAction) anyerror!void,
    mark_redraw: *const fn (*anyopaque) void,
    note_input: *const fn (*anyopaque, f64) void,
};

const RuntimeCtx = struct {
    tab_bar: *TabBar,
    terminal_tab_bar_visible: bool,
    active_tab: *usize,
    user_ctx: *anyopaque,
    hooks: Hooks,
};

pub fn handle(
    app_mode: app_bootstrap.AppMode,
    tab_bar: *TabBar,
    terminal_tab_bar_visible: bool,
    active_tab: *usize,
    input_batch: *input_types.InputBatch,
    layout: layout_types.WidgetLayout,
    mouse: input_types.MousePos,
    now: f64,
    ctx: *anyopaque,
    hooks: Hooks,
) !void {
    var runtime_ctx: RuntimeCtx = .{
        .tab_bar = tab_bar,
        .terminal_tab_bar_visible = terminal_tab_bar_visible,
        .active_tab = active_tab,
        .user_ctx = ctx,
        .hooks = hooks,
    };
    try app_tab_drag_frame.handle(
        app_mode,
        input_batch,
        layout,
        mouse,
        now,
        @ptrCast(&runtime_ctx),
        .{
            .handle_terminal_tab_drag_input = struct {
                fn call(
                    raw: *anyopaque,
                    drag_input_batch: *input_types.InputBatch,
                    drag_layout: layout_types.WidgetLayout,
                    drag_mouse: input_types.MousePos,
                    drag_now: f64,
                ) !void {
                    const route: *RuntimeCtx = @ptrCast(@alignCast(raw));
                    const result = try app_tab_drag_routing_runtime.handleTerminal(
                        route.tab_bar,
                        drag_input_batch,
                        drag_layout,
                        drag_mouse,
                        route.terminal_tab_bar_visible,
                        route.user_ctx,
                        .{
                            .apply_terminal_action = route.hooks.apply_terminal_action,
                            .route_activate_by_tab_id = route.hooks.route_activate_by_tab_id,
                            .focus_terminal_tab_index = route.hooks.focus_terminal_tab_index,
                        },
                    );
                    if (result.needs_redraw) route.hooks.mark_redraw(route.user_ctx);
                    if (result.note_input) route.hooks.note_input(route.user_ctx, drag_now);
                }
            }.call,
            .handle_ide_tab_drag_input = struct {
                fn call(
                    raw: *anyopaque,
                    drag_input_batch: *input_types.InputBatch,
                    drag_layout: layout_types.WidgetLayout,
                    drag_mouse: input_types.MousePos,
                    drag_now: f64,
                ) !void {
                    const route: *RuntimeCtx = @ptrCast(@alignCast(raw));
                    const result = try app_tab_drag_routing_runtime.handleIde(
                        route.tab_bar,
                        drag_input_batch,
                        drag_layout,
                        drag_mouse,
                        route.active_tab,
                        route.user_ctx,
                        .{
                            .apply_editor_action = route.hooks.apply_editor_action,
                        },
                    );
                    if (result.needs_redraw) route.hooks.mark_redraw(route.user_ctx);
                    if (result.note_input) route.hooks.note_input(route.user_ctx, drag_now);
                }
            }.call,
        },
    );
}
