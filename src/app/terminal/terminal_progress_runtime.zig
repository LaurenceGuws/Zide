const std = @import("std");
const app_shell = @import("../../app_shell.zig");
const terminal_composition_host = @import("terminal_composition_host.zig");
const host_types = @import("../../terminal/core/session/host_types.zig");

const Shell = app_shell.Shell;
const Color = app_shell.Color;
const TerminalBand = terminal_composition_host.TerminalBand;
const ProgressMetadata = host_types.ProgressMetadata;
const ProgressState = host_types.ProgressState;

pub fn drawActiveTabProgress(
    shell: *Shell,
    x: f32,
    y: f32,
    width: f32,
    progress: ProgressMetadata,
) void {
    if (width <= 0) return;
    if (!progress.active()) return;

    const ui_scale = shell.uiScaleFactor();
    const bar_h = @max(@as(f32, 2), 2 * ui_scale);
    const bg = alphaScale(shell.theme().ui_text_inactive, 0.25);
    var band = TerminalBand.init(shell, bg);
    defer band.flush();
    band.fillRect(@intFromFloat(x), @intFromFloat(y), @intFromFloat(width), @intFromFloat(bar_h), bg);

    const fill_color = switch (progress.state) {
        .@"error" => alphaScale(shell.theme().error_token, 0.85),
        .pause => alphaScale(shell.theme().ui_modified, 0.8),
        else => alphaScale(shell.theme().ui_accent, 0.85),
    };

    const fill_w = progressFillWidth(width, progress.state, progress.value);
    if (fill_w <= 0) return;
    const fill_x = progressFillX(x, width, progress.state, fill_w);
    band.fillRect(@intFromFloat(fill_x), @intFromFloat(y), @intFromFloat(fill_w), @intFromFloat(bar_h), fill_color);
}

fn progressFillWidth(width: f32, state: ProgressState, value: ?u8) f32 {
    return switch (state) {
        .none => 0,
        .indeterminate => @max(8, width * 0.3),
        .set, .@"error", .pause => blk: {
            const percent = @as(f32, @floatFromInt(value orelse 0)) / 100.0;
            break :blk std.math.clamp(width * percent, 0, width);
        },
    };
}

fn progressFillX(x: f32, width: f32, state: ProgressState, fill_w: f32) f32 {
    return switch (state) {
        .indeterminate => x + @max(0, (width - fill_w) * 0.5),
        else => x,
    };
}

fn alphaScale(color: Color, scale: f32) Color {
    var out = color;
    out.a = @intFromFloat(std.math.clamp(@as(f32, @floatFromInt(color.a)) * scale, 0, 255));
    return out;
}
