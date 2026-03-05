const std = @import("std");
const zlua = @import("zlua");
const capi_bridge = @import("./lua_config_capi_bridge.zig");
const lua_shared = @import("./lua_config_shared.zig");

pub const LuaConfigError = capi_bridge.LuaConfigError;
pub const Config = capi_bridge.Config;

// Migration seam: replace this bridge call with native ziglua table parsing.
pub fn parseConfigFromLuaState(allocator: std.mem.Allocator, L: *anyopaque) LuaConfigError!Config {
    const lua: *zlua.Lua = @ptrCast(@alignCast(L));
    if (lua.isNil(-1)) {
        return lua_shared.emptyConfig();
    }
    if (!lua.isTable(-1)) {
        return LuaConfigError.InvalidConfig;
    }
    return capi_bridge.parseConfigFromLuaState(allocator, L);
}
