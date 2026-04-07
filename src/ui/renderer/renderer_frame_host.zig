const present_trace_runtime = @import("present_trace_runtime.zig");

pub fn beginFrameHost(renderer: anytype) void {
    renderer.present.frame_seq +%= 1;
    renderer.present.trace_current = .{ .frame_seq = renderer.present.frame_seq };
    renderer.clip_depth = 0;

    const display_metrics = renderer.display_metrics;
    renderer.width = display_metrics.window_w;
    renderer.height = display_metrics.window_h;
    renderer.render_width = display_metrics.drawable_w;
    renderer.render_height = display_metrics.drawable_h;

    renderer.text_render.bg_rgba = .{ .r = 0, .g = 0, .b = 0, .a = 0 };
}

pub fn finishFrameSubmission(renderer: anytype, succeeded: bool, present_ms: f64) present_trace_runtime.FrameSubmission {
    renderer.present.last_swap_ms = present_ms;
    renderer.present.main_composition_target = .default_target;
    renderer.present.trace_last = renderer.present.trace_current;
    renderer.present.capture_path = null;
    renderer.present.capture_armed = false;
    renderer.present.capture_frame_seq = 0;
    if (succeeded) renderer.present.submission_sequence += 1;
    return .{
        .succeeded = succeeded,
        .sequence = renderer.present.submission_sequence,
        .terminal_presented = renderer.present.trace_current.terminal_presentation_count > 0,
        .terminal_presented_generation = renderer.present.trace_current.terminal_presented_generation,
    };
}
