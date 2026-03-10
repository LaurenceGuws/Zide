const std = @import("std");
const zlua = @import("zlua");
const iface = @import("./lua_config_iface.zig");

const ThemeConfig = iface.ThemeConfig;
const Color = std.meta.Child(@TypeOf((@as(ThemeConfig, undefined)).background));
const LuaConfigError = iface.LuaConfigError;

fn parseHexByte(slice: []const u8) ?u8 {
    return std.fmt.parseInt(u8, slice, 16) catch null;
}

fn parseHexColor(value: []const u8) ?Color {
    var slice = value;
    if (slice.len >= 2 and slice[0] == '0' and (slice[1] == 'x' or slice[1] == 'X')) slice = slice[2..];
    if (slice.len > 0 and slice[0] == '#') slice = slice[1..];
    if (slice.len != 6 and slice.len != 8) return null;

    const r = parseHexByte(slice[0..2]) orelse return null;
    const g = parseHexByte(slice[2..4]) orelse return null;
    const b = parseHexByte(slice[4..6]) orelse return null;
    const a = if (slice.len == 8) parseHexByte(slice[6..8]) orelse return null else 255;
    return Color{ .r = r, .g = g, .b = b, .a = a };
}

fn parseColorChannel(lua: *zlua.Lua, idx: i32) ?u8 {
    if (!lua.isNumber(idx)) return null;
    if (lua.toInteger(idx)) |value| {
        if (value < 0 or value > 255) return null;
        return @intCast(value);
    } else |_| return null;
}

fn parseColorFromValue(lua: *zlua.Lua, idx: i32) ?Color {
    if (lua.isString(idx)) {
        if (lua.toString(idx)) |value| return parseHexColor(value) else |_| return null;
    }
    if (lua.isTable(idx)) {
        const table_idx = lua.absIndex(idx);
        var r: ?u8 = null;
        var g: ?u8 = null;
        var b: ?u8 = null;
        var a: ?u8 = null;

        _ = lua.getField(table_idx, "r");
        r = parseColorChannel(lua, -1);
        lua.pop(1);
        _ = lua.getField(table_idx, "g");
        g = parseColorChannel(lua, -1);
        lua.pop(1);
        _ = lua.getField(table_idx, "b");
        b = parseColorChannel(lua, -1);
        lua.pop(1);
        _ = lua.getField(table_idx, "a");
        a = parseColorChannel(lua, -1);
        lua.pop(1);

        if (r != null and g != null and b != null) {
            return Color{ .r = r.?, .g = g.?, .b = b.?, .a = a orelse 255 };
        }
    }
    return null;
}

fn parseColorField(lua: *zlua.Lua, idx: i32, field: [:0]const u8, out: *?Color) void {
    _ = lua.getField(idx, field);
    if (parseColorFromValue(lua, -1)) |color| out.* = color;
    lua.pop(1);
}

fn parseIndexedAnsiColors(lua: *zlua.Lua, idx: i32, ansi_colors: *[16]?Color) void {
    for (0..16) |i| {
        _ = lua.rawGetIndex(idx, @intCast(i + 1));
        if (parseColorFromValue(lua, -1)) |color| ansi_colors[i] = color;
        lua.pop(1);
    }
}

fn parseNamedAnsiColors(lua: *zlua.Lua, idx: i32, ansi_colors: *[16]?Color) void {
    parseColorField(lua, idx, "black", &ansi_colors[0]);
    parseColorField(lua, idx, "red", &ansi_colors[1]);
    parseColorField(lua, idx, "green", &ansi_colors[2]);
    parseColorField(lua, idx, "yellow", &ansi_colors[3]);
    parseColorField(lua, idx, "blue", &ansi_colors[4]);
    parseColorField(lua, idx, "magenta", &ansi_colors[5]);
    parseColorField(lua, idx, "cyan", &ansi_colors[6]);
    parseColorField(lua, idx, "white", &ansi_colors[7]);
    parseColorField(lua, idx, "bright_black", &ansi_colors[8]);
    parseColorField(lua, idx, "bright_red", &ansi_colors[9]);
    parseColorField(lua, idx, "bright_green", &ansi_colors[10]);
    parseColorField(lua, idx, "bright_yellow", &ansi_colors[11]);
    parseColorField(lua, idx, "bright_blue", &ansi_colors[12]);
    parseColorField(lua, idx, "bright_magenta", &ansi_colors[13]);
    parseColorField(lua, idx, "bright_cyan", &ansi_colors[14]);
    parseColorField(lua, idx, "bright_white", &ansi_colors[15]);
}

fn parseThemePaletteTableNative(lua: *zlua.Lua, idx: i32, theme: *ThemeConfig) void {
    parseColorField(lua, idx, "background", &theme.background);
    parseColorField(lua, idx, "foreground", &theme.foreground);
    parseColorField(lua, idx, "selection", &theme.selection);
    parseColorField(lua, idx, "selection_background", &theme.selection);
    parseColorField(lua, idx, "selection-background", &theme.selection);
    parseColorField(lua, idx, "cursor", &theme.cursor);
    parseColorField(lua, idx, "link", &theme.link);
    parseColorField(lua, idx, "line_number", &theme.line_number);
    parseColorField(lua, idx, "line_number_bg", &theme.line_number_bg);
    parseColorField(lua, idx, "current_line", &theme.current_line);
    parseColorField(lua, idx, "ui_bar_bg", &theme.ui_bar_bg);
    parseColorField(lua, idx, "ui_panel_bg", &theme.ui_panel_bg);
    parseColorField(lua, idx, "ui_panel_overlay", &theme.ui_panel_overlay);
    parseColorField(lua, idx, "ui_hover", &theme.ui_hover);
    parseColorField(lua, idx, "ui_pressed", &theme.ui_pressed);
    parseColorField(lua, idx, "ui_tab_inactive_bg", &theme.ui_tab_inactive_bg);
    parseColorField(lua, idx, "ui_accent", &theme.ui_accent);
    parseColorField(lua, idx, "ui_border", &theme.ui_border);
    parseColorField(lua, idx, "ui_modified", &theme.ui_modified);
    parseColorField(lua, idx, "ui_text", &theme.ui_text);
    parseColorField(lua, idx, "ui_text_inactive", &theme.ui_text_inactive);
    parseColorField(lua, idx, "color0", &theme.ansi_colors[0]);
    parseColorField(lua, idx, "color1", &theme.ansi_colors[1]);
    parseColorField(lua, idx, "color2", &theme.ansi_colors[2]);
    parseColorField(lua, idx, "color3", &theme.ansi_colors[3]);
    parseColorField(lua, idx, "color4", &theme.ansi_colors[4]);
    parseColorField(lua, idx, "color5", &theme.ansi_colors[5]);
    parseColorField(lua, idx, "color6", &theme.ansi_colors[6]);
    parseColorField(lua, idx, "color7", &theme.ansi_colors[7]);
    parseColorField(lua, idx, "color8", &theme.ansi_colors[8]);
    parseColorField(lua, idx, "color9", &theme.ansi_colors[9]);
    parseColorField(lua, idx, "color10", &theme.ansi_colors[10]);
    parseColorField(lua, idx, "color11", &theme.ansi_colors[11]);
    parseColorField(lua, idx, "color12", &theme.ansi_colors[12]);
    parseColorField(lua, idx, "color13", &theme.ansi_colors[13]);
    parseColorField(lua, idx, "color14", &theme.ansi_colors[14]);
    parseColorField(lua, idx, "color15", &theme.ansi_colors[15]);
    parseNamedAnsiColors(lua, idx, &theme.ansi_colors);

    _ = lua.getField(idx, "ansi");
    if (lua.isTable(-1)) {
        const ansi_idx = lua.absIndex(-1);
        parseIndexedAnsiColors(lua, ansi_idx, &theme.ansi_colors);
        parseNamedAnsiColors(lua, ansi_idx, &theme.ansi_colors);
    }
    lua.pop(1);
}

fn parseThemeSyntaxTableNative(lua: *zlua.Lua, idx: i32, theme: *ThemeConfig) void {
    parseColorField(lua, idx, "comment", &theme.comment_color);
    parseColorField(lua, idx, "comment_color", &theme.comment_color);
    parseColorField(lua, idx, "string", &theme.string);
    parseColorField(lua, idx, "keyword", &theme.keyword);
    parseColorField(lua, idx, "number", &theme.number);
    parseColorField(lua, idx, "function", &theme.function);
    parseColorField(lua, idx, "variable", &theme.variable);
    parseColorField(lua, idx, "type_name", &theme.type_name);
    parseColorField(lua, idx, "operator", &theme.operator);
    parseColorField(lua, idx, "builtin", &theme.builtin_color);
    parseColorField(lua, idx, "builtin_color", &theme.builtin_color);
    parseColorField(lua, idx, "punctuation", &theme.punctuation);
    parseColorField(lua, idx, "constant", &theme.constant);
    parseColorField(lua, idx, "attribute", &theme.attribute);
    parseColorField(lua, idx, "namespace", &theme.namespace);
    parseColorField(lua, idx, "label", &theme.label);
    parseColorField(lua, idx, "error", &theme.error_token);
    parseColorField(lua, idx, "error_token", &theme.error_token);
    parseColorField(lua, idx, "preproc", &theme.preproc);
    parseColorField(lua, idx, "macro", &theme.macro);
    parseColorField(lua, idx, "escape", &theme.escape);
    parseColorField(lua, idx, "keyword_control", &theme.keyword_control);
    parseColorField(lua, idx, "function_method", &theme.function_method);
    parseColorField(lua, idx, "type_builtin", &theme.type_builtin);
    parseColorField(lua, idx, "keyword.control", &theme.keyword_control);
    parseColorField(lua, idx, "function.method", &theme.function_method);
    parseColorField(lua, idx, "type.builtin", &theme.type_builtin);
}

fn parseThemeFromTableNative(lua: *zlua.Lua, idx: i32) ThemeConfig {
    var theme: ThemeConfig = .{};
    const table_idx = lua.absIndex(idx);
    parseThemePaletteTableNative(lua, table_idx, &theme);
    parseThemeSyntaxTableNative(lua, table_idx, &theme);

    _ = lua.getField(table_idx, "palette");
    if (lua.isTable(-1)) parseThemePaletteTableNative(lua, lua.absIndex(-1), &theme);
    lua.pop(1);
    _ = lua.getField(table_idx, "syntax");
    if (lua.isTable(-1)) parseThemeSyntaxTableNative(lua, lua.absIndex(-1), &theme);
    lua.pop(1);
    return theme;
}

fn normalizeEditorThemeName(buf: *[96]u8, raw: []const u8) []const u8 {
    var in_idx: usize = if (raw.len > 0 and raw[0] == '@') 1 else 0;
    var out_idx: usize = 0;
    while (in_idx < raw.len and out_idx < buf.len) : (in_idx += 1) {
        var ch = raw[in_idx];
        if (ch >= 'A' and ch <= 'Z') ch = ch - 'A' + 'a';
        if (ch == '-' or ch == ' ') ch = '_';
        buf[out_idx] = ch;
        out_idx += 1;
    }
    return buf[0..out_idx];
}

fn themeColorSlotByEditorName(theme: *ThemeConfig, name: []const u8) ?*?Color {
    var normalized_buf: [96]u8 = undefined;
    const normalized = normalizeEditorThemeName(&normalized_buf, name);
    if (std.mem.eql(u8, normalized, "normal") or std.mem.eql(u8, normalized, "text")) return &theme.foreground;
    if (std.mem.eql(u8, normalized, "comment") or std.mem.startsWith(u8, normalized, "comment.")) return &theme.comment_color;
    if (std.mem.eql(u8, normalized, "string") or std.mem.eql(u8, normalized, "character")) return &theme.string;
    if (std.mem.eql(u8, normalized, "keyword") or std.mem.eql(u8, normalized, "statement")) return &theme.keyword;
    if (std.mem.eql(u8, normalized, "number")) return &theme.number;
    if (std.mem.eql(u8, normalized, "function") or std.mem.eql(u8, normalized, "constructor")) return &theme.function;
    if (std.mem.eql(u8, normalized, "variable") or std.mem.eql(u8, normalized, "identifier")) return &theme.variable;
    if (std.mem.eql(u8, normalized, "type") or std.mem.eql(u8, normalized, "typename")) return &theme.type_name;
    if (std.mem.eql(u8, normalized, "operator")) return &theme.operator;
    if (std.mem.eql(u8, normalized, "builtin")) return &theme.builtin_color;
    if (std.mem.eql(u8, normalized, "punctuation") or std.mem.startsWith(u8, normalized, "punctuation.")) return &theme.punctuation;
    if (std.mem.eql(u8, normalized, "constant") or std.mem.startsWith(u8, normalized, "constant.")) return &theme.constant;
    if (std.mem.eql(u8, normalized, "attribute") or std.mem.eql(u8, normalized, "tag.attribute")) return &theme.attribute;
    if (std.mem.eql(u8, normalized, "namespace") or std.mem.eql(u8, normalized, "module")) return &theme.namespace;
    if (std.mem.eql(u8, normalized, "label")) return &theme.label;
    if (std.mem.eql(u8, normalized, "error")) return &theme.error_token;
    if (std.mem.eql(u8, normalized, "preproc")) return &theme.preproc;
    if (std.mem.eql(u8, normalized, "macro")) return &theme.macro;
    if (std.mem.eql(u8, normalized, "escape")) return &theme.escape;
    if (std.mem.eql(u8, normalized, "keyword.control") or std.mem.eql(u8, normalized, "conditional") or std.mem.eql(u8, normalized, "repeat") or std.mem.eql(u8, normalized, "exception")) return &theme.keyword_control;
    if (std.mem.eql(u8, normalized, "function.method") or std.mem.eql(u8, normalized, "method")) return &theme.function_method;
    if (std.mem.eql(u8, normalized, "type.builtin")) return &theme.type_builtin;
    if (std.mem.eql(u8, normalized, "cursorline")) return &theme.current_line;
    if (std.mem.eql(u8, normalized, "visual") or std.mem.eql(u8, normalized, "selection")) return &theme.selection;
    if (std.mem.eql(u8, normalized, "linenr") or std.mem.eql(u8, normalized, "line_number")) return &theme.line_number;
    if (std.mem.eql(u8, normalized, "cursor")) return &theme.cursor;
    return null;
}

fn setThemeColorByEditorName(theme: *ThemeConfig, name: []const u8, color: Color) bool {
    const slot = themeColorSlotByEditorName(theme, name) orelse return false;
    slot.* = color;
    return true;
}

fn lookupThemeColorByEditorName(theme: *const ThemeConfig, name: []const u8) ?Color {
    var normalized_buf: [96]u8 = undefined;
    const normalized = normalizeEditorThemeName(&normalized_buf, name);
    if (std.mem.eql(u8, normalized, "normal") or std.mem.eql(u8, normalized, "text")) return theme.foreground;
    if (std.mem.eql(u8, normalized, "comment") or std.mem.startsWith(u8, normalized, "comment.")) return theme.comment_color;
    if (std.mem.eql(u8, normalized, "string") or std.mem.eql(u8, normalized, "character")) return theme.string;
    if (std.mem.eql(u8, normalized, "keyword") or std.mem.eql(u8, normalized, "statement")) return theme.keyword;
    if (std.mem.eql(u8, normalized, "number")) return theme.number;
    if (std.mem.eql(u8, normalized, "function") or std.mem.eql(u8, normalized, "constructor")) return theme.function;
    if (std.mem.eql(u8, normalized, "variable") or std.mem.eql(u8, normalized, "identifier")) return theme.variable;
    if (std.mem.eql(u8, normalized, "type") or std.mem.eql(u8, normalized, "typename")) return theme.type_name;
    if (std.mem.eql(u8, normalized, "operator")) return theme.operator;
    if (std.mem.eql(u8, normalized, "builtin")) return theme.builtin_color;
    if (std.mem.eql(u8, normalized, "punctuation") or std.mem.startsWith(u8, normalized, "punctuation.")) return theme.punctuation;
    if (std.mem.eql(u8, normalized, "constant") or std.mem.startsWith(u8, normalized, "constant.")) return theme.constant;
    if (std.mem.eql(u8, normalized, "attribute") or std.mem.eql(u8, normalized, "tag.attribute")) return theme.attribute;
    if (std.mem.eql(u8, normalized, "namespace") or std.mem.eql(u8, normalized, "module")) return theme.namespace;
    if (std.mem.eql(u8, normalized, "label")) return theme.label;
    if (std.mem.eql(u8, normalized, "error")) return theme.error_token;
    if (std.mem.eql(u8, normalized, "preproc")) return theme.preproc;
    if (std.mem.eql(u8, normalized, "macro")) return theme.macro;
    if (std.mem.eql(u8, normalized, "escape")) return theme.escape;
    if (std.mem.eql(u8, normalized, "keyword.control") or std.mem.eql(u8, normalized, "conditional") or std.mem.eql(u8, normalized, "repeat") or std.mem.eql(u8, normalized, "exception")) return theme.keyword_control;
    if (std.mem.eql(u8, normalized, "function.method") or std.mem.eql(u8, normalized, "method")) return theme.function_method;
    if (std.mem.eql(u8, normalized, "type.builtin")) return theme.type_builtin;
    if (std.mem.eql(u8, normalized, "cursorline")) return theme.current_line;
    if (std.mem.eql(u8, normalized, "visual") or std.mem.eql(u8, normalized, "selection")) return theme.selection;
    if (std.mem.eql(u8, normalized, "linenr") or std.mem.eql(u8, normalized, "line_number")) return theme.line_number;
    if (std.mem.eql(u8, normalized, "cursor")) return theme.cursor;
    return null;
}

fn parseEditorThemeColorFromValue(lua: *zlua.Lua, idx: i32) ?Color {
    if (parseColorFromValue(lua, idx)) |color| return color;
    if (!lua.isTable(idx)) return null;
    const table_idx = lua.absIndex(idx);
    inline for ([_][:0]const u8{ "fg", "foreground", "color", "bg", "background" }) |field| {
        _ = lua.getField(table_idx, field);
        if (parseColorFromValue(lua, -1)) |color| {
            lua.pop(1);
            return color;
        }
        lua.pop(1);
    }
    return null;
}

fn editorThemeLinkTargetFromValue(lua: *zlua.Lua, idx: i32) ?[]const u8 {
    if (lua.isString(idx)) {
        if (lua.toString(idx)) |text| {
            if (parseHexColor(text) != null) return null;
            return text;
        } else |_| return null;
    }
    if (!lua.isTable(idx)) return null;
    _ = lua.getField(idx, "link");
    if (lua.isString(-1)) {
        if (lua.toString(-1)) |target| {
            lua.pop(1);
            return target;
        } else |_| {}
    }
    lua.pop(1);
    return null;
}

fn captureNameMatches(key: []const u8, name: []const u8) bool {
    if (std.mem.eql(u8, key, name)) return true;
    if (key.len > 0 and key[0] == '@' and std.mem.eql(u8, key[1..], name)) return true;
    if (name.len > 0 and name[0] == '@' and std.mem.eql(u8, key, name[1..])) return true;
    return false;
}

fn resolveEditorThemeColorFromSection(lua: *zlua.Lua, theme_idx: i32, section_name: [:0]const u8, theme: *const ThemeConfig, name: []const u8, depth: u8) ?Color {
    _ = lua.getField(theme_idx, section_name);
    if (!lua.isTable(-1)) {
        lua.pop(1);
        return null;
    }
    const section_idx = lua.absIndex(-1);
    var color: ?Color = null;
    lua.pushNil();
    while (lua.next(section_idx)) {
        defer lua.pop(1);
        if (!lua.isString(-2)) continue;
        if (lua.toString(-2)) |source_name| {
            if (!captureNameMatches(source_name, name)) continue;
            color = parseEditorThemeColorFromValue(lua, -1);
            if (color == null) {
                if (editorThemeLinkTargetFromValue(lua, -1)) |target_name| color = resolveEditorThemeColor(lua, theme_idx, theme, target_name, depth);
            }
            break;
        } else |_| {}
    }
    lua.pop(1);
    return color;
}

fn resolveEditorThemeColor(lua: *zlua.Lua, theme_idx: i32, theme: *const ThemeConfig, name: []const u8, depth: u8) ?Color {
    if (depth >= 12 or name.len == 0) return null;
    if (lookupThemeColorByEditorName(theme, name)) |color| return color;
    if (resolveEditorThemeColorFromSection(lua, theme_idx, "captures", theme, name, depth + 1)) |color| return color;
    if (resolveEditorThemeColorFromSection(lua, theme_idx, "groups", theme, name, depth + 1)) |color| return color;
    if (resolveEditorThemeColorFromSection(lua, theme_idx, "links", theme, name, depth + 1)) |color| return color;
    return null;
}

fn applyEditorThemeColorSection(lua: *zlua.Lua, theme_idx: i32, section_name: [:0]const u8, theme: *ThemeConfig) void {
    _ = lua.getField(theme_idx, section_name);
    if (!lua.isTable(-1)) {
        lua.pop(1);
        return;
    }
    const section_idx = lua.absIndex(-1);
    lua.pushNil();
    while (lua.next(section_idx)) {
        defer lua.pop(1);
        if (!lua.isString(-2)) continue;
        if (lua.toString(-2)) |source_name| {
            if (parseEditorThemeColorFromValue(lua, -1)) |color| _ = setThemeColorByEditorName(theme, source_name, color);
        } else |_| {}
    }
    lua.pop(1);
}

fn applyEditorThemeLinkSection(lua: *zlua.Lua, theme_idx: i32, section_name: [:0]const u8, theme: *ThemeConfig) void {
    _ = lua.getField(theme_idx, section_name);
    if (!lua.isTable(-1)) {
        lua.pop(1);
        return;
    }
    const section_idx = lua.absIndex(-1);
    lua.pushNil();
    while (lua.next(section_idx)) {
        defer lua.pop(1);
        if (!lua.isString(-2)) continue;
        if (lua.toString(-2)) |source_name| {
            if (editorThemeLinkTargetFromValue(lua, -1)) |target_name| {
                if (resolveEditorThemeColor(lua, theme_idx, theme, target_name, 0)) |color| _ = setThemeColorByEditorName(theme, source_name, color);
            }
        } else |_| {}
    }
    lua.pop(1);
}

fn applyEditorThemeSchemaNative(lua: *zlua.Lua, idx: i32, theme: *ThemeConfig) void {
    const theme_idx = lua.absIndex(idx);
    applyEditorThemeColorSection(lua, theme_idx, "groups", theme);
    applyEditorThemeColorSection(lua, theme_idx, "captures", theme);
    applyEditorThemeLinkSection(lua, theme_idx, "links", theme);
    applyEditorThemeLinkSection(lua, theme_idx, "groups", theme);
    applyEditorThemeLinkSection(lua, theme_idx, "captures", theme);
}

pub fn parseEditorThemeAtStackIndex(lua: *zlua.Lua, idx: i32) ?ThemeConfig {
    if (!lua.isTable(idx)) return null;
    var parsed = parseThemeFromTableNative(lua, idx);
    applyEditorThemeSchemaNative(lua, idx, &parsed);
    return parsed;
}

pub fn parseThemeAtStackIndex(lua: *zlua.Lua, idx: i32) LuaConfigError!?ThemeConfig {
    if (!lua.isTable(idx)) return null;
    return parseThemeFromTableNative(lua, idx);
}
