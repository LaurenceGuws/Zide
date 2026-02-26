const std = @import("std");
const app_shell = @import("../../app_shell.zig");
const terminal_mod = @import("../../terminal/core/terminal.zig");
const app_logger = @import("../../app_logger.zig");
const shared_types = @import("../../types/mod.zig");
const time_utils = @import("../renderer/time_utils.zig");
const common = @import("common.zig");
const renderer_mod = @import("../renderer.zig");
const terminal_font_mod = @import("../terminal_font.zig");
const terminal_glyphs = @import("../renderer/terminal_glyphs.zig");
const terminal_underline = @import("../renderer/terminal_underline.zig");

const hover_mod = @import("terminal_widget_hover.zig");
const kitty_mod = @import("terminal_widget_kitty.zig");

const Shell = app_shell.Shell;
const Color = app_shell.Color;
const CursorPos = terminal_mod.CursorPos;
const Cell = terminal_mod.Cell;

const TerminalFont = terminal_font_mod.TerminalFont;
const hb = terminal_font_mod.c;
const DrawContext = terminal_font_mod.DrawContext;
const Rect = terminal_font_mod.Rect;
const Texture = terminal_font_mod.Texture;
const TextureKind = terminal_font_mod.TextureKind;
const Rgba = terminal_font_mod.Rgba;
const Renderer = renderer_mod.Renderer;
const TerminalDisableLigaturesStrategy = renderer_mod.TerminalDisableLigaturesStrategy;

var jitter_debug_enabled_cache: ?bool = null;

fn snapToDevicePixel(value: f32, render_scale: f32) f32 {
    const scale = if (render_scale > 0.0) render_scale else 1.0;
    return @as(f32, @floatFromInt(@as(i32, @intFromFloat(std.math.round(value * scale))))) / scale;
}

pub fn draw(
    self: anytype,
    shell: *Shell,
    x: f32,
    y: f32,
    width: f32,
    height: f32,
    input: shared_types.input.InputSnapshot,
) void {
    self.session.lock();
    defer self.session.unlock();

    const draw_start = app_shell.getTime();
    const r = shell.rendererPtr();
    var cache = self.session.renderCache();
    if (!cache.alt_active and self.session.view_cache_pending.load(.acquire)) {
        self.session.updateViewCacheForScrollLocked();
        cache = self.session.renderCache();
    }
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
    const show_scrollbar = !cache.alt_active and !self.session.mouseReportingEnabled() and total_lines > rows;
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
            draw_cursor_mode: bool,
            cursor_pos: CursorPos,
            ligature_strategy: TerminalDisableLigaturesStrategy,
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

            const draw_ctx = DrawContext{ .ctx = rr, .drawTexture = drawTextureGlyphCache };

            const cursor_row_active = ligature_strategy == .cursor and draw_cursor_mode and row_idx == cursor_pos.row and cursor_pos.col < cols_count;
            const cursor_split_col: usize = if (cursor_row_active) blk: {
                const cursor_cell = row_cells[cursor_pos.col];
                break :blk if (cursor_cell.x > 0) cursor_pos.col - @as(usize, @intCast(cursor_cell.x)) else cursor_pos.col;
            } else 0;
            const cursor_split_end: usize = if (cursor_row_active) blk: {
                const split_cell = row_cells[cursor_split_col];
                const span_w = @as(usize, @max(@as(u8, 1), split_cell.width));
                break :blk @min(cols_count, cursor_split_col + span_w);
            } else 0;

            var col: usize = col_start;
            while (col <= col_end and col < cols_count) {
                const cell0 = row_cells[col];
                if (cell0.x != 0 or cell0.y != 0) {
                    col += 1;
                    continue;
                }
                const span_choice = rr.terminal_font.pickFontForCodepoint(cell0.codepoint);
                const span_hb_font = span_choice.hb_font;
                const span_start_col = col;

                var scan_col: usize = col;
                var prev_root_col: usize = col;
                while (scan_col <= col_end and scan_col < cols_count) {
                    const ccell = row_cells[scan_col];
                    if (ccell.x != 0 or ccell.y != 0) {
                        scan_col += 1;
                        continue;
                    }
                    if (scan_col > span_start_col) {
                        const prev_cell = row_cells[prev_root_col];
                        if (!sameAttrsForShapingRun(prev_cell.attrs, ccell.attrs)) break;
                    }
                    const cwidth_units = @as(usize, @max(@as(u8, 1), ccell.width));
                    const choice = rr.terminal_font.pickFontForCodepoint(ccell.codepoint);
                    if (choice.hb_font != span_hb_font) break;
                    prev_root_col = scan_col;
                    scan_col += cwidth_units;
                }
                var span_end_excl = @min(scan_col, col_end + 1);
                if (cursor_row_active) {
                    if (span_start_col < cursor_split_col and span_end_excl > cursor_split_col) {
                        span_end_excl = cursor_split_col;
                    } else if (span_start_col == cursor_split_col and span_end_excl > cursor_split_end) {
                        span_end_excl = cursor_split_end;
                    }
                }
                if (span_end_excl <= span_start_col) {
                    const advance = @as(usize, @max(@as(u8, 1), row_cells[span_start_col].width));
                    span_end_excl = @min(col_end + 1, span_start_col + advance);
                }
                const span_cols = span_end_excl - span_start_col;

                const disable_programming_ligatures = switch (ligature_strategy) {
                    .never => false,
                    .always => true,
                    .cursor => cursor_row_active and span_start_col == cursor_split_col,
                };
                var shape_features_buf: [16]hb.hb_feature_t = undefined;
                const shape_features_len = rr.collectShapeFeatures(.terminal, disable_programming_ligatures, shape_features_buf[0..]);

                const buffer = hb.hb_buffer_create();
                defer hb.hb_buffer_destroy(buffer);
                var cc: usize = span_start_col;
                while (cc < span_end_excl and cc < cols_count) {
                    const ccell = row_cells[cc];
                    if (ccell.x != 0 or ccell.y != 0) {
                        cc += 1;
                        continue;
                    }
                    const cwidth_units = @as(usize, @max(@as(u8, 1), ccell.width));
                    const cluster: u32 = @intCast(cc - span_start_col);
                    const cp_base: u32 = if (ccell.codepoint == 0) ' ' else ccell.codepoint;
                    hb.hb_buffer_add(buffer, cp_base, cluster);
                    if (ccell.combining_len > 0) {
                        var j: usize = 0;
                        while (j < @as(usize, @intCast(ccell.combining_len)) and j < ccell.combining.len) : (j += 1) {
                            hb.hb_buffer_add(buffer, ccell.combining[j], cluster);
                        }
                    }
                    cc += cwidth_units;
                }
                hb.hb_buffer_guess_segment_properties(buffer);
                hb.hb_shape(
                    span_hb_font,
                    buffer,
                    if (shape_features_len > 0) shape_features_buf[0..].ptr else null,
                    @intCast(shape_features_len),
                );

                // Underlines are per-cell, not per glyph.
                cc = span_start_col;
                while (cc < span_end_excl and cc < cols_count) {
                    const ccell = row_cells[cc];
                    if (ccell.x != 0 or ccell.y != 0) {
                        cc += 1;
                        continue;
                    }
                    const cwidth_units = @as(usize, @max(@as(u8, 1), ccell.width));
                    const cell_x_i = base_x_i + @as(i32, @intCast(cc)) * cell_w_i;
                    const cell_y_i = base_y_i + @as(i32, @intCast(row_idx)) * cell_h_i;
                    const underline_color = Color{ .r = ccell.attrs.underline_color.r, .g = ccell.attrs.underline_color.g, .b = ccell.attrs.underline_color.b, .a = ccell.attrs.underline_color.a };
                    var underline = ccell.attrs.underline;
                    if (ccell.attrs.link_id != 0) {
                        underline = ccell.attrs.link_id == hover_link;
                    }
                    if (ccell.attrs.blink and blink_style_mode != BlinkStyleT.off) {
                        const period: f64 = if (ccell.attrs.blink_fast) @as(f64, 0.5) else @as(f64, 1.0);
                        const phase = @mod(blink_time_s, period * 2.0);
                        if (phase >= period) {
                            cc += cwidth_units;
                            continue;
                        }
                    }
                    if (underline and ccell.codepoint != 0) {
                        terminal_underline.drawUnderline(
                            addTerminalGlyphRect,
                            rr,
                            cell_x_i,
                            cell_y_i,
                            cell_w_i * @as(i32, @intCast(cwidth_units)),
                            cell_h_i,
                            underline_color,
                        );
                    }
                    cc += cwidth_units;
                }

                // Map HarfBuzz output back to the monospace grid by resetting pen position per cell.
                rr.terminal_shape_first_pen_set.items.len = 0;
                rr.terminal_shape_first_pen.items.len = 0;

                rr.terminal_shape_first_pen_set.ensureTotalCapacity(rr.allocator, span_cols) catch {
                    col = span_end_excl;
                    continue;
                };
                rr.terminal_shape_first_pen.ensureTotalCapacity(rr.allocator, span_cols) catch {
                    col = span_end_excl;
                    continue;
                };
                rr.terminal_shape_first_pen_set.items.len = span_cols;
                rr.terminal_shape_first_pen.items.len = span_cols;
                @memset(rr.terminal_shape_first_pen_set.items, false);
                @memset(rr.terminal_shape_first_pen.items, 0);

                var length: c_uint = 0;
                const infos = hb.hb_buffer_get_glyph_infos(buffer, &length);
                const positions = hb.hb_buffer_get_glyph_positions(buffer, &length);
                if (length == 0) {
                    // Fallback: if shaping produces no glyphs, draw per-cell.
                    var fb_col: usize = span_start_col;
                    while (fb_col < span_end_excl and fb_col < cols_count) {
                        const cell = row_cells[fb_col];
                        if (cell.x != 0 or cell.y != 0) {
                            fb_col += 1;
                            continue;
                        }
                        const cell_width_units = @as(usize, @max(@as(u8, 1), cell.width));
                        const cell_x_i = base_x_i + @as(i32, @intCast(fb_col)) * cell_w_i;
                        const cell_y_i = base_y_i + @as(i32, @intCast(row_idx)) * cell_h_i;

                        const fg = Color{ .r = cell.attrs.fg.r, .g = cell.attrs.fg.g, .b = cell.attrs.fg.b, .a = cell.attrs.fg.a };
                        const bg = Color{ .r = cell.attrs.bg.r, .g = cell.attrs.bg.g, .b = cell.attrs.bg.b, .a = cell.attrs.bg.a };
                        const underline_color = Color{ .r = cell.attrs.underline_color.r, .g = cell.attrs.underline_color.g, .b = cell.attrs.underline_color.b, .a = cell.attrs.underline_color.a };

                        const cell_reverse = cell.attrs.reverse != screen_reverse_mode;
                        if (cell.attrs.blink and blink_style_mode != BlinkStyleT.off) {
                            const period: f64 = if (cell.attrs.blink_fast) @as(f64, 0.5) else @as(f64, 1.0);
                            const phase = @mod(blink_time_s, period * 2.0);
                            if (phase >= period) {
                                fb_col += cell_width_units;
                                continue;
                            }
                        }
                        const followed_by_space = blk: {
                            const next_col = fb_col + cell_width_units;
                            if (next_col < cols_count) {
                                const next_cell = row_cells[next_col];
                                break :blk next_cell.codepoint == ' ' or next_cell.codepoint == 0;
                            }
                            break :blk true;
                        };

                        // Underlines already drawn above for this span.
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
                                false,
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
                                false,
                                false,
                                followed_by_space,
                                false,
                            );
                        }

                        fb_col += cell_width_units;
                    }
                    col = span_end_excl;
                    continue;
                }

                const glyph_len: usize = @intCast(length);
                const render_scale = if (rr.terminal_font.render_scale > 0.0) rr.terminal_font.render_scale else 1.0;
                const inv_scale = 1.0 / render_scale;
                var pen_x: f32 = 0;
                var i: usize = 0;
                while (i < glyph_len) : (i += 1) {
                    const cluster_rel_u32: u32 = infos[i].cluster;
                    const pen_before = pen_x;
                    pen_x += (@as(f32, @floatFromInt(positions[i].x_advance)) / 64.0) * inv_scale;

                    if (cluster_rel_u32 >= span_cols) continue;
                    const cluster_rel: usize = @intCast(cluster_rel_u32);
                    const abs_col = span_start_col + cluster_rel;
                    if (abs_col >= row_cells.len) continue;
                    const cell = row_cells[abs_col];
                    if (cell.x != 0 or cell.y != 0) continue;

                    const width_units = @as(usize, @max(@as(u8, 1), cell.width));
                    const cell_x_i = base_x_i + @as(i32, @intCast(abs_col)) * cell_w_i;
                    const cell_y_i = base_y_i + @as(i32, @intCast(row_idx)) * cell_h_i;
                    const cell_x = @as(f32, @floatFromInt(cell_x_i));
                    const cell_y = @as(f32, @floatFromInt(cell_y_i));
                    const cell_w = @as(f32, @floatFromInt(cell_w_i * @as(i32, @intCast(width_units))));
                    const cell_h = @as(f32, @floatFromInt(cell_h_i));

                    if (!rr.terminal_shape_first_pen_set.items[cluster_rel]) {
                        rr.terminal_shape_first_pen_set.items[cluster_rel] = true;
                        rr.terminal_shape_first_pen.items[cluster_rel] = pen_before;
                    }
                    const pen_rel = pen_before - rr.terminal_shape_first_pen.items[cluster_rel];

                    if (cell.attrs.blink and blink_style_mode != BlinkStyleT.off) {
                        const period: f64 = if (cell.attrs.blink_fast) @as(f64, 0.5) else @as(f64, 1.0);
                        const phase = @mod(blink_time_s, period * 2.0);
                        if (phase >= period) continue;
                    }

                    const followed_by_space = blk: {
                        const next_col = abs_col + width_units;
                        if (next_col < row_cells.len) {
                            const next_cell = row_cells[next_col];
                            break :blk next_cell.codepoint == ' ' or next_cell.codepoint == 0;
                        }
                        break :blk true;
                    };

                    const fg = Color{ .r = cell.attrs.fg.r, .g = cell.attrs.fg.g, .b = cell.attrs.fg.b, .a = cell.attrs.fg.a };
                    const bg = Color{ .r = cell.attrs.bg.r, .g = cell.attrs.bg.g, .b = cell.attrs.bg.b, .a = cell.attrs.bg.a };
                    const cell_reverse = cell.attrs.reverse != screen_reverse_mode;
                    const fg_draw = if (cell_reverse) bg else fg;
                    const bg_draw = if (cell_reverse) fg else bg;
                    var behind_rgba = bg_draw.toRgba();
                    behind_rgba.a = 255;
                    rr.text_bg_rgba = behind_rgba;

                    if (cell.codepoint == 0) continue;
                    if (cell.combining_len == 0) {
                        const box_x_i = base_x_i + @as(i32, @intCast(abs_col)) * cell_w_i;
                        const box_y_i = base_y_i + @as(i32, @intCast(row_idx)) * cell_h_i;
                        const box_w_i = cell_w_i * @as(i32, @intCast(width_units));
                        const box_h_i = cell_h_i;
                        if (terminal_glyphs.specialVariantForCodepoint(cell.codepoint)) |variant| {
                            // Keep core box/block glyphs on the procedural path for now.
                            // The sprite migration for U+2500..U+259F is not quality-accepted yet
                            // at fractional scales (e.g. 4k @ 1.6x in btop panel layouts).
                            if (variant == .box) {
                                // Fall through to the procedural box renderer below.
                            } else {
                            const x0 = snapToDevicePixel(@as(f32, @floatFromInt(box_x_i)), render_scale);
                            const x1 = snapToDevicePixel(@as(f32, @floatFromInt(box_x_i + box_w_i)), render_scale);
                            const y0_unsnapped = @as(f32, @floatFromInt(box_y_i));
                            const y1_unsnapped = @as(f32, @floatFromInt(box_y_i + box_h_i));
                            const use_y_snap = variant == .box;
                            const y0 = if (use_y_snap) snapToDevicePixel(y0_unsnapped, render_scale) else y0_unsnapped;
                            const y1 = if (use_y_snap) snapToDevicePixel(y1_unsnapped, render_scale) else y1_unsnapped;
                            const snapped_w = @max(1.0 / render_scale, x1 - x0);
                            const snapped_h = @max(1.0 / render_scale, y1 - y0);
                            const raster_w_i: i32 = @max(1, @as(i32, @intFromFloat(std.math.round(snapped_w * render_scale))));
                            const raster_h_i: i32 = @max(1, @as(i32, @intFromFloat(std.math.round(snapped_h * render_scale))));
                            const sprite_key = rr.terminal_font.specialGlyphSpriteKey(
                                cell.codepoint,
                                raster_w_i,
                                raster_h_i,
                                variant,
                            );
                            const sprite = rr.terminal_font.getSpecialGlyphSprite(sprite_key) orelse rr.terminal_font.getOrCreateSpecialGlyphSprite(
                                cell.codepoint,
                                box_w_i,
                                box_h_i,
                                raster_w_i,
                                raster_h_i,
                                variant,
                            );
                            if (sprite) |sp| {
                                var dest_x = x0;
                                var dest_w = snapped_w;
                                const seam_overdraw = 1.0 / render_scale;
                                if (cell.codepoint == 0xE0B2) { //  flat edge on right
                                    const next_col = abs_col + width_units;
                                    if (next_col < row_cells.len) {
                                        const next_cell = row_cells[next_col];
                                        const next_reverse = next_cell.attrs.reverse != screen_reverse_mode;
                                        const next_bg = if (next_reverse) next_cell.attrs.fg else next_cell.attrs.bg;
                                        if (next_bg.r == fg_draw.r and next_bg.g == fg_draw.g and next_bg.b == fg_draw.b) {
                                            dest_w += seam_overdraw;
                                        }
                                    }
                                } else if (cell.codepoint == 0xE0B0) { //  flat edge on left
                                    if (abs_col > 0) {
                                        const prev_col = abs_col - 1;
                                        const prev_cell = row_cells[prev_col];
                                        const prev_reverse = prev_cell.attrs.reverse != screen_reverse_mode;
                                        const prev_bg = if (prev_reverse) prev_cell.attrs.fg else prev_cell.attrs.bg;
                                        if (prev_bg.r == fg_draw.r and prev_bg.g == fg_draw.g and prev_bg.b == fg_draw.b) {
                                            dest_x -= seam_overdraw;
                                            dest_w += seam_overdraw;
                                        }
                                    }
                                }
                                const dest = terminal_font_mod.Rect{
                                    .x = dest_x,
                                    .y = y0,
                                    .width = dest_w,
                                    .height = snapped_h,
                                };
                                rr.terminal_glyph_cache.addQuad(
                                    rr.terminal_font.coverage_texture,
                                    sp.rect,
                                    dest,
                                    fg_draw.toRgba(),
                                    rr.text_bg_rgba,
                                    .font_coverage,
                                );
                                continue;
                            }
                            if (variant == .powerline) {
                                const special_log = app_logger.logger("terminal.glyph.special");
                                special_log.logf(
                                    "sprite_missing cp=U+{X} variant={s} cell={d}x{d}",
                                    .{ cell.codepoint, @tagName(variant), box_w_i, box_h_i },
                                );
                                // No powerline fallback path: only sprite pipeline is used.
                                continue;
                            }
                            }
                        }
                    }
                    if (cell.combining_len == 0 and isTerminalBoxGlyph(cell.codepoint)) {
                        const box_x_i = base_x_i + @as(i32, @intCast(abs_col)) * cell_w_i;
                        const box_y_i = base_y_i + @as(i32, @intCast(row_idx)) * cell_h_i;
                        const box_w_i = cell_w_i * @as(i32, @intCast(width_units));
                        const box_h_i = cell_h_i;
                        _ = terminal_glyphs.drawBoxGlyphBatched(
                            addTerminalGlyphRect,
                            rr,
                            cell.codepoint,
                            @as(f32, @floatFromInt(box_x_i)),
                            @as(f32, @floatFromInt(box_y_i)),
                            @as(f32, @floatFromInt(box_w_i)),
                            @as(f32, @floatFromInt(box_h_i)),
                            fg_draw,
                        );
                        continue;
                    }

                    drawShapedGlyph(
                        &rr.terminal_font,
                        draw_ctx,
                        span_choice.face,
                        span_choice.want_color,
                        cell.codepoint,
                        infos[i].codepoint,
                        positions[i],
                        pen_rel,
                        cell_x,
                        cell_y,
                        cell_w,
                        cell_h,
                        followed_by_space,
                        fg_draw.toRgba(),
                    );
                }

                col = span_end_excl;
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
                    drawRowGlyphs(shell, view_cells, cols, row, 0, cols - 1, base_x_local, base_y_local, padding_x_i, hover_link_id, screen_reverse, blink_style, blink_time, draw_cursor, cursor, r.terminal_disable_ligatures);
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
                        drawRowGlyphs(shell, view_cells, cols, row, col_start, col_end, base_x_local, base_y_local, padding_x_i, hover_link_id, screen_reverse, blink_style, blink_time, draw_cursor, cursor, r.terminal_disable_ligatures);
                        if (row > 0) {
                            drawRowGlyphs(shell, view_cells, cols, row - 1, col_start, col_end, base_x_local, base_y_local, padding_x_i, hover_link_id, screen_reverse, blink_style, blink_time, draw_cursor, cursor, r.terminal_disable_ligatures);
                        }
                        if (row + 1 < rows) {
                            drawRowGlyphs(shell, view_cells, cols, row + 1, col_start, col_end, base_x_local, base_y_local, padding_x_i, hover_link_id, screen_reverse, blink_style, blink_time, draw_cursor, cursor, r.terminal_disable_ligatures);
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

    if (show_scrollbar and height > 0 and width > 0) {
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
        const current_gen = self.session.currentGeneration();
        if (current_gen == cache.generation) {
            self.session.clearDirty();
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

fn drawTextureGlyphCache(ctx: *anyopaque, texture: Texture, src: Rect, dest: Rect, color: Rgba, kind: TextureKind) void {
    const rr: *Renderer = @ptrCast(@alignCast(ctx));
    rr.terminal_glyph_cache.addQuad(texture, src, dest, color, rr.text_bg_rgba, kind);
}

fn addTerminalGlyphRect(ctx: *anyopaque, x: i32, y: i32, w: i32, h: i32, color: Color) void {
    const rr: *Renderer = @ptrCast(@alignCast(ctx));
    rr.addTerminalGlyphRect(x, y, w, h, color);
}

fn sameColor(a: terminal_mod.Color, b: terminal_mod.Color) bool {
    return a.r == b.r and a.g == b.g and a.b == b.b and a.a == b.a;
}

fn sameAttrsForShapingRun(a: terminal_mod.CellAttrs, b: terminal_mod.CellAttrs) bool {
    // Follow ghostty-like convention: allow background differences without
    // forcing a shaping split; other style changes should split.
    return sameColor(a.fg, b.fg) and
        a.bold == b.bold and
        a.blink == b.blink and
        a.blink_fast == b.blink_fast and
        a.reverse == b.reverse and
        a.underline == b.underline and
        sameColor(a.underline_color, b.underline_color) and
        a.link_id == b.link_id;
}

fn isTerminalBoxGlyph(codepoint: u32) bool {
    return switch (codepoint) {
        0x2500,
        0x2501,
        0x2502,
        0x2503,
        0x256d,
        0x256e,
        0x256f,
        0x2570,
        0x250c,
        0x2510,
        0x2514,
        0x2518,
        0x2574,
        0x2575,
        0x2576,
        0x2577,
        0x251c,
        0x2524,
        0x252c,
        0x2534,
        0x253c,
        0x2580,
        0x2584,
        0x2588,
        0xE0B1,
        0xE0B3,
        => true,
        else => false,
    };
}

fn isPowerlineGlyph(codepoint: u32) bool {
    return (codepoint >= 0xE0B0 and codepoint <= 0xE0BF) or
        codepoint == 0xE0D6 or
        codepoint == 0xE0D7;
}

fn drawShapedGlyph(
    font: *TerminalFont,
    ctx_draw: DrawContext,
    face: hb.FT_Face,
    want_color: bool,
    base_codepoint: u32,
    glyph_id: u32,
    hb_pos: hb.hb_glyph_position_t,
    pen_x_rel: f32,
    x: f32,
    y: f32,
    cell_width: f32,
    cell_height: f32,
    followed_by_space: bool,
    color: Rgba,
) void {
    const glyph = font.getGlyphById(face, glyph_id, want_color, hb_pos.x_advance) catch return;
    const render_scale = if (font.render_scale > 0.0) font.render_scale else 1.0;
    const inv_scale = 1.0 / render_scale;
    const baseline = y + font.baseline_from_top * inv_scale;

    const gx_off = (@as(f32, @floatFromInt(hb_pos.x_offset)) / 64.0) * inv_scale;
    const gy_off = (@as(f32, @floatFromInt(hb_pos.y_offset)) / 64.0) * inv_scale;
    const origin_x = x + pen_x_rel + gx_off;

    const glyph_w = @as(f32, @floatFromInt(glyph.width)) * inv_scale;
    const glyph_h = @as(f32, @floatFromInt(glyph.height)) * inv_scale;
    const bearing_x = @as(f32, @floatFromInt(glyph.bearing_x)) * inv_scale;
    const bearing_y = @as(f32, @floatFromInt(glyph.bearing_y)) * inv_scale;

    const is_symbol_glyph = (base_codepoint >= 0xE000 and base_codepoint <= 0xF8FF) or
        (base_codepoint >= 0xF0000 and base_codepoint <= 0xFFFFD) or
        (base_codepoint >= 0x100000 and base_codepoint <= 0x10FFFD) or
        (base_codepoint >= 0x2700 and base_codepoint <= 0x27BF) or
        (base_codepoint >= 0x2600 and base_codepoint <= 0x26FF);
    const is_powerline_thin = base_codepoint == 0xE0B1 or base_codepoint == 0xE0B3;

    const aspect = if (cell_height > 0) glyph_w / cell_height else 0.0;
    const is_square_or_wide = aspect >= 0.7;
    const allow_width_overflow = if (is_symbol_glyph) true else if (is_square_or_wide) switch (font.overflow_policy) {
        .never => false,
        .always => true,
        .when_followed_by_space => followed_by_space,
    } else false;

    // Only apply width-fit scaling for square/wide glyphs (icons, box-ish symbols).
    // Scaling normal text glyphs to fit the cell can cause visible baseline jitter at
    // certain fractional scales.
    const overflow_eps: f32 = 0.25;
    const should_fit = (!allow_width_overflow) and is_square_or_wide;
    const overflow_scale = if (should_fit and glyph_w > cell_width + overflow_eps and glyph_w > 0) cell_width / glyph_w else 1.0;
    const scaled_w = glyph_w * overflow_scale;
    const scaled_h = glyph_h * overflow_scale;

    const draw_x = if (allow_width_overflow) origin_x + bearing_x * overflow_scale else @max(x, origin_x + bearing_x * overflow_scale);
    const draw_y = (baseline - bearing_y * overflow_scale) - gy_off;
    const snapped_x = snapToDevicePixel(draw_x, render_scale);
    const snapped_y = snapToDevicePixel(draw_y, render_scale);

    const jitter_log = app_logger.logger("terminal.font.jitter");
    if ((jitter_log.enabled_file or jitter_log.enabled_console) and jitterDebugEnabled()) {
        const did_fit_scale = @abs(overflow_scale - 1.0) > 0.001;
        const has_y_offset = hb_pos.y_offset != 0;
        const y_snap_error = draw_y - snapped_y;
        const large_y_snap = @abs(y_snap_error) >= 0.45;
        if (did_fit_scale or has_y_offset or large_y_snap) {
            jitter_log.logf(
                "cp=U+{X:0>4} gid={d} x={d:.2} y={d:.2} cell_w={d:.2} glyph_w={d:.2} bearing_y={d:.2} y_off_26_6={d} draw_y={d:.3} snap_y={d:.3} snap_err={d:.3} scale={d:.4} fit={d} square_or_wide={d}",
                .{
                    base_codepoint,
                    glyph_id,
                    x,
                    y,
                    cell_width,
                    glyph_w,
                    bearing_y,
                    hb_pos.y_offset,
                    draw_y,
                    snapped_y,
                    y_snap_error,
                    overflow_scale,
                    @intFromBool(did_fit_scale),
                    @intFromBool(is_square_or_wide),
                },
            );
        }
    }

    const dest = if (is_powerline_thin) blk: {
        // Powerline separators should lock horizontally to cell edges. Using
        // font side bearings can cause zoom-dependent seams between cells.
        const cell_left = snapToDevicePixel(x, render_scale);
        const cell_right = snapToDevicePixel(x + cell_width, render_scale);
        break :blk terminal_font_mod.Rect{
            .x = cell_left,
            .y = snapped_y,
            .width = @max(inv_scale, cell_right - cell_left),
            .height = scaled_h,
        };
    } else terminal_font_mod.Rect{ .x = snapped_x, .y = snapped_y, .width = scaled_w, .height = scaled_h };

    const draw_color = if (glyph.is_color)
        Rgba{ .r = 255, .g = 255, .b = 255, .a = 255 }
    else
        color;
    if (glyph.is_color) {
        ctx_draw.drawTexture(ctx_draw.ctx, font.color_texture, glyph.rect, dest, draw_color, .rgba);
    } else {
        ctx_draw.drawTexture(ctx_draw.ctx, font.coverage_texture, glyph.rect, dest, draw_color, .font_coverage);
    }
}

fn jitterDebugEnabled() bool {
    if (jitter_debug_enabled_cache) |cached| return cached;
    const raw = std.c.getenv("ZIDE_TERMINAL_FONT_JITTER");
    if (raw == null) {
        jitter_debug_enabled_cache = false;
        return false;
    }
    const value = std.mem.sliceTo(raw.?, 0);
    if (value.len == 0) {
        jitter_debug_enabled_cache = true;
        return true;
    }
    if (std.ascii.eqlIgnoreCase(value, "0") or
        std.ascii.eqlIgnoreCase(value, "false") or
        std.ascii.eqlIgnoreCase(value, "off") or
        std.ascii.eqlIgnoreCase(value, "no"))
    {
        jitter_debug_enabled_cache = false;
        return false;
    }
    jitter_debug_enabled_cache = true;
    return true;
}
