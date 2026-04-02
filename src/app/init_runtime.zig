const std = @import("std");
const app_bootstrap = @import("bootstrap.zig");
const build_options = @import("build_options");
const mode_build = @import("mode_build.zig");
const app_font_rendering = @import("font_rendering.zig");
const app_config_runtime_common = @import("config_runtime_common.zig");
const app_theme_utils = @import("theme_utils.zig");
const app_terminal_shell_icon_runtime = @import("terminal/terminal_shell_icon_runtime.zig");
const app_ui_layout_runtime = @import("ui_layout_runtime.zig");
const app_modes = @import("modes/mod.zig");
const app_types = @import("app_state_types.zig");
const app_shell = @import("../app_shell.zig");
const app_logger = @import("../app_logger.zig");
const config_mod = @import("../config/lua_config.zig");
const manual_highlights_mod = @import("../editor/manual_highlights.zig");
const terminal_runtime = @import("../terminal/core/terminal_runtime.zig");
const workspace_mod = @import("../terminal/core/workspace.zig");
const metrics_mod = @import("../terminal/model/metrics.zig");
const term_types = @import("../terminal/model/types.zig");
const shared_types = @import("../types/mod.zig");
const widgets = @import("../ui/widgets.zig");
const font_sample_view_mod = @import("../ui/font_sample_view.zig");
const input_actions = @import("../input/input_actions.zig");
const app_editor_live_smoke_runtime = @import("editor/live_smoke_runtime.zig");
const app_lifecycle_runtime = @import("lifecycle_runtime.zig");

const grammar_manager_mod = if (mode_build.focused_mode == .terminal) struct {
    pub const GrammarManager = app_types.GrammarManager;
} else @import("../editor/grammar_manager.zig");

const editor_render_cache_mod = if (mode_build.focused_mode == .terminal) struct {
    pub const EditorRenderCache = app_types.EditorRenderCache;
} else @import("../editor/render/cache.zig");

const TerminalWorkspace = workspace_mod.TerminalWorkspace;
const Metrics = metrics_mod.Metrics;
const EditorClusterCache = widgets.EditorClusterCache;
const EditorRenderCache = editor_render_cache_mod.EditorRenderCache;

const StartupPerf = struct {
    perf_mode: bool,
    perf_frames_total: u64,
    perf_scroll_delta: i32,
    perf_file_path: ?[]u8,
    startup_file_paths: ?[][]u8,
    editor_live_smoke: app_types.EditorLiveSmokeState,
};

const TerminalStartup = struct {
    terminal_workspace: ?TerminalWorkspace,
    terminal_default_start_location: ?[]u8,
    terminal_shell_path: ?[]u8,
    terminal_tab_bar_shell_icons: ?[]app_types.TerminalShellIconMapping,
};

const ModeAdapters = struct {
    editor_mode_adapter: ?app_modes.backend.EditorMode,
    terminal_mode_adapter: app_modes.backend.TerminalMode,
};

fn mapTerminalNewTabStartLocationMode(mode: ?config_mod.TerminalNewTabStartLocationMode) app_types.TerminalNewTabStartLocationMode {
    return switch (mode orelse .current) {
        .current => .current,
        .default => .default,
    };
}

fn mapTerminalWindowChromeMode(mode: ?config_mod.TerminalWindowChromeMode) app_types.TerminalWindowChromeMode {
    return mode orelse .native;
}

fn windowTitleForMode(app_mode: app_bootstrap.AppMode) [*:0]const u8 {
    return switch (app_mode) {
        .ide => "Zide - Zig IDE",
        .editor => "Zide Editor",
        .terminal => "Zide Terminal",
        .font_sample => "Zide Font Sample",
    };
}

fn applyInitialUiScale(state: anytype) void {
    app_ui_layout_runtime.applyUiScaleForState(state, state.shell.uiScaleFactor());
}

fn resolveStartupPerf(
    allocator: std.mem.Allocator,
    app_mode: app_bootstrap.AppMode,
) !StartupPerf {
    const perf_file_path = if (std.c.getenv("ZIDE_EDITOR_PERF_FILE")) |raw|
        try allocator.dupe(u8, std.mem.sliceTo(raw, 0))
    else
        null;
    const startup_file_paths = app_bootstrap.parseStartupFilePaths(allocator);
    const editor_live_smoke: app_types.EditorLiveSmokeState = if (app_modes.ide.supportsEditorSurface(app_mode))
        try app_editor_live_smoke_runtime.initState(allocator)
    else
        .{};
    const perf_mode = perf_file_path != null;
    const perf_frames_total: u64 = if (perf_mode)
        app_bootstrap.parseEnvU64("ZIDE_EDITOR_PERF_FRAMES", 240)
    else
        0;
    const perf_scroll_delta: i32 = if (perf_mode)
        @intCast(app_bootstrap.parseEnvU64("ZIDE_EDITOR_PERF_SCROLL", 3))
    else
        0;

    return .{
        .perf_mode = perf_mode,
        .perf_frames_total = perf_frames_total,
        .perf_scroll_delta = perf_scroll_delta,
        .perf_file_path = perf_file_path,
        .startup_file_paths = startup_file_paths,
        .editor_live_smoke = editor_live_smoke,
    };
}

fn resolveTerminalStartup(
    allocator: std.mem.Allocator,
    app_mode: app_bootstrap.AppMode,
    config: *const config_mod.Config,
    terminal_cursor_style: ?term_types.CursorStyle,
) !TerminalStartup {
    const terminal_workspace = if (app_modes.ide.shouldUseTerminalWorkspace(app_mode))
        TerminalWorkspace.init(allocator, .{
            .scrollback_rows = config.terminal_scrollback_rows,
            .cursor_style = terminal_cursor_style,
        })
    else
        null;
    const terminal_default_start_location = try app_config_runtime_common.resolveTerminalDefaultStartLocation(
        allocator,
        config.terminal_default_start_location,
    );
    const terminal_shell_path = try app_config_runtime_common.resolveTerminalShellPath(
        allocator,
        config.terminal_shell_path,
    );
    const terminal_tab_bar_shell_icons = try app_terminal_shell_icon_runtime.dupMappings(
        allocator,
        config.terminal_tab_bar_shell_icons,
    );

    return .{
        .terminal_workspace = terminal_workspace,
        .terminal_default_start_location = terminal_default_start_location,
        .terminal_shell_path = terminal_shell_path,
        .terminal_tab_bar_shell_icons = terminal_tab_bar_shell_icons,
    };
}

fn resolveModeAdapters(
    allocator: std.mem.Allocator,
    app_mode: app_bootstrap.AppMode,
) !ModeAdapters {
    const bootstrap_opts = app_modes.backend.bootstrap.BootstrapOptions{
        .seed_editor_tab = false,
        .seed_terminal_tab = false,
    };
    const editor_mode_adapter: ?app_modes.backend.EditorMode = if (app_modes.ide.supportsEditorSurface(app_mode))
        try app_modes.backend.bootstrap.initEditorMode(allocator, bootstrap_opts)
    else
        null;
    const terminal_mode_adapter = try app_modes.backend.bootstrap.initTerminalMode(allocator, bootstrap_opts);
    return .{
        .editor_mode_adapter = editor_mode_adapter,
        .terminal_mode_adapter = terminal_mode_adapter,
    };
}

pub fn init(comptime AppStateT: type, allocator: std.mem.Allocator, app_mode: app_bootstrap.AppMode) !*AppStateT {
    return try initWithMode(AppStateT, allocator, null, app_mode);
}

pub fn initFocused(comptime AppStateT: type, allocator: std.mem.Allocator, comptime app_mode: app_bootstrap.AppMode) !*AppStateT {
    return try initWithMode(AppStateT, allocator, app_mode, .ide);
}

fn initWithMode(
    comptime AppStateT: type,
    allocator: std.mem.Allocator,
    comptime forced_mode: ?app_bootstrap.AppMode,
    runtime_mode: app_bootstrap.AppMode,
) !*AppStateT {
    const app_mode = if (comptime forced_mode) |mode| mode else runtime_mode;

    var config = config_mod.loadConfig(allocator) catch |err| blk: {
        std.debug.print("config load error: {any}\n", .{err});
        break :blk config_mod.emptyConfig();
    };
    defer config_mod.freeConfig(allocator, &config);

    try manual_highlights_mod.applyConfig(allocator, &config);
    errdefer manual_highlights_mod.reset();

    app_config_runtime_common.applyLoggerConfig(&config, "");
    try app_logger.init();
    app_lifecycle_runtime.reset();

    if (config.sdl_log_level) |level| {
        app_shell.setSdlLogLevel(level);
    }

    const window_width = app_bootstrap.parseEnvI32("ZIDE_WINDOW_WIDTH", 1280);
    const window_height = app_bootstrap.parseEnvI32("ZIDE_WINDOW_HEIGHT", 720);
    const renderer_init = app_font_rendering.buildRendererInitOptions(&config);
    const shell = try app_shell.Shell.init(
        allocator,
        window_width,
        window_height,
        windowTitleForMode(app_mode),
        renderer_init,
    );
    errdefer shell.deinit(allocator);

    // Startup now seeds renderer font/render state from the loaded config, so
    // this post-init apply should be uniform-only and rebuild-free.
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
    shell.rendererPtr().setTerminalTextureShiftEnabled(config.terminal_texture_shift orelse true);
    shell.rendererPtr().setTerminalRecentInputFullPublicationPolicy(
        config.terminal_recent_input_force_full orelse true,
        config.terminal_recent_input_force_full_ms,
    );
    shell.rendererPtr().setEditorSelectionOverlayStyle(
        config.editor_selection_overlay_smooth orelse config.selection_overlay_smooth,
        config.editor_selection_overlay_corner_px orelse config.selection_overlay_corner_px,
        config.editor_selection_overlay_pad_px orelse config.selection_overlay_pad_px,
    );
    shell.rendererPtr().setTerminalSelectionOverlayStyle(
        config.terminal_selection_overlay_smooth orelse config.selection_overlay_smooth,
        config.terminal_selection_overlay_corner_px orelse config.selection_overlay_corner_px,
        config.terminal_selection_overlay_pad_px orelse config.selection_overlay_pad_px,
    );
    if (config.app_theme != null or config.editor_theme != null or config.terminal_theme != null or config.theme != null) {
        // Wait, we need to defer theme initialization to AppState so let's do it right before AppState init
    }
    _ = try shell.refreshUiScale();
    const app_log = app_logger.logger("app.core");
    app_log.logStdout(.info, "logger initialized", .{});
    app_log.logStdout(.info, "config lua backend: impl={s}", .{"ziglua"});
    app_log.logStdout(.info, "terminal present mitigation recent_input_force_full={any} recent_input_force_full_ms={d}", .{
        shell.rendererPtr().terminalRecentInputFullPublicationEnabled(),
        shell.rendererPtr().terminalRecentInputFullPublicationWindowMs(),
    });
    const metrics_log = app_logger.logger("terminal.metrics");
    const input_latency_log = app_logger.logger("input.latency");
    const perf_log = app_logger.logger("editor.perf");
    const startup_perf = try resolveStartupPerf(allocator, app_mode);

    const TerminalBlinkStyle = @TypeOf(@as(AppStateT, undefined).terminal_blink_style);
    const terminal_blink_style: TerminalBlinkStyle = switch (config.terminal_blink_style orelse .kitty) {
        .kitty => .kitty,
        .off => .off,
    };
    const terminal_cursor_style = app_config_runtime_common.resolveTerminalCursorStyle(&config);

    const shell_base_theme = shell.theme().*;
    const resolved_themes = app_theme_utils.resolveConfigThemes(shell_base_theme, &config);
    const app_theme = resolved_themes.app;
    const editor_theme = resolved_themes.editor;
    const terminal_theme = resolved_themes.terminal;

    shell.setTheme(app_theme);

    const grammar_manager: ?grammar_manager_mod.GrammarManager = if (app_modes.ide.supportsEditorSurface(app_mode)) blk: {
        var gm = try grammar_manager_mod.GrammarManager.init(allocator);
        errdefer gm.deinit();
        break :blk gm;
    } else null;
    const terminal_startup = try resolveTerminalStartup(allocator, app_mode, &config, terminal_cursor_style);
    errdefer if (terminal_startup.terminal_default_start_location) |path| allocator.free(path);
    errdefer if (terminal_startup.terminal_shell_path) |path| allocator.free(path);
    errdefer app_terminal_shell_icon_runtime.freeMappings(allocator, terminal_startup.terminal_tab_bar_shell_icons);
    const mode_adapters = try resolveModeAdapters(allocator, app_mode);

    const state = try allocator.create(AppStateT);
    state.* = .{
        .allocator = allocator,
        .shell = shell,
        .top_bar = .{},
        .tab_bar = widgets.TabBar.init(allocator),
        .side_nav = .{},
        .status_bar = .{},
        .editors = .empty,
        .terminals = .empty,
        .terminal_widgets = .empty,
        .terminal_workspace = terminal_startup.terminal_workspace,
        .pending_terminal_presentation_feedback = null,
        .last_terminal_submission_sequence = 0,
        .app_theme = app_theme,
        .editor_theme = editor_theme,
        .terminal_theme = terminal_theme,
        .shell_base_theme = shell_base_theme,
        .editor_imported_theme_name = if (config.editor_imported_theme_name) |name| try allocator.dupe(u8, name) else null,
        .active_tab = 0,
        .active_kind = app_modes.ide.initialActiveMode(app_mode),
        .mode = "NORMAL",
        .show_terminal = app_modes.ide.initialTerminalVisibility(app_mode),
        .terminal_height = 200,
        .terminal_blink_style = terminal_blink_style,
        .terminal_cursor_style = terminal_cursor_style,
        .terminal_scrollback_rows = config.terminal_scrollback_rows,
        .terminal_shell_path = terminal_startup.terminal_shell_path,
        .terminal_default_start_location = terminal_startup.terminal_default_start_location,
        .terminal_new_tab_start_location = mapTerminalNewTabStartLocationMode(config.terminal_new_tab_start_location),
        .terminal_window_chrome_mode = mapTerminalWindowChromeMode(config.terminal_window_chrome_mode),
        .pressed_window_caption_button = null,
        .hovered_window_caption_button = null,
        .terminal_tab_bar_show_shell_icon = config.terminal_tab_bar_show_shell_icon orelse false,
        .terminal_tab_bar_shell_icons = terminal_startup.terminal_tab_bar_shell_icons,
        .terminal_shell_icon_cache = app_terminal_shell_icon_runtime.ShellIconCache.init(allocator),
        .editor_tab_bar_width_mode = @import("tabs/tab_bar_width.zig").mapMode(config.editor_tab_bar_width_mode),
        .terminal_tab_bar_show_single_tab = config.terminal_tab_bar_show_single_tab orelse false,
        .terminal_tab_bar_width_mode = @import("tabs/tab_bar_width.zig").mapMode(config.terminal_tab_bar_width_mode),
        .terminal_focus_report_window_events = config.terminal_focus_report_window orelse true,
        .terminal_focus_report_pane_events = config.terminal_focus_report_pane orelse false,
        .last_terminal_pane_focus_reported = null,
        .config_reload_notice_until = 0,
        .config_reload_notice_success = true,
        .needs_redraw = true,
        .terminal_frame_pacing = .{},
        .last_mouse_pos = .{ .x = -1, .y = -1 },
        .last_cursor_blink_on = true,
        .last_cursor_blink_armed = false,
        .resizing_terminal = false,
        .resize_start_y = 0,
        .resize_start_height = 0,
        .window_resize_pending = false,
        .window_resize_last_time = 0,
        .mouse_debug = std.c.getenv("ZIDE_MOUSE_DEBUG") != null,
        .last_mouse_redraw_time = 0,
        .last_ctrl_down = false,
        .editor_dragging = false,
        .editor_drag_start = .{ .line = 0, .col = 0, .offset = 0 },
        .editor_drag_rect = false,
        .editor_hscroll_dragging = false,
        .editor_hscroll_grab_offset = 0,
        .editor_vscroll_dragging = false,
        .editor_vscroll_grab_offset = 0,
        .terminal_scrollbar_dragging = false,
        .terminal_scrollbar_grab_offset = 0,
        .terminal_scrollbar_hovered = false,
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
        .perf_mode = startup_perf.perf_mode,
        .perf_frames_total = startup_perf.perf_frames_total,
        .perf_frames_done = 0,
        .perf_scroll_delta = startup_perf.perf_scroll_delta,
        .perf_file_path = startup_perf.perf_file_path,
        .startup_file_paths = startup_perf.startup_file_paths,
        .perf_logger = perf_log,
        .last_input = shared_types.input.InputSnapshot.init(.{ .x = 0, .y = 0 }, .{}),
        .app_mode = app_mode,
        .input_router = input_actions.InputRouter.init(allocator),
        .editor_mode_adapter = mode_adapters.editor_mode_adapter,
        .terminal_mode_adapter = mode_adapters.terminal_mode_adapter,
        .font_sample_view = null,
        .font_sample_auto_close_frames = if (app_modes.ide.isFontSample(app_mode))
            app_bootstrap.parseEnvU64("ZIDE_FONT_SAMPLE_FRAMES", 0)
        else
            0,
        .font_sample_close_pending = false,
        .font_sample_screenshot_path = if (app_modes.ide.isFontSample(app_mode)) app_bootstrap.envSlice("ZIDE_FONT_SAMPLE_SCREENSHOT") else null,
        .editor_live_smoke = startup_perf.editor_live_smoke,
        .search_panel = .{
            .active = false,
            .query = std.ArrayList(u8).empty,
            .select_all = false,
        },
        .path_prompt = .init(),
        .terminal_close_confirm_tab = null,
        .terminal_window_close_pending = false,
    };
    if (app_modes.ide.isFontSample(app_mode)) {
        state.font_sample_view = try font_sample_view_mod.FontSampleView.init(allocator, shell.rendererPtr());
    }
    if (config.keybinds) |binds| {
        state.input_router.setBindings(binds);
    }
    applyInitialUiScale(state);

    return state;
}
