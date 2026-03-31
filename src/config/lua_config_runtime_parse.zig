const std = @import("std");
const zlua = @import("zlua");
const zlua_portable = @import("zlua_portable");
const iface = @import("./lua_config_iface.zig");

const Config = iface.Config;
const TabBarWidthMode = std.meta.Child(@TypeOf((@as(Config, undefined)).editor_tab_bar_width_mode));
const CursorShape = std.meta.Child(@TypeOf((@as(Config, undefined)).terminal_cursor_shape));
const TerminalBlinkStyle = std.meta.Child(@TypeOf((@as(Config, undefined)).terminal_blink_style));
const LigatureStrategy = std.meta.Child(@TypeOf((@as(Config, undefined)).terminal_disable_ligatures));
const TerminalNewTabStartLocationMode = std.meta.Child(@TypeOf((@as(Config, undefined)).terminal_new_tab_start_location));
const TerminalWindowChromeMode = std.meta.Child(@TypeOf((@as(Config, undefined)).terminal_window_chrome_mode));
const terminal_scrollback_default: usize = 1000;
const terminal_scrollback_min: usize = 100;
const terminal_scrollback_max: usize = 100000;

pub const SelectionOverlayPrefix = enum {
    global,
    editor,
    terminal,
};

pub fn parseTabBarWidthModeFromString(value: []const u8) ?TabBarWidthMode {
    if (std.mem.eql(u8, value, "fixed")) return .fixed;
    if (std.mem.eql(u8, value, "dynamic")) return .dynamic;
    if (std.mem.eql(u8, value, "label_length")) return .label_length;
    return null;
}

pub fn parseCursorShapeFromString(value: []const u8) ?CursorShape {
    if (std.mem.eql(u8, value, "block")) return .block;
    if (std.mem.eql(u8, value, "bar")) return .bar;
    if (std.mem.eql(u8, value, "underline")) return .underline;
    return null;
}

pub fn parseBlinkStyleFromString(value: []const u8) ?TerminalBlinkStyle {
    if (std.mem.eql(u8, value, "kitty")) return .kitty;
    if (std.mem.eql(u8, value, "off")) return .off;
    if (std.mem.eql(u8, value, "ghostty")) return .off;
    return null;
}

pub fn parseLigatureStrategyFromString(value: []const u8) ?LigatureStrategy {
    if (std.mem.eql(u8, value, "never")) return .never;
    if (std.mem.eql(u8, value, "cursor")) return .cursor;
    if (std.mem.eql(u8, value, "always")) return .always;
    return null;
}

pub fn parseTerminalNewTabStartLocationModeFromString(value: []const u8) ?TerminalNewTabStartLocationMode {
    if (std.mem.eql(u8, value, "current")) return .current;
    if (std.mem.eql(u8, value, "default")) return .default;
    return null;
}

pub fn parseTerminalWindowChromeModeFromString(value: []const u8) ?TerminalWindowChromeMode {
    if (std.mem.eql(u8, value, "native")) return .native;
    if (std.mem.eql(u8, value, "integrated")) return .integrated;
    return null;
}

pub fn normalizeScrollback(value: i64) usize {
    if (value < @as(i64, @intCast(terminal_scrollback_min)) or value > @as(i64, @intCast(terminal_scrollback_max))) {
        return terminal_scrollback_default;
    }
    return @intCast(value);
}

pub fn parsePositiveF32(lua: *zlua.Lua, idx: i32) ?f32 {
    const state = zlua_portable.api.State.fromRaw(@ptrCast(lua));
    if (!state.isNumber(idx)) return null;
    const v = state.readNumber(idx);
    if (v > 0) return @floatCast(v);
    return null;
}

pub fn parseSelectionOverlayTable(
    lua: *zlua.Lua,
    idx: i32,
    out: *Config,
    prefix: SelectionOverlayPrefix,
) void {
    const state = zlua_portable.api.State.fromRaw(@ptrCast(lua));
    if (!state.isTable(idx)) return;
    const reader = zlua_portable.reader.Reader.init(state, std.heap.page_allocator, idx);

    if (reader.boolField("smooth")) |value| {
        switch (prefix) {
            .global => out.selection_overlay_smooth = value,
            .editor => out.editor_selection_overlay_smooth = value,
            .terminal => out.terminal_selection_overlay_smooth = value,
        }
    }

    if (reader.numberField("corner_px")) |raw_value| {
        const value: f32 = @floatCast(raw_value);
        if (value > 0) switch (prefix) {
            .global => out.selection_overlay_corner_px = value,
            .editor => out.editor_selection_overlay_corner_px = value,
            .terminal => out.terminal_selection_overlay_corner_px = value,
        };
    }

    if (reader.numberField("pad_px")) |raw_value| {
        const value: f32 = @floatCast(raw_value);
        if (value > 0) switch (prefix) {
            .global => out.selection_overlay_pad_px = value,
            .editor => out.editor_selection_overlay_pad_px = value,
            .terminal => out.terminal_selection_overlay_pad_px = value,
        };
    }
}
