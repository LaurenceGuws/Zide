const std = @import("std");
const app_logger = @import("../app_logger.zig");
const app_shell = @import("../app_shell.zig");
const app_config_runtime_common = @import("config_runtime_common.zig");
const app_font_rendering = @import("font_rendering.zig");
const app_tab_bar_width = @import("tabs/tab_bar_width.zig");
const app_terminal_shell_icon_runtime = @import("terminal/terminal_shell_icon_runtime.zig");
const app_terminal_theme_apply = @import("terminal/terminal_theme_apply.zig");
const app_theme_utils = @import("theme_utils.zig");
const config_mod = @import("../config/lua_config.zig");
const manual_highlights_mod = @import("../editor/manual_highlights.zig");
const term_types = @import("../terminal/model/types.zig");
const app_types = @import("app_state_types.zig");

fn mapTerminalNewTabStartLocationMode(mode: ?config_mod.TerminalNewTabStartLocationMode) app_types.TerminalNewTabStartLocationMode {
    return switch (mode orelse .current) {
        .current => .current,
        .default => .default,
    };
}

fn mapTerminalWindowChromeMode(mode: ?config_mod.TerminalWindowChromeMode) app_types.TerminalWindowChromeMode {
    return mode orelse .native;
}

fn shellIconMappingsEqual(
    a: ?[]const app_types.TerminalShellIconMapping,
    b: ?[]const app_types.TerminalShellIconMapping,
) bool {
    const a_slice = a orelse return b == null;
    const b_slice = b orelse return false;
    if (a_slice.len != b_slice.len) return false;
    for (a_slice, b_slice) |lhs, rhs| {
        if (!std.mem.eql(u8, lhs.shell, rhs.shell)) return false;
        if (!std.mem.eql(u8, lhs.icon_path, rhs.icon_path)) return false;
    }
    return true;
}

fn applyResolvedThemes(state: anytype, config: *const config_mod.Config) !void {
    const resolved_themes = app_theme_utils.resolveConfigThemes(state.shell_base_theme, config);
    const app_theme_changed = !std.meta.eql(state.app_theme, resolved_themes.app);
    const editor_theme_changed = !std.meta.eql(state.editor_theme, resolved_themes.editor);
    const terminal_theme_changed = !std.meta.eql(state.terminal_theme, resolved_themes.terminal);

    if (!(app_theme_changed or editor_theme_changed or terminal_theme_changed)) return;

    state.app_theme = resolved_themes.app;
    state.editor_theme = resolved_themes.editor;
    state.terminal_theme = resolved_themes.terminal;

    if (app_theme_changed) {
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
}

fn applyFontReload(state: anytype, ctx: *anyopaque, hooks: Hooks, config: *const config_mod.Config, log: app_logger.Logger) !void {
    const font_reload = try app_font_rendering.applyRendererReloadConfig(state.shell, config);
    if (font_reload.rebuilt_fonts) {
        state.editor_render_cache.clear();
        state.editor_cluster_cache.clear();
        try hooks.refresh_terminal_sizing(ctx);
        state.needs_redraw = true;
        log.logStdout(.info, "reload font renderer path/size/rendering changed choice={any} rendering={any} text={any}", .{
            font_reload.font_choice_changed,
            font_reload.font_rendering_changed,
            font_reload.text_rendering_changed,
        });
    } else if (font_reload.text_rendering_changed) {
        state.needs_redraw = true;
        log.logStdout(.info, "reload font renderer text controls changed", .{});
    }
}

fn reloadShellIcons(state: anytype, config: *const config_mod.Config, log: app_logger.Logger) !void {
    const next_show_shell_icon = config.terminal_tab_bar_show_shell_icon orelse state.terminal_tab_bar_show_shell_icon;
    const next_shell_icons = try app_terminal_shell_icon_runtime.dupMappings(
        state.allocator,
        config.terminal_tab_bar_shell_icons,
    );
    const changed = next_show_shell_icon != state.terminal_tab_bar_show_shell_icon or
        !shellIconMappingsEqual(state.terminal_tab_bar_shell_icons, next_shell_icons);
    if (changed) {
        state.terminal_tab_bar_show_shell_icon = next_show_shell_icon;
        app_terminal_shell_icon_runtime.freeMappings(state.allocator, state.terminal_tab_bar_shell_icons);
        state.terminal_tab_bar_shell_icons = next_shell_icons;
        state.tab_bar.clearTabIcons();
        state.terminal_shell_icon_cache.clear(state.shell.rendererPtr());
        state.needs_redraw = true;
        log.logStdout(.info, "reload terminal.tab_bar.show_shell_icon={any}", .{
            state.terminal_tab_bar_show_shell_icon,
        });
    } else {
        app_terminal_shell_icon_runtime.freeMappings(state.allocator, next_shell_icons);
    }
}

pub const Hooks = struct {
    refresh_terminal_sizing: *const fn (*anyopaque) anyerror!void,
    apply_current_tab_bar_width_mode: *const fn (*anyopaque) void,
};

pub fn handle(state: anytype, ctx: *anyopaque, hooks: Hooks) !void {
    const log = app_logger.logger("config.reload");
    var config = try config_mod.loadConfig(state.allocator);
    defer config_mod.freeConfig(state.allocator, &config);

    try manual_highlights_mod.applyConfig(state.allocator, &config);

    app_config_runtime_common.applyLoggerConfig(&config, "reload");
    if (config.sdl_log_level) |level| {
        app_shell.setSdlLogLevel(level);
    }
    if (state.editor_imported_theme_name) |old| {
        state.allocator.free(old);
        state.editor_imported_theme_name = null;
    }
    if (config.editor_imported_theme_name) |name| {
        state.editor_imported_theme_name = try state.allocator.dupe(u8, name);
    }
    try applyResolvedThemes(state, &config);

    state.editor_wrap = config.editor_wrap orelse state.editor_wrap;
    state.editor_large_jump_rows = config.editor_large_jump_rows orelse state.editor_large_jump_rows;
    if (config.editor_highlight_budget != null) {
        state.editor_highlight_budget = config.editor_highlight_budget;
    }
    if (config.editor_width_budget != null) {
        state.editor_width_budget = config.editor_width_budget;
    }

    if (config.keybinds) |binds| {
        state.input_router.setBindings(binds);
    }

    try applyFontReload(state, ctx, hooks, &config, log);

    if (config.terminal_blink_style) |blink_style| {
        state.terminal_blink_style = switch (blink_style) {
            .kitty => .kitty,
            .off => .off,
        };
        for (state.terminal_widgets.items) |*widget| {
            widget.blink_style = state.terminal_blink_style;
        }
    }

    if (config.terminal_disable_ligatures != null or config.terminal_font_features != null) {
        state.shell.rendererPtr().setTerminalLigatureConfig(
            if (config.terminal_disable_ligatures) |v| switch (v) {
                .never => .never,
                .cursor => .cursor,
                .always => .always,
            } else null,
            config.terminal_font_features,
        );
        state.needs_redraw = true;
        log.logStdout(.info, "reload terminal ligatures strategy={s} features={s}", .{
            if (config.terminal_disable_ligatures) |v| @tagName(v) else "(unchanged)",
            config.terminal_font_features orelse "(unchanged)",
        });
    }

    if (config.terminal_texture_shift) |enabled| {
        state.shell.rendererPtr().setTerminalTextureShiftEnabled(enabled);
        state.needs_redraw = true;
        log.logStdout(.info, "reload terminal.texture_shift={any}", .{enabled});
    }

    if (config.terminal_recent_input_force_full != null or config.terminal_recent_input_force_full_ms != null) {
        state.shell.rendererPtr().setTerminalRecentInputFullPublicationPolicy(
            config.terminal_recent_input_force_full orelse state.shell.rendererPtr().terminalRecentInputFullPublicationConfiguredEnabled(),
            config.terminal_recent_input_force_full_ms,
        );
        state.needs_redraw = true;
        log.logStdout(.info, "reload terminal.presentation recent_input_force_full={any} recent_input_force_full_ms={d}", .{
            state.shell.rendererPtr().terminalRecentInputFullPublicationEnabled(),
            state.shell.rendererPtr().terminalRecentInputFullPublicationWindowMs(),
        });
    }

    if (config.editor_disable_ligatures != null or config.editor_font_features != null) {
        state.shell.rendererPtr().setEditorLigatureConfig(
            if (config.editor_disable_ligatures) |v| switch (v) {
                .never => .never,
                .cursor => .cursor,
                .always => .always,
            } else null,
            config.editor_font_features,
        );
        state.needs_redraw = true;
        log.logStdout(.info, "reload editor.disable_ligatures={s} editor.font_features={s}", .{
            if (config.editor_disable_ligatures) |v| @tagName(v) else "(unchanged)",
            config.editor_font_features orelse "(unchanged)",
        });
    }

    if (config.selection_overlay_smooth != null or config.selection_overlay_corner_px != null or config.selection_overlay_pad_px != null or
        config.editor_selection_overlay_smooth != null or config.editor_selection_overlay_corner_px != null or config.editor_selection_overlay_pad_px != null or
        config.terminal_selection_overlay_smooth != null or config.terminal_selection_overlay_corner_px != null or config.terminal_selection_overlay_pad_px != null)
    {
        state.shell.rendererPtr().setEditorSelectionOverlayStyle(
            config.editor_selection_overlay_smooth orelse config.selection_overlay_smooth,
            config.editor_selection_overlay_corner_px orelse config.selection_overlay_corner_px,
            config.editor_selection_overlay_pad_px orelse config.selection_overlay_pad_px,
        );
        state.shell.rendererPtr().setTerminalSelectionOverlayStyle(
            config.terminal_selection_overlay_smooth orelse config.selection_overlay_smooth,
            config.terminal_selection_overlay_corner_px orelse config.selection_overlay_corner_px,
            config.terminal_selection_overlay_pad_px orelse config.selection_overlay_pad_px,
        );
        state.needs_redraw = true;
        log.logStdout(.info, "reload selection_overlay editor(smooth={any}, corner_px={any}, pad_px={any}) terminal(smooth={any}, corner_px={any}, pad_px={any})", .{
            config.editor_selection_overlay_smooth orelse config.selection_overlay_smooth,
            config.editor_selection_overlay_corner_px orelse config.selection_overlay_corner_px,
            config.editor_selection_overlay_pad_px orelse config.selection_overlay_pad_px,
            config.terminal_selection_overlay_smooth orelse config.selection_overlay_smooth,
            config.terminal_selection_overlay_corner_px orelse config.selection_overlay_corner_px,
            config.terminal_selection_overlay_pad_px orelse config.selection_overlay_pad_px,
        });
    }

    if (app_config_runtime_common.resolveTerminalCursorStyle(&config)) |cursor_style| {
        state.terminal_cursor_style = cursor_style;
        for (state.terminals.items) |term| {
            term.setConfiguredCursorStyle(cursor_style);
        }
        state.needs_redraw = true;
        log.logStdout(.info, "reload terminal cursor shape={s} blink={any}", .{ @tagName(cursor_style.shape), cursor_style.blink });
    }

    if (config.terminal_scrollback_rows != null) {
        state.terminal_scrollback_rows = config.terminal_scrollback_rows;
        log.logStdout(.info, "reload note: terminal scrollback cap applies to new sessions", .{});
    }
    {
        const next_shell_path = try app_config_runtime_common.resolveTerminalShellPath(
            state.allocator,
            config.terminal_shell_path,
        );
        if (state.terminal_shell_path) |old| {
            state.allocator.free(old);
        }
        state.terminal_shell_path = next_shell_path;
        log.logStdout(.info, "reload terminal.shell.path={s}", .{
            state.terminal_shell_path orelse "<default>",
        });
    }
    {
        const next_default_start_location = try app_config_runtime_common.resolveTerminalDefaultStartLocation(
            state.allocator,
            config.terminal_default_start_location,
        );
        if (state.terminal_default_start_location) |old| {
            state.allocator.free(old);
        }
        state.terminal_default_start_location = next_default_start_location;
        state.terminal_new_tab_start_location = mapTerminalNewTabStartLocationMode(config.terminal_new_tab_start_location);
        log.logStdout(.info, "reload terminal.start_location default={s} new_tab={s}", .{
            state.terminal_default_start_location orelse "<unset>",
            @tagName(state.terminal_new_tab_start_location),
        });
    }
    if (config.terminal_window_chrome_mode != null) {
        state.terminal_window_chrome_mode = mapTerminalWindowChromeMode(config.terminal_window_chrome_mode);
        state.pressed_window_caption_button = null;
        state.needs_redraw = true;
        log.logStdout(.info, "reload terminal.window_chrome.mode={s}", .{
            @tagName(state.terminal_window_chrome_mode),
        });
    }
    if (config.terminal_tab_bar_show_single_tab != null) {
        state.terminal_tab_bar_show_single_tab = config.terminal_tab_bar_show_single_tab.?;
        state.needs_redraw = true;
        log.logStdout(.info, "reload terminal.tab_bar.show_single_tab={any}", .{
            state.terminal_tab_bar_show_single_tab,
        });
    }
    try reloadShellIcons(state, &config, log);
    if (config.editor_tab_bar_width_mode != null) {
        state.editor_tab_bar_width_mode = app_tab_bar_width.mapMode(config.editor_tab_bar_width_mode);
        state.needs_redraw = true;
        log.logStdout(.info, "reload editor.tab_bar.width_mode={s}", .{@tagName(state.editor_tab_bar_width_mode)});
    }
    if (config.terminal_tab_bar_width_mode != null) {
        state.terminal_tab_bar_width_mode = app_tab_bar_width.mapMode(config.terminal_tab_bar_width_mode);
        state.needs_redraw = true;
        log.logStdout(.info, "reload terminal.tab_bar.width_mode={s}", .{@tagName(state.terminal_tab_bar_width_mode)});
    }
    hooks.apply_current_tab_bar_width_mode(ctx);
    if (config.terminal_focus_report_window != null or config.terminal_focus_report_pane != null) {
        if (config.terminal_focus_report_window) |v| state.terminal_focus_report_window_events = v;
        if (config.terminal_focus_report_pane) |v| state.terminal_focus_report_pane_events = v;
        for (state.terminal_widgets.items) |*widget| {
            widget.setFocusReportSources(state.terminal_focus_report_window_events, state.terminal_focus_report_pane_events);
        }
        log.logStdout(.info, "reload terminal.focus_reporting window={any} pane={any}", .{
            state.terminal_focus_report_window_events,
            state.terminal_focus_report_pane_events,
        });
    }

    log.logStdout(.info, "config reloaded", .{});
}
