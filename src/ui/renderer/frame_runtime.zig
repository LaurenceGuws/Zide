const platform_window = @import("../../platform/window_metrics.zig");
const renderer_root = @import("../renderer.zig");
const scene_frame_runtime = @import("scene_frame_runtime.zig");
const gl_backend = @import("gl_backend.zig");
const metal_backend = @import("metal_backend.zig");

pub const FrameSubmission = scene_frame_runtime.FrameSubmission;
pub const PresentTrace = scene_frame_runtime.PresentTrace;
const WindowSizes = renderer_root.WindowSizes;

pub fn beginFrame(self: anytype) void {
    self.present.frame_seq +%= 1;
    self.present.trace_current = .{ .frame_seq = self.present.frame_seq };
    self.present.drawing_editor_surface = false;
    const display_metrics = self.display_metrics;
    const sizes = windowSizesFromDisplayMetrics(display_metrics);
    self.width = sizes.width;
    self.height = sizes.height;
    self.render_width = sizes.render_width;
    self.render_height = sizes.render_height;

    self.text_render.bg_rgba = .{ .r = 0, .g = 0, .b = 0, .a = 0 };
    metal_backend.clearQueuedSurfaceDraws(self);
    switch (self.backend) {
        .opengl => gl_backend.beginFrame(self),
        .metal => metal_backend.beginFrame(self),
    }
}

pub fn submitFrame(self: anytype) FrameSubmission {
    return switch (self.backend) {
        .opengl => gl_backend.submitFrame(self),
        .metal => metal_backend.submitFrame(self),
    };
}

pub fn armPresentCapture(self: anytype, path: []const u8) void {
    self.present.capture_path = path;
    self.present.capture_armed = true;
    self.present.capture_frame_seq = self.present.frame_seq;
}

pub fn lastPresentTrace(self: anytype) PresentTrace {
    return self.present.trace_last;
}

pub fn dumpWindowScreenshotPpm(self: anytype, path: []const u8) !void {
    return switch (self.backend) {
        .opengl => gl_backend.dumpWindowScreenshotPpm(self, path),
        .metal => error.RendererScreenshotUnavailable,
    };
}

pub fn dumpWindowScreenshotPpmSized(self: anytype, path: []const u8, out_width: i32, out_height: i32) !void {
    return switch (self.backend) {
        .opengl => gl_backend.dumpWindowScreenshotPpmSized(self, path, out_width, out_height),
        .metal => error.RendererScreenshotUnavailable,
    };
}

fn windowSizesFromDisplayMetrics(metrics: platform_window.DisplayMetrics) WindowSizes {
    return .{
        .width = metrics.window_w,
        .height = metrics.window_h,
        .render_width = metrics.drawable_w,
        .render_height = metrics.drawable_h,
    };
}
