const std = @import("std");
const capi_bridge = @import("./lua_config_capi_bridge.zig");

pub const LuaConfigError = capi_bridge.LuaConfigError;
pub const Config = capi_bridge.Config;

// Migration seam: replace this bridge call with native ziglua table parsing.
pub fn parseConfigFromLuaState(allocator: std.mem.Allocator, L: *anyopaque) LuaConfigError!Config {
    return capi_bridge.parseConfigFromLuaState(allocator, L);
}
