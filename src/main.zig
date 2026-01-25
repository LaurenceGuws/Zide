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

    pub fn init(allocator: std.mem.Allocator) !*AppState {
        var config = config_mod.loadConfig(allocator) catch |err| blk: {
            std.debug.print("config load error: {any}\n", .{err});
            break :blk config_mod.Config{
                .log_file_filter = null,
                .log_console_filter = null,
                .raylib_log_level = null,
                .editor_wrap = null,
                .editor_highlight_budget = null,
                .editor_width_budget = null,
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

        if (config.raylib_log_level) |level| {
            app_shell.setRaylibLogLevel(level);
        }

        const shell = try Shell.init(allocator, 1280, 720, "Zide - Zig IDE");
        errdefer shell.deinit(allocator);
        _ = try shell.refreshUiScale();
        const app_log = app_logger.logger("app.core");
        app_log.logStdout("logger initialized", .{});
        const metrics_log = app_logger.logger("terminal.metrics");
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
            .active_kind = .editor,
            .mode = "NORMAL",
            .show_terminal = false,
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
        const cols: u16 = @intCast(@max(80, @divFloor(shell.width(), @as(i32, @intFromFloat(shell.terminalCellWidth())))));
        const rows: u16 = @intCast(@max(24, @divFloor(@as(i32, @intFromFloat(self.terminal_height)), @as(i32, @intFromFloat(shell.terminalCellHeight())))));
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
        const cols: u16 = @intCast(@max(1, @divFloor(shell.width(), @as(i32, @intFromFloat(shell.terminalCellWidth())))));
        const rows: u16 = @intCast(@max(1, @divFloor(@as(i32, @intFromFloat(self.terminal_height)), @as(i32, @intFromFloat(shell.terminalCellHeight())))));
        for (self.terminals.items) |term| {
            term.setCellSize(
                @intFromFloat(shell.terminalCellWidth()),
                @intFromFloat(shell.terminalCellHeight()),
            );
            try term.resize(rows, cols);
        }
    }

    pub fn run(self: *AppState) !void {
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

        // Main loop
        while (!self.shell.shouldClose()) {
            // Poll events first (this updates raylib's input state)
            app_shell.pollInputEvents();
            var input_batch = buildInputBatch(self.allocator, self.shell);
            defer input_batch.deinit();

            self.frame_id +|= 1;
            self.editor_cluster_cache.beginFrame(self.frame_id);

            const frame_time = app_shell.getTime();
            self.metrics.beginFrame(frame_time);

            try self.update(&input_batch);

            // Only redraw when something changed
            if (self.needs_redraw) {
                const draw_start = app_shell.getTime();
                self.draw();
                const draw_end = app_shell.getTime();
                self.metrics.recordDraw(draw_start, draw_end);
                if (self.perf_mode and self.perf_frames_done > 0) {
                    const draw_ms = (draw_end - draw_start) * 1000.0;
                    const editor_idx = if (self.editors.items.len > 0) @min(self.active_tab, self.editors.items.len - 1) else 0;
                    if (self.editors.items.len > 0) {
                        const editor = self.editors.items[editor_idx];
                        self.perf_logger.logf(
                            "frame={d} draw_ms={d:.2} scroll_line={d} scroll_row_offset={d} scroll_col={d}",
                            .{ self.perf_frames_done, draw_ms, editor.scroll_line, editor.scroll_row_offset, editor.scroll_col },
                        );
                    } else {
                        self.perf_logger.logf("frame={d} draw_ms={d:.2}", .{ self.perf_frames_done, draw_ms });
                    }
                }
                self.maybeLogMetrics(draw_end);
                self.needs_redraw = false;
                self.idle_frames = 0;
            } else {
                self.idle_frames +|= 1; // Saturating add

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
        const now = app_shell.getTime();
        if (try shell.applyPendingZoom(now)) {
            self.applyUiScale();
            try self.refreshTerminalSizing();
            self.needs_redraw = true;
            self.metrics.noteInput(now);
        }
        // Check for window resize (event-based, works with Wayland)
        if (app_shell.isWindowResized()) {
            shell.setSize(app_shell.getScreenWidth(), app_shell.getScreenHeight());
            if (try shell.refreshUiScale()) {
                self.applyUiScale();
            }
            if (self.terminals.items.len > 0) {
                const term = self.terminals.items[0];
                const width = @as(f32, @floatFromInt(shell.width()));
                const height = @as(f32, @floatFromInt(shell.height()));
                const options_bar_height = self.options_bar.height;
                const tab_bar_height = self.tab_bar.height;
                const status_bar_height = self.status_bar.height;
                const max_terminal_h = @max(0, height - options_bar_height - tab_bar_height - status_bar_height);
                const terminal_h = if (self.show_terminal) @min(self.terminal_height, max_terminal_h) else 0;
                const cols: u16 = @intCast(@max(1, @divFloor(@as(i32, @intFromFloat(width)), @as(i32, @intFromFloat(shell.terminalCellWidth())))));
                const rows: u16 = @intCast(@max(1, @divFloor(@as(i32, @intFromFloat(terminal_h)), @as(i32, @intFromFloat(shell.terminalCellHeight())))));
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
        const options_bar_height = self.options_bar.height;
        const tab_bar_height = self.tab_bar.height;
        const side_nav_width = self.side_nav.width;
        const status_bar_height = self.status_bar.height;
        const max_terminal_h = @max(0, height - options_bar_height - tab_bar_height - status_bar_height);
        const terminal_h = if (self.show_terminal) @min(self.terminal_height, max_terminal_h) else 0;
        const editor_height = @max(0, height - options_bar_height - tab_bar_height - status_bar_height - terminal_h);
        const editor_width = @max(0, width - side_nav_width);

        const layout = layout_types.WidgetLayout{
            .window = .{ .x = 0, .y = 0, .width = width, .height = height },
            .options_bar = .{ .x = 0, .y = 0, .width = width, .height = options_bar_height },
            .tab_bar = .{ .x = side_nav_width, .y = options_bar_height, .width = editor_width, .height = tab_bar_height },
            .side_nav = .{ .x = 0, .y = options_bar_height, .width = side_nav_width, .height = height - status_bar_height - options_bar_height },
            .editor = .{ .x = side_nav_width, .y = options_bar_height + tab_bar_height, .width = editor_width, .height = editor_height },
            .terminal = .{ .x = side_nav_width, .y = height - status_bar_height - terminal_h, .width = editor_width, .height = terminal_h },
            .status_bar = .{ .x = 0, .y = height - status_bar_height, .width = width, .height = status_bar_height },
        };

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
        if (self.show_terminal) {
            const separator_y = layout.terminal.y;
            const hit_zone: f32 = 6;
            const over_separator = mouse.y >= separator_y - hit_zone and mouse.y <= separator_y + hit_zone;

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
                        const cols: u16 = @intCast(@max(1, @divFloor(shell.width(), @as(i32, @intFromFloat(shell.terminalCellWidth())))));
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
        if (ctrl and input_batch.keyPressed(.q)) {
            // Quit - handled by window close
            return;
        }

        if (ctrl and input_batch.keyPressed(.n)) {
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
        if (ctrl and input_batch.keyPressed(.grave)) {
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
        if (self.active_kind == .editor and self.editors.items.len > 0) {
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
        if (self.show_terminal and self.terminals.items.len > 0) {
            const term = self.terminals.items[0];
            var term_widget = &self.terminal_widgets.items[0];

            // Only poll PTY if there's data available (non-blocking check)
            // Skip polling when in deep idle to save CPU
            if (term.hasData()) {
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

        // Calculate layout
        const options_bar_height = self.options_bar.height;
        const tab_bar_height = self.tab_bar.height;
        const side_nav_width = self.side_nav.width;
        const status_bar_height = self.status_bar.height;
        const max_terminal_h = @max(0, height - options_bar_height - tab_bar_height - status_bar_height);
        const terminal_h = if (self.show_terminal) @min(self.terminal_height, max_terminal_h) else 0;
        const editor_height = @max(0, height - options_bar_height - tab_bar_height - status_bar_height - terminal_h);
        const editor_width = @max(0, width - side_nav_width);

        const layout = layout_types.WidgetLayout{
            .window = .{ .x = 0, .y = 0, .width = width, .height = height },
            .options_bar = .{ .x = 0, .y = 0, .width = width, .height = options_bar_height },
            .tab_bar = .{ .x = side_nav_width, .y = options_bar_height, .width = editor_width, .height = tab_bar_height },
            .side_nav = .{ .x = 0, .y = options_bar_height, .width = side_nav_width, .height = height - status_bar_height - options_bar_height },
            .editor = .{ .x = side_nav_width, .y = options_bar_height + tab_bar_height, .width = editor_width, .height = editor_height },
            .terminal = .{ .x = side_nav_width, .y = height - status_bar_height - terminal_h, .width = editor_width, .height = terminal_h },
            .status_bar = .{ .x = 0, .y = height - status_bar_height, .width = width, .height = status_bar_height },
        };
        // Draw options bar
        self.options_bar.draw(shell, layout.window.width);

        // Draw tab bar
        self.tab_bar.draw(shell, layout.tab_bar.x, layout.tab_bar.y, layout.tab_bar.width);

        // Draw editor
        if (self.editors.items.len > 0) {
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
            );
        }

        // Draw terminal if shown
        if (self.show_terminal and self.terminals.items.len > 0) {
            const term_y = layout.terminal.y;

            // Terminal separator
            shell.drawRect(@intFromFloat(layout.terminal.x), @intFromFloat(term_y), @intFromFloat(layout.terminal.width), 2, app_shell.Color.light_gray);

            var term_widget = &self.terminal_widgets.items[0];
            const term_draw_height = @max(0, layout.terminal.height - 2);
            if (layout.terminal.width > 0 and term_draw_height > 0) {
                shell.beginClip(
                    @intFromFloat(layout.terminal.x),
                    @intFromFloat(term_y + 2),
                    @intFromFloat(layout.terminal.width),
                    @intFromFloat(term_draw_height),
                );
            }
            term_widget.draw(shell, layout.terminal.x, term_y + 2, layout.terminal.width, term_draw_height);
            if (layout.terminal.width > 0 and term_draw_height > 0) {
                shell.endClip();
            }
        }

        // Draw side navigation bar (covers terminal icon overflow)
        self.side_nav.draw(shell, layout.side_nav.height, layout.side_nav.y);

        // Draw status bar LAST so it spans full width over everything
        if (self.editors.items.len > 0) {
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

    var app = try AppState.init(allocator);
    defer app.deinit();

    try app.run();
}

fn parseEnvU64(env_key: [:0]const u8, default_value: u64) u64 {
    const raw = std.c.getenv(env_key) orelse return default_value;
    const slice = std.mem.sliceTo(raw, 0);
    if (slice.len == 0) return default_value;
    return std.fmt.parseInt(u64, slice, 10) catch default_value;
}

fn buildInputBatch(allocator: std.mem.Allocator, shell: *app_shell.Shell) shared_types.input.InputBatch {
    var batch = shared_types.input.InputBatch.init(allocator);
    const r = shell.rendererPtr();

    const pos = r.getMousePos();
    batch.mouse_pos = .{ .x = pos.x, .y = pos.y };
    const pos_raw = r.getMousePosRaw();
    batch.mouse_pos_raw = .{ .x = pos_raw.x, .y = pos_raw.y };
    batch.scroll = .{ .x = 0, .y = r.getMouseWheelMove() };

    batch.mouse_down[@intFromEnum(shared_types.input.MouseButton.left)] = r.isMouseButtonDown(app_shell.MOUSE_LEFT);
    batch.mouse_down[@intFromEnum(shared_types.input.MouseButton.middle)] = r.isMouseButtonDown(app_shell.MOUSE_MIDDLE);
    batch.mouse_down[@intFromEnum(shared_types.input.MouseButton.right)] = r.isMouseButtonDown(app_shell.MOUSE_RIGHT);

    batch.mouse_pressed[@intFromEnum(shared_types.input.MouseButton.left)] = r.isMouseButtonPressed(app_shell.MOUSE_LEFT);
    batch.mouse_pressed[@intFromEnum(shared_types.input.MouseButton.middle)] = r.isMouseButtonPressed(app_shell.MOUSE_MIDDLE);
    batch.mouse_pressed[@intFromEnum(shared_types.input.MouseButton.right)] = r.isMouseButtonPressed(app_shell.MOUSE_RIGHT);

    batch.mouse_released[@intFromEnum(shared_types.input.MouseButton.left)] = r.isMouseButtonReleased(app_shell.MOUSE_LEFT);
    batch.mouse_released[@intFromEnum(shared_types.input.MouseButton.middle)] = r.isMouseButtonReleased(app_shell.MOUSE_MIDDLE);
    batch.mouse_released[@intFromEnum(shared_types.input.MouseButton.right)] = r.isMouseButtonReleased(app_shell.MOUSE_RIGHT);

    batch.mods = .{
        .shift = r.isKeyDown(app_shell.KEY_LEFT_SHIFT) or r.isKeyDown(app_shell.KEY_RIGHT_SHIFT),
        .alt = r.isKeyDown(app_shell.KEY_LEFT_ALT) or r.isKeyDown(app_shell.KEY_RIGHT_ALT),
        .ctrl = r.isKeyDown(app_shell.KEY_LEFT_CONTROL) or r.isKeyDown(app_shell.KEY_RIGHT_CONTROL),
        .super = r.isKeyDown(app_shell.KEY_LEFT_SUPER) or r.isKeyDown(app_shell.KEY_RIGHT_SUPER),
    };

    const key_map = [_]struct { key: shared_types.input.Key, raylib: i32 }{
        .{ .key = .enter, .raylib = app_shell.KEY_ENTER },
        .{ .key = .backspace, .raylib = app_shell.KEY_BACKSPACE },
        .{ .key = .tab, .raylib = app_shell.KEY_TAB },
        .{ .key = .escape, .raylib = app_shell.KEY_ESCAPE },
        .{ .key = .up, .raylib = app_shell.KEY_UP },
        .{ .key = .down, .raylib = app_shell.KEY_DOWN },
        .{ .key = .left, .raylib = app_shell.KEY_LEFT },
        .{ .key = .right, .raylib = app_shell.KEY_RIGHT },
        .{ .key = .home, .raylib = app_shell.KEY_HOME },
        .{ .key = .end, .raylib = app_shell.KEY_END },
        .{ .key = .page_up, .raylib = app_shell.KEY_PAGE_UP },
        .{ .key = .page_down, .raylib = app_shell.KEY_PAGE_DOWN },
        .{ .key = .insert, .raylib = app_shell.KEY_INSERT },
        .{ .key = .delete, .raylib = app_shell.KEY_DELETE },
        .{ .key = .a, .raylib = app_shell.KEY_A },
        .{ .key = .b, .raylib = app_shell.KEY_B },
        .{ .key = .c, .raylib = app_shell.KEY_C },
        .{ .key = .d, .raylib = app_shell.KEY_D },
        .{ .key = .e, .raylib = app_shell.KEY_E },
        .{ .key = .f, .raylib = app_shell.KEY_F },
        .{ .key = .g, .raylib = app_shell.KEY_G },
        .{ .key = .h, .raylib = app_shell.KEY_H },
        .{ .key = .i, .raylib = app_shell.KEY_I },
        .{ .key = .j, .raylib = app_shell.KEY_J },
        .{ .key = .k, .raylib = app_shell.KEY_K },
        .{ .key = .l, .raylib = app_shell.KEY_L },
        .{ .key = .m, .raylib = app_shell.KEY_M },
        .{ .key = .n, .raylib = app_shell.KEY_N },
        .{ .key = .o, .raylib = app_shell.KEY_O },
        .{ .key = .p, .raylib = app_shell.KEY_P },
        .{ .key = .q, .raylib = app_shell.KEY_Q },
        .{ .key = .r, .raylib = app_shell.KEY_R },
        .{ .key = .s, .raylib = app_shell.KEY_S },
        .{ .key = .t, .raylib = app_shell.KEY_T },
        .{ .key = .u, .raylib = app_shell.KEY_U },
        .{ .key = .v, .raylib = app_shell.KEY_V },
        .{ .key = .w, .raylib = app_shell.KEY_W },
        .{ .key = .x, .raylib = app_shell.KEY_X },
        .{ .key = .y, .raylib = app_shell.KEY_Y },
        .{ .key = .z, .raylib = app_shell.KEY_Z },
        .{ .key = .zero, .raylib = app_shell.KEY_ZERO },
        .{ .key = .one, .raylib = app_shell.KEY_ONE },
        .{ .key = .two, .raylib = app_shell.KEY_TWO },
        .{ .key = .three, .raylib = app_shell.KEY_THREE },
        .{ .key = .four, .raylib = app_shell.KEY_FOUR },
        .{ .key = .five, .raylib = app_shell.KEY_FIVE },
        .{ .key = .six, .raylib = app_shell.KEY_SIX },
        .{ .key = .seven, .raylib = app_shell.KEY_SEVEN },
        .{ .key = .eight, .raylib = app_shell.KEY_EIGHT },
        .{ .key = .nine, .raylib = app_shell.KEY_NINE },
        .{ .key = .space, .raylib = app_shell.KEY_SPACE },
        .{ .key = .minus, .raylib = app_shell.KEY_MINUS },
        .{ .key = .equal, .raylib = app_shell.KEY_EQUAL },
        .{ .key = .left_bracket, .raylib = app_shell.KEY_LEFT_BRACKET },
        .{ .key = .right_bracket, .raylib = app_shell.KEY_RIGHT_BRACKET },
        .{ .key = .backslash, .raylib = app_shell.KEY_BACKSLASH },
        .{ .key = .semicolon, .raylib = app_shell.KEY_SEMICOLON },
        .{ .key = .apostrophe, .raylib = app_shell.KEY_APOSTROPHE },
        .{ .key = .comma, .raylib = app_shell.KEY_COMMA },
        .{ .key = .period, .raylib = app_shell.KEY_PERIOD },
        .{ .key = .slash, .raylib = app_shell.KEY_SLASH },
        .{ .key = .grave, .raylib = app_shell.KEY_GRAVE },
        .{ .key = .kp_0, .raylib = app_shell.KEY_KP_0 },
        .{ .key = .kp_1, .raylib = app_shell.KEY_KP_1 },
        .{ .key = .kp_2, .raylib = app_shell.KEY_KP_2 },
        .{ .key = .kp_3, .raylib = app_shell.KEY_KP_3 },
        .{ .key = .kp_4, .raylib = app_shell.KEY_KP_4 },
        .{ .key = .kp_5, .raylib = app_shell.KEY_KP_5 },
        .{ .key = .kp_6, .raylib = app_shell.KEY_KP_6 },
        .{ .key = .kp_7, .raylib = app_shell.KEY_KP_7 },
        .{ .key = .kp_8, .raylib = app_shell.KEY_KP_8 },
        .{ .key = .kp_9, .raylib = app_shell.KEY_KP_9 },
        .{ .key = .kp_decimal, .raylib = app_shell.KEY_KP_DECIMAL },
        .{ .key = .kp_divide, .raylib = app_shell.KEY_KP_DIVIDE },
        .{ .key = .kp_multiply, .raylib = app_shell.KEY_KP_MULTIPLY },
        .{ .key = .kp_subtract, .raylib = app_shell.KEY_KP_SUBTRACT },
        .{ .key = .kp_add, .raylib = app_shell.KEY_KP_ADD },
        .{ .key = .kp_enter, .raylib = app_shell.KEY_KP_ENTER },
        .{ .key = .kp_equal, .raylib = app_shell.KEY_KP_EQUAL },
    };

    for (key_map) |entry| {
        batch.key_down[@intFromEnum(entry.key)] = r.isKeyDown(entry.raylib);
        batch.key_pressed[@intFromEnum(entry.key)] = r.isKeyPressed(entry.raylib);
        batch.key_repeated[@intFromEnum(entry.key)] = r.isKeyRepeated(entry.raylib);
    }

    while (r.getKeyPressed()) |raw_key| {
        if (inputKeyFromRaylib(raw_key)) |key| {
            batch.append(.{
                .key = .{
                    .key = key,
                    .mods = batch.mods,
                    .repeated = false,
                    .pressed = true,
                },
            }) catch {};
        }
    }

    while (r.getCharPressed()) |char| {
        batch.append(.{ .text = .{ .codepoint = char } }) catch {};
    }

    return batch;
}

fn inputKeyFromRaylib(key: i32) ?shared_types.input.Key {
    return switch (key) {
        app_shell.KEY_ENTER => .enter,
        app_shell.KEY_BACKSPACE => .backspace,
        app_shell.KEY_TAB => .tab,
        app_shell.KEY_ESCAPE => .escape,
        app_shell.KEY_UP => .up,
        app_shell.KEY_DOWN => .down,
        app_shell.KEY_LEFT => .left,
        app_shell.KEY_RIGHT => .right,
        app_shell.KEY_HOME => .home,
        app_shell.KEY_END => .end,
        app_shell.KEY_PAGE_UP => .page_up,
        app_shell.KEY_PAGE_DOWN => .page_down,
        app_shell.KEY_INSERT => .insert,
        app_shell.KEY_DELETE => .delete,
        app_shell.KEY_A => .a,
        app_shell.KEY_B => .b,
        app_shell.KEY_C => .c,
        app_shell.KEY_D => .d,
        app_shell.KEY_E => .e,
        app_shell.KEY_F => .f,
        app_shell.KEY_G => .g,
        app_shell.KEY_H => .h,
        app_shell.KEY_I => .i,
        app_shell.KEY_J => .j,
        app_shell.KEY_K => .k,
        app_shell.KEY_L => .l,
        app_shell.KEY_M => .m,
        app_shell.KEY_N => .n,
        app_shell.KEY_O => .o,
        app_shell.KEY_P => .p,
        app_shell.KEY_Q => .q,
        app_shell.KEY_R => .r,
        app_shell.KEY_S => .s,
        app_shell.KEY_T => .t,
        app_shell.KEY_U => .u,
        app_shell.KEY_V => .v,
        app_shell.KEY_W => .w,
        app_shell.KEY_X => .x,
        app_shell.KEY_Y => .y,
        app_shell.KEY_Z => .z,
        app_shell.KEY_ZERO => .zero,
        app_shell.KEY_ONE => .one,
        app_shell.KEY_TWO => .two,
        app_shell.KEY_THREE => .three,
        app_shell.KEY_FOUR => .four,
        app_shell.KEY_FIVE => .five,
        app_shell.KEY_SIX => .six,
        app_shell.KEY_SEVEN => .seven,
        app_shell.KEY_EIGHT => .eight,
        app_shell.KEY_NINE => .nine,
        app_shell.KEY_SPACE => .space,
        app_shell.KEY_MINUS => .minus,
        app_shell.KEY_EQUAL => .equal,
        app_shell.KEY_LEFT_BRACKET => .left_bracket,
        app_shell.KEY_RIGHT_BRACKET => .right_bracket,
        app_shell.KEY_BACKSLASH => .backslash,
        app_shell.KEY_SEMICOLON => .semicolon,
        app_shell.KEY_APOSTROPHE => .apostrophe,
        app_shell.KEY_COMMA => .comma,
        app_shell.KEY_PERIOD => .period,
        app_shell.KEY_SLASH => .slash,
        app_shell.KEY_GRAVE => .grave,
        app_shell.KEY_KP_0 => .kp_0,
        app_shell.KEY_KP_1 => .kp_1,
        app_shell.KEY_KP_2 => .kp_2,
        app_shell.KEY_KP_3 => .kp_3,
        app_shell.KEY_KP_4 => .kp_4,
        app_shell.KEY_KP_5 => .kp_5,
        app_shell.KEY_KP_6 => .kp_6,
        app_shell.KEY_KP_7 => .kp_7,
        app_shell.KEY_KP_8 => .kp_8,
        app_shell.KEY_KP_9 => .kp_9,
        app_shell.KEY_KP_DECIMAL => .kp_decimal,
        app_shell.KEY_KP_DIVIDE => .kp_divide,
        app_shell.KEY_KP_MULTIPLY => .kp_multiply,
        app_shell.KEY_KP_SUBTRACT => .kp_subtract,
        app_shell.KEY_KP_ADD => .kp_add,
        app_shell.KEY_KP_ENTER => .kp_enter,
        app_shell.KEY_KP_EQUAL => .kp_equal,
        else => null,
    };
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
