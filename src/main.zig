const std = @import("std");
const app_bootstrap = @import("app/bootstrap.zig");
const app_config_reload_notice_state = @import("app/config_reload_notice_state.zig");
const app_editor_actions = @import("app/editor_actions.zig");
const app_editor_intent_route = @import("app/editor_intent_route.zig");
const app_editor_create_intent_runtime = @import("app/editor_create_intent_runtime.zig");
const app_editor_display_prepare = @import("app/editor_display_prepare.zig");
const app_editor_input_runtime = @import("app/editor_input_runtime.zig");
const app_editor_frame_hooks_runtime = @import("app/editor_frame_hooks_runtime.zig");
const app_editor_visible_caches_runtime = @import("app/editor_visible_caches_runtime.zig");
const app_active_editor_frame = @import("app/active_editor_frame.zig");
const app_editor_shortcuts_frame = @import("app/editor_shortcuts_frame.zig");
const app_editor_seed = @import("app/editor_seed.zig");
const app_file_detect = @import("app/file_detect.zig");
const app_font_rendering = @import("app/font_rendering.zig");
const app_terminal_grid = @import("app/terminal_grid.zig");
const app_terminal_runtime_intents = @import("app/terminal_runtime_intents.zig");
const app_terminal_intent_route_runtime = @import("app/terminal_intent_route_runtime.zig");
const app_terminal_active_widget = @import("app/terminal_active_widget.zig");
const app_terminal_clipboard_shortcuts_frame = @import("app/terminal_clipboard_shortcuts_frame.zig");
const app_terminal_tab_bar_sync_runtime = @import("app/terminal_tab_bar_sync_runtime.zig");
const app_terminal_tabs_runtime = @import("app/terminal_tabs_runtime.zig");
const app_terminal_surface_gate = @import("app/terminal_surface_gate.zig");
const app_terminal_shortcut_suppress = @import("app/terminal_shortcut_suppress.zig");
const app_terminal_shortcut_policy = @import("app/terminal_shortcut_policy.zig");
const app_terminal_shortcut_runtime = @import("app/terminal_shortcut_runtime.zig");
const app_terminal_tab_intents = @import("app/terminal_tab_intents.zig");
const app_terminal_resize = @import("app/terminal_resize.zig");
const app_terminal_refresh_sizing_runtime = @import("app/terminal_refresh_sizing_runtime.zig");
const app_pre_input_shortcut_frame_runtime = @import("app/pre_input_shortcut_frame_runtime.zig");
const app_visible_terminal_frame = @import("app/visible_terminal_frame.zig");
const app_visible_terminal_frame_hooks_runtime = @import("app/visible_terminal_frame_hooks_runtime.zig");
const app_terminal_session_bootstrap = @import("app/terminal_session_bootstrap.zig");
const app_terminal_widget_input_runtime = @import("app/terminal_widget_input_runtime.zig");
const app_terminal_widget_input_hook_runtime = @import("app/terminal_widget_input_hook_runtime.zig");
const app_terminal_close_confirm_input = @import("app/terminal_close_confirm_input.zig");
const app_mode_adapter_sync_runtime = @import("app/mode_adapter_sync_runtime.zig");
const app_terminal_theme_apply = @import("app/terminal_theme_apply.zig");
const app_poll_visible_terminal_sessions_runtime = @import("app/poll_visible_terminal_sessions_runtime.zig");
const app_search_panel_input = @import("app/search_panel_input.zig");
const app_search_panel_frame_runtime = @import("app/search_panel_frame_runtime.zig");
const app_search_panel_runtime = @import("app/search_panel_runtime.zig");
const app_search_panel_state = @import("app/search_panel_state.zig");
const app_mouse_debug_log = @import("app/mouse_debug_log.zig");
const app_mouse_pressed_frame = @import("app/mouse_pressed_frame.zig");
const app_mouse_pressed_routing_runtime = @import("app/mouse_pressed_routing_runtime.zig");
const app_mouse_pressed_hooks_runtime = @import("app/mouse_pressed_hooks_runtime.zig");
const app_input_actions_hooks_runtime = @import("app/input_actions_hooks_runtime.zig");
const app_tab_drag_input_runtime = @import("app/tab_drag_input_runtime.zig");
const app_active_view_runtime = @import("app/active_view_runtime.zig");
const app_active_view_hooks_runtime = @import("app/active_view_hooks_runtime.zig");
const app_pointer_activity_frame = @import("app/pointer_activity_frame.zig");
const app_terminal_split_resize_frame = @import("app/terminal_split_resize_frame.zig");
const app_window_resize_event_frame = @import("app/window_resize_event_frame.zig");
const app_deferred_terminal_resize_frame = @import("app/deferred_terminal_resize_frame.zig");
const app_cursor_blink_frame = @import("app/cursor_blink_frame.zig");
const app_post_preinput_frame = @import("app/post_preinput_frame.zig");
const app_post_preinput_hooks_runtime = @import("app/post_preinput_hooks_runtime.zig");
const app_update_frame_hooks_runtime = @import("app/update_frame_hooks_runtime.zig");
const app_update_driver = @import("app/update_driver.zig");
const app_run_loop_driver = @import("app/run_loop_driver.zig");
const app_reload_config_runtime = @import("app/reload_config_runtime.zig");
const app_run_mode_init = @import("app/run_mode_init.zig");
const app_prepare_run_frame_runtime = @import("app/prepare_run_frame_runtime.zig");
const app_frame_render_idle_hooks_runtime = @import("app/frame_render_idle_hooks_runtime.zig");
const app_update_prelude_frame_runtime = @import("app/update_prelude_frame_runtime.zig");
const app_ui_layout_runtime = @import("app/ui_layout_runtime.zig");
const app_run_entry_runtime = @import("app/run_entry_runtime.zig");
const app_terminal_tab_navigation_runtime = @import("app/terminal_tab_navigation_runtime.zig");
const app_terminal_close_active_runtime = @import("app/terminal_close_active_runtime.zig");
const app_terminal_close_confirm_active_runtime = @import("app/terminal_close_confirm_active_runtime.zig");
const app_terminal_close_confirm_decision_runtime = @import("app/terminal_close_confirm_decision_runtime.zig");
const app_tab_action_apply_runtime = @import("app/tab_action_apply_runtime.zig");
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
        _ = try app_editor_create_intent_runtime.routeCreateAndSync(self);
        const editor = try Editor.init(self.allocator, &self.grammar_manager);
        try self.editors.append(self.allocator, editor);
        try self.tab_bar.addTab("untitled", .editor);
        self.active_tab = self.tab_bar.tabs.items.len - 1;
        self.active_kind = .editor;
        try app_mode_adapter_sync_runtime.sync(self);
    }

    pub fn openFile(self: *AppState, path: []const u8) !void {
        _ = try app_editor_create_intent_runtime.routeCreateAndSync(self);
        const editor = try Editor.init(self.allocator, &self.grammar_manager);
        try editor.openFile(path);
        try self.editors.append(self.allocator, editor);

        // Extract filename for tab title
        const filename = std.fs.path.basename(path);
        try self.tab_bar.addTab(filename, .editor);
        self.active_tab = self.tab_bar.tabs.items.len - 1;
        self.active_kind = .editor;
        try app_mode_adapter_sync_runtime.sync(self);
    }

    pub fn openFileAt(self: *AppState, path: []const u8, line_1: usize, col_1: ?usize) !void {
        _ = try app_editor_create_intent_runtime.routeCreateAndSync(self);
        const editor = try Editor.init(self.allocator, &self.grammar_manager);
        try editor.openFile(path);
        try self.editors.append(self.allocator, editor);

        const filename = std.fs.path.basename(path);
        try self.tab_bar.addTab(filename, .editor);
        self.active_tab = self.tab_bar.tabs.items.len - 1;
        self.active_kind = .editor;
        try app_mode_adapter_sync_runtime.sync(self);

        const line0 = if (line_1 > 0) line_1 - 1 else 0;
        const col0 = if (col_1) |c1| (if (c1 > 0) c1 - 1 else 0) else 0;
        const clamped_line = @min(line0, editor.lineCount() -| 1);
        const line_len = editor.lineLen(clamped_line);
        const clamped_col = @min(col0, line_len);
        editor.setCursor(clamped_line, clamped_col);
    }

    fn routeOpenFileFromCtx(raw: *anyopaque, path: []const u8) !void {
        const state: *AppState = @ptrCast(@alignCast(raw));
        try state.openFile(path);
    }

    fn routeOpenFileAtFromCtx(raw: *anyopaque, path: []const u8, line_1: usize, col_1: ?usize) !void {
        const state: *AppState = @ptrCast(@alignCast(raw));
        try state.openFileAt(path, line_1, col_1);
    }

    fn routeSyncTerminalTabBarFromCtx(raw: *anyopaque) !void {
        const state: *AppState = @ptrCast(@alignCast(raw));
        try app_terminal_tab_bar_sync_runtime.syncIfWorkspace(state);
    }

    fn routeNewEditorFromCtx(raw: *anyopaque) !void {
        const state: *AppState = @ptrCast(@alignCast(raw));
        try state.newEditor();
    }

    fn routeNewTerminalFromCtx(raw: *anyopaque) !void {
        const state: *AppState = @ptrCast(@alignCast(raw));
        try state.newTerminal();
    }

    fn routeSeedDefaultWelcomeBufferFromCtx(raw: *anyopaque) !void {
        const state: *AppState = @ptrCast(@alignCast(raw));
        if (state.editors.items.len > 0) {
            const editor = state.editors.items[0];
            try app_editor_seed.seedDefaultWelcomeBuffer(editor);
        }
    }

    fn routeTerminalTabCountFromCtx(raw: *anyopaque) usize {
        const state: *AppState = @ptrCast(@alignCast(raw));
        return app_terminal_tabs_runtime.count(state.app_mode, state.terminal_workspace, state.terminals.items.len);
    }

    fn routeRefreshTerminalSizingFromCtx(raw: *anyopaque) !void {
        const state: *AppState = @ptrCast(@alignCast(raw));
        try app_terminal_refresh_sizing_runtime.handle(
            state,
            state.app_mode,
            &state.terminal_workspace,
            state.terminals.items,
            state.show_terminal,
            state.terminal_height,
            state.shell,
        );
    }

    fn routeApplyCurrentTabBarWidthModeFromCtx(raw: *anyopaque) void {
        const state: *AppState = @ptrCast(@alignCast(raw));
        app_tab_bar_width.applyForMode(
            &state.tab_bar,
            state.app_mode,
            state.editor_tab_bar_width_mode,
            state.terminal_tab_bar_width_mode,
        );
    }

    fn routeReloadConfigFromCtx(raw: *anyopaque) !void {
        const state: *AppState = @ptrCast(@alignCast(raw));
        try app_reload_config_runtime.handle(
            state,
            raw,
            .{
                .refresh_terminal_sizing = routeRefreshTerminalSizingFromCtx,
                .apply_current_tab_bar_width_mode = routeApplyCurrentTabBarWidthModeFromCtx,
            },
        );
    }

    fn routeShowConfigReloadNoticeFromCtx(raw: *anyopaque, success: bool) void {
        const state: *AppState = @ptrCast(@alignCast(raw));
        const notice = app_config_reload_notice_state.arm(app_shell.getTime(), success);
        state.config_reload_notice_success = notice.success;
        state.config_reload_notice_until = notice.until;
        state.needs_redraw = true;
    }

    fn routeNoteInputFromCtx(raw: *anyopaque, at: f64) void {
        const state: *AppState = @ptrCast(@alignCast(raw));
        state.metrics.noteInput(at);
    }

    fn routeActiveTerminalCloseIntentFromCtx(raw: *anyopaque) !void {
        const state: *AppState = @ptrCast(@alignCast(raw));
        _ = try app_terminal_intent_route_runtime.routeActiveAndSync(state, .close);
    }

    fn routeCloseActiveTerminalTabFromCtx(raw: *anyopaque) !bool {
        const state: *AppState = @ptrCast(@alignCast(raw));
        return try app_terminal_close_active_runtime.closeActive(
            state,
            raw,
            .{ .sync_terminal_mode_tab_bar = routeSyncTerminalTabBarFromCtx },
        );
    }

    fn routeApplyTerminalCloseConfirmDecisionFromCtx(
        raw: *anyopaque,
        decision: app_modes.ide.TerminalCloseConfirmDecision,
        at: f64,
    ) !bool {
        const state: *AppState = @ptrCast(@alignCast(raw));
        return try app_terminal_close_confirm_decision_runtime.applyDecision(
            state,
            decision,
            at,
            raw,
            .{
                .route_close_intent_and_sync = routeActiveTerminalCloseIntentFromCtx,
                .close_active_terminal_tab = routeCloseActiveTerminalTabFromCtx,
                .note_input = routeNoteInputFromCtx,
            },
        );
    }

    fn routeReconcileTerminalCloseModalActiveFromCtx(raw: *anyopaque) bool {
        const state: *AppState = @ptrCast(@alignCast(raw));
        return app_terminal_close_confirm_active_runtime.reconcile(state);
    }

    fn routeComputeLayoutFromCtx(raw: *anyopaque, w: f32, h: f32) layout_types.WidgetLayout {
        const state: *AppState = @ptrCast(@alignCast(raw));
        return app_ui_layout_runtime.computeLayout(state, w, h);
    }

    fn routeMarkRedrawFromCtx(raw: *anyopaque) void {
        const state: *AppState = @ptrCast(@alignCast(raw));
        state.needs_redraw = true;
    }

    pub fn handlePreInputShortcutFrame(
        self: *AppState,
        frame_shell: *Shell,
        frame_input_batch: *shared_types.input.InputBatch,
        focus: input_actions.FocusKind,
        at: f64,
    ) !app_update_prelude_frame_runtime.PreInputResult {
        return try app_pre_input_shortcut_frame_runtime.handle(
            self.input_router.actionsSlice(),
            frame_shell,
            frame_input_batch,
            focus,
            at,
            self.app_mode,
            self.show_terminal,
            &self.terminal_workspace,
            self.terminals.items,
            self.terminal_widgets.items,
            self.allocator,
            self.editors.items,
            self.active_tab,
            &self.editor_cluster_cache,
            self.editor_wrap,
            self.editor_large_jump_rows,
            &self.search_panel.active,
            &self.search_panel.query,
            @ptrCast(self),
            .{
                .reload_config = routeReloadConfigFromCtx,
                .show_reload_notice = routeShowConfigReloadNoticeFromCtx,
                .reconcile_terminal_close_modal_active = routeReconcileTerminalCloseModalActiveFromCtx,
                .apply_terminal_close_confirm_decision = routeApplyTerminalCloseConfirmDecisionFromCtx,
                .compute_layout = routeComputeLayoutFromCtx,
                .mark_redraw = routeMarkRedrawFromCtx,
                .note_input = routeNoteInputFromCtx,
            },
        );
    }

    pub fn handlePostPreinputFrame(
        self: *AppState,
        shell: *Shell,
        batch: *shared_types.input.InputBatch,
        now: f64,
    ) !app_update_driver.Frame {
        return try app_post_preinput_hooks_runtime.handle(self, shell, batch, now);
    }

    pub fn handleInputActionsFrame(
        self: *AppState,
        frame_shell: *Shell,
        at: f64,
    ) !bool {
        return try app_input_actions_hooks_runtime.handle(self, frame_shell, at);
    }

    pub fn handleTabDragFrame(
        self: *AppState,
        frame_input_batch: *shared_types.input.InputBatch,
        layout: layout_types.WidgetLayout,
        mouse: shared_types.input.MousePos,
        at: f64,
    ) !void {
        try app_tab_drag_input_runtime.handle(
            self.app_mode,
            &self.tab_bar,
            app_terminal_tabs_runtime.barVisible(
                self.app_mode,
                self.terminal_tab_bar_show_single_tab,
                self.terminal_workspace,
                self.terminals.items.len,
            ),
            &self.active_tab,
            frame_input_batch,
            layout,
            mouse,
            at,
            @ptrCast(self),
            .{
                .apply_terminal_action = struct {
                    fn call(hook_raw: *anyopaque, action: app_modes.shared.actions.TabAction) !void {
                        const state: *AppState = @ptrCast(@alignCast(hook_raw));
                        try app_tab_action_apply_runtime.applyTerminalAndSync(state, action);
                    }
                }.call,
                .route_activate_by_tab_id = struct {
                    fn call(hook_raw: *anyopaque, tab_id: ?u64) !void {
                        const state: *AppState = @ptrCast(@alignCast(hook_raw));
                        _ = try app_terminal_intent_route_runtime.routeByTabIdAndSync(
                            state,
                            .activate,
                            tab_id,
                        );
                    }
                }.call,
                .focus_terminal_tab_index = struct {
                    fn call(hook_raw: *anyopaque, index: usize) bool {
                        const state: *AppState = @ptrCast(@alignCast(hook_raw));
                        return app_terminal_tab_navigation_runtime.focusByIndex(state, index);
                    }
                }.call,
                .apply_editor_action = struct {
                    fn call(hook_raw: *anyopaque, action: app_modes.shared.actions.TabAction) !void {
                        const state: *AppState = @ptrCast(@alignCast(hook_raw));
                        try app_tab_action_apply_runtime.applyEditorAndSync(state, action);
                    }
                }.call,
                .mark_redraw = struct {
                    fn call(hook_raw: *anyopaque) void {
                        const state: *AppState = @ptrCast(@alignCast(hook_raw));
                        state.needs_redraw = true;
                    }
                }.call,
                .note_input = struct {
                    fn call(hook_raw: *anyopaque, t: f64) void {
                        const state: *AppState = @ptrCast(@alignCast(hook_raw));
                        state.metrics.noteInput(t);
                    }
                }.call,
            },
        );
    }

    pub fn handleMousePressedFrame(
        self: *AppState,
        frame_shell: *Shell,
        layout: layout_types.WidgetLayout,
        mouse: shared_types.input.MousePos,
        term_y: f32,
        frame_input_batch: *shared_types.input.InputBatch,
        at: f64,
    ) !void {
        try app_mouse_pressed_hooks_runtime.handle(
            self,
            frame_shell,
            layout,
            mouse,
            term_y,
            frame_input_batch,
            at,
        );
    }

    pub fn handleActiveViewFrame(
        self: *AppState,
        frame_shell: *Shell,
        layout: layout_types.WidgetLayout,
        mouse: shared_types.input.MousePos,
        frame_input_batch: *shared_types.input.InputBatch,
        frame_suppress_terminal_shortcuts: bool,
        frame_terminal_close_modal_active: bool,
        at: f64,
    ) !void {
        try app_active_view_hooks_runtime.handle(
            self.allocator,
            &self.search_panel.active,
            &self.search_panel.query,
            self.editors.items,
            self.active_tab,
            self.app_mode,
            self.active_kind,
            &self.editor_cluster_cache,
            self.editor_wrap,
            frame_shell,
            layout,
            mouse,
            frame_input_batch,
            self.perf_mode,
            &self.perf_frames_done,
            self.perf_frames_total,
            self.perf_scroll_delta,
            &self.editor_render_cache,
            self.editor_highlight_budget,
            self.editor_width_budget,
            .{
                .editor_hscroll_dragging = &self.editor_hscroll_dragging,
                .editor_hscroll_grab_offset = &self.editor_hscroll_grab_offset,
                .editor_vscroll_dragging = &self.editor_vscroll_dragging,
                .editor_vscroll_grab_offset = &self.editor_vscroll_grab_offset,
                .editor_dragging = &self.editor_dragging,
                .editor_drag_start = &self.editor_drag_start,
                .editor_drag_rect = &self.editor_drag_rect,
            },
            self.show_terminal,
            &self.terminal_workspace,
            self.terminals.items,
            self.terminal_widgets.items,
            self.tab_bar.isDragging(),
            frame_suppress_terminal_shortcuts,
            frame_terminal_close_modal_active,
            self.allocator,
            &self.terminal_scroll_dragging,
            &self.terminal_scroll_grab_offset,
            at,
            &self.needs_redraw,
            &self.metrics,
            @ptrCast(self),
            .{
                .open_file = routeOpenFileFromCtx,
                .open_file_at = routeOpenFileAtFromCtx,
                .sync_terminal_tab_bar = routeSyncTerminalTabBarFromCtx,
            },
        );
    }

    fn handleUpdateFrame(
        self: *AppState,
        input_batch: *shared_types.input.InputBatch,
    ) !void {
        try app_update_frame_hooks_runtime.handle(self, input_batch);
    }

    fn handleFrameRenderAndIdle(
        self: *AppState,
        input_batch: *shared_types.input.InputBatch,
        poll_ms: f64,
        build_ms: f64,
        update_ms: f64,
    ) void {
        app_frame_render_idle_hooks_runtime.handle(self, input_batch, poll_ms, build_ms, update_ms);
    }

    fn shouldStopForPerfFrame(self: *AppState) bool {
        return self.perf_mode and self.perf_frames_done >= self.perf_frames_total and self.perf_frames_total > 0;
    }

    fn onPerfCompleteFrame(self: *AppState) void {
        self.perf_logger.logf("perf complete frames={d}", .{self.perf_frames_done});
    }

    fn runOneFrame(self: *AppState) !bool {
        return try app_run_loop_driver.runOneFrame(
            @ptrCast(self),
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
                        try step_state.handleUpdateFrame(input_batch);
                    }
                }.step,
                .handle_frame_render_and_idle = struct {
                    fn step(step_raw: *anyopaque, input_batch: *shared_types.input.InputBatch, poll_ms: f64, build_ms: f64, update_ms: f64) void {
                        const step_state: *AppState = @ptrCast(@alignCast(step_raw));
                        step_state.handleFrameRenderAndIdle(input_batch, poll_ms, build_ms, update_ms);
                    }
                }.step,
                .should_stop_for_perf = struct {
                    fn step(step_raw: *anyopaque) bool {
                        const step_state: *AppState = @ptrCast(@alignCast(step_raw));
                        return step_state.shouldStopForPerfFrame();
                    }
                }.step,
                .on_perf_complete = struct {
                    fn step(step_raw: *anyopaque) void {
                        const step_state: *AppState = @ptrCast(@alignCast(step_raw));
                        step_state.onPerfCompleteFrame();
                    }
                }.step,
            },
        );
    }

    fn runMainLoop(self: *AppState) !void {
        try app_run_loop_driver.runMainLoop(
            self.shell,
            @ptrCast(self),
            .{
                .run_one_frame = struct {
                    fn inner(one_frame_raw: *anyopaque) !bool {
                        const one_frame_state: *AppState = @ptrCast(@alignCast(one_frame_raw));
                        return try one_frame_state.runOneFrame();
                    }
                }.inner,
            },
        );
    }

    fn initializeRunModeState(self: *AppState) !void {
        try app_run_mode_init.initialize(
            self.app_mode,
            self.perf_mode,
            self.perf_file_path,
            @ptrCast(self),
            .{
                .terminal_tab_count = routeTerminalTabCountFromCtx,
                .new_terminal = routeNewTerminalFromCtx,
                .sync_terminal_mode_tab_bar = routeSyncTerminalTabBarFromCtx,
                .open_file = routeOpenFileFromCtx,
                .new_editor = routeNewEditorFromCtx,
                .seed_default_welcome_buffer = routeSeedDefaultWelcomeBufferFromCtx,
            },
        );
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
                try app_terminal_tab_bar_sync_runtime.syncIfWorkspace(self);
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
                        try state.initializeRunModeState();
                    }
                }.call,
                .run_main_loop = struct {
                    fn call(raw: *anyopaque) !void {
                        const run_state: *AppState = @ptrCast(@alignCast(raw));
                        try run_state.runMainLoop();
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
    try app_mode_adapter_sync_runtime.sync(app);

    try std.testing.expect(try app_terminal_runtime_intents.routeByTabIdAndSync(
        .close,
        202,
        @ptrCast(&app),
        struct {
            fn call(raw: *anyopaque, action: app_modes.shared.actions.TabAction) !void {
                const state: *AppState = @ptrCast(@alignCast(raw));
                try app_tab_action_apply_runtime.applyTerminalAndSync(state, action);
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
                try app_tab_action_apply_runtime.applyTerminalAndSync(state, action);
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
    try app_mode_adapter_sync_runtime.sync(app);

    const moved = app.tab_bar.tabs.orderedRemove(0);
    try app.tab_bar.tabs.insert(allocator, 1, moved);
    app.tab_bar.active_index = 0;

    try app_tab_action_apply_runtime.applyTerminalAndSync(app, .{
        .move = .{
            .from_index = 0,
            .to_index = 1,
        },
    });

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
    try app_mode_adapter_sync_runtime.sync(app);

    try std.testing.expect(!try app_terminal_runtime_intents.routeByTabIdAndSync(
        .activate,
        null,
        @ptrCast(&app),
        struct {
            fn call(raw: *anyopaque, action: app_modes.shared.actions.TabAction) !void {
                const state: *AppState = @ptrCast(@alignCast(raw));
                try app_tab_action_apply_runtime.applyTerminalAndSync(state, action);
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
                try app_tab_action_apply_runtime.applyTerminalAndSync(state, action);
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
