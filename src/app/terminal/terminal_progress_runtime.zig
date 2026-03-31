const std = @import("std");
const app_shell = @import("../../app_shell.zig");
const terminal_runtime = @import("../../terminal/core/terminal_runtime.zig");

const Shell = app_shell.Shell;
const Color = app_shell.Color;
const ProgressState = terminal_runtime.ProgressState;

pub fn drawActiveTabProgress(
    shell: *Shell,
    x: f32,
    y: f32,
    width: f32,
    activity: terminal_runtime.ActivityMetadata,
) void {
    if (width <= 0) return;
    if (!activity.progress.active()) return;

    const ui_scale = shell.uiScaleFactor();
    const bar_h = @max(@as(f32, 2), 2 * ui_scale);
    const bg = alphaScale(shell.theme().ui_text_inactive, 0.25);
    shell.drawRect(@intFromFloat(x), @intFromFloat(y), @intFromFloat(width), @intFromFloat(bar_h), bg);

    const fill_color = switch (activity.progress.state) {
        .@"error" => alphaScale(shell.theme().error_token, 0.85),
        .pause => alphaScale(shell.theme().ui_modified, 0.8),
        else => alphaScale(shell.theme().ui_accent, 0.85),
    };

    const fill_w = progressFillWidth(width, activity.progress.state, activity.progress.value);
    if (fill_w <= 0) return;
    const fill_x = progressFillX(x, width, activity.progress.state, fill_w);
    shell.drawRect(@intFromFloat(fill_x), @intFromFloat(y), @intFromFloat(fill_w), @intFromFloat(bar_h), fill_color);
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
