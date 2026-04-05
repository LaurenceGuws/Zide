const std = @import("std");
const mode_build = @import("mode_build.zig");

pub const AppMode = enum {
    ide,
    editor,
    terminal,
    font_sample,
};

pub const WriteDefaultConfigTarget = union(enum) {
    user,
    stdout,
    path: []u8,

    pub fn deinit(self: *@This(), allocator: std.mem.Allocator) void {
        switch (self.*) {
            .path => |path| allocator.free(path),
            else => {},
        }
        self.* = .user;
    }
};

pub const DefaultConfigScope = enum {
    full,
    editor,
    terminal,
};

pub const StartupCommand = union(enum) {
    run,
    macos_metal_live_smoke,
    macos_metal_text_diagnostic,
    macos_metal_terminal_diagnostic,
    write_default_config: struct {
        target: WriteDefaultConfigTarget,
        scope: DefaultConfigScope = .full,
        force: bool = false,
        with_lua_meta: bool = false,

        pub fn deinit(self: *@This(), allocator: std.mem.Allocator) void {
            self.target.deinit(allocator);
            self.scope = .full;
            self.force = false;
            self.with_lua_meta = false;
        }
    },
    install_user_lua_meta: struct {
        force: bool = false,
    },

    pub fn deinit(self: *@This(), allocator: std.mem.Allocator) void {
        switch (self.*) {
            .write_default_config => |*cmd| cmd.deinit(allocator),
            .install_user_lua_meta => |*cmd| cmd.force = false,
            .macos_metal_live_smoke => {},
            .macos_metal_text_diagnostic => {},
            .macos_metal_terminal_diagnostic => {},
            .run => {},
        }
        self.* = .run;
    }
};

pub fn parseStartupCommand(allocator: std.mem.Allocator) !StartupCommand {
    const args = try std.process.argsAlloc(allocator);
    defer std.process.argsFree(allocator, args);
    return try parseStartupCommandArgs(allocator, args[1..]);
}

fn parseStartupCommandArgs(allocator: std.mem.Allocator, args: []const []const u8) !StartupCommand {
    var command: StartupCommand = .run;
    errdefer command.deinit(allocator);

    var i: usize = 0;
    while (i < args.len) : (i += 1) {
        const arg = args[i];
        if (std.mem.eql(u8, arg, "--write-default-config")) {
            const target: WriteDefaultConfigTarget = if (i + 1 < args.len and !std.mem.startsWith(u8, args[i + 1], "-")) blk: {
                i += 1;
                break :blk .{ .path = try allocator.dupe(u8, args[i]) };
            } else .user;
            command.deinit(allocator);
            command = .{ .write_default_config = .{ .target = target } };
            continue;
        }
        if (std.mem.startsWith(u8, arg, "--write-default-config=")) {
            command.deinit(allocator);
            command = .{ .write_default_config = .{
                .target = .{ .path = try allocator.dupe(u8, arg["--write-default-config=".len..]) },
            } };
            continue;
        }
        if (std.mem.eql(u8, arg, "--install-user-lua-meta")) {
            command.deinit(allocator);
            command = .{ .install_user_lua_meta = .{} };
            continue;
        }
        if (std.mem.eql(u8, arg, "--macos-metal-live-smoke")) {
            command.deinit(allocator);
            command = .macos_metal_live_smoke;
            continue;
        }
        if (std.mem.eql(u8, arg, "--macos-metal-text-diagnostic")) {
            command.deinit(allocator);
            command = .macos_metal_text_diagnostic;
            continue;
        }
        if (std.mem.eql(u8, arg, "--macos-metal-terminal-diagnostic")) {
            command.deinit(allocator);
            command = .macos_metal_terminal_diagnostic;
            continue;
        }
        if (std.mem.eql(u8, arg, "--config-scope")) {
            const value = args[i + 1];
            if (i + 1 >= args.len) return error.MissingConfigScope;
            i += 1;
            switch (command) {
                .write_default_config => |*cmd| cmd.scope = parseDefaultConfigScope(value) orelse return error.InvalidConfigScope,
                else => {},
            }
            continue;
        }
        if (std.mem.startsWith(u8, arg, "--config-scope=")) {
            const value = arg["--config-scope=".len..];
            switch (command) {
                .write_default_config => |*cmd| cmd.scope = parseDefaultConfigScope(value) orelse return error.InvalidConfigScope,
                else => {},
            }
            continue;
        }
        if (std.mem.eql(u8, arg, "--stdout")) {
            switch (command) {
                .write_default_config => |*cmd| {
                    cmd.target.deinit(allocator);
                    cmd.target = .stdout;
                },
                else => {},
            }
            continue;
        }
        if (std.mem.eql(u8, arg, "--force")) {
            switch (command) {
                .write_default_config => |*cmd| cmd.force = true,
                .install_user_lua_meta => |*cmd| cmd.force = true,
                else => {},
            }
            continue;
        }
        if (std.mem.eql(u8, arg, "--with-lua-meta")) {
            switch (command) {
                .write_default_config => |*cmd| cmd.with_lua_meta = true,
                else => {},
            }
            continue;
        }
    }

    return command;
}

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
    const paths = parseStartupFilePaths(allocator) orelse return null;
    defer {
        var i: usize = 0;
        while (i < paths.len) : (i += 1) allocator.free(paths[i]);
        allocator.free(paths);
    }
    return allocator.dupe(u8, paths[0]) catch null;
}

pub fn parseStartupFilePaths(allocator: std.mem.Allocator) ?[][]u8 {
    if (comptime mode_build.focused_mode == .terminal) return null;

    const args = std.process.argsAlloc(allocator) catch return null;
    defer std.process.argsFree(allocator, args);

    var paths = std.ArrayList([]u8).empty;
    defer {
        if (paths.capacity > 0) {
            for (paths.items) |path| allocator.free(path);
            paths.deinit(allocator);
        }
    }

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
        if (std.mem.eql(u8, arg, "--write-default-config")) {
            if (i + 1 < args.len and !std.mem.startsWith(u8, args[i + 1], "-")) i += 1;
            continue;
        }
        if (std.mem.startsWith(u8, arg, "--write-default-config=")) continue;
        if (std.mem.eql(u8, arg, "--config-scope")) {
            if (i + 1 < args.len) i += 1;
            continue;
        }
        if (std.mem.startsWith(u8, arg, "--config-scope=")) continue;
        if (std.mem.eql(u8, arg, "--install-user-lua-meta")) continue;
        if (std.mem.eql(u8, arg, "--stdout") or std.mem.eql(u8, arg, "--force") or std.mem.eql(u8, arg, "--with-lua-meta")) continue;
        if (isStartupDirectoryFlagWithValue(arg)) {
            if (i + 1 < args.len) i += 1;
            continue;
        }
        if (isStartupDirectoryInlineFlag(arg)) continue;
        if (isLaunchOverrideFlagWithValue(arg)) {
            if (i + 1 < args.len) i += 1;
            continue;
        }
        if (isLaunchOverrideInlineFlag(arg) or std.mem.eql(u8, arg, "--close-on-child-exit")) continue;
        if (std.mem.startsWith(u8, arg, "-")) continue;
        const owned = allocator.dupe(u8, arg) catch return null;
        paths.append(allocator, owned) catch {
            allocator.free(owned);
            return null;
        };
    }

    if (paths.items.len == 0) return null;
    const owned = paths.toOwnedSlice(allocator) catch return null;
    return owned;
}

pub fn parseStartupDirectoryPath(allocator: std.mem.Allocator) ?[]u8 {
    if (comptime mode_build.focused_mode == .terminal) return null;

    const args = std.process.argsAlloc(allocator) catch return null;
    defer std.process.argsFree(allocator, args);

    var i: usize = 1;
    while (i < args.len) : (i += 1) {
        const arg = args[i];
        if (std.mem.eql(u8, arg, "--folder")) {
            if (i + 1 >= args.len) return null;
            return allocator.dupe(u8, args[i + 1]) catch null;
        }
        if (std.mem.startsWith(u8, arg, "--folder=")) {
            return allocator.dupe(u8, arg["--folder=".len..]) catch null;
        }
    }

    return null;
}

fn isStartupDirectoryFlagWithValue(arg: []const u8) bool {
    return std.mem.eql(u8, arg, "--folder");
}

fn isStartupDirectoryInlineFlag(arg: []const u8) bool {
    return std.mem.startsWith(u8, arg, "--folder=");
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

fn parseDefaultConfigScope(value: []const u8) ?DefaultConfigScope {
    if (std.mem.eql(u8, value, "full")) return .full;
    if (std.mem.eql(u8, value, "editor")) return .editor;
    if (std.mem.eql(u8, value, "terminal")) return .terminal;
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
    try std.testing.expect(isStartupDirectoryFlagWithValue("--folder"));
    try std.testing.expect(isStartupDirectoryInlineFlag("--folder=C:\\Users\\lggou\\repo"));
    try std.testing.expect(!isLaunchOverrideFlagWithValue("README.md"));
    try std.testing.expect(!isLaunchOverrideInlineFlag("--mode=editor"));
}

test "startup directory helpers recognize folder flags" {
    try std.testing.expect(isStartupDirectoryFlagWithValue("--folder"));
    try std.testing.expect(isStartupDirectoryInlineFlag("--folder=C:\\repo"));
    try std.testing.expect(!isStartupDirectoryFlagWithValue("--cwd"));
    try std.testing.expect(!isStartupDirectoryInlineFlag("README.md"));
}

test "parse startup command supports writing default config" {
    const argv = [_][]const u8{
        "--write-default-config",
        "--force",
    };
    var command = try parseStartupCommandArgs(std.testing.allocator, &argv);
    defer command.deinit(std.testing.allocator);
    switch (command) {
        .write_default_config => |cmd| {
            try std.testing.expectEqual(true, cmd.force);
            try std.testing.expectEqual(DefaultConfigScope.full, cmd.scope);
            try std.testing.expect(!cmd.with_lua_meta);
            try std.testing.expectEqual(@as(WriteDefaultConfigTarget, .user), cmd.target);
        },
        else => try std.testing.expect(false),
    }
}

test "parse startup command supports custom path and stdout target" {
    const argv = [_][]const u8{
        "--write-default-config=tmp/init.lua",
        "--stdout",
    };
    var command = try parseStartupCommandArgs(std.testing.allocator, &argv);
    defer command.deinit(std.testing.allocator);
    switch (command) {
        .write_default_config => |cmd| {
            try std.testing.expect(!cmd.force);
            try std.testing.expectEqual(DefaultConfigScope.full, cmd.scope);
            try std.testing.expect(!cmd.with_lua_meta);
            switch (cmd.target) {
                .stdout => {},
                else => try std.testing.expect(false),
            }
        },
        else => try std.testing.expect(false),
    }
}

test "parse startup command supports user lua meta install" {
    const argv = [_][]const u8{
        "--install-user-lua-meta",
        "--force",
    };
    var command = try parseStartupCommandArgs(std.testing.allocator, &argv);
    defer command.deinit(std.testing.allocator);
    switch (command) {
        .install_user_lua_meta => |cmd| try std.testing.expect(cmd.force),
        else => try std.testing.expect(false),
    }
}

test "parse startup command supports macos metal live smoke" {
    const argv = [_][]const u8{
        "--macos-metal-live-smoke",
    };
    var command = try parseStartupCommandArgs(std.testing.allocator, &argv);
    defer command.deinit(std.testing.allocator);
    switch (command) {
        .macos_metal_live_smoke => {},
        else => try std.testing.expect(false),
    }
}

test "parse startup command supports macos metal text diagnostic" {
    const argv = [_][]const u8{
        "--macos-metal-text-diagnostic",
    };
    var command = try parseStartupCommandArgs(std.testing.allocator, &argv);
    defer command.deinit(std.testing.allocator);
    switch (command) {
        .macos_metal_text_diagnostic => {},
        else => try std.testing.expect(false),
    }
}

test "parse startup command supports macos metal terminal diagnostic" {
    const argv = [_][]const u8{
        "--macos-metal-terminal-diagnostic",
    };
    var command = try parseStartupCommandArgs(std.testing.allocator, &argv);
    defer command.deinit(std.testing.allocator);
    switch (command) {
        .macos_metal_terminal_diagnostic => {},
        else => try std.testing.expect(false),
    }
}

test "parse startup command supports default config with lua meta" {
    const argv = [_][]const u8{
        "--write-default-config",
        "--with-lua-meta",
        "--force",
    };
    var command = try parseStartupCommandArgs(std.testing.allocator, &argv);
    defer command.deinit(std.testing.allocator);
    switch (command) {
        .write_default_config => |cmd| {
            try std.testing.expect(cmd.force);
            try std.testing.expectEqual(DefaultConfigScope.full, cmd.scope);
            try std.testing.expect(cmd.with_lua_meta);
            try std.testing.expectEqual(@as(WriteDefaultConfigTarget, .user), cmd.target);
        },
        else => try std.testing.expect(false),
    }
}

test "parse startup command supports config scope" {
    const argv = [_][]const u8{
        "--write-default-config",
        "--config-scope=terminal",
    };
    var command = try parseStartupCommandArgs(std.testing.allocator, &argv);
    defer command.deinit(std.testing.allocator);
    switch (command) {
        .write_default_config => |cmd| try std.testing.expectEqual(DefaultConfigScope.terminal, cmd.scope),
        else => try std.testing.expect(false),
    }
}
