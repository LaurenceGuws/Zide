const std = @import("std");
const iface = @import("./lua_config_iface.zig");
const input_actions = @import("../input/input_actions.zig");

pub const Config = iface.Config;
pub const Theme = iface.Theme;
pub const ThemeConfig = iface.ThemeConfig;

pub fn fileExists(path: []const u8) bool {
    if (std.fs.cwd().openFile(path, .{})) |file| {
        file.close();
        return true;
    } else |_| {
        return false;
    }
}

pub fn findUserConfigPath(allocator: std.mem.Allocator) iface.LuaConfigError!?[]u8 {
    switch (@import("builtin").target.os.tag) {
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

pub fn emptyConfig() Config {
    return .{
        .log_file_filter = null,
        .log_console_filter = null,
        .log_file_level = null,
        .log_console_level = null,
        .sdl_log_level = null,
        .editor_wrap = null,
        .editor_large_jump_rows = null,
        .editor_highlight_budget = null,
        .editor_width_budget = null,
        .selection_overlay_smooth = null,
        .selection_overlay_corner_px = null,
        .selection_overlay_pad_px = null,
        .editor_selection_overlay_smooth = null,
        .editor_selection_overlay_corner_px = null,
        .editor_selection_overlay_pad_px = null,
        .terminal_selection_overlay_smooth = null,
        .terminal_selection_overlay_corner_px = null,
        .terminal_selection_overlay_pad_px = null,
        .app_font_path = null,
        .app_font_size = null,
        .editor_font_path = null,
        .editor_font_size = null,
        .editor_font_features = null,
        .editor_disable_ligatures = null,
        .terminal_font_path = null,
        .terminal_font_size = null,
        .terminal_blink_style = null,
        .terminal_disable_ligatures = null,
        .terminal_font_features = null,
        .terminal_default_start_location = null,
        .terminal_new_tab_start_location = null,
        .terminal_scrollback_rows = null,
        .terminal_cursor_shape = null,
        .terminal_cursor_blink = null,
        .editor_tab_bar_width_mode = null,
        .terminal_tab_bar_show_single_tab = null,
        .terminal_tab_bar_width_mode = null,
        .terminal_focus_report_window = null,
        .terminal_focus_report_pane = null,
        .font_lcd = null,
        .font_hinting = null,
        .font_autohint = null,
        .font_glyph_overflow = null,
        .text_gamma = null,
        .text_contrast = null,
        .text_linear_correction = null,
        .theme = null,
        .app_theme = null,
        .editor_theme = null,
        .terminal_theme = null,
        .keybinds_no_defaults = null,
        .keybinds = null,
    };
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
    if (config.app_font_path) |path| {
        allocator.free(path);
        config.app_font_path = null;
    }
    if (config.editor_font_path) |path| {
        allocator.free(path);
        config.editor_font_path = null;
    }
    if (config.editor_font_features) |features| {
        allocator.free(features);
        config.editor_font_features = null;
    }
    if (config.terminal_font_path) |path| {
        allocator.free(path);
        config.terminal_font_path = null;
    }
    if (config.terminal_font_features) |features| {
        allocator.free(features);
        config.terminal_font_features = null;
    }
    if (config.terminal_default_start_location) |path| {
        allocator.free(path);
        config.terminal_default_start_location = null;
    }
    config.terminal_new_tab_start_location = null;
    if (config.keybinds) |binds| {
        allocator.free(binds);
        config.keybinds = null;
    }

    config.keybinds_no_defaults = null;

    config.font_lcd = null;
    config.font_hinting = null;
    config.font_autohint = null;
    config.font_glyph_overflow = null;
    config.text_gamma = null;
    config.text_contrast = null;
    config.text_linear_correction = null;
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
    if (overlay.ui_bar_bg) |color| base.ui_bar_bg = color;
    if (overlay.ui_panel_bg) |color| base.ui_panel_bg = color;
    if (overlay.ui_panel_overlay) |color| base.ui_panel_overlay = color;
    if (overlay.ui_hover) |color| base.ui_hover = color;
    if (overlay.ui_pressed) |color| base.ui_pressed = color;
    if (overlay.ui_tab_inactive_bg) |color| base.ui_tab_inactive_bg = color;
    if (overlay.ui_accent) |color| base.ui_accent = color;
    if (overlay.ui_border) |color| base.ui_border = color;
    if (overlay.ui_modified) |color| base.ui_modified = color;
    if (overlay.ui_text) |color| base.ui_text = color;
    if (overlay.ui_text_inactive) |color| base.ui_text_inactive = color;
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
    if (overlay.preproc) |color| base.preproc = color;
    if (overlay.macro) |color| base.macro = color;
    if (overlay.escape) |color| base.escape = color;
    if (overlay.keyword_control) |color| base.keyword_control = color;
    if (overlay.function_method) |color| base.function_method = color;
    if (overlay.type_builtin) |color| base.type_builtin = color;
    for (0..16) |i| {
        if (overlay.ansi_colors[i]) |color| base.ansi_colors[i] = color;
    }
}

fn sameBindingIdentity(a: input_actions.BindSpec, b: input_actions.BindSpec) bool {
    return a.scope == b.scope and
        a.key == b.key and
        a.mods.shift == b.mods.shift and
        a.mods.alt == b.mods.alt and
        a.mods.ctrl == b.mods.ctrl and
        a.mods.super == b.mods.super;
}

fn mergeKeybinds(
    allocator: std.mem.Allocator,
    base: []input_actions.BindSpec,
    overlay: []const input_actions.BindSpec,
) ![]input_actions.BindSpec {
    var merged = try allocator.dupe(input_actions.BindSpec, base);
    for (overlay) |incoming| {
        var replaced = false;
        for (merged, 0..) |*existing, i| {
            if (sameBindingIdentity(existing.*, incoming)) {
                _ = i;
                existing.* = incoming;
                replaced = true;
                break;
            }
        }
        if (!replaced) {
            const old = merged;
            merged = try allocator.alloc(input_actions.BindSpec, old.len + 1);
            @memcpy(merged[0..old.len], old);
            merged[old.len] = incoming;
            allocator.free(old);
        }
    }
    return merged;
}

pub fn mergeConfig(allocator: std.mem.Allocator, base: *Config, overlay: Config) void {
    if (overlay.log_file_filter) |filter| {
        if (base.log_file_filter) |old| allocator.free(old);
        base.log_file_filter = allocator.dupe(u8, filter) catch base.log_file_filter;
    }
    if (overlay.log_console_filter) |filter| {
        if (base.log_console_filter) |old| allocator.free(old);
        base.log_console_filter = allocator.dupe(u8, filter) catch base.log_console_filter;
    }
    if (overlay.log_file_level) |level| base.log_file_level = level;
    if (overlay.log_console_level) |level| base.log_console_level = level;
    if (overlay.sdl_log_level) |level| base.sdl_log_level = level;
    if (overlay.editor_wrap != null) base.editor_wrap = overlay.editor_wrap;
    if (overlay.editor_large_jump_rows != null) base.editor_large_jump_rows = overlay.editor_large_jump_rows;
    if (overlay.editor_highlight_budget != null) base.editor_highlight_budget = overlay.editor_highlight_budget;
    if (overlay.editor_width_budget != null) base.editor_width_budget = overlay.editor_width_budget;
    if (overlay.selection_overlay_smooth != null) base.selection_overlay_smooth = overlay.selection_overlay_smooth;
    if (overlay.selection_overlay_corner_px != null) base.selection_overlay_corner_px = overlay.selection_overlay_corner_px;
    if (overlay.selection_overlay_pad_px != null) base.selection_overlay_pad_px = overlay.selection_overlay_pad_px;
    if (overlay.editor_selection_overlay_smooth != null) base.editor_selection_overlay_smooth = overlay.editor_selection_overlay_smooth;
    if (overlay.editor_selection_overlay_corner_px != null) base.editor_selection_overlay_corner_px = overlay.editor_selection_overlay_corner_px;
    if (overlay.editor_selection_overlay_pad_px != null) base.editor_selection_overlay_pad_px = overlay.editor_selection_overlay_pad_px;
    if (overlay.terminal_selection_overlay_smooth != null) base.terminal_selection_overlay_smooth = overlay.terminal_selection_overlay_smooth;
    if (overlay.terminal_selection_overlay_corner_px != null) base.terminal_selection_overlay_corner_px = overlay.terminal_selection_overlay_corner_px;
    if (overlay.terminal_selection_overlay_pad_px != null) base.terminal_selection_overlay_pad_px = overlay.terminal_selection_overlay_pad_px;
    if (overlay.app_font_path) |path| {
        if (base.app_font_path) |old| allocator.free(old);
        base.app_font_path = allocator.dupe(u8, path) catch base.app_font_path;
    }
    if (overlay.app_font_size != null) base.app_font_size = overlay.app_font_size;
    if (overlay.editor_font_path) |path| {
        if (base.editor_font_path) |old| allocator.free(old);
        base.editor_font_path = allocator.dupe(u8, path) catch base.editor_font_path;
    }
    if (overlay.editor_font_size != null) base.editor_font_size = overlay.editor_font_size;
    if (overlay.editor_font_features) |features| {
        if (base.editor_font_features) |old| allocator.free(old);
        base.editor_font_features = allocator.dupe(u8, features) catch base.editor_font_features;
    }
    if (overlay.editor_disable_ligatures != null) base.editor_disable_ligatures = overlay.editor_disable_ligatures;
    if (overlay.terminal_font_path) |path| {
        if (base.terminal_font_path) |old| allocator.free(old);
        base.terminal_font_path = allocator.dupe(u8, path) catch base.terminal_font_path;
    }
    if (overlay.terminal_font_size != null) base.terminal_font_size = overlay.terminal_font_size;
    if (overlay.terminal_blink_style != null) base.terminal_blink_style = overlay.terminal_blink_style;
    if (overlay.terminal_disable_ligatures != null) base.terminal_disable_ligatures = overlay.terminal_disable_ligatures;
    if (overlay.terminal_font_features) |features| {
        if (base.terminal_font_features) |old| allocator.free(old);
        base.terminal_font_features = allocator.dupe(u8, features) catch base.terminal_font_features;
    }
    if (overlay.terminal_default_start_location) |path| {
        if (base.terminal_default_start_location) |old| allocator.free(old);
        base.terminal_default_start_location = allocator.dupe(u8, path) catch base.terminal_default_start_location;
    }
    if (overlay.terminal_new_tab_start_location != null) base.terminal_new_tab_start_location = overlay.terminal_new_tab_start_location;
    if (overlay.terminal_scrollback_rows != null) base.terminal_scrollback_rows = overlay.terminal_scrollback_rows;
    if (overlay.terminal_cursor_shape != null) base.terminal_cursor_shape = overlay.terminal_cursor_shape;
    if (overlay.terminal_cursor_blink != null) base.terminal_cursor_blink = overlay.terminal_cursor_blink;
    if (overlay.editor_tab_bar_width_mode != null) base.editor_tab_bar_width_mode = overlay.editor_tab_bar_width_mode;
    if (overlay.terminal_tab_bar_show_single_tab != null) base.terminal_tab_bar_show_single_tab = overlay.terminal_tab_bar_show_single_tab;
    if (overlay.terminal_tab_bar_width_mode != null) base.terminal_tab_bar_width_mode = overlay.terminal_tab_bar_width_mode;
    if (overlay.terminal_focus_report_window != null) base.terminal_focus_report_window = overlay.terminal_focus_report_window;
    if (overlay.terminal_focus_report_pane != null) base.terminal_focus_report_pane = overlay.terminal_focus_report_pane;
    if (overlay.font_lcd != null) base.font_lcd = overlay.font_lcd;
    if (overlay.font_hinting != null) base.font_hinting = overlay.font_hinting;
    if (overlay.font_autohint != null) base.font_autohint = overlay.font_autohint;
    if (overlay.font_glyph_overflow != null) base.font_glyph_overflow = overlay.font_glyph_overflow;
    if (overlay.text_gamma != null) base.text_gamma = overlay.text_gamma;
    if (overlay.text_contrast != null) base.text_contrast = overlay.text_contrast;
    if (overlay.text_linear_correction != null) base.text_linear_correction = overlay.text_linear_correction;
    if (overlay.theme) |overlay_theme| {
        if (base.theme) |base_theme| {
            var merged = base_theme;
            mergeThemeConfig(&merged, overlay_theme);
            base.theme = merged;
        } else base.theme = overlay_theme;
    }
    if (overlay.app_theme) |overlay_theme| {
        if (base.app_theme) |base_theme| {
            var merged = base_theme;
            mergeThemeConfig(&merged, overlay_theme);
            base.app_theme = merged;
        } else base.app_theme = overlay_theme;
    }
    if (overlay.editor_theme) |overlay_theme| {
        if (base.editor_theme) |base_theme| {
            var merged = base_theme;
            mergeThemeConfig(&merged, overlay_theme);
            base.editor_theme = merged;
        } else base.editor_theme = overlay_theme;
    }
    if (overlay.terminal_theme) |overlay_theme| {
        if (base.terminal_theme) |base_theme| {
            var merged = base_theme;
            mergeThemeConfig(&merged, overlay_theme);
            base.terminal_theme = merged;
        } else base.terminal_theme = overlay_theme;
    }
    if (overlay.keybinds) |binds| {
        if (overlay.keybinds_no_defaults == true or base.keybinds == null) {
            if (base.keybinds) |old| allocator.free(old);
            base.keybinds = allocator.dupe(input_actions.BindSpec, binds) catch base.keybinds;
        } else if (base.keybinds) |base_binds| {
            const merged = mergeKeybinds(allocator, base_binds, binds) catch base_binds;
            if (merged.ptr != base_binds.ptr) allocator.free(base_binds);
            base.keybinds = merged;
        }
    }
    if (overlay.keybinds_no_defaults != null) base.keybinds_no_defaults = overlay.keybinds_no_defaults;
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
    if (overlay.ui_bar_bg) |color| theme.ui_bar_bg = color;
    if (overlay.ui_panel_bg) |color| theme.ui_panel_bg = color;
    if (overlay.ui_panel_overlay) |color| theme.ui_panel_overlay = color;
    if (overlay.ui_hover) |color| theme.ui_hover = color;
    if (overlay.ui_pressed) |color| theme.ui_pressed = color;
    if (overlay.ui_tab_inactive_bg) |color| theme.ui_tab_inactive_bg = color;
    if (overlay.ui_accent) |color| theme.ui_accent = color;
    if (overlay.ui_border) |color| theme.ui_border = color;
    if (overlay.ui_modified) |color| theme.ui_modified = color;
    if (overlay.ui_text) |color| theme.ui_text = color;
    if (overlay.ui_text_inactive) |color| theme.ui_text_inactive = color;
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
    if (overlay.preproc) |color| theme.preproc = color;
    if (overlay.macro) |color| theme.macro = color;
    if (overlay.escape) |color| theme.escape = color;
    if (overlay.keyword_control) |color| theme.keyword_control = color;
    if (overlay.function_method) |color| theme.function_method = color;
    if (overlay.type_builtin) |color| theme.type_builtin = color;
    if (theme.ansi_colors) |*colors| {
        for (0..16) |i| {
            if (overlay.ansi_colors[i]) |color| colors[i] = color;
        }
    } else {
        var has_any = false;
        for (0..16) |i| {
            if (overlay.ansi_colors[i] != null) has_any = true;
        }
        if (has_any) {
            var colors = [_]iface.Color{.{ .r = 0, .g = 0, .b = 0 }} ** 16;
            for (0..16) |i| {
                if (overlay.ansi_colors[i]) |color| colors[i] = color;
            }
            theme.ansi_colors = colors;
        }
    }
}
