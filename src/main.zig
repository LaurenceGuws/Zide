const std = @import("std");
const builtin = @import("builtin");

// Editor modules
const editor_mod = @import("editor/editor.zig");
const buffer_mod = @import("editor/buffer.zig");
const types = @import("editor/types.zig");
const app_logger = @import("app_logger.zig");
const config_mod = @import("config/lua_config.zig");

// Terminal modules
const terminal_mod = @import("terminal/terminal.zig");
const metrics_mod = @import("terminal/metrics.zig");

// UI modules
const renderer_mod = @import("ui/renderer.zig");
const widgets = @import("ui/widgets.zig");

const Editor = editor_mod.Editor;
const TerminalSession = terminal_mod.TerminalSession;
const Metrics = metrics_mod.Metrics;
const Logger = app_logger.Logger;
const Renderer = renderer_mod.Renderer;
const TabBar = widgets.TabBar;
const OptionsBar = widgets.OptionsBar;
const SideNav = widgets.SideNav;
const StatusBar = widgets.StatusBar;
const EditorWidget = widgets.EditorWidget;
const TerminalWidget = widgets.TerminalWidget;

const AppState = struct {
    allocator: std.mem.Allocator,
    renderer: *Renderer,
    options_bar: OptionsBar,
    tab_bar: TabBar,
    side_nav: SideNav,
    status_bar: StatusBar,

    // Active views
    editors: std.ArrayList(*Editor),
    terminals: std.ArrayList(*TerminalSession),

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
    last_mouse_pos: renderer_mod.MousePos,
    resizing_terminal: bool,
    resize_start_y: f32,
    resize_start_height: f32,
    mouse_debug: bool,
    terminal_scroll_dragging: bool,
    terminal_scroll_grab_offset: f32,
    last_mouse_redraw_time: f64,
    metrics: Metrics,
    metrics_logger: Logger,
    app_logger: Logger,
    last_metrics_log_time: f64,

    pub fn init(allocator: std.mem.Allocator) !*AppState {
        var config = config_mod.loadConfig(allocator) catch |err| blk: {
            std.debug.print("config load error: {any}\n", .{err});
            break :blk config_mod.Config{
                .log_file_filter = null,
                .log_console_filter = null,
                .raylib_log_level = null,
            };
        };
        defer config_mod.freeConfig(allocator, &config);

        if (config.raylib_log_level) |level| {
            renderer_mod.setRaylibLogLevel(level);
        }

        const renderer = try Renderer.init(allocator, 1280, 720, "Zide - Zig IDE");
        errdefer renderer.deinit();
        try app_logger.init();
        if (config.log_file_filter) |filter| {
            app_logger.setFileFilterString(filter) catch {};
        }
        if (config.log_console_filter) |filter| {
            app_logger.setConsoleFilterString(filter) catch {};
        }
        const app_log = app_logger.logger("app.core");
        app_log.logStdout("logger initialized", .{});
        const metrics_log = app_logger.logger("terminal.metrics");

        const state = try allocator.create(AppState);
        state.* = .{
            .allocator = allocator,
            .renderer = renderer,
            .options_bar = .{},
            .tab_bar = TabBar.init(allocator),
            .side_nav = .{},
            .status_bar = .{},
            .editors = .empty,
            .terminals = .empty,
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
            .metrics = Metrics.init(),
            .metrics_logger = metrics_log,
            .app_logger = app_log,
            .last_metrics_log_time = 0,
        };

        return state;
    }

    pub fn deinit(self: *AppState) void {
        for (self.editors.items) |e| {
            e.deinit();
        }
        self.editors.deinit(self.allocator);

        for (self.terminals.items) |t| {
            t.deinit();
        }
        self.terminals.deinit(self.allocator);

        self.tab_bar.deinit();
        self.renderer.deinit();
        app_logger.deinit();
        self.allocator.destroy(self);
    }

    pub fn newEditor(self: *AppState) !void {
        const editor = try Editor.init(self.allocator);
        try self.editors.append(self.allocator, editor);
        try self.tab_bar.addTab("untitled", .editor);
        self.active_tab = self.tab_bar.tabs.items.len - 1;
        self.active_kind = .editor;
    }

    pub fn openFile(self: *AppState, path: []const u8) !void {
        const editor = try Editor.init(self.allocator);
        try editor.openFile(path);
        try self.editors.append(self.allocator, editor);

        // Extract filename for tab title
        const filename = std.fs.path.basename(path);
        try self.tab_bar.addTab(filename, .editor);
        self.active_tab = self.tab_bar.tabs.items.len - 1;
        self.active_kind = .editor;
    }

    pub fn newTerminal(self: *AppState) !void {
        // Calculate terminal size based on UI
        const cols: u16 = @intCast(@max(80, @divFloor(self.renderer.width, @as(i32, @intFromFloat(self.renderer.terminal_cell_width)))));
        const rows: u16 = @intCast(@max(24, @divFloor(@as(i32, @intFromFloat(self.terminal_height)), @as(i32, @intFromFloat(self.renderer.terminal_cell_height)))));

        const term = try TerminalSession.init(self.allocator, rows, cols);
        term.setCellSize(
            @intFromFloat(self.renderer.terminal_cell_width),
            @intFromFloat(self.renderer.terminal_cell_height),
        );
        try term.start(null);
        try self.terminals.append(self.allocator, term);

        self.show_terminal = true;
    }

    pub fn run(self: *AppState) !void {
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

        // Main loop
        while (!self.renderer.shouldClose()) {
            // Poll events first (this updates raylib's input state)
            renderer_mod.pollInputEvents();

            const frame_time = renderer_mod.getTime();
            self.metrics.beginFrame(frame_time);

            try self.update();

            // Only redraw when something changed
            if (self.needs_redraw) {
                const draw_start = renderer_mod.getTime();
                self.draw();
                const draw_end = renderer_mod.getTime();
                self.metrics.recordDraw(draw_start, draw_end);
                self.maybeLogMetrics(draw_end);
                self.needs_redraw = false;
                self.idle_frames = 0;
            } else {
                self.idle_frames +|= 1; // Saturating add

                // Adaptive sleep: longer sleep when idle longer
                // - Startup grace period: stay responsive for first 3 seconds
                // - Active: 16ms (~60fps responsiveness)
                // - Idle: up to 100ms (~10fps, saves CPU)
                const uptime = renderer_mod.getTime();
                const sleep_ms: f64 = if (uptime < 3.0)
                    0.016 // Startup: stay fully responsive
                else if (self.idle_frames < 10)
                    0.016 // First 10 idle frames: stay responsive
                else if (self.idle_frames < 60)
                    0.033 // ~30fps check rate
                else
                    0.100; // Deep idle: 10fps check rate

                renderer_mod.waitTime(sleep_ms);
                self.maybeLogMetrics(renderer_mod.getTime());
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

    fn update(self: *AppState) !void {
        const r = self.renderer;
        const now = renderer_mod.getTime();

        // Check for window resize (event-based, works with Wayland)
        if (renderer_mod.isWindowResized()) {
            r.width = renderer_mod.getScreenWidth();
            r.height = renderer_mod.getScreenHeight();
            if (self.terminals.items.len > 0) {
                const term = self.terminals.items[0];
                const width = @as(f32, @floatFromInt(r.width));
                const height = @as(f32, @floatFromInt(r.height));
                const options_bar_height = self.options_bar.height;
                const tab_bar_height = self.tab_bar.height;
                const status_bar_height = self.status_bar.height;
                const max_terminal_h = @max(0, height - options_bar_height - tab_bar_height - status_bar_height);
                const terminal_h = if (self.show_terminal) @min(self.terminal_height, max_terminal_h) else 0;
                const cols: u16 = @intCast(@max(1, @divFloor(@as(i32, @intFromFloat(width)), @as(i32, @intFromFloat(r.terminal_cell_width)))));
                const rows: u16 = @intCast(@max(1, @divFloor(@as(i32, @intFromFloat(terminal_h)), @as(i32, @intFromFloat(r.terminal_cell_height)))));
                term.setCellSize(
                    @intFromFloat(r.terminal_cell_width),
                    @intFromFloat(r.terminal_cell_height),
                );
                try term.resize(rows, cols);
            }
            self.needs_redraw = true;
        }

        const width = @as(f32, @floatFromInt(r.width));
        const height = @as(f32, @floatFromInt(r.height));
        const options_bar_height = self.options_bar.height;
        const tab_bar_height = self.tab_bar.height;
        const side_nav_width = self.side_nav.width;
        const status_bar_height = self.status_bar.height;
        const max_terminal_h = @max(0, height - options_bar_height - tab_bar_height - status_bar_height);
        const terminal_h = if (self.show_terminal) @min(self.terminal_height, max_terminal_h) else 0;
        const editor_height = @max(0, height - options_bar_height - tab_bar_height - status_bar_height - terminal_h);
        const editor_width = @max(0, width - side_nav_width);

        // Check for mouse activity (doesn't consume input)
        const mouse = r.getMousePos();
        const mouse_down = r.isMouseButtonDown(renderer_mod.MOUSE_LEFT);
        const mouse_moved = mouse.x != self.last_mouse_pos.x or mouse.y != self.last_mouse_pos.y;
        const wheel = r.getMouseWheelMove();
        const mouse_pressed = r.isMouseButtonPressed(renderer_mod.MOUSE_LEFT) or
            r.isMouseButtonPressed(renderer_mod.MOUSE_RIGHT);
        const has_mouse_action = mouse_pressed or wheel != 0 or mouse_down;

        const terminal_visible = self.show_terminal and terminal_h > 0;
        const term_y = height - status_bar_height - terminal_h;
        const in_terminal_area = terminal_visible and mouse.y >= term_y;

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
        if (mouse_moved) {
            self.last_mouse_pos = mouse;
        }

        // Terminal resize by dragging separator
        if (self.show_terminal) {
            const separator_y = height - status_bar_height - terminal_h;
            const hit_zone: f32 = 6;
            const over_separator = mouse.y >= separator_y - hit_zone and mouse.y <= separator_y + hit_zone;

            if (!self.resizing_terminal and mouse_down and over_separator) {
                self.resizing_terminal = true;
                self.resize_start_y = mouse.y;
                self.resize_start_height = terminal_h;
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
                        const cols: u16 = @intCast(@max(1, @divFloor(self.renderer.width, @as(i32, @intFromFloat(self.renderer.terminal_cell_width)))));
                        const rows: u16 = @intCast(@max(1, @divFloor(@as(i32, @intFromFloat(self.terminal_height)), @as(i32, @intFromFloat(self.renderer.terminal_cell_height)))));
                        term.setCellSize(
                            @intFromFloat(self.renderer.terminal_cell_width),
                            @intFromFloat(self.renderer.terminal_cell_height),
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

        const ctrl = r.isKeyDown(renderer_mod.KEY_LEFT_CONTROL) or r.isKeyDown(renderer_mod.KEY_RIGHT_CONTROL);

        // Global shortcuts
        if (ctrl and r.isKeyPressed(renderer_mod.KEY_Q)) {
            // Quit - handled by window close
            return;
        }

        if (ctrl and r.isKeyPressed(renderer_mod.KEY_N)) {
            try self.newEditor();
            self.needs_redraw = true;
            self.metrics.noteInput(now);
            return;
        }

        // Toggle terminal with Ctrl+`
        if (ctrl and r.isKeyPressed(renderer_mod.KEY_GRAVE)) {
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
        if (r.isMouseButtonPressed(renderer_mod.MOUSE_LEFT)) {
            const tab_bar_y = self.options_bar.height;
            if (self.tab_bar.handleClick(mouse.x, mouse.y, self.side_nav.width, tab_bar_y)) {
                // Tab was clicked
                self.active_tab = self.tab_bar.active_index;
                self.needs_redraw = true;
                self.metrics.noteInput(now);
            }

            const editor_x = side_nav_width;
            const editor_y = options_bar_height + tab_bar_height;
            const in_editor = mouse.x >= editor_x and mouse.x <= editor_x + editor_width and
                mouse.y >= editor_y and mouse.y <= editor_y + editor_height;

            const in_terminal = terminal_h > 0 and mouse.y >= term_y and mouse.y <= term_y + terminal_h;

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
                        r.mouse_scale.x,
                    },
                );
            }
        }

        // Update active view
        if (self.active_kind == .editor and self.editors.items.len > 0) {
            const editor_idx = @min(self.active_tab, self.editors.items.len - 1);
            var widget = EditorWidget.init(self.editors.items[editor_idx]);
            if (try widget.handleInput(r)) {
                self.needs_redraw = true;
                self.metrics.noteInput(now);
            }
            if (r.isMouseButtonPressed(renderer_mod.MOUSE_LEFT)) {
                const editor_x = side_nav_width;
                const editor_y = options_bar_height + tab_bar_height;
                if (widget.handleMouseClick(r, editor_x, editor_y, editor_width, editor_height, mouse.x, mouse.y)) {
                    self.needs_redraw = true;
                    self.metrics.noteInput(now);
                }
            }
        }

        // Update terminal if shown
        if (self.show_terminal and self.terminals.items.len > 0) {
            const term = self.terminals.items[0];

            // Only poll PTY if there's data available (non-blocking check)
            // Skip polling when in deep idle to save CPU
            if (self.idle_frames < 60 and term.hasData()) {
                try term.poll();
                self.needs_redraw = true;
            }

            // Handle terminal input if focused at bottom
            const term_y_draw = height - status_bar_height - terminal_h + 2;
            const term_x = side_nav_width;
            const term_draw_height = @max(0, terminal_h - 2);
            if (self.active_kind == .terminal) {
                var term_widget = TerminalWidget.init(term);
                if (try term_widget.handleInput(
                    r,
                    term_x,
                    term_y_draw,
                    editor_width,
                    term_draw_height,
                    true,
                    &self.terminal_scroll_dragging,
                    &self.terminal_scroll_grab_offset,
                )) {
                    self.needs_redraw = true;
                    self.metrics.noteInput(now);
                }
            } else {
                var term_widget = TerminalWidget.init(term);
                if (try term_widget.handleInput(
                    r,
                    term_x,
                    term_y_draw,
                    editor_width,
                    term_draw_height,
                    false,
                    &self.terminal_scroll_dragging,
                    &self.terminal_scroll_grab_offset,
                )) {
                    self.needs_redraw = true;
                    self.metrics.noteInput(now);
                }
            }
        }
    }

    fn draw(self: *AppState) void {
        const r = self.renderer;

        r.beginFrame();

        const width = @as(f32, @floatFromInt(r.width));
        const height = @as(f32, @floatFromInt(r.height));

        // Calculate layout
        const options_bar_height = self.options_bar.height;
        const tab_bar_height = self.tab_bar.height;
        const side_nav_width = self.side_nav.width;
        const status_bar_height = self.status_bar.height;
        const max_terminal_h = @max(0, height - options_bar_height - tab_bar_height - status_bar_height);
        const terminal_h = if (self.show_terminal) @min(self.terminal_height, max_terminal_h) else 0;
        const editor_height = @max(0, height - options_bar_height - tab_bar_height - status_bar_height - terminal_h);
        const editor_width = @max(0, width - side_nav_width);

        // Draw options bar
        self.options_bar.draw(r, width);

        // Draw tab bar
        self.tab_bar.draw(r, side_nav_width, options_bar_height, editor_width);

        // Draw editor
        if (self.editors.items.len > 0) {
            const editor_idx = @min(self.active_tab, self.editors.items.len - 1);
            var widget = EditorWidget.init(self.editors.items[editor_idx]);
            if (editor_width > 0 and editor_height > 0) {
                r.beginClip(
                    @intFromFloat(side_nav_width),
                    @intFromFloat(options_bar_height + tab_bar_height),
                    @intFromFloat(editor_width),
                    @intFromFloat(editor_height),
                );
            }
            widget.draw(r, side_nav_width, options_bar_height + tab_bar_height, editor_width, editor_height);
            if (editor_width > 0 and editor_height > 0) {
                r.endClip();
            }
        }

        // Draw terminal if shown
        if (self.show_terminal and self.terminals.items.len > 0) {
            const term_y = height - status_bar_height - terminal_h;

            // Terminal separator
            r.drawRect(@intFromFloat(side_nav_width), @intFromFloat(term_y), @intFromFloat(editor_width), 2, renderer_mod.Color.light_gray);

            var term_widget = TerminalWidget.init(self.terminals.items[0]);
            const term_draw_height = @max(0, terminal_h - 2);
            if (editor_width > 0 and term_draw_height > 0) {
                r.beginClip(
                    @intFromFloat(side_nav_width),
                    @intFromFloat(term_y + 2),
                    @intFromFloat(editor_width),
                    @intFromFloat(term_draw_height),
                );
            }
            term_widget.draw(r, side_nav_width, term_y + 2, editor_width, term_draw_height);
            if (editor_width > 0 and term_draw_height > 0) {
                r.endClip();
            }
        }

        // Draw side navigation bar (covers terminal icon overflow)
        const side_nav_height = height - status_bar_height - options_bar_height;
        self.side_nav.draw(r, side_nav_height, options_bar_height);

        // Draw status bar LAST so it spans full width over everything
        if (self.editors.items.len > 0) {
            const editor_idx = @min(self.active_tab, self.editors.items.len - 1);
            const editor = self.editors.items[editor_idx];
            self.status_bar.draw(
                r,
                width,
                height - status_bar_height,
                self.mode,
                editor.file_path,
                editor.cursor.line,
                editor.cursor.col,
                editor.modified,
            );
        }

        r.endFrame();
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

// Tests
test "buffer basic operations" {
    const allocator = std.testing.allocator;

    const buffer = try buffer_mod.createBuffer(allocator, "Hello, World!");
    defer buffer_mod.destroyBuffer(buffer);

    try std.testing.expectEqual(@as(usize, 13), buffer_mod.totalLen(buffer));

    // Test insert
    try buffer_mod.insertBytes(buffer, 7, "Zig ");
    try std.testing.expectEqual(@as(usize, 17), buffer_mod.totalLen(buffer));

    // Test read
    var out: [32]u8 = undefined;
    const len = buffer_mod.readRange(buffer, 0, &out);
    try std.testing.expectEqualStrings("Hello, Zig World!", out[0..len]);
}

test "editor cursor movement" {
    const allocator = std.testing.allocator;

    var editor = try Editor.init(allocator);
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
