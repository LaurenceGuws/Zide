const std = @import("std");
const app_font_sample_draw_runtime = @import("font_sample_draw_runtime.zig");
const app_editor_live_smoke_runtime = @import("editor/live_smoke_runtime.zig");
const app_editor_draw_surface_runtime = @import("editor/editor_draw_surface_runtime.zig");
const app_present_feedback_runtime = @import("present_feedback_runtime.zig");
const app_scene_assembly_runtime = @import("scene_assembly_runtime.zig");
const app_bootstrap = @import("bootstrap.zig");
const app_logger = @import("../app_logger.zig");
const app_terminal_active_widget = @import("terminal/terminal_active_widget.zig");
const mode_build = @import("mode_build.zig");
const shared_types = @import("../types/mod.zig");

const layout_types = shared_types.layout;

pub const Hooks = struct {
    compute_layout: *const fn (*anyopaque, f32, f32) layout_types.WidgetLayout,
    apply_current_tab_bar_width_mode: *const fn (*anyopaque) void,
    terminal_close_confirm_active: *const fn (*anyopaque) bool,
};

pub fn draw(state: anytype, shell: anytype, ctx: *anyopaque, hooks: Hooks) void {
    const frame_ready = shell.beginFrame();
    if (!frame_ready) {
        const submission = shell.endFrame();
        app_present_feedback_runtime.completePresent(state, shell, submission);
        return;
    }

    if (app_font_sample_draw_runtime.handle(state, shell)) {
        const submission = shell.endFrame();
        app_present_feedback_runtime.completePresent(state, shell, submission);
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
    if (state.app_mode == .terminal) {
        maybeDumpVisibleTerminalView(state, shell);
    }
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

fn maybeDumpVisibleTerminalView(state: anytype, shell: anytype) void {
    const dump_frame = app_bootstrap.parseEnvU64("ZIDE_TERMINAL_VISIBLE_DUMP_FRAME", std.math.maxInt(u64));
    if (state.frame_id < dump_frame) return;

    const log = app_logger.logger("terminal.ui.dump");
    const widget = app_terminal_active_widget.resolveActive(
        state.app_mode,
        &state.terminal_workspace,
        state.terminals.items.len,
        state.terminal_widgets.items,
    ) orelse {
        log.logf(.warning, "visible_ascii_dump skipped reason=no_active_terminal frame={d}", .{state.frame_id});
        return;
    };
    widget.dumpVisibleAsciiView(shell, log) catch |err| {
        log.logf(.warning, "visible_ascii_dump failed frame={d} err={s}", .{ state.frame_id, @errorName(err) });
    };
}
