const std = @import("std");
const renderer = @import("../ui/renderer.zig");
const capi = @import("./lua_config_capi.zig");

pub const Color = renderer.Color;
pub const Theme = renderer.Theme;

pub const LuaConfigError = capi.LuaConfigError;
pub const Config = capi.Config;
pub const FontHinting = capi.FontHinting;
pub const GlyphOverflowPolicy = capi.GlyphOverflowPolicy;
pub const TerminalBlinkStyle = capi.TerminalBlinkStyle;
pub const TerminalDisableLigaturesStrategy = capi.TerminalDisableLigaturesStrategy;
pub const TabBarWidthMode = capi.TabBarWidthMode;
pub const ThemeConfig = capi.ThemeConfig;

pub const LoadConfigFn = fn (allocator: std.mem.Allocator) LuaConfigError!Config;
pub const EmptyConfigFn = fn () Config;
pub const FreeConfigFn = fn (allocator: std.mem.Allocator, config: *Config) void;
pub const ApplyThemeConfigFn = fn (theme: *Theme, overlay: ThemeConfig) void;
