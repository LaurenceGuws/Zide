const std = @import("std");
const app_bootstrap = @import("bootstrap.zig");
const mode_build = @import("mode_build.zig");
const app_runner = @import("runner.zig");
const app_signals = @import("signals.zig");
const app_state_mod = @import("app_state.zig");
const terminal_cli = @import("terminal_cli.zig");
const lua_config_shared = @import("../config/lua_config_shared.zig");
const lua_config_export = @import("../config/lua_config_export.zig");

pub const AppMode = app_state_mod.AppMode;
const AppState = app_state_mod.AppState;

pub fn runWithMode(allocator: std.mem.Allocator, app_mode: AppMode) !void {
    const effective_mode = mode_build.effectiveMode(app_mode);
    var app = try AppState.init(allocator, effective_mode);
    defer app.deinit();

    try app.run();
}

pub fn runFromArgs(allocator: std.mem.Allocator) !void {
    var startup_command = try app_bootstrap.parseStartupCommand(allocator);
    defer startup_command.deinit(allocator);
    switch (startup_command) {
        .write_default_config => |cmd| return try writeDefaultConfig(allocator, cmd),
        .run => {},
    }

    try terminal_cli.applyKnownOverridesFromProcessArgs(allocator);
    try applyStartupDirectoryFromArgs(allocator);
    const app_mode = app_bootstrap.parseAppMode(allocator);
    try runWithMode(allocator, app_mode);
}

fn writeDefaultConfig(
    allocator: std.mem.Allocator,
    command: std.meta.TagPayload(app_bootstrap.StartupCommand, .write_default_config),
) !void {
    const rendered = try lua_config_export.renderStandaloneDefaultConfig(allocator);
    defer allocator.free(rendered);

    switch (command.target) {
        .stdout => {
            try std.fs.File.stdout().writeAll(rendered);
        },
        .user => {
            const path = try lua_config_shared.userConfigDestinationPath(allocator);
            defer allocator.free(path);
            try writeDefaultConfigFile(path, rendered, command.force);
            std.debug.print("wrote default config to {s}\n", .{path});
        },
        .path => |path| {
            try writeDefaultConfigFile(path, rendered, command.force);
            std.debug.print("wrote default config to {s}\n", .{path});
        },
    }
}

fn writeDefaultConfigFile(path: []const u8, bytes: []const u8, force: bool) !void {
    if (!force and lua_config_shared.fileExists(path)) return error.PathAlreadyExists;

    if (std.fs.path.dirname(path)) |dir_path| {
        if (std.fs.path.isAbsolute(dir_path)) {
            std.fs.makeDirAbsolute(dir_path) catch |err| switch (err) {
                error.PathAlreadyExists => {},
                else => return err,
            };
        } else {
            try std.fs.cwd().makePath(dir_path);
        }
    }
    if (std.fs.path.isAbsolute(path)) {
        var file = try std.fs.createFileAbsolute(path, .{ .truncate = true });
        defer file.close();
        try file.writeAll(bytes);
    } else {
        try std.fs.cwd().writeFile(.{ .sub_path = path, .data = bytes });
    }
}

fn applyStartupDirectoryFromArgs(allocator: std.mem.Allocator) !void {
    const startup_directory = app_bootstrap.parseStartupDirectoryPath(allocator) orelse return;
    defer allocator.free(startup_directory);

    const normalized = try std.fs.cwd().realpathAlloc(allocator, startup_directory);
    defer allocator.free(normalized);

    var dir = try std.fs.openDirAbsolute(normalized, .{});
    defer dir.close();
    try dir.setAsCwd();
}

pub fn runMain() !void {
    try app_runner.runWithGpa(struct {
        fn call(allocator: std.mem.Allocator) !void {
            app_signals.install();
            try runFromArgs(allocator);
        }
    }.call);
}
