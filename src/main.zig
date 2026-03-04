const std = @import("std");
const app_bootstrap = @import("app/bootstrap.zig");
const app_config_reload_notice_state = @import("app/config_reload_notice_state.zig");
const app_editor_actions = @import("app/editor_actions.zig");
const app_editor_intent_route = @import("app/editor_intent_route.zig");
const app_editor_display_prepare = @import("app/editor_display_prepare.zig");
const app_active_editor_frame = @import("app/active_editor_frame.zig");
const app_editor_shortcuts_frame = @import("app/editor_shortcuts_frame.zig");
const app_editor_seed = @import("app/editor_seed.zig");
const app_file_detect = @import("app/file_detect.zig");
const app_font_rendering = @import("app/font_rendering.zig");
const app_terminal_grid = @import("app/terminal_grid.zig");
const app_terminal_runtime_intents = @import("app/terminal_runtime_intents.zig");
const app_terminal_active_widget = @import("app/terminal_active_widget.zig");
const app_terminal_clipboard_shortcuts_frame = @import("app/terminal_clipboard_shortcuts_frame.zig");
const app_terminal_tab_bar_sync = @import("app/terminal_tab_bar_sync.zig");
const app_terminal_tabs_runtime = @import("app/terminal_tabs_runtime.zig");
const app_terminal_surface_gate = @import("app/terminal_surface_gate.zig");
const app_terminal_shortcut_suppress = @import("app/terminal_shortcut_suppress.zig");
const app_terminal_shortcut_policy = @import("app/terminal_shortcut_policy.zig");
const app_terminal_shortcut_runtime = @import("app/terminal_shortcut_runtime.zig");
const app_terminal_tab_intents = @import("app/terminal_tab_intents.zig");
const app_terminal_resize = @import("app/terminal_resize.zig");
const app_terminal_refresh_sizing_runtime = @import("app/terminal_refresh_sizing_runtime.zig");
const app_visible_terminal_frame = @import("app/visible_terminal_frame.zig");
const app_terminal_session_bootstrap = @import("app/terminal_session_bootstrap.zig");
const app_terminal_close_confirm_input = @import("app/terminal_close_confirm_input.zig");
const app_mode_adapter_sync = @import("app/mode_adapter_sync.zig");
const app_mode_adapter_parity = @import("app/mode_adapter_parity.zig");
const app_terminal_theme_apply = @import("app/terminal_theme_apply.zig");
const app_search_panel_input = @import("app/search_panel_input.zig");
const app_search_panel_runtime = @import("app/search_panel_runtime.zig");
const app_search_panel_state = @import("app/search_panel_state.zig");
const app_mouse_debug_log = @import("app/mouse_debug_log.zig");
const app_mouse_pressed_frame = @import("app/mouse_pressed_frame.zig");
const app_input_actions_frame_runtime = @import("app/input_actions_frame_runtime.zig");
const app_pointer_activity_frame = @import("app/pointer_activity_frame.zig");
const app_shortcut_action_runtime = @import("app/shortcut_action_runtime.zig");
const app_tab_drag_frame = @import("app/tab_drag_frame.zig");
const app_terminal_split_resize_frame = @import("app/terminal_split_resize_frame.zig");
const app_window_resize_event_frame = @import("app/window_resize_event_frame.zig");
const app_deferred_terminal_resize_frame = @import("app/deferred_terminal_resize_frame.zig");
const app_cursor_blink_frame = @import("app/cursor_blink_frame.zig");
const app_post_preinput_frame = @import("app/post_preinput_frame.zig");
const app_interactive_frame = @import("app/interactive_frame.zig");
const app_update_driver = @import("app/update_driver.zig");
const app_run_loop_driver = @import("app/run_loop_driver.zig");
const app_reload_config_runtime = @import("app/reload_config_runtime.zig");
const app_run_mode_init = @import("app/run_mode_init.zig");
const app_prepare_run_frame_runtime = @import("app/prepare_run_frame_runtime.zig");
const app_frame_render_idle_runtime = @import("app/frame_render_idle_runtime.zig");
const app_update_prelude_frame_runtime = @import("app/update_prelude_frame_runtime.zig");
const app_ui_layout_runtime = @import("app/ui_layout_runtime.zig");
const app_metrics_log_runtime = @import("app/metrics_log_runtime.zig");
const app_run_entry_runtime = @import("app/run_entry_runtime.zig");
const app_draw_frame_runtime = @import("app/draw_frame_runtime.zig");
const app_terminal_tab_navigation_runtime = @import("app/terminal_tab_navigation_runtime.zig");
const app_terminal_close_active_runtime = @import("app/terminal_close_active_runtime.zig");
const app_terminal_close_confirm_active_runtime = @import("app/terminal_close_confirm_active_runtime.zig");
const app_terminal_close_confirm_decision_runtime = @import("app/terminal_close_confirm_decision_runtime.zig");
const app_tab_action_apply = @import("app/tab_action_apply.zig");
const app_tab_bar_width = @import("app/tab_bar_width.zig");
const app_theme_utils = @import("app/theme_utils.zig");
const app_reload_config_shortcut_runtime = @import("app/reload_config_shortcut_runtime.zig");
const app_runner = @import("app/runner.zig");
const app_signals = @import("app/signals.zig");
const app_modes = @import("app/modes/mod.zig");

// Editor modules
const editor_mod = @import("editor/editor.zig");
const text_store = @import("editor/text_store.zig");
const types = @import("editor/types.zig");
const editor_render_cache_mod = @import("editor/render/cache.zig");
const grammar_manager_mod = @import("editor/grammar_manager.zig");
const app_logger = @import("app_logger.zig");
const config_mod = @import("config/lua_config.zig");

// Terminal modules
const terminal_mod = @import("terminal/core/terminal.zig");
const metrics_mod = @import("terminal/model/metrics.zig");
const term_types = @import("terminal/model/types.zig");
const shared_types = @import("types/mod.zig");

// UI modules
const app_shell = @import("app_shell.zig");
const widgets = @import("ui/widgets.zig");
const editor_draw = @import("ui/widgets/editor_widget_draw.zig");
const layout_types = shared_types.layout;
const input_actions = @import("input/input_actions.zig");
const font_sample_view_mod = @import("ui/font_sample_view.zig");

const Editor = editor_mod.Editor;
const TerminalSession = terminal_mod.TerminalSession;
const TerminalWorkspace = terminal_mod.TerminalWorkspace;
const Metrics = metrics_mod.Metrics;
const Logger = app_logger.Logger;
const Shell = app_shell.Shell;
const TabBar = widgets.TabBar;
const OptionsBar = widgets.OptionsBar;
const SideNav = widgets.SideNav;
const StatusBar = widgets.StatusBar;
const EditorWidget = widgets.EditorWidget;
const EditorClusterCache = widgets.EditorClusterCache;
const EditorRenderCache = editor_render_cache_mod.EditorRenderCache;
const TerminalWidget = widgets.TerminalWidget;

pub const AppMode = app_bootstrap.AppMode;

const AppState = struct {
    const SearchPanelState = struct {
        active: bool,
        query: std.ArrayList(u8),

        fn init(_: std.mem.Allocator) SearchPanelState {
            return .{
                .active = false,
                .query = std.ArrayList(u8).empty,
            };
        }

        fn deinit(self: *SearchPanelState, allocator: std.mem.Allocator) void {
            self.query.deinit(allocator);
        }
    };

    const TerminalCloseModalLayout = app_modes.ide.TerminalCloseConfirmLayout;

    allocator: std.mem.Allocator,
    shell: *Shell,
    options_bar: OptionsBar,
    tab_bar: TabBar,
    side_nav: SideNav,
    status_bar: StatusBar,

    // Active views
    editors: std.ArrayList(*Editor),
    terminals: std.ArrayList(*TerminalSession),
    terminal_widgets: std.ArrayList(TerminalWidget),
    terminal_workspace: ?TerminalWorkspace,

    // Themes
    app_theme: app_shell.Theme,
    editor_theme: app_shell.Theme,
    terminal_theme: app_shell.Theme,
    shell_base_theme: app_shell.Theme,

    // Current focus
    active_tab: usize,
    active_kind: app_modes.ide.ActiveMode,

    // UI state
    mode: []const u8,
    show_terminal: bool,
    terminal_height: f32,
    terminal_blink_style: TerminalWidget.BlinkStyle,
    terminal_cursor_style: ?term_types.CursorStyle,
    terminal_scrollback_rows: ?usize,
    editor_tab_bar_width_mode: TabBar.WidthMode,
    terminal_tab_bar_show_single_tab: bool,
    terminal_tab_bar_width_mode: TabBar.WidthMode,
    terminal_focus_report_window_events: bool,
    terminal_focus_report_pane_events: bool,
    last_terminal_pane_focus_reported: ?bool,
    config_reload_notice_until: f64,
    config_reload_notice_success: bool,

    // Dirty tracking for efficient rendering
    needs_redraw: bool,
    idle_frames: u32, // Count frames without activity for adaptive sleep
    last_mouse_pos: app_shell.MousePos,
    resizing_terminal: bool,
    resize_start_y: f32,
    resize_start_height: f32,
    window_resize_pending: bool,
    window_resize_last_time: f64,
    mouse_debug: bool,
    terminal_scroll_dragging: bool,
    terminal_scroll_grab_offset: f32,
    last_mouse_redraw_time: f64,
    last_ctrl_down: bool,
    editor_dragging: bool,
    editor_drag_start: types.CursorPos,
    editor_drag_rect: bool,
    editor_hscroll_dragging: bool,
    editor_hscroll_grab_offset: f32,
    editor_vscroll_dragging: bool,
    editor_vscroll_grab_offset: f32,
    editor_cluster_cache: EditorClusterCache,
    editor_render_cache: EditorRenderCache,
    grammar_manager: grammar_manager_mod.GrammarManager,
    last_cursor_blink_on: bool,
    last_cursor_blink_armed: bool,
    frame_id: u64,
    metrics: Metrics,
    metrics_logger: Logger,
    input_latency_logger: Logger,
    app_logger: Logger,
    last_metrics_log_time: f64,
    editor_wrap: bool,
    editor_large_jump_rows: usize,
    editor_highlight_budget: ?usize,
    editor_width_budget: ?usize,
    perf_mode: bool,
    perf_frames_total: u64,
    perf_frames_done: u64,
    perf_scroll_delta: i32,
    perf_file_path: ?[]u8,
    perf_logger: Logger,
    last_input: shared_types.input.InputSnapshot,
    app_mode: AppMode,
    input_router: input_actions.InputRouter,
    editor_mode_adapter: app_modes.backend.EditorMode,
    terminal_mode_adapter: app_modes.backend.TerminalMode,
    font_sample_view: ?font_sample_view_mod.FontSampleView,
    font_sample_auto_close_frames: u64,
    font_sample_close_pending: bool,
    font_sample_screenshot_path: ?[]const u8,
    search_panel: SearchPanelState,
    terminal_close_confirm_tab: ?terminal_mod.TerminalTabId,

    fn applyCurrentTabBarWidthMode(self: *AppState) void {
        app_tab_bar_width.applyForMode(
            &self.tab_bar,
            self.app_mode,
            self.editor_tab_bar_width_mode,
            self.terminal_tab_bar_width_mode,
        );
    }

    pub fn init(allocator: std.mem.Allocator, app_mode: AppMode) !*AppState {
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
        const shell = try Shell.init(allocator, window_width, window_height, "Zide - Zig IDE");
        errdefer shell.deinit(allocator);

        // Apply font rendering knobs before (re)loading fonts.
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

        const terminal_blink_style: TerminalWidget.BlinkStyle = switch (config.terminal_blink_style orelse .kitty) {
            .kitty => .kitty,
            .off => .off,
        };
        var terminal_cursor_style: ?term_types.CursorStyle = null;
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

        shell.setTheme(app_theme); // Default to app theme

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

        const state = try allocator.create(AppState);
        state.* = .{
            .allocator = allocator,
            .shell = shell,
            .options_bar = .{},
            .tab_bar = TabBar.init(allocator),
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
            .search_panel = SearchPanelState.init(allocator),
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
                        const cb_state: *AppState = @ptrCast(@alignCast(raw));
                        cb_state.applyCurrentTabBarWidthMode();
                    }
                }.call,
            },
        );
        state.applyCurrentTabBarWidthMode();

        return state;
    }

    pub fn deinit(self: *AppState) void {
        if (self.font_sample_view) |*view| {
            view.deinit();
        }
        for (self.editors.items) |e| {
            e.deinit();
        }
        self.editors.deinit(self.allocator);

        for (self.terminal_widgets.items) |*widget| {
            widget.deinit();
        }
        self.terminal_widgets.deinit(self.allocator);
        if (self.terminal_workspace) |*workspace| {
            workspace.deinit();
            self.terminal_workspace = null;
        } else {
            for (self.terminals.items) |t| {
                t.deinit();
            }
        }
        self.terminals.deinit(self.allocator);

        self.tab_bar.deinit();
        self.shell.deinit(self.allocator);
        self.editor_render_cache.deinit();
        self.editor_cluster_cache.deinit();
        self.grammar_manager.deinit();
        self.input_router.deinit();
        self.editor_mode_adapter.deinit(self.allocator);
        self.terminal_mode_adapter.deinit(self.allocator);
        self.search_panel.deinit(self.allocator);
        if (self.perf_file_path) |path| {
            self.allocator.free(path);
        }
        app_logger.deinit();
        self.allocator.destroy(self);
    }

    pub fn newEditor(self: *AppState) !void {
        _ = try app_editor_intent_route.routeCreateAndSync(@ptrCast(self), routeEditorTabActionFromCtx);
        const editor = try Editor.init(self.allocator, &self.grammar_manager);
        try self.editors.append(self.allocator, editor);
        try self.tab_bar.addTab("untitled", .editor);
        self.active_tab = self.tab_bar.tabs.items.len - 1;
        self.active_kind = .editor;
        try self.syncModeAdaptersFromTabBar();
    }

    pub fn openFile(self: *AppState, path: []const u8) !void {
        _ = try app_editor_intent_route.routeCreateAndSync(@ptrCast(self), routeEditorTabActionFromCtx);
        const editor = try Editor.init(self.allocator, &self.grammar_manager);
        try editor.openFile(path);
        try self.editors.append(self.allocator, editor);

        // Extract filename for tab title
        const filename = std.fs.path.basename(path);
        try self.tab_bar.addTab(filename, .editor);
        self.active_tab = self.tab_bar.tabs.items.len - 1;
        self.active_kind = .editor;
        try self.syncModeAdaptersFromTabBar();
    }

    pub fn openFileAt(self: *AppState, path: []const u8, line_1: usize, col_1: ?usize) !void {
        _ = try app_editor_intent_route.routeCreateAndSync(@ptrCast(self), routeEditorTabActionFromCtx);
        const editor = try Editor.init(self.allocator, &self.grammar_manager);
        try editor.openFile(path);
        try self.editors.append(self.allocator, editor);

        const filename = std.fs.path.basename(path);
        try self.tab_bar.addTab(filename, .editor);
        self.active_tab = self.tab_bar.tabs.items.len - 1;
        self.active_kind = .editor;
        try self.syncModeAdaptersFromTabBar();

        const line0 = if (line_1 > 0) line_1 - 1 else 0;
        const col0 = if (col_1) |c1| (if (c1 > 0) c1 - 1 else 0) else 0;
        const clamped_line = @min(line0, editor.lineCount() -| 1);
        const line_len = editor.lineLen(clamped_line);
        const clamped_col = @min(col0, line_len);
        editor.setCursor(clamped_line, clamped_col);
    }

    fn handleSearchPanelInput(self: *AppState, editor: *Editor, input_batch: *shared_types.input.InputBatch) !bool {
        if (!self.search_panel.active) return false;

        var handled = false;
        var query_changed = false;
        const command_result = app_search_panel_runtime.applyCommand(
            app_search_panel_input.searchPanelCommand(input_batch),
            editor,
            &self.search_panel.active,
            &self.search_panel.query,
        );
        if (command_result.handled and !command_result.query_changed) return true;
        handled = command_result.handled;
        query_changed = command_result.query_changed;

        if (try app_search_panel_input.appendSearchPanelTextEvents(self.allocator, &self.search_panel.query, input_batch)) {
            query_changed = true;
            handled = true;
        }

        if (query_changed) {
            try app_search_panel_state.syncEditorSearchQuery(editor, &self.search_panel.query);
        }

        return handled;
    }

    fn syncModeAdaptersFromTabBar(self: *AppState) !void {
        try app_mode_adapter_sync.syncFromTabBar(
            self.allocator,
            self.active_kind,
            self.tab_bar.tabs.items,
            self.tab_bar.active_index,
            &self.editor_mode_adapter,
            &self.terminal_mode_adapter,
        );
        app_mode_adapter_parity.logIfMismatch(
            self.allocator,
            self.active_kind,
            self.tab_bar.tabs.items,
            self.tab_bar.active_index,
            &self.editor_mode_adapter,
            &self.terminal_mode_adapter,
        );
    }

    fn requestCloseActiveTerminalTab(self: *AppState, now: f64) !bool {
        _ = try app_terminal_runtime_intents.routeForActiveWorkspaceTabAndSync(
            .close,
            &self.terminal_workspace,
            @ptrCast(self),
            routeTerminalTabActionFromCtx,
        );
        if (try app_terminal_close_active_runtime.closeActive(
            self,
            @ptrCast(self),
            .{
                .sync_terminal_mode_tab_bar = struct {
                    fn call(raw: *anyopaque) !void {
                        const state: *AppState = @ptrCast(@alignCast(raw));
                        if (!app_modes.ide.shouldUseTerminalWorkspace(state.app_mode)) return;
                        try app_terminal_tab_bar_sync.syncFromWorkspace(&state.tab_bar, &state.terminal_workspace);
                        try state.syncModeAdaptersFromTabBar();
                    }
                }.call,
            },
        )) {
            self.needs_redraw = true;
            self.metrics.noteInput(now);
            return true;
        }
        if (app_terminal_close_confirm_active_runtime.reconcile(self)) {
            self.needs_redraw = true;
            self.metrics.noteInput(now);
            return true;
        }
        return false;
    }

    fn requestCreateTerminalTab(self: *AppState, now: f64) !bool {
        app_tab_action_apply.applyTerminal(self.allocator, self.app_mode, &self.terminal_mode_adapter, .create);
        try self.syncModeAdaptersFromTabBar();
        try self.newTerminal();
        if (app_modes.ide.shouldUseTerminalWorkspace(self.app_mode)) {
            try app_terminal_tab_bar_sync.syncFromWorkspace(&self.tab_bar, &self.terminal_workspace);
            try self.syncModeAdaptersFromTabBar();
        }
        self.needs_redraw = true;
        self.metrics.noteInput(now);
        return true;
    }

    fn requestCycleTerminalTabWithIntent(
        self: *AppState,
        dir: app_modes.ide.TerminalShortcutCycleDirection,
        now: f64,
    ) !bool {
        const moved = app_terminal_tab_navigation_runtime.cycle(self, dir == .next);
        if (!moved) return false;
        app_tab_action_apply.applyTerminal(
            self.allocator,
            self.app_mode,
            &self.terminal_mode_adapter,
            app_terminal_tab_intents.cycleIntentForDirection(dir),
        );
        try self.syncModeAdaptersFromTabBar();
        self.needs_redraw = true;
        self.metrics.noteInput(now);
        return true;
    }

    fn requestFocusTerminalTabWithIntent(
        self: *AppState,
        route: app_modes.ide.TerminalFocusRoute,
        now: f64,
    ) !bool {
        app_tab_action_apply.applyTerminal(self.allocator, self.app_mode, &self.terminal_mode_adapter, route.intent);
        try self.syncModeAdaptersFromTabBar();
        if (!app_terminal_tab_navigation_runtime.focusByIndex(self, route.index)) return false;
        self.needs_redraw = true;
        self.metrics.noteInput(now);
        return true;
    }

    fn handleTerminalShortcutIntent(
        self: *AppState,
        intent: app_modes.ide.TerminalShortcutIntent,
        now: f64,
    ) !bool {
        if (!app_terminal_shortcut_policy.canHandleIntent(self.app_mode, intent)) return false;
        const hooks: app_terminal_shortcut_runtime.RuntimeHooks = .{
            .request_create = struct {
                fn call(raw: *anyopaque, at: f64) !bool {
                    const state: *AppState = @ptrCast(@alignCast(raw));
                    return state.requestCreateTerminalTab(at);
                }
            }.call,
            .request_close = struct {
                fn call(raw: *anyopaque, at: f64) !bool {
                    const state: *AppState = @ptrCast(@alignCast(raw));
                    return state.requestCloseActiveTerminalTab(at);
                }
            }.call,
            .request_cycle = struct {
                fn call(raw: *anyopaque, dir: app_modes.ide.TerminalShortcutCycleDirection, at: f64) !bool {
                    const state: *AppState = @ptrCast(@alignCast(raw));
                    return state.requestCycleTerminalTabWithIntent(dir, at);
                }
            }.call,
            .request_focus = struct {
                fn call(raw: *anyopaque, route: app_modes.ide.TerminalFocusRoute, at: f64) !bool {
                    const state: *AppState = @ptrCast(@alignCast(raw));
                    return state.requestFocusTerminalTabWithIntent(route, at);
                }
            }.call,
        };
        return app_terminal_shortcut_runtime.handleIntent(intent, now, @ptrCast(self), hooks);
    }

    fn routeTerminalTabActionFromCtx(raw: *anyopaque, action: app_modes.shared.actions.TabAction) !void {
        const state: *AppState = @ptrCast(@alignCast(raw));
        app_tab_action_apply.applyTerminal(state.allocator, state.app_mode, &state.terminal_mode_adapter, action);
        try state.syncModeAdaptersFromTabBar();
    }

    fn routeEditorTabActionFromCtx(raw: *anyopaque, action: app_modes.shared.actions.TabAction) !void {
        const state: *AppState = @ptrCast(@alignCast(raw));
        app_tab_action_apply.applyEditor(state.allocator, state.app_mode, &state.editor_mode_adapter, action);
        try state.syncModeAdaptersFromTabBar();
    }

    fn handleIdeMousePressedRouting(
        self: *AppState,
        layout: layout_types.WidgetLayout,
        mouse: shared_types.input.MousePos,
        term_y: f32,
        now: f64,
    ) !void {
        const tab_bar_y = self.options_bar.height;
        _ = self.tab_bar.beginDrag(mouse.x, mouse.y, layout.side_nav.width, tab_bar_y, layout.tab_bar.width);
        if (self.tab_bar.handleClick(mouse.x, mouse.y, layout.side_nav.width, tab_bar_y, layout.tab_bar.width)) {
            self.active_tab = self.tab_bar.active_index;
            _ = try app_editor_intent_route.routeActivateByIndexAndSync(
                self.active_tab,
                @ptrCast(self),
                routeEditorTabActionFromCtx,
            );
            self.needs_redraw = true;
            self.metrics.noteInput(now);
        }

        const editor_x = layout.editor.x;
        const editor_y = layout.editor.y;
        const in_editor = mouse.x >= editor_x and mouse.x <= editor_x + layout.editor.width and
            mouse.y >= editor_y and mouse.y <= editor_y + layout.editor.height;

        const in_terminal = layout.terminal.height > 0 and mouse.y >= term_y and mouse.y <= term_y + layout.terminal.height;

        if (in_terminal and self.show_terminal) {
            if (self.active_kind != .terminal) {
                self.active_kind = .terminal;
                try self.syncModeAdaptersFromTabBar();
                self.needs_redraw = true;
                self.metrics.noteInput(now);
            }
        } else if (in_editor) {
            if (self.active_kind != .editor) {
                self.active_kind = .editor;
                try self.syncModeAdaptersFromTabBar();
                self.needs_redraw = true;
                self.metrics.noteInput(now);
            }
        }
    }

    fn handleTerminalMousePressedRouting(
        self: *AppState,
        layout: layout_types.WidgetLayout,
        mouse: shared_types.input.MousePos,
    ) !void {
        if (app_terminal_tabs_runtime.barVisible(
            self.app_mode,
            self.terminal_tab_bar_show_single_tab,
            self.terminal_workspace,
            self.terminals.items.len,
        )) {
            _ = self.tab_bar.beginDrag(mouse.x, mouse.y, layout.tab_bar.x, layout.tab_bar.y, layout.tab_bar.width);
        }
        if (self.active_kind != .terminal) {
            self.active_kind = .terminal;
            try self.syncModeAdaptersFromTabBar();
        }
        _ = try app_terminal_runtime_intents.routeForActiveWorkspaceTabAndSync(
            .activate,
            &self.terminal_workspace,
            @ptrCast(self),
            routeTerminalTabActionFromCtx,
        );
    }

    fn handleEditorMousePressedRouting(self: *AppState) !void {
        if (self.active_kind != .editor) {
            self.active_kind = .editor;
            try self.syncModeAdaptersFromTabBar();
        }
    }

    fn handleTerminalTabDragInput(
        self: *AppState,
        input_batch: *shared_types.input.InputBatch,
        layout: layout_types.WidgetLayout,
        mouse: shared_types.input.MousePos,
        now: f64,
    ) !void {
        const drag_frame = app_modes.ide.processTabDragFrame(
            &self.tab_bar,
            input_batch,
            mouse,
            layout.tab_bar.x,
            layout.tab_bar.y,
            layout.tab_bar.width,
            app_terminal_tabs_runtime.barVisible(
                self.app_mode,
                self.terminal_tab_bar_show_single_tab,
                self.terminal_workspace,
                self.terminals.items.len,
            ),
        );
        if (drag_frame.updated) {
            self.needs_redraw = true;
            self.metrics.noteInput(now);
        }
        if (drag_frame.release) |drag_end| {
            const release_plan = app_modes.ide.terminalTabDragReleasePlan(drag_end);
            if (release_plan.intent) |intent| {
                app_tab_action_apply.applyTerminal(self.allocator, self.app_mode, &self.terminal_mode_adapter, intent);
                try self.syncModeAdaptersFromTabBar();
            }
            if (release_plan.handle_click) {
                if (self.tab_bar.handleClick(mouse.x, mouse.y, layout.tab_bar.x, layout.tab_bar.y, layout.tab_bar.width)) {
                    _ = try app_terminal_runtime_intents.routeByTabIdAndSync(
                        .activate,
                        self.tab_bar.terminalTabIdAtVisual(self.tab_bar.active_index),
                        @ptrCast(self),
                        routeTerminalTabActionFromCtx,
                    );
                    if (app_terminal_tab_navigation_runtime.focusByIndex(self, self.tab_bar.active_index)) {
                        self.needs_redraw = true;
                        self.metrics.noteInput(now);
                    }
                }
            }
            if (release_plan.mark_redraw) {
                self.needs_redraw = true;
                self.metrics.noteInput(now);
            }
        }
    }

    fn handleIdeTabDragInput(
        self: *AppState,
        input_batch: *shared_types.input.InputBatch,
        layout: layout_types.WidgetLayout,
        mouse: shared_types.input.MousePos,
        now: f64,
    ) !void {
        const drag_frame = app_modes.ide.processTabDragFrame(
            &self.tab_bar,
            input_batch,
            mouse,
            layout.tab_bar.x,
            layout.tab_bar.y,
            layout.tab_bar.width,
            true,
        );
        if (drag_frame.updated) {
            self.needs_redraw = true;
            self.metrics.noteInput(now);
        }
        if (drag_frame.release) |drag_end| {
            const release_plan = app_modes.ide.ideEditorTabDragReleasePlan(drag_end);
            if (release_plan.intent) |intent| {
                app_tab_action_apply.applyEditor(self.allocator, self.app_mode, &self.editor_mode_adapter, intent);
                try self.syncModeAdaptersFromTabBar();
                if (release_plan.sync_active_tab) {
                    self.active_tab = self.tab_bar.active_index;
                }
                if (release_plan.mark_redraw) {
                    self.needs_redraw = true;
                    self.metrics.noteInput(now);
                }
            }
        }
    }

    fn handleEditorScrollbarInput(
        self: *AppState,
        widget: *EditorWidget,
        shell: *Shell,
        layout: layout_types.WidgetLayout,
        mouse: shared_types.input.MousePos,
        input_batch: *shared_types.input.InputBatch,
        now: f64,
    ) bool {
        const editor_x = layout.editor.x;
        const editor_y = layout.editor.y;
        const mouse_shell = app_shell.MousePos{ .x = mouse.x, .y = mouse.y };
        const hscroll_handled = widget.handleHorizontalScrollbarInput(
            shell,
            editor_x,
            editor_y,
            layout.editor.width,
            layout.editor.height,
            mouse_shell,
            &self.editor_hscroll_dragging,
            &self.editor_hscroll_grab_offset,
            input_batch,
        );
        const vscroll_handled = widget.handleVerticalScrollbarInput(
            shell,
            editor_x,
            editor_y,
            layout.editor.width,
            layout.editor.height,
            mouse_shell,
            &self.editor_vscroll_dragging,
            &self.editor_vscroll_grab_offset,
            input_batch,
        );
        if (hscroll_handled or vscroll_handled) {
            self.needs_redraw = true;
            self.metrics.noteInput(now);
        }
        return hscroll_handled or vscroll_handled;
    }

    fn handleEditorMouseSelectionInput(
        self: *AppState,
        widget: *EditorWidget,
        shell: *Shell,
        layout: layout_types.WidgetLayout,
        mouse: shared_types.input.MousePos,
        input_batch: *shared_types.input.InputBatch,
        scrollbar_blocking: bool,
        now: f64,
    ) void {
        const editor_x = layout.editor.x;
        const editor_y = layout.editor.y;
        const in_editor = mouse.x >= editor_x and mouse.x <= editor_x + layout.editor.width and
            mouse.y >= editor_y and mouse.y <= editor_y + layout.editor.height;
        const alt = input_batch.mods.alt;

        if (!scrollbar_blocking and input_batch.mousePressed(.left) and in_editor) {
            if (widget.cursorFromMouse(shell, editor_x, editor_y, layout.editor.width, layout.editor.height, mouse.x, mouse.y, false)) |pos| {
                widget.editor.setCursor(pos.line, pos.col);
                widget.editor.selection = null;
                widget.editor.clearSelections();
                self.editor_dragging = true;
                self.editor_drag_start = pos;
                self.editor_drag_rect = alt;
                if (alt) {
                    widget.editor.expandRectSelection(pos.line, pos.line, pos.col, pos.col) catch {};
                } else {
                    widget.editor.selection = .{ .start = pos, .end = pos };
                }
                self.needs_redraw = true;
                self.metrics.noteInput(now);
            }
        }

        if (!scrollbar_blocking and self.editor_dragging and input_batch.mouseDown(.left)) {
            if (widget.cursorFromMouse(shell, editor_x, editor_y, layout.editor.width, layout.editor.height, mouse.x, mouse.y, true)) |pos| {
                widget.editor.setCursorNoClear(pos.line, pos.col);
                if (self.editor_drag_rect) {
                    widget.editor.clearSelections();
                    const start_line = @min(self.editor_drag_start.line, pos.line);
                    const end_line = @max(self.editor_drag_start.line, pos.line);
                    const start_col = @min(self.editor_drag_start.col, pos.col);
                    const end_col = @max(self.editor_drag_start.col, pos.col);
                    widget.editor.expandRectSelection(start_line, end_line, start_col, end_col) catch {};
                    widget.editor.selection = null;
                } else {
                    widget.editor.selection = .{ .start = self.editor_drag_start, .end = pos };
                    widget.editor.clearSelections();
                }
                self.needs_redraw = true;
                self.metrics.noteInput(now);
            }
        }

        if (self.editor_dragging and input_batch.mouseReleased(.left)) {
            self.editor_dragging = false;
            if (!self.editor_drag_rect) {
                if (widget.editor.selection) |sel| {
                    if (sel.start.offset == sel.end.offset) {
                        widget.editor.selection = null;
                    }
                }
            } else if (widget.editor.selectionCount() == 0) {
                widget.editor.selection = null;
            }
            self.needs_redraw = true;
        }
    }

    fn handleTerminalPendingOpenRequest(
        self: *AppState,
        term_widget: *TerminalWidget,
        now: f64,
    ) !void {
        if (term_widget.takePendingOpenRequest()) |req| {
            defer self.allocator.free(req.path);
            if (app_file_detect.isProbablyTextFile(req.path)) {
                if (req.line != null) {
                    try self.openFileAt(req.path, req.line.?, req.col);
                } else {
                    try self.openFile(req.path);
                }
                self.needs_redraw = true;
                self.metrics.noteInput(now);
            }
        }
    }

    fn handleTerminalWidgetInput(
        self: *AppState,
        term_widget: *TerminalWidget,
        shell: *Shell,
        term_x: f32,
        term_y: f32,
        term_width: f32,
        term_height: f32,
        allow_terminal_input: bool,
        suppress_terminal_shortcuts: bool,
        input_batch: *shared_types.input.InputBatch,
        search_panel_consumed_input: bool,
        now: f64,
    ) !void {
        if (!search_panel_consumed_input and try term_widget.handleInput(
            shell,
            term_x,
            term_y,
            term_width,
            term_height,
            allow_terminal_input,
            &self.terminal_scroll_dragging,
            &self.terminal_scroll_grab_offset,
            suppress_terminal_shortcuts,
            input_batch,
        )) {
            self.needs_redraw = true;
            self.metrics.noteInput(now);
        }
        try self.handleTerminalPendingOpenRequest(term_widget, now);
    }

    fn precomputeEditorVisibleCaches(
        self: *AppState,
        widget: *EditorWidget,
        shell: *Shell,
        layout: layout_types.WidgetLayout,
    ) void {
        if (layout.editor.width <= 0 or layout.editor.height <= 0) return;
        app_editor_display_prepare.prepare(widget.editor, &self.editor_render_cache);
        const visible_lines = @as(usize, @intFromFloat(layout.editor.height / shell.charHeight()));
        const default_budget = if (visible_lines > 0) visible_lines + 1 else 0;
        const highlight_budget = self.editor_highlight_budget orelse default_budget;
        editor_draw.precomputeHighlightTokens(widget, &self.editor_render_cache, shell, layout.editor.height, highlight_budget);
        const width_budget = self.editor_width_budget orelse highlight_budget;
        editor_draw.precomputeLineWidths(widget, &self.editor_render_cache, shell, layout.editor.height, width_budget);
        editor_draw.precomputeWrapCounts(widget, &self.editor_render_cache, shell, layout.editor.height, width_budget);
    }

    fn pollVisibleTerminalSessions(
        self: *AppState,
        input_batch: *shared_types.input.InputBatch,
    ) !void {
        if (!app_terminal_surface_gate.hasVisibleTerminalTabs(self.app_mode, self.show_terminal, self.terminal_workspace, self.terminals.items.len)) return;

        if (app_modes.ide.shouldUseTerminalWorkspace(self.app_mode)) {
            if (self.terminal_workspace) |*workspace| {
                const polled = try workspace.pollAll(
                    app_terminal_tabs_runtime.activeIndex(
                        self.app_mode,
                        self.terminal_workspace,
                        self.terminals.items.len,
                    ),
                    input_batch.events.items.len > 0,
                );
                if (polled) self.needs_redraw = true;
            }
            return;
        }

        if (self.terminals.items.len > 0) {
            const term = self.terminals.items[0];
            if (term.hasData()) {
                term.setInputPressure(input_batch.events.items.len > 0);
                try term.poll();
                self.needs_redraw = true;
            }
        }
    }

    fn handleSearchPanelFrameInput(
        self: *AppState,
        input_batch: *shared_types.input.InputBatch,
        now: f64,
    ) !bool {
        if (!self.search_panel.active) return false;
        if (self.editors.items.len == 0) return false;
        const editor = self.editors.items[@min(self.active_tab, self.editors.items.len - 1)];
        if (try self.handleSearchPanelInput(editor, input_batch)) {
            self.editor_cluster_cache.clear();
            self.needs_redraw = true;
            self.metrics.noteInput(now);
            return true;
        }
        return false;
    }

    fn handleActiveEditorFrame(
        self: *AppState,
        shell: *Shell,
        layout: layout_types.WidgetLayout,
        mouse: shared_types.input.MousePos,
        input_batch: *shared_types.input.InputBatch,
        search_panel_consumed_input: bool,
        now: f64,
    ) !void {
        const result = try app_active_editor_frame.handle(
            self.app_mode,
            self.active_kind,
            self.editors.items,
            self.active_tab,
            &self.editor_cluster_cache,
            self.editor_wrap,
            shell,
            layout,
            mouse,
            input_batch,
            search_panel_consumed_input,
            self.perf_mode,
            self.perf_frames_done,
            self.perf_frames_total,
            self.perf_scroll_delta,
            now,
            @ptrCast(self),
            .{
                .handle_editor_scrollbar_input = struct {
                    fn call(
                        raw: *anyopaque,
                        widget: *EditorWidget,
                        frame_shell: *Shell,
                        frame_layout: layout_types.WidgetLayout,
                        frame_mouse: shared_types.input.MousePos,
                        frame_input_batch: *shared_types.input.InputBatch,
                        frame_now: f64,
                    ) bool {
                        const state: *AppState = @ptrCast(@alignCast(raw));
                        return state.handleEditorScrollbarInput(
                            widget,
                            frame_shell,
                            frame_layout,
                            frame_mouse,
                            frame_input_batch,
                            frame_now,
                        );
                    }
                }.call,
                .handle_editor_mouse_selection_input = struct {
                    fn call(
                        raw: *anyopaque,
                        widget: *EditorWidget,
                        frame_shell: *Shell,
                        frame_layout: layout_types.WidgetLayout,
                        frame_mouse: shared_types.input.MousePos,
                        frame_input_batch: *shared_types.input.InputBatch,
                        scrollbar_blocking: bool,
                        frame_now: f64,
                    ) void {
                        const state: *AppState = @ptrCast(@alignCast(raw));
                        state.handleEditorMouseSelectionInput(
                            widget,
                            frame_shell,
                            frame_layout,
                            frame_mouse,
                            frame_input_batch,
                            scrollbar_blocking,
                            frame_now,
                        );
                    }
                }.call,
                .precompute_editor_visible_caches = struct {
                    fn call(
                        raw: *anyopaque,
                        widget: *EditorWidget,
                        frame_shell: *Shell,
                        frame_layout: layout_types.WidgetLayout,
                    ) void {
                        const state: *AppState = @ptrCast(@alignCast(raw));
                        state.precomputeEditorVisibleCaches(widget, frame_shell, frame_layout);
                    }
                }.call,
            },
        );
        if (result.clear_editor_cluster_cache) self.editor_cluster_cache.clear();
        if (result.needs_redraw) self.needs_redraw = true;
        if (result.note_input) self.metrics.noteInput(now);
        if (result.perf_frames_done_inc) self.perf_frames_done +|= 1;
    }

    fn handleVisibleTerminalFrame(
        self: *AppState,
        shell: *Shell,
        layout: layout_types.WidgetLayout,
        input_batch: *shared_types.input.InputBatch,
        search_panel_consumed_input: bool,
        suppress_terminal_shortcuts: bool,
        terminal_close_modal_active: bool,
        now: f64,
    ) !void {
        const result = try app_visible_terminal_frame.handle(
            self.app_mode,
            self.show_terminal,
            &self.terminal_workspace,
            self.terminals.items.len,
            self.terminal_widgets.items,
            self.tab_bar.isDragging(),
            self.active_kind,
            shell,
            layout,
            input_batch,
            search_panel_consumed_input,
            suppress_terminal_shortcuts,
            terminal_close_modal_active,
            now,
            @ptrCast(self),
            .{
                .poll_visible_sessions = struct {
                    fn call(raw: *anyopaque, batch: *shared_types.input.InputBatch) !void {
                        const state: *AppState = @ptrCast(@alignCast(raw));
                        try state.pollVisibleTerminalSessions(batch);
                    }
                }.call,
                .handle_terminal_widget_input = struct {
                    fn call(
                        raw: *anyopaque,
                        term_widget: *TerminalWidget,
                        frame_shell: *Shell,
                        term_x: f32,
                        term_y_draw: f32,
                        term_width: f32,
                        term_draw_height: f32,
                        allow_terminal_input: bool,
                        frame_suppress_terminal_shortcuts: bool,
                        frame_input_batch: *shared_types.input.InputBatch,
                        frame_search_panel_consumed_input: bool,
                        frame_now: f64,
                    ) !void {
                        const state: *AppState = @ptrCast(@alignCast(raw));
                        try state.handleTerminalWidgetInput(
                            term_widget,
                            frame_shell,
                            term_x,
                            term_y_draw,
                            term_width,
                            term_draw_height,
                            allow_terminal_input,
                            frame_suppress_terminal_shortcuts,
                            frame_input_batch,
                            frame_search_panel_consumed_input,
                            frame_now,
                        );
                    }
                }.call,
            },
        );
        if (result.needs_redraw) self.needs_redraw = true;
    }

    fn handleActiveViewFrame(
        self: *AppState,
        shell: *Shell,
        layout: layout_types.WidgetLayout,
        mouse: shared_types.input.MousePos,
        input_batch: *shared_types.input.InputBatch,
        suppress_terminal_shortcuts: bool,
        terminal_close_modal_active: bool,
        now: f64,
    ) !void {
        const search_panel_consumed_input = try self.handleSearchPanelFrameInput(input_batch, now);
        try self.handleActiveEditorFrame(shell, layout, mouse, input_batch, search_panel_consumed_input, now);
        try self.handleVisibleTerminalFrame(
            shell,
            layout,
            input_batch,
            search_panel_consumed_input,
            suppress_terminal_shortcuts,
            terminal_close_modal_active,
            now,
        );
        if (app_modes.ide.shouldUseTerminalWorkspace(self.app_mode)) {
            try app_terminal_tab_bar_sync.syncFromWorkspace(&self.tab_bar, &self.terminal_workspace);
            try self.syncModeAdaptersFromTabBar();
        }
    }

    fn handleShortcutAction(
        self: *AppState,
        shell: *Shell,
        kind: input_actions.ActionKind,
        now: f64,
        handled_zoom: *bool,
        zoom_log: Logger,
    ) !bool {
        const result = try app_shortcut_action_runtime.handle(
            kind,
            self.app_mode,
            &self.show_terminal,
            self.terminals.items.len,
            shell,
            now,
            zoom_log,
            @ptrCast(self),
            .{
                .new_editor = struct {
                    fn call(raw: *anyopaque) !void {
                        const state: *AppState = @ptrCast(@alignCast(raw));
                        try state.newEditor();
                    }
                }.call,
                .new_terminal = struct {
                    fn call(raw: *anyopaque) !void {
                        const state: *AppState = @ptrCast(@alignCast(raw));
                        try state.newTerminal();
                    }
                }.call,
                .handle_terminal_shortcut_intent = struct {
                    fn call(raw: *anyopaque, intent: app_modes.ide.TerminalShortcutIntent, at: f64) !bool {
                        const state: *AppState = @ptrCast(@alignCast(raw));
                        return try state.handleTerminalShortcutIntent(intent, at);
                    }
                }.call,
            },
        );
        if (result.needs_redraw) self.needs_redraw = true;
        if (result.note_input) self.metrics.noteInput(now);
        if (result.handled_zoom) handled_zoom.* = true;
        return result.handled;
    }

    fn handleMousePressedFrame(
        self: *AppState,
        shell: *Shell,
        layout: layout_types.WidgetLayout,
        mouse: shared_types.input.MousePos,
        term_y: f32,
        input_batch: *shared_types.input.InputBatch,
        now: f64,
    ) !void {
        _ = shell;
        try app_mouse_pressed_frame.handle(
            self.app_mode,
            input_batch,
            layout,
            mouse,
            term_y,
            now,
            @ptrCast(self),
            .{
                .handle_ide_mouse_pressed_routing = struct {
                    fn call(
                        raw: *anyopaque,
                        frame_layout: layout_types.WidgetLayout,
                        frame_mouse: shared_types.input.MousePos,
                        frame_term_y: f32,
                        frame_now: f64,
                    ) !void {
                        const state: *AppState = @ptrCast(@alignCast(raw));
                        try state.handleIdeMousePressedRouting(frame_layout, frame_mouse, frame_term_y, frame_now);
                    }
                }.call,
                .handle_terminal_mouse_pressed_routing = struct {
                    fn call(
                        raw: *anyopaque,
                        frame_layout: layout_types.WidgetLayout,
                        frame_mouse: shared_types.input.MousePos,
                    ) !void {
                        const state: *AppState = @ptrCast(@alignCast(raw));
                        try state.handleTerminalMousePressedRouting(frame_layout, frame_mouse);
                    }
                }.call,
                .handle_editor_mouse_pressed_routing = struct {
                    fn call(raw: *anyopaque) !void {
                        const state: *AppState = @ptrCast(@alignCast(raw));
                        try state.handleEditorMousePressedRouting();
                    }
                }.call,
                .log_mouse_debug_click = struct {
                    fn call(raw: *anyopaque) void {
                        const state: *AppState = @ptrCast(@alignCast(raw));
                        app_mouse_debug_log.log(state.shell, state.mouse_debug);
                    }
                }.call,
            },
        );
    }

    const PreInputShortcutResult = struct {
        suppress_terminal_shortcuts: bool,
        terminal_close_modal_active: bool,
        handled_shortcut: bool,
        consumed: bool,
    };

    fn handlePreInputShortcutFrame(
        self: *AppState,
        shell: *Shell,
        r: anytype,
        input_batch: *shared_types.input.InputBatch,
        focus: input_actions.FocusKind,
        now: f64,
    ) !PreInputShortcutResult {
        var handled_shortcut = app_reload_config_shortcut_runtime.handle(
            self.input_router.actionsSlice(),
            @ptrCast(self),
            .{
                .reload = struct {
                    fn call(raw: *anyopaque) !void {
                        const state: *AppState = @ptrCast(@alignCast(raw));
                        try app_reload_config_runtime.handle(
                            state,
                            raw,
                            .{
                                .refresh_terminal_sizing = struct {
                                    fn cb(cb_raw: *anyopaque) !void {
                                        const cb_state: *AppState = @ptrCast(@alignCast(cb_raw));
                                        try app_terminal_refresh_sizing_runtime.handle(
                                            cb_state,
                                            cb_state.app_mode,
                                            &cb_state.terminal_workspace,
                                            cb_state.terminals.items,
                                            cb_state.show_terminal,
                                            cb_state.terminal_height,
                                            cb_state.shell,
                                        );
                                    }
                                }.cb,
                                .apply_current_tab_bar_width_mode = struct {
                                    fn cb(cb_raw: *anyopaque) void {
                                        const cb_state: *AppState = @ptrCast(@alignCast(cb_raw));
                                        cb_state.applyCurrentTabBarWidthMode();
                                    }
                                }.cb,
                            },
                        );
                    }
                }.call,
                .show_notice = struct {
                    fn call(raw: *anyopaque, success: bool) void {
                        const state: *AppState = @ptrCast(@alignCast(raw));
                        const notice = app_config_reload_notice_state.arm(app_shell.getTime(), success);
                        state.config_reload_notice_success = notice.success;
                        state.config_reload_notice_until = notice.until;
                        state.needs_redraw = true;
                    }
                }.call,
            },
        );
        const live_layout = app_ui_layout_runtime.computeLayout(self, @floatFromInt(r.width), @floatFromInt(r.height));
        if (app_terminal_close_confirm_active_runtime.reconcile(self)) {
            if (try app_terminal_close_confirm_input.handleInput(
                self.input_router.actionsSlice(),
                input_batch,
                live_layout,
                self.shell.uiScaleFactor(),
                now,
                @ptrCast(self),
                struct {
                    fn call(raw: *anyopaque, decision: app_modes.ide.TerminalCloseConfirmDecision, at: f64) !bool {
                        const state: *AppState = @ptrCast(@alignCast(raw));
                        return try app_terminal_close_confirm_decision_runtime.applyDecision(
                            state,
                            decision,
                            at,
                            raw,
                            .{
                                .route_close_intent_and_sync = struct {
                                    fn inner(inner_raw: *anyopaque) !void {
                                        const inner_state: *AppState = @ptrCast(@alignCast(inner_raw));
                                        _ = try app_terminal_runtime_intents.routeForActiveWorkspaceTabAndSync(
                                            .close,
                                            &inner_state.terminal_workspace,
                                            @ptrCast(inner_state),
                                            routeTerminalTabActionFromCtx,
                                        );
                                    }
                                }.inner,
                                .close_active_terminal_tab = struct {
                                    fn inner(inner_raw: *anyopaque) !bool {
                                        const inner_state: *AppState = @ptrCast(@alignCast(inner_raw));
                                        return try app_terminal_close_active_runtime.closeActive(
                                            inner_state,
                                            @ptrCast(inner_state),
                                            .{
                                                .sync_terminal_mode_tab_bar = struct {
                                                    fn call(cb_raw: *anyopaque) !void {
                                                        const cb_state: *AppState = @ptrCast(@alignCast(cb_raw));
                                                        if (!app_modes.ide.shouldUseTerminalWorkspace(cb_state.app_mode)) return;
                                                        try app_terminal_tab_bar_sync.syncFromWorkspace(&cb_state.tab_bar, &cb_state.terminal_workspace);
                                                        try cb_state.syncModeAdaptersFromTabBar();
                                                    }
                                                }.call,
                                            },
                                        );
                                    }
                                }.inner,
                                .note_input = struct {
                                    fn inner(inner_raw: *anyopaque, inner_at: f64) void {
                                        const inner_state: *AppState = @ptrCast(@alignCast(inner_raw));
                                        inner_state.metrics.noteInput(inner_at);
                                    }
                                }.inner,
                            },
                        );
                    }
                }.call,
            )) {
                return .{
                    .suppress_terminal_shortcuts = false,
                    .terminal_close_modal_active = app_terminal_close_confirm_active_runtime.reconcile(self),
                    .handled_shortcut = handled_shortcut,
                    .consumed = true,
                };
            }
        }

        const terminal_close_modal_active = app_terminal_close_confirm_active_runtime.reconcile(self);
        const suppress_terminal_shortcuts = app_terminal_shortcut_suppress.forFocus(focus, self.input_router.actionsSlice());

        if (!terminal_close_modal_active and focus == .terminal and app_terminal_surface_gate.hasTerminalInputScopeWithTabs(self.app_mode, self.show_terminal, self.terminal_workspace, self.terminals.items.len)) {
            const clipboard_result = try app_terminal_clipboard_shortcuts_frame.handle(
                self.input_router.actionsSlice(),
                self.allocator,
                self.app_mode,
                &self.terminal_workspace,
                self.terminals.items,
                self.terminal_widgets.items,
                shell,
                input_batch.events.items.len,
                now,
            );
            if (clipboard_result.needs_redraw) self.needs_redraw = true;
            if (clipboard_result.handled) {
                handled_shortcut = true;
            }
        }

        if (focus == .editor) {
            const action_layout = app_ui_layout_runtime.computeLayout(self, @floatFromInt(r.width), @floatFromInt(r.height));
            if (self.editors.items.len > 0) {
                const editor_idx = @min(self.active_tab, self.editors.items.len - 1);
                const editor = self.editors.items[editor_idx];
                const editor_shortcut_result = try app_editor_shortcuts_frame.handle(
                    self.input_router.actionsSlice(),
                    self.allocator,
                    shell,
                    action_layout,
                    editor,
                    &self.editor_cluster_cache,
                    self.editor_wrap,
                    self.editor_large_jump_rows,
                    &self.search_panel.active,
                    &self.search_panel.query,
                );
                if (editor_shortcut_result.needs_redraw) self.needs_redraw = true;
                if (editor_shortcut_result.handled) {
                    handled_shortcut = true;
                }
            }
        }

        return .{
            .suppress_terminal_shortcuts = suppress_terminal_shortcuts,
            .terminal_close_modal_active = terminal_close_modal_active,
            .handled_shortcut = handled_shortcut,
            .consumed = false,
        };
    }

    fn handleFontSampleFrame(
        self: *AppState,
        r: anytype,
        input_batch: *shared_types.input.InputBatch,
    ) bool {
        if (!app_modes.ide.isFontSample(self.app_mode)) return false;
        if (self.font_sample_auto_close_frames > 0 and self.frame_id >= self.font_sample_auto_close_frames) {
            self.font_sample_close_pending = true;
            self.needs_redraw = true;
            return true;
        }
        if (self.font_sample_view) |*view| {
            if (view.update(r, input_batch)) {
                self.needs_redraw = true;
            }
        }
        return false;
    }

    fn handleWidgetInputFrame(self: *AppState) !void {
        self.options_bar.updateInput(self.last_input);
        self.tab_bar.updateInput(self.last_input);
        self.side_nav.updateInput(self.last_input);
        self.status_bar.updateInput(self.last_input);
        if (app_modes.ide.shouldUseTerminalWorkspace(self.app_mode)) {
            try app_terminal_tab_bar_sync.syncFromWorkspace(&self.tab_bar, &self.terminal_workspace);
            try self.syncModeAdaptersFromTabBar();
        }
    }

    fn tickConfigReloadNoticeFrame(self: *AppState, now: f64) void {
        const still_visible = app_config_reload_notice_state.isVisible(self.config_reload_notice_until, now);
        if (still_visible) {
            self.needs_redraw = true;
        } else {
            if (app_config_reload_notice_state.clearIfExpired(&self.config_reload_notice_until, now)) {
                self.needs_redraw = true;
            }
        }
    }

    fn routeInputForCurrentFocus(
        self: *AppState,
        input_batch: *shared_types.input.InputBatch,
    ) input_actions.FocusKind {
        _ = app_terminal_close_confirm_active_runtime.reconcile(self);
        const routed_active = app_modes.ide.routedActiveMode(self.app_mode, self.active_kind);
        const focus = if (routed_active == .terminal) input_actions.FocusKind.terminal else input_actions.FocusKind.editor;
        self.input_router.route(input_batch, focus);
        return focus;
    }

    fn handleTabDragFrame(
        self: *AppState,
        input_batch: *shared_types.input.InputBatch,
        layout: layout_types.WidgetLayout,
        mouse: shared_types.input.MousePos,
        now: f64,
    ) !void {
        try app_tab_drag_frame.handle(
            self.app_mode,
            input_batch,
            layout,
            mouse,
            now,
            @ptrCast(self),
            .{
                .handle_terminal_tab_drag_input = struct {
                    fn call(
                        raw: *anyopaque,
                        frame_input_batch: *shared_types.input.InputBatch,
                        frame_layout: layout_types.WidgetLayout,
                        frame_mouse: shared_types.input.MousePos,
                        frame_now: f64,
                    ) !void {
                        const state: *AppState = @ptrCast(@alignCast(raw));
                        try state.handleTerminalTabDragInput(frame_input_batch, frame_layout, frame_mouse, frame_now);
                    }
                }.call,
                .handle_ide_tab_drag_input = struct {
                    fn call(
                        raw: *anyopaque,
                        frame_input_batch: *shared_types.input.InputBatch,
                        frame_layout: layout_types.WidgetLayout,
                        frame_mouse: shared_types.input.MousePos,
                        frame_now: f64,
                    ) !void {
                        const state: *AppState = @ptrCast(@alignCast(raw));
                        try state.handleIdeTabDragInput(frame_input_batch, frame_layout, frame_mouse, frame_now);
                    }
                }.call,
            },
        );
    }

    fn handleInputActionsFrame(
        self: *AppState,
        shell: *Shell,
        now: f64,
    ) !bool {
        _ = shell;
        return try app_input_actions_frame_runtime.handle(
            self.input_router.actionsSlice(),
            now,
            @ptrCast(self),
            .{
                .handle_shortcut_action = struct {
                    fn call(raw: *anyopaque, kind: input_actions.ActionKind, at: f64, handled_zoom: *bool) !bool {
                        const state: *AppState = @ptrCast(@alignCast(raw));
                        const zoom_log = app_logger.logger("ui.zoom.shortcut");
                        return try state.handleShortcutAction(state.shell, kind, at, handled_zoom, zoom_log);
                    }
                }.call,
            },
        );
    }

    fn handlePointerActivityFrame(
        self: *AppState,
        input_batch: *shared_types.input.InputBatch,
        layout: layout_types.WidgetLayout,
        mouse: shared_types.input.MousePos,
        now: f64,
    ) void {
        const result = app_pointer_activity_frame.handle(
            self.show_terminal,
            input_batch,
            layout,
            mouse,
            now,
            &self.last_mouse_pos,
            &self.last_mouse_redraw_time,
            &self.last_ctrl_down,
        );
        if (result.needs_redraw) self.needs_redraw = true;
        if (result.note_input) self.metrics.noteInput(now);
    }

    fn handleTerminalSplitResizeFrame(
        self: *AppState,
        shell: *Shell,
        input_batch: *shared_types.input.InputBatch,
        layout: layout_types.WidgetLayout,
        width: f32,
        height: f32,
        now: f64,
    ) !void {
        const result = app_terminal_split_resize_frame.handle(
            self.app_mode,
            self.show_terminal,
            input_batch,
            layout,
            height,
            self.options_bar.height,
            self.tab_bar.height,
            self.status_bar.height,
            &self.resizing_terminal,
            &self.resize_start_y,
            &self.resize_start_height,
            self.terminal_height,
        );

        if (result.new_terminal_height) |new_height| {
            self.terminal_height = new_height;
            if (self.terminals.items.len > 0) {
                const term = self.terminals.items[0];
                const grid = app_terminal_grid.compute(
                    width,
                    self.terminal_height,
                    self.shell.terminalCellWidth(),
                    self.shell.terminalCellHeight(),
                    1,
                    1,
                );
                const cols: u16 = grid.cols;
                const rows: u16 = grid.rows;
                term.setCellSize(
                    @intFromFloat(shell.terminalCellWidth()),
                    @intFromFloat(shell.terminalCellHeight()),
                );
                try term.resize(rows, cols);
            }
        }
        if (result.needs_redraw) self.needs_redraw = true;
        if (result.note_input) self.metrics.noteInput(now);
    }

    fn handleWindowResizeEventFrame(self: *AppState, shell: *Shell, now: f64) !void {
        _ = now;
        const result = try app_window_resize_event_frame.handle(
            shell,
            &self.window_resize_pending,
            &self.window_resize_last_time,
        );
        if (result.ui_scale_changed) {
            app_ui_layout_runtime.applyUiScale(
                self,
                self.shell.uiScaleFactor(),
                @ptrCast(self),
                .{
                    .apply_current_tab_bar_width_mode = struct {
                        fn call(raw: *anyopaque) void {
                            const cb_state: *AppState = @ptrCast(@alignCast(raw));
                            cb_state.applyCurrentTabBarWidthMode();
                        }
                    }.call,
                },
            );
        }
        if (result.needs_redraw) self.needs_redraw = true;
    }

    fn handleCursorBlinkArmingFrame(self: *AppState, now: f64) void {
        var cache: ?app_cursor_blink_frame.Input = null;
        if (app_terminal_active_widget.resolveActive(
            self.app_mode,
            &self.terminal_workspace,
            self.terminals.items.len,
            self.terminal_widgets.items,
        )) |term_widget| {
            const rc = term_widget.session.renderCache();
            cache = app_cursor_blink_frame.Input{
                .cursor_visible = rc.cursor_visible,
                .cursor_blink = rc.cursor_style.blink,
                .scroll_offset = rc.scroll_offset,
            };
        }

        const result = app_cursor_blink_frame.handle(
            cache,
            now,
            &self.last_cursor_blink_armed,
            &self.last_cursor_blink_on,
        );

        if (result.blink_armed_changed) {
            const cursor_log = app_logger.logger("terminal.cursor");
            if (cursor_log.enabled_file or cursor_log.enabled_console) {
                cursor_log.logf(
                    "cursor blink armed={any} visible={any} blink={any} scroll_offset={d}",
                    .{
                        result.blink_armed,
                        cache.?.cursor_visible,
                        cache.?.cursor_blink,
                        cache.?.scroll_offset,
                    },
                );
            }
        }
        if (result.needs_redraw) self.needs_redraw = true;
    }

    fn handleDeferredTerminalResizeFrame(
        self: *AppState,
        shell: *Shell,
        layout: layout_types.WidgetLayout,
        now: f64,
    ) !void {
        const result = app_deferred_terminal_resize_frame.handle(
            &self.window_resize_pending,
            self.window_resize_last_time,
            now,
            self.app_mode,
            self.show_terminal,
            layout,
            self.terminal_height,
            app_terminal_tabs_runtime.count(self.app_mode, self.terminal_workspace, self.terminals.items.len),
            shell.terminalCellWidth(),
            shell.terminalCellHeight(),
        );
        if (!result.triggered) return;

        if (result.should_resize_terminals) {
            if (app_modes.ide.shouldUseTerminalWorkspace(self.app_mode)) {
                if (self.terminal_workspace) |*workspace| {
                    try app_terminal_resize.resizeWorkspaceWithShellCellSize(workspace, shell, result.rows, result.cols);
                }
            } else {
                const term = self.terminals.items[0];
                try app_terminal_resize.resizeSessionWithShellCellSize(term, shell, result.rows, result.cols);
            }
        }
        if (result.needs_redraw) self.needs_redraw = true;
    }


    pub fn newTerminal(self: *AppState) !void {
        // Calculate terminal size based on UI
        const shell = self.shell;
        const width = @as(f32, @floatFromInt(shell.width()));
        const height = @as(f32, @floatFromInt(shell.height()));
        const layout = app_ui_layout_runtime.computeLayout(self, width, height);
        if (app_modes.ide.shouldUseTerminalWorkspace(self.app_mode)) {
            self.active_kind = .terminal;
        } else if (app_modes.ide.isEditorOnly(self.app_mode)) {
            self.active_kind = .editor;
        }
        const initial_grid = app_terminal_grid.compute(
            layout.terminal.width,
            layout.terminal.height,
            shell.terminalCellWidth(),
            shell.terminalCellHeight(),
            80,
            24,
        );
        const cols: u16 = initial_grid.cols;
        const rows: u16 = initial_grid.rows;
        const theme = &self.terminal_theme;

        if (app_modes.ide.shouldUseTerminalWorkspace(self.app_mode)) {
            if (self.terminal_workspace) |*workspace| {
                _ = try workspace.createTab(rows, cols);
                const term = workspace.activeSession() orelse return error.TerminalWorkspaceNoActiveTab;
                app_terminal_theme_apply.setSessionPalette(term, theme);
                try app_terminal_session_bootstrap.startSessionWithShellCellSize(term, shell);
                const widget = app_terminal_session_bootstrap.initWidget(
                    term,
                    self.terminal_blink_style,
                    self.terminal_focus_report_window_events,
                    self.terminal_focus_report_pane_events,
                );
                try self.terminal_widgets.append(self.allocator, widget);
                if (app_modes.ide.shouldUseTerminalWorkspace(self.app_mode)) {
                    try app_terminal_tab_bar_sync.syncFromWorkspace(&self.tab_bar, &self.terminal_workspace);
                    try self.syncModeAdaptersFromTabBar();
                }
                try app_terminal_theme_apply.notifyColorSchemeChanged(&self.terminal_widgets, &self.terminal_theme);
                self.show_terminal = true;
                return;
            }
            return error.TerminalWorkspaceMissing;
        }

        const term = try TerminalSession.initWithOptions(self.allocator, rows, cols, .{
            .scrollback_rows = self.terminal_scrollback_rows,
            .cursor_style = self.terminal_cursor_style,
        });
        app_terminal_theme_apply.setSessionPalette(term, theme);
        try app_terminal_session_bootstrap.startSessionWithShellCellSize(term, shell);
        try self.terminals.append(self.allocator, term);
        const widget = app_terminal_session_bootstrap.initWidget(
            term,
            self.terminal_blink_style,
            self.terminal_focus_report_window_events,
            self.terminal_focus_report_pane_events,
        );
        try self.terminal_widgets.append(self.allocator, widget);
        try app_terminal_theme_apply.notifyColorSchemeChanged(&self.terminal_widgets, &self.terminal_theme);

        self.show_terminal = true;
    }

    pub fn run(self: *AppState) !void {
        try app_run_entry_runtime.run(
            @ptrCast(self),
            .{
                .initialize_run_mode_state = struct {
                    fn call(raw: *anyopaque) !void {
                        const state: *AppState = @ptrCast(@alignCast(raw));
                        try app_run_mode_init.initialize(
                            state.app_mode,
                            state.perf_mode,
                            state.perf_file_path,
                            raw,
                            .{
                                .terminal_tab_count = struct {
                                    fn cb(cb_raw: *anyopaque) usize {
                                        const cb_state: *AppState = @ptrCast(@alignCast(cb_raw));
                                        return app_terminal_tabs_runtime.count(cb_state.app_mode, cb_state.terminal_workspace, cb_state.terminals.items.len);
                                    }
                                }.cb,
                                .new_terminal = struct {
                                    fn cb(cb_raw: *anyopaque) !void {
                                        const cb_state: *AppState = @ptrCast(@alignCast(cb_raw));
                                        try cb_state.newTerminal();
                                    }
                                }.cb,
                                .sync_terminal_mode_tab_bar = struct {
                                    fn cb(cb_raw: *anyopaque) !void {
                                        const cb_state: *AppState = @ptrCast(@alignCast(cb_raw));
                                        if (!app_modes.ide.shouldUseTerminalWorkspace(cb_state.app_mode)) return;
                                        try app_terminal_tab_bar_sync.syncFromWorkspace(&cb_state.tab_bar, &cb_state.terminal_workspace);
                                        try cb_state.syncModeAdaptersFromTabBar();
                                    }
                                }.cb,
                                .open_file = struct {
                                    fn cb(cb_raw: *anyopaque, path: []const u8) !void {
                                        const cb_state: *AppState = @ptrCast(@alignCast(cb_raw));
                                        try cb_state.openFile(path);
                                    }
                                }.cb,
                                .new_editor = struct {
                                    fn cb(cb_raw: *anyopaque) !void {
                                        const cb_state: *AppState = @ptrCast(@alignCast(cb_raw));
                                        try cb_state.newEditor();
                                    }
                                }.cb,
                                .seed_default_welcome_buffer = struct {
                                    fn cb(cb_raw: *anyopaque) !void {
                                        const cb_state: *AppState = @ptrCast(@alignCast(cb_raw));
                                        if (cb_state.editors.items.len > 0) {
                                            const editor = cb_state.editors.items[0];
                                            try app_editor_seed.seedDefaultWelcomeBuffer(editor);
                                        }
                                    }
                                }.cb,
                            },
                        );
                    }
                }.call,
                .run_main_loop = struct {
                    fn call(raw: *anyopaque) !void {
                        const run_state: *AppState = @ptrCast(@alignCast(raw));
                        try app_run_loop_driver.runMainLoop(
                            run_state.shell,
                            raw,
                            .{
                                .run_one_frame = struct {
                                    fn inner(one_frame_raw: *anyopaque) !bool {
                                        return try app_run_loop_driver.runOneFrame(
                                            one_frame_raw,
                                            .{
                                                .prepare_run_frame = struct {
                                                    fn step(step_raw: *anyopaque) !?app_run_loop_driver.FrameSetup {
                                                        const step_state: *AppState = @ptrCast(@alignCast(step_raw));
                                                        return try app_prepare_run_frame_runtime.prepare(step_state);
                                                    }
                                                }.step,
                                                .update = struct {
                                                    fn step(step_raw: *anyopaque, input_batch: *shared_types.input.InputBatch) !void {
                                                        const step_state: *AppState = @ptrCast(@alignCast(step_raw));
                                                        try app_update_driver.handle(
                                                            step_state.shell,
                                                            input_batch,
                                                            step_raw,
                                                            .{
                                                                .handle_update_prelude_frame = struct {
                                                                    fn cb(cb_raw: *anyopaque, shell: *Shell, batch: *shared_types.input.InputBatch) !?app_update_driver.Prelude {
                                                                        const pre = (try app_update_prelude_frame_runtime.handle(
                                                                            shell,
                                                                            batch,
                                                                            cb_raw,
                                                                            .{
                                                                                .handle_font_sample_frame = struct {
                                                                                    fn inner(inner_raw: *anyopaque, frame_shell: *Shell, frame_input_batch: *shared_types.input.InputBatch) bool {
                                                                                        const inner_state: *AppState = @ptrCast(@alignCast(inner_raw));
                                                                                        return inner_state.handleFontSampleFrame(frame_shell.rendererPtr(), frame_input_batch);
                                                                                    }
                                                                                }.inner,
                                                                                .handle_widget_input_frame = struct {
                                                                                    fn inner(inner_raw: *anyopaque) !void {
                                                                                        const inner_state: *AppState = @ptrCast(@alignCast(inner_raw));
                                                                                        try inner_state.handleWidgetInputFrame();
                                                                                    }
                                                                                }.inner,
                                                                                .tick_config_reload_notice_frame = struct {
                                                                                    fn inner(inner_raw: *anyopaque, at: f64) void {
                                                                                        const inner_state: *AppState = @ptrCast(@alignCast(inner_raw));
                                                                                        inner_state.tickConfigReloadNoticeFrame(at);
                                                                                    }
                                                                                }.inner,
                                                                                .route_input_for_current_focus = struct {
                                                                                    fn inner(inner_raw: *anyopaque, frame_input_batch: *shared_types.input.InputBatch) input_actions.FocusKind {
                                                                                        const inner_state: *AppState = @ptrCast(@alignCast(inner_raw));
                                                                                        return inner_state.routeInputForCurrentFocus(frame_input_batch);
                                                                                    }
                                                                                }.inner,
                                                                                .handle_pre_input_shortcut_frame = struct {
                                                                                    fn inner(
                                                                                        inner_raw: *anyopaque,
                                                                                        frame_shell: *Shell,
                                                                                        frame_input_batch: *shared_types.input.InputBatch,
                                                                                        focus: input_actions.FocusKind,
                                                                                        at: f64,
                                                                                    ) !app_update_prelude_frame_runtime.PreInputResult {
                                                                                        const inner_state: *AppState = @ptrCast(@alignCast(inner_raw));
                                                                                        const pre_input = try inner_state.handlePreInputShortcutFrame(frame_shell, frame_shell.rendererPtr(), frame_input_batch, focus, at);
                                                                                        return .{
                                                                                            .suppress_terminal_shortcuts = pre_input.suppress_terminal_shortcuts,
                                                                                            .terminal_close_modal_active = pre_input.terminal_close_modal_active,
                                                                                            .handled_shortcut = pre_input.handled_shortcut,
                                                                                            .consumed = pre_input.consumed,
                                                                                        };
                                                                                    }
                                                                                }.inner,
                                                                                .note_input = struct {
                                                                                    fn inner(inner_raw: *anyopaque, at: f64) void {
                                                                                        const inner_state: *AppState = @ptrCast(@alignCast(inner_raw));
                                                                                        inner_state.metrics.noteInput(at);
                                                                                    }
                                                                                }.inner,
                                                                                .set_last_input_snapshot = struct {
                                                                                    fn inner(inner_raw: *anyopaque, snapshot: shared_types.input.InputSnapshot) void {
                                                                                        const inner_state: *AppState = @ptrCast(@alignCast(inner_raw));
                                                                                        inner_state.last_input = snapshot;
                                                                                    }
                                                                                }.inner,
                                                                            },
                                                                        )) orelse return null;
                                                                        return .{
                                                                            .now = pre.now,
                                                                            .suppress_terminal_shortcuts = pre.suppress_terminal_shortcuts,
                                                                            .terminal_close_modal_active = pre.terminal_close_modal_active,
                                                                        };
                                                                    }
                                                                }.cb,
                                                                .handle_post_preinput_frame = struct {
                                                                    fn cb(cb_raw: *anyopaque, shell: *Shell, batch: *shared_types.input.InputBatch, now: f64) !app_update_driver.Frame {
                                                                        const state: *AppState = @ptrCast(@alignCast(cb_raw));
                                                                        const frame = try app_post_preinput_frame.handle(
                                                                            shell,
                                                                            batch,
                                                                            now,
                                                                            cb_raw,
                                                                            .{
                                                                                .apply_ui_scale = struct {
                                                                                    fn inner(inner_raw: *anyopaque) void {
                                                                                        const inner_state: *AppState = @ptrCast(@alignCast(inner_raw));
                                                                                        app_ui_layout_runtime.applyUiScale(
                                                                                            inner_state,
                                                                                            inner_state.shell.uiScaleFactor(),
                                                                                            @ptrCast(inner_state),
                                                                                            .{
                                                                                                .apply_current_tab_bar_width_mode = struct {
                                                                                                    fn call(scale_raw: *anyopaque) void {
                                                                                                        const cb_state: *AppState = @ptrCast(@alignCast(scale_raw));
                                                                                                        cb_state.applyCurrentTabBarWidthMode();
                                                                                                    }
                                                                                                }.call,
                                                                                            },
                                                                                        );
                                                                                    }
                                                                                }.inner,
                                                                                .refresh_terminal_sizing = struct {
                                                                                    fn inner(inner_raw: *anyopaque) !void {
                                                                                        const inner_state: *AppState = @ptrCast(@alignCast(inner_raw));
                                                                                        try app_terminal_refresh_sizing_runtime.handle(
                                                                                            inner_state,
                                                                                            inner_state.app_mode,
                                                                                            &inner_state.terminal_workspace,
                                                                                            inner_state.terminals.items,
                                                                                            inner_state.show_terminal,
                                                                                            inner_state.terminal_height,
                                                                                            inner_state.shell,
                                                                                        );
                                                                                    }
                                                                                }.inner,
                                                                                .handle_window_resize_event = struct {
                                                                                    fn inner(inner_raw: *anyopaque, frame_shell: *Shell, at: f64) !void {
                                                                                        const inner_state: *AppState = @ptrCast(@alignCast(inner_raw));
                                                                                        try inner_state.handleWindowResizeEventFrame(frame_shell, at);
                                                                                    }
                                                                                }.inner,
                                                                                .compute_layout = struct {
                                                                                    fn inner(inner_raw: *anyopaque, width: f32, height: f32) layout_types.WidgetLayout {
                                                                                        const inner_state: *AppState = @ptrCast(@alignCast(inner_raw));
                                                                                        return app_ui_layout_runtime.computeLayout(inner_state, width, height);
                                                                                    }
                                                                                }.inner,
                                                                                .handle_cursor_blink_arming = struct {
                                                                                    fn inner(inner_raw: *anyopaque, at: f64) void {
                                                                                        const inner_state: *AppState = @ptrCast(@alignCast(inner_raw));
                                                                                        inner_state.handleCursorBlinkArmingFrame(at);
                                                                                    }
                                                                                }.inner,
                                                                                .handle_deferred_terminal_resize = struct {
                                                                                    fn inner(inner_raw: *anyopaque, frame_shell: *Shell, layout: layout_types.WidgetLayout, at: f64) !void {
                                                                                        const inner_state: *AppState = @ptrCast(@alignCast(inner_raw));
                                                                                        try inner_state.handleDeferredTerminalResizeFrame(frame_shell, layout, at);
                                                                                    }
                                                                                }.inner,
                                                                                .handle_pointer_activity = struct {
                                                                                    fn inner(
                                                                                        inner_raw: *anyopaque,
                                                                                        frame_input_batch: *shared_types.input.InputBatch,
                                                                                        layout: layout_types.WidgetLayout,
                                                                                        mouse: shared_types.input.MousePos,
                                                                                        at: f64,
                                                                                    ) void {
                                                                                        const inner_state: *AppState = @ptrCast(@alignCast(inner_raw));
                                                                                        inner_state.handlePointerActivityFrame(frame_input_batch, layout, mouse, at);
                                                                                    }
                                                                                }.inner,
                                                                                .handle_terminal_split_resize = struct {
                                                                                    fn inner(
                                                                                        inner_raw: *anyopaque,
                                                                                        frame_shell: *Shell,
                                                                                        frame_input_batch: *shared_types.input.InputBatch,
                                                                                        layout: layout_types.WidgetLayout,
                                                                                        width: f32,
                                                                                        height: f32,
                                                                                        at: f64,
                                                                                    ) !void {
                                                                                        const inner_state: *AppState = @ptrCast(@alignCast(inner_raw));
                                                                                        try inner_state.handleTerminalSplitResizeFrame(frame_shell, frame_input_batch, layout, width, height, at);
                                                                                    }
                                                                                }.inner,
                                                                            },
                                                                        );
                                                                        if (frame.needs_redraw) state.needs_redraw = true;
                                                                        if (frame.note_input) state.metrics.noteInput(now);
                                                                        return .{
                                                                            .layout = frame.layout,
                                                                            .mouse = frame.mouse,
                                                                            .term_y = frame.term_y,
                                                                        };
                                                                    }
                                                                }.cb,
                                                                .handle_interactive_frame = struct {
                                                                    fn cb(
                                                                        cb_raw: *anyopaque,
                                                                        shell: *Shell,
                                                                        frame: app_update_driver.Frame,
                                                                        batch: *shared_types.input.InputBatch,
                                                                        suppress_terminal_shortcuts: bool,
                                                                        terminal_close_modal_active: bool,
                                                                        now: f64,
                                                                    ) !void {
                                                                        try app_interactive_frame.handle(
                                                                            shell,
                                                                            .{
                                                                                .layout = frame.layout,
                                                                                .mouse = frame.mouse,
                                                                                .term_y = frame.term_y,
                                                                            },
                                                                            batch,
                                                                            suppress_terminal_shortcuts,
                                                                            terminal_close_modal_active,
                                                                            now,
                                                                            cb_raw,
                                                                            .{
                                                                                .handle_input_actions = struct {
                                                                                    fn inner(inner_raw: *anyopaque, frame_shell: *Shell, at: f64) !bool {
                                                                                        const inner_state: *AppState = @ptrCast(@alignCast(inner_raw));
                                                                                        return try inner_state.handleInputActionsFrame(frame_shell, at);
                                                                                    }
                                                                                }.inner,
                                                                                .handle_mouse_pressed = struct {
                                                                                    fn inner(
                                                                                        inner_raw: *anyopaque,
                                                                                        frame_shell: *Shell,
                                                                                        layout: layout_types.WidgetLayout,
                                                                                        mouse: shared_types.input.MousePos,
                                                                                        term_y: f32,
                                                                                        frame_input_batch: *shared_types.input.InputBatch,
                                                                                        at: f64,
                                                                                    ) !void {
                                                                                        const inner_state: *AppState = @ptrCast(@alignCast(inner_raw));
                                                                                        try inner_state.handleMousePressedFrame(frame_shell, layout, mouse, term_y, frame_input_batch, at);
                                                                                    }
                                                                                }.inner,
                                                                                .handle_tab_drag = struct {
                                                                                    fn inner(
                                                                                        inner_raw: *anyopaque,
                                                                                        frame_input_batch: *shared_types.input.InputBatch,
                                                                                        layout: layout_types.WidgetLayout,
                                                                                        mouse: shared_types.input.MousePos,
                                                                                        at: f64,
                                                                                    ) !void {
                                                                                        const inner_state: *AppState = @ptrCast(@alignCast(inner_raw));
                                                                                        try inner_state.handleTabDragFrame(frame_input_batch, layout, mouse, at);
                                                                                    }
                                                                                }.inner,
                                                                                .handle_active_view = struct {
                                                                                    fn inner(
                                                                                        inner_raw: *anyopaque,
                                                                                        frame_shell: *Shell,
                                                                                        layout: layout_types.WidgetLayout,
                                                                                        mouse: shared_types.input.MousePos,
                                                                                        frame_input_batch: *shared_types.input.InputBatch,
                                                                                        frame_suppress_terminal_shortcuts: bool,
                                                                                        frame_terminal_close_modal_active: bool,
                                                                                        at: f64,
                                                                                    ) !void {
                                                                                        const inner_state: *AppState = @ptrCast(@alignCast(inner_raw));
                                                                                        try inner_state.handleActiveViewFrame(
                                                                                            frame_shell,
                                                                                            layout,
                                                                                            mouse,
                                                                                            frame_input_batch,
                                                                                            frame_suppress_terminal_shortcuts,
                                                                                            frame_terminal_close_modal_active,
                                                                                            at,
                                                                                        );
                                                                                    }
                                                                                }.inner,
                                                                            },
                                                                        );
                                                                    }
                                                                }.cb,
                                                            },
                                                        );
                                                    }
                                                }.step,
                                                .handle_frame_render_and_idle = struct {
                                                    fn step(step_raw: *anyopaque, input_batch: *shared_types.input.InputBatch, poll_ms: f64, build_ms: f64, update_ms: f64) void {
                                                        const step_state: *AppState = @ptrCast(@alignCast(step_raw));
                                                        app_frame_render_idle_runtime.handle(
                                                            step_state,
                                                            @ptrCast(step_state),
                                                            input_batch,
                                                            poll_ms,
                                                            build_ms,
                                                            update_ms,
                                                            .{
                                                                .draw = struct {
                                                                    fn cb(cb_raw: *anyopaque) void {
                                                                        const cb_state: *AppState = @ptrCast(@alignCast(cb_raw));
                                                                        app_draw_frame_runtime.draw(
                                                                            cb_state,
                                                                            cb_state.shell,
                                                                            cb_raw,
                                                                            .{
                                                                                .compute_layout = struct {
                                                                                    fn inner(inner_raw: *anyopaque, width: f32, height: f32) layout_types.WidgetLayout {
                                                                                        const inner_state: *AppState = @ptrCast(@alignCast(inner_raw));
                                                                                        return app_ui_layout_runtime.computeLayout(inner_state, width, height);
                                                                                    }
                                                                                }.inner,
                                                                                .apply_current_tab_bar_width_mode = struct {
                                                                                    fn inner(inner_raw: *anyopaque) void {
                                                                                        const inner_state: *AppState = @ptrCast(@alignCast(inner_raw));
                                                                                        inner_state.applyCurrentTabBarWidthMode();
                                                                                    }
                                                                                }.inner,
                                                                                .terminal_close_confirm_active = struct {
                                                                                    fn inner(inner_raw: *anyopaque) bool {
                                                                                        const inner_state: *AppState = @ptrCast(@alignCast(inner_raw));
                                                                                        return app_terminal_close_confirm_active_runtime.reconcile(inner_state);
                                                                                    }
                                                                                }.inner,
                                                                            },
                                                                        );
                                                                    }
                                                                }.cb,
                                                                .maybe_log_metrics = struct {
                                                                    fn cb(cb_raw: *anyopaque, at: f64) void {
                                                                        const cb_state: *AppState = @ptrCast(@alignCast(cb_raw));
                                                                        app_metrics_log_runtime.maybeLog(cb_state, at);
                                                                    }
                                                                }.cb,
                                                            },
                                                        );
                                                    }
                                                }.step,
                                                .should_stop_for_perf = struct {
                                                    fn step(step_raw: *anyopaque) bool {
                                                        const step_state: *AppState = @ptrCast(@alignCast(step_raw));
                                                        return step_state.perf_mode and step_state.perf_frames_done >= step_state.perf_frames_total and step_state.perf_frames_total > 0;
                                                    }
                                                }.step,
                                                .on_perf_complete = struct {
                                                    fn step(step_raw: *anyopaque) void {
                                                        const step_state: *AppState = @ptrCast(@alignCast(step_raw));
                                                        step_state.perf_logger.logf("perf complete frames={d}", .{step_state.perf_frames_done});
                                                    }
                                                }.step,
                                            },
                                        );
                                    }
                                }.inner,
                            },
                        );
                    }
                }.call,
            },
        );
    }

};

pub fn runWithMode(allocator: std.mem.Allocator, app_mode: AppMode) !void {
    var app = try AppState.init(allocator, app_mode);
    defer app.deinit();

    try app.run();
}

pub fn runFromArgs(allocator: std.mem.Allocator) !void {
    const app_mode = app_bootstrap.parseAppMode(allocator);
    try runWithMode(allocator, app_mode);
}

pub fn main() !void {
    try app_runner.runWithGpa(struct {
        fn call(allocator: std.mem.Allocator) !void {
            app_signals.install();
            try runFromArgs(allocator);
        }
    }.call);
}


// Tests
test "buffer basic operations" {
    const allocator = std.testing.allocator;

    const store = try text_store.TextStore.init(allocator, "Hello, World!");
    defer store.deinit();

    try std.testing.expectEqual(@as(usize, 13), store.totalLen());

    // Test insert
    try store.insertBytes(7, "Zig ");
    try std.testing.expectEqual(@as(usize, 17), store.totalLen());

    // Test read
    var out: [32]u8 = undefined;
    const len = store.readRange(0, &out);
    try std.testing.expectEqualStrings("Hello, Zig World!", out[0..len]);
}

test "editor cursor movement" {
    const allocator = std.testing.allocator;

    var grammar_manager = try grammar_manager_mod.GrammarManager.init(allocator);
    defer grammar_manager.deinit();

    const editor = try Editor.init(allocator, &grammar_manager);
    defer editor.deinit();

    try editor.insertText("Line 1\nLine 2\nLine 3");

    // Reset cursor
    editor.cursor = .{ .line = 0, .col = 0, .offset = 0 };

    // Move down
    editor.moveCursorDown();
    try std.testing.expectEqual(@as(usize, 1), editor.cursor.line);

    // Move to end
    editor.moveCursorToLineEnd();
    try std.testing.expectEqual(@as(usize, 6), editor.cursor.col);
}

test "theme utils dark classifier uses background luma" {
    var dark_theme = app_shell.Theme{};
    dark_theme.background = .{ .r = 20, .g = 22, .b = 26 };
    try std.testing.expect(app_theme_utils.isDarkTheme(&dark_theme));

    var light_theme = app_shell.Theme{};
    light_theme.background = .{ .r = 245, .g = 245, .b = 245 };
    try std.testing.expect(!app_theme_utils.isDarkTheme(&light_theme));
}

test "search panel command maps navigation keys" {
    const allocator = std.testing.allocator;
    var batch = shared_types.input.InputBatch.init(allocator);
    defer batch.deinit();

    batch.key_pressed[@intFromEnum(shared_types.input.Key.enter)] = true;
    try std.testing.expectEqual(app_search_panel_input.SearchPanelCommand.next, app_search_panel_input.searchPanelCommand(&batch));

    batch.clear();
    batch.key_pressed[@intFromEnum(shared_types.input.Key.f3)] = true;
    batch.mods.shift = true;
    try std.testing.expectEqual(app_search_panel_input.SearchPanelCommand.prev, app_search_panel_input.searchPanelCommand(&batch));

    batch.clear();
    batch.key_pressed[@intFromEnum(shared_types.input.Key.escape)] = true;
    try std.testing.expectEqual(app_search_panel_input.SearchPanelCommand.close, app_search_panel_input.searchPanelCommand(&batch));

    batch.clear();
    batch.key_repeated[@intFromEnum(shared_types.input.Key.backspace)] = true;
    try std.testing.expectEqual(app_search_panel_input.SearchPanelCommand.backspace, app_search_panel_input.searchPanelCommand(&batch));
}

test "search panel text helper appends utf8 input events" {
    const allocator = std.testing.allocator;
    var batch = shared_types.input.InputBatch.init(allocator);
    defer batch.deinit();

    var query = std.ArrayList(u8).empty;
    defer query.deinit(allocator);

    try batch.append(.{ .text = .{
        .codepoint = 'a',
        .utf8_len = 1,
        .utf8 = .{ 'a', 0, 0, 0 },
    } });
    try batch.append(.{ .text = .{
        .codepoint = 0x00E9,
        .utf8_len = 2,
        .utf8 = .{ 0xC3, 0xA9, 0, 0 },
    } });

    try std.testing.expect(try app_search_panel_input.appendSearchPanelTextEvents(allocator, &query, &batch));
    try std.testing.expectEqualStrings("a\xC3\xA9", query.items);
}

test "visual extend action helper maps routed editor actions" {
    try std.testing.expectEqual(@as(?i32, -1), app_editor_actions.visualExtendDeltaForAction(.editor_extend_up, 5));
    try std.testing.expectEqual(@as(?i32, 1), app_editor_actions.visualExtendDeltaForAction(.editor_extend_down, 5));
    try std.testing.expectEqual(@as(?i32, -5), app_editor_actions.visualExtendDeltaForAction(.editor_extend_large_up, 5));
    try std.testing.expectEqual(@as(?i32, 5), app_editor_actions.visualExtendDeltaForAction(.editor_extend_large_down, 5));
    try std.testing.expectEqual(@as(?i32, -9), app_editor_actions.visualExtendDeltaForAction(.editor_extend_large_up, 9));
    try std.testing.expectEqual(@as(?i32, null), app_editor_actions.visualExtendDeltaForAction(.editor_extend_right, 5));
}

test "visual move action helper maps routed editor actions" {
    try std.testing.expectEqual(@as(?i32, -5), app_editor_actions.visualMoveDeltaForAction(.editor_move_large_up, 5));
    try std.testing.expectEqual(@as(?i32, 5), app_editor_actions.visualMoveDeltaForAction(.editor_move_large_down, 5));
    try std.testing.expectEqual(@as(?i32, 12), app_editor_actions.visualMoveDeltaForAction(.editor_move_large_down, 12));
    try std.testing.expectEqual(@as(?i32, null), app_editor_actions.visualMoveDeltaForAction(.editor_move_word_right, 5));
}

test "applyRepeatedVisualDelta steps until blocked" {
    const Ctx = struct {
        steps: usize,
        limit: usize,
    };
    var ctx = Ctx{ .steps = 0, .limit = 3 };
    const moved = app_editor_actions.applyRepeatedVisualDelta(
        8,
        @ptrCast(&ctx),
        struct {
            fn step(raw: *anyopaque, dir: i32) bool {
                _ = dir;
                const payload: *Ctx = @ptrCast(@alignCast(raw));
                if (payload.steps >= payload.limit) return false;
                payload.steps += 1;
                return true;
            }
        }.step,
    );
    try std.testing.expect(moved);
    try std.testing.expectEqual(@as(usize, 3), ctx.steps);
}

test "routed large visual actions apply configured step sequence" {
    const Ctx = struct {
        dirs: [16]i32 = [_]i32{0} ** 16,
        len: usize = 0,
        fn push(self: *@This(), dir: i32) bool {
            if (self.len >= self.dirs.len) return false;
            self.dirs[self.len] = dir;
            self.len += 1;
            return true;
        }
    };

    var ctx = Ctx{};

    const down_delta = app_editor_actions.visualExtendDeltaForAction(.editor_extend_large_down, 4) orelse return error.TestUnexpectedResult;
    const moved_down = app_editor_actions.applyRepeatedVisualDelta(
        down_delta,
        @ptrCast(&ctx),
        struct {
            fn step(raw: *anyopaque, dir: i32) bool {
                const payload: *Ctx = @ptrCast(@alignCast(raw));
                return payload.push(dir);
            }
        }.step,
    );
    try std.testing.expect(moved_down);

    const up_delta = app_editor_actions.visualMoveDeltaForAction(.editor_move_large_up, 2) orelse return error.TestUnexpectedResult;
    const moved_up = app_editor_actions.applyRepeatedVisualDelta(
        up_delta,
        @ptrCast(&ctx),
        struct {
            fn step(raw: *anyopaque, dir: i32) bool {
                const payload: *Ctx = @ptrCast(@alignCast(raw));
                return payload.push(dir);
            }
        }.step,
    );
    try std.testing.expect(moved_up);

    try std.testing.expectEqual(@as(usize, 6), ctx.len);
    try std.testing.expectEqual(@as(i32, 1), ctx.dirs[0]);
    try std.testing.expectEqual(@as(i32, 1), ctx.dirs[1]);
    try std.testing.expectEqual(@as(i32, 1), ctx.dirs[2]);
    try std.testing.expectEqual(@as(i32, 1), ctx.dirs[3]);
    try std.testing.expectEqual(@as(i32, -1), ctx.dirs[4]);
    try std.testing.expectEqual(@as(i32, -1), ctx.dirs[5]);
}

test "direct editor action helper routes word and line selection actions" {
    const allocator = std.testing.allocator;

    var grammar_manager = try grammar_manager_mod.GrammarManager.init(allocator);
    defer grammar_manager.deinit();

    const editor = try Editor.init(allocator, &grammar_manager);
    defer editor.deinit();

    try editor.insertText("alpha beta\ngamma");
    editor.setCursor(0, 2);

    try std.testing.expect(app_editor_actions.applyDirectEditorAction(editor, .editor_extend_line_end));
    try std.testing.expectEqual(@as(usize, 2), editor.selection.?.start.offset);
    try std.testing.expectEqual(@as(usize, 10), editor.selection.?.end.offset);

    editor.setCursor(0, 0);
    try std.testing.expect(app_editor_actions.applyDirectEditorAction(editor, .editor_extend_word_right));
    try std.testing.expectEqual(@as(usize, 0), editor.selection.?.start.offset);
    try std.testing.expectEqual(@as(usize, 6), editor.selection.?.end.offset);

    try std.testing.expect(!app_editor_actions.applyDirectEditorAction(editor, .editor_search_open));
}

test "direct editor action helper routes horizontal selection actions" {
    const allocator = std.testing.allocator;

    var grammar_manager = try grammar_manager_mod.GrammarManager.init(allocator);
    defer grammar_manager.deinit();

    const editor = try Editor.init(allocator, &grammar_manager);
    defer editor.deinit();

    try editor.insertText("alpha");
    editor.setCursor(0, 2);

    try std.testing.expect(app_editor_actions.applyDirectEditorAction(editor, .editor_extend_left));
    try std.testing.expectEqual(@as(usize, 2), editor.selection.?.start.offset);
    try std.testing.expectEqual(@as(usize, 1), editor.selection.?.end.offset);

    try std.testing.expect(app_editor_actions.applyDirectEditorAction(editor, .editor_extend_right));
    try std.testing.expect(editor.selection == null);
}

test "direct editor action helper routes word cursor movement actions" {
    const allocator = std.testing.allocator;

    var grammar_manager = try grammar_manager_mod.GrammarManager.init(allocator);
    defer grammar_manager.deinit();

    const editor = try Editor.init(allocator, &grammar_manager);
    defer editor.deinit();

    try editor.insertText("alpha beta_gamma");
    editor.setCursor(0, 0);

    try std.testing.expect(app_editor_actions.applyDirectEditorAction(editor, .editor_move_word_right));
    try std.testing.expectEqual(@as(usize, 6), editor.cursor.offset);

    try std.testing.expect(app_editor_actions.applyDirectEditorAction(editor, .editor_move_word_right));
    try std.testing.expectEqual(@as(usize, 16), editor.cursor.offset);

    try std.testing.expect(app_editor_actions.applyDirectEditorAction(editor, .editor_move_word_left));
    try std.testing.expectEqual(@as(usize, 6), editor.cursor.offset);
}

test "caret editor action helper routes add-caret actions" {
    const allocator = std.testing.allocator;

    var grammar_manager = try grammar_manager_mod.GrammarManager.init(allocator);
    defer grammar_manager.deinit();

    const editor = try Editor.init(allocator, &grammar_manager);
    defer editor.deinit();

    try editor.insertText("one\ntwo\nthree");
    editor.setCursor(0, 1);

    try std.testing.expect(try app_editor_actions.applyCaretEditorAction(editor, .editor_add_caret_down));
    try std.testing.expectEqual(@as(usize, 1), editor.auxiliaryCaretCount());
    try std.testing.expectEqual(@as(usize, 5), editor.auxiliaryCaretAt(0).?.offset);

    try std.testing.expect(try app_editor_actions.applyCaretEditorAction(editor, .editor_add_caret_down));
    try std.testing.expectEqual(@as(usize, 2), editor.auxiliaryCaretCount());
    try std.testing.expectEqual(@as(usize, 9), editor.auxiliaryCaretAt(1).?.offset);

    try std.testing.expect(!try app_editor_actions.applyCaretEditorAction(editor, .editor_search_open));
}

test "openSearchPanel restores editor query and clears stale panel text" {
    const allocator = std.testing.allocator;

    var grammar_manager = try grammar_manager_mod.GrammarManager.init(allocator);
    defer grammar_manager.deinit();

    var editor = try Editor.init(allocator, &grammar_manager);
    defer editor.deinit();
    try editor.setSearchQuery("alpha");

    var app: AppState = undefined;
    app.allocator = allocator;
    app.search_panel = AppState.SearchPanelState.init(allocator);
    defer app.search_panel.deinit(allocator);

    try app.search_panel.query.appendSlice(allocator, "stale");
    try app_search_panel_state.openPanel(allocator, &app.search_panel.active, &app.search_panel.query, editor);

    try std.testing.expect(app.search_panel.active);
    try std.testing.expectEqualStrings("alpha", app.search_panel.query.items);
}

test "search panel reopen preserves synced query through editor state" {
    const allocator = std.testing.allocator;

    var grammar_manager = try grammar_manager_mod.GrammarManager.init(allocator);
    defer grammar_manager.deinit();

    const editor = try Editor.init(allocator, &grammar_manager);
    defer editor.deinit();

    var app: AppState = undefined;
    app.allocator = allocator;
    app.search_panel = AppState.SearchPanelState.init(allocator);
    defer app.search_panel.deinit(allocator);

    try app_search_panel_state.openPanel(allocator, &app.search_panel.active, &app.search_panel.query, editor);
    try app.search_panel.query.appendSlice(allocator, "beta");
    try app_search_panel_state.syncEditorSearchQuery(editor, &app.search_panel.query);
    app_search_panel_state.closePanel(&app.search_panel.active);

    try std.testing.expect(!app.search_panel.active);
    try std.testing.expectEqualStrings("beta", app.search_panel.query.items);

    app.search_panel.query.clearRetainingCapacity();
    try app.search_panel.query.appendSlice(allocator, "junk");
    try app_search_panel_state.openPanel(allocator, &app.search_panel.active, &app.search_panel.query, editor);

    try std.testing.expect(app.search_panel.active);
    try std.testing.expectEqualStrings("beta", app.search_panel.query.items);
    try std.testing.expectEqualStrings("beta", editor.searchQuery().?);
}

fn initTestAppStateForTerminalTabRouting(allocator: std.mem.Allocator) !AppState {
    var app: AppState = undefined;
    app.allocator = allocator;
    app.app_mode = .terminal;
    app.active_kind = .terminal;
    app.metrics = Metrics.init();
    app.needs_redraw = false;
    app.tab_bar = TabBar.init(allocator);
    app.editor_mode_adapter = try app_modes.backend.bootstrap.initEditorMode(allocator, .{
        .seed_editor_tab = false,
        .seed_terminal_tab = false,
    });
    app.terminal_mode_adapter = try app_modes.backend.bootstrap.initTerminalMode(allocator, .{
        .seed_editor_tab = false,
        .seed_terminal_tab = false,
    });
    app.terminal_workspace = null;
    return app;
}

fn deinitTestAppStateForTerminalTabRouting(app: *AppState, allocator: std.mem.Allocator) void {
    app.tab_bar.deinit();
    app.editor_mode_adapter.deinit(allocator);
    app.terminal_mode_adapter.deinit(allocator);
}

test "terminal close intent routing emits only when tab id is present" {
    const allocator = std.testing.allocator;
    var app = try initTestAppStateForTerminalTabRouting(allocator);
    defer deinitTestAppStateForTerminalTabRouting(&app, allocator);

    try app.tab_bar.addTerminalTab("t1", 101);
    try app.tab_bar.addTerminalTab("t2", 202);
    app.tab_bar.active_index = 1;
    try app.syncModeAdaptersFromTabBar();

    try std.testing.expect(try app_terminal_runtime_intents.routeByTabIdAndSync(
        .close,
        202,
        @ptrCast(&app),
        struct {
            fn call(raw: *anyopaque, action: app_modes.shared.actions.TabAction) !void {
                const state: *AppState = @ptrCast(@alignCast(raw));
                app_tab_action_apply.applyTerminal(state.allocator, state.app_mode, &state.terminal_mode_adapter, action);
                try state.syncModeAdaptersFromTabBar();
            }
        }.call,
    ));
    try std.testing.expect(!try app_terminal_runtime_intents.routeByTabIdAndSync(
        .close,
        null,
        @ptrCast(&app),
        struct {
            fn call(raw: *anyopaque, action: app_modes.shared.actions.TabAction) !void {
                const state: *AppState = @ptrCast(@alignCast(raw));
                app_tab_action_apply.applyTerminal(state.allocator, state.app_mode, &state.terminal_mode_adapter, action);
                try state.syncModeAdaptersFromTabBar();
            }
        }.call,
    ));
}

test "terminal tab action apply keeps terminal mode aligned with reordered tab bar" {
    const allocator = std.testing.allocator;
    var app = try initTestAppStateForTerminalTabRouting(allocator);
    defer deinitTestAppStateForTerminalTabRouting(&app, allocator);

    try app.tab_bar.addTerminalTab("t1", 11);
    try app.tab_bar.addTerminalTab("t2", 22);
    try app.tab_bar.addTerminalTab("t3", 33);
    app.tab_bar.active_index = 1;
    try app.syncModeAdaptersFromTabBar();

    const moved = app.tab_bar.tabs.orderedRemove(0);
    try app.tab_bar.tabs.insert(allocator, 1, moved);
    app.tab_bar.active_index = 0;

    app_tab_action_apply.applyTerminal(app.allocator, app.app_mode, &app.terminal_mode_adapter, .{
        .move = .{
            .from_index = 0,
            .to_index = 1,
        },
    });
    try app.syncModeAdaptersFromTabBar();

    const snap = try app.terminal_mode_adapter.asContract().snapshot(allocator);
    try std.testing.expectEqual(@as(usize, 3), snap.tabs.len);
    try std.testing.expectEqual(@as(?u64, 22), snap.active_tab);
    try std.testing.expectEqual(@as(u64, 22), snap.tabs[0].id);
    try std.testing.expectEqual(@as(u64, 11), snap.tabs[1].id);
    try std.testing.expectEqual(@as(u64, 33), snap.tabs[2].id);
}

test "terminal activate intent routing emits only when tab id exists" {
    const allocator = std.testing.allocator;
    var app = try initTestAppStateForTerminalTabRouting(allocator);
    defer deinitTestAppStateForTerminalTabRouting(&app, allocator);

    try app.tab_bar.addTerminalTab("t1", 1001);
    try app.tab_bar.addTerminalTab("t2", 1002);
    app.tab_bar.active_index = 0;
    try app.syncModeAdaptersFromTabBar();

    try std.testing.expect(!try app_terminal_runtime_intents.routeByTabIdAndSync(
        .activate,
        null,
        @ptrCast(&app),
        struct {
            fn call(raw: *anyopaque, action: app_modes.shared.actions.TabAction) !void {
                const state: *AppState = @ptrCast(@alignCast(raw));
                app_tab_action_apply.applyTerminal(state.allocator, state.app_mode, &state.terminal_mode_adapter, action);
                try state.syncModeAdaptersFromTabBar();
            }
        }.call,
    ));
    try std.testing.expect(try app_terminal_runtime_intents.routeByTabIdAndSync(
        .activate,
        1002,
        @ptrCast(&app),
        struct {
            fn call(raw: *anyopaque, action: app_modes.shared.actions.TabAction) !void {
                const state: *AppState = @ptrCast(@alignCast(raw));
                app_tab_action_apply.applyTerminal(state.allocator, state.app_mode, &state.terminal_mode_adapter, action);
                try state.syncModeAdaptersFromTabBar();
            }
        }.call,
    ));
}

test "requestCancelTerminalCloseFromModal clears pending tab and marks redraw" {
    const allocator = std.testing.allocator;
    var app = try initTestAppStateForTerminalTabRouting(allocator);
    defer deinitTestAppStateForTerminalTabRouting(&app, allocator);

    app.terminal_close_confirm_tab = 42;
    app.needs_redraw = false;
    const consumed = app.requestCancelTerminalCloseFromModal(app_shell.getTime());
    try std.testing.expect(consumed);
    try std.testing.expectEqual(@as(?terminal_mod.TerminalTabId, null), app.terminal_close_confirm_tab);
    try std.testing.expect(app.needs_redraw);
}

test "applyTerminalCloseConfirmDecision handles consume and none without mutation" {
    const allocator = std.testing.allocator;
    var app = try initTestAppStateForTerminalTabRouting(allocator);
    defer deinitTestAppStateForTerminalTabRouting(&app, allocator);

    app.needs_redraw = false;
    try std.testing.expect(try app.applyTerminalCloseConfirmDecision(.consume, app_shell.getTime()));
    try std.testing.expect(!app.needs_redraw);

    try std.testing.expect(!try app.applyTerminalCloseConfirmDecision(.none, app_shell.getTime()));
    try std.testing.expect(!app.needs_redraw);
}
