const std = @import("std");
const builtin = @import("builtin");

// Editor modules
const editor_mod = @import("editor/editor.zig");
const text_store = @import("editor/text_store.zig");
const types = @import("editor/types.zig");
const editor_render_cache_mod = @import("editor/render/cache.zig");
const grammar_manager_mod = @import("editor/grammar_manager.zig");
const app_logger = @import("app_logger.zig");
const config_mod = @import("config/lua_config.zig");
const terminal_font_mod = @import("ui/terminal_font.zig");

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

const AppMode = enum {
    ide,
    editor,
    terminal,
    font_sample,
};

var sigint_requested = std.atomic.Value(bool).init(false);

fn handleSigint(_: c_int) callconv(.c) void {
    sigint_requested.store(true, .release);
}

fn installSignalHandlers() void {
    if (builtin.os.tag == .windows) {
        const win32 = struct {
            const BOOL = i32;
            const DWORD = u32;
            const TRUE: BOOL = 1;
            const FALSE: BOOL = 0;

            const CTRL_C_EVENT: DWORD = 0;
            const CTRL_BREAK_EVENT: DWORD = 1;
            const CTRL_CLOSE_EVENT: DWORD = 2;
            const CTRL_LOGOFF_EVENT: DWORD = 5;
            const CTRL_SHUTDOWN_EVENT: DWORD = 6;

            const HandlerRoutine = *const fn (dwCtrlType: DWORD) callconv(.winapi) BOOL;

            extern "kernel32" fn SetConsoleCtrlHandler(HandlerRoutine: ?HandlerRoutine, Add: BOOL) callconv(.winapi) BOOL;
        };

        const handler = struct {
            fn call(ctrl_type: win32.DWORD) callconv(.winapi) win32.BOOL {
                switch (ctrl_type) {
                    win32.CTRL_C_EVENT,
                    win32.CTRL_BREAK_EVENT,
                    win32.CTRL_CLOSE_EVENT,
                    win32.CTRL_LOGOFF_EVENT,
                    win32.CTRL_SHUTDOWN_EVENT,
                    => {
                        sigint_requested.store(true, .release);
                        return win32.TRUE;
                    },
                    else => return win32.FALSE,
                }
            }
        }.call;

        _ = win32.SetConsoleCtrlHandler(handler, win32.TRUE);
        return;
    }
    const act = std.posix.Sigaction{
        .handler = .{ .handler = handleSigint },
        .mask = std.posix.sigemptyset(),
        .flags = 0,
    };
    std.posix.sigaction(std.posix.SIG.INT, &act, null);
}

fn shellSingleQuoteAlloc(allocator: std.mem.Allocator, value: []const u8) ![]u8 {
    var out = std.ArrayList(u8).empty;
    errdefer out.deinit(allocator);
    try out.append(allocator, '\'');
    for (value) |ch| {
        if (ch == '\'') {
            try out.appendSlice(allocator, "'\\''");
        } else {
            try out.append(allocator, ch);
        }
    }
    try out.append(allocator, '\'');
    return out.toOwnedSlice(allocator);
}

fn buildFontRenderingOptions(config: *const config_mod.Config) terminal_font_mod.RenderingOptions {
    var font_opts: terminal_font_mod.RenderingOptions = .{};
    if (config.font_lcd) |v| font_opts.lcd = v;
    if (parseEnvBool("ZIDE_FONT_RENDERING_LCD")) |v| font_opts.lcd = v;
    if (config.font_autohint) |v| font_opts.autohint = v;
    if (config.font_hinting) |mode| {
        font_opts.hinting = switch (mode) {
            .default => .default,
            .none => .none,
            .light => .light,
            .normal => .normal,
        };
    }
    if (config.font_glyph_overflow) |policy| {
        font_opts.glyph_overflow = switch (policy) {
            .when_followed_by_space => .when_followed_by_space,
            .never => .never,
            .always => .always,
        };
    }
    return font_opts;
}

fn applyRendererFontRenderingConfig(shell: *Shell, config: *const config_mod.Config, rebuild_fonts: bool) !void {
    const renderer = shell.rendererPtr();
    renderer.setFontRenderingOptions(buildFontRenderingOptions(config));
    renderer.setTextRenderingConfig(config.text_gamma, config.text_contrast, config.text_linear_correction);
    if (rebuild_fonts) {
        try renderer.setFontConfig(null, null);
    }
}

const AppState = struct {
    const SearchPanelCommand = enum {
        none,
        close,
        next,
        prev,
        backspace,
    };

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

    // Themes
    app_theme: app_shell.Theme,
    editor_theme: app_shell.Theme,
    terminal_theme: app_shell.Theme,

    // Current focus
    active_tab: usize,
    active_kind: enum { editor, terminal },

    // UI state
    mode: []const u8,
    show_terminal: bool,
    terminal_height: f32,
    terminal_blink_style: TerminalWidget.BlinkStyle,
    terminal_cursor_style: ?term_types.CursorStyle,
    terminal_scrollback_rows: ?usize,
    terminal_focus_report_window_events: bool,
    terminal_focus_report_pane_events: bool,
    last_terminal_pane_focus_reported: ?bool,

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
    font_sample_view: ?font_sample_view_mod.FontSampleView,
    font_sample_auto_close_frames: u64,
    font_sample_close_pending: bool,
    font_sample_screenshot_path: ?[]const u8,
    search_panel: SearchPanelState,

    fn isDarkTheme(theme: *const app_shell.Theme) bool {
        const r = @as(u32, theme.background.r);
        const g = @as(u32, theme.background.g);
        const b = @as(u32, theme.background.b);
        // Integer luma heuristic (BT.601-ish) is enough for ?2031 dark/light signaling.
        const luma = r * 299 + g * 587 + b * 114;
        return luma < 128000;
    }

    fn notifyTerminalColorSchemeChanged(self: *AppState) !void {
        const dark = isDarkTheme(&self.terminal_theme);
        for (self.terminal_widgets.items) |*widget| {
            _ = try widget.session.reportColorSchemeChanged(dark);
        }
    }

    pub fn init(allocator: std.mem.Allocator, app_mode: AppMode) !*AppState {
        var config = config_mod.loadConfig(allocator) catch |err| blk: {
            std.debug.print("config load error: {any}\n", .{err});
            break :blk config_mod.Config{
                .log_file_filter = null,
                .log_console_filter = null,
                .sdl_log_level = null,
                .editor_wrap = null,
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

        const window_width = parseEnvI32("ZIDE_WINDOW_WIDTH", 1280);
        const window_height = parseEnvI32("ZIDE_WINDOW_HEIGHT", 720);
        const shell = try Shell.init(allocator, window_width, window_height, "Zide - Zig IDE");
        errdefer shell.deinit(allocator);

        // Apply font rendering knobs before (re)loading fonts.
        try applyRendererFontRenderingConfig(shell, &config, false);
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
            parseEnvU64("ZIDE_EDITOR_PERF_FRAMES", 240)
        else
            0;
        const perf_scroll_delta: i32 = if (perf_mode)
            @intCast(parseEnvU64("ZIDE_EDITOR_PERF_SCROLL", 3))
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

        var base_theme = shell.theme().*;
        if (config.theme) |global_theme| {
            config_mod.applyThemeConfig(&base_theme, global_theme);
        }

        var app_theme = base_theme;
        if (config.app_theme) |t| config_mod.applyThemeConfig(&app_theme, t);

        var editor_theme = base_theme;
        if (config.editor_theme) |t| config_mod.applyThemeConfig(&editor_theme, t);

        var terminal_theme = base_theme;
        if (config.terminal_theme) |t| config_mod.applyThemeConfig(&terminal_theme, t);

        shell.setTheme(app_theme); // Default to app theme

        var grammar_manager = try grammar_manager_mod.GrammarManager.init(allocator);
        errdefer grammar_manager.deinit();

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
            .app_theme = app_theme,
            .editor_theme = editor_theme,
            .terminal_theme = terminal_theme,
            .active_tab = 0,
            .active_kind = if (app_mode == .terminal) .terminal else .editor,
            .mode = "NORMAL",
            .show_terminal = app_mode == .terminal,
            .terminal_height = 200,
            .terminal_blink_style = terminal_blink_style,
            .terminal_cursor_style = terminal_cursor_style,
            .terminal_scrollback_rows = config.terminal_scrollback_rows,
            .terminal_focus_report_window_events = config.terminal_focus_report_window orelse true,
            .terminal_focus_report_pane_events = config.terminal_focus_report_pane orelse false,
            .last_terminal_pane_focus_reported = null,
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
            .font_sample_view = null,
            .font_sample_auto_close_frames = if (app_mode == .font_sample)
                parseEnvU64("ZIDE_FONT_SAMPLE_FRAMES", 0)
            else
                0,
            .font_sample_close_pending = false,
            .font_sample_screenshot_path = if (app_mode == .font_sample) envSlice("ZIDE_FONT_SAMPLE_SCREENSHOT") else null,
            .search_panel = SearchPanelState.init(allocator),
        };
        if (app_mode == .font_sample) {
            state.font_sample_view = try font_sample_view_mod.FontSampleView.init(allocator, shell.rendererPtr());
        }
        if (config.keybinds) |binds| {
            state.input_router.setBindings(binds);
        }
        state.applyUiScale();

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
        for (self.terminals.items) |t| {
            t.deinit();
        }
        self.terminals.deinit(self.allocator);

        self.tab_bar.deinit();
        self.shell.deinit(self.allocator);
        self.editor_render_cache.deinit();
        self.editor_cluster_cache.deinit();
        self.grammar_manager.deinit();
        self.input_router.deinit();
        self.search_panel.deinit(self.allocator);
        if (self.perf_file_path) |path| {
            self.allocator.free(path);
        }
        app_logger.deinit();
        self.allocator.destroy(self);
    }

    pub fn newEditor(self: *AppState) !void {
        const editor = try Editor.init(self.allocator, &self.grammar_manager);
        try self.editors.append(self.allocator, editor);
        try self.tab_bar.addTab("untitled", .editor);
        self.active_tab = self.tab_bar.tabs.items.len - 1;
        self.active_kind = .editor;
    }

    pub fn openFile(self: *AppState, path: []const u8) !void {
        const editor = try Editor.init(self.allocator, &self.grammar_manager);
        try editor.openFile(path);
        try self.editors.append(self.allocator, editor);

        // Extract filename for tab title
        const filename = std.fs.path.basename(path);
        try self.tab_bar.addTab(filename, .editor);
        self.active_tab = self.tab_bar.tabs.items.len - 1;
        self.active_kind = .editor;
    }

    pub fn openFileAt(self: *AppState, path: []const u8, line_1: usize, col_1: ?usize) !void {
        const editor = try Editor.init(self.allocator, &self.grammar_manager);
        try editor.openFile(path);
        try self.editors.append(self.allocator, editor);

        const filename = std.fs.path.basename(path);
        try self.tab_bar.addTab(filename, .editor);
        self.active_tab = self.tab_bar.tabs.items.len - 1;
        self.active_kind = .editor;

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

    fn openSearchPanel(self: *AppState, editor: *Editor) !void {
        self.search_panel.active = true;
        self.search_panel.query.clearRetainingCapacity();
        if (editor.searchQuery()) |query| {
            try self.search_panel.query.appendSlice(self.allocator, query);
        }
    }

    fn closeSearchPanel(self: *AppState) void {
        self.search_panel.active = false;
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

    fn syncEditorSearchQuery(self: *AppState, editor: *Editor) !void {
        if (self.search_panel.query.items.len == 0) {
            try editor.setSearchQuery(null);
            return;
        }
        try editor.setSearchQuery(self.search_panel.query.items);
    }

    fn popSearchQueryScalar(self: *AppState) void {
        if (self.search_panel.query.items.len == 0) return;
        var idx = self.search_panel.query.items.len - 1;
        while (idx > 0 and (self.search_panel.query.items[idx] & 0b1100_0000) == 0b1000_0000) : (idx -= 1) {}
        self.search_panel.query.items.len = idx;
    }

    fn searchPanelCommand(input_batch: *const shared_types.input.InputBatch) SearchPanelCommand {
        if (input_batch.keyPressed(.escape)) return .close;
        if (input_batch.keyPressed(.enter) or input_batch.keyPressed(.kp_enter) or input_batch.keyPressed(.f3)) {
            return if (input_batch.mods.shift) .prev else .next;
        }
        if (input_batch.keyPressed(.backspace) or input_batch.keyRepeated(.backspace)) return .backspace;
        return .none;
    }

    fn appendSearchPanelTextEvents(
        allocator: std.mem.Allocator,
        query: *std.ArrayList(u8),
        input_batch: *const shared_types.input.InputBatch,
    ) !bool {
        var appended = false;
        for (input_batch.events.items) |event| {
            if (event != .text) continue;
            const text = event.text.utf8Slice();
            if (text.len == 0) continue;
            try query.appendSlice(allocator, text);
            appended = true;
        }
        return appended;
    }

    fn visualExtendDeltaForAction(action: input_actions.ActionKind) ?i32 {
        return switch (action) {
            .editor_extend_up => -1,
            .editor_extend_down => 1,
            else => null,
        };
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

        switch (searchPanelCommand(input_batch)) {
            .close => {
                self.closeSearchPanel();
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
                self.popSearchQueryScalar();
                query_changed = true;
                handled = true;
            },
            .none => {},
        }

        if (try appendSearchPanelTextEvents(self.allocator, &self.search_panel.query, input_batch)) {
            query_changed = true;
            handled = true;
        }

        if (query_changed) {
            try self.syncEditorSearchQuery(editor);
        }

        return handled;
    }

    fn isProbablyTextFile(path: []const u8) bool {
        var file = if (std.fs.path.isAbsolute(path))
            std.fs.openFileAbsolute(path, .{ .mode = .read_only }) catch return false
        else
            std.fs.cwd().openFile(path, .{ .mode = .read_only }) catch return false;
        defer file.close();
        const stat = file.stat() catch return false;
        if (stat.kind != .file) return false;
        var buf: [8192]u8 = undefined;
        const n = file.read(&buf) catch return false;
        if (n == 0) return true;
        if (std.mem.indexOfScalar(u8, buf[0..n], 0) != null) return false;
        return std.unicode.utf8ValidateSlice(buf[0..n]);
    }

    pub fn newTerminal(self: *AppState) !void {
        // Calculate terminal size based on UI
        const shell = self.shell;
        const width = @as(f32, @floatFromInt(shell.width()));
        const height = @as(f32, @floatFromInt(shell.height()));
        const layout = self.computeLayout(width, height);
        if (self.app_mode == .terminal) {
            self.active_kind = .terminal;
        } else if (self.app_mode == .editor) {
            self.active_kind = .editor;
        }
        const initial_grid = self.terminalGridSize(layout.terminal.width, layout.terminal.height, 80, 24);
        const cols: u16 = initial_grid.cols;
        const rows: u16 = initial_grid.rows;
        const theme = &self.terminal_theme;

        const term = try TerminalSession.initWithOptions(self.allocator, rows, cols, .{
            .scrollback_rows = self.terminal_scrollback_rows,
            .cursor_style = self.terminal_cursor_style,
        });
        term.setDefaultColors(
            term_types.Color{
                .r = theme.foreground.r,
                .g = theme.foreground.g,
                .b = theme.foreground.b,
            },
            term_types.Color{
                .r = theme.background.r,
                .g = theme.background.g,
                .b = theme.background.b,
            },
        );
        if (theme.ansi_colors) |ansi| {
            var colors: [16]term_types.Color = undefined;
            for (ansi, 0..) |c, i| {
                colors[i] = term_types.Color{ .r = c.r, .g = c.g, .b = c.b };
            }
            term.setAnsiColors(colors);
        }
        term.setCellSize(
            @intFromFloat(shell.terminalCellWidth()),
            @intFromFloat(shell.terminalCellHeight()),
        );
        try term.start(null);
        try self.terminals.append(self.allocator, term);
        var widget = TerminalWidget.init(term, self.terminal_blink_style);
        widget.setFocusReportSources(self.terminal_focus_report_window_events, self.terminal_focus_report_pane_events);
        try self.terminal_widgets.append(self.allocator, widget);
        try self.notifyTerminalColorSchemeChanged();

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
    }

    fn terminalGridSize(self: *AppState, terminal_width: f32, terminal_height: f32, min_cols: u16, min_rows: u16) struct { cols: u16, rows: u16 } {
        // Match terminal widget packing, which uses rounded logical cell steps
        // for row/column placement in offscreen texture updates.
        const cell_w = @as(f32, @floatFromInt(@max(1, @as(i32, @intFromFloat(std.math.round(self.shell.terminalCellWidth()))))));
        const cell_h = @as(f32, @floatFromInt(@max(1, @as(i32, @intFromFloat(std.math.round(self.shell.terminalCellHeight()))))));
        const cols_f = std.math.floor(@max(0.0, terminal_width) / cell_w);
        const rows_f = std.math.floor(@max(0.0, terminal_height) / cell_h);
        const cols_u: u16 = @intFromFloat(@max(@as(f32, @floatFromInt(min_cols)), cols_f));
        const rows_u: u16 = @intFromFloat(@max(@as(f32, @floatFromInt(min_rows)), rows_f));
        return .{ .cols = cols_u, .rows = rows_u };
    }

    fn refreshTerminalSizing(self: *AppState) !void {
        if (self.terminals.items.len == 0) return;
        const shell = self.shell;
        const width = @as(f32, @floatFromInt(shell.width()));
        const height = @as(f32, @floatFromInt(shell.height()));
        const layout = self.computeLayout(width, height);
        const effective_height = if (self.app_mode == .ide and !self.show_terminal) self.terminal_height else layout.terminal.height;
        const grid = self.terminalGridSize(layout.terminal.width, effective_height, 1, 1);
        const cols: u16 = grid.cols;
        const rows: u16 = grid.rows;
        for (self.terminals.items) |term| {
            term.setCellSize(
                @intFromFloat(shell.terminalCellWidth()),
                @intFromFloat(shell.terminalCellHeight()),
            );
            try term.resize(rows, cols);
        }
    }

    fn computeLayout(self: *AppState, width: f32, height: f32) layout_types.WidgetLayout {
        switch (self.app_mode) {
            .terminal => {
                const terminal_h = if (self.show_terminal) height else 0;
                return .{
                    .window = .{ .x = 0, .y = 0, .width = width, .height = height },
                    .options_bar = .{ .x = 0, .y = 0, .width = 0, .height = 0 },
                    .tab_bar = .{ .x = 0, .y = 0, .width = 0, .height = 0 },
                    .side_nav = .{ .x = 0, .y = 0, .width = 0, .height = 0 },
                    .editor = .{ .x = 0, .y = 0, .width = 0, .height = 0 },
                    .terminal = .{ .x = 0, .y = 0, .width = width, .height = terminal_h },
                    .status_bar = .{ .x = 0, .y = 0, .width = 0, .height = 0 },
                };
            },
            .editor => {
                return .{
                    .window = .{ .x = 0, .y = 0, .width = width, .height = height },
                    .options_bar = .{ .x = 0, .y = 0, .width = 0, .height = 0 },
                    .tab_bar = .{ .x = 0, .y = 0, .width = 0, .height = 0 },
                    .side_nav = .{ .x = 0, .y = 0, .width = 0, .height = 0 },
                    .editor = .{ .x = 0, .y = 0, .width = width, .height = height },
                    .terminal = .{ .x = 0, .y = 0, .width = 0, .height = 0 },
                    .status_bar = .{ .x = 0, .y = 0, .width = 0, .height = 0 },
                };
            },
            .font_sample => {
                return .{
                    .window = .{ .x = 0, .y = 0, .width = width, .height = height },
                    .options_bar = .{ .x = 0, .y = 0, .width = 0, .height = 0 },
                    .tab_bar = .{ .x = 0, .y = 0, .width = 0, .height = 0 },
                    .side_nav = .{ .x = 0, .y = 0, .width = 0, .height = 0 },
                    .editor = .{ .x = 0, .y = 0, .width = width, .height = height },
                    .terminal = .{ .x = 0, .y = 0, .width = 0, .height = 0 },
                    .status_bar = .{ .x = 0, .y = 0, .width = 0, .height = 0 },
                };
            },
            .ide => {},
        }

        const options_bar_height = self.options_bar.height;
        const tab_bar_height = self.tab_bar.height;
        const side_nav_width = self.side_nav.width;
        const status_bar_height = self.status_bar.height;
        const max_terminal_h = @max(0, height - options_bar_height - tab_bar_height - status_bar_height);
        const terminal_h = if (self.show_terminal) @min(self.terminal_height, max_terminal_h) else 0;
        const editor_height = @max(0, height - options_bar_height - tab_bar_height - status_bar_height - terminal_h);
        const editor_width = @max(0, width - side_nav_width);

        return .{
            .window = .{ .x = 0, .y = 0, .width = width, .height = height },
            .options_bar = .{ .x = 0, .y = 0, .width = width, .height = options_bar_height },
            .tab_bar = .{ .x = side_nav_width, .y = options_bar_height, .width = editor_width, .height = tab_bar_height },
            .side_nav = .{ .x = 0, .y = options_bar_height, .width = side_nav_width, .height = height - status_bar_height - options_bar_height },
            .editor = .{ .x = side_nav_width, .y = options_bar_height + tab_bar_height, .width = editor_width, .height = editor_height },
            .terminal = .{ .x = side_nav_width, .y = height - status_bar_height - terminal_h, .width = editor_width, .height = terminal_h },
            .status_bar = .{ .x = 0, .y = height - status_bar_height, .width = width, .height = status_bar_height },
        };
    }

    pub fn run(self: *AppState) !void {
        if (self.app_mode == .terminal) {
            if (self.terminals.items.len == 0) {
                try self.newTerminal();
            }
        } else if (self.app_mode == .font_sample) {
            // No initial editor/terminal. The font sample view draws directly.
        } else {
            if (self.perf_mode and self.perf_file_path != null) {
                try self.openFile(self.perf_file_path.?);
            } else {
                // Create initial editor
                try self.newEditor();

                // Insert welcome message
                if (self.editors.items.len > 0) {
                    const editor = self.editors.items[0];
                    try editor.insertText(
                        \\// Welcome to Zide - A Zig IDE
                        \\//
                        \\// Keyboard shortcuts:
                        \\//   Ctrl+N  - New file
                        \\//   Ctrl+O  - Open file
                        \\//   Ctrl+S  - Save file
                        \\//   Ctrl+Z  - Undo
                        \\//   Ctrl+Y  - Redo
                        \\//   Ctrl+`  - Toggle terminal
                        \\//   Ctrl+Q  - Quit
                        \\//
                        \\// Start typing to begin editing...
                        \\
                        \\const std = @import("std");
                        \\
                        \\pub fn main() !void {
                        \\    std.debug.print("Hello, Zide!\n", .{});
                        \\}
                        \\
                    );
                    editor.cursor = .{ .line = 0, .col = 0, .offset = 0 };
                    editor.modified = false;
                }
            }
        }

        // Main loop
        while (!self.shell.shouldClose()) {
            // Poll events first (this updates SDL's input state)
            const poll_start = app_shell.getTime();
            app_shell.pollInputEvents();
            const poll_end = app_shell.getTime();
            if (self.shell.shouldClose()) break;
            if (sigint_requested.load(.acquire)) {
                self.shell.requestClose();
                break;
            }
            const build_start = app_shell.getTime();
            var input_batch = input_builder.buildInputBatch(self.allocator, self.shell);
            const build_end = app_shell.getTime();
            defer input_batch.deinit();

            self.frame_id +|= 1;
            if (self.app_mode != .terminal) {
                self.editor_cluster_cache.beginFrame(self.frame_id);
            }

            const frame_time = app_shell.getTime();
            self.metrics.beginFrame(frame_time);

            const update_start = app_shell.getTime();
            try self.update(&input_batch);
            const update_end = app_shell.getTime();
            var draw_ms: f64 = 0.0;
            const poll_ms = (poll_end - poll_start) * 1000.0;
            const build_ms = (build_end - build_start) * 1000.0;
            const update_ms = (update_end - update_start) * 1000.0;

            // Only redraw when something changed
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
            } else {
                self.idle_frames +|= 1; // Saturating add
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

                // Adaptive sleep: longer sleep when idle longer
                // - Startup grace period: stay responsive for first 3 seconds
                // - Active: 16ms (~60fps responsiveness)
                // - Idle: up to 100ms (~10fps, saves CPU)
                const uptime = app_shell.getTime();
                const sleep_ms: f64 = if (uptime < 3.0)
                    0.016 // Startup: stay fully responsive
                else if (self.idle_frames < 10)
                    0.016 // First 10 idle frames: stay responsive
                else if (self.idle_frames < 60)
                    0.033 // ~30fps check rate
                else
                    0.100; // Deep idle: 10fps check rate

                app_shell.waitTime(sleep_ms);
                self.maybeLogMetrics(app_shell.getTime());
            }

            if (self.perf_mode and self.perf_frames_done >= self.perf_frames_total and self.perf_frames_total > 0) {
                self.perf_logger.logf("perf complete frames={d}", .{self.perf_frames_done});
                break;
            }
        }
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
        const r = shell.rendererPtr();
        self.last_input = input_batch.snapshot();

        if (self.app_mode == .font_sample) {
            if (self.font_sample_auto_close_frames > 0 and self.frame_id >= self.font_sample_auto_close_frames) {
                self.font_sample_close_pending = true;
                self.needs_redraw = true;
                return;
            }
            if (self.font_sample_view) |*view| {
                if (view.update(r, input_batch)) {
                    self.needs_redraw = true;
                }
            }
        }
        self.options_bar.updateInput(self.last_input);
        self.tab_bar.updateInput(self.last_input);
        self.side_nav.updateInput(self.last_input);
        self.status_bar.updateInput(self.last_input);
        const now = app_shell.getTime();
        const focus = if (self.app_mode == .terminal or self.active_kind == .terminal) input_actions.FocusKind.terminal else input_actions.FocusKind.editor;
        self.input_router.route(input_batch, focus);
        var suppress_terminal_shortcuts = false;
        var handled_shortcut = false;
        for (self.input_router.actionsSlice()) |action| {
            if (action.kind == .reload_config) {
                try self.reloadConfig();
                self.needs_redraw = true;
                handled_shortcut = true;
            }
        }
        for (self.input_router.actionsSlice()) |action| {
            if (focus != .terminal) continue;
            switch (action.kind) {
                .copy, .paste => suppress_terminal_shortcuts = true,
                else => {},
            }
        }
        if (focus == .terminal and (self.app_mode == .terminal or self.show_terminal) and self.terminals.items.len > 0) {
            var term_widget = &self.terminal_widgets.items[0];
            const pane_focused_now = true;
            if (self.last_terminal_pane_focus_reported == null or self.last_terminal_pane_focus_reported.? != pane_focused_now) {
                if (try term_widget.reportFocusChangedFrom(.pane, pane_focused_now)) {
                    handled_shortcut = true;
                }
                self.last_terminal_pane_focus_reported = pane_focused_now;
            }
            if (input_batch.events.items.len > 0) {
                term_widget.noteInput(now);
            }
            for (self.input_router.actionsSlice()) |action| {
                switch (action.kind) {
                    .copy => {
                        if (term_widget.copySelectionToClipboard(shell)) {
                            handled_shortcut = true;
                        }
                    },
                    .paste => {
                        if (term_widget.pasteClipboardFromSystem(shell)) {
                            handled_shortcut = true;
                            self.needs_redraw = true;
                        }
                    },
                    .terminal_scrollback_pager => {
                        if (try self.openTerminalScrollbackInPager(term_widget, self.terminals.items[0])) {
                            handled_shortcut = true;
                        }
                    },
                    else => {},
                }
            }
        }
        if (!(focus == .terminal and (self.app_mode == .terminal or self.show_terminal) and self.terminals.items.len > 0) and self.terminals.items.len > 0) {
            var term_widget = &self.terminal_widgets.items[0];
            const pane_focused_now = false;
            if (self.last_terminal_pane_focus_reported == null or self.last_terminal_pane_focus_reported.? != pane_focused_now) {
                if (try term_widget.reportFocusChangedFrom(.pane, pane_focused_now)) {
                    handled_shortcut = true;
                }
                self.last_terminal_pane_focus_reported = pane_focused_now;
            }
        }
        if (focus == .editor and self.editors.items.len > 0) {
            const editor_idx = @min(self.active_tab, self.editors.items.len - 1);
            const editor = self.editors.items[editor_idx];
            var editor_widget = EditorWidget.initWithCache(editor, &self.editor_cluster_cache, self.editor_wrap);
            const action_layout = self.computeLayout(@floatFromInt(r.width), @floatFromInt(r.height));
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
                            handled_shortcut = true;
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
                            handled_shortcut = true;
                        }
                    },
                    .paste => {
                        if (shell.getClipboardText()) |clip| {
                            try editor.insertText(clip);
                            self.needs_redraw = true;
                            handled_shortcut = true;
                        }
                    },
                    .save => {
                        try editor.save();
                        self.needs_redraw = true;
                        handled_shortcut = true;
                    },
                    .undo => {
                        _ = try editor.undo();
                        self.needs_redraw = true;
                        handled_shortcut = true;
                    },
                    .redo => {
                        _ = try editor.redo();
                        self.needs_redraw = true;
                        handled_shortcut = true;
                    },
                    .editor_add_caret_up => {
                        if (try editor.addCaretUp()) {
                            self.needs_redraw = true;
                            handled_shortcut = true;
                        }
                    },
                    .editor_add_caret_down => {
                        if (try editor.addCaretDown()) {
                            self.needs_redraw = true;
                            handled_shortcut = true;
                        }
                    },
                    .editor_move_word_left => {
                        editor.moveCursorWordLeft();
                        self.needs_redraw = true;
                        handled_shortcut = true;
                    },
                    .editor_move_word_right => {
                        editor.moveCursorWordRight();
                        self.needs_redraw = true;
                        handled_shortcut = true;
                    },
                    .editor_extend_left => {
                        editor.extendSelectionLeft();
                        self.needs_redraw = true;
                        handled_shortcut = true;
                    },
                    .editor_extend_right => {
                        editor.extendSelectionRight();
                        self.needs_redraw = true;
                        handled_shortcut = true;
                    },
                    .editor_extend_line_start => {
                        editor.extendSelectionToLineStart();
                        self.needs_redraw = true;
                        handled_shortcut = true;
                    },
                    .editor_extend_line_end => {
                        editor.extendSelectionToLineEnd();
                        self.needs_redraw = true;
                        handled_shortcut = true;
                    },
                    .editor_extend_word_left => {
                        editor.extendSelectionWordLeft();
                        self.needs_redraw = true;
                        handled_shortcut = true;
                    },
                    .editor_extend_word_right => {
                        editor.extendSelectionWordRight();
                        self.needs_redraw = true;
                        handled_shortcut = true;
                    },
                    .editor_extend_up, .editor_extend_down => {
                        const delta = visualExtendDeltaForAction(action.kind).?;
                        if (editor_widget.extendSelectionVisual(shell, delta)) {
                            editor_widget.ensureCursorVisible(shell, action_layout.editor.height);
                            self.needs_redraw = true;
                            handled_shortcut = true;
                        }
                    },
                    .editor_search_open => {
                        try self.openSearchPanel(editor);
                        self.needs_redraw = true;
                        handled_shortcut = true;
                    },
                    .editor_search_next => {
                        if (editor.activateNextSearchMatch()) {
                            self.needs_redraw = true;
                            handled_shortcut = true;
                        }
                    },
                    .editor_search_prev => {
                        if (editor.activatePrevSearchMatch()) {
                            self.needs_redraw = true;
                            handled_shortcut = true;
                        }
                    },
                    else => {},
                }
            }
        }
        if (handled_shortcut) {
            self.metrics.noteInput(now);
        }
        if (try shell.applyPendingZoom(now)) {
            self.applyUiScale();
            try self.refreshTerminalSizing();
            self.needs_redraw = true;
            self.metrics.noteInput(now);
        }
        // Check for window resize (event-based, works with Wayland)
        if (app_shell.isWindowResized()) {
            _ = shell.refreshWindowMetrics("window-event");
            if (try shell.refreshUiScale()) {
                self.applyUiScale();
            }
            self.window_resize_pending = true;
            self.window_resize_last_time = now;
            self.needs_redraw = true;
        }

        const width = @as(f32, @floatFromInt(shell.width()));
        const height = @as(f32, @floatFromInt(shell.height()));
        const layout = self.computeLayout(width, height);

        if (self.terminals.items.len > 0 and self.terminal_widgets.items.len > 0) {
            const term_widget = &self.terminal_widgets.items[0];
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

        if (self.window_resize_pending and (now - self.window_resize_last_time) >= 0.12) {
            self.window_resize_pending = false;
            if (self.terminals.items.len > 0) {
                const term = self.terminals.items[0];
                const effective_height = if (self.app_mode == .ide and !self.show_terminal) self.terminal_height else layout.terminal.height;
                const grid = self.terminalGridSize(layout.terminal.width, effective_height, 1, 1);
                const cols: u16 = grid.cols;
                const rows: u16 = grid.rows;
                term.setCellSize(
                    @intFromFloat(shell.terminalCellWidth()),
                    @intFromFloat(shell.terminalCellHeight()),
                );
                try term.resize(rows, cols);
            }
            self.needs_redraw = true;
        }

        // Check for mouse activity (doesn't consume input)
        const mouse = input_batch.mouse_pos;
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

        // Terminal resize by dragging separator
        if (self.app_mode == .ide and self.show_terminal) {
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
                        const grid = self.terminalGridSize(layout.terminal.width, self.terminal_height, 1, 1);
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

        var handled_zoom = false;
        const zoom_log = app_logger.logger("ui.zoom.shortcut");
        for (self.input_router.actionsSlice()) |action| {
            switch (action.kind) {
                .new_editor => {
                    if (self.app_mode != .terminal) {
                        try self.newEditor();
                        self.needs_redraw = true;
                        self.metrics.noteInput(now);
                        return;
                    }
                },
                .zoom_in => {
                    const prev_zoom = shell.userZoomFactor();
                    const prev_target = shell.userZoomTargetFactor();
                    const changed = shell.queueUserZoom(0.1, now);
                    if (changed) {
                        self.metrics.noteInput(now);
                    }
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
                    handled_zoom = true;
                },
                .zoom_out => {
                    const prev_zoom = shell.userZoomFactor();
                    const prev_target = shell.userZoomTargetFactor();
                    const changed = shell.queueUserZoom(-0.1, now);
                    if (changed) {
                        self.metrics.noteInput(now);
                    }
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
                    handled_zoom = true;
                },
                .zoom_reset => {
                    const prev_zoom = shell.userZoomFactor();
                    const prev_target = shell.userZoomTargetFactor();
                    const changed = shell.resetUserZoomTarget(now);
                    if (changed) {
                        self.metrics.noteInput(now);
                    }
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
                    handled_zoom = true;
                },
                .toggle_terminal => {
                    if (self.app_mode == .ide) {
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
                        return;
                    }
                },
                else => {},
            }
        }
        if (handled_zoom) {
            return;
        }

        // Tab bar click handling
        if (input_batch.mousePressed(.left)) {
            if (self.app_mode == .ide) {
                const tab_bar_y = self.options_bar.height;
                if (self.tab_bar.handleClick(mouse.x, mouse.y, layout.side_nav.width, tab_bar_y)) {
                    // Tab was clicked
                    self.active_tab = self.tab_bar.active_index;
                    self.needs_redraw = true;
                    self.metrics.noteInput(now);
                }

                const editor_x = layout.editor.x;
                const editor_y = layout.editor.y;
                const in_editor = mouse.x >= editor_x and mouse.x <= editor_x + layout.editor.width and
                    mouse.y >= editor_y and mouse.y <= editor_y + layout.editor.height;

                const in_terminal = layout.terminal.height > 0 and mouse.y >= term_y and mouse.y <= term_y + layout.terminal.height;

                if (in_terminal and self.show_terminal) {
                    self.active_kind = .terminal;
                    self.needs_redraw = true;
                    self.metrics.noteInput(now);
                } else if (in_editor) {
                    self.active_kind = .editor;
                    self.needs_redraw = true;
                    self.metrics.noteInput(now);
                }
            } else if (self.app_mode == .terminal) {
                self.active_kind = .terminal;
            } else {
                self.active_kind = .editor;
            }

            if (self.mouse_debug) {
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
        }

        // Update active view
        var search_panel_consumed_input = false;
        if (self.search_panel.active) {
            if (self.activeEditor()) |editor| {
                if (try self.handleSearchPanelInput(editor, input_batch)) {
                    self.editor_cluster_cache.clear();
                    self.needs_redraw = true;
                    self.metrics.noteInput(now);
                    search_panel_consumed_input = true;
                }
            }
        }

        if (self.app_mode != .terminal and self.active_kind == .editor and self.editors.items.len > 0) {
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
            const editor_x = layout.editor.x;
            const editor_y = layout.editor.y;
            const in_editor = mouse.x >= editor_x and mouse.x <= editor_x + layout.editor.width and
                mouse.y >= editor_y and mouse.y <= editor_y + layout.editor.height;
            const alt = input_batch.mods.alt;
            const mouse_shell = app_shell.MousePos{ .x = mouse.x, .y = mouse.y };
            const scrollbar_handled = widget.handleHorizontalScrollbarInput(
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
            const scrollbar_blocking = scrollbar_handled or vscroll_handled;
            if (scrollbar_handled) {
                self.needs_redraw = true;
                self.metrics.noteInput(now);
            }
            if (vscroll_handled) {
                self.needs_redraw = true;
                self.metrics.noteInput(now);
            }

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

            if (layout.editor.width > 0 and layout.editor.height > 0) {
                self.prepareEditorForDisplay(widget.editor);
                const visible_lines = @as(usize, @intFromFloat(layout.editor.height / r.char_height));
                const default_budget = if (visible_lines > 0) visible_lines + 1 else 0;
                const highlight_budget = self.editor_highlight_budget orelse default_budget;
                editor_draw.precomputeHighlightTokens(&widget, &self.editor_render_cache, shell, layout.editor.height, highlight_budget);
                const width_budget = self.editor_width_budget orelse highlight_budget;
                editor_draw.precomputeLineWidths(&widget, &self.editor_render_cache, shell, layout.editor.height, width_budget);
                editor_draw.precomputeWrapCounts(&widget, &self.editor_render_cache, shell, layout.editor.height, width_budget);
            }
        }

        // Update terminal if shown
        if (self.app_mode != .editor and self.show_terminal and self.terminals.items.len > 0) {
            const term = self.terminals.items[0];
            var term_widget = &self.terminal_widgets.items[0];

            // Only poll PTY if there's data available (non-blocking check)
            // Skip polling when in deep idle to save CPU
            if (term.hasData()) {
                term.setInputPressure(input_batch.events.items.len > 0);
                try term.poll();
                self.needs_redraw = true;
            }

            // Handle terminal input if focused at bottom
            const term_y_draw = layout.terminal.y + 2;
            const term_x = layout.terminal.x;
            const term_draw_height = @max(0, layout.terminal.height - 2);
            if (term_widget.updateBlink(now)) {
                self.needs_redraw = true;
            }
            if (self.active_kind == .terminal) {
                if (!search_panel_consumed_input and try term_widget.handleInput(
                    shell,
                    term_x,
                    term_y_draw,
                    layout.terminal.width,
                    term_draw_height,
                    true,
                    &self.terminal_scroll_dragging,
                    &self.terminal_scroll_grab_offset,
                    suppress_terminal_shortcuts,
                    input_batch,
                )) {
                    self.needs_redraw = true;
                    self.metrics.noteInput(now);
                }
                if (term_widget.takePendingOpenRequest()) |req| {
                    defer self.allocator.free(req.path);
                    if (isProbablyTextFile(req.path)) {
                        if (req.line != null) {
                            try self.openFileAt(req.path, req.line.?, req.col);
                        } else {
                            try self.openFile(req.path);
                        }
                        self.needs_redraw = true;
                        self.metrics.noteInput(now);
                    }
                }
            } else {
                if (!search_panel_consumed_input and try term_widget.handleInput(
                    shell,
                    term_x,
                    term_y_draw,
                    layout.terminal.width,
                    term_draw_height,
                    false,
                    &self.terminal_scroll_dragging,
                    &self.terminal_scroll_grab_offset,
                    suppress_terminal_shortcuts,
                    input_batch,
                )) {
                    self.needs_redraw = true;
                    self.metrics.noteInput(now);
                }
                if (term_widget.takePendingOpenRequest()) |req| {
                    defer self.allocator.free(req.path);
                    if (isProbablyTextFile(req.path)) {
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
        }
    }

    fn openTerminalScrollbackInPager(self: *AppState, term_widget: *TerminalWidget, term: *TerminalSession) !bool {
        const allocator = self.allocator;
        const text = try term_widget.scrollbackAnsiTextAlloc(allocator);
        defer allocator.free(text);
        if (text.len == 0) return false;

        var dir = try std.fs.cwd().makeOpenPath(".tmp", .{});
        defer dir.close();

        const nanos = std.time.nanoTimestamp();
        const file_name = try std.fmt.allocPrint(allocator, "terminal-scrollback-{d}.txt", .{nanos});
        defer allocator.free(file_name);

        {
            var file = try dir.createFile(file_name, .{ .truncate = true });
            defer file.close();
            try file.writeAll(text);
        }

        const path = try std.fs.path.join(allocator, &.{ ".tmp", file_name });
        defer allocator.free(path);
        const abs_path = std.fs.cwd().realpathAlloc(allocator, path) catch try allocator.dupe(u8, path);
        defer allocator.free(abs_path);
        const shell_path = try shellSingleQuoteAlloc(allocator, abs_path);
        defer allocator.free(shell_path);

        if (builtin.os.tag == .windows) {
            // Keep flow inside the active terminal session; use `more` as a simple pager.
            const cmd = try std.fmt.allocPrint(
                allocator,
                "\x15more \"{s}\"\r",
                .{abs_path},
            );
            defer allocator.free(cmd);
            term.sendText(cmd) catch return false;
            return true;
        }

        const script_name = try std.fmt.allocPrint(allocator, "terminal-scrollback-{d}.sh", .{nanos});
        defer allocator.free(script_name);
        const script_path = try std.fs.path.join(allocator, &.{ ".tmp", script_name });
        defer allocator.free(script_path);
        const script_abs_path = std.fs.cwd().realpathAlloc(allocator, script_path) catch try allocator.dupe(u8, script_path);
        defer allocator.free(script_abs_path);
        const shell_script_path = try shellSingleQuoteAlloc(allocator, script_abs_path);
        defer allocator.free(shell_script_path);

        {
            var script = try dir.createFile(script_name, .{ .truncate = true });
            defer script.close();
            const script_body = try std.fmt.allocPrint(
                allocator,
                "#!/usr/bin/env sh\nif [ -n \"${{PAGER:-}}\" ]; then if [ \"${{PAGER##*/}}\" = \"page\" ]; then cat {s} | \"$PAGER\" -o; else \"$PAGER\" {s}; fi; elif command -v less >/dev/null 2>&1; then less -R -+F {s}; elif command -v more >/dev/null 2>&1; then more {s}; else cat {s}; fi\nrm -f \"$0\"\n",
                .{ shell_path, shell_path, shell_path, shell_path, shell_path },
            );
            defer allocator.free(script_body);
            try script.writeAll(script_body);
        }

        const cmd = try std.fmt.allocPrint(
            allocator,
            "\x15sh {s}\r",
            .{shell_script_path},
        );
        defer allocator.free(cmd);
        term.sendText(cmd) catch return false;
        return true;
    }

    fn reloadConfig(self: *AppState) !void {
        const log = app_logger.logger("config.reload");
        var config = config_mod.loadConfig(self.allocator) catch |err| {
            log.logf("reload failed: {any}", .{err});
            return;
        };
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
        if (config.theme != null or config.app_theme != null or config.editor_theme != null or config.terminal_theme != null) {
            var base_theme = self.shell.theme().*; // use whatever is currently base, or we might need to recreate from default?
            // Actually it's better to just apply them on top of the existing theme states.
            if (config.theme) |t| config_mod.applyThemeConfig(&base_theme, t);

            if (config.theme != null or config.app_theme != null) {
                if (config.theme) |t| config_mod.applyThemeConfig(&self.app_theme, t);
                if (config.app_theme) |t| config_mod.applyThemeConfig(&self.app_theme, t);
                self.shell.setTheme(self.app_theme);
            }
            if (config.theme != null or config.editor_theme != null) {
                if (config.theme) |t| config_mod.applyThemeConfig(&self.editor_theme, t);
                if (config.editor_theme) |t| config_mod.applyThemeConfig(&self.editor_theme, t);
                self.editor_render_cache.clear();
                self.editor_cluster_cache.clear();
            }
            if (config.theme != null or config.terminal_theme != null) {
                if (config.theme) |t| config_mod.applyThemeConfig(&self.terminal_theme, t);
                if (config.terminal_theme) |t| config_mod.applyThemeConfig(&self.terminal_theme, t);
                try self.notifyTerminalColorSchemeChanged();
                for (self.terminals.items) |term| {
                    term.setDefaultColors(
                        term_types.Color{
                            .r = self.terminal_theme.foreground.r,
                            .g = self.terminal_theme.foreground.g,
                            .b = self.terminal_theme.foreground.b,
                        },
                        term_types.Color{
                            .r = self.terminal_theme.background.r,
                            .g = self.terminal_theme.background.g,
                            .b = self.terminal_theme.background.b,
                        },
                    );
                    if (self.terminal_theme.ansi_colors) |ansi| {
                        var colors: [16]term_types.Color = undefined;
                        for (ansi, 0..) |c, i| {
                            colors[i] = term_types.Color{ .r = c.r, .g = c.g, .b = c.b };
                        }
                        term.setAnsiColors(colors);
                    }
                    term.markDirty();
                }
            }
            self.needs_redraw = true;
        }

        self.editor_wrap = config.editor_wrap orelse self.editor_wrap;
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
            try applyRendererFontRenderingConfig(self.shell, &config, true);
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

        if (self.app_mode == .font_sample) {
            if (self.font_sample_view) |*view| {
                view.draw(shell);
            }
            if (self.font_sample_close_pending) {
                if (self.font_sample_screenshot_path) |path| {
                    const screenshot_w = parseEnvI32("ZIDE_FONT_SAMPLE_SCREENSHOT_WIDTH", 0);
                    const screenshot_h = parseEnvI32("ZIDE_FONT_SAMPLE_SCREENSHOT_HEIGHT", 0);
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

        if (self.app_mode == .ide) {
            shell.setTheme(self.app_theme);
            // Draw options bar
            self.options_bar.draw(shell, layout.window.width);

            // Draw tab bar
            tab_tooltip = self.tab_bar.draw(shell, layout.tab_bar.x, layout.tab_bar.y, layout.tab_bar.width);
        }

        // Draw editor
        if (self.app_mode != .terminal and self.editors.items.len > 0) {
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
        if (self.app_mode != .editor and self.show_terminal and self.terminals.items.len > 0) {
            const term_y = layout.terminal.y;

            // Terminal separator
            if (self.app_mode == .ide) {
                shell.setTheme(self.app_theme);
                shell.drawRect(@intFromFloat(layout.terminal.x), @intFromFloat(term_y), @intFromFloat(layout.terminal.width), 2, self.app_theme.ui_border);
            }

            shell.setTheme(self.terminal_theme);
            var term_widget = &self.terminal_widgets.items[0];
            const term_offset_y: f32 = if (self.app_mode == .ide) 2 else 0;
            const term_height = if (self.app_mode == .ide) @max(0, layout.terminal.height - 2) else layout.terminal.height;
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

        if (self.app_mode == .ide) {
            shell.setTheme(self.app_theme);
            // Draw side navigation bar (covers terminal icon overflow)
            self.side_nav.draw(shell, layout.side_nav.height, layout.side_nav.y);
        }

        // Draw status bar LAST so it spans full width over everything
        if (self.app_mode == .ide and self.editors.items.len > 0) {
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

        shell.endFrame();
    }
};

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    installSignalHandlers();

    const app_mode = parseAppMode(allocator);
    var app = try AppState.init(allocator, app_mode);
    defer app.deinit();

    try app.run();
}

fn parseAppMode(allocator: std.mem.Allocator) AppMode {
    const args = std.process.argsAlloc(allocator) catch return .ide;
    defer std.process.argsFree(allocator, args);

    var i: usize = 1;
    while (i < args.len) : (i += 1) {
        const arg = args[i];
        if (std.mem.eql(u8, arg, "--terminal") or std.mem.eql(u8, arg, "terminal")) {
            return .terminal;
        }
        if (std.mem.eql(u8, arg, "--editor") or std.mem.eql(u8, arg, "editor")) {
            return .editor;
        }
        if (std.mem.eql(u8, arg, "--ide") or std.mem.eql(u8, arg, "ide")) {
            return .ide;
        }
        if (std.mem.startsWith(u8, arg, "--mode=")) {
            const value = arg["--mode=".len..];
            if (modeFromArg(value)) |mode| return mode;
        } else if (std.mem.eql(u8, arg, "--mode") and i + 1 < args.len) {
            i += 1;
            if (modeFromArg(args[i])) |mode| return mode;
        }
    }

    return .ide;
}

fn modeFromArg(value: []const u8) ?AppMode {
    if (std.mem.eql(u8, value, "terminal")) return .terminal;
    if (std.mem.eql(u8, value, "editor")) return .editor;
    if (std.mem.eql(u8, value, "ide")) return .ide;
    if (std.mem.eql(u8, value, "font") or std.mem.eql(u8, value, "fonts") or std.mem.eql(u8, value, "font-sample")) return .font_sample;
    return null;
}

fn parseEnvU64(env_key: [:0]const u8, default_value: u64) u64 {
    const raw = std.c.getenv(env_key) orelse return default_value;
    const slice = std.mem.sliceTo(raw, 0);
    if (slice.len == 0) return default_value;
    return std.fmt.parseInt(u64, slice, 10) catch default_value;
}

fn parseEnvI32(env_key: [:0]const u8, default_value: i32) i32 {
    const raw = std.c.getenv(env_key) orelse return default_value;
    const slice = std.mem.sliceTo(raw, 0);
    if (slice.len == 0) return default_value;
    const parsed = std.fmt.parseInt(i32, slice, 10) catch return default_value;
    return if (parsed > 0) parsed else default_value;
}

fn parseEnvBool(env_key: [:0]const u8) ?bool {
    const raw = std.c.getenv(env_key) orelse return null;
    const slice = std.mem.sliceTo(raw, 0);
    if (slice.len == 0) return null;
    if (std.mem.eql(u8, slice, "1") or std.ascii.eqlIgnoreCase(slice, "true") or std.ascii.eqlIgnoreCase(slice, "yes") or std.ascii.eqlIgnoreCase(slice, "on")) return true;
    if (std.mem.eql(u8, slice, "0") or std.ascii.eqlIgnoreCase(slice, "false") or std.ascii.eqlIgnoreCase(slice, "no") or std.ascii.eqlIgnoreCase(slice, "off")) return false;
    return null;
}

fn envSlice(env_key: [:0]const u8) ?[]const u8 {
    const raw = std.c.getenv(env_key) orelse return null;
    const slice = std.mem.sliceTo(raw, 0);
    if (slice.len == 0) return null;
    return slice;
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

test "AppState.isDarkTheme classifies background luma" {
    var dark_theme = app_shell.Theme{};
    dark_theme.background = .{ .r = 20, .g = 22, .b = 26 };
    try std.testing.expect(AppState.isDarkTheme(&dark_theme));

    var light_theme = app_shell.Theme{};
    light_theme.background = .{ .r = 245, .g = 245, .b = 245 };
    try std.testing.expect(!AppState.isDarkTheme(&light_theme));
}

test "search panel command maps navigation keys" {
    const allocator = std.testing.allocator;
    var batch = shared_types.input.InputBatch.init(allocator);
    defer batch.deinit();

    batch.key_pressed[@intFromEnum(shared_types.input.Key.enter)] = true;
    try std.testing.expectEqual(AppState.SearchPanelCommand.next, AppState.searchPanelCommand(&batch));

    batch.clear();
    batch.key_pressed[@intFromEnum(shared_types.input.Key.f3)] = true;
    batch.mods.shift = true;
    try std.testing.expectEqual(AppState.SearchPanelCommand.prev, AppState.searchPanelCommand(&batch));

    batch.clear();
    batch.key_pressed[@intFromEnum(shared_types.input.Key.escape)] = true;
    try std.testing.expectEqual(AppState.SearchPanelCommand.close, AppState.searchPanelCommand(&batch));

    batch.clear();
    batch.key_repeated[@intFromEnum(shared_types.input.Key.backspace)] = true;
    try std.testing.expectEqual(AppState.SearchPanelCommand.backspace, AppState.searchPanelCommand(&batch));
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

    try std.testing.expect(try AppState.appendSearchPanelTextEvents(allocator, &query, &batch));
    try std.testing.expectEqualStrings("a\xC3\xA9", query.items);
}

test "visual extend action helper maps routed editor actions" {
    try std.testing.expectEqual(@as(?i32, -1), AppState.visualExtendDeltaForAction(.editor_extend_up));
    try std.testing.expectEqual(@as(?i32, 1), AppState.visualExtendDeltaForAction(.editor_extend_down));
    try std.testing.expectEqual(@as(?i32, null), AppState.visualExtendDeltaForAction(.editor_extend_right));
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
    try app.openSearchPanel(editor);

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

    try app.openSearchPanel(editor);
    try app.search_panel.query.appendSlice(allocator, "beta");
    try app.syncEditorSearchQuery(editor);
    app.closeSearchPanel();

    try std.testing.expect(!app.search_panel.active);
    try std.testing.expectEqualStrings("beta", app.search_panel.query.items);

    app.search_panel.query.clearRetainingCapacity();
    try app.search_panel.query.appendSlice(allocator, "junk");
    try app.openSearchPanel(editor);

    try std.testing.expect(app.search_panel.active);
    try std.testing.expectEqualStrings("beta", app.search_panel.query.items);
    try std.testing.expectEqualStrings("beta", editor.searchQuery().?);
}
