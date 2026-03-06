const app_font_sample_draw_runtime = @import("font_sample_draw_runtime.zig");
const app_tabbar_draw_runtime = @import("tabbar_draw_runtime.zig");
const app_terminal_draw_surface_runtime = @import("terminal_draw_surface_runtime.zig");
const app_shell_chrome_draw_runtime = @import("shell_chrome_draw_runtime.zig");
const app_draw_overlays_runtime = @import("draw_overlays_runtime.zig");
const mode_build = @import("mode_build.zig");
const shared_types = @import("../types/mod.zig");

const layout_types = shared_types.layout;

pub const Hooks = struct {
    compute_layout: *const fn (*anyopaque, f32, f32) layout_types.WidgetLayout,
    apply_current_tab_bar_width_mode: *const fn (*anyopaque) void,
    terminal_close_confirm_active: *const fn (*anyopaque) bool,
};

pub fn draw(state: anytype, shell: anytype, ctx: *anyopaque, hooks: Hooks) void {
    shell.beginFrame();

    if (app_font_sample_draw_runtime.handle(state, shell)) {
        shell.endFrame();
        return;
    }

    const width = @as(f32, @floatFromInt(shell.width()));
    const height = @as(f32, @floatFromInt(shell.height()));
    const layout = hooks.compute_layout(ctx, width, height);
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
        const app_editor_draw_surface_runtime = @import("editor_draw_surface_runtime.zig");
        app_editor_draw_surface_runtime.draw(state, shell, layout);
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

    shell.endFrame();
}
