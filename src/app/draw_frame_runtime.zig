const app_font_sample_draw_runtime = @import("font_sample_draw_runtime.zig");
const app_terminal_draw_surface_runtime = @import("terminal/terminal_draw_surface_runtime.zig");
const app_editor_live_smoke_runtime = @import("editor/live_smoke_runtime.zig");
const app_editor_draw_surface_runtime = @import("editor/editor_draw_surface_runtime.zig");
const app_present_feedback_runtime = @import("present_feedback_runtime.zig");
const app_scene_assembly_runtime = @import("scene_assembly_runtime.zig");
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
        const submission = shell.endFrame();
        app_terminal_draw_surface_runtime.flushPresentationFeedback(state, submission);
        return;
    }

    const width = @as(f32, @floatFromInt(shell.width()));
    const height = @as(f32, @floatFromInt(shell.height()));
    const layout = hooks.compute_layout(ctx, width, height);
    _ = app_scene_assembly_runtime.draw(
        state,
        shell,
        layout,
        ctx,
        .{
            .apply_current_tab_bar_width_mode = hooks.apply_current_tab_bar_width_mode,
            .terminal_close_confirm_active = hooks.terminal_close_confirm_active,
        },
    );
    if (comptime mode_build.focused_mode != .terminal) {
        app_editor_draw_surface_runtime.redrawAfterPendingHighlight(state, shell, layout);
    }

    const capture_path = if (comptime mode_build.focused_mode == .terminal)
        null
    else
        app_editor_live_smoke_runtime.armPresentCapture(state, shell);
    const submission = shell.endFrame();
    defer if (capture_path) |path| state.allocator.free(path);
    app_present_feedback_runtime.completePresent(state, shell, submission);
}
