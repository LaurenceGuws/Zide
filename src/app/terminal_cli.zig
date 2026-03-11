const std = @import("std");
const c = @cImport({
    @cInclude("stdlib.h");
});

pub const Config = struct {
    cwd: ?[]u8 = null,
    shell: ?[]u8 = null,
    command: ?[]u8 = null,
    rows: ?u16 = null,
    cols: ?u16 = null,
    close_on_child_exit: bool = false,
    help: bool = false,

    pub fn deinit(self: *Config, allocator: std.mem.Allocator) void {
        if (self.cwd) |value| allocator.free(value);
        if (self.shell) |value| allocator.free(value);
        if (self.command) |value| allocator.free(value);
        self.* = .{};
    }
};

pub fn parseArgs(allocator: std.mem.Allocator) !Config {
    var args = std.process.args();
    _ = args.next();
    return parseIterator(allocator, &args);
}

fn parseIterator(allocator: std.mem.Allocator, args: anytype) !Config {
    var config: Config = .{};
    while (args.next()) |arg| {
        if (std.mem.eql(u8, arg, "--help") or std.mem.eql(u8, arg, "-h")) {
            config.help = true;
            continue;
        }
        if (std.mem.eql(u8, arg, "--close-on-child-exit")) {
            config.close_on_child_exit = true;
            continue;
        }
        if (std.mem.eql(u8, arg, "--rows")) {
            const value = args.next() orelse return error.MissingRows;
            config.rows = try parseDimension(value);
            continue;
        }
        if (std.mem.startsWith(u8, arg, "--rows=")) {
            config.rows = try parseDimension(arg["--rows=".len..]);
            continue;
        }
        if (std.mem.eql(u8, arg, "--cols")) {
            const value = args.next() orelse return error.MissingCols;
            config.cols = try parseDimension(value);
            continue;
        }
        if (std.mem.startsWith(u8, arg, "--cols=")) {
            config.cols = try parseDimension(arg["--cols=".len..]);
            continue;
        }
        if (std.mem.eql(u8, arg, "--cwd")) {
            const value = args.next() orelse return error.MissingCwd;
            config.cwd = try allocator.dupe(u8, value);
            continue;
        }
        if (std.mem.startsWith(u8, arg, "--cwd=")) {
            config.cwd = try allocator.dupe(u8, arg["--cwd=".len..]);
            continue;
        }
        if (std.mem.eql(u8, arg, "--shell")) {
            const value = args.next() orelse return error.MissingShell;
            config.shell = try allocator.dupe(u8, value);
            continue;
        }
        if (std.mem.startsWith(u8, arg, "--shell=")) {
            config.shell = try allocator.dupe(u8, arg["--shell=".len..]);
            continue;
        }
        if (std.mem.eql(u8, arg, "--command")) {
            const value = args.next() orelse return error.MissingCommand;
            config.command = try allocator.dupe(u8, value);
            continue;
        }
        if (std.mem.startsWith(u8, arg, "--command=")) {
            config.command = try allocator.dupe(u8, arg["--command=".len..]);
            continue;
        }
        return error.UnknownArgument;
    }
    return config;
}

fn SliceArgsIterator(comptime T: type) type {
    return struct {
        items: []const T,
        index: usize = 0,

        fn next(self: *@This()) ?T {
            if (self.index >= self.items.len) return null;
            const value = self.items[self.index];
            self.index += 1;
            return value;
        }
    };
}

fn parseDimension(value: []const u8) !u16 {
    const parsed = try std.fmt.parseUnsigned(u16, value, 10);
    if (parsed == 0) return error.InvalidDimension;
    return parsed;
}

pub fn printHelp(writer: anytype) !void {
    try writer.writeAll(
        \\Usage: zide-terminal [options]
        \\
        \\Options:
        \\  --rows <n>           Override terminal row count for backend repro.
        \\  --cols <n>           Override terminal column count for backend repro.
        \\  --cwd <path>         Start the terminal command in this working directory.
        \\  --shell <path>       Override the shell/program used for the PTY child.
        \\  --command <string>   Run a command through the PTY shell for repro/testing.
        \\  --close-on-child-exit
        \\                       Exit terminal mode when the PTY child exits.
        \\  -h, --help           Show this help and exit.
        \\
        \\Examples:
        \\  zide-terminal --rows 40 --cols 120 --cwd /tmp --command "nvim -u NONE -N file.zig" --close-on-child-exit
        \\  zide-terminal --shell /bin/zsh
        \\
    );
}

pub fn applyEnv(config: *const Config, allocator: std.mem.Allocator) !void {
    var rows_buf: [16]u8 = undefined;
    var cols_buf: [16]u8 = undefined;
    try applyEnvOverride(allocator, "ZIDE_LAUNCH_CWD", config.cwd);
    try applyEnvOverride(allocator, "ZIDE_TERMINAL_SHELL", config.shell);
    try applyEnvOverride(allocator, "ZIDE_TERMINAL_COMMAND", config.command);
    try applyEnvOverride(
        allocator,
        "ZIDE_TERMINAL_ROWS",
        if (config.rows) |rows| try std.fmt.bufPrint(&rows_buf, "{d}", .{rows}) else null,
    );
    try applyEnvOverride(
        allocator,
        "ZIDE_TERMINAL_COLS",
        if (config.cols) |cols| try std.fmt.bufPrint(&cols_buf, "{d}", .{cols}) else null,
    );
    try applyEnvOverride(
        allocator,
        "ZIDE_TERMINAL_CLOSE_ON_CHILD_EXIT",
        if (config.close_on_child_exit) "1" else null,
    );
}

fn applyEnvOverride(allocator: std.mem.Allocator, name: []const u8, value: ?[]const u8) !void {
    const z_name = try allocator.dupeZ(u8, name);
    defer allocator.free(z_name);
    if (value) |slice| {
        const z_value = try allocator.dupeZ(u8, slice);
        defer allocator.free(z_value);
        _ = c.setenv(z_name.ptr, z_value.ptr, 1);
    } else {
        _ = c.unsetenv(z_name.ptr);
    }
}

test "parse terminal cli args" {
    const argv = [_][]const u8{
        "--rows=40",
        "--cols",
        "120",
        "--cwd",
        "/tmp",
        "--shell=/bin/zsh",
        "--command",
        "nvim -u NONE test.zig",
        "--close-on-child-exit",
    };
    var args = SliceArgsIterator([]const u8){ .items = &argv };
    var config = try parseIterator(std.testing.allocator, &args);
    defer config.deinit(std.testing.allocator);
    try std.testing.expectEqual(@as(?u16, 40), config.rows);
    try std.testing.expectEqual(@as(?u16, 120), config.cols);
    try std.testing.expectEqualStrings("/tmp", config.cwd.?);
    try std.testing.expectEqualStrings("/bin/zsh", config.shell.?);
    try std.testing.expectEqualStrings("nvim -u NONE test.zig", config.command.?);
    try std.testing.expect(config.close_on_child_exit);
}
