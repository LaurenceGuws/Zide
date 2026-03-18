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
pub const TabBarWidthMode = iface.TabBarWidthMode;
pub const ThemeConfig = iface.ThemeConfig;

fn loadConfigFromFileZiglua(allocator: std.mem.Allocator, path: []const u8) LuaConfigError!Config {
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

    if (parsed.editor_imported_theme_name) |theme_name| {
        const theme_path = std.fmt.allocPrint(allocator, "assets/themes/{s}.lua", .{theme_name}) catch return LuaConfigError.OutOfMemory;
        defer allocator.free(theme_path);
        if (!lua_shared.fileExists(theme_path)) return LuaConfigError.InvalidConfig;

        var imported = try loadConfigFromFileZiglua(allocator, theme_path);
        defer lua_shared.freeConfig(allocator, &imported);
        lua_shared.mergeConfig(allocator, &imported, parsed);
        lua_shared.freeConfig(allocator, &parsed);
        return imported;
    }

    return parsed;
}

pub fn loadConfig(allocator: std.mem.Allocator) LuaConfigError!Config {
    var config: Config = emptyConfig();

    if (lua_shared.fileExists("assets/config/init.lua")) {
        config = try loadConfigFromFileZiglua(allocator, "assets/config/init.lua");
    }

    if (try lua_shared.findUserConfigPath(allocator)) |path| {
        defer allocator.free(path);
        var user_config = try loadConfigFromFileZiglua(allocator, path);
        lua_shared.mergeConfig(allocator, &config, user_config);
        lua_shared.freeConfig(allocator, &user_config);
    }

    if (lua_shared.fileExists(".zide.lua")) {
        var project_config = try loadConfigFromFileZiglua(allocator, ".zide.lua");
        lua_shared.mergeConfig(allocator, &config, project_config);
        lua_shared.freeConfig(allocator, &project_config);
    }

    return config;
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
