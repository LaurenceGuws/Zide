const std = @import("std");
const builtin = @import("builtin");
const renderer_mod = @import("../renderer.zig");
const terminal_mod = @import("../../terminal/core/terminal.zig");

const Renderer = renderer_mod.Renderer;
const Color = renderer_mod.Color;
const TerminalSession = terminal_mod.TerminalSession;
const CursorPos = terminal_mod.CursorPos;
const Cell = terminal_mod.Cell;

/// Terminal widget for drawing a terminal view
pub const TerminalWidget = struct {
    session: *TerminalSession,

    pub fn init(session: *TerminalSession) TerminalWidget {
        return .{
            .session = session,
        };
    }

    pub fn draw(self: *TerminalWidget, r: *Renderer, x: f32, y: f32, width: f32, height: f32) void {
        const snapshot = self.session.snapshot();
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
        const end_line = total_lines - scroll_offset;
        const start_line = if (end_line > rows) end_line - rows else 0;
        const draw_cursor = scroll_offset == 0;
        const cursor = if (draw_cursor) snapshot.cursor else CursorPos{ .row = rows + 1, .col = cols + 1 };

        // No clipping - let icons overflow freely
        // (sidebar draws last to cover any left overflow, right overflow goes into empty space)

        const base_x = @as(f32, @floatFromInt(@as(i32, @intFromFloat(std.math.round(x)))));
        const base_y = @as(f32, @floatFromInt(@as(i32, @intFromFloat(std.math.round(y)))));

        const scrollbar_w: f32 = 10;
        const scrollbar_x = x + width - scrollbar_w;
        const scrollbar_y = y;
        const scrollbar_h = height;

        const rowSlice = struct {
            fn get(parent: *TerminalWidget, snapshot_cells: []const Cell, history: usize, cols_count: usize, start: usize, row: usize) []const Cell {
                const global_row = start + row;
                if (global_row < history) {
                    if (parent.session.scrollbackRow(global_row)) |history_row| {
                        return history_row;
                    }
                }
                const grid_row = global_row - history;
                const row_start = grid_row * cols_count;
                return snapshot_cells[row_start .. row_start + cols_count];
            }
        }.get;

        const drawRowRange = struct {
            fn render(
                parent: *TerminalWidget,
                renderer: *Renderer,
                snapshot_cells: []const Cell,
                history: usize,
                cols_count: usize,
                start: usize,
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

                const row_cells = rowSlice(parent, snapshot_cells, history, cols_count, start, row_idx);
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
                    };
                    const bg = Color{
                        .r = cell.attrs.bg.r,
                        .g = cell.attrs.bg.g,
                        .b = cell.attrs.bg.b,
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
                    };
                    const bg = Color{
                        .r = cell.attrs.bg.r,
                        .g = cell.attrs.bg.g,
                        .b = cell.attrs.bg.b,
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
            const needs_full = recreated or snapshot.alt_active or snapshot.dirty == .full or (snapshot.dirty != .none and scroll_offset > 0);
            const needs_partial = snapshot.dirty == .partial and !needs_full and scroll_offset == 0;

            if ((needs_full or needs_partial) and r.beginTerminalTexture()) {
                // Disable scissor while updating the offscreen texture.
                // The main draw pass will restore the clip for on-screen drawing.
                r.endClip();
                const base_x_local: f32 = 0;
                const base_y_local: f32 = 0;

                if (needs_full) {
                    var row: usize = 0;
                    while (row < rows) : (row += 1) {
                        drawRowRange(self, r, snapshot.cells, history_len, cols, start_line, row, 0, cols - 1, base_x_local, base_y_local, padding_x_i);
                    }
                } else if (needs_partial) {
                    var row: usize = 0;
                    while (row < rows) : (row += 1) {
                        if (row < snapshot.dirty_rows.len and snapshot.dirty_rows[row]) {
                            const draw_start: usize = 0;
                            const draw_end: usize = cols - 1;
                            drawRowRange(self, r, snapshot.cells, history_len, cols, start_line, row, draw_start, draw_end, base_x_local, base_y_local, padding_x_i);
                            if (row > 0) {
                                drawRowRange(self, r, snapshot.cells, history_len, cols, start_line, row - 1, draw_start, draw_end, base_x_local, base_y_local, padding_x_i);
                            }
                            if (row + 1 < rows) {
                                drawRowRange(self, r, snapshot.cells, history_len, cols, start_line, row + 1, draw_start, draw_end, base_x_local, base_y_local, padding_x_i);
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
            if (self.session.selectionState()) |selection| {
                const total_lines_sel = history_len + rows;
                if (total_lines_sel > 0) {
                    var start_sel = selection.start;
                    var end_sel = selection.end;
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
            const row_cells = rowSlice(self, snapshot.cells, history_len, cols, start_line, cursor.row);
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
            };
            const bg = Color{
                .r = cell.attrs.bg.r,
                .g = cell.attrs.bg.g,
                .b = cell.attrs.bg.b,
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
            self.session.clearDirty();
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

            if (allow_terminal_key) {
                if (r.isKeyPressed(renderer_mod.KEY_ENTER)) {
                    try self.session.sendKey(terminal_mod.VTERM_KEY_ENTER, mod);
                    handled = true;
                } else if (r.isKeyPressed(renderer_mod.KEY_BACKSPACE)) {
                    try self.session.sendKey(terminal_mod.VTERM_KEY_BACKSPACE, mod);
                    handled = true;
                } else if (r.isKeyPressed(renderer_mod.KEY_TAB)) {
                    try self.session.sendKey(terminal_mod.VTERM_KEY_TAB, mod);
                    handled = true;
                } else if (r.isKeyPressed(renderer_mod.KEY_ESCAPE)) {
                    try self.session.sendKey(terminal_mod.VTERM_KEY_ESCAPE, mod);
                    handled = true;
                } else if (r.isKeyPressed(renderer_mod.KEY_UP)) {
                    try self.session.sendKey(terminal_mod.VTERM_KEY_UP, mod);
                    handled = true;
                } else if (r.isKeyPressed(renderer_mod.KEY_DOWN)) {
                    try self.session.sendKey(terminal_mod.VTERM_KEY_DOWN, mod);
                    handled = true;
                } else if (r.isKeyPressed(renderer_mod.KEY_LEFT)) {
                    try self.session.sendKey(terminal_mod.VTERM_KEY_LEFT, mod);
                    handled = true;
                } else if (r.isKeyPressed(renderer_mod.KEY_RIGHT)) {
                    try self.session.sendKey(terminal_mod.VTERM_KEY_RIGHT, mod);
                    handled = true;
                } else if (r.isKeyPressed(renderer_mod.KEY_HOME)) {
                    try self.session.sendKey(terminal_mod.VTERM_KEY_HOME, mod);
                    handled = true;
                } else if (r.isKeyPressed(renderer_mod.KEY_END)) {
                    try self.session.sendKey(terminal_mod.VTERM_KEY_END, mod);
                    handled = true;
                } else if (r.isKeyPressed(renderer_mod.KEY_PAGE_UP)) {
                    try self.session.sendKey(terminal_mod.VTERM_KEY_PAGEUP, mod);
                    handled = true;
                } else if (r.isKeyPressed(renderer_mod.KEY_PAGE_DOWN)) {
                    try self.session.sendKey(terminal_mod.VTERM_KEY_PAGEDOWN, mod);
                    handled = true;
                } else if (r.isKeyPressed(renderer_mod.KEY_INSERT)) {
                    try self.session.sendKey(terminal_mod.VTERM_KEY_INS, mod);
                    handled = true;
                } else if (r.isKeyPressed(renderer_mod.KEY_DELETE)) {
                    try self.session.sendKey(terminal_mod.VTERM_KEY_DEL, mod);
                    handled = true;
                }
            }

            if (!skip_chars) {
                while (r.getCharPressed()) |char| {
                    if (char >= 32) {
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
