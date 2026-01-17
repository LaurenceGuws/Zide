const std = @import("std");

const c = @cImport({
    @cInclude("lua.h");
    @cInclude("lauxlib.h");
    @cInclude("lualib.h");
    @cInclude("raylib.h");
});

pub const LuaConfigError = error{
    LuaInitFailed,
    LuaLoadFailed,
    LuaRunFailed,
    InvalidConfig,
    OutOfMemory,
};

pub const Config = struct {
    log_filter: ?[]u8,
    raylib_log_level: ?c_int,
};

pub fn loadConfig(allocator: std.mem.Allocator) LuaConfigError!Config {
    var config: Config = .{ .log_filter = null, .raylib_log_level = null };
    if (fileExists("assets/config/init.lua")) {
        config = try loadConfigFromFile(allocator, "assets/config/init.lua");
    }

    if (try findUserConfigPath(allocator)) |path| {
        defer allocator.free(path);
        const user_config = try loadConfigFromFile(allocator, path);
        mergeConfig(&config, user_config);
    }

    if (fileExists(".zide.lua")) {
        const project_config = try loadConfigFromFile(allocator, ".zide.lua");
        mergeConfig(&config, project_config);
    }

    return config;
}

pub fn freeConfig(allocator: std.mem.Allocator, config: *Config) void {
    if (config.log_filter) |filter| {
        allocator.free(filter);
        config.log_filter = null;
    }
}

fn mergeConfig(base: *Config, overlay: Config) void {
    if (overlay.log_filter) |filter| {
        base.log_filter = filter;
    }
    if (overlay.raylib_log_level) |level| {
        base.raylib_log_level = level;
    }
}

fn loadConfigFromFile(allocator: std.mem.Allocator, path: []const u8) LuaConfigError!Config {
    const L = c.luaL_newstate() orelse return LuaConfigError.LuaInitFailed;
    defer c.lua_close(L);
    c.luaL_openlibs(L);

    if (c.luaL_loadfilex(L, path.ptr, null) != 0) {
        return LuaConfigError.LuaLoadFailed;
    }
    if (c.lua_pcallk(L, 0, 1, 0, 0, null) != 0) {
        return LuaConfigError.LuaRunFailed;
    }

    return parseConfigFromStack(allocator, L);
}

fn parseConfigFromStack(allocator: std.mem.Allocator, L: *c.lua_State) LuaConfigError!Config {
    if (c.lua_isnil(L, -1)) {
        return .{ .log_filter = null, .raylib_log_level = null };
    }
    if (!c.lua_istable(L, -1)) {
        return LuaConfigError.InvalidConfig;
    }

    var log_filter: ?[]u8 = null;
    var raylib_log_level: ?c_int = null;

    _ = c.lua_getfield(L, -1, "log");
    if (c.lua_isstring(L, -1) != 0) {
        log_filter = try luaStringToOwned(allocator, L, -1);
    } else if (c.lua_istable(L, -1)) {
        _ = c.lua_getfield(L, -1, "enable");
        if (c.lua_isstring(L, -1) != 0) {
            log_filter = try luaStringToOwned(allocator, L, -1);
        } else if (c.lua_istable(L, -1)) {
            log_filter = try luaStringListToOwned(allocator, L, -1);
        }
        c.lua_pop(L, 1);
    }
    c.lua_pop(L, 1);

    _ = c.lua_getfield(L, -1, "raylib");
    if (c.lua_isstring(L, -1) != 0) {
        raylib_log_level = parseRaylibLogLevel(L, -1);
    } else if (c.lua_istable(L, -1)) {
        _ = c.lua_getfield(L, -1, "log_level");
        if (c.lua_isstring(L, -1) != 0) {
            raylib_log_level = parseRaylibLogLevel(L, -1);
        }
        c.lua_pop(L, 1);
    }
    c.lua_pop(L, 1);

    return .{
        .log_filter = log_filter,
        .raylib_log_level = raylib_log_level,
    };
}

fn findUserConfigPath(allocator: std.mem.Allocator) LuaConfigError!?[]u8 {
    const builtin = @import("builtin");
    switch (builtin.os.tag) {
        .windows => {
            const appdata = std.c.getenv("APPDATA") orelse return null;
            const base = std.mem.sliceTo(appdata, 0);
            const path = try std.fs.path.join(allocator, &.{ base, "Zide", "init.lua" });
            if (!fileExists(path)) {
                allocator.free(path);
                return null;
            }
            return path;
        },
        .macos => {
            const home = std.c.getenv("HOME") orelse return null;
            const base = std.mem.sliceTo(home, 0);
            const path = try std.fs.path.join(allocator, &.{ base, "Library", "Application Support", "Zide", "init.lua" });
            if (!fileExists(path)) {
                allocator.free(path);
                return null;
            }
            return path;
        },
        else => {
            const xdg = std.c.getenv("XDG_CONFIG_HOME");
            const home = std.c.getenv("HOME");
            if (xdg == null and home == null) return null;

            const base = if (xdg) |val| std.mem.sliceTo(val, 0) else blk: {
                const home_slice = std.mem.sliceTo(home.?, 0);
                break :blk try std.fs.path.join(allocator, &.{ home_slice, ".config" });
            };
            defer if (xdg == null and home != null) allocator.free(base);

            const path = try std.fs.path.join(allocator, &.{ base, "zide", "init.lua" });
            if (!fileExists(path)) {
                allocator.free(path);
                return null;
            }
            return path;
        },
    }
}

fn fileExists(path: []const u8) bool {
    if (std.fs.cwd().openFile(path, .{})) |file| {
        file.close();
        return true;
    } else |_| {
        return false;
    }
}

fn luaStringToOwned(allocator: std.mem.Allocator, L: *c.lua_State, idx: c_int) LuaConfigError![]u8 {
    var len: usize = 0;
    const ptr = c.lua_tolstring(L, idx, &len) orelse return LuaConfigError.InvalidConfig;
    const slice = @as([*]const u8, @ptrCast(ptr))[0..len];
    return allocator.dupe(u8, slice);
}

fn luaStringListToOwned(allocator: std.mem.Allocator, L: *c.lua_State, idx: c_int) LuaConfigError![]u8 {
    const len = c.lua_rawlen(L, idx);
    var out = std.ArrayList(u8).empty;
    errdefer out.deinit(allocator);

    var i: c_int = 1;
    while (i <= @as(c_int, @intCast(len))) : (i += 1) {
        _ = c.lua_rawgeti(L, idx, i);
        if (c.lua_isstring(L, -1) != 0) {
            var s_len: usize = 0;
            const s_ptr = c.lua_tolstring(L, -1, &s_len) orelse {
                c.lua_pop(L, 1);
                continue;
            };
            const s_slice = @as([*]const u8, @ptrCast(s_ptr))[0..s_len];
            if (out.items.len > 0) {
                try out.append(allocator, ',');
            }
            try out.appendSlice(allocator, s_slice);
        }
        c.lua_pop(L, 1);
    }

    return out.toOwnedSlice(allocator);
}

fn parseRaylibLogLevel(L: *c.lua_State, idx: c_int) ?c_int {
    var len: usize = 0;
    const ptr = c.lua_tolstring(L, idx, &len) orelse return null;
    const value = @as([*]const u8, @ptrCast(ptr))[0..len];
    if (std.mem.eql(u8, value, "none")) return c.LOG_NONE;
    if (std.mem.eql(u8, value, "error")) return c.LOG_ERROR;
    if (std.mem.eql(u8, value, "warning")) return c.LOG_WARNING;
    if (std.mem.eql(u8, value, "warn")) return c.LOG_WARNING;
    if (std.mem.eql(u8, value, "info")) return c.LOG_INFO;
    if (std.mem.eql(u8, value, "debug")) return c.LOG_DEBUG;
    if (std.mem.eql(u8, value, "trace")) return c.LOG_TRACE;
    return null;
}
