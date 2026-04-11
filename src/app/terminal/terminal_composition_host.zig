const app_shell = @import("../../app_shell.zig");
const renderer_chrome_band_host = @import("../../ui/renderer/renderer_chrome_band_host.zig");

const Shell = app_shell.Shell;
const Color = app_shell.Color;
const Band = renderer_chrome_band_host.Band;

pub const TerminalBand = struct {
    band: Band,

    pub fn init(shell: *Shell, bg: Color) TerminalBand {
        return .{ .band = Band.init(shell, bg) };
    }

    pub fn fillRect(self: *TerminalBand, x: i32, y: i32, w: i32, h: i32, color: Color) void {
        self.band.fillRect(x, y, w, h, color);
    }

    pub fn drawRectOutline(self: *TerminalBand, x: i32, y: i32, w: i32, h: i32, color: Color) void {
        self.band.drawRectOutline(x, y, w, h, color);
    }

    pub fn drawText(self: *TerminalBand, text: []const u8, x: f32, y: f32, color: Color) void {
        self.band.drawText(text, x, y, color);
    }

    pub fn flush(self: *TerminalBand) void {
        self.band.flush();
    }
};
