const std = @import("std");
const app_bootstrap = @import("app/bootstrap.zig");
const app_config_reload_notice_state = @import("app/config_reload_notice_state.zig");
const app_editor_actions = @import("app/editor_actions.zig");
const app_editor_intent_route = @import("app/editor_intent_route.zig");
const app_editor_seed = @import("app/editor_seed.zig");
const app_file_detect = @import("app/file_detect.zig");
const app_font_rendering = @import("app/font_rendering.zig");
const app_config_reload_notice = @import("app/config_reload_notice.zig");
const app_terminal_grid = @import("app/terminal_grid.zig");
const app_terminal_runtime_intents = @import("app/terminal_runtime_intents.zig");
const app_terminal_tab_ops = @import("app/terminal_tab_ops.zig");
const app_terminal_shortcut_policy = @import("app/terminal_shortcut_policy.zig");
const app_terminal_shortcut_runtime = @import("app/terminal_shortcut_runtime.zig");
const app_terminal_tab_intents = @import("app/terminal_tab_intents.zig");
const app_terminal_resize = @import("app/terminal_resize.zig");
const app_terminal_session_bootstrap = @import("app/terminal_session_bootstrap.zig");
const app_terminal_close_confirm_state = @import("app/terminal_close_confirm_state.zig");
const app_terminal_close_confirm_runtime = @import("app/terminal_close_confirm_runtime.zig");
const app_terminal_theme_apply = @import("app/terminal_theme_apply.zig");
const app_terminal_tabs = @import("app/terminal_tabs.zig");
const app_terminal_close_confirm_draw = @import("app/terminal_close_confirm_draw.zig");
const app_search_panel_input = @import("app/search_panel_input.zig");
const app_search_panel_state = @import("app/search_panel_state.zig");
const app_tab_action_apply = @import("app/tab_action_apply.zig");
const app_tab_bar_width = @import("app/tab_bar_width.zig");
const app_theme_utils = @import("app/theme_utils.zig");
const app_runner = @import("app/runner.zig");
const app_signals = @import("app/signals.zig");
const terminal_scrollback_pager = @import("app/terminal_scrollback_pager.zig");
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
const widgets_common = @import("ui/widgets/common.zig");
const editor_draw = @import("ui/widgets/editor_widget_draw.zig");
const layout_types = shared_types.layout;
const input_builder = @import("input/input_builder.zig");
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
        state.applyUiScale();
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

    fn activeEditor(self: *AppState) ?*Editor {
        if (self.editors.items.len == 0) return null;
        const editor_idx = @min(self.active_tab, self.editors.items.len - 1);
        return self.editors.items[editor_idx];
    }

    fn consumeEditorHighlightDirtyRange(self: *AppState, editor: *Editor) void {
        const total_lines = editor.lineCount();
        if (editor.takeHighlightDirtyRange()) |range| {
            const end_line = @min(range.end_line, total_lines);
            self.editor_render_cache.invalidateHighlightRange(range.start_line, end_line);
        }
    }

    fn prepareEditorForDisplay(self: *AppState, editor: *Editor) void {
        self.consumeEditorHighlightDirtyRange(editor);
        editor.ensureHighlighter();
    }

    fn handleSearchPanelInput(self: *AppState, editor: *Editor, input_batch: *shared_types.input.InputBatch) !bool {
        if (!self.search_panel.active) return false;

        var handled = false;
        var query_changed = false;

        const searchAction = struct {
            fn run(target_editor: *Editor, forward: bool) bool {
                const active = target_editor.searchActiveMatch() orelse return false;
                if (target_editor.cursor.offset != active.start) {
                    return target_editor.focusSearchActiveMatch();
                }
                return if (forward)
                    target_editor.activateNextSearchMatch()
                else
                    target_editor.activatePrevSearchMatch();
            }
        }.run;

        switch (app_search_panel_input.searchPanelCommand(input_batch)) {
            .close => {
                app_search_panel_state.closePanel(&self.search_panel.active);
                return true;
            },
            .next => {
                _ = searchAction(editor, true);
                return true;
            },
            .prev => {
                _ = searchAction(editor, false);
                return true;
            },
            .backspace => {
                app_search_panel_state.popQueryScalar(&self.search_panel.query);
                query_changed = true;
                handled = true;
            },
            .none => {},
        }

        if (try app_search_panel_input.appendSearchPanelTextEvents(self.allocator, &self.search_panel.query, input_batch)) {
            query_changed = true;
            handled = true;
        }

        if (query_changed) {
            try app_search_panel_state.syncEditorSearchQuery(editor, &self.search_panel.query);
        }

        return handled;
    }

    fn terminalTabCount(self: *const AppState) usize {
        return app_terminal_tabs.count(
            self.app_mode,
            self.terminal_workspace,
            self.terminals.items.len,
        );
    }

    fn terminalTabBarVisible(self: *const AppState) bool {
        return app_terminal_tabs.barVisible(
            self.app_mode,
            self.terminal_tab_bar_show_single_tab,
            self.terminalTabCount(),
        );
    }

    fn activeTerminalArrayIndex(self: *const AppState) ?usize {
        return app_terminal_tabs.activeIndex(
            self.app_mode,
            self.terminal_workspace,
            self.terminalTabCount(),
        );
    }

    fn activeTerminalSession(self: *AppState) ?*TerminalSession {
        const idx = self.activeTerminalArrayIndex() orelse return null;
        if (app_modes.ide.shouldUseTerminalWorkspace(self.app_mode)) {
            if (self.terminal_workspace) |*workspace| {
                return workspace.sessionAt(idx);
            }
            return null;
        }
        return self.terminals.items[idx];
    }

    fn activeTerminalWidget(self: *AppState) ?*TerminalWidget {
        const idx = self.activeTerminalArrayIndex() orelse return null;
        if (idx >= self.terminal_widgets.items.len) return null;
        return &self.terminal_widgets.items[idx];
    }

    fn syncTerminalModeTabBar(self: *AppState) !void {
        if (!app_modes.ide.shouldUseTerminalWorkspace(self.app_mode)) return;
        if (self.terminal_workspace) |*workspace| {
            const count = workspace.tabCount();
            var has_non_terminal = false;
            for (self.tab_bar.tabs.items) |tab| {
                if (tab.kind != .terminal) {
                    has_non_terminal = true;
                    break;
                }
            }
            if (has_non_terminal) {
                self.tab_bar.clearTabs();
            }

            // Remove tabs that no longer exist in workspace.
            var i: usize = self.tab_bar.tabs.items.len;
            while (i > 0) {
                i -= 1;
                const tab = self.tab_bar.tabs.items[i];
                if (tab.kind != .terminal) {
                    self.tab_bar.removeTabAt(i);
                    continue;
                }
                const tab_id = tab.terminal_tab_id orelse {
                    self.tab_bar.removeTabAt(i);
                    continue;
                };
                var found = false;
                for (0..count) |widx| {
                    if (workspace.tabIdAt(widx)) |wid| {
                        if (wid == tab_id) {
                            found = true;
                            break;
                        }
                    }
                }
                if (!found) self.tab_bar.removeTabAt(i);
            }

            // Add missing tabs and refresh titles while preserving current visual order.
            for (0..count) |widx| {
                const tab_id = workspace.tabIdAt(widx) orelse continue;
                const session = workspace.sessionAt(widx) orelse continue;
                const title = if (session.currentTitle().len > 0) session.currentTitle() else "Terminal";
                if (self.tab_bar.indexOfTerminalTabId(tab_id)) |bar_idx| {
                    try self.tab_bar.setTabTitle(bar_idx, title);
                } else {
                    try self.tab_bar.addTerminalTab(title, tab_id);
                }
            }

            if (workspace.activeTabId()) |active_id| {
                self.tab_bar.active_index = self.tab_bar.indexOfTerminalTabId(active_id) orelse 0;
            } else {
                self.tab_bar.active_index = 0;
            }
        } else {
            self.tab_bar.clearTabs();
        }
        try self.syncModeAdaptersFromTabBar();
    }

    fn syncModeAdaptersFromTabBar(self: *AppState) !void {
        var projections = try app_modes.ide.buildTabProjections(self.allocator, self.tab_bar.tabs.items);
        defer projections.deinit(self.allocator);

        const active_projection = app_modes.ide.activeProjectionForTabBar(
            self.active_kind,
            self.tab_bar.tabs.items,
            self.tab_bar.active_index,
        );

        try app_modes.runtime_bridge.syncModesFromProjections(
            self.allocator,
            &self.editor_mode_adapter,
            &self.terminal_mode_adapter,
            projections.items,
            active_projection,
        );
        self.logModeAdapterParity();
    }

    fn requestCloseActiveTerminalTab(self: *AppState, now: f64) !bool {
        _ = try self.routeActiveWorkspaceTerminalIntentAndSync(.close);
        if (try self.closeActiveTerminalTab()) {
            self.needs_redraw = true;
            self.metrics.noteInput(now);
            return true;
        }
        if (self.terminalCloseConfirmActive()) {
            self.needs_redraw = true;
            self.metrics.noteInput(now);
            return true;
        }
        return false;
    }

    fn requestCreateTerminalTab(self: *AppState, now: f64) !bool {
        try self.routeTerminalTabActionAndSync(.create);
        try self.newTerminal();
        try self.syncTerminalModeTabBar();
        self.needs_redraw = true;
        self.metrics.noteInput(now);
        return true;
    }

    fn requestCycleTerminalTabWithIntent(
        self: *AppState,
        dir: app_modes.ide.TerminalShortcutCycleDirection,
        now: f64,
    ) !bool {
        const moved = self.cycleTerminalTab(dir == .next);
        if (!moved) return false;
        try self.routeTerminalTabActionAndSync(app_terminal_tab_intents.cycleIntentForDirection(dir));
        self.needs_redraw = true;
        self.metrics.noteInput(now);
        return true;
    }

    fn requestFocusTerminalTabWithIntent(
        self: *AppState,
        route: app_modes.ide.TerminalFocusRoute,
        now: f64,
    ) !bool {
        try self.routeTerminalTabActionAndSync(route.intent);
        if (!self.focusTerminalTabByIndex(route.index)) return false;
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
            .request_create = requestCreateTerminalTabFromCtx,
            .request_close = requestCloseActiveTerminalTabFromCtx,
            .request_cycle = requestCycleTerminalTabWithIntentFromCtx,
            .request_focus = requestFocusTerminalTabWithIntentFromCtx,
        };
        return app_terminal_shortcut_runtime.handleIntent(intent, now, @ptrCast(self), hooks);
    }

    fn routeTerminalTabActionAndSync(self: *AppState, tab_action: app_modes.shared.actions.TabAction) !void {
        app_tab_action_apply.applyTerminal(self.allocator, self.app_mode, &self.terminal_mode_adapter, tab_action);
        try self.syncModeAdaptersFromTabBar();
    }

    fn routeActiveWorkspaceTerminalIntentAndSync(
        self: *AppState,
        intent: app_terminal_runtime_intents.Intent,
    ) !bool {
        return app_terminal_runtime_intents.routeForActiveWorkspaceTabAndSync(
            intent,
            &self.terminal_workspace,
            @ptrCast(self),
            routeTerminalTabActionFromCtx,
        );
    }

    fn routeTerminalIntentByTabIdAndSync(
        self: *AppState,
        intent: app_terminal_runtime_intents.Intent,
        tab_id: ?u64,
    ) !bool {
        return app_terminal_runtime_intents.routeByTabIdAndSync(
            intent,
            tab_id,
            @ptrCast(self),
            routeTerminalTabActionFromCtx,
        );
    }

    fn routeEditorTabActionAndSync(self: *AppState, tab_action: app_modes.shared.actions.TabAction) !void {
        app_tab_action_apply.applyEditor(self.allocator, self.app_mode, &self.editor_mode_adapter, tab_action);
        try self.syncModeAdaptersFromTabBar();
    }

    fn setActiveKindAndSyncIfChanged(self: *AppState, kind: app_modes.ide.ActiveMode) !bool {
        if (self.active_kind == kind) return false;
        self.active_kind = kind;
        try self.syncModeAdaptersFromTabBar();
        return true;
    }

    fn activateEditorTabAtCurrentIndex(self: *AppState, now: f64) !void {
        self.active_tab = self.tab_bar.active_index;
        _ = try app_editor_intent_route.routeActivateByIndexAndSync(
            self.active_tab,
            @ptrCast(self),
            routeEditorTabActionFromCtx,
        );
        self.needs_redraw = true;
        self.metrics.noteInput(now);
    }

    fn routeTerminalTabActionFromCtx(raw: *anyopaque, action: app_modes.shared.actions.TabAction) !void {
        const state: *AppState = @ptrCast(@alignCast(raw));
        try state.routeTerminalTabActionAndSync(action);
    }

    fn routeEditorTabActionFromCtx(raw: *anyopaque, action: app_modes.shared.actions.TabAction) !void {
        const state: *AppState = @ptrCast(@alignCast(raw));
        try state.routeEditorTabActionAndSync(action);
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
            try self.activateEditorTabAtCurrentIndex(now);
        }

        const editor_x = layout.editor.x;
        const editor_y = layout.editor.y;
        const in_editor = mouse.x >= editor_x and mouse.x <= editor_x + layout.editor.width and
            mouse.y >= editor_y and mouse.y <= editor_y + layout.editor.height;

        const in_terminal = layout.terminal.height > 0 and mouse.y >= term_y and mouse.y <= term_y + layout.terminal.height;

        if (in_terminal and self.show_terminal) {
            if (try self.setActiveKindAndSyncIfChanged(.terminal)) {
                self.needs_redraw = true;
                self.metrics.noteInput(now);
            }
        } else if (in_editor) {
            if (try self.setActiveKindAndSyncIfChanged(.editor)) {
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
        if (self.terminalTabBarVisible()) {
            _ = self.tab_bar.beginDrag(mouse.x, mouse.y, layout.tab_bar.x, layout.tab_bar.y, layout.tab_bar.width);
        }
        _ = try self.setActiveKindAndSyncIfChanged(.terminal);
        _ = try self.routeActiveWorkspaceTerminalIntentAndSync(.activate);
    }

    fn handleEditorMousePressedRouting(self: *AppState) !void {
        _ = try self.setActiveKindAndSyncIfChanged(.editor);
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
            self.terminalTabBarVisible(),
        );
        if (drag_frame.updated) {
            self.needs_redraw = true;
            self.metrics.noteInput(now);
        }
        if (drag_frame.release) |drag_end| {
            const release_plan = app_modes.ide.terminalTabDragReleasePlan(drag_end);
            if (release_plan.intent) |intent| {
                try self.routeTerminalTabActionAndSync(intent);
            }
            if (release_plan.handle_click) {
                if (self.tab_bar.handleClick(mouse.x, mouse.y, layout.tab_bar.x, layout.tab_bar.y, layout.tab_bar.width)) {
                    _ = try self.routeTerminalIntentByTabIdAndSync(
                        .activate,
                        self.tab_bar.terminalTabIdAtVisual(self.tab_bar.active_index),
                    );
                    if (self.focusTerminalTabByIndex(self.tab_bar.active_index)) {
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
                try self.routeEditorTabActionAndSync(intent);
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
        self.prepareEditorForDisplay(widget.editor);
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
        if (!app_modes.ide.supportsTerminalSurface(self.app_mode) or !self.show_terminal or self.terminalTabCount() == 0) return;

        if (app_modes.ide.shouldUseTerminalWorkspace(self.app_mode)) {
            if (self.terminal_workspace) |*workspace| {
                const polled = try workspace.pollAll(
                    self.activeTerminalArrayIndex(),
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
        const editor = self.activeEditor() orelse return false;
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
        if (!app_modes.ide.supportsEditorSurface(self.app_mode) or self.active_kind != .editor or self.editors.items.len == 0) return;

        const editor_idx = @min(self.active_tab, self.editors.items.len - 1);
        var widget = EditorWidget.initWithCache(self.editors.items[editor_idx], &self.editor_cluster_cache, self.editor_wrap);
        if (!search_panel_consumed_input and try widget.handleInput(shell, layout.editor.height, input_batch)) {
            self.editor_cluster_cache.clear();
            self.needs_redraw = true;
            self.metrics.noteInput(now);
        }
        if (self.perf_mode and self.perf_frames_done < self.perf_frames_total) {
            widget.scrollVisual(shell, self.perf_scroll_delta);
            self.needs_redraw = true;
            self.metrics.noteInput(now);
            self.perf_frames_done +|= 1;
        }
        const scrollbar_blocking = self.handleEditorScrollbarInput(&widget, shell, layout, mouse, input_batch, now);
        self.handleEditorMouseSelectionInput(&widget, shell, layout, mouse, input_batch, scrollbar_blocking, now);
        self.precomputeEditorVisibleCaches(&widget, shell, layout);
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
        if (!app_modes.ide.supportsTerminalSurface(self.app_mode) or !self.show_terminal or self.terminalTabCount() == 0) return;

        try self.pollVisibleTerminalSessions(input_batch);
        if (self.activeTerminalWidget()) |term_widget| {
            const strip = app_modes.ide.terminalStrip(self.app_mode, layout.terminal.height);
            const term_y_draw = layout.terminal.y + strip.offset_y;
            const term_x = layout.terminal.x;
            const term_draw_height = strip.draw_height;
            if (term_widget.updateBlink(now)) {
                self.needs_redraw = true;
            }
            const suppress_terminal_input_for_tab_drag = app_modes.ide.suppressTerminalInputForTabDrag(self.app_mode, self.tab_bar.isDragging());
            const allow_terminal_input = self.active_kind == .terminal and !terminal_close_modal_active and !suppress_terminal_input_for_tab_drag;
            try self.handleTerminalWidgetInput(
                term_widget,
                shell,
                term_x,
                term_y_draw,
                layout.terminal.width,
                term_draw_height,
                allow_terminal_input,
                suppress_terminal_shortcuts,
                input_batch,
                search_panel_consumed_input,
                now,
            );
        }
    }

    fn logMouseDebugClick(self: *AppState, shell: *Shell) void {
        if (!self.mouse_debug) return;
        const r = shell.rendererPtr();
        const raw = r.getMousePosRaw();
        const scaled = r.getMousePos();
        const dpi = r.getDpiScale();
        const screen = r.getScreenSize();
        const render = r.getRenderSize();
        const monitor = r.getMonitorSize();
        const scale_screen = if (render.x > 0) screen.x / render.x else 1.0;
        const scale_render = if (screen.x > 0) render.x / screen.x else 1.0;
        const via_screen = r.getMousePosScaled(scale_screen);
        const via_render = r.getMousePosScaled(scale_render);

        std.debug.print(
            "mouse click raw({d:.1},{d:.1}) scaled({d:.1},{d:.1}) dpi({d:.2},{d:.2}) scr({d:.0}x{d:.0}) ren({d:.0}x{d:.0}) mon({d:.0}x{d:.0}) via_screen({d:.1},{d:.1}) via_render({d:.1},{d:.1}) scale({d:.2})\n",
            .{
                raw.x,
                raw.y,
                scaled.x,
                scaled.y,
                dpi.x,
                dpi.y,
                screen.x,
                screen.y,
                render.x,
                render.y,
                monitor.x,
                monitor.y,
                via_screen.x,
                via_screen.y,
                via_render.x,
                via_render.y,
                shell.mouseScale().x,
            },
        );
    }

    fn postFrameModeSync(self: *AppState) !void {
        if (app_modes.ide.shouldUseTerminalWorkspace(self.app_mode)) {
            try self.syncTerminalModeTabBar();
        }
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
        try self.postFrameModeSync();
    }

    fn handleShortcutAction(
        self: *AppState,
        shell: *Shell,
        kind: input_actions.ActionKind,
        now: f64,
        handled_zoom: *bool,
        zoom_log: Logger,
    ) !bool {
        switch (kind) {
            .new_editor => {
                if (app_modes.ide.canCreateEditorFromShortcut(self.app_mode)) {
                    try self.newEditor();
                    self.needs_redraw = true;
                    self.metrics.noteInput(now);
                    return true;
                }
            },
            .zoom_in => {
                const prev_zoom = shell.userZoomFactor();
                const prev_target = shell.userZoomTargetFactor();
                const changed = shell.queueUserZoom(0.1, now);
                if (changed) self.metrics.noteInput(now);
                if (zoom_log.enabled_file or zoom_log.enabled_console) {
                    zoom_log.logf(
                        "action=zoom_in changed={d} zoom={d:.3}->{d:.3} target={d:.3}->{d:.3} base_font={d:.2} layout_font={d:.2} ui_scale={d:.3} render_scale={d:.3} term_cell={d:.2}x{d:.2}",
                        .{
                            @intFromBool(changed),
                            prev_zoom,
                            shell.userZoomFactor(),
                            prev_target,
                            shell.userZoomTargetFactor(),
                            shell.baseFontSize(),
                            shell.fontSize(),
                            shell.uiScaleFactor(),
                            shell.renderScaleFactor(),
                            shell.terminalCellWidth(),
                            shell.terminalCellHeight(),
                        },
                    );
                }
                handled_zoom.* = true;
            },
            .zoom_out => {
                const prev_zoom = shell.userZoomFactor();
                const prev_target = shell.userZoomTargetFactor();
                const changed = shell.queueUserZoom(-0.1, now);
                if (changed) self.metrics.noteInput(now);
                if (zoom_log.enabled_file or zoom_log.enabled_console) {
                    zoom_log.logf(
                        "action=zoom_out changed={d} zoom={d:.3}->{d:.3} target={d:.3}->{d:.3} base_font={d:.2} layout_font={d:.2} ui_scale={d:.3} render_scale={d:.3} term_cell={d:.2}x{d:.2}",
                        .{
                            @intFromBool(changed),
                            prev_zoom,
                            shell.userZoomFactor(),
                            prev_target,
                            shell.userZoomTargetFactor(),
                            shell.baseFontSize(),
                            shell.fontSize(),
                            shell.uiScaleFactor(),
                            shell.renderScaleFactor(),
                            shell.terminalCellWidth(),
                            shell.terminalCellHeight(),
                        },
                    );
                }
                handled_zoom.* = true;
            },
            .zoom_reset => {
                const prev_zoom = shell.userZoomFactor();
                const prev_target = shell.userZoomTargetFactor();
                const changed = shell.resetUserZoomTarget(now);
                if (changed) self.metrics.noteInput(now);
                if (zoom_log.enabled_file or zoom_log.enabled_console) {
                    zoom_log.logf(
                        "action=zoom_reset changed={d} zoom={d:.3}->{d:.3} target={d:.3}->{d:.3} base_font={d:.2} layout_font={d:.2} ui_scale={d:.3} render_scale={d:.3} term_cell={d:.2}x{d:.2}",
                        .{
                            @intFromBool(changed),
                            prev_zoom,
                            shell.userZoomFactor(),
                            prev_target,
                            shell.userZoomTargetFactor(),
                            shell.baseFontSize(),
                            shell.fontSize(),
                            shell.uiScaleFactor(),
                            shell.renderScaleFactor(),
                            shell.terminalCellWidth(),
                            shell.terminalCellHeight(),
                        },
                    );
                }
                handled_zoom.* = true;
            },
            .toggle_terminal => {
                if (app_modes.ide.canToggleTerminal(self.app_mode)) {
                    if (self.show_terminal) {
                        self.show_terminal = false;
                    } else {
                        if (self.terminals.items.len == 0) {
                            try self.newTerminal();
                        }
                        self.show_terminal = true;
                    }
                    self.needs_redraw = true;
                    self.metrics.noteInput(now);
                    return true;
                }
            },
            else => {},
        }

        if (app_modes.ide.terminalShortcutIntentForAction(kind)) |intent| {
            if (try self.handleTerminalShortcutIntent(intent, now)) {
                return true;
            }
        }
        return false;
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
        if (!input_batch.mousePressed(.left)) return;
        switch (app_modes.ide.mouseClickRoute(self.app_mode)) {
            .ide => try self.handleIdeMousePressedRouting(layout, mouse, term_y, now),
            .terminal => try self.handleTerminalMousePressedRouting(layout, mouse),
            .editor => try self.handleEditorMousePressedRouting(),
        }
        self.logMouseDebugClick(shell);
    }

    const PreInputShortcutResult = struct {
        suppress_terminal_shortcuts: bool,
        terminal_close_modal_active: bool,
        handled_shortcut: bool,
        consumed: bool,
    };

    fn handleReloadConfigShortcutFrame(self: *AppState) bool {
        var handled = false;
        for (self.input_router.actionsSlice()) |action| {
            if (action.kind == .reload_config) {
                self.reloadConfig() catch {
                    self.showConfigReloadNotice(false);
                    handled = true;
                    continue;
                };
                self.showConfigReloadNotice(true);
                handled = true;
            }
        }
        return handled;
    }

    fn collectSuppressTerminalShortcutsForFocus(
        self: *AppState,
        focus: input_actions.FocusKind,
    ) bool {
        if (focus != .terminal) return false;
        var suppress = false;
        for (self.input_router.actionsSlice()) |action| {
            switch (action.kind) {
                .copy, .paste => suppress = true,
                else => {},
            }
        }
        return suppress;
    }

    fn handleTerminalClipboardShortcutsFrame(
        self: *AppState,
        shell: *Shell,
        input_batch: *shared_types.input.InputBatch,
        now: f64,
    ) !bool {
        if (self.activeTerminalWidget()) |term_widget| {
            if (input_batch.events.items.len > 0) {
                term_widget.noteInput(now);
            }
            var handled = false;
            for (self.input_router.actionsSlice()) |action| {
                switch (action.kind) {
                    .copy => {
                        if (term_widget.copySelectionToClipboard(shell)) {
                            handled = true;
                        }
                    },
                    .paste => {
                        if (term_widget.pasteClipboardFromSystem(shell)) {
                            handled = true;
                            self.needs_redraw = true;
                        }
                    },
                    .terminal_scrollback_pager => {
                        if (self.activeTerminalSession()) |term| {
                            if (try terminal_scrollback_pager.openInPager(self.allocator, term_widget, term)) {
                                handled = true;
                            }
                        }
                    },
                    else => {},
                }
            }
            return handled;
        }
        return false;
    }

    fn handleEditorShortcutActionsFrame(
        self: *AppState,
        shell: *Shell,
        action_layout: layout_types.WidgetLayout,
    ) !bool {
        if (self.editors.items.len == 0) return false;
        const editor_idx = @min(self.active_tab, self.editors.items.len - 1);
        const editor = self.editors.items[editor_idx];
        var editor_widget = EditorWidget.initWithCache(editor, &self.editor_cluster_cache, self.editor_wrap);
        var handled = false;

        for (self.input_router.actionsSlice()) |action| {
            switch (action.kind) {
                .copy => {
                    if (try editor.selectionTextAlloc()) |text| {
                        defer self.allocator.free(text);
                        const buf = try self.allocator.alloc(u8, text.len + 1);
                        defer self.allocator.free(buf);
                        std.mem.copyForwards(u8, buf[0..text.len], text);
                        buf[text.len] = 0;
                        const cstr: [*:0]const u8 = @ptrCast(buf.ptr);
                        shell.setClipboardText(cstr);
                        handled = true;
                    }
                },
                .cut => {
                    if (try editor.selectionTextAlloc()) |text| {
                        defer self.allocator.free(text);
                        const buf = try self.allocator.alloc(u8, text.len + 1);
                        defer self.allocator.free(buf);
                        std.mem.copyForwards(u8, buf[0..text.len], text);
                        buf[text.len] = 0;
                        const cstr: [*:0]const u8 = @ptrCast(buf.ptr);
                        shell.setClipboardText(cstr);
                        try editor.deleteSelection();
                        self.needs_redraw = true;
                        handled = true;
                    }
                },
                .paste => {
                    if (shell.getClipboardText()) |clip| {
                        try editor.insertText(clip);
                        self.needs_redraw = true;
                        handled = true;
                    }
                },
                .save => {
                    try editor.save();
                    self.needs_redraw = true;
                    handled = true;
                },
                .undo => {
                    _ = try editor.undo();
                    self.needs_redraw = true;
                    handled = true;
                },
                .redo => {
                    _ = try editor.redo();
                    self.needs_redraw = true;
                    handled = true;
                },
                .editor_add_caret_up => {
                    if (try app_editor_actions.applyCaretEditorAction(editor, action.kind)) {
                        self.needs_redraw = true;
                        handled = true;
                    }
                },
                .editor_add_caret_down => {
                    if (try app_editor_actions.applyCaretEditorAction(editor, action.kind)) {
                        self.needs_redraw = true;
                        handled = true;
                    }
                },
                .editor_move_word_left,
                .editor_move_word_right,
                .editor_extend_left,
                .editor_extend_right,
                .editor_extend_line_start,
                .editor_extend_line_end,
                .editor_extend_word_left,
                .editor_extend_word_right,
                => {
                    if (app_editor_actions.applyDirectEditorAction(editor, action.kind)) {
                        self.needs_redraw = true;
                        handled = true;
                    }
                },
                .editor_move_large_up, .editor_move_large_down => {
                    const delta = app_editor_actions.visualMoveDeltaForAction(action.kind, self.editor_large_jump_rows).?;
                    const Ctx = struct {
                        widget: *EditorWidget,
                        shell: *Shell,
                    };
                    var ctx = Ctx{ .widget = &editor_widget, .shell = shell };
                    const moved = app_editor_actions.applyRepeatedVisualDelta(
                        delta,
                        @ptrCast(&ctx),
                        struct {
                            fn step(raw: *anyopaque, dir: i32) bool {
                                const payload: *Ctx = @ptrCast(@alignCast(raw));
                                return payload.widget.moveCursorVisual(payload.shell, dir);
                            }
                        }.step,
                    );
                    if (moved) {
                        editor_widget.ensureCursorVisible(shell, action_layout.editor.height);
                        self.needs_redraw = true;
                        handled = true;
                    }
                },
                .editor_extend_up, .editor_extend_down, .editor_extend_large_up, .editor_extend_large_down => {
                    const delta = app_editor_actions.visualExtendDeltaForAction(action.kind, self.editor_large_jump_rows).?;
                    const Ctx = struct {
                        widget: *EditorWidget,
                        shell: *Shell,
                    };
                    var ctx = Ctx{ .widget = &editor_widget, .shell = shell };
                    const extended = app_editor_actions.applyRepeatedVisualDelta(
                        delta,
                        @ptrCast(&ctx),
                        struct {
                            fn step(raw: *anyopaque, dir: i32) bool {
                                const payload: *Ctx = @ptrCast(@alignCast(raw));
                                return payload.widget.extendSelectionVisual(payload.shell, dir);
                            }
                        }.step,
                    );
                    if (extended) {
                        editor_widget.ensureCursorVisible(shell, action_layout.editor.height);
                        self.needs_redraw = true;
                        handled = true;
                    }
                },
                .editor_search_open => {
                    try app_search_panel_state.openPanel(
                        self.allocator,
                        &self.search_panel.active,
                        &self.search_panel.query,
                        editor,
                    );
                    self.needs_redraw = true;
                    handled = true;
                },
                .editor_search_next => {
                    if (editor.activateNextSearchMatch()) {
                        self.needs_redraw = true;
                        handled = true;
                    }
                },
                .editor_search_prev => {
                    if (editor.activatePrevSearchMatch()) {
                        self.needs_redraw = true;
                        handled = true;
                    }
                },
                else => {},
            }
        }
        return handled;
    }

    fn handlePreInputShortcutFrame(
        self: *AppState,
        shell: *Shell,
        r: anytype,
        input_batch: *shared_types.input.InputBatch,
        focus: input_actions.FocusKind,
        now: f64,
    ) !PreInputShortcutResult {
        var handled_shortcut = self.handleReloadConfigShortcutFrame();
        const live_layout = self.computeLayout(@floatFromInt(r.width), @floatFromInt(r.height));
        if (try self.handleTerminalCloseConfirmInput(input_batch, live_layout, now)) {
            return .{
                .suppress_terminal_shortcuts = false,
                .terminal_close_modal_active = self.terminalCloseConfirmActive(),
                .handled_shortcut = handled_shortcut,
                .consumed = true,
            };
        }

        const terminal_close_modal_active = self.terminalCloseConfirmActive();
        const suppress_terminal_shortcuts = self.collectSuppressTerminalShortcutsForFocus(focus);

        if (!terminal_close_modal_active and focus == .terminal and app_modes.ide.hasTerminalInputScope(self.app_mode, self.show_terminal) and self.terminalTabCount() > 0) {
            if (try self.handleTerminalClipboardShortcutsFrame(shell, input_batch, now)) {
                handled_shortcut = true;
            }
        }

        if (focus == .editor) {
            const action_layout = self.computeLayout(@floatFromInt(r.width), @floatFromInt(r.height));
            if (try self.handleEditorShortcutActionsFrame(shell, action_layout)) {
                handled_shortcut = true;
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
            try self.syncTerminalModeTabBar();
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
        _ = self.terminalCloseConfirmActive();
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
        if (app_modes.ide.canDriveTerminalTabDrag(self.app_mode)) {
            try self.handleTerminalTabDragInput(input_batch, layout, mouse, now);
        }
        if (app_modes.ide.isIde(self.app_mode)) {
            try self.handleIdeTabDragInput(input_batch, layout, mouse, now);
        }
    }

    fn handleInputActionsFrame(
        self: *AppState,
        shell: *Shell,
        now: f64,
    ) !bool {
        var handled_zoom = false;
        const zoom_log = app_logger.logger("ui.zoom.shortcut");
        for (self.input_router.actionsSlice()) |action| {
            if (try self.handleShortcutAction(shell, action.kind, now, &handled_zoom, zoom_log)) {
                return true;
            }
        }
        if (handled_zoom) {
            return true;
        }
        return false;
    }

    fn handlePointerActivityFrame(
        self: *AppState,
        input_batch: *shared_types.input.InputBatch,
        layout: layout_types.WidgetLayout,
        mouse: shared_types.input.MousePos,
        now: f64,
    ) void {
        const mouse_down = input_batch.mouseDown(.left);
        const mouse_moved = mouse.x != self.last_mouse_pos.x or mouse.y != self.last_mouse_pos.y;
        const wheel = input_batch.scroll.y;
        const mouse_pressed = input_batch.mousePressed(.left) or input_batch.mousePressed(.right);
        const has_mouse_action = mouse_pressed or wheel != 0 or mouse_down;

        const terminal_visible = self.show_terminal and layout.terminal.height > 0;
        const term_y = layout.terminal.y;
        const in_terminal_area = terminal_visible and mouse.y >= term_y;
        const ctrl_down = input_batch.mods.ctrl;

        if (has_mouse_action) {
            self.needs_redraw = true;
            self.metrics.noteInput(now);
        } else if (mouse_moved) {
            if (!in_terminal_area) {
                const interval: f64 = 1.0 / 60.0;
                if (now - self.last_mouse_redraw_time >= interval) {
                    self.needs_redraw = true;
                    self.last_mouse_redraw_time = now;
                }
            }
        }
        if (in_terminal_area and (ctrl_down != self.last_ctrl_down or (ctrl_down and mouse_moved))) {
            const interval: f64 = 1.0 / 60.0;
            if (now - self.last_mouse_redraw_time >= interval) {
                self.needs_redraw = true;
                self.last_mouse_redraw_time = now;
            }
        }
        if (mouse_moved) {
            self.last_mouse_pos = .{ .x = mouse.x, .y = mouse.y };
        }
        self.last_ctrl_down = ctrl_down;
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
        if (!app_modes.ide.canResizeTerminalSplit(self.app_mode, self.show_terminal)) return;

        const mouse = input_batch.mouse_pos;
        const mouse_down = input_batch.mouseDown(.left);
        const separator_y = layout.terminal.y;
        const hit_zone: f32 = 6;
        const over_separator = mouse.y >= separator_y - hit_zone and mouse.y <= separator_y + hit_zone;
        const max_terminal_h = @max(0, height - self.options_bar.height - self.tab_bar.height - self.status_bar.height);

        if (!self.resizing_terminal and mouse_down and over_separator) {
            self.resizing_terminal = true;
            self.resize_start_y = mouse.y;
            self.resize_start_height = layout.terminal.height;
            self.needs_redraw = true;
            self.metrics.noteInput(now);
        } else if (self.resizing_terminal and mouse_down) {
            const delta = mouse.y - self.resize_start_y;
            const min_terminal_h: f32 = 80;
            const new_height = @max(min_terminal_h, @min(self.resize_start_height - delta, max_terminal_h));
            if (new_height != self.terminal_height) {
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
                self.needs_redraw = true;
                self.metrics.noteInput(now);
            }
        } else if (self.resizing_terminal and !mouse_down) {
            self.resizing_terminal = false;
        }
    }

    fn handleWindowResizeEventFrame(self: *AppState, shell: *Shell, now: f64) !void {
        _ = now;
        if (!app_shell.isWindowResized()) return;
        _ = shell.refreshWindowMetrics("window-event");
        if (try shell.refreshUiScale()) {
            self.applyUiScale();
        }
        self.window_resize_pending = true;
        self.window_resize_last_time = app_shell.getTime();
        self.needs_redraw = true;
    }

    fn handleCursorBlinkArmingFrame(self: *AppState, now: f64) void {
        if (self.activeTerminalWidget()) |term_widget| {
            const cache = term_widget.session.renderCache();
            const blink_armed = cache.cursor_visible and cache.cursor_style.blink and cache.scroll_offset == 0;
            if (blink_armed != self.last_cursor_blink_armed) {
                self.last_cursor_blink_armed = blink_armed;
                const cursor_log = app_logger.logger("terminal.cursor");
                if (cursor_log.enabled_file or cursor_log.enabled_console) {
                    cursor_log.logf(
                        "cursor blink armed={any} visible={any} blink={any} scroll_offset={d}",
                        .{ blink_armed, cache.cursor_visible, cache.cursor_style.blink, cache.scroll_offset },
                    );
                }
            }
            if (blink_armed) {
                const period: f64 = 0.5;
                const phase = @mod(now, period * 2.0);
                const blink_on = phase < period;
                if (blink_on != self.last_cursor_blink_on) {
                    self.last_cursor_blink_on = blink_on;
                    self.needs_redraw = true;
                }
            }
        }
    }

    fn handleDeferredTerminalResizeFrame(
        self: *AppState,
        shell: *Shell,
        layout: layout_types.WidgetLayout,
        now: f64,
    ) !void {
        if (!self.window_resize_pending or (now - self.window_resize_last_time) < 0.12) return;

        self.window_resize_pending = false;
        if (self.terminalTabCount() > 0) {
            const effective_height = app_modes.ide.terminalEffectiveHeightForSizing(
                self.app_mode,
                self.show_terminal,
                layout.terminal.height,
                self.terminal_height,
            );
            const grid = app_terminal_grid.compute(
                layout.terminal.width,
                effective_height,
                shell.terminalCellWidth(),
                shell.terminalCellHeight(),
                1,
                1,
            );
            const cols: u16 = grid.cols;
            const rows: u16 = grid.rows;
            if (app_modes.ide.shouldUseTerminalWorkspace(self.app_mode)) {
                if (self.terminal_workspace) |*workspace| {
                    try app_terminal_resize.resizeWorkspaceWithShellCellSize(workspace, shell, rows, cols);
                }
            } else {
                const term = self.terminals.items[0];
                try app_terminal_resize.resizeSessionWithShellCellSize(term, shell, rows, cols);
            }
        }
        self.needs_redraw = true;
    }

    const PostPreInputFrameResult = struct {
        layout: layout_types.WidgetLayout,
        mouse: shared_types.input.MousePos,
        term_y: f32,
    };

    const UpdatePreludeResult = struct {
        now: f64,
        suppress_terminal_shortcuts: bool,
        terminal_close_modal_active: bool,
    };

    fn handlePostPreInputFrame(
        self: *AppState,
        shell: *Shell,
        input_batch: *shared_types.input.InputBatch,
        now: f64,
    ) !PostPreInputFrameResult {
        if (try shell.applyPendingZoom(now)) {
            self.applyUiScale();
            try self.refreshTerminalSizing();
            self.needs_redraw = true;
            self.metrics.noteInput(now);
        }
        try self.handleWindowResizeEventFrame(shell, now);

        const width = @as(f32, @floatFromInt(shell.width()));
        const height = @as(f32, @floatFromInt(shell.height()));
        const layout = self.computeLayout(width, height);

        self.handleCursorBlinkArmingFrame(now);
        try self.handleDeferredTerminalResizeFrame(shell, layout, now);

        const mouse = input_batch.mouse_pos;
        const term_y = layout.terminal.y;
        self.handlePointerActivityFrame(input_batch, layout, mouse, now);
        try self.handleTerminalSplitResizeFrame(shell, input_batch, layout, layout.terminal.width, height, now);

        return .{
            .layout = layout,
            .mouse = mouse,
            .term_y = term_y,
        };
    }

    fn handleInteractiveFrame(
        self: *AppState,
        shell: *Shell,
        frame: PostPreInputFrameResult,
        input_batch: *shared_types.input.InputBatch,
        suppress_terminal_shortcuts: bool,
        terminal_close_modal_active: bool,
        now: f64,
    ) !void {
        if (try self.handleInputActionsFrame(shell, now)) {
            return;
        }

        try self.handleMousePressedFrame(shell, frame.layout, frame.mouse, frame.term_y, input_batch, now);
        try self.handleTabDragFrame(input_batch, frame.layout, frame.mouse, now);

        try self.handleActiveViewFrame(
            shell,
            frame.layout,
            frame.mouse,
            input_batch,
            suppress_terminal_shortcuts,
            terminal_close_modal_active,
            now,
        );
    }

    fn handleUpdatePreludeFrame(
        self: *AppState,
        shell: *Shell,
        input_batch: *shared_types.input.InputBatch,
    ) !?UpdatePreludeResult {
        const r = shell.rendererPtr();
        self.last_input = input_batch.snapshot();

        if (self.handleFontSampleFrame(r, input_batch)) return null;
        try self.handleWidgetInputFrame();
        const now = app_shell.getTime();
        self.tickConfigReloadNoticeFrame(now);
        const focus = self.routeInputForCurrentFocus(input_batch);
        const pre_input = try self.handlePreInputShortcutFrame(shell, r, input_batch, focus, now);
        if (pre_input.consumed) return null;
        if (pre_input.handled_shortcut) {
            self.metrics.noteInput(now);
        }

        return .{
            .now = now,
            .suppress_terminal_shortcuts = pre_input.suppress_terminal_shortcuts,
            .terminal_close_modal_active = pre_input.terminal_close_modal_active,
        };
    }

    fn logModeAdapterParity(self: *AppState) void {
        const log = app_logger.logger("app.mode.parity");
        if (!log.enabled_file and !log.enabled_console) return;

        const editor_snap = self.editor_mode_adapter.asContract().snapshot(self.allocator) catch return;
        const terminal_snap = self.terminal_mode_adapter.asContract().snapshot(self.allocator) catch return;
        var projections = app_modes.ide.buildTabProjections(self.allocator, self.tab_bar.tabs.items) catch return;
        defer projections.deinit(self.allocator);

        const active_projection = app_modes.ide.activeProjectionForTabBar(
            self.active_kind,
            self.tab_bar.tabs.items,
            self.tab_bar.active_index,
        );

        const editor_parity = app_modes.ide.evaluateKind(
            projections.items,
            .editor,
            active_projection,
            editor_snap.tabs,
            editor_snap.active_tab,
        );
        const terminal_parity = app_modes.ide.evaluateKind(
            projections.items,
            .terminal,
            active_projection,
            terminal_snap.tabs,
            terminal_snap.active_tab,
        );

        if (editor_parity.expected_count != editor_parity.actual_count or
            editor_parity.expected_active != editor_parity.actual_active or
            editor_parity.mismatch != null or
            terminal_parity.expected_count != terminal_parity.actual_count or
            terminal_parity.expected_active != terminal_parity.actual_active or
            terminal_parity.mismatch != null)
        {
            log.logf(
                "adapter parity mismatch editor_count={d}/{d} editor_active={?d}/{?d} editor_first_mismatch_idx={?d} editor_first_mismatch_id={?d}/{?d} editor_first_mismatch_title={s}/{s} terminal_count={d}/{d} terminal_active={?d}/{?d} terminal_first_mismatch_idx={?d} terminal_first_mismatch_id={?d}/{?d} terminal_first_mismatch_title={s}/{s}",
                .{
                    editor_parity.actual_count,
                    editor_parity.expected_count,
                    editor_parity.actual_active,
                    editor_parity.expected_active,
                    if (editor_parity.mismatch) |m| m.index else null,
                    if (editor_parity.mismatch) |m| m.actual_id else null,
                    if (editor_parity.mismatch) |m| m.expected_id else null,
                    if (editor_parity.mismatch) |m| m.actual_title else "<ok>",
                    if (editor_parity.mismatch) |m| m.expected_title else "<ok>",
                    terminal_parity.actual_count,
                    terminal_parity.expected_count,
                    terminal_parity.actual_active,
                    terminal_parity.expected_active,
                    if (terminal_parity.mismatch) |m| m.index else null,
                    if (terminal_parity.mismatch) |m| m.actual_id else null,
                    if (terminal_parity.mismatch) |m| m.expected_id else null,
                    if (terminal_parity.mismatch) |m| m.actual_title else "<ok>",
                    if (terminal_parity.mismatch) |m| m.expected_title else "<ok>",
                },
            );
        }
    }

    fn terminalCloseConfirmActive(self: *AppState) bool {
        const active_tab: ?u64 = if (self.terminal_workspace) |*workspace| workspace.activeTabId() else null;
        self.terminal_close_confirm_tab = app_terminal_close_confirm_state.reconcilePending(
            self.terminal_close_confirm_tab,
            active_tab,
        );
        return self.terminal_close_confirm_tab != null;
    }

    fn clearTerminalCloseConfirm(self: *AppState) void {
        self.terminal_close_confirm_tab = null;
    }

    fn requestConfirmTerminalCloseFromModal(self: *AppState, now: f64) !bool {
        _ = try self.routeActiveWorkspaceTerminalIntentAndSync(.close);
        if (try self.closeActiveTerminalTab()) {
            self.needs_redraw = true;
        }
        self.metrics.noteInput(now);
        return true;
    }

    fn requestCancelTerminalCloseFromModal(self: *AppState, now: f64) bool {
        self.clearTerminalCloseConfirm();
        self.needs_redraw = true;
        self.metrics.noteInput(now);
        return true;
    }

    fn applyTerminalCloseConfirmDecision(
        self: *AppState,
        decision: app_modes.ide.TerminalCloseConfirmDecision,
        now: f64,
    ) !bool {
        const hooks: app_terminal_close_confirm_runtime.RuntimeHooks = .{
            .confirm = requestConfirmTerminalCloseFromModalFromCtx,
            .cancel = requestCancelTerminalCloseFromModalFromCtx,
        };
        return app_terminal_close_confirm_runtime.applyDecision(decision, now, @ptrCast(self), hooks);
    }

    fn requestCreateTerminalTabFromCtx(raw: *anyopaque, at: f64) !bool {
        const state: *AppState = @ptrCast(@alignCast(raw));
        return state.requestCreateTerminalTab(at);
    }

    fn requestCloseActiveTerminalTabFromCtx(raw: *anyopaque, at: f64) !bool {
        const state: *AppState = @ptrCast(@alignCast(raw));
        return state.requestCloseActiveTerminalTab(at);
    }

    fn requestCycleTerminalTabWithIntentFromCtx(
        raw: *anyopaque,
        dir: app_modes.ide.TerminalShortcutCycleDirection,
        at: f64,
    ) !bool {
        const state: *AppState = @ptrCast(@alignCast(raw));
        return state.requestCycleTerminalTabWithIntent(dir, at);
    }

    fn requestFocusTerminalTabWithIntentFromCtx(
        raw: *anyopaque,
        route: app_modes.ide.TerminalFocusRoute,
        at: f64,
    ) !bool {
        const state: *AppState = @ptrCast(@alignCast(raw));
        return state.requestFocusTerminalTabWithIntent(route, at);
    }

    fn requestConfirmTerminalCloseFromModalFromCtx(raw: *anyopaque, at: f64) !bool {
        const state: *AppState = @ptrCast(@alignCast(raw));
        return state.requestConfirmTerminalCloseFromModal(at);
    }

    fn requestCancelTerminalCloseFromModalFromCtx(raw: *anyopaque, at: f64) !bool {
        const state: *AppState = @ptrCast(@alignCast(raw));
        return state.requestCancelTerminalCloseFromModal(at);
    }

    fn handleTerminalCloseConfirmInput(
        self: *AppState,
        input_batch: *shared_types.input.InputBatch,
        layout: layout_types.WidgetLayout,
        now: f64,
    ) !bool {
        if (!self.terminalCloseConfirmActive()) return false;

        const modal = app_modes.ide.terminalCloseConfirmModalLayout(layout, self.shell.uiScaleFactor());
        const decision = app_modes.ide.decideTerminalCloseConfirmInput(
            self.input_router.actionsSlice(),
            input_batch,
            modal,
        );
        return self.applyTerminalCloseConfirmDecision(decision, now);
    }

    fn focusTerminalTabByIndex(self: *AppState, index: usize) bool {
        const changed = app_terminal_tab_ops.focusByVisualIndex(
            self.app_mode,
            &self.terminal_workspace,
            &self.tab_bar,
            index,
        );
        if (!changed) return false;
        self.clearTerminalCloseConfirm();
        if (self.activeTerminalWidget()) |widget| {
            widget.invalidateTextureCache();
        }
        return true;
    }

    fn cycleTerminalTab(self: *AppState, next: bool) bool {
        const changed = app_terminal_tab_ops.cycle(
            self.app_mode,
            &self.terminal_workspace,
            &self.tab_bar,
            next,
        );
        if (!changed) return false;
        self.clearTerminalCloseConfirm();
        if (self.activeTerminalWidget()) |widget| {
            widget.invalidateTextureCache();
        }
        return true;
    }

    fn closeActiveTerminalTab(self: *AppState) !bool {
        if (!app_modes.ide.shouldUseTerminalWorkspace(self.app_mode)) return false;
        if (self.terminal_workspace) |*workspace| {
            if (workspace.tabCount() == 0) return false;
            if (workspace.activeTabId()) |active_tab_id| {
                if (workspace.activeSession()) |active_session| {
                    if (app_terminal_close_confirm_state.shouldArmCloseConfirm(
                        self.terminal_close_confirm_tab,
                        active_tab_id,
                        active_session.shouldConfirmClose(),
                    )) {
                        self.terminal_close_confirm_tab = active_tab_id;
                        self.needs_redraw = true;
                        return false;
                    }
                }
            }
            const active_idx = workspace.activeIndex();
            if (active_idx < self.terminal_widgets.items.len) {
                self.terminal_widgets.items[active_idx].deinit();
                _ = self.terminal_widgets.orderedRemove(active_idx);
            }
            if (!workspace.closeActiveTab()) return false;
            self.clearTerminalCloseConfirm();
            if (workspace.tabCount() == 0) {
                self.shell.requestClose();
            } else {
                try self.syncTerminalModeTabBar();
                if (self.activeTerminalWidget()) |widget| {
                    widget.invalidateTextureCache();
                }
            }
            return true;
        }
        return false;
    }

    pub fn newTerminal(self: *AppState) !void {
        // Calculate terminal size based on UI
        const shell = self.shell;
        const width = @as(f32, @floatFromInt(shell.width()));
        const height = @as(f32, @floatFromInt(shell.height()));
        const layout = self.computeLayout(width, height);
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
                try self.syncTerminalModeTabBar();
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

    fn applyUiScale(self: *AppState) void {
        const scale = self.shell.uiScaleFactor();
        self.options_bar.height = 26 * scale;
        self.tab_bar.height = 28 * scale;
        self.tab_bar.tab_width = 150 * scale;
        self.tab_bar.tab_spacing = @max(1, scale);
        self.status_bar.height = 24 * scale;
        self.side_nav.width = 52 * scale;
        self.applyCurrentTabBarWidthMode();
    }

    fn showConfigReloadNotice(self: *AppState, success: bool) void {
        const notice = app_config_reload_notice_state.arm(app_shell.getTime(), success);
        self.config_reload_notice_success = notice.success;
        self.config_reload_notice_until = notice.until;
        self.needs_redraw = true;
    }

    fn refreshTerminalSizing(self: *AppState) !void {
        if (self.terminalTabCount() == 0) return;
        const shell = self.shell;
        const width = @as(f32, @floatFromInt(shell.width()));
        const height = @as(f32, @floatFromInt(shell.height()));
        const layout = self.computeLayout(width, height);
        const effective_height = app_modes.ide.terminalEffectiveHeightForSizing(
            self.app_mode,
            self.show_terminal,
            layout.terminal.height,
            self.terminal_height,
        );
        const grid = app_terminal_grid.compute(
            layout.terminal.width,
            effective_height,
            shell.terminalCellWidth(),
            shell.terminalCellHeight(),
            1,
            1,
        );
        const cols: u16 = grid.cols;
        const rows: u16 = grid.rows;
        if (app_modes.ide.shouldUseTerminalWorkspace(self.app_mode)) {
            if (self.terminal_workspace) |*workspace| {
                try app_terminal_resize.resizeWorkspaceWithShellCellSize(workspace, shell, rows, cols);
            }
        } else {
            try app_terminal_resize.resizeSessionsWithShellCellSize(self.terminals.items, shell, rows, cols);
        }
    }

    fn computeLayout(self: *AppState, width: f32, height: f32) layout_types.WidgetLayout {
        return app_modes.ide.computeLayoutForMode(
            self.app_mode,
            width,
            height,
            self.options_bar.height,
            self.tab_bar.height,
            self.side_nav.width,
            self.status_bar.height,
            self.terminal_height,
            self.show_terminal,
            self.terminalTabBarVisible(),
        );
    }

    fn initializeRunModeState(self: *AppState) !void {
        if (app_modes.ide.shouldUseTerminalWorkspace(self.app_mode)) {
            if (self.terminalTabCount() == 0) {
                try self.newTerminal();
            }
            try self.syncTerminalModeTabBar();
            return;
        }

        if (app_modes.ide.isFontSample(self.app_mode)) {
            return;
        }

        if (self.perf_mode and self.perf_file_path != null) {
            try self.openFile(self.perf_file_path.?);
            return;
        }

        try self.newEditor();

        if (self.editors.items.len > 0) {
            const editor = self.editors.items[0];
            try app_editor_seed.seedDefaultWelcomeBuffer(editor);
        }
    }

    const RunFrameSetup = struct {
        input_batch: shared_types.input.InputBatch,
        poll_ms: f64,
        build_ms: f64,
    };

    fn prepareRunFrame(self: *AppState) !?RunFrameSetup {
        const poll_start = app_shell.getTime();
        app_shell.pollInputEvents();
        const poll_end = app_shell.getTime();
        if (self.shell.shouldClose()) return null;
        if (app_signals.requested()) {
            self.shell.requestClose();
            return null;
        }

        const build_start = app_shell.getTime();
        const input_batch = input_builder.buildInputBatch(self.allocator, self.shell);
        const build_end = app_shell.getTime();

        self.frame_id +|= 1;
        if (!app_modes.ide.shouldUseTerminalWorkspace(self.app_mode)) {
            self.editor_cluster_cache.beginFrame(self.frame_id);
        }

        self.metrics.beginFrame(app_shell.getTime());

        return .{
            .input_batch = input_batch,
            .poll_ms = (poll_end - poll_start) * 1000.0,
            .build_ms = (build_end - build_start) * 1000.0,
        };
    }

    fn runOneFrame(self: *AppState) !bool {
        var frame = (try self.prepareRunFrame()) orelse return false;
        defer frame.input_batch.deinit();

        const update_start = app_shell.getTime();
        try self.update(&frame.input_batch);
        const update_end = app_shell.getTime();
        const update_ms = (update_end - update_start) * 1000.0;
        self.handleFrameRenderAndIdle(&frame.input_batch, frame.poll_ms, frame.build_ms, update_ms);

        if (self.perf_mode and self.perf_frames_done >= self.perf_frames_total and self.perf_frames_total > 0) {
            self.perf_logger.logf("perf complete frames={d}", .{self.perf_frames_done});
            return false;
        }
        return true;
    }

    fn runMainLoop(self: *AppState) !void {
        while (!self.shell.shouldClose()) {
            if (!try self.runOneFrame()) break;
        }
    }

    pub fn run(self: *AppState) !void {
        try self.initializeRunModeState();
        try self.runMainLoop();
    }

    fn handleFrameRenderAndIdle(
        self: *AppState,
        input_batch: *shared_types.input.InputBatch,
        poll_ms: f64,
        build_ms: f64,
        update_ms: f64,
    ) void {
        var draw_ms: f64 = 0.0;

        if (self.needs_redraw) {
            const draw_start = app_shell.getTime();
            self.draw();
            const draw_end = app_shell.getTime();
            draw_ms = (draw_end - draw_start) * 1000.0;
            self.metrics.recordDraw(draw_start, draw_end);
            if (self.perf_mode and self.perf_frames_done > 0) {
                const draw_ms_perf = (draw_end - draw_start) * 1000.0;
                const editor_idx = if (self.editors.items.len > 0) @min(self.active_tab, self.editors.items.len - 1) else 0;
                if (self.editors.items.len > 0) {
                    const editor = self.editors.items[editor_idx];
                    self.perf_logger.logf(
                        "frame={d} draw_ms={d:.2} scroll_line={d} scroll_row_offset={d} scroll_col={d}",
                        .{ self.perf_frames_done, draw_ms_perf, editor.scroll_line, editor.scroll_row_offset, editor.scroll_col },
                    );
                } else {
                    self.perf_logger.logf("frame={d} draw_ms={d:.2}", .{ self.perf_frames_done, draw_ms_perf });
                }
            }
            self.maybeLogMetrics(draw_end);
            self.needs_redraw = false;
            self.idle_frames = 0;
            if (self.input_latency_logger.enabled_file or self.input_latency_logger.enabled_console) {
                if (input_batch.events.items.len > 0) {
                    const total_ms = poll_ms + build_ms + update_ms + draw_ms;
                    if (total_ms >= 1.0) {
                        self.input_latency_logger.logf(
                            "poll_ms={d:.2} build_ms={d:.2} update_ms={d:.2} draw_ms={d:.2}",
                            .{ poll_ms, build_ms, update_ms, draw_ms },
                        );
                    }
                }
            }
            return;
        }

        self.idle_frames +|= 1;
        if (self.input_latency_logger.enabled_file or self.input_latency_logger.enabled_console) {
            if (input_batch.events.items.len > 0) {
                const total_ms = poll_ms + build_ms + update_ms;
                if (total_ms >= 1.0) {
                    self.input_latency_logger.logf(
                        "poll_ms={d:.2} build_ms={d:.2} update_ms={d:.2} draw_ms=0.00",
                        .{ poll_ms, build_ms, update_ms },
                    );
                }
            }
        }

        const uptime = app_shell.getTime();
        const sleep_ms: f64 = if (uptime < 3.0)
            0.016
        else if (self.idle_frames < 10)
            0.016
        else if (self.idle_frames < 60)
            0.033
        else
            0.100;

        app_shell.waitTime(sleep_ms);
        self.maybeLogMetrics(app_shell.getTime());
    }

    fn maybeLogMetrics(self: *AppState, now: f64) void {
        if (!self.metrics_logger.enabled_file) return;
        if (now - self.last_metrics_log_time < 1.0) return;
        self.last_metrics_log_time = now;
        self.metrics_logger.logf(
            "frame_avg_ms={d:.2} draw_avg_ms={d:.2} input_avg_ms={d:.2} input_max_ms={d:.2} frames={d} redraws={d}",
            .{
                self.metrics.frame_ms_avg,
                self.metrics.draw_ms_avg,
                self.metrics.input_latency_ms_avg,
                self.metrics.input_latency_ms_max,
                self.metrics.frames,
                self.metrics.redraws,
            },
        );
    }

    fn update(self: *AppState, input_batch: *shared_types.input.InputBatch) !void {
        const shell = self.shell;
        const prelude = (try self.handleUpdatePreludeFrame(shell, input_batch)) orelse return;
        const frame = try self.handlePostPreInputFrame(shell, input_batch, prelude.now);
        try self.handleInteractiveFrame(
            shell,
            frame,
            input_batch,
            prelude.suppress_terminal_shortcuts,
            prelude.terminal_close_modal_active,
            prelude.now,
        );
    }

    fn reloadConfig(self: *AppState) !void {
        const log = app_logger.logger("config.reload");
        var config = try config_mod.loadConfig(self.allocator);
        defer config_mod.freeConfig(self.allocator, &config);

        if (config.log_file_filter) |filter| {
            app_logger.setFileFilterString(filter) catch {};
        }
        if (config.log_console_filter) |filter| {
            app_logger.setConsoleFilterString(filter) catch {};
        }
        if (config.sdl_log_level) |level| {
            app_shell.setSdlLogLevel(level);
        }
        {
            const resolved_themes = app_theme_utils.resolveConfigThemes(self.shell_base_theme, &config);
            const app_theme_changed = !std.meta.eql(self.app_theme, resolved_themes.app);
            const editor_theme_changed = !std.meta.eql(self.editor_theme, resolved_themes.editor);
            const terminal_theme_changed = !std.meta.eql(self.terminal_theme, resolved_themes.terminal);

            if (app_theme_changed or editor_theme_changed or terminal_theme_changed) {
                self.app_theme = resolved_themes.app;
                self.editor_theme = resolved_themes.editor;
                self.terminal_theme = resolved_themes.terminal;

                if (app_theme_changed) {
                    self.shell.setTheme(self.app_theme);
                }
                if (editor_theme_changed) {
                    self.editor_render_cache.clear();
                    self.editor_cluster_cache.clear();
                }
                if (terminal_theme_changed) {
                    try app_terminal_theme_apply.notifyColorSchemeChanged(&self.terminal_widgets, &self.terminal_theme);
                    app_terminal_theme_apply.applyThemeToWidgets(&self.terminal_widgets, &self.terminal_theme);
                }
                self.needs_redraw = true;
            }
        }

        self.editor_wrap = config.editor_wrap orelse self.editor_wrap;
        self.editor_large_jump_rows = config.editor_large_jump_rows orelse self.editor_large_jump_rows;
        if (config.editor_highlight_budget != null) {
            self.editor_highlight_budget = config.editor_highlight_budget;
        }
        if (config.editor_width_budget != null) {
            self.editor_width_budget = config.editor_width_budget;
        }

        if (config.keybinds) |binds| {
            self.input_router.setBindings(binds);
        }

        if (config.font_lcd != null or config.font_hinting != null or config.font_autohint != null or
            config.font_glyph_overflow != null or config.text_gamma != null or
            config.text_contrast != null or config.text_linear_correction != null)
        {
            try app_font_rendering.applyRendererFontRenderingConfig(self.shell, &config, true);
            try self.refreshTerminalSizing();
            self.needs_redraw = true;
            log.logStdout("reload font_rendering applied", .{});
        }

        if (config.terminal_blink_style) |blink_style| {
            self.terminal_blink_style = switch (blink_style) {
                .kitty => .kitty,
                .off => .off,
            };
            for (self.terminal_widgets.items) |*widget| {
                widget.blink_style = self.terminal_blink_style;
            }
        }

        if (config.terminal_disable_ligatures != null or config.terminal_font_features != null) {
            self.shell.rendererPtr().setTerminalLigatureConfig(
                if (config.terminal_disable_ligatures) |v| switch (v) {
                    .never => .never,
                    .cursor => .cursor,
                    .always => .always,
                } else null,
                config.terminal_font_features,
            );
            self.needs_redraw = true;
            log.logStdout("reload terminal ligatures strategy={s} features={s}", .{
                if (config.terminal_disable_ligatures) |v| @tagName(v) else "(unchanged)",
                config.terminal_font_features orelse "(unchanged)",
            });
        }

        if (config.editor_disable_ligatures != null or config.editor_font_features != null) {
            self.shell.rendererPtr().setEditorLigatureConfig(
                if (config.editor_disable_ligatures) |v| switch (v) {
                    .never => .never,
                    .cursor => .cursor,
                    .always => .always,
                } else null,
                config.editor_font_features,
            );
            self.needs_redraw = true;
            log.logStdout("reload editor.disable_ligatures={s} editor.font_features={s}", .{
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
            self.terminal_cursor_style = cursor_style;
            for (self.terminals.items) |term| {
                term.primary.cursor_style = cursor_style;
                term.alt.cursor_style = cursor_style;
                term.force_full_damage.store(true, .release);
                term.updateViewCacheForScroll();
            }
            self.needs_redraw = true;
            log.logStdout("reload terminal cursor shape={s} blink={any}", .{ @tagName(cursor_style.shape), cursor_style.blink });
        }

        if (config.terminal_scrollback_rows != null) {
            self.terminal_scrollback_rows = config.terminal_scrollback_rows;
            log.logStdout("reload note: terminal scrollback cap applies to new sessions", .{});
        }
        if (config.terminal_tab_bar_show_single_tab != null) {
            self.terminal_tab_bar_show_single_tab = config.terminal_tab_bar_show_single_tab.?;
            self.needs_redraw = true;
            log.logStdout("reload terminal.tab_bar.show_single_tab={any}", .{
                self.terminal_tab_bar_show_single_tab,
            });
        }
        if (config.editor_tab_bar_width_mode != null) {
            self.editor_tab_bar_width_mode = app_tab_bar_width.mapMode(config.editor_tab_bar_width_mode);
            self.needs_redraw = true;
            log.logStdout("reload editor.tab_bar.width_mode={s}", .{@tagName(self.editor_tab_bar_width_mode)});
        }
        if (config.terminal_tab_bar_width_mode != null) {
            self.terminal_tab_bar_width_mode = app_tab_bar_width.mapMode(config.terminal_tab_bar_width_mode);
            self.needs_redraw = true;
            log.logStdout("reload terminal.tab_bar.width_mode={s}", .{@tagName(self.terminal_tab_bar_width_mode)});
        }
        self.applyCurrentTabBarWidthMode();
        if (config.terminal_focus_report_window != null or config.terminal_focus_report_pane != null) {
            if (config.terminal_focus_report_window) |v| self.terminal_focus_report_window_events = v;
            if (config.terminal_focus_report_pane) |v| self.terminal_focus_report_pane_events = v;
            for (self.terminal_widgets.items) |*widget| {
                widget.setFocusReportSources(self.terminal_focus_report_window_events, self.terminal_focus_report_pane_events);
            }
            log.logStdout("reload terminal.focus_reporting window={any} pane={any}", .{
                self.terminal_focus_report_window_events,
                self.terminal_focus_report_pane_events,
            });
        }

        if (config.app_font_path != null or config.app_font_size != null or
            config.editor_font_path != null or config.editor_font_size != null or
            config.terminal_font_path != null or config.terminal_font_size != null)
        {
            log.logStdout("reload note: font changes require restart", .{});
        }

        log.logStdout("config reloaded", .{});
    }

    fn draw(self: *AppState) void {
        const shell = self.shell;

        shell.beginFrame();

        if (app_modes.ide.isFontSample(self.app_mode)) {
            if (self.font_sample_view) |*view| {
                view.draw(shell);
            }
            if (self.font_sample_close_pending) {
                if (self.font_sample_screenshot_path) |path| {
                    const screenshot_w = app_bootstrap.parseEnvI32("ZIDE_FONT_SAMPLE_SCREENSHOT_WIDTH", 0);
                    const screenshot_h = app_bootstrap.parseEnvI32("ZIDE_FONT_SAMPLE_SCREENSHOT_HEIGHT", 0);
                    if (screenshot_w > 0 and screenshot_h > 0) {
                        shell.rendererPtr().dumpWindowScreenshotPpmSized(path, screenshot_w, screenshot_h) catch {};
                    } else {
                        shell.rendererPtr().dumpWindowScreenshotPpm(path) catch {};
                    }
                }
                shell.requestClose();
                self.font_sample_close_pending = false;
            }
            shell.endFrame();
            return;
        }

        const width = @as(f32, @floatFromInt(shell.width()));
        const height = @as(f32, @floatFromInt(shell.height()));
        const layout = self.computeLayout(width, height);
        var tab_tooltip: ?widgets_common.Tooltip = null;

        if (app_modes.ide.canToggleTerminal(self.app_mode)) {
            self.applyCurrentTabBarWidthMode();
            shell.setTheme(self.app_theme);
            // Draw options bar
            self.options_bar.draw(shell, layout.window.width);

            // Draw tab bar
            tab_tooltip = self.tab_bar.draw(shell, layout.tab_bar.x, layout.tab_bar.y, layout.tab_bar.width);
        } else if (app_modes.ide.useTerminalTabBarWidthMode(self.app_mode)) {
            self.applyCurrentTabBarWidthMode();
            const tab_theme = app_theme_utils.terminalTabBarTheme(self.terminal_theme, self.shell_base_theme);
            shell.setTheme(tab_theme);
            if (self.terminalTabBarVisible()) {
                tab_tooltip = self.tab_bar.draw(shell, layout.tab_bar.x, layout.tab_bar.y, layout.tab_bar.width);
            }
        }

        // Draw editor
        if (app_modes.ide.supportsEditorSurface(self.app_mode) and self.editors.items.len > 0) {
            shell.setTheme(self.editor_theme);
            const editor_idx = @min(self.active_tab, self.editors.items.len - 1);
            const editor = self.editors.items[editor_idx];
            self.prepareEditorForDisplay(editor);
            var widget = EditorWidget.initWithCache(editor, &self.editor_cluster_cache, self.editor_wrap);
            widget.drawCached(
                shell,
                &self.editor_render_cache,
                layout.editor.x,
                layout.editor.y,
                layout.editor.width,
                layout.editor.height,
                self.frame_id,
                self.last_input,
            );
        }

        // Draw terminal if shown
        if (app_modes.ide.supportsTerminalSurface(self.app_mode) and self.show_terminal and self.terminalTabCount() > 0) {
            const term_y = layout.terminal.y;

            // Terminal separator
            if (app_modes.ide.shouldRenderTerminalSeparator(self.app_mode)) {
                shell.setTheme(self.app_theme);
                shell.drawRect(@intFromFloat(layout.terminal.x), @intFromFloat(term_y), @intFromFloat(layout.terminal.width), 2, self.app_theme.ui_border);
            }

            shell.setTheme(self.terminal_theme);
            if (self.activeTerminalWidget()) |term_widget| {
                const strip = app_modes.ide.terminalStrip(self.app_mode, layout.terminal.height);
                const term_offset_y: f32 = strip.offset_y;
                const term_height = strip.draw_height;
                if (layout.terminal.width > 0 and term_height > 0) {
                    shell.beginClip(
                        @intFromFloat(layout.terminal.x),
                        @intFromFloat(term_y + term_offset_y),
                        @intFromFloat(layout.terminal.width),
                        @intFromFloat(term_height),
                    );
                }
                term_widget.draw(shell, layout.terminal.x, term_y + term_offset_y, layout.terminal.width, term_height, self.last_input);
                if (layout.terminal.width > 0 and term_height > 0) {
                    shell.endClip();
                }
            }
        }

        if (app_modes.ide.canToggleTerminal(self.app_mode)) {
            shell.setTheme(self.app_theme);
            // Draw side navigation bar (covers terminal icon overflow)
            self.side_nav.draw(shell, layout.side_nav.height, layout.side_nav.y);
        }

        // Draw status bar LAST so it spans full width over everything
        if (app_modes.ide.canToggleTerminal(self.app_mode) and self.editors.items.len > 0) {
            shell.setTheme(self.app_theme);
            const editor_idx = @min(self.active_tab, self.editors.items.len - 1);
            const editor = self.editors.items[editor_idx];
            self.status_bar.draw(
                shell,
                layout.window.width,
                layout.status_bar.y,
                self.mode,
                editor.file_path,
                editor.cursor.line,
                editor.cursor.col,
                editor.modified,
                if (self.search_panel.active)
                    .{
                        .active = true,
                        .query = self.search_panel.query.items,
                        .match_count = editor.searchMatches().len,
                        .active_index = editor.searchActiveIndex(),
                    }
                else
                    null,
            );
        }

        if (tab_tooltip) |tip| {
            widgets_common.drawTooltip(shell, tip.text, tip.x, tip.y);
        }

        if (app_modes.ide.shouldShowTerminalCloseConfirmModal(self.app_mode, self.terminalCloseConfirmActive())) {
            app_terminal_close_confirm_draw.draw(shell, layout, self.app_theme);
        }
        app_config_reload_notice.draw(
            shell,
            layout,
            self.app_mode,
            self.terminalTabBarVisible(),
            self.config_reload_notice_until,
            self.config_reload_notice_success,
            self.app_theme,
        );

        shell.endFrame();
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
                try state.routeTerminalTabActionAndSync(action);
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
                try state.routeTerminalTabActionAndSync(action);
            }
        }.call,
    ));
}

test "routeTerminalTabActionAndSync keeps terminal mode aligned with reordered tab bar" {
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

    try app.routeTerminalTabActionAndSync(.{
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
    try app.syncModeAdaptersFromTabBar();

    try std.testing.expect(!try app_terminal_runtime_intents.routeByTabIdAndSync(
        .activate,
        null,
        @ptrCast(&app),
        struct {
            fn call(raw: *anyopaque, action: app_modes.shared.actions.TabAction) !void {
                const state: *AppState = @ptrCast(@alignCast(raw));
                try state.routeTerminalTabActionAndSync(action);
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
                try state.routeTerminalTabActionAndSync(action);
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
