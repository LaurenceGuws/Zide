const std = @import("std");
const app_shell = @import("../../app_shell.zig");
const app_logger = @import("../../app_logger.zig");
const present_trace_runtime = @import("present_trace_runtime.zig");
const renderer_text_phase_group_host = @import("renderer_text_phase_group_host.zig");
const renderer_surface_host = @import("renderer_surface_host.zig");

const Shell = app_shell.Shell;
const Color = app_shell.Color;

pub const Band = struct {
    const TextKind = renderer_text_phase_group_host.TextKind;
    const TextOp = renderer_text_phase_group_host.ReplayOp;

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
        if (w <= 0 or h <= 0) return;
        present_trace_runtime.setEditorSurfaceSolidFamily(self.shell.renderer, .chrome_band);
        defer present_trace_runtime.clearEditorSurfaceSolidFamily(self.shell.renderer);
        const recorded = renderer_surface_host.recordSolidSurfaceFromLogicalRect(
            self.shell.renderer,
            @floatFromInt(x),
            @floatFromInt(y),
            @floatFromInt(w),
            @floatFromInt(h),
            color.toRgba(),
        );
        if (recorded) present_trace_runtime.noteFrameFamilyTouch(self.shell.renderer, .chrome_band);
    }

    pub fn drawRectOutline(self: *Band, x: i32, y: i32, w: i32, h: i32, color: Color) void {
        if (w <= 0 or h <= 0) return;
        present_trace_runtime.setEditorSurfaceSolidFamily(self.shell.renderer, .chrome_band);
        defer present_trace_runtime.clearEditorSurfaceSolidFamily(self.shell.renderer);
        const thick: i32 = 1;
        var recorded_any = false;
        recorded_any = renderer_surface_host.recordSolidSurfaceFromLogicalRect(
            self.shell.renderer,
            @floatFromInt(x),
            @floatFromInt(y),
            @floatFromInt(w),
            @floatFromInt(thick),
            color.toRgba(),
        ) or recorded_any;
        recorded_any = renderer_surface_host.recordSolidSurfaceFromLogicalRect(
            self.shell.renderer,
            @floatFromInt(x),
            @floatFromInt(y + h - thick),
            @floatFromInt(w),
            @floatFromInt(thick),
            color.toRgba(),
        ) or recorded_any;
        recorded_any = renderer_surface_host.recordSolidSurfaceFromLogicalRect(
            self.shell.renderer,
            @floatFromInt(x),
            @floatFromInt(y),
            @floatFromInt(thick),
            @floatFromInt(h),
            color.toRgba(),
        ) or recorded_any;
        recorded_any = renderer_surface_host.recordSolidSurfaceFromLogicalRect(
            self.shell.renderer,
            @floatFromInt(x + w - thick),
            @floatFromInt(y),
            @floatFromInt(thick),
            @floatFromInt(h),
            color.toRgba(),
        ) or recorded_any;
        if (recorded_any) present_trace_runtime.noteFrameFamilyTouch(self.shell.renderer, .chrome_band);
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
        present_trace_runtime.noteFrameFamilyTouch(self.shell.renderer, .chrome_band);
    }

    fn queueSizedTextOp(self: *Band, text: []const u8, x: f32, y: f32, size: f32, color: Color) void {
        self.text_ops.append(self.shell.renderer.allocator, .{
            .kind = .sized_text,
            .text = text,
            .x = x,
            .y = y,
            .color = color,
            .bg = self.bg,
            .size = size,
        }) catch |err| {
            const log = app_logger.logger("renderer.chrome.band");
            log.logf(.warning, "band sized text op append failed err={s}", .{@errorName(err)});
            return;
        };
        present_trace_runtime.noteFrameFamilyTouch(self.shell.renderer, .chrome_band);
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

    pub fn drawTextSized(self: *Band, text: []const u8, x: f32, y: f32, size: f32, color: Color) void {
        self.queueSizedTextOp(text, x, y, size, color);
    }

    pub fn flush(self: *Band) void {
        defer {
            self.text_ops.deinit(self.shell.renderer.allocator);
            self.text_ops = .{};
        }
        renderer_text_phase_group_host.replayOps(self.shell.renderer, .chrome_band, self.text_ops.items);
    }
};
