const std = @import("std");
const app_shell = @import("../../app_shell.zig");
const common = @import("common.zig");

const Shell = app_shell.Shell;
const Color = app_shell.Color;

/// Status bar at the bottom
pub const StatusBar = struct {
    height: f32 = 24,

    pub fn draw(
        self: *StatusBar,
        shell: *Shell,
        width: f32,
        y: f32,
        mode: []const u8,
        file_path: ?[]const u8,
        line: usize,
        col: usize,
        modified: bool,
    ) void {
        const scale = shell.uiScaleFactor();
        // Background
        shell.drawRect(0, @intFromFloat(y), @intFromFloat(width), @intFromFloat(self.height), Color{ .r = 30, .g = 31, .b = 41 });

        // Line/column (reserve space on right)
        var pos_buf: [32]u8 = undefined;
        const pos_str = std.fmt.bufPrint(&pos_buf, "Ln {d}, Col {d}", .{ line + 1, col + 1 }) catch return;
        const pos_width = @as(f32, @floatFromInt(pos_str.len)) * shell.charWidth();
        const pos_start = width - pos_width - 16 * scale;

        // Mode indicator
        const mode_bg = if (std.mem.eql(u8, mode, "INSERT"))
            Color.green
        else if (std.mem.eql(u8, mode, "VISUAL"))
            Color.purple
        else
            Color.cyan;

        const mode_width: f32 = 80 * scale;
        const text_y: f32 = y + (self.height - shell.charHeight()) / 2;
        const text_x: f32 = 8 * scale;
        const mouse = shell.getMousePos();
        const pressed = shell.isMouseButtonDown(app_shell.MOUSE_LEFT);
        const mode_hover = mouse.x >= 0 and mouse.x <= mode_width and mouse.y >= y and mouse.y <= y + self.height;
        const mode_bg_final = if (mode_hover and pressed) Color{ .r = 58, .g = 60, .b = 78 } else if (mode_hover) Color.selection else mode_bg;
        shell.drawRect(0, @intFromFloat(y), @intFromFloat(mode_width), @intFromFloat(self.height), mode_bg_final);
        shell.drawText(mode, text_x, text_y, if (mode_hover) Color.fg else Color.black);

        // File path
        var x: f32 = 88 * scale;
        if (file_path) |path| {
            const available = pos_start - 16 * scale - x;
            const result = common.drawTruncatedText(shell, path, x, text_y, Color.fg, available);
            const mouse_path = shell.getMousePos();
            const in_path = mouse_path.x >= x and mouse_path.x <= x + result.drawn_width and
                mouse_path.y >= y and mouse_path.y <= y + self.height;
            if (result.truncated and in_path) {
                common.drawTooltip(shell, path, mouse_path.x, mouse_path.y);
            }
            x += result.drawn_width + 16 * scale;
        }

        // Modified indicator
        if (modified) {
            const indicator = "[+]";
            const indicator_width = @as(f32, @floatFromInt(indicator.len)) * shell.charWidth();
            if (x + indicator_width <= pos_start - 8 * scale) {
                shell.drawText(indicator, x, text_y, Color.orange);
            }
        }

        const pos_hover = mouse.x >= pos_start and mouse.x <= pos_start + pos_width and mouse.y >= y and mouse.y <= y + self.height;
        if (pos_hover) {
            const bg = if (pressed) Color{ .r = 58, .g = 60, .b = 78 } else Color.selection;
            shell.drawRect(@intFromFloat(pos_start - 4 * scale), @intFromFloat(y + 2 * scale), @intFromFloat(pos_width + 8 * scale), @intFromFloat(self.height - 4 * scale), bg);
        }
        shell.drawText(pos_str, pos_start, text_y, if (pos_hover) Color.fg else Color.comment);
    }
};
