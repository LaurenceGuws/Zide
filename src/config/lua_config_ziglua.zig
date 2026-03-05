const std = @import("std");
const iface = @import("./lua_config_iface.zig");

pub const LuaConfigError = iface.LuaConfigError;
pub const Config = iface.Config;
pub const FontHinting = iface.FontHinting;
pub const GlyphOverflowPolicy = iface.GlyphOverflowPolicy;
pub const TerminalBlinkStyle = iface.TerminalBlinkStyle;
pub const TerminalDisableLigaturesStrategy = iface.TerminalDisableLigaturesStrategy;
pub const TabBarWidthMode = iface.TabBarWidthMode;
pub const ThemeConfig = iface.ThemeConfig;

pub fn loadConfig(_: std.mem.Allocator) LuaConfigError!Config {
    @panic("lua_config_ziglua is not implemented yet; use -Dlua-impl=capi");
}

pub fn freeConfig(_: std.mem.Allocator, _: *Config) void {}

pub fn applyThemeConfig(theme: *iface.Theme, overlay: ThemeConfig) void {
    _ = theme;
    _ = overlay;
}
