const std = @import("std");
const app_shell = @import("../../app_shell.zig");
const terminal_mod = @import("../../terminal/core/terminal.zig");
const app_logger = @import("../../app_logger.zig");
const shared_types = @import("../../types/mod.zig");
const time_utils = @import("../renderer/time_utils.zig");
const common = @import("common.zig");

const hover_mod = @import("terminal_widget_hover.zig");
const kitty_mod = @import("terminal_widget_kitty.zig");

const Shell = app_shell.Shell;
const Color = app_shell.Color;
const CursorPos = terminal_mod.CursorPos;
const Cell = terminal_mod.Cell;

pub fn draw(
    self: anytype,
    shell: *Shell,
    x: f32,
    y: f32,
    width: f32,
    height: f32,
    input: shared_types.input.InputSnapshot,
) void {
    const draw_start = app_shell.getTime();
    const r = shell.rendererPtr();
    const cache = self.session.renderCache();
    const sync_updates = cache.sync_updates_active;
    const screen_reverse = cache.screen_reverse;
    const blink_style = self.blink_style;
    const blink_time = app_shell.getTime();
    if (sync_updates and cache.cells.items.len > 0) {
        const view_cells = cache.cells.items;
        const bg_color = if (view_cells.len > 0) blk: {
            const cell = view_cells[0];
            const reversed = cell.attrs.reverse != screen_reverse;
            const bg = if (reversed) cell.attrs.fg else cell.attrs.bg;
            break :blk Color{
                .r = bg.r,
                .g = bg.g,
                .b = bg.b,
            };
        } else r.theme.background;
        r.drawRect(
            @intFromFloat(x),
            @intFromFloat(y),
            @intFromFloat(width),
            @intFromFloat(height),
            bg_color,
        );
        r.drawTerminalTexture(x, y);
        return;
    }
    const alt_exit = self.session.alt_last_active and !cache.alt_active;
    self.session.alt_last_active = cache.alt_active;
    const draw_start_time = if (alt_exit) app_shell.getTime() else 0;
    const rows = cache.rows;
    const cols = cache.cols;
    const history_len = cache.history_len;
    const total_lines = cache.total_lines;
    const scroll_offset = cache.scroll_offset;
    const viewport_shift_rows = cache.viewport_shift_rows;
    const max_scroll_offset = if (total_lines > rows) total_lines - rows else 0;
    const scroll_changed = scroll_offset != self.last_scroll_offset;
    self.last_scroll_offset = scroll_offset;
    const end_line = total_lines - scroll_offset;
    const start_line = if (end_line > rows) end_line - rows else 0;
    var draw_cursor = scroll_offset == 0 and cache.cursor_visible;
    const cursor = if (draw_cursor) cache.cursor else CursorPos{ .row = rows + 1, .col = cols + 1 };
    const cursor_style = cache.cursor_style;
    if (draw_cursor and cursor_style.blink) {
        if (blink_time >= self.cursor_blink_pause_until) {
            const period: f64 = 0.5;
            const phase = @mod(blink_time, period * 2.0);
            draw_cursor = phase < period;
        }
    }
    const selection_active = cache.selection_active;
    const kitty_generation = cache.kitty_generation;
    var has_blink = false;
    if (blink_style != .off) {
        for (cache.cells.items) |cell| {
            if (cell.attrs.blink) {
                has_blink = true;
                break;
            }
        }
    }

    if (!cache.alt_active and self.session.view_cache_pending.load(.acquire)) {
        self.session.updateViewCacheForScroll();
    }

    self.kitty.updateViews(self.session.allocator, rows, cols, cache.kitty_images.items, cache.kitty_placements.items);

    var upload_stats: kitty_mod.KittyState.UploadStats = .{};
    if (self.kitty.images_view.items.len > 0) {
        self.kitty.primeUploads(self.session.allocator);
        upload_stats = self.kitty.processPendingUploads(shell);
    }

    const view_cells = cache.cells.items;
    const view_dirty_rows = cache.dirty_rows.items;
    const has_kitty = self.kitty.hasKitty();
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
    self.hover.dirty = false;
    const hover_link_id = hover_mod.hoverLinkId(&self.hover);

    const rowSlice = struct {
        fn get(cells: []const Cell, cols_count: usize, row: usize) []const Cell {
            const row_start = row * cols_count;
            if (row_start + cols_count > cells.len) {
                return cells[0..0];
            }
            return cells[row_start .. row_start + cols_count];
        }
    }.get;

    const drawRowBackgrounds = struct {
        fn render(
            renderer: *Shell,
            snapshot_cells: []const Cell,
            cols_count: usize,
            row_idx: usize,
            col_start_in: usize,
            col_end_in: usize,
            base_x_local: f32,
            base_y_local: f32,
            padding_x_i: i32,
            draw_padding: bool,
            screen_reverse_mode: bool,
        ) void {
            const rr = renderer.rendererPtr();
            const cell_w_i: i32 = @intFromFloat(std.math.round(rr.terminal_cell_width));
            const cell_h_i: i32 = @intFromFloat(std.math.round(rr.terminal_cell_height));
            const base_x_i: i32 = @intFromFloat(std.math.round(base_x_local));
            const base_y_i: i32 = @intFromFloat(std.math.round(base_y_local));

            const row_cells = rowSlice(snapshot_cells, cols_count, row_idx);
            if (row_cells.len != cols_count) return;
            const col_start = @min(col_start_in, cols_count - 1);
            const col_end = @min(col_end_in, cols_count - 1);
            if (col_start > col_end) return;

            var col: usize = col_start;
            while (col <= col_end and col < cols_count) : (col += 1) {
                const cell = row_cells[col];
                if (cell.x != 0 or cell.y != 0) {
                    continue;
                }
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
                    fg = rr.theme.link;
                }

                const cell_reverse = cell.attrs.reverse != screen_reverse_mode;
                rr.addTerminalRect(
                    cell_x_i,
                    cell_y_i,
                    cell_w_i_scaled,
                    cell_h_i,
                    if (cell_reverse) fg else bg,
                );

                if (cell.width > 1) {
                    col += cell_width_units - 1;
                }
            }

            if (draw_padding and padding_x_i > 0 and cols_count > 0) {
                const last_cell = row_cells[cols_count - 1];
                const padding_bg = Color{
                    .r = last_cell.attrs.bg.r,
                    .g = last_cell.attrs.bg.g,
                    .b = last_cell.attrs.bg.b,
                };
                const padding_reverse = last_cell.attrs.reverse != screen_reverse_mode;
                rr.addTerminalRect(
                    base_x_i + @as(i32, @intCast(cols_count)) * cell_w_i,
                    base_y_i + @as(i32, @intCast(row_idx)) * cell_h_i,
                    padding_x_i,
                    cell_h_i,
                    if (padding_reverse) Color{
                        .r = last_cell.attrs.fg.r,
                        .g = last_cell.attrs.fg.g,
                        .b = last_cell.attrs.fg.b,
                    } else padding_bg,
                );
            }
        }
    }.render;

    const drawRowGlyphs = struct {
        fn render(
            renderer: *Shell,
            snapshot_cells: []const Cell,
            cols_count: usize,
            row_idx: usize,
            col_start_in: usize,
            col_end_in: usize,
            base_x_local: f32,
            base_y_local: f32,
            padding_x_i: i32,
            hover_link: u32,
            screen_reverse_mode: bool,
            blink_style_mode: anytype,
            blink_time_s: f64,
        ) void {
            _ = padding_x_i;
            const BlinkStyleT = @TypeOf(blink_style_mode);

            const rr = renderer.rendererPtr();
            const cell_w_i: i32 = @intFromFloat(std.math.round(rr.terminal_cell_width));
            const cell_h_i: i32 = @intFromFloat(std.math.round(rr.terminal_cell_height));
            const base_x_i: i32 = @intFromFloat(std.math.round(base_x_local));
            const base_y_i: i32 = @intFromFloat(std.math.round(base_y_local));

            const row_cells = rowSlice(snapshot_cells, cols_count, row_idx);
            if (row_cells.len != cols_count) return;
            const col_start = @min(col_start_in, cols_count - 1);
            const col_end = @min(col_end_in, cols_count - 1);
            if (col_start > col_end) return;

            var col: usize = col_start;
            while (col <= col_end and col < cols_count) : (col += 1) {
                const cell = row_cells[col];
                if (cell.x != 0 or cell.y != 0) {
                    continue;
                }
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
                var underline = cell.attrs.underline;
                if (cell.attrs.link_id != 0) {
                    underline = cell.attrs.link_id == hover_link;
                }

                const cell_reverse = cell.attrs.reverse != screen_reverse_mode;
                if (cell.attrs.blink and blink_style_mode != BlinkStyleT.off) {
                    const period: f64 = if (cell.attrs.blink_fast) @as(f64, 0.5) else @as(f64, 1.0);
                    const phase = @mod(blink_time_s, period * 2.0);
                    if (phase >= period) {
                        if (cell.width > 1) {
                            col += cell_width_units - 1;
                        }
                        continue;
                    }
                }
                const followed_by_space = blk: {
                    const next_col = col + cell_width_units;
                    if (next_col < cols_count) {
                        const next_cell = row_cells[next_col];
                        break :blk next_cell.codepoint == ' ' or next_cell.codepoint == 0;
                    }
                    break :blk true;
                };

                if (cell.combining_len > 0) {
                    rr.drawTerminalCellGraphemeBatched(
                        cell.codepoint,
                        cell.combining[0..@intCast(cell.combining_len)],
                        @as(f32, @floatFromInt(cell_x_i)),
                        @as(f32, @floatFromInt(cell_y_i)),
                        @as(f32, @floatFromInt(cell_w_i * @as(i32, @intCast(cell_width_units)))),
                        @as(f32, @floatFromInt(cell_h_i)),
                        if (cell_reverse) bg else fg,
                        if (cell_reverse) fg else bg,
                        underline_color,
                        cell.attrs.bold,
                        underline,
                        false,
                        followed_by_space,
                        false,
                    );
                } else {
                    rr.drawTerminalCellBatched(
                        cell.codepoint,
                        @as(f32, @floatFromInt(cell_x_i)),
                        @as(f32, @floatFromInt(cell_y_i)),
                        @as(f32, @floatFromInt(cell_w_i * @as(i32, @intCast(cell_width_units)))),
                        @as(f32, @floatFromInt(cell_h_i)),
                        if (cell_reverse) bg else fg,
                        if (cell_reverse) fg else bg,
                        underline_color,
                        cell.attrs.bold,
                        underline,
                        false,
                        followed_by_space,
                        false,
                    );
                }

                if (cell.width > 1) {
                    col += cell_width_units - 1;
                }
            }
        }
    }.render;

    var updated = false;
    if (rows > 0 and cols > 0) {
        const cell_w_i: i32 = @intFromFloat(std.math.round(r.terminal_cell_width));
        const cell_h_i: i32 = @intFromFloat(std.math.round(r.terminal_cell_height));
        const cell_metrics_changed = cell_w_i != self.last_cell_w_i or cell_h_i != self.last_cell_h_i;
        const render_scale_changed = r.render_scale != self.last_render_scale;
        const padding_x_i: i32 = @max(2, @divTrunc(cell_w_i, 2));
        const texture_w = cell_w_i * @as(i32, @intCast(cols)) + padding_x_i;
        const texture_h = cell_h_i * @as(i32, @intCast(rows));
        const recreated = r.ensureTerminalTexture(texture_w, texture_h);
        const kitty_changed = kitty_generation != self.kitty.last_generation;
        const gen_changed = cache.generation != self.last_render_generation;
        var needs_full = recreated or gen_changed or cell_metrics_changed or render_scale_changed or cache.alt_active or cache.dirty == .full or scroll_changed or (cache.dirty != .none and scroll_offset > 0) or has_kitty or kitty_changed or has_blink;
        var needs_partial = cache.dirty == .partial and !needs_full and scroll_offset == 0;
        if (!self.terminal_texture_ready and rows > 0 and cols > 0) {
            needs_full = true;
            needs_partial = false;
        }
        const shift_abs_i: i32 = if (viewport_shift_rows < 0) -viewport_shift_rows else viewport_shift_rows;
        var shifted_rows: usize = 0;
        if (viewport_shift_rows != 0 and scroll_offset == 0 and !needs_full and self.terminal_texture_ready and shift_abs_i > 0 and shift_abs_i < @as(i32, @intCast(rows))) {
            const dy_pixels: i32 = -viewport_shift_rows * cell_h_i;
            if (r.scrollTerminalTexture(0, dy_pixels)) {
                needs_partial = true;
                shifted_rows = @as(usize, @intCast(shift_abs_i));
            } else {
                needs_full = true;
                needs_partial = false;
            }
        } else if (viewport_shift_rows != 0 and scroll_offset == 0 and shift_abs_i > 0) {
            needs_full = true;
            needs_partial = false;
        }

        if ((needs_full or needs_partial) and r.beginTerminalTexture()) {
            // Disable scissor while updating the offscreen texture.
            // The main draw pass will restore the clip for on-screen drawing.
            r.endClip();
            const base_x_local: f32 = 0;
            const base_y_local: f32 = 0;

            if (needs_full) {
                const bg = if (view_cells.len > 0) blk: {
                    const cell = view_cells[0];
                    const reversed = cell.attrs.reverse != screen_reverse;
                    const base_bg = if (reversed) cell.attrs.fg else cell.attrs.bg;
                    break :blk Color{
                        .r = base_bg.r,
                        .g = base_bg.g,
                        .b = base_bg.b,
                    };
                } else r.theme.background;
                r.beginTerminalBatch();
                r.addTerminalRect(0, 0, texture_w, texture_h, bg);
                var row: usize = 0;
                while (row < rows) : (row += 1) {
                    drawRowBackgrounds(shell, view_cells, cols, row, 0, cols - 1, base_x_local, base_y_local, padding_x_i, true, screen_reverse);
                }
                r.flushTerminalBatch();
                if (has_kitty) {
                    self.kitty.cleanupTextures(self.session.allocator, self.kitty.images_view.items);
                    self.kitty.drawImages(self.session.allocator, shell, base_x_local, base_y_local, false, start_line, rows, cols);
                }
                r.beginTerminalGlyphBatch();
                row = 0;
                while (row < rows) : (row += 1) {
                    drawRowGlyphs(shell, view_cells, cols, row, 0, cols - 1, base_x_local, base_y_local, padding_x_i, hover_link_id, screen_reverse, blink_style, blink_time);
                }
                r.flushTerminalGlyphBatch();
                if (has_kitty) {
                    self.kitty.drawImages(self.session.allocator, shell, base_x_local, base_y_local, true, start_line, rows, cols);
                }
            } else if (needs_partial) {
                r.beginTerminalBatch();
                var row: usize = 0;
                const shift_up = viewport_shift_rows > 0;
                while (row < rows) : (row += 1) {
                    const is_shift_row = shifted_rows > 0 and (if (shift_up) row >= rows - shifted_rows else row < shifted_rows);
                    if ((row < view_dirty_rows.len and view_dirty_rows[row]) or is_shift_row) {
                        var col_start: usize = 0;
                        var col_end: usize = cols - 1;
                        if (row < cache.dirty_cols_start.items.len and row < cache.dirty_cols_end.items.len) {
                            col_start = @min(@as(usize, cache.dirty_cols_start.items[row]), cols - 1);
                            col_end = @min(@as(usize, cache.dirty_cols_end.items[row]), cols - 1);
                        }
                        const draw_padding = col_end >= cols - 1;
                        drawRowBackgrounds(shell, view_cells, cols, row, col_start, col_end, base_x_local, base_y_local, padding_x_i, draw_padding, screen_reverse);
                        if (row > 0) {
                            drawRowBackgrounds(shell, view_cells, cols, row - 1, col_start, col_end, base_x_local, base_y_local, padding_x_i, draw_padding, screen_reverse);
                        }
                        if (row + 1 < rows) {
                            drawRowBackgrounds(shell, view_cells, cols, row + 1, col_start, col_end, base_x_local, base_y_local, padding_x_i, draw_padding, screen_reverse);
                        }
                    }
                }
                r.flushTerminalBatch();
                r.beginTerminalGlyphBatch();
                row = 0;
                while (row < rows) : (row += 1) {
                    const is_shift_row = shifted_rows > 0 and (if (shift_up) row >= rows - shifted_rows else row < shifted_rows);
                    if ((row < view_dirty_rows.len and view_dirty_rows[row]) or is_shift_row) {
                        var col_start: usize = 0;
                        var col_end: usize = cols - 1;
                        if (row < cache.dirty_cols_start.items.len and row < cache.dirty_cols_end.items.len) {
                            col_start = @min(@as(usize, cache.dirty_cols_start.items[row]), cols - 1);
                            col_end = @min(@as(usize, cache.dirty_cols_end.items[row]), cols - 1);
                        }
                        drawRowGlyphs(shell, view_cells, cols, row, col_start, col_end, base_x_local, base_y_local, padding_x_i, hover_link_id, screen_reverse, blink_style, blink_time);
                        if (row > 0) {
                            drawRowGlyphs(shell, view_cells, cols, row - 1, col_start, col_end, base_x_local, base_y_local, padding_x_i, hover_link_id, screen_reverse, blink_style, blink_time);
                        }
                        if (row + 1 < rows) {
                            drawRowGlyphs(shell, view_cells, cols, row + 1, col_start, col_end, base_x_local, base_y_local, padding_x_i, hover_link_id, screen_reverse, blink_style, blink_time);
                        }
                    }
                }
                r.flushTerminalGlyphBatch();
            }
            r.endTerminalTexture();
            if (kitty_changed) {
                self.kitty.last_generation = kitty_generation;
            }
            self.terminal_texture_ready = true;
            self.last_render_generation = cache.generation;
            self.last_cell_w_i = cell_w_i;
            self.last_cell_h_i = cell_h_i;
            self.last_render_scale = r.render_scale;
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
        if (rows > 0 and cols > 0) {
            const bg = if (view_cells.len > 0) blk: {
                const cell = view_cells[0];
                const reversed = cell.attrs.reverse != screen_reverse;
                const base_bg = if (reversed) cell.attrs.fg else cell.attrs.bg;
                break :blk Color{
                    .r = base_bg.r,
                    .g = base_bg.g,
                    .b = base_bg.b,
                    .a = base_bg.a,
                };
            } else r.theme.background;
            r.drawRect(
                @intFromFloat(base_x),
                @intFromFloat(base_y),
                @intFromFloat(width),
                @intFromFloat(height),
                bg,
            );
        }
        r.drawTerminalTexture(base_x, base_y);
    }
    if (!has_kitty and self.kitty.textures.count() > 0) {
        self.kitty.cleanupTextures(self.session.allocator, self.kitty.images_view.items);
    }

    if (rows > 0 and cols > 0 and selection_active) {
        const selection_rows = cache.selection_rows.items;
        if (selection_rows.len == rows) {
            const selection_color = Color{
                .r = r.theme.selection.r,
                .g = r.theme.selection.g,
                .b = r.theme.selection.b,
                .a = 140,
            };
            const cell_w_i: i32 = @intFromFloat(std.math.round(r.terminal_cell_width));
            const cell_h_i: i32 = @intFromFloat(std.math.round(r.terminal_cell_height));
            const base_x_i: i32 = @intFromFloat(std.math.round(base_x));
            const base_y_i: i32 = @intFromFloat(std.math.round(base_y));

            var row_idx: usize = 0;
            while (row_idx < rows) : (row_idx += 1) {
                if (!selection_rows[row_idx]) continue;
                const col_start = @as(usize, cache.selection_cols_start.items[row_idx]);
                const col_end = @as(usize, cache.selection_cols_end.items[row_idx]);
                if (col_end < col_start or col_end >= cols) continue;

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

    hover_mod.drawHoverUnderlineOverlay(r, base_x, base_y, rows, cols, hover_link_id, view_cells);

    if (draw_cursor and rows > 0 and cols > 0 and cursor.row < rows and cursor.col < cols and view_cells.len >= rows * cols) {
        const row_cells = rowSlice(view_cells, cols, cursor.row);
        if (row_cells.len != 0) {
            const cell = row_cells[cursor.col];
            const cell_width_units = @as(usize, @max(@as(u8, 1), cell.width));
            const cell_w_i: i32 = @intFromFloat(std.math.round(r.terminal_cell_width));
            const cell_h_i: i32 = @intFromFloat(std.math.round(r.terminal_cell_height));
            const base_x_i: i32 = @intFromFloat(std.math.round(base_x));
            const base_y_i: i32 = @intFromFloat(std.math.round(base_y));
            const cell_x_i = base_x_i + @as(i32, @intCast(cursor.col)) * cell_w_i;
            const cell_y_i = base_y_i + @as(i32, @intCast(cursor.row)) * cell_h_i;
            const cell_x = @as(f32, @floatFromInt(cell_x_i));
            const cell_y = @as(f32, @floatFromInt(cell_y_i));

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
            var underline = cell.attrs.underline;
            if (cell.attrs.link_id != 0) {
                underline = cell.attrs.link_id == hover_link_id;
            }

            const cell_reverse = cell.attrs.reverse != screen_reverse;
            const followed_by_space = blk: {
                const next_col = cursor.col + cell_width_units;
                if (next_col < cols) {
                    const next_cell = row_cells[next_col];
                    break :blk next_cell.codepoint == ' ' or next_cell.codepoint == 0;
                }
                break :blk true;
            };

            const cursor_w_i: i32 = cell_w_i * @as(i32, @intCast(cell_width_units));
            switch (cursor_style.shape) {
                .block => {
                    if (cell.combining_len > 0) {
                        r.drawTerminalCellGrapheme(
                            cell.codepoint,
                            cell.combining[0..@intCast(cell.combining_len)],
                            cell_x,
                            cell_y,
                            @as(f32, @floatFromInt(cursor_w_i)),
                            @as(f32, @floatFromInt(cell_h_i)),
                            if (cell_reverse) bg else fg,
                            if (cell_reverse) fg else bg,
                            underline_color,
                            cell.attrs.bold,
                            underline,
                            true,
                            followed_by_space,
                            true,
                        );
                    } else {
                        r.drawTerminalCell(
                            cell.codepoint,
                            cell_x,
                            cell_y,
                            @as(f32, @floatFromInt(cursor_w_i)),
                            @as(f32, @floatFromInt(cell_h_i)),
                            if (cell_reverse) bg else fg,
                            if (cell_reverse) fg else bg,
                            underline_color,
                            cell.attrs.bold,
                            underline,
                            true,
                            followed_by_space,
                            true,
                        );
                    }
                },
                .underline => {
                    r.drawRect(cell_x_i, cell_y_i + cell_h_i - 2, cursor_w_i, 2, r.theme.cursor);
                },
                .bar => {
                    r.drawRect(cell_x_i, cell_y_i, 2, cell_h_i, r.theme.cursor);
                },
            }
            const composing_cells: usize = if (input.composing_active and input.composing_text.len > 0) blk: {
                var count: usize = 0;
                var count_iter = std.unicode.Utf8Iterator{ .bytes = input.composing_text, .i = 0 };
                while (count_iter.nextCodepoint()) |_| {
                    count += 1;
                }
                break :blk count;
            } else 0;
            const cursor_rect_w = if (composing_cells > 0)
                @as(i32, @intCast(@max(@as(usize, 1), composing_cells))) * cell_w_i
            else
                cell_w_i;
            shell.setTextInputRect(
                cell_x_i,
                cell_y_i,
                cursor_rect_w,
                cell_h_i,
            );

            if (composing_cells > 0) {
                var iter = std.unicode.Utf8Iterator{ .bytes = input.composing_text, .i = 0 };
                var comp_col: usize = 0;
                while (iter.nextCodepoint()) |cp| {
                    const comp_x = cell_x + @as(f32, @floatFromInt(@as(i32, @intCast(comp_col)) * cell_w_i));
                    r.drawTerminalCell(
                        cp,
                        comp_x,
                        cell_y,
                        @as(f32, @floatFromInt(cell_w_i)),
                        @as(f32, @floatFromInt(cell_h_i)),
                        r.theme.foreground,
                        bg,
                        underline_color,
                        false,
                        true,
                        false,
                        true,
                        false,
                    );
                    comp_col += 1;
                }
                const underline_w = @as(i32, @intCast(@max(@as(usize, 1), comp_col))) * cell_w_i;
                r.drawRect(cell_x_i, cell_y_i + cell_h_i - 2, underline_w, 2, r.theme.selection);
            }
        }
    }

    if (height > 0 and width > 0) {
        const track_h = scrollbar_h;
        const min_thumb_h: f32 = 18;
        const ratio = if (max_scroll_offset > 0)
            @as(f32, @floatFromInt(max_scroll_offset - scroll_offset)) / @as(f32, @floatFromInt(max_scroll_offset))
        else
            1.0;
        const thumb = common.computeScrollbarThumb(scrollbar_y, track_h, rows, total_lines, min_thumb_h, ratio);

        r.drawRect(
            @intFromFloat(scrollbar_x),
            @intFromFloat(scrollbar_y),
            @intFromFloat(scrollbar_w),
            @intFromFloat(scrollbar_h),
            r.theme.line_number_bg,
        );
        r.drawRect(
            @intFromFloat(scrollbar_x + 2),
            @intFromFloat(thumb.thumb_y),
            @intFromFloat(scrollbar_w - 4),
            @intFromFloat(thumb.thumb_h),
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

    if (!sync_updates and (updated or cache.dirty == .none)) {
        if (self.session.tryLock()) {
            const current_gen = self.session.currentGeneration();
            if (current_gen == cache.generation) {
                self.session.clearDirty();
            }
            self.session.unlock();
        }
    }

    if (alt_exit) {
        const elapsed_ms = (app_shell.getTime() - draw_start_time) * 1000.0;
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

    const draw_log = app_logger.logger("terminal.ui.redraw");
    if (draw_log.enabled_file or draw_log.enabled_console) {
        const now = app_shell.getTime();
        const elapsed_ms = time_utils.secondsToMs(now - draw_start);
        const has_kitty_images = self.kitty.images_view.items.len > 0;
        if ((elapsed_ms >= 4.0 or has_kitty_images) and (now - self.last_draw_log_time) >= 0.1) {
            self.last_draw_log_time = now;
            draw_log.logf(
                "draw_ms={d:.2} rows={d} cols={d} history={d} cells={d} kitty_images={d} kitty_placements={d}",
                .{
                    elapsed_ms,
                    rows,
                    cols,
                    history_len,
                    rows * cols,
                    self.kitty.images_view.items.len,
                    self.kitty.placements_view.items.len,
                },
            );
        }
    }

    if (self.bench_enabled) {
        const bench_log = app_logger.logger("terminal.ui.bench");
        if (bench_log.enabled_file or bench_log.enabled_console) {
            const now = app_shell.getTime();
            const elapsed_ms = time_utils.secondsToMs(now - draw_start);
            if ((now - self.last_bench_log_time) >= 0.1) {
                self.last_bench_log_time = now;
                bench_log.logf(
                    "draw_ms={d:.2} rows={d} cols={d} upload_images={d} upload_bytes={d}",
                    .{ elapsed_ms, rows, cols, upload_stats.images, upload_stats.bytes },
                );
            }
        }
    }
}
