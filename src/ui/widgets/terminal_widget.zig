const std = @import("std");
const builtin = @import("builtin");
const renderer_mod = @import("../renderer.zig");
const terminal_mod = @import("../../terminal/core/terminal.zig");
const app_logger = @import("../../app_logger.zig");

const Renderer = renderer_mod.Renderer;
const Color = renderer_mod.Color;
const TerminalSession = terminal_mod.TerminalSession;
const CursorPos = terminal_mod.CursorPos;
const Cell = terminal_mod.Cell;

/// Terminal widget for drawing a terminal view
pub const TerminalWidget = struct {
    session: *TerminalSession,
    last_scroll_offset: usize = 0,

    pub fn init(session: *TerminalSession) TerminalWidget {
        return .{
            .session = session,
            .last_scroll_offset = 0,
        };
    }

    pub fn draw(self: *TerminalWidget, r: *Renderer, x: f32, y: f32, width: f32, height: f32) void {
        self.session.lock();
        const snapshot = self.session.snapshot();
        const alt_exit = self.session.alt_last_active and !snapshot.alt_active;
        self.session.alt_last_active = snapshot.alt_active;
        const draw_start_time = if (alt_exit) renderer_mod.getTime() else 0;
        const rows = snapshot.rows;
        const cols = snapshot.cols;
        const history_len = self.session.scrollbackCount();
        const total_lines = history_len + rows;
        var scroll_offset = self.session.scrollOffset();
        const max_scroll_offset = if (total_lines > rows) total_lines - rows else 0;
        if (scroll_offset > max_scroll_offset) {
            self.session.setScrollOffset(max_scroll_offset);
            scroll_offset = max_scroll_offset;
        }
        const scroll_changed = scroll_offset != self.last_scroll_offset;
        self.last_scroll_offset = scroll_offset;
        const end_line = total_lines - scroll_offset;
        const start_line = if (end_line > rows) end_line - rows else 0;
        const draw_cursor = scroll_offset == 0;
        const cursor = if (draw_cursor) snapshot.cursor else CursorPos{ .row = rows + 1, .col = cols + 1 };
        const selection = self.session.selectionState();

        if (rows > 0 and cols > 0) {
            const view_count = rows * cols;
            _ = self.session.view_cells.resize(self.session.allocator, view_count) catch {};
            _ = self.session.view_dirty_rows.resize(self.session.allocator, rows) catch {};
            _ = self.session.view_dirty_cols_start.resize(self.session.allocator, rows) catch {};
            _ = self.session.view_dirty_cols_end.resize(self.session.allocator, rows) catch {};

            if (snapshot.dirty_rows.len == rows) {
                std.mem.copyForwards(bool, self.session.view_dirty_rows.items, snapshot.dirty_rows);
            } else {
                for (self.session.view_dirty_rows.items) |*row_dirty| {
                    row_dirty.* = true;
                }
            }
            if (snapshot.dirty_cols_start.len == rows and snapshot.dirty_cols_end.len == rows) {
                std.mem.copyForwards(u16, self.session.view_dirty_cols_start.items, snapshot.dirty_cols_start);
                std.mem.copyForwards(u16, self.session.view_dirty_cols_end.items, snapshot.dirty_cols_end);
            } else {
                for (self.session.view_dirty_cols_start.items, self.session.view_dirty_cols_end.items) |*col_start, *col_end| {
                    col_start.* = 0;
                    col_end.* = if (cols > 0) @intCast(cols - 1) else 0;
                }
            }

            var row: usize = 0;
            while (row < rows) : (row += 1) {
                const global_row = start_line + row;
                const row_start = row * cols;
                const row_dest = self.session.view_cells.items[row_start .. row_start + cols];
                if (global_row < history_len) {
                    if (self.session.scrollbackRow(global_row)) |history_row| {
                        std.mem.copyForwards(Cell, row_dest, history_row[0..cols]);
                    } else {
                        std.mem.copyForwards(Cell, row_dest, snapshot.cells[0..cols]);
                    }
                } else {
                    const grid_row = global_row - history_len;
                    const src_start = grid_row * cols;
                    std.mem.copyForwards(Cell, row_dest, snapshot.cells[src_start .. src_start + cols]);
                }
            }
        } else {
            self.session.view_cells.clearRetainingCapacity();
            self.session.view_dirty_rows.clearRetainingCapacity();
            self.session.view_dirty_cols_start.clearRetainingCapacity();
            self.session.view_dirty_cols_end.clearRetainingCapacity();
        }
        self.session.unlock();

        const view_cells = self.session.view_cells.items;
        const view_dirty_rows = self.session.view_dirty_rows.items;
        const bg_color = if (view_cells.len > 0) Color{
            .r = view_cells[0].attrs.bg.r,
            .g = view_cells[0].attrs.bg.g,
            .b = view_cells[0].attrs.bg.b,
        } else r.theme.background;
        r.drawRect(
            @intFromFloat(x),
            @intFromFloat(y),
            @intFromFloat(width),
            @intFromFloat(height),
            bg_color,
        );

        // No clipping - let icons overflow freely
        // (sidebar draws last to cover any left overflow, right overflow goes into empty space)

        const base_x = @as(f32, @floatFromInt(@as(i32, @intFromFloat(std.math.round(x)))));
        const base_y = @as(f32, @floatFromInt(@as(i32, @intFromFloat(std.math.round(y)))));

        const scrollbar_w: f32 = 10;
        const scrollbar_x = x + width - scrollbar_w;
        const scrollbar_y = y;
        const scrollbar_h = height;

        const rowSlice = struct {
            fn get(cells: []const Cell, cols_count: usize, row: usize) []const Cell {
                const row_start = row * cols_count;
                return cells[row_start .. row_start + cols_count];
            }
        }.get;

        const drawRowRange = struct {
            fn render(
                renderer: *Renderer,
                snapshot_cells: []const Cell,
                cols_count: usize,
                row_idx: usize,
                col_start_in: usize,
                col_end_in: usize,
                base_x_local: f32,
                base_y_local: f32,
                padding_x_i: i32,
            ) void {
                const cell_w_i: i32 = @intFromFloat(std.math.round(renderer.terminal_cell_width));
                const cell_h_i: i32 = @intFromFloat(std.math.round(renderer.terminal_cell_height));
                const base_x_i: i32 = @intFromFloat(std.math.round(base_x_local));
                const base_y_i: i32 = @intFromFloat(std.math.round(base_y_local));

                const row_cells = rowSlice(snapshot_cells, cols_count, row_idx);
                const col_start = @min(col_start_in, cols_count - 1);
                const col_end = @min(col_end_in, cols_count - 1);
                if (col_start > col_end) return;

                var col: usize = col_start;
                while (col <= col_end and col < cols_count) : (col += 1) {
                    const cell = row_cells[col];
                    const cell_width_units = @as(usize, @max(@as(u8, 1), cell.width));
                    const cell_x_i = base_x_i + @as(i32, @intCast(col)) * cell_w_i;
                    const cell_y_i = base_y_i + @as(i32, @intCast(row_idx)) * cell_h_i;
                    const cell_w_i_scaled = cell_w_i * @as(i32, @intCast(cell_width_units));

                    var fg = Color{
                        .r = cell.attrs.fg.r,
                        .g = cell.attrs.fg.g,
                        .b = cell.attrs.fg.b,
                        .a = cell.attrs.fg.a,
                    };
                    const bg = Color{
                        .r = cell.attrs.bg.r,
                        .g = cell.attrs.bg.g,
                        .b = cell.attrs.bg.b,
                        .a = cell.attrs.bg.a,
                    };
                    if (cell.attrs.link_id != 0) {
                        fg = renderer.theme.link;
                    }

                    renderer.drawRect(
                        cell_x_i,
                        cell_y_i,
                        cell_w_i_scaled,
                        cell_h_i,
                        if (cell.attrs.reverse) fg else bg,
                    );

                    if (cell.width > 1) {
                        col += cell_width_units - 1;
                    }
                }

                if (padding_x_i > 0 and cols_count > 0) {
                    const last_cell = row_cells[cols_count - 1];
                    const padding_bg = Color{
                        .r = last_cell.attrs.bg.r,
                        .g = last_cell.attrs.bg.g,
                        .b = last_cell.attrs.bg.b,
                    };
                    renderer.drawRect(
                        base_x_i + @as(i32, @intCast(cols_count)) * cell_w_i,
                        base_y_i + @as(i32, @intCast(row_idx)) * cell_h_i,
                        padding_x_i,
                        cell_h_i,
                        if (last_cell.attrs.reverse) Color{
                            .r = last_cell.attrs.fg.r,
                            .g = last_cell.attrs.fg.g,
                            .b = last_cell.attrs.fg.b,
                        } else padding_bg,
                    );
                }

                col = col_start;
                while (col <= col_end and col < cols_count) : (col += 1) {
                    const cell = row_cells[col];
                    const cell_width_units = @as(usize, @max(@as(u8, 1), cell.width));
                    const cell_x_i = base_x_i + @as(i32, @intCast(col)) * cell_w_i;
                    const cell_y_i = base_y_i + @as(i32, @intCast(row_idx)) * cell_h_i;

                    const fg = Color{
                        .r = cell.attrs.fg.r,
                        .g = cell.attrs.fg.g,
                        .b = cell.attrs.fg.b,
                        .a = cell.attrs.fg.a,
                    };
                    const bg = Color{
                        .r = cell.attrs.bg.r,
                        .g = cell.attrs.bg.g,
                        .b = cell.attrs.bg.b,
                        .a = cell.attrs.bg.a,
                    };
                    const underline_color = Color{
                        .r = cell.attrs.underline_color.r,
                        .g = cell.attrs.underline_color.g,
                        .b = cell.attrs.underline_color.b,
                        .a = cell.attrs.underline_color.a,
                    };

                    const followed_by_space = blk: {
                        const next_col = col + cell_width_units;
                        if (next_col < cols_count) {
                            const next_cell = row_cells[next_col];
                            break :blk next_cell.codepoint == ' ' or next_cell.codepoint == 0;
                        }
                        break :blk true;
                    };

                    renderer.drawTerminalCell(
                        cell.codepoint,
                        @as(f32, @floatFromInt(cell_x_i)),
                        @as(f32, @floatFromInt(cell_y_i)),
                        @as(f32, @floatFromInt(cell_w_i * @as(i32, @intCast(cell_width_units)))),
                        @as(f32, @floatFromInt(cell_h_i)),
                        if (cell.attrs.reverse) bg else fg,
                        if (cell.attrs.reverse) fg else bg,
                        underline_color,
                        cell.attrs.bold,
                        cell.attrs.underline,
                        false,
                        followed_by_space,
                        false,
                    );

                    if (cell.width > 1) {
                        col += cell_width_units - 1;
                    }
                }
            }
        }.render;

        var updated = false;
        if (rows > 0 and cols > 0) {
            const cell_w_i: i32 = @intFromFloat(std.math.round(r.terminal_cell_width));
            const padding_x_i: i32 = @max(2, @divTrunc(cell_w_i, 2));
            const texture_w = cell_w_i * @as(i32, @intCast(cols)) + padding_x_i;
            const texture_h = @as(i32, @intFromFloat(@round(r.terminal_cell_height * @as(f32, @floatFromInt(rows)))));
            const recreated = r.ensureTerminalTexture(texture_w, texture_h);
            const needs_full = recreated or snapshot.alt_active or snapshot.dirty == .full or scroll_changed or (snapshot.dirty != .none and scroll_offset > 0);
            const needs_partial = snapshot.dirty == .partial and !needs_full and scroll_offset == 0;

            if ((needs_full or needs_partial) and r.beginTerminalTexture()) {
                // Disable scissor while updating the offscreen texture.
                // The main draw pass will restore the clip for on-screen drawing.
                r.endClip();
                const base_x_local: f32 = 0;
                const base_y_local: f32 = 0;

                if (needs_full) {
                    const bg = if (view_cells.len > 0) Color{
                        .r = view_cells[0].attrs.bg.r,
                        .g = view_cells[0].attrs.bg.g,
                        .b = view_cells[0].attrs.bg.b,
                    } else r.theme.background;
                    r.drawRect(0, 0, texture_w, texture_h, bg);
                    var row: usize = 0;
                    while (row < rows) : (row += 1) {
                        drawRowRange(r, view_cells, cols, row, 0, cols - 1, base_x_local, base_y_local, padding_x_i);
                    }
                } else if (needs_partial) {
                    var row: usize = 0;
                    while (row < rows) : (row += 1) {
                        if (row < view_dirty_rows.len and view_dirty_rows[row]) {
                            const draw_start: usize = 0;
                            const draw_end: usize = cols - 1;
                            drawRowRange(r, view_cells, cols, row, draw_start, draw_end, base_x_local, base_y_local, padding_x_i);
                            if (row > 0) {
                                drawRowRange(r, view_cells, cols, row - 1, draw_start, draw_end, base_x_local, base_y_local, padding_x_i);
                            }
                            if (row + 1 < rows) {
                                drawRowRange(r, view_cells, cols, row + 1, draw_start, draw_end, base_x_local, base_y_local, padding_x_i);
                            }
                        }
                    }
                }
                r.endTerminalTexture();
                const base_x_i: i32 = @intFromFloat(std.math.round(base_x));
                const base_y_i: i32 = @intFromFloat(std.math.round(base_y));
                const clip_w_i: i32 = @min(@as(i32, @intFromFloat(std.math.round(width))), cell_w_i * @as(i32, @intCast(cols)));
                const clip_h_i: i32 = @min(@as(i32, @intFromFloat(std.math.round(height))), @as(i32, @intFromFloat(std.math.round(r.terminal_cell_height))) * @as(i32, @intCast(rows)));
                r.beginClip(
                    base_x_i,
                    base_y_i,
                    clip_w_i,
                    clip_h_i,
                );
                updated = true;
            }

            r.drawTerminalTexture(base_x, base_y);
        }

        if (rows > 0 and cols > 0) {
            if (selection) |selection_state| {
                const total_lines_sel = history_len + rows;
                if (total_lines_sel > 0) {
                    var start_sel = selection_state.start;
                    var end_sel = selection_state.end;
                    if (start_sel.row > end_sel.row or (start_sel.row == end_sel.row and start_sel.col > end_sel.col)) {
                        const tmp = start_sel;
                        start_sel = end_sel;
                        end_sel = tmp;
                    }
                    start_sel.row = @min(start_sel.row, total_lines_sel - 1);
                    end_sel.row = @min(end_sel.row, total_lines_sel - 1);
                    start_sel.col = @min(start_sel.col, cols - 1);
                    end_sel.col = @min(end_sel.col, cols - 1);

                    const selection_color = Color{
                        .r = r.theme.selection.r,
                        .g = r.theme.selection.g,
                        .b = r.theme.selection.b,
                        .a = 140,
                    };

                    var row_idx: usize = 0;
                    while (row_idx < rows) : (row_idx += 1) {
                        const global_row = start_line + row_idx;
                        if (global_row < start_sel.row or global_row > end_sel.row) continue;

                        const col_start = if (global_row == start_sel.row) start_sel.col else 0;
                        const col_end = if (global_row == end_sel.row) end_sel.col else cols - 1;
                        if (col_end < col_start) continue;

                        const cell_w_i: i32 = @intFromFloat(std.math.round(r.terminal_cell_width));
                        const cell_h_i: i32 = @intFromFloat(std.math.round(r.terminal_cell_height));
                        const base_x_i: i32 = @intFromFloat(std.math.round(base_x));
                        const base_y_i: i32 = @intFromFloat(std.math.round(base_y));
                        const rect_x = base_x_i + @as(i32, @intCast(col_start)) * cell_w_i;
                        const rect_y = base_y_i + @as(i32, @intCast(row_idx)) * cell_h_i;
                        const rect_w = cell_w_i * @as(i32, @intCast(col_end - col_start + 1));
                        const rect_h = cell_h_i;

                        r.drawRect(
                            rect_x,
                            rect_y,
                            rect_w,
                            rect_h,
                            selection_color,
                        );
                    }
                }
            }
        }

        if (draw_cursor and rows > 0 and cols > 0 and cursor.row < rows and cursor.col < cols) {
            const row_cells = rowSlice(view_cells, cols, cursor.row);
            const cell = row_cells[cursor.col];
            const cell_width_units = @as(usize, @max(@as(u8, 1), cell.width));
            const cell_w_i: i32 = @intFromFloat(std.math.round(r.terminal_cell_width));
            const cell_h_i: i32 = @intFromFloat(std.math.round(r.terminal_cell_height));
            const base_x_i: i32 = @intFromFloat(std.math.round(base_x));
            const base_y_i: i32 = @intFromFloat(std.math.round(base_y));
            const cell_x = @as(f32, @floatFromInt(base_x_i + @as(i32, @intCast(cursor.col)) * cell_w_i));
            const cell_y = @as(f32, @floatFromInt(base_y_i + @as(i32, @intCast(cursor.row)) * cell_h_i));

            var fg = Color{
                .r = cell.attrs.fg.r,
                .g = cell.attrs.fg.g,
                .b = cell.attrs.fg.b,
                .a = cell.attrs.fg.a,
            };
            const bg = Color{
                .r = cell.attrs.bg.r,
                .g = cell.attrs.bg.g,
                .b = cell.attrs.bg.b,
                .a = cell.attrs.bg.a,
            };
            const underline_color = Color{
                .r = cell.attrs.underline_color.r,
                .g = cell.attrs.underline_color.g,
                .b = cell.attrs.underline_color.b,
                .a = cell.attrs.underline_color.a,
            };
            if (cell.attrs.link_id != 0) {
                fg = r.theme.link;
            }

            const followed_by_space = blk: {
                const next_col = cursor.col + cell_width_units;
                if (next_col < cols) {
                    const next_cell = row_cells[next_col];
                    break :blk next_cell.codepoint == ' ' or next_cell.codepoint == 0;
                }
                break :blk true;
            };

            r.drawTerminalCell(
                cell.codepoint,
                cell_x,
                cell_y,
                @as(f32, @floatFromInt(cell_w_i * @as(i32, @intCast(cell_width_units)))),
                @as(f32, @floatFromInt(cell_h_i)),
                if (cell.attrs.reverse) bg else fg,
                if (cell.attrs.reverse) fg else bg,
                underline_color,
                cell.attrs.bold,
                cell.attrs.underline,
                true,
                followed_by_space,
                true,
            );
        }

        if (height > 0 and width > 0) {
            const track_h = scrollbar_h;
            const min_thumb_h: f32 = 18;
            const thumb_h = if (total_lines > rows)
                @max(min_thumb_h, track_h * (@as(f32, @floatFromInt(rows)) / @as(f32, @floatFromInt(total_lines))))
            else
                track_h;
            const available = @max(@as(f32, 1), track_h - thumb_h);
            const ratio = if (max_scroll_offset > 0)
                @as(f32, @floatFromInt(max_scroll_offset - scroll_offset)) / @as(f32, @floatFromInt(max_scroll_offset))
            else
                1.0;
            const thumb_y = scrollbar_y + available * ratio;

            r.drawRect(
                @intFromFloat(scrollbar_x),
                @intFromFloat(scrollbar_y),
                @intFromFloat(scrollbar_w),
                @intFromFloat(scrollbar_h),
                r.theme.line_number_bg,
            );
            r.drawRect(
                @intFromFloat(scrollbar_x + 2),
                @intFromFloat(thumb_y),
                @intFromFloat(scrollbar_w - 4),
                @intFromFloat(thumb_h),
                r.theme.selection,
            );

            // Scrollbar only; no debug chip.
        }

        if (scroll_offset > 0 and width > 0 and height > 0) {
            var label_buf: [48]u8 = undefined;
            const label = std.fmt.bufPrint(&label_buf, "SCROLLBACK {d}", .{scroll_offset}) catch "SCROLLBACK";
            const padding_x: f32 = 6;
            const padding_y: f32 = 3;
            const text_w = @as(f32, @floatFromInt(label.len)) * r.char_width;
            const box_w = text_w + padding_x * 2;
            const box_h = r.char_height + padding_y * 2;
            const desired_x = x + width - scrollbar_w - box_w - 6;
            const box_x = @max(x + 4, desired_x);
            const box_y = y + 6;

            const bg = Color{
                .r = r.theme.line_number_bg.r,
                .g = r.theme.line_number_bg.g,
                .b = r.theme.line_number_bg.b,
                .a = 220,
            };

            r.drawRect(
                @intFromFloat(box_x),
                @intFromFloat(box_y),
                @intFromFloat(box_w),
                @intFromFloat(box_h),
                bg,
            );
            r.drawText(
                label,
                box_x + padding_x,
                box_y + padding_y,
                r.theme.foreground,
            );
        }

        if (updated or snapshot.dirty == .none) {
            self.session.lock();
            const current_gen = self.session.currentGeneration();
            if (current_gen == snapshot.generation) {
                self.session.clearDirty();
            }
            self.session.unlock();
        }

        if (alt_exit) {
            const elapsed_ms = (renderer_mod.getTime() - draw_start_time) * 1000.0;
            const exit_time_ms = self.session.alt_exit_time_ms.swap(-1, .acq_rel);
            const exit_to_draw_ms: f64 = if (exit_time_ms >= 0)
                @as(f64, @floatFromInt(std.time.milliTimestamp() - exit_time_ms))
            else
                -1.0;
            const log = app_logger.logger("terminal.alt");
            log.logf("alt_exit_draw_ms={d:.2} exit_to_draw_ms={d:.2} rows={d} cols={d} history={d} scroll_offset={d}", .{
                elapsed_ms,
                exit_to_draw_ms,
                rows,
                cols,
                history_len,
                scroll_offset,
            });
        }
    }

    /// Handle input, returns true if any input was processed
    pub fn handleInput(
        self: *TerminalWidget,
        r: *Renderer,
        x: f32,
        y: f32,
        width: f32,
        height: f32,
        allow_input: bool,
        scroll_dragging: *bool,
        scroll_grab_offset: *f32,
    ) !bool {
        self.session.lock();
        defer self.session.unlock();
        var handled = false;
        const mouse = r.getMousePos();
        const in_terminal = mouse.x >= x and mouse.x <= x + width and mouse.y >= y and mouse.y <= y + height;
        const scrollbar_w: f32 = 10;
        const scrollbar_x = x + width - scrollbar_w;
        const scrollbar_y = y;
        const scrollbar_h = height;

        const history_len = self.session.scrollbackCount();
        const rows = self.session.gridRows();
        const cols = self.session.gridCols();
        const total_lines = history_len + rows;
        const scroll_offset = self.session.scrollOffset();
        const end_line = total_lines - scroll_offset;
        const start_line = if (end_line > rows) end_line - rows else 0;
        const max_scroll_offset = if (total_lines > rows) total_lines - rows else 0;

        const ctrl = r.isKeyDown(renderer_mod.KEY_LEFT_CONTROL) or r.isKeyDown(renderer_mod.KEY_RIGHT_CONTROL);
        const shift = r.isKeyDown(renderer_mod.KEY_LEFT_SHIFT) or r.isKeyDown(renderer_mod.KEY_RIGHT_SHIFT);
        const alt = r.isKeyDown(renderer_mod.KEY_LEFT_ALT) or r.isKeyDown(renderer_mod.KEY_RIGHT_ALT);
        const super = r.isKeyDown(renderer_mod.KEY_LEFT_SUPER) or r.isKeyDown(renderer_mod.KEY_RIGHT_SUPER);
        var mod: terminal_mod.Modifier = terminal_mod.VTERM_MOD_NONE;
        if (shift) mod |= terminal_mod.VTERM_MOD_SHIFT;
        if (alt) mod |= terminal_mod.VTERM_MOD_ALT;
        if (ctrl) mod |= terminal_mod.VTERM_MOD_CTRL;

        const wheel = r.getMouseWheelMove();
        const mouse_reporting = allow_input and in_terminal and self.session.mouseReportingEnabled();

        if (self.session.takeOscClipboard()) |clip| {
            const cstr: [*:0]const u8 = @ptrCast(clip.ptr);
            r.setClipboardText(cstr);
            handled = true;
        }

        if (mouse_reporting and rows > 0 and cols > 0) {
            const mouse_left_down = r.isMouseButtonDown(renderer_mod.MOUSE_LEFT);
            const mouse_middle_down = r.isMouseButtonDown(renderer_mod.MOUSE_MIDDLE);
            const mouse_right_down = r.isMouseButtonDown(renderer_mod.MOUSE_RIGHT);
            var buttons_down: u8 = 0;
            if (mouse_left_down) buttons_down |= 1;
            if (mouse_middle_down) buttons_down |= 2;
            if (mouse_right_down) buttons_down |= 4;

            var col: usize = 0;
            if (mouse.x > x) {
                col = @as(usize, @intFromFloat((mouse.x - x) / r.terminal_cell_width));
            }
            var row: usize = 0;
            if (mouse.y > y) {
                row = @as(usize, @intFromFloat((mouse.y - y) / r.terminal_cell_height));
            }
            row = @min(row, rows - 1);
            col = @min(col, cols - 1);

            if (wheel != 0) {
                const button: terminal_mod.MouseButton = if (wheel > 0) .wheel_up else .wheel_down;
                if (try self.session.reportMouseEvent(.{ .kind = .wheel, .button = button, .row = row, .col = col, .mod = mod, .buttons_down = buttons_down })) {
                    handled = true;
                }
            }

            if (r.isMouseButtonPressed(renderer_mod.MOUSE_LEFT)) {
                if (try self.session.reportMouseEvent(.{ .kind = .press, .button = .left, .row = row, .col = col, .mod = mod, .buttons_down = buttons_down })) {
                    handled = true;
                }
            }
            if (r.isMouseButtonPressed(renderer_mod.MOUSE_MIDDLE)) {
                if (try self.session.reportMouseEvent(.{ .kind = .press, .button = .middle, .row = row, .col = col, .mod = mod, .buttons_down = buttons_down })) {
                    handled = true;
                }
            }
            if (r.isMouseButtonPressed(renderer_mod.MOUSE_RIGHT)) {
                if (try self.session.reportMouseEvent(.{ .kind = .press, .button = .right, .row = row, .col = col, .mod = mod, .buttons_down = buttons_down })) {
                    handled = true;
                }
            }

            if (r.isMouseButtonReleased(renderer_mod.MOUSE_LEFT)) {
                if (try self.session.reportMouseEvent(.{ .kind = .release, .button = .left, .row = row, .col = col, .mod = mod, .buttons_down = buttons_down })) {
                    handled = true;
                }
            }
            if (r.isMouseButtonReleased(renderer_mod.MOUSE_MIDDLE)) {
                if (try self.session.reportMouseEvent(.{ .kind = .release, .button = .middle, .row = row, .col = col, .mod = mod, .buttons_down = buttons_down })) {
                    handled = true;
                }
            }
            if (r.isMouseButtonReleased(renderer_mod.MOUSE_RIGHT)) {
                if (try self.session.reportMouseEvent(.{ .kind = .release, .button = .right, .row = row, .col = col, .mod = mod, .buttons_down = buttons_down })) {
                    handled = true;
                }
            }

            if (try self.session.reportMouseEvent(.{ .kind = .move, .button = .none, .row = row, .col = col, .mod = mod, .buttons_down = buttons_down })) {
                handled = true;
            }
        }

        if (allow_input) {
            var skip_chars = false;
            const allow_terminal_key = !(builtin.target.os.tag == .macos and super);
            const clearLiveState = struct {
                fn apply(widget: *TerminalWidget) void {
                    if (widget.session.selectionState() != null) {
                        widget.session.clearSelection();
                    }
                    if (widget.session.scrollOffset() > 0) {
                        widget.session.setScrollOffset(0);
                    }
                }
            }.apply;

            if (ctrl and shift and r.isKeyPressed(renderer_mod.KEY_V) and in_terminal) {
                if (r.getClipboardText()) |clip| {
                    clearLiveState(self);
                    if (self.session.bracketedPasteEnabled()) {
                        try self.session.sendText("\x1b[200~");
                        var filtered = std.ArrayList(u8).empty;
                        defer filtered.deinit(self.session.allocator);
                        for (clip) |b| {
                            if (b == 0x1b or b == 0x03) continue;
                            try filtered.append(self.session.allocator, b);
                        }
                        if (filtered.items.len > 0) {
                            try self.session.sendText(filtered.items);
                        }
                        try self.session.sendText("\x1b[201~");
                    } else {
                        try self.session.sendText(clip);
                    }
                    handled = true;
                    skip_chars = true;
                }
            }

            if (ctrl and shift and r.isKeyPressed(renderer_mod.KEY_C)) {
                if (self.session.selectionState()) |selection| {
                    const snapshot = self.session.snapshot();
                    const rows_snapshot = snapshot.rows;
                    const cols_snapshot = snapshot.cols;
                    const history = self.session.scrollbackCount();
                    const total_lines_copy = history + rows_snapshot;
                    if (rows_snapshot > 0 and cols_snapshot > 0 and total_lines_copy > 0) {
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
                        defer text.deinit(r.allocator);

                        var row_idx: usize = start_sel.row;
                        while (row_idx <= end_sel.row and row_idx < total_lines_copy) : (row_idx += 1) {
                            const row_cells = blk: {
                                if (row_idx < history) {
                                    if (self.session.scrollbackRow(row_idx)) |history_row| break :blk history_row;
                                }
                                const grid_row = row_idx - history;
                                const row_start = grid_row * cols_snapshot;
                                break :blk snapshot.cells[row_start .. row_start + cols_snapshot];
                            };

                            const col_start = if (row_idx == start_sel.row) start_sel.col else 0;
                            const col_end = if (row_idx == end_sel.row) end_sel.col else cols_snapshot - 1;
                            var col_idx: usize = col_start;
                            while (col_idx <= col_end and col_idx < cols_snapshot) : (col_idx += 1) {
                                const cell = row_cells[col_idx];
                                if (cell.codepoint == 0) {
                                    _ = text.append(r.allocator, ' ') catch {};
                                    continue;
                                }
                                var buf: [4]u8 = undefined;
                                const len = std.unicode.utf8Encode(@intCast(cell.codepoint), &buf) catch 0;
                                if (len > 0) {
                                    _ = text.appendSlice(r.allocator, buf[0..len]) catch {};
                                }
                            }

                            // Trim trailing spaces
                            while (text.items.len > 0 and text.items[text.items.len - 1] == ' ') {
                                _ = text.pop();
                            }

                            if (row_idx != end_sel.row) {
                                _ = text.append(r.allocator, '\n') catch {};
                            }
                        }

                        _ = text.append(r.allocator, 0) catch {};
                        const cstr: [*:0]const u8 = @ptrCast(text.items.ptr);
                        r.setClipboardText(cstr);
                        handled = true;
                        skip_chars = true;
                    }
                }
            }

            if (!skip_chars and allow_terminal_key) {
                while (r.getKeyPressed()) |key| {
                    const handled_key = blk: {
                        switch (key) {
                            renderer_mod.KEY_ENTER => {
                                try self.session.sendKey(terminal_mod.VTERM_KEY_ENTER, mod);
                                break :blk true;
                            },
                            renderer_mod.KEY_BACKSPACE => {
                                try self.session.sendKey(terminal_mod.VTERM_KEY_BACKSPACE, mod);
                                break :blk true;
                            },
                            renderer_mod.KEY_TAB => {
                                try self.session.sendKey(terminal_mod.VTERM_KEY_TAB, mod);
                                break :blk true;
                            },
                            renderer_mod.KEY_ESCAPE => {
                                try self.session.sendKey(terminal_mod.VTERM_KEY_ESCAPE, mod);
                                break :blk true;
                            },
                            renderer_mod.KEY_UP => {
                                try self.session.sendKey(terminal_mod.VTERM_KEY_UP, mod);
                                break :blk true;
                            },
                            renderer_mod.KEY_DOWN => {
                                try self.session.sendKey(terminal_mod.VTERM_KEY_DOWN, mod);
                                break :blk true;
                            },
                            renderer_mod.KEY_LEFT => {
                                try self.session.sendKey(terminal_mod.VTERM_KEY_LEFT, mod);
                                break :blk true;
                            },
                            renderer_mod.KEY_RIGHT => {
                                try self.session.sendKey(terminal_mod.VTERM_KEY_RIGHT, mod);
                                break :blk true;
                            },
                            renderer_mod.KEY_HOME => {
                                try self.session.sendKey(terminal_mod.VTERM_KEY_HOME, mod);
                                break :blk true;
                            },
                            renderer_mod.KEY_END => {
                                try self.session.sendKey(terminal_mod.VTERM_KEY_END, mod);
                                break :blk true;
                            },
                            renderer_mod.KEY_PAGE_UP => {
                                try self.session.sendKey(terminal_mod.VTERM_KEY_PAGEUP, mod);
                                break :blk true;
                            },
                            renderer_mod.KEY_PAGE_DOWN => {
                                try self.session.sendKey(terminal_mod.VTERM_KEY_PAGEDOWN, mod);
                                break :blk true;
                            },
                            renderer_mod.KEY_INSERT => {
                                try self.session.sendKey(terminal_mod.VTERM_KEY_INS, mod);
                                break :blk true;
                            },
                            renderer_mod.KEY_DELETE => {
                                try self.session.sendKey(terminal_mod.VTERM_KEY_DEL, mod);
                                break :blk true;
                            },
                            else => break :blk false,
                        }
                    };

                    if (handled_key) {
                        clearLiveState(self);
                        handled = true;
                        continue;
                    }

                    if (ctrl or alt or shift) {
                        var maybe_char: u32 = 0;
                        switch (key) {
                            renderer_mod.KEY_A => maybe_char = if (shift) 'A' else 'a',
                            renderer_mod.KEY_B => maybe_char = if (shift) 'B' else 'b',
                            renderer_mod.KEY_C => maybe_char = if (shift) 'C' else 'c',
                            renderer_mod.KEY_D => maybe_char = if (shift) 'D' else 'd',
                            renderer_mod.KEY_E => maybe_char = if (shift) 'E' else 'e',
                            renderer_mod.KEY_F => maybe_char = if (shift) 'F' else 'f',
                            renderer_mod.KEY_G => maybe_char = if (shift) 'G' else 'g',
                            renderer_mod.KEY_H => maybe_char = if (shift) 'H' else 'h',
                            renderer_mod.KEY_I => maybe_char = if (shift) 'I' else 'i',
                            renderer_mod.KEY_J => maybe_char = if (shift) 'J' else 'j',
                            renderer_mod.KEY_K => maybe_char = if (shift) 'K' else 'k',
                            renderer_mod.KEY_L => maybe_char = if (shift) 'L' else 'l',
                            renderer_mod.KEY_M => maybe_char = if (shift) 'M' else 'm',
                            renderer_mod.KEY_N => maybe_char = if (shift) 'N' else 'n',
                            renderer_mod.KEY_O => maybe_char = if (shift) 'O' else 'o',
                            renderer_mod.KEY_P => maybe_char = if (shift) 'P' else 'p',
                            renderer_mod.KEY_Q => maybe_char = if (shift) 'Q' else 'q',
                            renderer_mod.KEY_R => maybe_char = if (shift) 'R' else 'r',
                            renderer_mod.KEY_S => maybe_char = if (shift) 'S' else 's',
                            renderer_mod.KEY_T => maybe_char = if (shift) 'T' else 't',
                            renderer_mod.KEY_U => maybe_char = if (shift) 'U' else 'u',
                            renderer_mod.KEY_V => maybe_char = if (shift) 'V' else 'v',
                            renderer_mod.KEY_W => maybe_char = if (shift) 'W' else 'w',
                            renderer_mod.KEY_X => maybe_char = if (shift) 'X' else 'x',
                            renderer_mod.KEY_Y => maybe_char = if (shift) 'Y' else 'y',
                            renderer_mod.KEY_Z => maybe_char = if (shift) 'Z' else 'z',
                            renderer_mod.KEY_ZERO => maybe_char = if (shift) ')' else '0',
                            renderer_mod.KEY_ONE => maybe_char = if (shift) '!' else '1',
                            renderer_mod.KEY_TWO => maybe_char = if (shift) '@' else '2',
                            renderer_mod.KEY_THREE => maybe_char = if (shift) '#' else '3',
                            renderer_mod.KEY_FOUR => maybe_char = if (shift) '$' else '4',
                            renderer_mod.KEY_FIVE => maybe_char = if (shift) '%' else '5',
                            renderer_mod.KEY_SIX => maybe_char = if (shift) '^' else '6',
                            renderer_mod.KEY_SEVEN => maybe_char = if (shift) '&' else '7',
                            renderer_mod.KEY_EIGHT => maybe_char = if (shift) '*' else '8',
                            renderer_mod.KEY_NINE => maybe_char = if (shift) '(' else '9',
                            renderer_mod.KEY_SPACE => maybe_char = ' ',
                            renderer_mod.KEY_MINUS => maybe_char = if (shift) '_' else '-',
                            renderer_mod.KEY_EQUAL => maybe_char = if (shift) '+' else '=',
                            renderer_mod.KEY_LEFT_BRACKET => maybe_char = if (shift) '{' else '[',
                            renderer_mod.KEY_RIGHT_BRACKET => maybe_char = if (shift) '}' else ']',
                            renderer_mod.KEY_BACKSLASH => maybe_char = if (shift) '|' else '\\',
                            renderer_mod.KEY_SEMICOLON => maybe_char = if (shift) ':' else ';',
                            renderer_mod.KEY_APOSTROPHE => maybe_char = if (shift) '"' else '\'',
                            renderer_mod.KEY_GRAVE => maybe_char = if (shift) '~' else '`',
                            renderer_mod.KEY_COMMA => maybe_char = if (shift) '<' else ',',
                            renderer_mod.KEY_PERIOD => maybe_char = if (shift) '>' else '.',
                            renderer_mod.KEY_SLASH => maybe_char = if (shift) '?' else '/',
                            else => {},
                        }
                        if (maybe_char != 0) {
                            clearLiveState(self);
                            try self.session.sendChar(maybe_char, mod);
                            handled = true;
                        }
                    }
                }
            }

            if (!skip_chars) {
                while (r.getCharPressed()) |char| {
                    if (char >= 32) {
                        clearLiveState(self);
                        try self.session.sendChar(char, mod);
                        handled = true;
                    }
                }
            }

            if (!mouse_reporting and in_terminal) {
                if (r.isMouseButtonPressed(renderer_mod.MOUSE_LEFT)) {
                    const local_x = mouse.x - x;
                    const local_y = mouse.y - y;
                    const col = @as(usize, @intFromFloat(local_x / r.terminal_cell_width));
                    const row = @as(usize, @intFromFloat(local_y / r.terminal_cell_height));
                    if (cols > 0 and rows > 0) {
                        const clamped_col = @min(col, cols - 1);
                        const clamped_row = @min(row, rows - 1);
                        const global_row = start_line + clamped_row;
                        if (global_row < history_len + rows) {
                            self.session.startSelection(global_row, clamped_col);
                            handled = true;
                        }
                    }
                }

                if (r.isMouseButtonDown(renderer_mod.MOUSE_LEFT)) {
                    if (self.session.selectionState()) |_| {
                        const local_x = mouse.x - x;
                        const local_y = mouse.y - y;
                        const col = @as(usize, @intFromFloat(local_x / r.terminal_cell_width));
                        const row = @as(usize, @intFromFloat(local_y / r.terminal_cell_height));
                        if (cols > 0 and rows > 0) {
                            const clamped_col = @min(col, cols - 1);
                            const clamped_row = @min(row, rows - 1);
                            const global_row = start_line + clamped_row;
                            if (global_row < history_len + rows) {
                                self.session.updateSelection(global_row, clamped_col);
                                handled = true;
                            }
                        }

                        // Autoscroll when dragging outside terminal area
                        if (mouse.y < y) {
                            self.session.scrollBy(1);
                            handled = true;
                        } else if (mouse.y > y + height) {
                            self.session.scrollBy(-1);
                            handled = true;
                        }
                    }
                }

                if (r.isMouseButtonReleased(renderer_mod.MOUSE_LEFT)) {
                    if (self.session.selectionState() != null) {
                        self.session.finishSelection();
                        handled = true;
                    }
                }
            }

            if (!mouse_reporting and in_terminal) {
                if (r.isMouseButtonPressed(renderer_mod.MOUSE_MIDDLE)) {
                    if (r.getClipboardText()) |clip| {
                        if (self.session.bracketedPasteEnabled()) {
                            try self.session.sendText("\x1b[200~");
                            try self.session.sendText(clip);
                            try self.session.sendText("\x1b[201~");
                        } else {
                            try self.session.sendText(clip);
                        }
                        handled = true;
                    }
                }
                if (wheel != 0) {
                    const delta: isize = if (wheel > 0) 3 else -3;
                    self.session.scrollBy(delta);
                    handled = true;
                }
            }

            const mouse_on_scrollbar = mouse.x >= scrollbar_x and mouse.x <= scrollbar_x + scrollbar_w and mouse.y >= scrollbar_y and mouse.y <= scrollbar_y + scrollbar_h;
            if (!mouse_reporting and in_terminal and mouse_on_scrollbar) {
                if (r.isMouseButtonPressed(renderer_mod.MOUSE_LEFT)) {
                    scroll_dragging.* = true;
                    const track_h = scrollbar_h;
                    const min_thumb_h: f32 = 18;
                    const thumb_h = if (total_lines > rows)
                        @max(min_thumb_h, track_h * (@as(f32, @floatFromInt(rows)) / @as(f32, @floatFromInt(total_lines))))
                    else
                        track_h;
                    const available = @max(@as(f32, 1), track_h - thumb_h);
                    const scroll_offset_local = self.session.scrollOffset();
                    const ratio = if (max_scroll_offset > 0)
                        @as(f32, @floatFromInt(max_scroll_offset - scroll_offset_local)) / @as(f32, @floatFromInt(max_scroll_offset))
                    else
                        1.0;
                    const thumb_y = scrollbar_y + available * ratio;
                    scroll_grab_offset.* = mouse.y - thumb_y;
                    handled = true;
                }
            }

            if (!mouse_reporting and scroll_dragging.*) {
                if (r.isMouseButtonDown(renderer_mod.MOUSE_LEFT)) {
                    const track_h = scrollbar_h;
                    const min_thumb_h: f32 = 18;
                    const thumb_h = if (total_lines > rows)
                        @max(min_thumb_h, track_h * (@as(f32, @floatFromInt(rows)) / @as(f32, @floatFromInt(total_lines))))
                    else
                        track_h;
                    const available = @max(@as(f32, 1), track_h - thumb_h);
                    const clamped_mouse = @min(@max(mouse.y - scroll_grab_offset.*, scrollbar_y), scrollbar_y + available);
                    const ratio = if (available > 0) (clamped_mouse - scrollbar_y) / available else 0;
                    const target_offset = @as(usize, @intFromFloat(@round(@as(f32, @floatFromInt(max_scroll_offset)) * (1.0 - ratio))));
                    self.session.setScrollOffset(target_offset);
                    handled = true;
                } else {
                    scroll_dragging.* = false;
                }
            }
        }

        return handled;
    }
};
