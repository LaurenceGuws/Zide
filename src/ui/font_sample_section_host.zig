const std = @import("std");
const app_shell = @import("../app_shell.zig");
const app_logger = @import("../app_logger.zig");
const renderer_text_phase_group_host = @import("renderer/renderer_text_phase_group_host.zig");
const renderer_surface_host = @import("renderer/renderer_surface_host.zig");
const renderer_mod = @import("renderer.zig");

const Color = app_shell.Color;
const Renderer = renderer_mod.Renderer;

pub const Section = struct {
    renderer: *Renderer,
    bg: Color,
    text_ops: std.ArrayListUnmanaged(renderer_text_phase_group_host.ReplayOp) = .{},

    pub fn init(renderer: *Renderer, bg: Color) Section {
        return .{
            .renderer = renderer,
            .bg = bg,
        };
    }

    pub fn deinit(self: *Section) void {
        self.text_ops.deinit(self.renderer.allocator);
        self.text_ops = .{};
    }

    pub fn fillRect(self: *Section, x: i32, y: i32, w: i32, h: i32, color: Color) void {
        renderer_surface_host.drawRect(self.renderer, x, y, w, h, color);
    }

    fn queueTextOp(self: *Section, text: []const u8, x: f32, y: f32, color: Color, bg: Color) void {
        self.text_ops.append(self.renderer.allocator, .{
            .kind = .text,
            .text = text,
            .x = x,
            .y = y,
            .color = color,
            .bg = bg,
        }) catch |err| {
            const log = app_logger.logger("ui.font-sample.section");
            log.logf(.warning, "section text op append failed err={s}", .{@errorName(err)});
        };
    }

    pub fn drawTextOnBg(self: *Section, text: []const u8, x: f32, y: f32, color: Color) void {
        self.queueTextOp(text, x, y, color, self.bg);
    }

    pub fn drawTextOnColor(self: *Section, text: []const u8, x: f32, y: f32, color: Color, bg: Color) void {
        self.queueTextOp(text, x, y, color, bg);
    }

    pub fn flush(self: *Section) void {
        renderer_text_phase_group_host.replayOps(self.renderer, .sample_section, self.text_ops.items);
        self.text_ops.clearRetainingCapacity();
    }
};
