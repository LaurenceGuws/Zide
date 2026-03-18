const std = @import("std");
const app_logger = @import("../../app_logger.zig");
const app_terminal_theme_apply = @import("../terminal/terminal_theme_apply.zig");
const app_theme_utils = @import("../theme_utils.zig");
const config_mod = @import("../../config/lua_config.zig");

const imported_themes = [_][]const u8{
    "ayu",
    "kanagawa-dragon",
    "tokyonight-night",
};

fn findThemeIndex(name: ?[]const u8) usize {
    if (name) |value| {
        for (imported_themes, 0..) |theme_name, idx| {
            if (std.mem.eql(u8, theme_name, value)) return idx;
        }
    }
    return imported_themes.len - 1;
}

fn applyThemeByIndex(state: anytype, idx: usize) !void {
    const log = app_logger.logger("editor.imported_theme");
    const next_name = imported_themes[idx];
    const theme_path = try std.fmt.allocPrint(state.allocator, "assets/themes/{s}.lua", .{next_name});
    defer state.allocator.free(theme_path);

    var config = try config_mod.loadConfigFile(state.allocator, theme_path);
    defer config_mod.freeConfig(state.allocator, &config);

    const resolved = app_theme_utils.resolveConfigThemes(state.shell_base_theme, &config);
    const app_theme_changed = !std.meta.eql(state.app_theme, resolved.app);
    const editor_theme_changed = !std.meta.eql(state.editor_theme, resolved.editor);
    const terminal_theme_changed = !std.meta.eql(state.terminal_theme, resolved.terminal);

    state.app_theme = resolved.app;
    state.editor_theme = resolved.editor;
    state.terminal_theme = resolved.terminal;

    if (state.editor_imported_theme_name) |old| state.allocator.free(old);
    state.editor_imported_theme_name = try state.allocator.dupe(u8, next_name);

    if (app_theme_changed) {
        state.shell.setTheme(state.app_theme);
    } else {
        state.shell.setTheme(state.app_theme);
    }
    if (editor_theme_changed) {
        state.editor_render_cache.clear();
        state.editor_cluster_cache.clear();
    }
    if (terminal_theme_changed) {
        try app_terminal_theme_apply.notifyColorSchemeChanged(&state.terminal_widgets, &state.terminal_theme);
        app_terminal_theme_apply.applyThemeToWidgets(&state.terminal_widgets, &state.terminal_theme);
    }

    state.needs_redraw = true;
    log.logf(.info, "cycled imported theme name={s}", .{next_name});
}

pub fn cycleNext(state: anytype) !void {
    const current_idx = findThemeIndex(state.editor_imported_theme_name);
    const next_idx = (current_idx + 1) % imported_themes.len;
    try applyThemeByIndex(state, next_idx);
}

pub fn cyclePrev(state: anytype) !void {
    const current_idx = findThemeIndex(state.editor_imported_theme_name);
    const prev_idx = if (current_idx == 0) imported_themes.len - 1 else current_idx - 1;
    try applyThemeByIndex(state, prev_idx);
}
