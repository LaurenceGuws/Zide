const app_shell = @import("../../app_shell.zig");
const renderer_band_phase_host = @import("renderer_band_phase_host.zig");
const renderer_surface_host = @import("renderer_surface_host.zig");
const renderer_text_host = @import("renderer_text_host.zig");

const Shell = app_shell.Shell;
const Color = app_shell.Color;

pub const Band = struct {
    const max_text_ops = 128;
    const TextKind = enum {
        text,
        icon,
    };
    const TextOp = struct {
        kind: TextKind,
        text: []const u8,
        x: f32,
        y: f32,
        color: Color,
        bg: Color,
    };

    shell: *Shell,
    bg: Color,
    text_ops: [max_text_ops]TextOp = undefined,
    text_ops_len: usize = 0,

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
        if (self.text_ops_len >= max_text_ops) {
            switch (kind) {
                .text => renderer_text_host.drawTextOnBg(self.shell.renderer, text, x, y, color, bg),
                .icon => renderer_text_host.drawIconTextOnBg(self.shell.renderer, text, x, y, color, bg),
            }
            return;
        }
        self.text_ops[self.text_ops_len] = .{
            .kind = kind,
            .text = text,
            .x = x,
            .y = y,
            .color = color,
            .bg = bg,
        };
        self.text_ops_len += 1;
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
        renderer_band_phase_host.beginBandCommandGroup(self.shell.renderer);
        defer renderer_band_phase_host.endBandCommandGroup(self.shell.renderer);
        for (self.text_ops[0..self.text_ops_len]) |op| {
            switch (op.kind) {
                .text => renderer_text_host.drawTextOnBg(self.shell.renderer, op.text, op.x, op.y, op.color, op.bg),
                .icon => renderer_text_host.drawIconTextOnBg(self.shell.renderer, op.text, op.x, op.y, op.color, op.bg),
            }
        }
        self.text_ops_len = 0;
    }
};
