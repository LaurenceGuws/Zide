const std = @import("std");
const app_shell = @import("../../app_shell.zig");
const terminal_runtime = @import("../../terminal/core/terminal_runtime.zig");
const publication_capture = @import("../../terminal/core/publication/publication_capture.zig");
const terminal_publication = @import("../../terminal/core/publication/terminal_publication.zig");
const session_input = @import("../../terminal/core/session/input.zig");
const session_interaction = @import("../../terminal/core/session/interaction.zig");
const terminal_selection = @import("../../terminal/core/selection.zig");
const terminal_types = @import("../../terminal/model/types.zig");
const key_encoder = @import("../../terminal/input/key_encoder.zig");
const app_logger = @import("../../app_logger.zig");
const shared_types = @import("../../types/mod.zig");
const presentation_feedback = @import("../../terminal/core/publication/presentation_feedback.zig");
const open_mod = @import("terminal_widget_open.zig");
const hover_mod = @import("terminal_widget_hover.zig");
const kitty_mod = @import("terminal_widget_kitty.zig");
const paste_mod = @import("terminal_widget_paste.zig");
const draw_mod = @import("terminal_widget_draw.zig");
const input_mod = @import("terminal_widget_input.zig");
const retained_state_mod = @import("terminal_widget_retained_state.zig");
const debug_geometry_mod = @import("terminal_widget_debug_geometry.zig");
const view_state = @import("terminal_widget_view_state.zig");
const render_cache_mod = @import("../../terminal/core/publication/render_cache.zig");

const Shell = app_shell.Shell;
const TerminalRuntimeShell = terminal_runtime.TerminalRuntimeShell;
const CursorPos = terminal_publication.CursorPos;
const KittyImage = terminal_publication.KittyImage;
const KittyPlacement = terminal_publication.KittyPlacement;
const RenderCache = render_cache_mod.RenderCache;
const RetainedState = retained_state_mod.RetainedState;
const DrawOutcome = draw_mod.DrawOutcome;
const DrawPreparation = draw_mod.DrawPreparation;
const Cell = terminal_publication.Cell;
const ViewGeometrySample = debug_geometry_mod.ViewGeometrySample;
const CursorOverlaySample = debug_geometry_mod.CursorOverlaySample;
const RetainedSurfacePresentSample = debug_geometry_mod.RetainedSurfacePresentSample;
const TextPaintSample = debug_geometry_mod.TextPaintSample;

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
    session: *TerminalRuntimeShell,
    blink_style: BlinkStyle = .kitty,
    kitty: kitty_mod.KittyState,
    hover: hover_mod.HoverState = .{},
    pending_open: ?PendingOpen = null,
    pending_presentation_feedback: ?DrawOutcome = null,
    draw_cache: RenderCache,
    retained: RetainedState,
    last_view_geometry: ViewGeometrySample = .{},
    last_cursor_overlay: CursorOverlaySample = .{},
    last_surface_present: RetainedSurfacePresentSample = .{},
    last_text_paint: TextPaintSample = .{},
    blink_last_slow_on: bool = true,
    blink_last_fast_on: bool = true,
    blink_last_active: bool = false,
    blink_phase_changed_pending: bool = false,
    cursor_blink_pause_until: f64 = 0,
    last_terminal_input_time: f64 = 0,
    focus_report_window_events: bool = true,
    focus_report_pane_events: bool = false,
    last_focus_reported: ?bool = null,
    ui_focused: bool = true,
    ui_window_focused: bool = true,
    selection_gesture: terminal_selection.SelectionGesture = .{},
    selection_press_origin: ?shared_types.input.MousePos = null,
    selection_drag_active: bool = false,

    pub const ScrollbarModel = struct {
        allowed: bool,
        visible: bool,
        rows: usize,
        total_lines: usize,
        scroll_offset: usize,
    };

    pub fn init(session: *TerminalRuntimeShell, blink_style: BlinkStyle) TerminalWidget {
        return .{
            .session = session,
            .blink_style = blink_style,
            .kitty = kitty_mod.KittyState.init(session.allocator),
            .hover = .{},
            .pending_open = null,
            .pending_presentation_feedback = null,
            .draw_cache = RenderCache.init(),
            .retained = RetainedState.init(),
            .last_view_geometry = .{},
            .last_cursor_overlay = .{},
            .last_surface_present = .{},
            .last_text_paint = .{},
            .blink_last_slow_on = true,
            .blink_last_fast_on = true,
            .blink_last_active = false,
            .blink_phase_changed_pending = false,
            .last_terminal_input_time = 0,
            .focus_report_window_events = true,
            .focus_report_pane_events = false,
            .last_focus_reported = null,
            .ui_focused = true,
            .ui_window_focused = true,
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
        if (try session_input.reportFocusChanged(self.session, focused)) {
            self.last_focus_reported = focused;
            return true;
        }
        return ui_changed;
    }

    pub fn setUiFocused(self: *TerminalWidget, focused: bool) void {
        if (self.ui_focused == focused) return;
        self.ui_focused = focused;
        if (!focused) {
            self.hover = .{};
        }
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
        self.retained.deinit(self.session.allocator);
        self.kitty.deinit(self.session.allocator);
    }

    pub fn takePendingOpenRequest(self: *TerminalWidget) ?PendingOpen {
        const value = self.pending_open;
        self.pending_open = null;
        return value;
    }

    pub fn stagePresentationFeedback(self: *TerminalWidget, feedback: DrawOutcome) void {
        self.pending_presentation_feedback = feedback;
    }

    pub fn completePendingPresentationFeedback(self: *TerminalWidget, submission: anytype) void {
        const pending = self.pending_presentation_feedback orelse return;
        defer self.pending_presentation_feedback = null;
        presentation_feedback.completeSubmittedPresentationFeedback(self.session, pending, submission);
    }

    pub fn invalidateTextureCache(self: *TerminalWidget) void {
        self.retained.invalidateTextureCache();
    }

    pub fn dumpVisibleAsciiView(self: *TerminalWidget, shell: *Shell) !void {
        var out = std.ArrayList(u8).empty;
        defer out.deinit(self.session.allocator);
        const dump_info = view_state.visibleViewDumpInfo(&self.draw_cache);
        const metrics = shell.refreshWindowGeometryDiagnostics("terminal_visible_ascii_dump");

        try out.writer(self.session.allocator).print(
            "# Zide terminal visible-view dump\npath={s}\nrows={d} cols={d} generation={d} scroll_offset={d} alt_active={d} cursor={d}:{d} cursor_visible={d} screen_reverse={d}\n",
            .{
                visible_ascii_dump_path,
                dump_info.rows,
                dump_info.cols,
                dump_info.generation,
                dump_info.scroll_offset,
                @intFromBool(dump_info.alt_active),
                dump_info.cursor.row,
                dump_info.cursor.col,
                @intFromBool(dump_info.draw_cursor_visible),
                @intFromBool(dump_info.screen_reverse),
            },
        );
        try out.writer(self.session.allocator).print(
            "window={d}x{d} drawable={d}x{d} display={d}x{d} display_index={d} dpi_scale={d:.3},{d:.3} display_scale={d:.3} pixel_density={d:.3} ui_scale={d:.3} render_scale={d:.3}\n",
            .{
                metrics.window_w,
                metrics.window_h,
                metrics.drawable_w,
                metrics.drawable_h,
                metrics.display_w,
                metrics.display_h,
                metrics.display_index,
                metrics.dpi.x,
                metrics.dpi.y,
                metrics.display_scale,
                metrics.pixel_density,
                shell.uiScaleFactor(),
                1.0 / shell.rendererPtr().devicePixelStep(),
            },
        );

        try out.writer(self.session.allocator).print(
            "view_geometry valid={d} generation={d} base=({d:.3},{d:.3}) viewport=({d:.3}x{d:.3}) rows={d} cols={d} cell_logical=({d:.3}x{d:.3}) cell_device=({d}x{d}) baseline={d:.3} ui_scale={d:.3} render_scale={d:.3}\n",
            .{
                @intFromBool(self.last_view_geometry.valid),
                self.last_view_geometry.generation,
                self.last_view_geometry.base_x,
                self.last_view_geometry.base_y,
                self.last_view_geometry.viewport_w,
                self.last_view_geometry.viewport_h,
                self.last_view_geometry.rows,
                self.last_view_geometry.cols,
                self.last_view_geometry.cell_width_logical,
                self.last_view_geometry.cell_height_logical,
                self.last_view_geometry.cell_width_device,
                self.last_view_geometry.cell_height_device,
                self.last_view_geometry.baseline_logical,
                self.last_view_geometry.ui_scale,
                self.last_view_geometry.render_scale,
            },
        );
        try out.writer(self.session.allocator).print(
            "cursor_overlay valid={d} generation={d} row={d} col={d} cp={d} width_units={d} cell=({d:.3},{d:.3},{d:.3},{d:.3}) cursor=({d:.3},{d:.3},{d:.3},{d:.3}) text_input_w={d:.3} edge_inset={d:.3} stroke={d:.3} render_scale={d:.3}\n",
            .{
                @intFromBool(self.last_cursor_overlay.valid),
                self.last_cursor_overlay.generation,
                self.last_cursor_overlay.row,
                self.last_cursor_overlay.col,
                self.last_cursor_overlay.codepoint,
                self.last_cursor_overlay.width_units,
                self.last_cursor_overlay.cell_x,
                self.last_cursor_overlay.cell_y,
                self.last_cursor_overlay.cell_w,
                self.last_cursor_overlay.cell_h,
                self.last_cursor_overlay.cursor_x,
                self.last_cursor_overlay.cursor_y,
                self.last_cursor_overlay.cursor_w,
                self.last_cursor_overlay.cursor_h,
                self.last_cursor_overlay.text_input_w,
                self.last_cursor_overlay.edge_inset,
                self.last_cursor_overlay.stroke,
                self.last_cursor_overlay.render_scale,
            },
        );
        try out.writer(self.session.allocator).print(
            "retained_surface valid={d} generation={d} texture_px=({d}x{d}) target_logical=({d:.3}x{d:.3}) source_logical=({d:.3}x{d:.3}) dest=({d:.3},{d:.3},{d:.3},{d:.3}) scale=({d:.6},{d:.6})\n",
            .{
                @intFromBool(self.last_surface_present.valid),
                self.last_surface_present.generation,
                self.last_surface_present.texture_w_px,
                self.last_surface_present.texture_h_px,
                self.last_surface_present.target_logical_w,
                self.last_surface_present.target_logical_h,
                self.last_surface_present.source_logical_w,
                self.last_surface_present.source_logical_h,
                self.last_surface_present.dest_x,
                self.last_surface_present.dest_y,
                self.last_surface_present.dest_w,
                self.last_surface_present.dest_h,
                self.last_surface_present.scale_x,
                self.last_surface_present.scale_y,
            },
        );
        try out.writer(self.session.allocator).print(
            "text_paint valid={d} generation={d} row={d} col={d} covers_cursor={d} cursor_distance_cols={d} cp={d} width_units={d} source={s} cell=({d:.3},{d:.3},{d:.3},{d:.3}) glyph=({d:.3},{d:.3},{d:.3},{d:.3}) baseline={d:.3} render_scale={d:.3}\n",
            .{
                @intFromBool(self.last_text_paint.valid),
                self.last_text_paint.generation,
                self.last_text_paint.row,
                self.last_text_paint.col,
                @intFromBool(self.last_text_paint.covers_cursor),
                self.last_text_paint.cursor_distance_cols,
                self.last_text_paint.codepoint,
                self.last_text_paint.width_units,
                @tagName(self.last_text_paint.source),
                self.last_text_paint.cell_x,
                self.last_text_paint.cell_y,
                self.last_text_paint.cell_w,
                self.last_text_paint.cell_h,
                self.last_text_paint.glyph.x,
                self.last_text_paint.glyph.y,
                self.last_text_paint.glyph.width,
                self.last_text_paint.glyph.height,
                self.last_text_paint.baseline,
                self.last_text_paint.render_scale,
            },
        );
        if (self.last_cursor_overlay.valid and self.last_text_paint.valid) {
            try out.writer(self.session.allocator).print(
                "cursor_vs_text delta_cell_origin=({d:.3},{d:.3}) delta_overlay_to_glyph=({d:.3},{d:.3},{d:.3},{d:.3})\n",
                .{
                    self.last_cursor_overlay.cell_x - self.last_text_paint.cell_x,
                    self.last_cursor_overlay.cell_y - self.last_text_paint.cell_y,
                    self.last_cursor_overlay.cursor_x - self.last_text_paint.glyph.x,
                    self.last_cursor_overlay.cursor_y - self.last_text_paint.glyph.y,
                    self.last_cursor_overlay.cursor_w - self.last_text_paint.glyph.width,
                    self.last_cursor_overlay.cursor_h - self.last_text_paint.glyph.height,
                },
            );
        }
        if (self.last_surface_present.valid and self.last_view_geometry.valid) {
            try out.writer(self.session.allocator).print(
                "surface_vs_view delta_target_minus_view=({d:.3},{d:.3}) delta_source_minus_view=({d:.3},{d:.3})\n",
                .{
                    self.last_surface_present.target_logical_w - self.last_view_geometry.viewport_w,
                    self.last_surface_present.target_logical_h - self.last_view_geometry.viewport_h,
                    self.last_surface_present.source_logical_w - self.last_view_geometry.viewport_w,
                    self.last_surface_present.source_logical_h - self.last_view_geometry.viewport_h,
                },
            );
        }

        try appendViewportColumnRuler(&out, self.session.allocator, dump_info.cols);
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
        return paste_mod.pasteSystemClipboard(self, clip_opt, html, uri_list, png);
    }

    pub fn scrollbarModel(self: *const TerminalWidget) ScrollbarModel {
        const cache = &self.draw_cache;
        const scrollbar = view_state.scrollbarInfo(cache, session_interaction.mouseReportingEnabled(self.session));
        return .{
            .allowed = scrollbar.allowed,
            .visible = scrollbar.allowed,
            .rows = scrollbar.rows,
            .total_lines = scrollbar.total_lines,
            .scroll_offset = scrollbar.scroll_offset,
        };
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
        const handoff_log = app_logger.logger("terminal.generation_handoff");
        const latest_capture = publication_capture.prepareLatestPresentation(self.session, &self.draw_cache) catch |err| {
            const log = app_logger.logger("terminal.ui.redraw");
            log.logf(.warning, "draw snapshot copy failed err={s}", .{@errorName(err)});
            return .{};
        };
        const capture = latest_capture.capture;
        if (handoff_log.enabled_file or handoff_log.enabled_console) {
            const generation_state = latest_capture.generation_state;
            handoff_log.logf(
                .info,
                "stage=widget_prepare sid={x} last_render={d} captured={d} cur={d} pub={d} presented={d} texture_ready={d}",
                .{
                    @intFromPtr(self.session),
                    self.retained.last_render_generation,
                    capture.presented.generation,
                    generation_state.pending,
                    generation_state.published,
                    generation_state.presented,
                    @intFromBool(self.retained.terminal_texture_ready),
                },
            );
            if (latest_capture.refreshed) {
                handoff_log.logf(
                    .info,
                    "stage=widget_prepare_latest sid={x} last_render={d} captured={d} cur={d} pub={d} presented={d} texture_ready={d}",
                    .{
                        @intFromPtr(self.session),
                        self.retained.last_render_generation,
                        capture.presented.generation,
                        generation_state.pending,
                        generation_state.published,
                        generation_state.presented,
                        @intFromBool(self.retained.terminal_texture_ready),
                    },
                );
            }
        }
        return draw_mod.drawPrepared(self, shell, x, y, width, height, input, DrawPreparation.fromCapture(draw_start, capture));
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

    const run_info = view_state.backgroundRunInfo(&cache, row);
    try out.writer(allocator).print(
        "row={d:0>3} cursor_here={d} cursor_col={d} runs=",
        .{
            row,
            @intFromBool(run_info.cursor_here),
            if (run_info.cursor_col) |cursor_col| @as(i64, @intCast(cursor_col)) else -1,
        },
    );

    var col: usize = 0;
    while (col < cache.cols) {
        const idx = row_start + col;
        if (idx >= cache.cells.items.len) break;
        const run_color = resolvedBackgroundColor(cache.cells.items[idx], run_info.screen_reverse);
        var end_col = col;
        while (end_col + 1 < cache.cols) : (end_col += 1) {
            const next_idx = row_start + end_col + 1;
            if (next_idx >= cache.cells.items.len) break;
            const next_color = resolvedBackgroundColor(cache.cells.items[next_idx], run_info.screen_reverse);
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
