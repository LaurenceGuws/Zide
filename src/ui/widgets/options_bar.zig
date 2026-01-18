const renderer_mod = @import("../renderer.zig");

const Renderer = renderer_mod.Renderer;
const Color = renderer_mod.Color;

/// Top options bar (VSCode-style app menu)
pub const OptionsBar = struct {
    height: f32 = 26,

    pub fn draw(self: *OptionsBar, r: *Renderer, width: f32) void {
        // Background
        r.drawRect(0, 0, @intFromFloat(width), @intFromFloat(self.height), Color{ .r = 24, .g = 25, .b = 33 });

        // Menu labels
        const labels = [_][]const u8{ "File", "Edit", "Selection", "View", "Go", "Run", "Terminal", "Help" };
        var x: f32 = 10;
        const y: f32 = (self.height - r.char_height) / 2;
        const mouse = r.getMousePos();
        const pressed = r.isMouseButtonDown(renderer_mod.MOUSE_LEFT);
        for (labels) |label| {
            const text_w = @as(f32, @floatFromInt(label.len)) * r.char_width;
            const pad_x: f32 = 6;
            const pad_y: f32 = 4;
            const bx = x - pad_x;
            const by = y - pad_y;
            const bw = text_w + pad_x * 2;
            const bh = r.char_height + pad_y * 2;
            const hovered = mouse.x >= bx and mouse.x <= bx + bw and mouse.y >= by and mouse.y <= by + bh;
            if (hovered) {
                const bg = if (pressed) Color{ .r = 58, .g = 60, .b = 78 } else Color.selection;
                r.drawRect(@intFromFloat(bx), @intFromFloat(by), @intFromFloat(bw), @intFromFloat(bh), bg);
            }
            r.drawText(label, x, y, if (hovered) Color.fg else Color.comment);
            x += text_w + 16;
        }
    }
};

