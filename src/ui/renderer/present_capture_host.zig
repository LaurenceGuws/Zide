const present_capture_state = @import("present_capture_state.zig");

pub fn armCapture(renderer: anytype, path: []const u8) void {
    renderer.present.capture = .{
        .path = path,
        .armed = true,
        .frame_seq = renderer.present.frame_seq,
    };
}

pub fn clearAfterSubmission(renderer: anytype) void {
    renderer.present.capture = .{};
}

pub fn noteCapturedPath(renderer: anytype, path: []const u8) void {
    renderer.present.trace_current.captured_path = path;
}

pub fn state(renderer: anytype) *present_capture_state.PresentCaptureState {
    return &renderer.present.capture;
}
