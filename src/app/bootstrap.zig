const std = @import("std");
const mode_build = @import("mode_build.zig");

pub const AppMode = enum {
    ide,
    editor,
    terminal,
    font_sample,
};

pub fn parseAppMode(allocator: std.mem.Allocator) AppMode {
    if (comptime mode_build.focused_mode) |mode| return mode;

    const args = std.process.argsAlloc(allocator) catch return .ide;
    defer std.process.argsFree(allocator, args);

    var i: usize = 1;
    while (i < args.len) : (i += 1) {
        const arg = args[i];
        if (std.mem.eql(u8, arg, "--terminal") or std.mem.eql(u8, arg, "terminal")) {
            return .terminal;
        }
        if (std.mem.eql(u8, arg, "--editor") or std.mem.eql(u8, arg, "editor")) {
            return .editor;
        }
        if (std.mem.eql(u8, arg, "--ide") or std.mem.eql(u8, arg, "ide")) {
            return .ide;
        }
        if (std.mem.startsWith(u8, arg, "--mode=")) {
            const value = arg["--mode=".len..];
            if (modeFromArg(value)) |mode| return mode;
        } else if (std.mem.eql(u8, arg, "--mode") and i + 1 < args.len) {
            i += 1;
            if (modeFromArg(args[i])) |mode| return mode;
        }
    }

    return .ide;
}

pub fn parseStartupFilePath(allocator: std.mem.Allocator) ?[]u8 {
    if (comptime mode_build.focused_mode == .terminal) return null;

    const args = std.process.argsAlloc(allocator) catch return null;
    defer std.process.argsFree(allocator, args);

    var i: usize = 1;
    while (i < args.len) : (i += 1) {
        const arg = args[i];
        if (std.mem.eql(u8, arg, "--terminal") or std.mem.eql(u8, arg, "terminal") or
            std.mem.eql(u8, arg, "--editor") or std.mem.eql(u8, arg, "editor") or
            std.mem.eql(u8, arg, "--ide") or std.mem.eql(u8, arg, "ide"))
        {
            continue;
        }
        if (std.mem.startsWith(u8, arg, "--mode=")) continue;
        if (std.mem.eql(u8, arg, "--mode")) {
            if (i + 1 < args.len) i += 1;
            continue;
        }
        if (isLaunchOverrideFlagWithValue(arg)) {
            if (i + 1 < args.len) i += 1;
            continue;
        }
        if (isLaunchOverrideInlineFlag(arg) or std.mem.eql(u8, arg, "--close-on-child-exit")) continue;
        if (std.mem.startsWith(u8, arg, "-")) continue;
        return allocator.dupe(u8, arg) catch null;
    }

    return null;
}

fn isLaunchOverrideFlagWithValue(arg: []const u8) bool {
    return std.mem.eql(u8, arg, "--rows") or
        std.mem.eql(u8, arg, "--cols") or
        std.mem.eql(u8, arg, "--cwd") or
        std.mem.eql(u8, arg, "--shell") or
        std.mem.eql(u8, arg, "--command");
}

fn isLaunchOverrideInlineFlag(arg: []const u8) bool {
    return std.mem.startsWith(u8, arg, "--rows=") or
        std.mem.startsWith(u8, arg, "--cols=") or
        std.mem.startsWith(u8, arg, "--cwd=") or
        std.mem.startsWith(u8, arg, "--shell=") or
        std.mem.startsWith(u8, arg, "--command=");
}

pub fn modeFromArg(value: []const u8) ?AppMode {
    if (std.mem.eql(u8, value, "terminal")) return .terminal;
    if (std.mem.eql(u8, value, "editor")) return .editor;
    if (std.mem.eql(u8, value, "ide")) return .ide;
    if (std.mem.eql(u8, value, "font") or std.mem.eql(u8, value, "fonts") or std.mem.eql(u8, value, "font-sample")) return .font_sample;
    return null;
}

pub fn parseEnvU64(env_key: [:0]const u8, default_value: u64) u64 {
    const raw = std.c.getenv(env_key) orelse return default_value;
    const slice = std.mem.sliceTo(raw, 0);
    if (slice.len == 0) return default_value;
    return std.fmt.parseInt(u64, slice, 10) catch default_value;
}

pub fn parseEnvI32(env_key: [:0]const u8, default_value: i32) i32 {
    const raw = std.c.getenv(env_key) orelse return default_value;
    const slice = std.mem.sliceTo(raw, 0);
    if (slice.len == 0) return default_value;
    const parsed = std.fmt.parseInt(i32, slice, 10) catch return default_value;
    return if (parsed > 0) parsed else default_value;
}

pub fn parseEnvBool(env_key: [:0]const u8) ?bool {
    const raw = std.c.getenv(env_key) orelse return null;
    const slice = std.mem.sliceTo(raw, 0);
    if (slice.len == 0) return null;
    if (std.mem.eql(u8, slice, "1") or std.ascii.eqlIgnoreCase(slice, "true") or std.ascii.eqlIgnoreCase(slice, "yes") or std.ascii.eqlIgnoreCase(slice, "on")) return true;
    if (std.mem.eql(u8, slice, "0") or std.ascii.eqlIgnoreCase(slice, "false") or std.ascii.eqlIgnoreCase(slice, "no") or std.ascii.eqlIgnoreCase(slice, "off")) return false;
    return null;
}

pub fn envSlice(env_key: [:0]const u8) ?[]const u8 {
    const raw = std.c.getenv(env_key) orelse return null;
    const slice = std.mem.sliceTo(raw, 0);
    if (slice.len == 0) return null;
    return slice;
}

test "modeFromArg maps supported values" {
    try std.testing.expectEqual(@as(?AppMode, .terminal), modeFromArg("terminal"));
    try std.testing.expectEqual(@as(?AppMode, .editor), modeFromArg("editor"));
    try std.testing.expectEqual(@as(?AppMode, .ide), modeFromArg("ide"));
    try std.testing.expectEqual(@as(?AppMode, .font_sample), modeFromArg("font-sample"));
    try std.testing.expectEqual(@as(?AppMode, null), modeFromArg("wat"));
}

test "launch override helpers recognize supported flags" {
    try std.testing.expect(isLaunchOverrideFlagWithValue("--cwd"));
    try std.testing.expect(isLaunchOverrideFlagWithValue("--shell"));
    try std.testing.expect(isLaunchOverrideFlagWithValue("--command"));
    try std.testing.expect(isLaunchOverrideInlineFlag("--shell=C:\\Program Files\\PowerShell\\7\\pwsh.exe"));
    try std.testing.expect(isLaunchOverrideInlineFlag("--cwd=C:\\Users\\lggou"));
    try std.testing.expect(!isLaunchOverrideFlagWithValue("README.md"));
    try std.testing.expect(!isLaunchOverrideInlineFlag("--mode=editor"));
}
