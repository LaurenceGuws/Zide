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
const WriteOutcome = enum {
    written,
    skipped_exists,
};

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
        .install_user_lua_meta => |cmd| return try installUserLuaMeta(allocator, cmd.force),
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
    const scope: lua_config_export.ExportScope = switch (command.scope) {
        .full => .full,
        .editor => .editor,
        .terminal => .terminal,
    };
    const rendered = try lua_config_export.renderStandaloneDefaultConfig(allocator, scope);
    defer allocator.free(rendered);

    switch (command.target) {
        .stdout => {
            try std.fs.File.stdout().writeAll(rendered);
        },
        .user => {
            const path = try lua_config_shared.userConfigDestinationPath(allocator);
            defer allocator.free(path);
            const init_outcome = try writeDefaultConfigFile(path, rendered, command.force);
            if (command.with_lua_meta) {
                try installUserLuaMeta(allocator, command.force);
            }
            switch (init_outcome) {
                .written => std.debug.print("wrote default config to {s}\n", .{path}),
                .skipped_exists => std.debug.print("kept existing default config at {s} (use --force to overwrite)\n", .{path}),
            }
        },
        .path => |path| {
            const outcome = try writeDefaultConfigFile(path, rendered, command.force);
            switch (outcome) {
                .written => std.debug.print("wrote default config to {s}\n", .{path}),
                .skipped_exists => std.debug.print("kept existing default config at {s} (use --force to overwrite)\n", .{path}),
            }
        },
    }
}

fn writeDefaultConfigFile(path: []const u8, bytes: []const u8, force: bool) !WriteOutcome {
    if (!force and lua_config_shared.fileExists(path)) return .skipped_exists;

    if (std.fs.path.dirname(path)) |dir_path| {
        if (std.fs.path.isAbsolute(dir_path)) {
            std.fs.makeDirAbsolute(dir_path) catch |err| switch (err) {
                error.PathAlreadyExists, error.FileNotFound => try makePathAbsolute(dir_path),
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
    return .written;
}

fn makePathAbsolute(dir_path: []const u8) !void {
    var dir = try std.fs.openDirAbsolute("/", .{});
    defer dir.close();
    const relative = std.mem.trimLeft(u8, dir_path, "/");
    if (relative.len == 0) return;
    try dir.makePath(relative);
}

fn installUserLuaMeta(allocator: std.mem.Allocator, force: bool) !void {
    const base_dir = try lua_config_shared.userConfigBaseDir(allocator);
    defer allocator.free(base_dir);

    const meta_src = (try lua_config_shared.findInstalledAssetPath(allocator, "lua/zide-meta.lua")) orelse return error.MissingLuaMeta;
    defer allocator.free(meta_src);

    const meta_bytes = try std.fs.cwd().readFileAlloc(allocator, meta_src, 2 * 1024 * 1024);
    defer allocator.free(meta_bytes);

    const meta_dir = try std.fs.path.join(allocator, &.{ base_dir, "lua" });
    defer allocator.free(meta_dir);
    const meta_dst = try std.fs.path.join(allocator, &.{ meta_dir, "zide-meta.lua" });
    defer allocator.free(meta_dst);

    const luarc_dst = try std.fs.path.join(allocator, &.{ base_dir, ".luarc.json" });
    defer allocator.free(luarc_dst);
    const luarc_bytes = try renderUserLuaRc(allocator);
    defer allocator.free(luarc_bytes);

    const meta_outcome = try writeDefaultConfigFile(meta_dst, meta_bytes, force);
    const luarc_outcome = try writeDefaultConfigFile(luarc_dst, luarc_bytes, force);

    if (meta_outcome == .skipped_exists and luarc_outcome == .skipped_exists) {
        std.debug.print("kept existing user LuaLS support in {s} (use --force to overwrite)\n", .{base_dir});
        return;
    }

    std.debug.print("installed user LuaLS support to {s}\n", .{base_dir});
}

fn renderUserLuaRc(allocator: std.mem.Allocator) ![]u8 {
    return std.fmt.allocPrint(
        allocator,
        \\{{
        \\  "$schema": "https://raw.githubusercontent.com/LuaLS/vscode-lua/master/setting/schema.json",
        \\  "runtime.version": "Lua 5.4",
        \\  "workspace.library": [
        \\    "{s}"
        \\  ],
        \\  "workspace.checkThirdParty": false,
        \\  "hint.enable": true,
        \\  "format.enable": true
        \\}}
        \\
    , .{"lua"});
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

test "write default config file skips existing file without force" {
    var tmp = std.testing.tmpDir(.{});
    defer tmp.cleanup();

    var path_buf: [std.fs.max_path_bytes]u8 = undefined;
    const base = try tmp.dir.realpath(".", &path_buf);
    const path = try std.fs.path.join(std.testing.allocator, &.{ base, "init.lua" });
    defer std.testing.allocator.free(path);

    try tmp.dir.writeFile(.{ .sub_path = "init.lua", .data = "original\n" });
    try std.testing.expectEqual(WriteOutcome.skipped_exists, try writeDefaultConfigFile(path, "new\n", false));

    const contents = try tmp.dir.readFileAlloc(std.testing.allocator, "init.lua", 1024);
    defer std.testing.allocator.free(contents);
    try std.testing.expectEqualStrings("original\n", contents);
}
