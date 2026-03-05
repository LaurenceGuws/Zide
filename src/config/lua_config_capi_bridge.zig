const std = @import("std");
const capi = @import("./lua_config_capi.zig");

pub const LuaConfigError = capi.LuaConfigError;
pub const Config = capi.Config;

pub fn parseConfigFromLuaState(allocator: std.mem.Allocator, L: *anyopaque) LuaConfigError!Config {
    return capi.parseConfigFromLuaState(allocator, L);
}
