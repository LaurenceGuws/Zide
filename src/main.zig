const std = @import("std");
const builtin = @import("builtin");

// Editor modules
const editor_mod = @import("editor/editor.zig");
const buffer_mod = @import("editor/buffer.zig");
const types = @import("editor/types.zig");

// Terminal modules
const terminal_mod = @import("terminal/terminal.zig");

// UI modules
const renderer_mod = @import("ui/renderer.zig");
const widgets = @import("ui/widgets.zig");

const Editor = editor_mod.Editor;
const TerminalSession = terminal_mod.TerminalSession;
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

    pub fn init(allocator: std.mem.Allocator) !*AppState {
        const renderer = try Renderer.init(allocator, 1280, 720, "Zide - Zig IDE");
        errdefer renderer.deinit();

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
            try self.update();

            // Only redraw when something changed
            if (self.needs_redraw) {
                self.draw();
                self.needs_redraw = false;
            } else {
                // Still need to poll events when not drawing
                renderer_mod.pollEvents();
            }
        }
    }

    fn update(self: *AppState) !void {
        const r = self.renderer;

        // Check for window resize (event-based, works with Wayland)
        if (renderer_mod.isWindowResized()) {
            r.width = renderer_mod.getScreenWidth();
            r.height = renderer_mod.getScreenHeight();
            self.needs_redraw = true;
        }

        // Check for any input activity
        const has_key = r.hasAnyKeyPressed();
        const has_char = r.hasCharPressed();
        const has_mouse = r.isMouseButtonPressed(renderer_mod.MOUSE_LEFT) or
            r.isMouseButtonPressed(renderer_mod.MOUSE_RIGHT) or
            r.getMouseWheelMove() != 0;

        if (has_key or has_char or has_mouse) {
            self.needs_redraw = true;
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
            return;
        }

        // Tab bar click handling
        const mouse = r.getMousePos();
        if (r.isMouseButtonPressed(renderer_mod.MOUSE_LEFT)) {
            const tab_bar_y = self.options_bar.height;
            if (self.tab_bar.handleClick(mouse.x, mouse.y, self.side_nav.width, tab_bar_y)) {
                // Tab was clicked
                self.active_tab = self.tab_bar.active_index;
                self.needs_redraw = true;
            }
        }

        // Update active view
        if (self.active_kind == .editor and self.editors.items.len > 0) {
            const editor_idx = @min(self.active_tab, self.editors.items.len - 1);
            var widget = EditorWidget.init(self.editors.items[editor_idx]);
            try widget.handleInput(r);
        }

        // Update terminal if shown - use poll() to check for data efficiently
        if (self.show_terminal and self.terminals.items.len > 0) {
            const term = self.terminals.items[0];

            // Only poll PTY if there's data available (non-blocking check)
            if (term.pty.hasData()) {
                try term.poll();
                self.needs_redraw = true;
            }

            // Handle terminal input if focused at bottom
            if (mouse.y > @as(f32, @floatFromInt(r.height)) - self.terminal_height) {
                var term_widget = TerminalWidget.init(term);
                try term_widget.handleInput(r);
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
        const terminal_h = if (self.show_terminal) self.terminal_height else 0;
        const editor_height = height - options_bar_height - tab_bar_height - status_bar_height - terminal_h;
        const editor_width = width - side_nav_width;

        // Draw options bar
        self.options_bar.draw(r, width);

        // Draw tab bar
        self.tab_bar.draw(r, side_nav_width, options_bar_height, editor_width);

        // Draw editor
        if (self.editors.items.len > 0) {
            const editor_idx = @min(self.active_tab, self.editors.items.len - 1);
            var widget = EditorWidget.init(self.editors.items[editor_idx]);
            widget.draw(r, side_nav_width, options_bar_height + tab_bar_height, editor_width, editor_height);

            // Update status bar info
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

        // Draw terminal if shown
        if (self.show_terminal and self.terminals.items.len > 0) {
            const term_y = height - status_bar_height - terminal_h;

            // Terminal separator
            r.drawRect(@intFromFloat(side_nav_width), @intFromFloat(term_y), @intFromFloat(editor_width), 2, renderer_mod.Color.light_gray);

            var term_widget = TerminalWidget.init(self.terminals.items[0]);
            term_widget.draw(r, side_nav_width, term_y + 2, editor_width, terminal_h - 2);
        }

        // Draw side navigation bar LAST so it covers any terminal icon overflow
        const side_nav_height = height - status_bar_height;
        self.side_nav.draw(r, side_nav_height, options_bar_height);

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
