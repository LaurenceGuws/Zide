const std = @import("std");
const app_bootstrap = @import("../bootstrap.zig");
const app_logger = @import("../../app_logger.zig");
const shared_types = @import("../../types/mod.zig");

pub fn initState(allocator: std.mem.Allocator) !@import("../app_state_types.zig").EditorLiveSmokeState {
    const scenario = app_bootstrap.envSlice("ZIDE_EDITOR_LIVE_SMOKE_SCENARIO") orelse
        return .{};
    const text = app_bootstrap.envSlice("ZIDE_EDITOR_LIVE_SMOKE_TEXT") orelse "x";
    const inject_frame = app_bootstrap.parseEnvU64("ZIDE_EDITOR_LIVE_SMOKE_INJECT_FRAME", 18);
    const capture_start_frame = app_bootstrap.parseEnvU64("ZIDE_EDITOR_LIVE_SMOKE_CAPTURE_START", if (inject_frame > 0) inject_frame - 1 else 0);
    const capture_end_frame = app_bootstrap.parseEnvU64("ZIDE_EDITOR_LIVE_SMOKE_CAPTURE_END", inject_frame + 3);
    const close_after_frame = app_bootstrap.parseEnvU64("ZIDE_EDITOR_LIVE_SMOKE_CLOSE_FRAME", capture_end_frame + 1);
    const output_dir_raw = app_bootstrap.envSlice("ZIDE_EDITOR_LIVE_SMOKE_OUTPUT_DIR") orelse ".tmp/editor-live-smoke";

    return .{
        .enabled = true,
        .scenario = try allocator.dupe(u8, scenario),
        .inject_text = try allocator.dupe(u8, text),
        .inject_frame = inject_frame,
        .capture_start_frame = capture_start_frame,
        .capture_end_frame = capture_end_frame,
        .close_after_frame = close_after_frame,
        .output_dir = try allocator.dupe(u8, output_dir_raw),
        .injected = false,
    };
}

pub fn deinitState(allocator: std.mem.Allocator, state: *@import("../app_state_types.zig").EditorLiveSmokeState) void {
    if (state.scenario) |value| allocator.free(value);
    if (state.inject_text) |value| allocator.free(value);
    if (state.output_dir) |value| allocator.free(value);
    state.* = .{};
}

pub fn appendInjectedText(state: anytype, input_batch: *shared_types.input.InputBatch) void {
    if (!state.editor_live_smoke.enabled) return;
    if (state.editor_live_smoke.injected) return;
    if (state.frame_id != state.editor_live_smoke.inject_frame) return;
    const text = state.editor_live_smoke.inject_text orelse return;
    const codepoint = firstCodepoint(text) orelse return;

    var utf8: [4]u8 = .{ 0, 0, 0, 0 };
    const utf8_len: u8 = @intCast(std.unicode.utf8Encode(codepoint, &utf8) catch return);
    input_batch.append(.{ .text = .{
        .codepoint = codepoint,
        .utf8_len = utf8_len,
        .utf8 = utf8,
        .text_is_composed = false,
    } }) catch |err| {
        app_logger.logger("editor.live_smoke").logf(.warning, "inject_text append failed frame={d} err={s}", .{ state.frame_id, @errorName(err) });
        return;
    };
    state.editor_live_smoke.injected = true;
    state.needs_redraw = true;
    app_logger.logger("editor.live_smoke").logf(.info, "inject_text frame={d} scenario={s} text={s}", .{
        state.frame_id,
        state.editor_live_smoke.scenario.?,
        text,
    });
}

pub fn shouldCaptureFrame(state: anytype) bool {
    if (!state.editor_live_smoke.enabled) return false;
    return state.frame_id >= state.editor_live_smoke.capture_start_frame and
        state.frame_id <= state.editor_live_smoke.capture_end_frame;
}

pub fn capturePath(state: anytype, allocator: std.mem.Allocator) !?[]u8 {
    if (!shouldCaptureFrame(state)) return null;
    const output_dir = state.editor_live_smoke.output_dir orelse return null;
    try std.fs.cwd().makePath(output_dir);
    return try std.fmt.allocPrint(allocator, "{s}/{s}-frame-{d}.ppm", .{
        output_dir,
        state.editor_live_smoke.scenario.?,
        state.frame_id,
    });
}

pub fn keepDrivingFrames(state: anytype) bool {
    if (!state.editor_live_smoke.enabled) return false;
    return state.frame_id < state.editor_live_smoke.close_after_frame;
}

pub fn shouldClose(state: anytype) bool {
    if (!state.editor_live_smoke.enabled) return false;
    return state.frame_id >= state.editor_live_smoke.close_after_frame;
}

fn firstCodepoint(text: []const u8) ?u21 {
    var view = std.unicode.Utf8View.init(text) catch return null;
    var it = view.iterator();
    return it.nextCodepoint();
}
