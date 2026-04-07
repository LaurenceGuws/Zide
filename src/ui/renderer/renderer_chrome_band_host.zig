const app_shell = @import("../../app_shell.zig");
const renderer_surface_host = @import("renderer_surface_host.zig");
const renderer_text_host = @import("renderer_text_host.zig");

const Shell = app_shell.Shell;
const Color = app_shell.Color;

pub const Band = struct {
    shell: *Shell,
    bg: Color,

    pub fn init(shell: *Shell, bg: Color) Band {
        return .{
            .shell = shell,
            .bg = bg,
        };
    }

    pub fn fillRect(self: Band, x: i32, y: i32, w: i32, h: i32, color: Color) void {
        renderer_surface_host.drawRect(self.shell.renderer, x, y, w, h, color);
    }

    pub fn drawRectOutline(self: Band, x: i32, y: i32, w: i32, h: i32, color: Color) void {
        renderer_surface_host.drawRectOutline(self.shell.renderer, x, y, w, h, color);
    }

    pub fn drawText(self: Band, text: []const u8, x: f32, y: f32, color: Color) void {
        renderer_text_host.drawText(self.shell.renderer, text, x, y, color);
    }

    pub fn drawTextOnBg(self: Band, text: []const u8, x: f32, y: f32, color: Color) void {
        renderer_text_host.drawTextOnBg(self.shell.renderer, text, x, y, color, self.bg);
    }

    pub fn drawTextOnColor(self: Band, text: []const u8, x: f32, y: f32, color: Color, bg: Color) void {
        renderer_text_host.drawTextOnBg(self.shell.renderer, text, x, y, color, bg);
    }

    pub fn drawIconText(self: Band, text: []const u8, x: f32, y: f32, color: Color) void {
        renderer_text_host.drawIconText(self.shell.renderer, text, x, y, color);
    }
};
