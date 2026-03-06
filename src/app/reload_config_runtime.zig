const std = @import("std");
const app_logger = @import("../app_logger.zig");
const app_shell = @import("../app_shell.zig");
const app_font_rendering = @import("font_rendering.zig");
const app_tab_bar_width = @import("tab_bar_width.zig");
const app_terminal_theme_apply = @import("terminal_theme_apply.zig");
const app_theme_utils = @import("theme_utils.zig");
const config_mod = @import("../config/lua_config.zig");
const term_types = @import("../terminal/model/types.zig");
const app_types = @import("app_state_types.zig");

fn mapTerminalNewTabStartLocationMode(mode: ?config_mod.TerminalNewTabStartLocationMode) app_types.TerminalNewTabStartLocationMode {
    return switch (mode orelse .current) {
        .current => .current,
        .default => .default,
    };
}

fn resolveTerminalDefaultStartLocation(
    allocator: std.mem.Allocator,
    configured: ?[]const u8,
) !?[]u8 {
    const home = if (std.c.getenv("HOME")) |value| std.mem.sliceTo(value, 0) else null;
    const raw = configured orelse home orelse return null;
    if (raw.len == 0) return null;

    if (raw[0] == '~' and home != null) {
        if (raw.len == 1) return try allocator.dupe(u8, home.?);
        if (raw.len >= 2 and raw[1] == '/') {
            return try std.fs.path.join(allocator, &.{ home.?, raw[2..] });
        }
    }

    return try allocator.dupe(u8, raw);
}

pub const Hooks = struct {
    refresh_terminal_sizing: *const fn (*anyopaque) anyerror!void,
    apply_current_tab_bar_width_mode: *const fn (*anyopaque) void,
};

pub fn handle(state: anytype, ctx: *anyopaque, hooks: Hooks) !void {
    const log = app_logger.logger("config.reload");
    var config = try config_mod.loadConfig(state.allocator);
    defer config_mod.freeConfig(state.allocator, &config);

    if (config.log_file_filter) |filter| {
        app_logger.setFileFilterString(filter) catch |err| {
            std.debug.print("reload log file filter parse error: {any}\n", .{err});
        };
    }
    if (config.log_console_filter) |filter| {
        app_logger.setConsoleFilterString(filter) catch |err| {
            std.debug.print("reload log console filter parse error: {any}\n", .{err});
        };
    }
    if (config.log_file_level) |level| {
        app_logger.setFileLevel(level);
    }
    if (config.log_console_level) |level| {
        app_logger.setConsoleLevel(level);
    }
    if (config.sdl_log_level) |level| {
        app_shell.setSdlLogLevel(level);
    }
    {
        const resolved_themes = app_theme_utils.resolveConfigThemes(state.shell_base_theme, &config);
        const app_theme_changed = !std.meta.eql(state.app_theme, resolved_themes.app);
        const editor_theme_changed = !std.meta.eql(state.editor_theme, resolved_themes.editor);
        const terminal_theme_changed = !std.meta.eql(state.terminal_theme, resolved_themes.terminal);

        if (app_theme_changed or editor_theme_changed or terminal_theme_changed) {
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
    }

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

    if (config.font_lcd != null or config.font_hinting != null or config.font_autohint != null or
        config.font_glyph_overflow != null or config.text_gamma != null or
        config.text_contrast != null or config.text_linear_correction != null)
    {
        try app_font_rendering.applyRendererFontRenderingConfig(state.shell, &config, true);
        try hooks.refresh_terminal_sizing(ctx);
        state.needs_redraw = true;
        log.logStdout(.info, "reload font_rendering applied", .{});
    }

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

    if (config.terminal_cursor_shape != null or config.terminal_cursor_blink != null) {
        var cursor_style = term_types.default_cursor_style;
        if (config.terminal_cursor_shape) |shape| {
            cursor_style.shape = shape;
        }
        if (config.terminal_cursor_blink) |blink| {
            cursor_style.blink = blink;
        }
        state.terminal_cursor_style = cursor_style;
        for (state.terminals.items) |term| {
            term.primary.cursor_style = cursor_style;
            term.alt.cursor_style = cursor_style;
            term.force_full_damage.store(true, .release);
            term.updateViewCacheForScroll();
        }
        state.needs_redraw = true;
        log.logStdout(.info, "reload terminal cursor shape={s} blink={any}", .{ @tagName(cursor_style.shape), cursor_style.blink });
    }

    if (config.terminal_scrollback_rows != null) {
        state.terminal_scrollback_rows = config.terminal_scrollback_rows;
        log.logStdout(.info, "reload note: terminal scrollback cap applies to new sessions", .{});
    }
    {
        const next_default_start_location = try resolveTerminalDefaultStartLocation(
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
    if (config.terminal_tab_bar_show_single_tab != null) {
        state.terminal_tab_bar_show_single_tab = config.terminal_tab_bar_show_single_tab.?;
        state.needs_redraw = true;
        log.logStdout(.info, "reload terminal.tab_bar.show_single_tab={any}", .{
            state.terminal_tab_bar_show_single_tab,
        });
    }
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

    if (config.app_font_path != null or config.app_font_size != null or
        config.editor_font_path != null or config.editor_font_size != null or
        config.terminal_font_path != null or config.terminal_font_size != null)
    {
        log.logStdout(.info, "reload note: font changes require restart", .{});
    }

    log.logStdout(.info, "config reloaded", .{});
}
