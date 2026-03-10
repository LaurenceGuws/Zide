const std = @import("std");
const app_shell = @import("../../app_shell.zig");
const app_logger = @import("../../app_logger.zig");
const terminal_mod = @import("../../terminal/core/terminal.zig");
const renderer_mod = @import("../renderer.zig");
const terminal_font_mod = @import("../terminal_font.zig");
const terminal_glyphs = @import("../renderer/terminal_glyphs.zig");
const terminal_underline = @import("../renderer/terminal_underline.zig");

const Shell = app_shell.Shell;
const Color = app_shell.Color;
const CursorPos = terminal_mod.CursorPos;
const Cell = terminal_mod.Cell;
const TerminalFont = terminal_font_mod.TerminalFont;
const hb = terminal_font_mod.c;
const DrawContext = terminal_font_mod.DrawContext;
const Renderer = renderer_mod.Renderer;
const TerminalDisableLigaturesStrategy = renderer_mod.TerminalDisableLigaturesStrategy;
const Rgba = terminal_font_mod.Rgba;

const kitty_unicode_placeholder: u32 = 0x10EEEE;

pub fn snapToDevicePixel(value: f32, render_scale: f32) f32 {
    const scale = if (render_scale > 0.0) render_scale else 1.0;
    return @as(f32, @floatFromInt(@as(i32, @intFromFloat(std.math.round(value * scale))))) / scale;
}

fn rowSlice(cells: []const Cell, cols_count: usize, row: usize) []const Cell {
    const row_start = row * cols_count;
    if (row_start + cols_count > cells.len) return cells[0..0];
    return cells[row_start .. row_start + cols_count];
}

pub fn drawRowBackgrounds(
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
        if (cell.x != 0 or cell.y != 0) continue;
        const cell_width_units = @as(usize, @max(@as(u8, 1), cell.width));
        const cell_x_i = base_x_i + @as(i32, @intCast(col)) * cell_w_i;
        const cell_y_i = base_y_i + @as(i32, @intCast(row_idx)) * cell_h_i;
        const cell_w_i_scaled = cell_w_i * @as(i32, @intCast(cell_width_units));

        var fg = Color{ .r = cell.attrs.fg.r, .g = cell.attrs.fg.g, .b = cell.attrs.fg.b, .a = cell.attrs.fg.a };
        const bg = Color{ .r = cell.attrs.bg.r, .g = cell.attrs.bg.g, .b = cell.attrs.bg.b, .a = cell.attrs.bg.a };
        if (cell.attrs.link_id != 0) fg = rr.theme.link;

        const cell_reverse = cell.attrs.reverse != screen_reverse_mode;
        rr.addTerminalRect(cell_x_i, cell_y_i, cell_w_i_scaled, cell_h_i, if (cell_reverse) fg else bg);
        if (cell.width > 1) col += cell_width_units - 1;
    }

    if (draw_padding and padding_x_i > 0 and cols_count > 0) {
        const last_cell = row_cells[cols_count - 1];
        const padding_bg = Color{ .r = last_cell.attrs.bg.r, .g = last_cell.attrs.bg.g, .b = last_cell.attrs.bg.b };
        const padding_reverse = last_cell.attrs.reverse != screen_reverse_mode;
        rr.addTerminalRect(
            base_x_i + @as(i32, @intCast(cols_count)) * cell_w_i,
            base_y_i + @as(i32, @intCast(row_idx)) * cell_h_i,
            padding_x_i,
            cell_h_i,
            if (padding_reverse) Color{ .r = last_cell.attrs.fg.r, .g = last_cell.attrs.fg.g, .b = last_cell.attrs.fg.b } else padding_bg,
        );
    }
}

fn drawTextureGlyphCache(ctx: *anyopaque, texture: terminal_font_mod.Texture, src: terminal_font_mod.Rect, dest: terminal_font_mod.Rect, color: terminal_font_mod.Rgba, kind: terminal_font_mod.TextureKind) void {
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
        0x2500, 0x2501, 0x2502, 0x2503, 0x256d, 0x256e, 0x256f, 0x2570,
        0x250c, 0x2510, 0x2514, 0x2518, 0x2574, 0x2575, 0x2576, 0x2577,
        0x251c, 0x2524, 0x252c, 0x2534, 0x253c, 0x2580, 0x2584, 0x2588,
        0xE0B1, 0xE0B3,
        => true,
        else => false,
    };
}

fn jitterDebugEnabled() bool {
    const raw = std.c.getenv("ZIDE_TERMINAL_FONT_JITTER");
    if (raw == null) return false;
    const value = std.mem.sliceTo(raw.?, 0);
    if (value.len == 0) return true;
    return !(std.ascii.eqlIgnoreCase(value, "0") or
        std.ascii.eqlIgnoreCase(value, "false") or
        std.ascii.eqlIgnoreCase(value, "off") or
        std.ascii.eqlIgnoreCase(value, "no"));
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
    const glyph = font.getGlyphById(face, glyph_id, want_color, hb_pos.x_advance) catch |err| {
        const log = app_logger.logger("terminal.draw");
        log.logf(.warning, "shaped glyph lookup failed cp=U+{X} glyph_id={d} err={s}", .{ base_codepoint, glyph_id, @errorName(err) });
        return;
    };
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
    const overflow_eps: f32 = 0.25;
    const should_fit = (!allow_width_overflow) and is_square_or_wide;
    const overflow_scale = if (should_fit and glyph_w > cell_width + overflow_eps and glyph_w > 0) cell_width / glyph_w else 1.0;
    const scaled_w = glyph_w * overflow_scale;
    const scaled_h = glyph_h * overflow_scale;
    const draw_x = if (allow_width_overflow) origin_x + bearing_x * overflow_scale else @max(x, origin_x + bearing_x * overflow_scale);
    const draw_y = (baseline - bearing_y * overflow_scale) - gy_off;
    const snapped_x = snapToDevicePixel(draw_x, render_scale);
    const snapped_y = snapToDevicePixel(draw_y, render_scale);

    if (jitterDebugEnabled()) {
        const did_fit_scale = @abs(overflow_scale - 1.0) > 0.001;
        const has_y_offset = hb_pos.y_offset != 0;
        const y_snap_error = draw_y - snapped_y;
        const large_y_snap = @abs(y_snap_error) >= 0.45;
        if (did_fit_scale or has_y_offset or large_y_snap) {
            const jitter_log = app_logger.logger("terminal.font.jitter");
            jitter_log.logf(.info, "cp=U+{X:0>4} gid={d} x={d:.2} y={d:.2} cell_w={d:.2} glyph_w={d:.2} bearing_y={d:.2} y_off_26_6={d} draw_y={d:.3} snap_y={d:.3} snap_err={d:.3} scale={d:.4} fit={d} square_or_wide={d}", .{ base_codepoint, glyph_id, x, y, cell_width, glyph_w, bearing_y, hb_pos.y_offset, draw_y, snapped_y, y_snap_error, overflow_scale, @intFromBool(did_fit_scale), @intFromBool(is_square_or_wide) });
        }
    }

    const dest = if (is_powerline_thin) blk: {
        const cell_left = snapToDevicePixel(x, render_scale);
        const cell_right = snapToDevicePixel(x + cell_width, render_scale);
        break :blk terminal_font_mod.Rect{ .x = cell_left, .y = snapped_y, .width = @max(inv_scale, cell_right - cell_left), .height = scaled_h };
    } else terminal_font_mod.Rect{ .x = snapped_x, .y = snapped_y, .width = scaled_w, .height = scaled_h };

    const draw_color = if (glyph.is_color) Rgba{ .r = 255, .g = 255, .b = 255, .a = 255 } else color;
    if (glyph.is_color) {
        ctx_draw.drawTexture(ctx_draw.ctx, font.color_texture, glyph.rect, dest, draw_color, .rgba);
    } else {
        ctx_draw.drawTexture(ctx_draw.ctx, font.coverage_texture, glyph.rect, dest, draw_color, .font_coverage);
    }
}

pub fn drawRowGlyphs(
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
        hb.hb_buffer_set_content_type(buffer, hb.HB_BUFFER_CONTENT_TYPE_UNICODE);
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
                while (j < @as(usize, @intCast(ccell.combining_len)) and j < ccell.combining.len) : (j += 1) hb.hb_buffer_add(buffer, ccell.combining[j], cluster);
            }
            cc += cwidth_units;
        }
        hb.hb_buffer_guess_segment_properties(buffer);
        hb.hb_shape(span_hb_font, buffer, if (shape_features_len > 0) shape_features_buf[0..].ptr else null, @intCast(shape_features_len));

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
            if (ccell.attrs.link_id != 0) underline = ccell.attrs.link_id == hover_link;
            if (ccell.attrs.blink and blink_style_mode != BlinkStyleT.off) {
                const period: f64 = if (ccell.attrs.blink_fast) 0.5 else 1.0;
                const phase = @mod(blink_time_s, period * 2.0);
                if (phase >= period) {
                    cc += cwidth_units;
                    continue;
                }
            }
            if (underline and ccell.codepoint != 0) {
                terminal_underline.drawUnderline(addTerminalGlyphRect, rr, cell_x_i, cell_y_i, cell_w_i * @as(i32, @intCast(cwidth_units)), cell_h_i, underline_color);
            }
            cc += cwidth_units;
        }

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
                    const period: f64 = if (cell.attrs.blink_fast) 0.5 else 1.0;
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
                if (cell.combining_len > 0) {
                    rr.drawTerminalCellGraphemeBatched(cell.codepoint, cell.combining[0..@intCast(cell.combining_len)], @as(f32, @floatFromInt(cell_x_i)), @as(f32, @floatFromInt(cell_y_i)), @as(f32, @floatFromInt(cell_w_i * @as(i32, @intCast(cell_width_units)))), @as(f32, @floatFromInt(cell_h_i)), if (cell_reverse) bg else fg, if (cell_reverse) fg else bg, underline_color, cell.attrs.bold, false, false, followed_by_space, false);
                } else {
                    rr.drawTerminalCellBatched(cell.codepoint, @as(f32, @floatFromInt(cell_x_i)), @as(f32, @floatFromInt(cell_y_i)), @as(f32, @floatFromInt(cell_w_i * @as(i32, @intCast(cell_width_units)))), @as(f32, @floatFromInt(cell_h_i)), if (cell_reverse) bg else fg, if (cell_reverse) fg else bg, underline_color, cell.attrs.bold, false, false, followed_by_space, false);
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
                const period: f64 = if (cell.attrs.blink_fast) 0.5 else 1.0;
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

            if (cell.codepoint == 0 or cell.codepoint == kitty_unicode_placeholder) continue;
            if (cell.combining_len == 0) {
                const box_x_i = base_x_i + @as(i32, @intCast(abs_col)) * cell_w_i;
                const box_y_i = base_y_i + @as(i32, @intCast(row_idx)) * cell_h_i;
                const box_w_i = cell_w_i * @as(i32, @intCast(width_units));
                const box_h_i = cell_h_i;
                if (terminal_glyphs.specialVariantForCodepoint(cell.codepoint)) |variant| {
                    if (variant != .box) {
                        const x0 = snapToDevicePixel(@as(f32, @floatFromInt(box_x_i)), render_scale);
                        const x1 = snapToDevicePixel(@as(f32, @floatFromInt(box_x_i + box_w_i)), render_scale);
                        const y0_unsnapped = @as(f32, @floatFromInt(box_y_i));
                        const y1_unsnapped = @as(f32, @floatFromInt(box_y_i + box_h_i));
                        const use_y_snap = variant == .box or variant == .braille;
                        const y0 = if (use_y_snap) snapToDevicePixel(y0_unsnapped, render_scale) else y0_unsnapped;
                        const y1 = if (use_y_snap) snapToDevicePixel(y1_unsnapped, render_scale) else y1_unsnapped;
                        const snapped_w = @max(1.0 / render_scale, x1 - x0);
                        const snapped_h = @max(1.0 / render_scale, y1 - y0);
                        const raster_w_i: i32 = @max(1, @as(i32, @intFromFloat(std.math.round(snapped_w * render_scale))));
                        const raster_h_i: i32 = @max(1, @as(i32, @intFromFloat(std.math.round(snapped_h * render_scale))));
                        const sprite_key = rr.terminal_font.specialGlyphSpriteKey(cell.codepoint, raster_w_i, raster_h_i, variant);
                        const sprite = rr.terminal_font.getSpecialGlyphSprite(sprite_key) orelse rr.terminal_font.getOrCreateSpecialGlyphSprite(cell.codepoint, box_w_i, box_h_i, raster_w_i, raster_h_i, variant);
                        if (sprite) |sp| {
                            var dest_x = x0;
                            var dest_w = snapped_w;
                            const seam_overdraw = 1.0 / render_scale;
                            if (cell.codepoint == 0xE0B2 or cell.codepoint == 0xE0B6) {
                                const next_col = abs_col + width_units;
                                if (next_col < row_cells.len) {
                                    const next_cell = row_cells[next_col];
                                    const next_reverse = next_cell.attrs.reverse != screen_reverse_mode;
                                    const next_bg = if (next_reverse) next_cell.attrs.fg else next_cell.attrs.bg;
                                    if (next_bg.r == fg_draw.r and next_bg.g == fg_draw.g and next_bg.b == fg_draw.b) dest_w += seam_overdraw;
                                }
                            } else if (cell.codepoint == 0xE0B0 or cell.codepoint == 0xE0B4) {
                                if (abs_col > 0) {
                                    const prev_cell = row_cells[abs_col - 1];
                                    const prev_reverse = prev_cell.attrs.reverse != screen_reverse_mode;
                                    const prev_bg = if (prev_reverse) prev_cell.attrs.fg else prev_cell.attrs.bg;
                                    if (prev_bg.r == fg_draw.r and prev_bg.g == fg_draw.g and prev_bg.b == fg_draw.b) {
                                        dest_x -= seam_overdraw;
                                        dest_w += seam_overdraw;
                                    }
                                }
                            }
                            rr.terminal_glyph_cache.addQuad(rr.terminal_font.coverage_texture, sp.rect, .{ .x = dest_x, .y = y0, .width = dest_w, .height = snapped_h }, fg_draw.toRgba(), rr.text_bg_rgba, .font_coverage);
                            continue;
                        }
                        if (variant == .powerline) {
                            const special_log = app_logger.logger("terminal.glyph.special");
                            special_log.logf(.info, "sprite_missing cp=U+{X} variant={s} cell={d}x{d}", .{ cell.codepoint, @tagName(variant), box_w_i, box_h_i });
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
                _ = terminal_glyphs.drawBoxGlyphBatched(addTerminalGlyphRect, rr, cell.codepoint, @as(f32, @floatFromInt(box_x_i)), @as(f32, @floatFromInt(box_y_i)), @as(f32, @floatFromInt(box_w_i)), @as(f32, @floatFromInt(box_h_i)), fg_draw);
                continue;
            }

            drawShapedGlyph(&rr.terminal_font, draw_ctx, span_choice.face, span_choice.want_color, cell.codepoint, infos[i].codepoint, positions[i], pen_rel, cell_x, cell_y, cell_w, cell_h, followed_by_space, fg_draw.toRgba());
        }

        col = span_end_excl;
    }
}
