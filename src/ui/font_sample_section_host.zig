const app_shell = @import("../app_shell.zig");
const renderer_surface_host = @import("renderer/renderer_surface_host.zig");
const renderer_text_host = @import("renderer/renderer_text_host.zig");
const renderer_mod = @import("renderer.zig");

const Color = app_shell.Color;
const Renderer = renderer_mod.Renderer;

pub const Section = struct {
    renderer: *Renderer,
    bg: Color,

    pub fn init(renderer: *Renderer, bg: Color) Section {
        return .{
            .renderer = renderer,
            .bg = bg,
        };
    }

    pub fn fillRect(self: Section, x: i32, y: i32, w: i32, h: i32, color: Color) void {
        renderer_surface_host.drawRect(self.renderer, x, y, w, h, color);
    }

    pub fn drawText(self: Section, text: []const u8, x: f32, y: f32, color: Color) void {
        renderer_text_host.drawText(self.renderer, text, x, y, color);
    }

    pub fn applyBg(self: Section) void {
        var bg_rgba = self.bg.toRgba();
        bg_rgba.a = 255;
        self.renderer.text_render.bg_rgba = bg_rgba;
    }

    pub fn clearBg(self: Section) void {
        self.renderer.text_render.bg_rgba = .{ .r = 0, .g = 0, .b = 0, .a = 0 };
    }
};
