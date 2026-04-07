const app_editor_live_smoke_runtime = @import("editor/live_smoke_runtime.zig");
const app_logger = @import("../app_logger.zig");
const mode_build = @import("mode_build.zig");
const app_terminal_active_widget = @import("terminal/terminal_active_widget.zig");

fn flushTerminalPresentationFeedback(state: anytype, submission: anytype) void {
    if (app_terminal_active_widget.resolveActive(
        state.app_mode,
        &state.terminal_workspace,
        state.terminals.items.len,
        state.terminal_widgets.items,
    )) |term_widget| {
        term_widget.completePendingPresentationFeedback(submission);
    }
}

fn logFramePresent(state: anytype, shell: anytype, submission: anytype) void {
    const trace = shell.lastPresentTrace();
    app_logger.logger("renderer.present").logFields(.info, "frame_present", &.{
        .{ .key = "frame", .value = .{ .unsigned = state.frame_id } },
        .{ .key = "frame_seq", .value = .{ .unsigned = trace.frame_seq } },
        .{ .key = "submission_seq", .value = .{ .unsigned = submission.sequence } },
        .{ .key = "terminal_presentations", .value = .{ .unsigned = trace.terminal_presentation_count } },
        .{ .key = "terminal_presented_generation", .value = .{ .unsigned = if (trace.terminal_presented_generation) |g| g else 0 } },
        .{ .key = "composition_clips", .value = .{ .unsigned = trace.composition_clip_count } },
        .{ .key = "band_group_begin", .value = .{ .unsigned = trace.band_group_begin_count } },
        .{ .key = "band_group_end", .value = .{ .unsigned = trace.band_group_end_count } },
        .{ .key = "composition_full_pane_clear", .value = .{ .boolean = trace.composition_full_pane_clear } },
        .{ .key = "captured", .value = .{ .boolean = trace.captured_path != null } },
    });
    if (trace.captured_path) |path| {
        app_logger.logger("editor.live_smoke").logf(.info, "captured_frame frame={d} path={s}", .{ state.frame_id, path });
    }
}

pub fn completePresent(state: anytype, shell: anytype, submission: anytype) void {
    logFramePresent(state, shell, submission);

    if (comptime mode_build.focused_mode == .terminal) {
        flushTerminalPresentationFeedback(state, submission);
        return;
    }

    if (app_editor_live_smoke_runtime.keepDrivingFrames(state)) {
        state.needs_redraw = true;
    }
    if (app_editor_live_smoke_runtime.shouldClose(state)) {
        shell.requestClose();
    }
    flushTerminalPresentationFeedback(state, submission);
}
