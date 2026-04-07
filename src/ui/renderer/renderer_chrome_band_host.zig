const std = @import("std");
const app_shell = @import("../../app_shell.zig");
const app_logger = @import("../../app_logger.zig");
const renderer_band_phase_host = @import("renderer_band_phase_host.zig");
const renderer_surface_host = @import("renderer_surface_host.zig");

const Shell = app_shell.Shell;
const Color = app_shell.Color;

pub const Band = struct {
    const TextKind = renderer_band_phase_host.TextKind;
    const TextOp = renderer_band_phase_host.ReplayOp;

    shell: *Shell,
    bg: Color,
    text_ops: std.ArrayListUnmanaged(TextOp) = .{},

    pub fn init(shell: *Shell, bg: Color) Band {
        return .{
            .shell = shell,
            .bg = bg,
        };
    }

    pub fn fillRect(self: *Band, x: i32, y: i32, w: i32, h: i32, color: Color) void {
        renderer_surface_host.drawRect(self.shell.renderer, x, y, w, h, color);
    }

    pub fn drawRectOutline(self: *Band, x: i32, y: i32, w: i32, h: i32, color: Color) void {
        renderer_surface_host.drawRectOutline(self.shell.renderer, x, y, w, h, color);
    }

    fn queueTextOp(self: *Band, kind: TextKind, text: []const u8, x: f32, y: f32, color: Color, bg: Color) void {
        self.text_ops.append(self.shell.renderer.allocator, .{
            .kind = kind,
            .text = text,
            .x = x,
            .y = y,
            .color = color,
            .bg = bg,
        }) catch |err| {
            const log = app_logger.logger("renderer.chrome.band");
            log.logf(.warning, "band text op append failed err={s}", .{@errorName(err)});
            return;
        };
    }

    pub fn drawText(self: *Band, text: []const u8, x: f32, y: f32, color: Color) void {
        self.queueTextOp(.text, text, x, y, color, self.bg);
    }

    pub fn drawTextOnBg(self: *Band, text: []const u8, x: f32, y: f32, color: Color) void {
        self.queueTextOp(.text, text, x, y, color, self.bg);
    }

    pub fn drawTextOnColor(self: *Band, text: []const u8, x: f32, y: f32, color: Color, bg: Color) void {
        self.queueTextOp(.text, text, x, y, color, bg);
    }

    pub fn drawIconText(self: *Band, text: []const u8, x: f32, y: f32, color: Color) void {
        self.queueTextOp(.icon, text, x, y, color, self.bg);
    }

    pub fn flush(self: *Band) void {
        defer {
            self.text_ops.deinit(self.shell.renderer.allocator);
            self.text_ops = .{};
        }
        renderer_band_phase_host.replayBandOps(self.shell.renderer, self.text_ops.items);
    }
};
