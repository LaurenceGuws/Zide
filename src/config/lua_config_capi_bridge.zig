const std = @import("std");
const capi = @import("./lua_config_capi.zig");
const input_actions = @import("../input/input_actions.zig");

pub const LuaConfigError = capi.LuaConfigError;
pub const Config = capi.Config;
pub const ThemeConfig = capi.ThemeConfig;
pub const BindSpec = input_actions.BindSpec;

pub fn parseConfigFromLuaState(allocator: std.mem.Allocator, L: *anyopaque) LuaConfigError!Config {
    return capi.parseConfigFromLuaState(allocator, L);
}

pub fn parseThemeFromLuaState(L: *anyopaque, idx: i32) LuaConfigError!ThemeConfig {
    return capi.parseThemeFromLuaState(L, idx);
}

pub fn parseKeybindsFromLuaState(allocator: std.mem.Allocator, L: *anyopaque, idx: i32) LuaConfigError![]BindSpec {
    return capi.parseKeybindsFromLuaState(allocator, L, idx);
}
