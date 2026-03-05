const std = @import("std");
const iface = @import("./lua_config_iface.zig");
const ziglua = @import("./lua_config_ziglua.zig");

comptime {
    if (@TypeOf(ziglua.loadConfig) != iface.LoadConfigFn) @compileError("lua backend loadConfig signature mismatch");
    if (@TypeOf(ziglua.emptyConfig) != iface.EmptyConfigFn) @compileError("lua backend emptyConfig signature mismatch");
    if (@TypeOf(ziglua.freeConfig) != iface.FreeConfigFn) @compileError("lua backend freeConfig signature mismatch");
    if (@TypeOf(ziglua.applyThemeConfig) != iface.ApplyThemeConfigFn) @compileError("lua backend applyThemeConfig signature mismatch");
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
    return ziglua.loadConfig(allocator);
}

pub fn emptyConfig() Config {
    return ziglua.emptyConfig();
}

pub fn freeConfig(allocator: std.mem.Allocator, config: *Config) void {
    ziglua.freeConfig(allocator, config);
}

pub fn applyThemeConfig(theme: *iface.Theme, overlay: ThemeConfig) void {
    ziglua.applyThemeConfig(theme, overlay);
}
