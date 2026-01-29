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
const input_builder = @import("input/input_builder.zig");

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
};

var sigint_requested = std.atomic.Value(bool).init(false);

fn handleSigint(_: c_int) callconv(.c) void {
    sigint_requested.store(true, .release);
}

fn installSignalHandlers() void {
    if (builtin.os.tag == .windows) return;
    const act = std.posix.Sigaction{
        .handler = .{ .handler = handleSigint },
        .mask = std.posix.sigemptyset(),
        .flags = 0,
    };
    std.posix.sigaction(std.posix.SIG.INT, &act, null);
}

const AppState = struct {
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

    // Current focus
    active_tab: usize,
    active_kind: enum { editor, terminal },

    // UI state
    mode: []const u8,
    show_terminal: bool,
    terminal_height: f32,

    // Dirty tracking for efficient rendering
    needs_redraw: bool,
    idle_frames: u32, // Count frames without activity for adaptive sleep
    last_mouse_pos: app_shell.MousePos,
    resizing_terminal: bool,
    resize_start_y: f32,
    resize_start_height: f32,
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
            .theme = null,
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

        const shell = try Shell.init(allocator, 1280, 720, "Zide - Zig IDE");
        errdefer shell.deinit(allocator);
        if (config.theme) |theme_config| {
            var theme = shell.theme().*;
            config_mod.applyThemeConfig(&theme, theme_config);
            shell.setTheme(theme);
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
            .active_tab = 0,
            .active_kind = if (app_mode == .terminal) .terminal else .editor,
            .mode = "NORMAL",
            .show_terminal = app_mode == .terminal,
            .terminal_height = 200,
            .needs_redraw = true,
            .idle_frames = 0,
            .last_mouse_pos = .{ .x = -1, .y = -1 },
            .resizing_terminal = false,
            .resize_start_y = 0,
            .resize_start_height = 0,
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
        };
        state.applyUiScale();

        return state;
    }

    pub fn deinit(self: *AppState) void {
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
        const cols: u16 = @intCast(@max(80, @divFloor(@as(i32, @intFromFloat(layout.terminal.width)), @as(i32, @intFromFloat(shell.terminalCellWidth())))));
        const rows: u16 = @intCast(@max(24, @divFloor(@as(i32, @intFromFloat(layout.terminal.height)), @as(i32, @intFromFloat(shell.terminalCellHeight())))));
        const theme = shell.theme();

        const term = try TerminalSession.init(self.allocator, rows, cols);
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
        term.setCellSize(
            @intFromFloat(shell.terminalCellWidth()),
            @intFromFloat(shell.terminalCellHeight()),
        );
        try term.start(null);
        try self.terminals.append(self.allocator, term);
        try self.terminal_widgets.append(self.allocator, TerminalWidget.init(term));

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

    fn refreshTerminalSizing(self: *AppState) !void {
        if (self.terminals.items.len == 0) return;
        const shell = self.shell;
        const width = @as(f32, @floatFromInt(shell.width()));
        const height = @as(f32, @floatFromInt(shell.height()));
        const layout = self.computeLayout(width, height);
        const effective_height = if (self.app_mode == .ide and !self.show_terminal) self.terminal_height else layout.terminal.height;
        const cols: u16 = @intCast(@max(1, @divFloor(@as(i32, @intFromFloat(layout.terminal.width)), @as(i32, @intFromFloat(shell.terminalCellWidth())))));
        const rows: u16 = @intCast(@max(1, @divFloor(@as(i32, @intFromFloat(effective_height)), @as(i32, @intFromFloat(shell.terminalCellHeight())))));
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
        self.options_bar.updateInput(self.last_input);
        self.tab_bar.updateInput(self.last_input);
        self.side_nav.updateInput(self.last_input);
        self.status_bar.updateInput(self.last_input);
        const now = app_shell.getTime();
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
            if (self.terminals.items.len > 0) {
                const term = self.terminals.items[0];
                const width = @as(f32, @floatFromInt(shell.width()));
                const height = @as(f32, @floatFromInt(shell.height()));
                const layout = self.computeLayout(width, height);
                const effective_height = if (self.app_mode == .ide and !self.show_terminal) self.terminal_height else layout.terminal.height;
                const cols: u16 = @intCast(@max(1, @divFloor(@as(i32, @intFromFloat(layout.terminal.width)), @as(i32, @intFromFloat(shell.terminalCellWidth())))));
                const rows: u16 = @intCast(@max(1, @divFloor(@as(i32, @intFromFloat(effective_height)), @as(i32, @intFromFloat(shell.terminalCellHeight())))));
                term.setCellSize(
                    @intFromFloat(shell.terminalCellWidth()),
                    @intFromFloat(shell.terminalCellHeight()),
                );
                try term.resize(rows, cols);
            }
            self.needs_redraw = true;
        }

        const width = @as(f32, @floatFromInt(shell.width()));
        const height = @as(f32, @floatFromInt(shell.height()));
        const layout = self.computeLayout(width, height);

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
                        const cols: u16 = @intCast(@max(1, @divFloor(@as(i32, @intFromFloat(layout.terminal.width)), @as(i32, @intFromFloat(shell.terminalCellWidth())))));
                        const rows: u16 = @intCast(@max(1, @divFloor(@as(i32, @intFromFloat(self.terminal_height)), @as(i32, @intFromFloat(shell.terminalCellHeight())))));
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

        const ctrl = input_batch.mods.ctrl;

        // Global shortcuts
        if (self.app_mode != .terminal and ctrl and input_batch.keyPressed(.n)) {
            try self.newEditor();
            self.needs_redraw = true;
            self.metrics.noteInput(now);
            return;
        }

        if (ctrl and (input_batch.keyPressed(.equal) or input_batch.keyPressed(.kp_add))) {
            if (shell.queueUserZoom(0.1, now)) {
                self.metrics.noteInput(now);
            }
            return;
        }
        if (ctrl and (input_batch.keyPressed(.minus) or input_batch.keyPressed(.kp_subtract))) {
            if (shell.queueUserZoom(-0.1, now)) {
                self.metrics.noteInput(now);
            }
            return;
        }
        if (ctrl and input_batch.keyPressed(.zero)) {
            if (shell.resetUserZoomTarget(now)) {
                self.metrics.noteInput(now);
            }
            return;
        }

        // Toggle terminal with Ctrl+`
        if (self.app_mode == .ide and ctrl and input_batch.keyPressed(.grave)) {
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
        if (self.app_mode != .terminal and self.active_kind == .editor and self.editors.items.len > 0) {
            const editor_idx = @min(self.active_tab, self.editors.items.len - 1);
            var widget = EditorWidget.initWithCache(self.editors.items[editor_idx], &self.editor_cluster_cache, self.editor_wrap);
            if (try widget.handleInput(shell, layout.editor.height, input_batch)) {
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
            if (self.active_kind == .terminal) {
                if (try term_widget.handleInput(
                    shell,
                    term_x,
                    term_y_draw,
                    layout.terminal.width,
                    term_draw_height,
                    true,
                    &self.terminal_scroll_dragging,
                    &self.terminal_scroll_grab_offset,
                    input_batch,
                )) {
                    self.needs_redraw = true;
                    self.metrics.noteInput(now);
                }
                if (term_widget.takePendingOpenPath()) |path| {
                    defer self.allocator.free(path);
                    if (isProbablyTextFile(path)) {
                        try self.openFile(path);
                        self.needs_redraw = true;
                        self.metrics.noteInput(now);
                    }
                }
            } else {
                if (try term_widget.handleInput(
                    shell,
                    term_x,
                    term_y_draw,
                    layout.terminal.width,
                    term_draw_height,
                    false,
                    &self.terminal_scroll_dragging,
                    &self.terminal_scroll_grab_offset,
                    input_batch,
                )) {
                    self.needs_redraw = true;
                    self.metrics.noteInput(now);
                }
                if (term_widget.takePendingOpenPath()) |path| {
                    defer self.allocator.free(path);
                    if (isProbablyTextFile(path)) {
                        try self.openFile(path);
                        self.needs_redraw = true;
                        self.metrics.noteInput(now);
                    }
                }
            }
        }
    }

    fn draw(self: *AppState) void {
        const shell = self.shell;

        shell.beginFrame();

        const width = @as(f32, @floatFromInt(shell.width()));
        const height = @as(f32, @floatFromInt(shell.height()));
        const layout = self.computeLayout(width, height);

        if (self.app_mode == .ide) {
            // Draw options bar
            self.options_bar.draw(shell, layout.window.width);

            // Draw tab bar
            self.tab_bar.draw(shell, layout.tab_bar.x, layout.tab_bar.y, layout.tab_bar.width);
        }

        // Draw editor
        if (self.app_mode != .terminal and self.editors.items.len > 0) {
            const editor_idx = @min(self.active_tab, self.editors.items.len - 1);
            var widget = EditorWidget.initWithCache(self.editors.items[editor_idx], &self.editor_cluster_cache, self.editor_wrap);
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
                shell.drawRect(@intFromFloat(layout.terminal.x), @intFromFloat(term_y), @intFromFloat(layout.terminal.width), 2, app_shell.Color.light_gray);
            }

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
            // Draw side navigation bar (covers terminal icon overflow)
            self.side_nav.draw(shell, layout.side_nav.height, layout.side_nav.y);
        }

        // Draw status bar LAST so it spans full width over everything
        if (self.app_mode == .ide and self.editors.items.len > 0) {
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
            );
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
    return null;
}

fn parseEnvU64(env_key: [:0]const u8, default_value: u64) u64 {
    const raw = std.c.getenv(env_key) orelse return default_value;
    const slice = std.mem.sliceTo(raw, 0);
    if (slice.len == 0) return default_value;
    return std.fmt.parseInt(u64, slice, 10) catch default_value;
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

    var editor = try Editor.init(allocator, &grammar_manager);
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
