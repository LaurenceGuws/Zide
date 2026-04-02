const app_font_sample_draw_runtime = @import("font_sample_draw_runtime.zig");
const app_terminal_draw_surface_runtime = @import("terminal/terminal_draw_surface_runtime.zig");
const app_editor_live_smoke_runtime = @import("editor/live_smoke_runtime.zig");
const app_active_editor_runtime = @import("editor/active_editor_runtime.zig");
const app_scene_assembly_runtime = @import("scene_assembly_runtime.zig");
const app_logger = @import("../app_logger.zig");
const mode_build = @import("mode_build.zig");
const shared_types = @import("../types/mod.zig");

const layout_types = shared_types.layout;

pub const Hooks = struct {
    compute_layout: *const fn (*anyopaque, f32, f32) layout_types.WidgetLayout,
    apply_current_tab_bar_width_mode: *const fn (*anyopaque) void,
    terminal_close_confirm_active: *const fn (*anyopaque) bool,
};

fn redrawEditorAfterPendingHighlight(state: anytype, shell: anytype, layout: layout_types.WidgetLayout) void {
    if (comptime mode_build.focused_mode == .terminal) return;

    const editor = app_active_editor_runtime.fromState(state);
    if (editor) |active_editor| {
        if (active_editor.applyPendingVisibleHighlightResult(&state.editor_render_cache)) {
            const app_editor_draw_surface_runtime = @import("editor/editor_draw_surface_runtime.zig");
            app_editor_draw_surface_runtime.draw(state, shell, layout);
        }
    }
}

fn armLiveSmokeCapture(state: anytype, shell: anytype) ?[]u8 {
    if (comptime mode_build.focused_mode == .terminal) return null;

    const capture_path = app_editor_live_smoke_runtime.capturePath(state, state.allocator) catch |err| blk: {
        app_logger.logger("editor.live_smoke").logf(.warning, "capture path build failed frame={d} err={s}", .{
            state.frame_id,
            @errorName(err),
        });
        break :blk null;
    };
    if (capture_path) |path| {
        shell.armPresentCapture(path);
    }
    return capture_path;
}

fn handleCompletedPresent(state: anytype, shell: anytype, submission: anytype) void {
    if (comptime mode_build.focused_mode == .terminal) {
        app_terminal_draw_surface_runtime.flushPresentationFeedback(state, submission);
        return;
    }

    const trace = shell.lastPresentTrace();
    app_logger.logger("renderer.present").logFields(.info, "frame_present", &.{
        .{ .key = "frame", .value = .{ .unsigned = state.frame_id } },
        .{ .key = "frame_seq", .value = .{ .unsigned = trace.frame_seq } },
        .{ .key = "submission_seq", .value = .{ .unsigned = submission.sequence } },
        .{ .key = "editor_surface_updates", .value = .{ .unsigned = trace.editor_surface_update_count } },
        .{ .key = "editor_surface_blits", .value = .{ .unsigned = trace.editor_surface_blit_count } },
        .{ .key = "composition_clips", .value = .{ .unsigned = trace.composition_clip_count } },
        .{ .key = "composition_full_pane_clear", .value = .{ .boolean = trace.composition_full_pane_clear } },
        .{ .key = "captured", .value = .{ .boolean = trace.captured_path != null } },
    });
    if (trace.captured_path) |path| {
        app_logger.logger("editor.live_smoke").logf(.info, "captured_frame frame={d} path={s}", .{ state.frame_id, path });
    }
    if (app_editor_live_smoke_runtime.keepDrivingFrames(state)) {
        state.needs_redraw = true;
    }
    if (app_editor_live_smoke_runtime.shouldClose(state)) {
        shell.requestClose();
    }
    app_terminal_draw_surface_runtime.flushPresentationFeedback(state, submission);
}

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
    redrawEditorAfterPendingHighlight(state, shell, layout);

    const capture_path = armLiveSmokeCapture(state, shell);
    const submission = shell.endFrame();
    defer if (capture_path) |path| state.allocator.free(path);
    handleCompletedPresent(state, shell, submission);
}
