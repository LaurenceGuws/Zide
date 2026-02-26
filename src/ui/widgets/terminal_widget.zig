const std = @import("std");
const builtin = @import("builtin");
const app_shell = @import("../../app_shell.zig");
const terminal_mod = @import("../../terminal/core/terminal.zig");
const key_encoder = @import("../../terminal/input/key_encoder.zig");
const app_logger = @import("../../app_logger.zig");
const shared_types = @import("../../types/mod.zig");
const open_mod = @import("terminal_widget_open.zig");
const hover_mod = @import("terminal_widget_hover.zig");
const kitty_mod = @import("terminal_widget_kitty.zig");
const draw_mod = @import("terminal_widget_draw.zig");
const input_mod = @import("terminal_widget_input.zig");

const Shell = app_shell.Shell;
const Color = app_shell.Color;
const TerminalSession = terminal_mod.TerminalSession;
const CursorPos = terminal_mod.CursorPos;
const Cell = terminal_mod.Cell;
const CellAttrs = terminal_mod.CellAttrs;
const KittyImage = terminal_mod.KittyImage;
const KittyPlacement = terminal_mod.KittyPlacement;

/// Terminal widget for drawing a terminal view
pub const TerminalWidget = struct {
    pub const BlinkStyle = enum {
        kitty,
        off,
    };

    pub const PendingOpen = open_mod.PendingOpen;
    pub const FocusReportSource = enum {
        window,
        pane,
    };

    session: *TerminalSession,
    blink_style: BlinkStyle = .kitty,
    last_scroll_offset: usize = 0,
    kitty: kitty_mod.KittyState,
    hover: hover_mod.HoverState = .{},
    pending_open: ?PendingOpen = null,
    last_draw_log_time: f64 = 0,
    bench_enabled: bool = false,
    last_bench_log_time: f64 = 0,
    blink_last_slow_on: bool = true,
    blink_last_fast_on: bool = true,
    blink_last_active: bool = false,
    cursor_blink_pause_until: f64 = 0,
    terminal_texture_ready: bool = false,
    last_render_generation: u64 = 0,
    last_cell_w_i: i32 = 0,
    last_cell_h_i: i32 = 0,
    last_render_scale: f32 = 0,
    focus_report_window_events: bool = true,
    focus_report_pane_events: bool = false,
    last_focus_reported: ?bool = null,

    pub fn init(session: *TerminalSession, blink_style: BlinkStyle) TerminalWidget {
        return .{
            .session = session,
            .blink_style = blink_style,
            .last_scroll_offset = 0,
            .kitty = kitty_mod.KittyState.init(session.allocator),
            .hover = .{},
            .pending_open = null,
            .last_draw_log_time = 0,
            .bench_enabled = std.c.getenv("ZIDE_TERMINAL_UI_BENCH") != null,
            .last_bench_log_time = 0,
            .blink_last_slow_on = true,
            .blink_last_fast_on = true,
            .blink_last_active = false,
            .terminal_texture_ready = false,
            .last_render_generation = 0,
            .last_cell_w_i = 0,
            .last_cell_h_i = 0,
            .last_render_scale = 0,
            .focus_report_window_events = true,
            .focus_report_pane_events = false,
            .last_focus_reported = null,
        };
    }

    pub fn setFocusReportSources(self: *TerminalWidget, window: bool, pane: bool) void {
        self.focus_report_window_events = window;
        self.focus_report_pane_events = pane;
    }

    pub fn reportFocusChangedFrom(self: *TerminalWidget, source: FocusReportSource, focused: bool) !bool {
        const source_enabled = switch (source) {
            .window => self.focus_report_window_events,
            .pane => self.focus_report_pane_events,
        };
        if (!source_enabled) return false;
        if (self.last_focus_reported) |last| {
            if (last == focused) return false;
        }
        if (try self.session.reportFocusChanged(focused)) {
            self.last_focus_reported = focused;
            return true;
        }
        return false;
    }

    pub fn updateBlink(self: *TerminalWidget, now: f64) bool {
        if (self.blink_style == .off) {
            self.blink_last_active = false;
            return false;
        }
        const cache = self.session.renderCache();
        var has_slow = false;
        var has_fast = false;
        for (cache.cells.items) |cell| {
            if (!cell.attrs.blink) continue;
            if (cell.attrs.blink_fast) {
                has_fast = true;
            } else {
                has_slow = true;
            }
            if (has_slow and has_fast) break;
        }
        if (!has_slow and !has_fast) {
            self.blink_last_active = false;
            return false;
        }
        const slow_on = @mod(now, 2.0) < 1.0;
        const fast_on = @mod(now, 1.0) < 0.5;
        var changed = false;
        if (has_slow) {
            if (!self.blink_last_active or slow_on != self.blink_last_slow_on) {
                changed = true;
            }
            self.blink_last_slow_on = slow_on;
        }
        if (has_fast) {
            if (!self.blink_last_active or fast_on != self.blink_last_fast_on) {
                changed = true;
            }
            self.blink_last_fast_on = fast_on;
        }
        self.blink_last_active = true;
        return changed;
    }

    pub fn noteInput(self: *TerminalWidget, now: f64) void {
        self.cursor_blink_pause_until = now + 0.4;
    }

    pub fn deinit(self: *TerminalWidget) void {
        if (self.pending_open) |req| {
            self.session.allocator.free(req.path);
            self.pending_open = null;
        }
        self.kitty.deinit(self.session.allocator);
    }

    pub fn takePendingOpenRequest(self: *TerminalWidget) ?PendingOpen {
        const value = self.pending_open;
        self.pending_open = null;
        return value;
    }

    pub fn copySelectionToClipboard(self: *TerminalWidget, shell: *Shell) bool {
        const selection = self.session.selectionState() orelse return false;
        const sel_snapshot = self.session.snapshot();
        const rows_snapshot = sel_snapshot.rows;
        const cols_snapshot = sel_snapshot.cols;
        const history = self.session.scrollbackCount();
        const total_lines_copy = history + rows_snapshot;
        if (rows_snapshot == 0 or cols_snapshot == 0 or total_lines_copy == 0) return false;

        var start_sel = selection.start;
        var end_sel = selection.end;
        if (start_sel.row > end_sel.row or (start_sel.row == end_sel.row and start_sel.col > end_sel.col)) {
            const tmp = start_sel;
            start_sel = end_sel;
            end_sel = tmp;
        }
        start_sel.row = @min(start_sel.row, total_lines_copy - 1);
        end_sel.row = @min(end_sel.row, total_lines_copy - 1);
        start_sel.col = @min(start_sel.col, cols_snapshot - 1);
        end_sel.col = @min(end_sel.col, cols_snapshot - 1);

        var text = std.ArrayList(u8).empty;
        defer text.deinit(self.session.allocator);

        var row_idx: usize = start_sel.row;
        while (row_idx <= end_sel.row and row_idx < total_lines_copy) : (row_idx += 1) {
            const row_cells = blk: {
                if (row_idx < history) {
                    if (self.session.scrollbackRow(row_idx)) |history_row| break :blk history_row;
                }
                const grid_row = row_idx - history;
                const row_start = grid_row * cols_snapshot;
                break :blk sel_snapshot.cells[row_start .. row_start + cols_snapshot];
            };

            const col_start = if (row_idx == start_sel.row) start_sel.col else 0;
            const col_end = if (row_idx == end_sel.row) end_sel.col else cols_snapshot - 1;
            var col_idx: usize = col_start;
            while (col_idx <= col_end and col_idx < cols_snapshot) : (col_idx += 1) {
                const cell = row_cells[col_idx];
                if (cell.x != 0 or cell.y != 0) {
                    continue;
                }
                if (cell.codepoint == 0) {
                    text.append(self.session.allocator, ' ') catch return false;
                    continue;
                }
                var buf: [4]u8 = undefined;
                const len = std.unicode.utf8Encode(@intCast(cell.codepoint), &buf) catch 0;
                if (len > 0) {
                    text.appendSlice(self.session.allocator, buf[0..len]) catch return false;
                }
                if (cell.combining_len > 0) {
                    var ci: usize = 0;
                    while (ci < @as(usize, @intCast(cell.combining_len)) and ci < cell.combining.len) : (ci += 1) {
                        const cp = cell.combining[ci];
                        const c_len = std.unicode.utf8Encode(@intCast(cp), &buf) catch 0;
                        if (c_len > 0) {
                            text.appendSlice(self.session.allocator, buf[0..c_len]) catch return false;
                        }
                    }
                }
            }

            while (text.items.len > 0 and text.items[text.items.len - 1] == ' ') {
                _ = text.pop();
            }

            if (row_idx != end_sel.row) {
                text.append(self.session.allocator, '\n') catch return false;
            }
        }

        text.append(self.session.allocator, 0) catch return false;
        const cstr: [*:0]const u8 = @ptrCast(text.items.ptr);
        shell.setClipboardText(cstr);
        return true;
    }

    pub fn pasteClipboardFromSystem(self: *TerminalWidget, shell: *Shell) bool {
        const clip_opt = shell.getClipboardText();
        const html = shell.getClipboardMimeData(self.session.allocator, "text/html");
        const uri_list = shell.getClipboardMimeData(self.session.allocator, "text/uri-list");
        const png = shell.getClipboardMimeData(self.session.allocator, "image/png");
        defer if (html) |buf| self.session.allocator.free(buf);
        defer if (uri_list) |buf| self.session.allocator.free(buf);
        defer if (png) |buf| self.session.allocator.free(buf);
        const clip = clip_opt orelse "";
        const has_supported_clipboard_data = clip_opt != null or html != null or uri_list != null or png != null;
        if (!has_supported_clipboard_data) return false;
        if (self.session.scrollOffset() > 0) {
            self.session.setScrollOffset(0);
        }
        if (self.session.sendKittyPasteEvent5522WithMimeRich(clip, html, uri_list, png) catch false) {
            return true;
        }
        if (clip_opt == null) return false;
        if (self.session.bracketedPasteEnabled()) {
            self.session.sendText("\x1b[200~") catch return false;
            var filtered = std.ArrayList(u8).empty;
            defer filtered.deinit(self.session.allocator);
            for (clip_opt.?) |b| {
                if (b == 0x1b or b == 0x03) continue;
                filtered.append(self.session.allocator, b) catch return false;
            }
            if (filtered.items.len > 0) {
                self.session.sendText(filtered.items) catch return false;
            }
            self.session.sendText("\x1b[201~") catch return false;
        } else {
            self.session.sendText(clip_opt.?) catch return false;
        }
        return true;
    }

    pub fn scrollbackPlainTextAlloc(self: *TerminalWidget, allocator: std.mem.Allocator) ![]u8 {
        const snap = self.session.snapshot();
        const rows = snap.rows;
        const cols = snap.cols;
        const history = self.session.scrollbackCount();

        var out = std.ArrayList(u8).empty;
        errdefer out.deinit(allocator);

        var buf: [4]u8 = undefined;

        var line_idx: usize = 0;
        while (line_idx < history + rows) : (line_idx += 1) {
            const row_cells = blk: {
                if (line_idx < history) {
                    if (self.session.scrollbackRow(line_idx)) |history_row| break :blk history_row;
                    continue;
                }
                const grid_row = line_idx - history;
                if (grid_row >= rows or cols == 0) continue;
                const row_start = grid_row * cols;
                break :blk snap.cells[row_start .. row_start + cols];
            };

            var line = std.ArrayList(u8).empty;
            defer line.deinit(allocator);

            var col_idx: usize = 0;
            while (col_idx < row_cells.len) : (col_idx += 1) {
                const cell = row_cells[col_idx];
                if (cell.x != 0 or cell.y != 0) continue;
                if (cell.codepoint == 0) {
                    try line.append(allocator, ' ');
                    continue;
                }
                const len = std.unicode.utf8Encode(@intCast(cell.codepoint), &buf) catch 0;
                if (len > 0) try line.appendSlice(allocator, buf[0..len]);
                if (cell.combining_len > 0) {
                    var ci: usize = 0;
                    while (ci < @as(usize, @intCast(cell.combining_len)) and ci < cell.combining.len) : (ci += 1) {
                        const cp = cell.combining[ci];
                        const clen = std.unicode.utf8Encode(@intCast(cp), &buf) catch 0;
                        if (clen > 0) try line.appendSlice(allocator, buf[0..clen]);
                    }
                }
            }

            while (line.items.len > 0 and line.items[line.items.len - 1] == ' ') {
                _ = line.pop();
            }
            try out.appendSlice(allocator, line.items);
            try out.append(allocator, '\n');
        }

        return out.toOwnedSlice(allocator);
    }

    fn appendSgrForAttrs(out: *std.ArrayList(u8), allocator: std.mem.Allocator, attrs: CellAttrs) !void {
        const bold = if (attrs.bold) ";1" else "";
        const underline = if (attrs.underline) ";4" else "";
        const reverse = if (attrs.reverse) ";7" else "";
        const blink = if (attrs.blink) (if (attrs.blink_fast) ";6" else ";5") else "";
        const seq = try std.fmt.allocPrint(
            allocator,
            "\x1b[0{s}{s}{s}{s};38;2;{d};{d};{d};48;2;{d};{d};{d};58;2;{d};{d};{d}m",
            .{
                bold,
                underline,
                reverse,
                blink,
                attrs.fg.r,
                attrs.fg.g,
                attrs.fg.b,
                attrs.bg.r,
                attrs.bg.g,
                attrs.bg.b,
                attrs.underline_color.r,
                attrs.underline_color.g,
                attrs.underline_color.b,
            },
        );
        defer allocator.free(seq);
        try out.appendSlice(allocator, seq);
    }

    fn attrsEqual(a: CellAttrs, b: CellAttrs) bool {
        return a.fg.r == b.fg.r and
            a.fg.g == b.fg.g and
            a.fg.b == b.fg.b and
            a.fg.a == b.fg.a and
            a.bg.r == b.bg.r and
            a.bg.g == b.bg.g and
            a.bg.b == b.bg.b and
            a.bg.a == b.bg.a and
            a.bold == b.bold and
            a.blink == b.blink and
            a.blink_fast == b.blink_fast and
            a.reverse == b.reverse and
            a.underline == b.underline and
            a.underline_color.r == b.underline_color.r and
            a.underline_color.g == b.underline_color.g and
            a.underline_color.b == b.underline_color.b and
            a.underline_color.a == b.underline_color.a;
    }

    pub fn scrollbackAnsiTextAlloc(self: *TerminalWidget, allocator: std.mem.Allocator) ![]u8 {
        const snap = self.session.snapshot();
        const rows = snap.rows;
        const cols = snap.cols;
        const history = self.session.scrollbackCount();

        var out = std.ArrayList(u8).empty;
        errdefer out.deinit(allocator);

        var buf: [4]u8 = undefined;

        var line_idx: usize = 0;
        while (line_idx < history + rows) : (line_idx += 1) {
            const row_cells = blk: {
                if (line_idx < history) {
                    if (self.session.scrollbackRow(line_idx)) |history_row| break :blk history_row;
                    continue;
                }
                const grid_row = line_idx - history;
                if (grid_row >= rows or cols == 0) continue;
                const row_start = grid_row * cols;
                break :blk snap.cells[row_start .. row_start + cols];
            };

            var active_attrs: ?CellAttrs = null;
            var col_idx: usize = 0;
            while (col_idx < row_cells.len) : (col_idx += 1) {
                const cell = row_cells[col_idx];
                if (cell.x != 0 or cell.y != 0) continue;
                if (active_attrs == null or !attrsEqual(active_attrs.?, cell.attrs)) {
                    try appendSgrForAttrs(&out, allocator, cell.attrs);
                    active_attrs = cell.attrs;
                }

                if (cell.codepoint == 0) {
                    try out.append(allocator, ' ');
                    continue;
                }
                const len = std.unicode.utf8Encode(@intCast(cell.codepoint), &buf) catch 0;
                if (len > 0) {
                    try out.appendSlice(allocator, buf[0..len]);
                }
                if (cell.combining_len > 0) {
                    var ci: usize = 0;
                    while (ci < @as(usize, @intCast(cell.combining_len)) and ci < cell.combining.len) : (ci += 1) {
                        const cp = cell.combining[ci];
                        const clen = std.unicode.utf8Encode(@intCast(cp), &buf) catch 0;
                        if (clen > 0) try out.appendSlice(allocator, buf[0..clen]);
                    }
                }
            }

            if (active_attrs != null) {
                try out.appendSlice(allocator, "\x1b[0m");
            }
            try out.append(allocator, '\n');
        }

        return out.toOwnedSlice(allocator);
    }

    pub fn draw(
        self: *TerminalWidget,
        shell: *Shell,
        x: f32,
        y: f32,
        width: f32,
        height: f32,
        input: shared_types.input.InputSnapshot,
    ) void {
        draw_mod.draw(self, shell, x, y, width, height, input);
    }

    /// Handle input, returns true if any input was processed
    pub fn handleInput(
        self: *TerminalWidget,
        shell: *Shell,
        x: f32,
        y: f32,
        width: f32,
        height: f32,
        allow_input: bool,
        scroll_dragging: *bool,
        scroll_grab_offset: *f32,
        suppress_shortcuts: bool,
        input_batch: *shared_types.input.InputBatch,
    ) !bool {
        return input_mod.handleInput(
            self,
            shell,
            x,
            y,
            width,
            height,
            allow_input,
            scroll_dragging,
            scroll_grab_offset,
            suppress_shortcuts,
            input_batch,
        );
    }
};
