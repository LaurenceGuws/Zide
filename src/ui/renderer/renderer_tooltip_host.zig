const app_shell = @import("../../app_shell.zig");
const renderer_surface_host = @import("renderer_surface_host.zig");
const renderer_text_host = @import("renderer_text_host.zig");

const Color = app_shell.Color;

pub const TooltipStyle = struct {
    bg: Color,
    border: Color,
    text: Color,
};

pub fn draw(renderer: anytype, text: []const u8, x: f32, y: f32, w: f32, h: f32, padding: f32, style: TooltipStyle) void {
    renderer_surface_host.drawRect(
        renderer,
        @intFromFloat(x),
        @intFromFloat(y),
        @intFromFloat(w),
        @intFromFloat(h),
        style.bg,
    );
    renderer_surface_host.drawRectOutline(
        renderer,
        @intFromFloat(x),
        @intFromFloat(y),
        @intFromFloat(w),
        @intFromFloat(h),
        style.border,
    );
    renderer_text_host.drawText(renderer, text, x + padding, y + padding, style.text);
}
