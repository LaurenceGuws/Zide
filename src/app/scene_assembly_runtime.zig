const app_active_editor_draw_surface_runtime = @import("editor/editor_draw_surface_runtime.zig");
const app_draw_overlays_runtime = @import("draw_overlays_runtime.zig");
const app_shell_chrome_draw_runtime = @import("shell_chrome_draw_runtime.zig");
const app_tabbar_draw_runtime = @import("tabs/tabbar_draw_runtime.zig");
const app_terminal_draw_surface_runtime = @import("terminal/terminal_draw_surface_runtime.zig");
const mode_build = @import("mode_build.zig");
const widgets_common = @import("../ui/widgets/common.zig");
const shared_types = @import("../types/mod.zig");

const layout_types = shared_types.layout;

pub const Hooks = struct {
    apply_current_tab_bar_width_mode: *const fn (*anyopaque) void,
    terminal_close_confirm_active: *const fn (*anyopaque) bool,
};

pub fn draw(state: anytype, shell: anytype, layout: layout_types.WidgetLayout, ctx: *anyopaque, hooks: Hooks) ?widgets_common.Tooltip {
    const tab_tooltip = app_tabbar_draw_runtime.draw(
        state,
        shell,
        layout,
        ctx,
        .{
            .apply_current_tab_bar_width_mode = hooks.apply_current_tab_bar_width_mode,
        },
    );

    if (comptime mode_build.focused_mode != .terminal) {
        app_active_editor_draw_surface_runtime.draw(state, shell, layout);
    }
    app_terminal_draw_surface_runtime.draw(state, shell, layout);
    app_shell_chrome_draw_runtime.draw(state, shell, layout, tab_tooltip);
    app_draw_overlays_runtime.draw(
        state,
        shell,
        layout,
        ctx,
        .{
            .terminal_close_confirm_active = hooks.terminal_close_confirm_active,
        },
    );
    return tab_tooltip;
}
