const std = @import("std");
const zlua = @import("zlua");
const iface = @import("./lua_config_iface.zig");
const ziglua_parse = @import("./lua_config_ziglua_parse.zig");
const lua_shared = @import("./lua_config_shared.zig");

comptime {
    _ = zlua.Lua;
}

pub const LuaConfigError = iface.LuaConfigError;
pub const Config = iface.Config;
pub const FontHinting = iface.FontHinting;
pub const GlyphOverflowPolicy = iface.GlyphOverflowPolicy;
pub const TerminalBlinkStyle = iface.TerminalBlinkStyle;
pub const TerminalDisableLigaturesStrategy = iface.TerminalDisableLigaturesStrategy;
pub const TerminalWindowChromeMode = iface.TerminalWindowChromeMode;
pub const TabBarWidthMode = iface.TabBarWidthMode;
pub const ThemeConfig = iface.ThemeConfig;

fn resolveNamedImportedThemePath(allocator: std.mem.Allocator, name: []const u8) LuaConfigError![]u8 {
    const direct = std.fmt.allocPrint(allocator, "assets/themes/{s}.lua", .{name}) catch return LuaConfigError.OutOfMemory;
    if (lua_shared.fileExists(direct)) return direct;
    allocator.free(direct);

    const generated = std.fmt.allocPrint(allocator, "assets/themes/generated/{s}.overlay.lua", .{name}) catch return LuaConfigError.OutOfMemory;
    if (lua_shared.fileExists(generated)) return generated;
    allocator.free(generated);

    return LuaConfigError.InvalidConfig;
}

fn loadConfigFromFileZiglua(allocator: std.mem.Allocator, path: []const u8, imported_theme_override: ?[]const u8) LuaConfigError!Config {
    const lua = zlua.Lua.init(allocator) catch return LuaConfigError.LuaInitFailed;
    defer lua.deinit();
    lua.openLibs();

    const zpath = allocator.dupeZ(u8, path) catch return LuaConfigError.OutOfMemory;
    defer allocator.free(zpath);

    switch (zlua.lang) {
        .lua51, .luajit => lua.loadFile(zpath) catch return LuaConfigError.LuaLoadFailed,
        else => lua.loadFile(zpath, .binary_text) catch return LuaConfigError.LuaLoadFailed,
    }
    lua.protectedCall(.{ .args = 0, .results = 1 }) catch return LuaConfigError.LuaRunFailed;
    var parsed = try ziglua_parse.parseConfigFromLuaState(allocator, @ptrCast(lua));
    errdefer lua_shared.freeConfig(allocator, &parsed);

    const selected_theme_name = imported_theme_override orelse parsed.editor_imported_theme_name;
    if (selected_theme_name) |theme_name| {
        const theme_path = try resolveNamedImportedThemePath(allocator, theme_name);
        defer allocator.free(theme_path);

        var imported = try loadConfigFromFileZiglua(allocator, theme_path, null);
        errdefer lua_shared.freeConfig(allocator, &imported);
        if (imported.editor_imported_theme_name) |old| {
            allocator.free(old);
            imported.editor_imported_theme_name = null;
        }
        imported.editor_imported_theme_name = allocator.dupe(u8, theme_name) catch return LuaConfigError.OutOfMemory;
        lua_shared.mergeConfig(allocator, &imported, parsed);
        lua_shared.freeConfig(allocator, &parsed);
        return imported;
    }

    return parsed;
}

pub fn loadConfig(allocator: std.mem.Allocator) LuaConfigError!Config {
    return loadConfigWithImportedThemeOverrideInternal(allocator, null);
}

fn loadConfigWithImportedThemeOverrideInternal(allocator: std.mem.Allocator, imported_theme_override: ?[]const u8) LuaConfigError!Config {
    var config: Config = emptyConfig();
    const user_config_path = try lua_shared.findUserConfigPath(allocator);
    defer if (user_config_path) |path| allocator.free(path);
    const has_project_config = lua_shared.fileExists(".zide.lua");

    if (lua_shared.fileExists("assets/config/init.lua")) {
        const init_override = if (imported_theme_override != null and user_config_path == null and !has_project_config)
            imported_theme_override
        else
            null;
        config = try loadConfigFromFileZiglua(allocator, "assets/config/init.lua", init_override);
    }

    if (user_config_path) |path| {
        const user_override = if (imported_theme_override != null and !has_project_config)
            imported_theme_override
        else
            null;
        var user_config = try loadConfigFromFileZiglua(allocator, path, user_override);
        lua_shared.mergeConfig(allocator, &config, user_config);
        lua_shared.freeConfig(allocator, &user_config);
    }

    if (has_project_config) {
        var project_config = try loadConfigFromFileZiglua(allocator, ".zide.lua", imported_theme_override);
        lua_shared.mergeConfig(allocator, &config, project_config);
        lua_shared.freeConfig(allocator, &project_config);
    }

    return config;
}

pub fn loadConfigFile(allocator: std.mem.Allocator, path: []const u8) LuaConfigError!Config {
    return loadConfigFromFileZiglua(allocator, path, null);
}

pub fn loadNamedEditorImportedTheme(allocator: std.mem.Allocator, name: []const u8) LuaConfigError!Config {
    const path = try resolveNamedImportedThemePath(allocator, name);
    defer allocator.free(path);
    return loadConfigFromFileZiglua(allocator, path, null);
}

pub fn loadConfigWithImportedThemeOverride(allocator: std.mem.Allocator, name: []const u8) LuaConfigError!Config {
    return loadConfigWithImportedThemeOverrideInternal(allocator, name);
}

pub fn loadAvailableEditorImportedThemes(allocator: std.mem.Allocator) LuaConfigError![][]u8 {
    const lua = zlua.Lua.init(allocator) catch return LuaConfigError.LuaInitFailed;
    defer lua.deinit();
    lua.openLibs();

    const zpath = allocator.dupeZ(u8, "assets/themes/init.lua") catch return LuaConfigError.OutOfMemory;
    defer allocator.free(zpath);

    switch (zlua.lang) {
        .lua51, .luajit => lua.loadFile(zpath) catch return LuaConfigError.LuaLoadFailed,
        else => lua.loadFile(zpath, .binary_text) catch return LuaConfigError.LuaLoadFailed,
    }
    lua.protectedCall(.{ .args = 0, .results = 1 }) catch return LuaConfigError.LuaRunFailed;
    if (!lua.isTable(-1)) return LuaConfigError.InvalidConfig;

    _ = lua.getField(-1, "available");
    if (!lua.isFunction(-1)) return LuaConfigError.InvalidConfig;
    lua.call(.{ .args = 0, .results = 1 });
    if (!lua.isTable(-1)) return LuaConfigError.InvalidConfig;

    var names: std.ArrayList([]u8) = .{};
    errdefer {
        for (names.items) |name| allocator.free(name);
        names.deinit(allocator);
    }

    lua.pushNil();
    while (lua.next(-2)) {
        defer lua.pop(1);
        if (lua.toString(-2)) |key| {
            try names.append(allocator, allocator.dupe(u8, key) catch return LuaConfigError.OutOfMemory);
        } else |_| {}
    }

    std.mem.sort([]u8, names.items, {}, struct {
        fn lessThan(_: void, lhs: []u8, rhs: []u8) bool {
            return std.mem.lessThan(u8, lhs, rhs);
        }
    }.lessThan);

    return names.toOwnedSlice(allocator) catch return LuaConfigError.OutOfMemory;
}

pub fn emptyConfig() Config {
    return lua_shared.emptyConfig();
}

pub fn freeConfig(allocator: std.mem.Allocator, config: *Config) void {
    lua_shared.freeConfig(allocator, config);
}

pub fn applyThemeConfig(theme: *iface.Theme, overlay: ThemeConfig) void {
    lua_shared.applyThemeConfig(theme, overlay);
}

test "loadConfigWithImportedThemeOverride preserves project overrides while switching imported theme" {
    const allocator = std.testing.allocator;
    var original_cwd = try std.fs.cwd().openDir(".", .{});
    defer original_cwd.close();
    defer original_cwd.setAsCwd() catch unreachable;

    var tmp = std.testing.tmpDir(.{});
    defer tmp.cleanup();
    try tmp.dir.setAsCwd();

    try tmp.dir.makePath("assets/config");
    try tmp.dir.makePath("assets/themes");

    try tmp.dir.writeFile(.{
        .sub_path = "assets/config/init.lua",
        .data =
            \\return {
            \\  editor = {
            \\    imported_theme = "theme-a",
            \\  },
            \\}
        ,
    });
    try tmp.dir.writeFile(.{
        .sub_path = "assets/themes/init.lua",
        .data =
            \\local M = {}
            \\local available = {
            \\  ["theme-a"] = "assets/themes/theme-a.lua",
            \\  ["theme-b"] = "assets/themes/theme-b.lua",
            \\}
            \\function M.available()
            \\  return available
            \\end
            \\function M.load(name)
            \\  local path = available[name]
            \\  assert(path)
            \\  return dofile(path)
            \\end
            \\return M
        ,
    });
    try tmp.dir.writeFile(.{
        .sub_path = "assets/themes/theme-a.lua",
        .data =
            \\return {
            \\  editor = {
            \\    theme = {
            \\      background = "#101010",
            \\    },
            \\  },
            \\}
        ,
    });
    try tmp.dir.writeFile(.{
        .sub_path = "assets/themes/theme-b.lua",
        .data =
            \\return {
            \\  editor = {
            \\    theme = {
            \\      background = "#202020",
            \\    },
            \\  },
            \\}
        ,
    });
    try tmp.dir.writeFile(.{
        .sub_path = ".zide.lua",
        .data =
            \\return {
            \\  app = {
            \\    theme = {
            \\      ui_accent = "#123456",
            \\    },
            \\  },
            \\  editor = {
            \\    theme = {
            \\      cursor = "#abcdef",
            \\    },
            \\  },
            \\}
        ,
    });

    var config = try loadConfigWithImportedThemeOverride(allocator, "theme-b");
    defer freeConfig(allocator, &config);

    try std.testing.expectEqualStrings("theme-b", config.editor_imported_theme_name.?);
    try std.testing.expect(config.app_theme != null);
    try std.testing.expect(config.editor_theme != null);
    try std.testing.expectEqual(@as(u8, 0x12), config.app_theme.?.ui_accent.?.r);
    try std.testing.expectEqual(@as(u8, 0x34), config.app_theme.?.ui_accent.?.g);
    try std.testing.expectEqual(@as(u8, 0x56), config.app_theme.?.ui_accent.?.b);
    try std.testing.expectEqual(@as(u8, 0xab), config.editor_theme.?.cursor.?.r);
    try std.testing.expectEqual(@as(u8, 0xcd), config.editor_theme.?.cursor.?.g);
    try std.testing.expectEqual(@as(u8, 0xef), config.editor_theme.?.cursor.?.b);
    try std.testing.expectEqual(@as(u8, 0x20), config.editor_theme.?.background.?.r);
    try std.testing.expectEqual(@as(u8, 0x20), config.editor_theme.?.background.?.g);
    try std.testing.expectEqual(@as(u8, 0x20), config.editor_theme.?.background.?.b);
}

test "loadAvailableEditorImportedThemes reads the Lua registry as the single authority" {
    const allocator = std.testing.allocator;
    var original_cwd = try std.fs.cwd().openDir(".", .{});
    defer original_cwd.close();
    defer original_cwd.setAsCwd() catch unreachable;

    var tmp = std.testing.tmpDir(.{});
    defer tmp.cleanup();
    try tmp.dir.setAsCwd();

    try tmp.dir.makePath("assets/themes");
    try tmp.dir.writeFile(.{
        .sub_path = "assets/themes/init.lua",
        .data =
            \\local M = {}
            \\local available = {
            \\  ["z-last"] = "assets/themes/z-last.lua",
            \\  ["a-first"] = "assets/themes/a-first.lua",
            \\  ["m-middle"] = "assets/themes/m-middle.lua",
            \\}
            \\function M.available()
            \\  return available
            \\end
            \\return M
        ,
    });

    const names = try loadAvailableEditorImportedThemes(allocator);
    defer {
        for (names) |name| allocator.free(name);
        allocator.free(names);
    }

    try std.testing.expectEqual(@as(usize, 3), names.len);
    try std.testing.expectEqualStrings("a-first", names[0]);
    try std.testing.expectEqualStrings("m-middle", names[1]);
    try std.testing.expectEqualStrings("z-last", names[2]);
}
