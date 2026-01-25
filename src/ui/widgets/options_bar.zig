const app_shell = @import("../../app_shell.zig");
const shared_types = @import("../../types/mod.zig");

const Shell = app_shell.Shell;
const Color = app_shell.Color;

/// Top options bar (VSCode-style app menu)
pub const OptionsBar = struct {
    height: f32 = 26,
    last_mouse: shared_types.input.MousePos = .{ .x = 0, .y = 0 },
    mouse_down_left: bool = false,

    pub fn updateInput(self: *OptionsBar, input: shared_types.input.InputSnapshot) void {
        self.last_mouse = input.mouse_pos;
        self.mouse_down_left = input.mouse_down[@intFromEnum(shared_types.input.MouseButton.left)];
    }

    pub fn draw(self: *OptionsBar, shell: *Shell, width: f32) void {
        // Background
        shell.drawRect(0, 0, @intFromFloat(width), @intFromFloat(self.height), Color{ .r = 24, .g = 25, .b = 33 });

        // Menu labels
        const labels = [_][]const u8{ "File", "Edit", "Selection", "View", "Go", "Run", "Terminal", "Help" };
        const scale = shell.uiScaleFactor();
        var x: f32 = 10 * scale;
        const y: f32 = (self.height - shell.charHeight()) / 2;
        const mouse = self.last_mouse;
        const pressed = self.mouse_down_left;
        for (labels) |label| {
            const text_w = @as(f32, @floatFromInt(label.len)) * shell.charWidth();
            const pad_x: f32 = 6 * scale;
            const pad_y: f32 = 4 * scale;
            const bx = x - pad_x;
            const by = y - pad_y;
            const bw = text_w + pad_x * 2;
            const bh = shell.charHeight() + pad_y * 2;
            const hovered = mouse.x >= bx and mouse.x <= bx + bw and mouse.y >= by and mouse.y <= by + bh;
            if (hovered) {
                const bg = if (pressed) Color{ .r = 58, .g = 60, .b = 78 } else Color.selection;
                shell.drawRect(@intFromFloat(bx), @intFromFloat(by), @intFromFloat(bw), @intFromFloat(bh), bg);
            }
            shell.drawText(label, x, y, if (hovered) Color.fg else Color.comment);
            x += text_w + 16 * scale;
        }
    }
};
