const shared_types = @import("../types/mod.zig");
const input_actions = @import("../input/input_actions.zig");
const app_modes = @import("modes/mod.zig");
const app_bootstrap = @import("bootstrap.zig");

const layout_types = shared_types.layout;
const input_types = shared_types.input;

pub const Hooks = struct {
    handle_ide_mouse_pressed_routing: *const fn (
        *anyopaque,
        layout_types.WidgetLayout,
        input_types.MousePos,
        f32,
        f64,
    ) anyerror!void,
    handle_terminal_mouse_pressed_routing: *const fn (
        *anyopaque,
        layout_types.WidgetLayout,
        input_types.MousePos,
    ) anyerror!void,
    handle_editor_mouse_pressed_routing: *const fn (*anyopaque) anyerror!void,
    log_mouse_debug_click: *const fn (*anyopaque) void,
};

pub fn handle(
    app_mode: app_bootstrap.AppMode,
    input_batch: *input_types.InputBatch,
    layout: layout_types.WidgetLayout,
    mouse: input_types.MousePos,
    term_y: f32,
    now: f64,
    ctx: *anyopaque,
    hooks: Hooks,
) !void {
    if (!input_batch.mousePressed(.left)) return;
    switch (app_modes.ide.mouseClickRoute(app_mode)) {
        .ide => try hooks.handle_ide_mouse_pressed_routing(ctx, layout, mouse, term_y, now),
        .terminal => try hooks.handle_terminal_mouse_pressed_routing(ctx, layout, mouse),
        .editor => try hooks.handle_editor_mouse_pressed_routing(ctx),
    }
    hooks.log_mouse_debug_click(ctx);
}
