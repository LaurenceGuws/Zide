const std = @import("std");
const zlua = @import("zlua");
const iface = @import("./lua_config_iface.zig");
const capi = @import("./lua_config_capi.zig");
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

pub fn loadConfig(allocator: std.mem.Allocator) LuaConfigError!Config {
    var config: Config = emptyConfig();



    if (capi.fileExists("assets/config/init.lua")) {
        config = try capi.loadConfigFromFile(allocator, "assets/config/init.lua");
    }

    if (try capi.findUserConfigPath(allocator)) |path| {
        defer allocator.free(path);
        var user_config = try capi.loadConfigFromFile(allocator, path);
        capi.mergeConfig(allocator, &config, user_config);
        lua_shared.freeConfig(allocator, &user_config);
    }

    if (capi.fileExists(".zide.lua")) {
        var project_config = try capi.loadConfigFromFile(allocator, ".zide.lua");
        capi.mergeConfig(allocator, &config, project_config);
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
