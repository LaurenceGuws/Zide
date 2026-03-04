const std = @import("std");
const app_bootstrap = @import("bootstrap.zig");
const app_font_rendering = @import("font_rendering.zig");
const app_theme_utils = @import("theme_utils.zig");
const app_ui_layout_runtime = @import("ui_layout_runtime.zig");
const app_tab_bar_width = @import("tab_bar_width.zig");
const app_modes = @import("modes/mod.zig");
const app_shell = @import("../app_shell.zig");
const app_logger = @import("../app_logger.zig");
const config_mod = @import("../config/lua_config.zig");
const grammar_manager_mod = @import("../editor/grammar_manager.zig");
const editor_render_cache_mod = @import("../editor/render/cache.zig");
const terminal_mod = @import("../terminal/core/terminal.zig");
const metrics_mod = @import("../terminal/model/metrics.zig");
const term_types = @import("../terminal/model/types.zig");
const shared_types = @import("../types/mod.zig");
const widgets = @import("../ui/widgets.zig");
const font_sample_view_mod = @import("../ui/font_sample_view.zig");
const input_actions = @import("../input/input_actions.zig");

const TerminalWorkspace = terminal_mod.TerminalWorkspace;
const Metrics = metrics_mod.Metrics;
const EditorClusterCache = widgets.EditorClusterCache;
const EditorRenderCache = editor_render_cache_mod.EditorRenderCache;

pub fn init(comptime AppStateT: type, allocator: std.mem.Allocator, app_mode: app_bootstrap.AppMode) !*AppStateT {
    var config = config_mod.loadConfig(allocator) catch |err| blk: {
        std.debug.print("config load error: {any}\n", .{err});
        break :blk config_mod.Config{
            .log_file_filter = null,
            .log_console_filter = null,
            .sdl_log_level = null,
            .editor_wrap = null,
            .editor_large_jump_rows = null,
            .editor_highlight_budget = null,
            .editor_width_budget = null,
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
    };
    defer config_mod.freeConfig(allocator, &config);

    if (config.log_file_filter) |filter| {
        app_logger.setFileFilterString(filter) catch {};
    }
    if (config.log_console_filter) |filter| {
        app_logger.setConsoleFilterString(filter) catch {};
    }
    try app_logger.init();

    if (config.sdl_log_level) |level| {
        app_shell.setSdlLogLevel(level);
    }

    const window_width = app_bootstrap.parseEnvI32("ZIDE_WINDOW_WIDTH", 1280);
    const window_height = app_bootstrap.parseEnvI32("ZIDE_WINDOW_HEIGHT", 720);
    const shell = try app_shell.Shell.init(allocator, window_width, window_height, "Zide - Zig IDE");
    errdefer shell.deinit(allocator);

    try app_font_rendering.applyRendererFontRenderingConfig(shell, &config, false);
    shell.rendererPtr().setTerminalLigatureConfig(
        if (config.terminal_disable_ligatures) |v| switch (v) {
            .never => .never,
            .cursor => .cursor,
            .always => .always,
        } else null,
        config.terminal_font_features,
    );
    shell.rendererPtr().setEditorLigatureConfig(
        if (config.editor_disable_ligatures) |v| switch (v) {
            .never => .never,
            .cursor => .cursor,
            .always => .always,
        } else null,
        config.editor_font_features,
    );
    if (config.app_font_path != null or config.app_font_size != null or
        config.editor_font_path != null or config.editor_font_size != null or
        config.terminal_font_path != null or config.terminal_font_size != null)
    {
        const font_path = config.terminal_font_path orelse config.editor_font_path orelse config.app_font_path;
        const font_size = config.terminal_font_size orelse config.editor_font_size orelse config.app_font_size;
        if (font_path != null or font_size != null) {
            shell.rendererPtr().setFontConfig(font_path, font_size) catch {};
        }
    }
    if (config.app_theme != null or config.editor_theme != null or config.terminal_theme != null or config.theme != null) {
        // Wait, we need to defer theme initialization to AppState so let's do it right before AppState init
    }
    _ = try shell.refreshUiScale();
    const app_log = app_logger.logger("app.core");
    app_log.logStdout("logger initialized", .{});
    const metrics_log = app_logger.logger("terminal.metrics");
    const input_latency_log = app_logger.logger("input.latency");
    const perf_log = app_logger.logger("editor.perf");

    const perf_file_path = if (std.c.getenv("ZIDE_EDITOR_PERF_FILE")) |raw|
        try allocator.dupe(u8, std.mem.sliceTo(raw, 0))
    else
        null;
    const perf_mode = perf_file_path != null;
    const perf_frames_total: u64 = if (perf_mode)
        app_bootstrap.parseEnvU64("ZIDE_EDITOR_PERF_FRAMES", 240)
    else
        0;
    const perf_scroll_delta: i32 = if (perf_mode)
        @intCast(app_bootstrap.parseEnvU64("ZIDE_EDITOR_PERF_SCROLL", 3))
    else
        0;

    const TerminalBlinkStyle = @TypeOf(@as(AppStateT, undefined).terminal_blink_style);
    const terminal_blink_style: TerminalBlinkStyle = switch (config.terminal_blink_style orelse .kitty) {
        .kitty => .kitty,
        .off => .off,
    };
    var terminal_cursor_style = @as(?term_types.CursorStyle, null);
    if (config.terminal_cursor_shape != null or config.terminal_cursor_blink != null) {
        var cursor_style = term_types.default_cursor_style;
        if (config.terminal_cursor_shape) |shape| {
            cursor_style.shape = shape;
        }
        if (config.terminal_cursor_blink) |blink| {
            cursor_style.blink = blink;
        }
        terminal_cursor_style = cursor_style;
    }

    const shell_base_theme = shell.theme().*;
    const resolved_themes = app_theme_utils.resolveConfigThemes(shell_base_theme, &config);
    const app_theme = resolved_themes.app;
    const editor_theme = resolved_themes.editor;
    const terminal_theme = resolved_themes.terminal;

    shell.setTheme(app_theme);

    var grammar_manager = try grammar_manager_mod.GrammarManager.init(allocator);
    errdefer grammar_manager.deinit();
    const terminal_workspace = if (app_modes.ide.shouldUseTerminalWorkspace(app_mode))
        TerminalWorkspace.init(allocator, .{
            .scrollback_rows = config.terminal_scrollback_rows,
            .cursor_style = terminal_cursor_style,
        })
    else
        null;
    const bootstrap_opts = app_modes.backend.bootstrap.BootstrapOptions{
        .seed_editor_tab = false,
        .seed_terminal_tab = false,
    };
    const editor_mode_adapter = try app_modes.backend.bootstrap.initEditorMode(allocator, bootstrap_opts);
    const terminal_mode_adapter = try app_modes.backend.bootstrap.initTerminalMode(allocator, bootstrap_opts);

    const state = try allocator.create(AppStateT);
    state.* = .{
        .allocator = allocator,
        .shell = shell,
        .options_bar = .{},
        .tab_bar = widgets.TabBar.init(allocator),
        .side_nav = .{},
        .status_bar = .{},
        .editors = .empty,
        .terminals = .empty,
        .terminal_widgets = .empty,
        .terminal_workspace = terminal_workspace,
        .app_theme = app_theme,
        .editor_theme = editor_theme,
        .terminal_theme = terminal_theme,
        .shell_base_theme = shell_base_theme,
        .active_tab = 0,
        .active_kind = app_modes.ide.initialActiveMode(app_mode),
        .mode = "NORMAL",
        .show_terminal = app_modes.ide.initialTerminalVisibility(app_mode),
        .terminal_height = 200,
        .terminal_blink_style = terminal_blink_style,
        .terminal_cursor_style = terminal_cursor_style,
        .terminal_scrollback_rows = config.terminal_scrollback_rows,
        .editor_tab_bar_width_mode = app_tab_bar_width.mapMode(config.editor_tab_bar_width_mode),
        .terminal_tab_bar_show_single_tab = config.terminal_tab_bar_show_single_tab orelse false,
        .terminal_tab_bar_width_mode = app_tab_bar_width.mapMode(config.terminal_tab_bar_width_mode),
        .terminal_focus_report_window_events = config.terminal_focus_report_window orelse true,
        .terminal_focus_report_pane_events = config.terminal_focus_report_pane orelse false,
        .last_terminal_pane_focus_reported = null,
        .config_reload_notice_until = 0,
        .config_reload_notice_success = true,
        .needs_redraw = true,
        .idle_frames = 0,
        .last_mouse_pos = .{ .x = -1, .y = -1 },
        .last_cursor_blink_on = true,
        .last_cursor_blink_armed = false,
        .resizing_terminal = false,
        .resize_start_y = 0,
        .resize_start_height = 0,
        .window_resize_pending = false,
        .window_resize_last_time = 0,
        .mouse_debug = std.c.getenv("ZIDE_MOUSE_DEBUG") != null,
        .terminal_scroll_dragging = false,
        .terminal_scroll_grab_offset = 0,
        .last_mouse_redraw_time = 0,
        .last_ctrl_down = false,
        .editor_dragging = false,
        .editor_drag_start = .{ .line = 0, .col = 0, .offset = 0 },
        .editor_drag_rect = false,
        .editor_hscroll_dragging = false,
        .editor_hscroll_grab_offset = 0,
        .editor_vscroll_dragging = false,
        .editor_vscroll_grab_offset = 0,
        .editor_cluster_cache = EditorClusterCache.init(allocator),
        .editor_render_cache = EditorRenderCache.init(allocator, 4096),
        .grammar_manager = grammar_manager,
        .frame_id = 0,
        .metrics = Metrics.init(),
        .metrics_logger = metrics_log,
        .input_latency_logger = input_latency_log,
        .app_logger = app_log,
        .last_metrics_log_time = 0,
        .editor_wrap = config.editor_wrap orelse false,
        .editor_large_jump_rows = config.editor_large_jump_rows orelse 5,
        .editor_highlight_budget = config.editor_highlight_budget,
        .editor_width_budget = config.editor_width_budget,
        .perf_mode = perf_mode,
        .perf_frames_total = perf_frames_total,
        .perf_frames_done = 0,
        .perf_scroll_delta = perf_scroll_delta,
        .perf_file_path = perf_file_path,
        .perf_logger = perf_log,
        .last_input = shared_types.input.InputSnapshot.init(.{ .x = 0, .y = 0 }, .{}),
        .app_mode = app_mode,
        .input_router = input_actions.InputRouter.init(allocator),
        .editor_mode_adapter = editor_mode_adapter,
        .terminal_mode_adapter = terminal_mode_adapter,
        .font_sample_view = null,
        .font_sample_auto_close_frames = if (app_modes.ide.isFontSample(app_mode))
            app_bootstrap.parseEnvU64("ZIDE_FONT_SAMPLE_FRAMES", 0)
        else
            0,
        .font_sample_close_pending = false,
        .font_sample_screenshot_path = if (app_modes.ide.isFontSample(app_mode)) app_bootstrap.envSlice("ZIDE_FONT_SAMPLE_SCREENSHOT") else null,
        .search_panel = .{
            .active = false,
            .query = std.ArrayList(u8).empty,
        },
        .terminal_close_confirm_tab = null,
    };
    if (app_modes.ide.isFontSample(app_mode)) {
        state.font_sample_view = try font_sample_view_mod.FontSampleView.init(allocator, shell.rendererPtr());
    }
    if (config.keybinds) |binds| {
        state.input_router.setBindings(binds);
    }
    app_ui_layout_runtime.applyUiScale(
        state,
        state.shell.uiScaleFactor(),
        @ptrCast(state),
        .{
            .apply_current_tab_bar_width_mode = struct {
                fn call(raw: *anyopaque) void {
                    const cb_state: *AppStateT = @ptrCast(@alignCast(raw));
                    app_tab_bar_width.applyForMode(
                        &cb_state.tab_bar,
                        cb_state.app_mode,
                        cb_state.editor_tab_bar_width_mode,
                        cb_state.terminal_tab_bar_width_mode,
                    );
                }
            }.call,
        },
    );
    app_tab_bar_width.applyForMode(
        &state.tab_bar,
        state.app_mode,
        state.editor_tab_bar_width_mode,
        state.terminal_tab_bar_width_mode,
    );

    return state;
}
