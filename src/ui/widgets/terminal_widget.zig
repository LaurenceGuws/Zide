const std = @import("std");
const app_shell = @import("../../app_shell.zig");
const terminal_mod = @import("../../terminal/core/terminal.zig");
const terminal_types = @import("../../terminal/model/types.zig");
const key_encoder = @import("../../terminal/input/key_encoder.zig");
const app_logger = @import("../../app_logger.zig");
const shared_types = @import("../../types/mod.zig");
const open_mod = @import("terminal_widget_open.zig");
const hover_mod = @import("terminal_widget_hover.zig");
const kitty_mod = @import("terminal_widget_kitty.zig");
const draw_mod = @import("terminal_widget_draw.zig");
const input_mod = @import("terminal_widget_input.zig");
const render_cache_mod = @import("../../terminal/core/render_cache.zig");

const Shell = app_shell.Shell;
const TerminalSession = terminal_mod.TerminalSession;
const CursorPos = terminal_mod.CursorPos;
const KittyImage = terminal_mod.KittyImage;
const KittyPlacement = terminal_mod.KittyPlacement;
const RenderCache = render_cache_mod.RenderCache;
const DrawOutcome = draw_mod.DrawOutcome;
const DrawPreparation = draw_mod.DrawPreparation;
const Cell = terminal_mod.Cell;

const visible_ascii_dump_path = "zide_terminal_view_dump.txt";

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
    kitty: kitty_mod.KittyState,
    hover: hover_mod.HoverState = .{},
    pending_open: ?PendingOpen = null,
    last_draw_log_time: f64 = 0,
    draw_cache: RenderCache,
    partial_draw_rows: std.ArrayList(bool),
    partial_draw_span_counts: std.ArrayList(u8),
    partial_draw_spans: std.ArrayList([render_cache_mod.max_row_dirty_spans]render_cache_mod.RowDirtySpan),
    partial_draw_cols_start: std.ArrayList(u16),
    partial_draw_cols_end: std.ArrayList(u16),
    bench_enabled: bool = false,
    last_bench_log_time: f64 = 0,
    blink_last_slow_on: bool = true,
    blink_last_fast_on: bool = true,
    blink_last_active: bool = false,
    blink_phase_changed_pending: bool = false,
    cursor_blink_pause_until: f64 = 0,
    last_terminal_input_time: f64 = 0,
    terminal_texture_ready: bool = false,
    last_render_generation: u64 = 0,
    force_full_texture_publish_until: f64 = 0,
    last_alt_active: bool = false,
    last_cell_w_i: i32 = 0,
    last_cell_h_i: i32 = 0,
    last_render_scale: f32 = 0,
    focus_report_window_events: bool = true,
    focus_report_pane_events: bool = false,
    last_focus_reported: ?bool = null,
    ui_focused: bool = true,
    ui_window_focused: bool = true,
    scrollbar_hover_anim: f32 = 0,
    scrollbar_anim_last_time: f64 = 0,
    scrollbar_drag_active: bool = false,
    scrollbar_grab_offset: f32 = 0,
    selection_gesture: terminal_mod.SelectionGesture = .{},
    selection_press_origin: ?shared_types.input.MousePos = null,
    selection_drag_active: bool = false,

    pub fn init(session: *TerminalSession, blink_style: BlinkStyle) TerminalWidget {
        return .{
            .session = session,
            .blink_style = blink_style,
            .kitty = kitty_mod.KittyState.init(session.allocator),
            .hover = .{},
            .pending_open = null,
            .last_draw_log_time = 0,
            .draw_cache = RenderCache.init(),
            .partial_draw_rows = std.ArrayList(bool).empty,
            .partial_draw_span_counts = std.ArrayList(u8).empty,
            .partial_draw_spans = std.ArrayList([render_cache_mod.max_row_dirty_spans]render_cache_mod.RowDirtySpan).empty,
            .partial_draw_cols_start = std.ArrayList(u16).empty,
            .partial_draw_cols_end = std.ArrayList(u16).empty,
            .bench_enabled = std.c.getenv("ZIDE_TERMINAL_UI_BENCH") != null,
            .last_bench_log_time = 0,
            .blink_last_slow_on = true,
            .blink_last_fast_on = true,
            .blink_last_active = false,
            .blink_phase_changed_pending = false,
            .last_terminal_input_time = 0,
            .terminal_texture_ready = false,
            .last_render_generation = 0,
            .force_full_texture_publish_until = 0,
            .last_alt_active = false,
            .last_cell_w_i = 0,
            .last_cell_h_i = 0,
            .last_render_scale = 0,
            .focus_report_window_events = true,
            .focus_report_pane_events = false,
            .last_focus_reported = null,
            .ui_focused = true,
            .ui_window_focused = true,
            .scrollbar_hover_anim = 0,
            .scrollbar_anim_last_time = 0,
            .scrollbar_drag_active = false,
            .scrollbar_grab_offset = 0,
            .selection_gesture = .{},
            .selection_press_origin = null,
            .selection_drag_active = false,
        };
    }

    pub fn setFocusReportSources(self: *TerminalWidget, window: bool, pane: bool) void {
        self.focus_report_window_events = window;
        self.focus_report_pane_events = pane;
    }

    pub fn reportFocusChangedFrom(self: *TerminalWidget, source: FocusReportSource, focused: bool) !bool {
        var ui_changed = false;
        if (source == .window) {
            ui_changed = self.ui_window_focused != focused;
            self.ui_window_focused = focused;
            self.setUiFocused(self.ui_window_focused);
        }

        const source_enabled = switch (source) {
            .window => self.focus_report_window_events,
            .pane => self.focus_report_pane_events,
        };
        if (!source_enabled) return ui_changed;
        if (self.last_focus_reported) |last| {
            if (last == focused) return ui_changed;
        }
        if (try self.session.reportFocusChanged(focused)) {
            self.last_focus_reported = focused;
            return true;
        }
        return ui_changed;
    }

    pub fn setUiFocused(self: *TerminalWidget, focused: bool) void {
        if (self.ui_focused == focused) return;
        self.ui_focused = focused;
        const log = app_logger.logger("terminal.cursor");
        log.logf(.info, "ui_focus changed focused={d}", .{@intFromBool(focused)});
    }

    pub fn updateBlink(self: *TerminalWidget, now: f64) bool {
        if (self.blink_style == .off) {
            self.blink_last_active = false;
            self.blink_phase_changed_pending = false;
            return false;
        }
        const cache = &self.draw_cache;
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
            self.blink_phase_changed_pending = false;
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
        self.blink_phase_changed_pending = changed;
        return changed;
    }

    pub fn noteInput(self: *TerminalWidget, now: f64) void {
        self.cursor_blink_pause_until = now + 0.4;
        self.last_terminal_input_time = now;
    }

    pub fn deinit(self: *TerminalWidget) void {
        if (self.pending_open) |req| {
            self.session.allocator.free(req.path);
            self.pending_open = null;
        }
        self.draw_cache.deinit(self.session.allocator);
        self.partial_draw_rows.deinit(self.session.allocator);
        self.partial_draw_span_counts.deinit(self.session.allocator);
        self.partial_draw_spans.deinit(self.session.allocator);
        self.partial_draw_cols_start.deinit(self.session.allocator);
        self.partial_draw_cols_end.deinit(self.session.allocator);
        self.kitty.deinit(self.session.allocator);
    }

    pub fn takePendingOpenRequest(self: *TerminalWidget) ?PendingOpen {
        const value = self.pending_open;
        self.pending_open = null;
        return value;
    }

    pub fn invalidateTextureCache(self: *TerminalWidget) void {
        self.terminal_texture_ready = false;
        self.force_full_texture_publish_until = 0;
    }

    pub fn dumpVisibleAsciiView(self: *TerminalWidget) !void {
        var out = std.ArrayList(u8).empty;
        defer out.deinit(self.session.allocator);

        try out.writer(self.session.allocator).print(
            "# Zide terminal visible-view dump\npath={s}\nrows={d} cols={d} generation={d} scroll_offset={d} alt_active={d} cursor={d}:{d} cursor_visible={d} screen_reverse={d}\n",
            .{
                visible_ascii_dump_path,
                self.draw_cache.rows,
                self.draw_cache.cols,
                self.draw_cache.generation,
                self.draw_cache.scroll_offset,
                @intFromBool(self.draw_cache.alt_active),
                self.draw_cache.cursor.row,
                self.draw_cache.cursor.col,
                @intFromBool(self.draw_cache.cursor_visible),
                @intFromBool(self.draw_cache.screen_reverse),
            },
        );

        try appendViewportColumnRuler(&out, self.session.allocator, self.draw_cache.cols);
        try out.append(self.session.allocator, '\n');

        if (self.draw_cache.rows == 0 or self.draw_cache.cols == 0 or self.draw_cache.cells.items.len == 0) {
            try out.appendSlice(self.session.allocator, "# empty draw cache\n");
        } else {
            var row: usize = 0;
            while (row < self.draw_cache.rows) : (row += 1) {
                try out.writer(self.session.allocator).print("{d:0>3}|", .{row});
                try appendViewportAsciiRow(&out, self.session.allocator, self.draw_cache, row);
                try out.appendSlice(self.session.allocator, "|\n");
            }
        }

        try out.appendSlice(self.session.allocator, "\n# resolved_bg_runs\n");
        if (self.draw_cache.rows == 0 or self.draw_cache.cols == 0 or self.draw_cache.cells.items.len == 0) {
            try out.appendSlice(self.session.allocator, "none\n");
        } else {
            var row: usize = 0;
            while (row < self.draw_cache.rows) : (row += 1) {
                try appendResolvedBackgroundRuns(&out, self.session.allocator, self.draw_cache, row);
            }
        }

        try out.appendSlice(self.session.allocator, "\n# non_ascii_cells\n");
        var listed_non_ascii = false;
        if (self.draw_cache.rows > 0 and self.draw_cache.cols > 0 and self.draw_cache.cells.items.len > 0) {
            var row: usize = 0;
            while (row < self.draw_cache.rows) : (row += 1) {
                var col: usize = 0;
                while (col < self.draw_cache.cols) : (col += 1) {
                    const idx = row * self.draw_cache.cols + col;
                    if (idx >= self.draw_cache.cells.items.len) break;
                    const cell = self.draw_cache.cells.items[idx];
                    if (cell.x != 0 or cell.y != 0) continue;
                    if (cell.codepoint == 0) continue;
                    if (cell.codepoint >= 32 and cell.codepoint <= 126 and cell.combining_len == 0 and cell.width <= 1) continue;
                    listed_non_ascii = true;
                    try out.writer(self.session.allocator).print(
                        "row={d} col={d} cp={d} width={d} combining={d}\n",
                        .{ row, col, cell.codepoint, cell.width, cell.combining_len },
                    );
                }
            }
        }
        if (!listed_non_ascii) {
            try out.appendSlice(self.session.allocator, "none\n");
        }

        try std.fs.cwd().writeFile(.{
            .sub_path = visible_ascii_dump_path,
            .data = out.items,
        });
    }

    pub fn pasteClipboardFromSystem(self: *TerminalWidget, shell: *Shell) bool {
        const clip_opt = shell.getClipboardText();
        const html = shell.getClipboardMimeData(self.session.allocator, "text/html");
        const uri_list = shell.getClipboardMimeData(self.session.allocator, "text/uri-list");
        const png = shell.getClipboardMimeData(self.session.allocator, "image/png");
        defer if (html) |buf| self.session.allocator.free(buf);
        defer if (uri_list) |buf| self.session.allocator.free(buf);
        defer if (png) |buf| self.session.allocator.free(buf);
        return self.session.pasteSystemClipboard(clip_opt, html, uri_list, png) catch false;
    }

    pub fn draw(
        self: *TerminalWidget,
        shell: *Shell,
        x: f32,
        y: f32,
        width: f32,
        height: f32,
        input: shared_types.input.InputSnapshot,
    ) DrawOutcome {
        const draw_start = app_shell.getTime();
        const capture = self.session.capturePresentation(&self.draw_cache) catch |err| {
            const log = app_logger.logger("terminal.ui.redraw");
            log.logf(.warning, "draw snapshot copy failed err={s}", .{@errorName(err)});
            return .{};
        };
        const handoff_log = app_logger.logger("terminal.generation_handoff");
        if (handoff_log.enabled_file or handoff_log.enabled_console) {
            handoff_log.logf(
                .info,
                "stage=widget_prepare sid={x} last_render={d} captured={d} cur={d} pub={d} presented={d} texture_ready={d}",
                .{
                    @intFromPtr(self.session),
                    self.last_render_generation,
                    capture.presented.generation,
                    self.session.currentGeneration(),
                    self.session.publishedGeneration(),
                    self.session.presentedGeneration(),
                    @intFromBool(self.terminal_texture_ready),
                },
            );
        }
        const preparation = DrawPreparation.fromCapture(draw_start, capture);
        return draw_mod.drawPrepared(self, shell, x, y, width, height, input, preparation);
    }

    pub fn finishFramePresentation(self: *TerminalWidget, outcome: DrawOutcome) void {
        self.session.finishFramePresentation(outcome);
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
            suppress_shortcuts,
            input_batch,
        );
    }
};

fn appendViewportColumnRuler(out: *std.ArrayList(u8), allocator: std.mem.Allocator, cols: usize) !void {
    try out.appendSlice(allocator, "   |");
    var col: usize = 0;
    while (col < cols) : (col += 1) {
        const digit: u8 = @intCast((col / 10) % 10);
        try out.append(allocator, '0' + digit);
    }
    try out.appendSlice(allocator, "|\n");

    try out.appendSlice(allocator, "   |");
    col = 0;
    while (col < cols) : (col += 1) {
        const digit: u8 = @intCast(col % 10);
        try out.append(allocator, '0' + digit);
    }
    try out.appendSlice(allocator, "|");
}

fn appendViewportAsciiRow(
    out: *std.ArrayList(u8),
    allocator: std.mem.Allocator,
    cache: RenderCache,
    row: usize,
) !void {
    if (cache.cols == 0 or row >= cache.rows) return;
    const row_start = row * cache.cols;
    var col: usize = 0;
    while (col < cache.cols) : (col += 1) {
        const idx = row_start + col;
        if (idx >= cache.cells.items.len) break;
        try out.append(allocator, viewportAsciiChar(cache.cells.items[idx]));
    }
}

fn viewportAsciiChar(cell: Cell) u8 {
    if (cell.x != 0 or cell.y != 0) return '<';
    if (cell.codepoint == 0 or cell.codepoint == ' ') return ' ';
    if (cell.combining_len > 0) return '+';
    if (cell.codepoint >= 33 and cell.codepoint <= 126 and cell.width <= 1) {
        return @intCast(cell.codepoint);
    }
    return '?';
}

fn appendResolvedBackgroundRuns(
    out: *std.ArrayList(u8),
    allocator: std.mem.Allocator,
    cache: RenderCache,
    row: usize,
) !void {
    if (cache.cols == 0 or row >= cache.rows) {
        try out.writer(allocator).print("row={d:0>3} cursor_here=0 cursor_col=-1 runs=none\n", .{row});
        return;
    }

    const row_start = row * cache.cols;
    if (row_start >= cache.cells.items.len) {
        try out.writer(allocator).print("row={d:0>3} cursor_here=0 cursor_col=-1 runs=none\n", .{row});
        return;
    }

    const cursor_here = cache.cursor_visible and cache.cursor.row == row and cache.cursor.col < cache.cols;
    try out.writer(allocator).print(
        "row={d:0>3} cursor_here={d} cursor_col={d} runs=",
        .{
            row,
            @intFromBool(cursor_here),
            if (cursor_here) @as(i64, @intCast(cache.cursor.col)) else -1,
        },
    );

    var col: usize = 0;
    while (col < cache.cols) {
        const idx = row_start + col;
        if (idx >= cache.cells.items.len) break;
        const run_color = resolvedBackgroundColor(cache.cells.items[idx], cache.screen_reverse);
        var end_col = col;
        while (end_col + 1 < cache.cols) : (end_col += 1) {
            const next_idx = row_start + end_col + 1;
            if (next_idx >= cache.cells.items.len) break;
            const next_color = resolvedBackgroundColor(cache.cells.items[next_idx], cache.screen_reverse);
            if (!sameColor(run_color, next_color)) break;
        }
        try out.writer(allocator).print(
            "{d}..{d}@{d}:{d}:{d}",
            .{ col, end_col, run_color.r, run_color.g, run_color.b },
        );
        col = end_col + 1;
        if (col < cache.cols) try out.appendSlice(allocator, " ");
    }
    try out.append(allocator, '\n');
}

fn resolvedBackgroundColor(cell: Cell, screen_reverse: bool) terminal_types.Color {
    const reversed = cell.attrs.reverse != screen_reverse;
    return if (reversed) cell.attrs.fg else cell.attrs.bg;
}

fn sameColor(a: terminal_types.Color, b: terminal_types.Color) bool {
    return a.r == b.r and a.g == b.g and a.b == b.b and a.a == b.a;
}
