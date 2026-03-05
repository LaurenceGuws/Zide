const std = @import("std");
const build_options = @import("build_options");
const iface = @import("./lua_config_iface.zig");
const capi = @import("./lua_config_capi.zig");
const ziglua = @import("./lua_config_ziglua.zig");

const lua_impl = if (@hasDecl(build_options, "lua_impl")) build_options.lua_impl else "capi";

const backend = if (std.mem.eql(u8, lua_impl, "ziglua")) ziglua else capi;

comptime {
    if (!std.mem.eql(u8, lua_impl, "capi") and !std.mem.eql(u8, lua_impl, "ziglua")) {
        @compileError("invalid build option lua_impl (expected 'capi' or 'ziglua')");
    }
    if (@TypeOf(backend.loadConfig) != iface.LoadConfigFn) @compileError("lua backend loadConfig signature mismatch");
    if (@TypeOf(backend.emptyConfig) != iface.EmptyConfigFn) @compileError("lua backend emptyConfig signature mismatch");
    if (@TypeOf(backend.freeConfig) != iface.FreeConfigFn) @compileError("lua backend freeConfig signature mismatch");
    if (@TypeOf(backend.applyThemeConfig) != iface.ApplyThemeConfigFn) @compileError("lua backend applyThemeConfig signature mismatch");
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
    return backend.loadConfig(allocator);
}

pub fn emptyConfig() Config {
    return backend.emptyConfig();
}

pub fn freeConfig(allocator: std.mem.Allocator, config: *Config) void {
    backend.freeConfig(allocator, config);
}

pub fn applyThemeConfig(theme: *iface.Theme, overlay: ThemeConfig) void {
    backend.applyThemeConfig(theme, overlay);
}
