const std = @import("std");
const iface = @import("./lua_config_iface.zig");
const ziglua = @import("./lua_config_ziglua.zig");

comptime {
    if (@TypeOf(ziglua.loadConfig) != iface.LoadConfigFn) @compileError("lua backend loadConfig signature mismatch");
    if (@TypeOf(ziglua.loadConfigFile) != iface.LoadConfigFileFn) @compileError("lua backend loadConfigFile signature mismatch");
    if (@TypeOf(ziglua.loadNamedEditorImportedTheme) != iface.LoadNamedEditorImportedThemeFn) @compileError("lua backend loadNamedEditorImportedTheme signature mismatch");
    if (@TypeOf(ziglua.loadConfigWithImportedThemeOverride) != iface.LoadConfigWithImportedThemeOverrideFn) @compileError("lua backend loadConfigWithImportedThemeOverride signature mismatch");
    if (@TypeOf(ziglua.loadAvailableEditorImportedThemes) != iface.LoadAvailableEditorImportedThemesFn) @compileError("lua backend loadAvailableEditorImportedThemes signature mismatch");
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
pub const TerminalNewTabStartLocationMode = iface.TerminalNewTabStartLocationMode;
pub const TerminalWindowChromeMode = iface.TerminalWindowChromeMode;
pub const TerminalShellIconMapping = iface.TerminalShellIconMapping;
pub const EditorManualHighlightMode = iface.EditorManualHighlightMode;
pub const EditorManualHighlightRule = iface.EditorManualHighlightRule;
pub const EditorManualHighlightFallback = iface.EditorManualHighlightFallback;
pub const TabBarWidthMode = iface.TabBarWidthMode;
pub const ThemeConfig = iface.ThemeConfig;

pub fn loadConfig(allocator: std.mem.Allocator) LuaConfigError!Config {
    return ziglua.loadConfig(allocator);
}

pub fn loadConfigFile(allocator: std.mem.Allocator, path: []const u8) LuaConfigError!Config {
    return ziglua.loadConfigFile(allocator, path);
}

pub fn loadNamedEditorImportedTheme(allocator: std.mem.Allocator, name: []const u8) LuaConfigError!Config {
    return ziglua.loadNamedEditorImportedTheme(allocator, name);
}

pub fn loadConfigWithImportedThemeOverride(allocator: std.mem.Allocator, name: []const u8) LuaConfigError!Config {
    return ziglua.loadConfigWithImportedThemeOverride(allocator, name);
}

pub fn loadAvailableEditorImportedThemes(allocator: std.mem.Allocator) LuaConfigError![][]u8 {
    return ziglua.loadAvailableEditorImportedThemes(allocator);
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
