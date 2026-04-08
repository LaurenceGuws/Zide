const present_trace_runtime = @import("present_trace_runtime.zig");

pub const FrameExecutionOutcome = present_trace_runtime.FrameExecutionOutcome;
pub const FrameExecutionOutcomeKind = present_trace_runtime.FrameExecutionOutcomeKind;

pub fn beginFrameHost(renderer: anytype) void {
    renderer.present.frame_seq +%= 1;
    renderer.present.frame_execution_state = .not_attempted;
    renderer.present.trace_current = .{ .frame_seq = renderer.present.frame_seq };
    renderer.clip_depth = 0;

    const display_metrics = renderer.display_metrics;
    renderer.width = display_metrics.window_w;
    renderer.height = display_metrics.window_h;
    renderer.render_width = display_metrics.drawable_w;
    renderer.render_height = display_metrics.drawable_h;

    renderer.text_render.bg_rgba = .{ .r = 0, .g = 0, .b = 0, .a = 0 };
}

pub fn noteFrameReady(renderer: anytype) void {
    renderer.present.frame_execution_state = .ready;
}

pub fn noteFrameBeginFailed(renderer: anytype) void {
    renderer.present.frame_execution_state = .begin_failed;
}

pub fn noteFrameAbandoned(renderer: anytype) void {
    renderer.present.frame_execution_state = .abandoned;
}

pub fn frameReadyForDraw(renderer: anytype) bool {
    return renderer.present.frame_execution_state == .ready;
}

pub fn finishFrameSubmission(renderer: anytype, outcome: FrameExecutionOutcome) present_trace_runtime.FrameSubmission {
    renderer.present.last_swap_ms = outcome.present_ms;
    renderer.present.main_composition_target = .default_target;
    renderer.present.trace_last = renderer.present.trace_current;
    renderer.present.capture_path = null;
    renderer.present.capture_armed = false;
    renderer.present.capture_frame_seq = 0;
    renderer.present.frame_execution_state = .not_attempted;
    const succeeded = outcome.kind == .submitted;
    if (succeeded) renderer.present.submission_sequence += 1;
    return .{
        .succeeded = succeeded,
        .sequence = renderer.present.submission_sequence,
        .terminal_presented = renderer.present.trace_current.terminal_presentation_count > 0,
        .terminal_presented_generation = renderer.present.trace_current.terminal_presented_generation,
    };
}
