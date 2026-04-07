const app_shell = @import("../../app_shell.zig");

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
        self.shell.drawRect(x, y, w, h, color);
    }

    pub fn drawRectOutline(self: Band, x: i32, y: i32, w: i32, h: i32, color: Color) void {
        self.shell.drawRectOutline(x, y, w, h, color);
    }

    pub fn drawText(self: Band, text: []const u8, x: f32, y: f32, color: Color) void {
        self.shell.drawText(text, x, y, color);
    }

    pub fn drawTextOnBg(self: Band, text: []const u8, x: f32, y: f32, color: Color) void {
        self.shell.drawTextOnBg(text, x, y, color, self.bg);
    }

    pub fn drawTextOnColor(self: Band, text: []const u8, x: f32, y: f32, color: Color, bg: Color) void {
        self.shell.drawTextOnBg(text, x, y, color, bg);
    }
};
