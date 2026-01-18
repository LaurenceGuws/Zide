const std = @import("std");
const renderer_mod = @import("../renderer.zig");
const common = @import("common.zig");

const Renderer = renderer_mod.Renderer;
const Color = renderer_mod.Color;

/// Status bar at the bottom
pub const StatusBar = struct {
    height: f32 = 24,

    pub fn draw(
        self: *StatusBar,
        r: *Renderer,
        width: f32,
        y: f32,
        mode: []const u8,
        file_path: ?[]const u8,
        line: usize,
        col: usize,
        modified: bool,
    ) void {
        // Background
        r.drawRect(0, @intFromFloat(y), @intFromFloat(width), @intFromFloat(self.height), Color{ .r = 30, .g = 31, .b = 41 });

        // Line/column (reserve space on right)
        var pos_buf: [32]u8 = undefined;
        const pos_str = std.fmt.bufPrint(&pos_buf, "Ln {d}, Col {d}", .{ line + 1, col + 1 }) catch return;
        const pos_width = @as(f32, @floatFromInt(pos_str.len)) * r.char_width;
        const pos_start = width - pos_width - 16;

        // Mode indicator
        const mode_bg = if (std.mem.eql(u8, mode, "INSERT"))
            Color.green
        else if (std.mem.eql(u8, mode, "VISUAL"))
            Color.purple
        else
            Color.cyan;

        const mouse = r.getMousePos();
        const pressed = r.isMouseButtonDown(renderer_mod.MOUSE_LEFT);
        const mode_hover = mouse.x >= 0 and mouse.x <= 80 and mouse.y >= y and mouse.y <= y + self.height;
        const mode_bg_final = if (mode_hover and pressed) Color{ .r = 58, .g = 60, .b = 78 } else if (mode_hover) Color.selection else mode_bg;
        r.drawRect(0, @intFromFloat(y), 80, @intFromFloat(self.height), mode_bg_final);
        r.drawText(mode, 8, y + 4, if (mode_hover) Color.fg else Color.black);

        // File path
        var x: f32 = 88;
        if (file_path) |path| {
            const available = pos_start - 16 - x;
            const result = common.drawTruncatedText(r, path, x, y + 4, Color.fg, available);
            const mouse_path = r.getMousePos();
            const in_path = mouse_path.x >= x and mouse_path.x <= x + result.drawn_width and
                mouse_path.y >= y and mouse_path.y <= y + self.height;
            if (result.truncated and in_path) {
                common.drawTooltip(r, path, mouse_path.x, mouse_path.y);
            }
            x += result.drawn_width + 16;
        }

        // Modified indicator
        if (modified) {
            const indicator = "[+]";
            const indicator_width = @as(f32, @floatFromInt(indicator.len)) * r.char_width;
            if (x + indicator_width <= pos_start - 8) {
                r.drawText(indicator, x, y + 4, Color.orange);
            }
        }

        const pos_hover = mouse.x >= pos_start and mouse.x <= pos_start + pos_width and mouse.y >= y and mouse.y <= y + self.height;
        if (pos_hover) {
            const bg = if (pressed) Color{ .r = 58, .g = 60, .b = 78 } else Color.selection;
            r.drawRect(@intFromFloat(pos_start - 4), @intFromFloat(y + 2), @intFromFloat(pos_width + 8), @intFromFloat(self.height - 4), bg);
        }
        r.drawText(pos_str, pos_start, y + 4, if (pos_hover) Color.fg else Color.comment);
    }
};

