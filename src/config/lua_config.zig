const std = @import("std");
const renderer = @import("../ui/renderer.zig");

const c = @cImport({
    @cInclude("lua.h");
    @cInclude("lauxlib.h");
    @cInclude("lualib.h");
    @cInclude("SDL2/SDL.h");
});

const Color = renderer.Color;
const Theme = renderer.Theme;

pub const LuaConfigError = error{
    LuaInitFailed,
    LuaLoadFailed,
    LuaRunFailed,
    InvalidConfig,
    OutOfMemory,
};

pub const Config = struct {
    log_file_filter: ?[]u8,
    log_console_filter: ?[]u8,
    sdl_log_level: ?c_int,
    editor_wrap: ?bool,
    editor_highlight_budget: ?usize,
    editor_width_budget: ?usize,
    theme: ?ThemeConfig,
};

pub const ThemeConfig = struct {
    background: ?Color = null,
    foreground: ?Color = null,
    selection: ?Color = null,
    cursor: ?Color = null,
    link: ?Color = null,
    line_number: ?Color = null,
    line_number_bg: ?Color = null,
    current_line: ?Color = null,
    comment_color: ?Color = null,
    string: ?Color = null,
    keyword: ?Color = null,
    number: ?Color = null,
    function: ?Color = null,
    variable: ?Color = null,
    type_name: ?Color = null,
    operator: ?Color = null,
    builtin_color: ?Color = null,
    punctuation: ?Color = null,
    constant: ?Color = null,
    attribute: ?Color = null,
    namespace: ?Color = null,
    label: ?Color = null,
    error_token: ?Color = null,
};

pub fn loadConfig(allocator: std.mem.Allocator) LuaConfigError!Config {
    var config: Config = .{
        .log_file_filter = null,
        .log_console_filter = null,
        .sdl_log_level = null,
        .editor_wrap = null,
        .editor_highlight_budget = null,
        .editor_width_budget = null,
        .theme = null,
    };
    if (fileExists("assets/config/init.lua")) {
        config = try loadConfigFromFile(allocator, "assets/config/init.lua");
    }

    if (try findUserConfigPath(allocator)) |path| {
        defer allocator.free(path);
        var user_config = try loadConfigFromFile(allocator, path);
        mergeConfig(allocator, &config, user_config);
        freeConfig(allocator, &user_config);
    }

    if (fileExists(".zide.lua")) {
        var project_config = try loadConfigFromFile(allocator, ".zide.lua");
        mergeConfig(allocator, &config, project_config);
        freeConfig(allocator, &project_config);
    }

    return config;
}

pub fn freeConfig(allocator: std.mem.Allocator, config: *Config) void {
    if (config.log_file_filter) |filter| {
        allocator.free(filter);
        config.log_file_filter = null;
    }
    if (config.log_console_filter) |filter| {
        allocator.free(filter);
        config.log_console_filter = null;
    }
}

fn mergeConfig(allocator: std.mem.Allocator, base: *Config, overlay: Config) void {
    if (overlay.log_file_filter) |filter| {
        if (base.log_file_filter) |old| allocator.free(old);
        base.log_file_filter = allocator.dupe(u8, filter) catch base.log_file_filter;
    }
    if (overlay.log_console_filter) |filter| {
        if (base.log_console_filter) |old| allocator.free(old);
        base.log_console_filter = allocator.dupe(u8, filter) catch base.log_console_filter;
    }
    if (overlay.sdl_log_level) |level| {
        base.sdl_log_level = level;
    }
    if (overlay.editor_wrap != null) {
        base.editor_wrap = overlay.editor_wrap;
    }
    if (overlay.editor_highlight_budget != null) {
        base.editor_highlight_budget = overlay.editor_highlight_budget;
    }
    if (overlay.editor_width_budget != null) {
        base.editor_width_budget = overlay.editor_width_budget;
    }
    if (overlay.theme) |overlay_theme| {
        if (base.theme) |base_theme| {
            var merged = base_theme;
            mergeThemeConfig(&merged, overlay_theme);
            base.theme = merged;
        } else {
            base.theme = overlay_theme;
        }
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
        return .{
            .log_file_filter = null,
            .log_console_filter = null,
            .sdl_log_level = null,
            .editor_wrap = null,
            .editor_highlight_budget = null,
            .editor_width_budget = null,
            .theme = null,
        };
    }
    if (!c.lua_istable(L, -1)) {
        return LuaConfigError.InvalidConfig;
    }

    var log_file_filter: ?[]u8 = null;
    var log_console_filter: ?[]u8 = null;
    var sdl_log_level: ?c_int = null;
    var editor_wrap: ?bool = null;
    var editor_highlight_budget: ?usize = null;
    var editor_width_budget: ?usize = null;
    var theme: ?ThemeConfig = null;

    _ = c.lua_getfield(L, -1, "log");
    if (c.lua_isstring(L, -1) != 0) {
        const value = try luaStringToOwned(allocator, L, -1);
        log_file_filter = value;
        log_console_filter = try allocator.dupe(u8, value);
    } else if (c.lua_istable(L, -1)) {
        if (parseLogFiltersFromTable(allocator, L, -1, &log_file_filter, &log_console_filter)) |_| {} else |_| {}
    }
    c.lua_pop(L, 1);

    _ = c.lua_getfield(L, -1, "sdl");
    if (c.lua_isstring(L, -1) != 0) {
        sdl_log_level = parseSdlLogLevel(L, -1);
    } else if (c.lua_istable(L, -1)) {
        _ = c.lua_getfield(L, -1, "log_level");
        if (c.lua_isstring(L, -1) != 0) {
            sdl_log_level = parseSdlLogLevel(L, -1);
        }
        c.lua_pop(L, 1);
    }
    c.lua_pop(L, 1);

    if (sdl_log_level == null) {
        _ = c.lua_getfield(L, -1, "raylib");
        if (c.lua_isstring(L, -1) != 0) {
            sdl_log_level = parseSdlLogLevel(L, -1);
        } else if (c.lua_istable(L, -1)) {
            _ = c.lua_getfield(L, -1, "log_level");
            if (c.lua_isstring(L, -1) != 0) {
                sdl_log_level = parseSdlLogLevel(L, -1);
            }
            c.lua_pop(L, 1);
        }
        c.lua_pop(L, 1);
    }

    _ = c.lua_getfield(L, -1, "editor");
    if (c.lua_istable(L, -1)) {
        _ = c.lua_getfield(L, -1, "wrap");
        if (c.lua_isboolean(L, -1)) {
            editor_wrap = c.lua_toboolean(L, -1) != 0;
        }
        c.lua_pop(L, 1);

        _ = c.lua_getfield(L, -1, "render");
        if (c.lua_istable(L, -1)) {
            _ = c.lua_getfield(L, -1, "highlight_budget");
            if (c.lua_isnumber(L, -1) != 0) {
                var is_num: c_int = 0;
                const value = c.lua_tointegerx(L, -1, &is_num);
                if (is_num != 0 and value >= 0) {
                    editor_highlight_budget = @intCast(value);
                }
            }
            c.lua_pop(L, 1);

            _ = c.lua_getfield(L, -1, "width_budget");
            if (c.lua_isnumber(L, -1) != 0) {
                var is_num: c_int = 0;
                const value = c.lua_tointegerx(L, -1, &is_num);
                if (is_num != 0 and value >= 0) {
                    editor_width_budget = @intCast(value);
                }
            }
            c.lua_pop(L, 1);
        }
        c.lua_pop(L, 1);
    }
    c.lua_pop(L, 1);

    _ = c.lua_getfield(L, -1, "theme");
    if (c.lua_istable(L, -1)) {
        theme = try parseThemeFromTable(L, -1);
    }
    c.lua_pop(L, 1);

    return .{
        .log_file_filter = log_file_filter,
        .log_console_filter = log_console_filter,
        .sdl_log_level = sdl_log_level,
        .editor_wrap = editor_wrap,
        .editor_highlight_budget = editor_highlight_budget,
        .editor_width_budget = editor_width_budget,
        .theme = theme,
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

fn parseLogFiltersFromTable(
    allocator: std.mem.Allocator,
    L: *c.lua_State,
    idx: c_int,
    file_out: *?[]u8,
    console_out: *?[]u8,
) LuaConfigError!void {
    _ = c.lua_getfield(L, idx, "file");
    if (c.lua_isstring(L, -1) != 0) {
        file_out.* = try luaStringToOwned(allocator, L, -1);
    } else if (c.lua_istable(L, -1)) {
        file_out.* = try luaStringListToOwned(allocator, L, -1);
    }
    c.lua_pop(L, 1);

    _ = c.lua_getfield(L, idx, "console");
    if (c.lua_isstring(L, -1) != 0) {
        console_out.* = try luaStringToOwned(allocator, L, -1);
    } else if (c.lua_istable(L, -1)) {
        console_out.* = try luaStringListToOwned(allocator, L, -1);
    }
    c.lua_pop(L, 1);

    if (file_out.* == null or console_out.* == null) {
        _ = c.lua_getfield(L, idx, "enable");
        if (c.lua_isstring(L, -1) != 0) {
            const value = try luaStringToOwned(allocator, L, -1);
            if (file_out.* == null) file_out.* = value else allocator.free(value);
            if (console_out.* == null) console_out.* = try allocator.dupe(u8, value);
        } else if (c.lua_istable(L, -1)) {
            const value = try luaStringListToOwned(allocator, L, -1);
            if (file_out.* == null) file_out.* = value else allocator.free(value);
            if (console_out.* == null) console_out.* = try allocator.dupe(u8, value);
        }
        c.lua_pop(L, 1);
    }
}

fn parseSdlLogLevel(L: *c.lua_State, idx: c_int) ?c_int {
    var len: usize = 0;
    const ptr = c.lua_tolstring(L, idx, &len) orelse return null;
    const value = @as([*]const u8, @ptrCast(ptr))[0..len];
    if (std.mem.eql(u8, value, "none")) return c.SDL_LOG_PRIORITY_CRITICAL;
    if (std.mem.eql(u8, value, "critical")) return c.SDL_LOG_PRIORITY_CRITICAL;
    if (std.mem.eql(u8, value, "error")) return c.SDL_LOG_PRIORITY_ERROR;
    if (std.mem.eql(u8, value, "warning")) return c.SDL_LOG_PRIORITY_WARN;
    if (std.mem.eql(u8, value, "warn")) return c.SDL_LOG_PRIORITY_WARN;
    if (std.mem.eql(u8, value, "info")) return c.SDL_LOG_PRIORITY_INFO;
    if (std.mem.eql(u8, value, "debug")) return c.SDL_LOG_PRIORITY_DEBUG;
    if (std.mem.eql(u8, value, "trace")) return c.SDL_LOG_PRIORITY_VERBOSE;
    return null;
}

fn mergeThemeConfig(base: *ThemeConfig, overlay: ThemeConfig) void {
    if (overlay.background) |color| base.background = color;
    if (overlay.foreground) |color| base.foreground = color;
    if (overlay.selection) |color| base.selection = color;
    if (overlay.cursor) |color| base.cursor = color;
    if (overlay.link) |color| base.link = color;
    if (overlay.line_number) |color| base.line_number = color;
    if (overlay.line_number_bg) |color| base.line_number_bg = color;
    if (overlay.current_line) |color| base.current_line = color;
    if (overlay.comment_color) |color| base.comment_color = color;
    if (overlay.string) |color| base.string = color;
    if (overlay.keyword) |color| base.keyword = color;
    if (overlay.number) |color| base.number = color;
    if (overlay.function) |color| base.function = color;
    if (overlay.variable) |color| base.variable = color;
    if (overlay.type_name) |color| base.type_name = color;
    if (overlay.operator) |color| base.operator = color;
    if (overlay.builtin_color) |color| base.builtin_color = color;
    if (overlay.punctuation) |color| base.punctuation = color;
    if (overlay.constant) |color| base.constant = color;
    if (overlay.attribute) |color| base.attribute = color;
    if (overlay.namespace) |color| base.namespace = color;
    if (overlay.label) |color| base.label = color;
    if (overlay.error_token) |color| base.error_token = color;
}

pub fn applyThemeConfig(theme: *Theme, overlay: ThemeConfig) void {
    if (overlay.background) |color| theme.background = color;
    if (overlay.foreground) |color| theme.foreground = color;
    if (overlay.selection) |color| theme.selection = color;
    if (overlay.cursor) |color| theme.cursor = color;
    if (overlay.link) |color| theme.link = color;
    if (overlay.line_number) |color| theme.line_number = color;
    if (overlay.line_number_bg) |color| theme.line_number_bg = color;
    if (overlay.current_line) |color| theme.current_line = color;
    if (overlay.comment_color) |color| theme.comment_color = color;
    if (overlay.string) |color| theme.string = color;
    if (overlay.keyword) |color| theme.keyword = color;
    if (overlay.number) |color| theme.number = color;
    if (overlay.function) |color| theme.function = color;
    if (overlay.variable) |color| theme.variable = color;
    if (overlay.type_name) |color| theme.type_name = color;
    if (overlay.operator) |color| theme.operator = color;
    if (overlay.builtin_color) |color| theme.builtin_color = color;
    if (overlay.punctuation) |color| theme.punctuation = color;
    if (overlay.constant) |color| theme.constant = color;
    if (overlay.attribute) |color| theme.attribute = color;
    if (overlay.namespace) |color| theme.namespace = color;
    if (overlay.label) |color| theme.label = color;
    if (overlay.error_token) |color| theme.error_token = color;
}

fn parseThemeFromTable(L: *c.lua_State, idx: c_int) LuaConfigError!ThemeConfig {
    var theme: ThemeConfig = .{};
    parseThemePaletteTable(L, idx, &theme);
    parseThemeSyntaxTable(L, idx, &theme);

    _ = c.lua_getfield(L, idx, "palette");
    if (c.lua_istable(L, -1)) {
        parseThemePaletteTable(L, -1, &theme);
    }
    c.lua_pop(L, 1);

    _ = c.lua_getfield(L, idx, "syntax");
    if (c.lua_istable(L, -1)) {
        parseThemeSyntaxTable(L, -1, &theme);
    }
    c.lua_pop(L, 1);

    return theme;
}

fn parseThemePaletteTable(L: *c.lua_State, idx: c_int, theme: *ThemeConfig) void {
    parseColorField(L, idx, "background", &theme.background);
    parseColorField(L, idx, "foreground", &theme.foreground);
    parseColorField(L, idx, "selection", &theme.selection);
    parseColorField(L, idx, "cursor", &theme.cursor);
    parseColorField(L, idx, "link", &theme.link);
    parseColorField(L, idx, "line_number", &theme.line_number);
    parseColorField(L, idx, "line_number_bg", &theme.line_number_bg);
    parseColorField(L, idx, "current_line", &theme.current_line);
}

fn parseThemeSyntaxTable(L: *c.lua_State, idx: c_int, theme: *ThemeConfig) void {
    parseColorField(L, idx, "comment", &theme.comment_color);
    parseColorField(L, idx, "comment_color", &theme.comment_color);
    parseColorField(L, idx, "string", &theme.string);
    parseColorField(L, idx, "keyword", &theme.keyword);
    parseColorField(L, idx, "number", &theme.number);
    parseColorField(L, idx, "function", &theme.function);
    parseColorField(L, idx, "variable", &theme.variable);
    parseColorField(L, idx, "type_name", &theme.type_name);
    parseColorField(L, idx, "operator", &theme.operator);
    parseColorField(L, idx, "builtin", &theme.builtin_color);
    parseColorField(L, idx, "builtin_color", &theme.builtin_color);
    parseColorField(L, idx, "punctuation", &theme.punctuation);
    parseColorField(L, idx, "constant", &theme.constant);
    parseColorField(L, idx, "attribute", &theme.attribute);
    parseColorField(L, idx, "namespace", &theme.namespace);
    parseColorField(L, idx, "label", &theme.label);
    parseColorField(L, idx, "error", &theme.error_token);
    parseColorField(L, idx, "error_token", &theme.error_token);
}

fn parseColorField(L: *c.lua_State, idx: c_int, field: [:0]const u8, out: *?Color) void {
    _ = c.lua_getfield(L, idx, field.ptr);
    const color = parseColorFromValue(L, -1);
    if (color != null) {
        out.* = color.?;
    }
    c.lua_pop(L, 1);
}

fn parseColorFromValue(L: *c.lua_State, idx: c_int) ?Color {
    if (c.lua_isstring(L, idx) != 0) {
        var len: usize = 0;
        const ptr = c.lua_tolstring(L, idx, &len) orelse return null;
        const value = @as([*]const u8, @ptrCast(ptr))[0..len];
        return parseHexColor(value);
    }
    if (c.lua_istable(L, idx)) {
        var r: ?u8 = null;
        var g: ?u8 = null;
        var b: ?u8 = null;
        var a: ?u8 = null;

        _ = c.lua_getfield(L, idx, "r");
        if (c.lua_isnumber(L, -1) != 0) {
            r = parseColorChannel(L, -1);
        }
        c.lua_pop(L, 1);

        _ = c.lua_getfield(L, idx, "g");
        if (c.lua_isnumber(L, -1) != 0) {
            g = parseColorChannel(L, -1);
        }
        c.lua_pop(L, 1);

        _ = c.lua_getfield(L, idx, "b");
        if (c.lua_isnumber(L, -1) != 0) {
            b = parseColorChannel(L, -1);
        }
        c.lua_pop(L, 1);

        _ = c.lua_getfield(L, idx, "a");
        if (c.lua_isnumber(L, -1) != 0) {
            a = parseColorChannel(L, -1);
        }
        c.lua_pop(L, 1);

        if (r != null and g != null and b != null) {
            return Color{ .r = r.?, .g = g.?, .b = b.?, .a = a orelse 255 };
        }
    }
    return null;
}

fn parseHexColor(value: []const u8) ?Color {
    var slice = value;
    if (slice.len >= 2 and slice[0] == '0' and (slice[1] == 'x' or slice[1] == 'X')) {
        slice = slice[2..];
    }
    if (slice.len > 0 and slice[0] == '#') {
        slice = slice[1..];
    }
    if (slice.len != 6 and slice.len != 8) return null;

    const r = parseHexByte(slice[0..2]) orelse return null;
    const g = parseHexByte(slice[2..4]) orelse return null;
    const b = parseHexByte(slice[4..6]) orelse return null;
    const a = if (slice.len == 8) parseHexByte(slice[6..8]) orelse return null else 255;

    return Color{ .r = r, .g = g, .b = b, .a = a };
}

fn parseHexByte(slice: []const u8) ?u8 {
    return std.fmt.parseInt(u8, slice, 16) catch null;
}

fn parseColorChannel(L: *c.lua_State, idx: c_int) ?u8 {
    var is_num: c_int = 0;
    const value = c.lua_tointegerx(L, idx, &is_num);
    if (is_num == 0) return null;
    if (value < 0 or value > 255) return null;
    return @intCast(value);
}
