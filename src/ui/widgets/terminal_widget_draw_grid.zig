const std = @import("std");
const app_shell = @import("../../app_shell.zig");
const app_logger = @import("../../app_logger.zig");
const terminal_publication = @import("../../terminal/core/publication/terminal_publication.zig");
const shared_types = @import("../../types/mod.zig");
const renderer_mod = @import("../renderer.zig");
const renderer_terminal_draw_host = @import("../renderer/renderer_terminal_draw_host.zig");
const terminal_font_mod = @import("../terminal_font.zig");
const terminal_glyphs = @import("../renderer/terminal_glyphs.zig");
const terminal_underline = @import("../renderer/terminal_underline.zig");
const debug_geometry_mod = @import("terminal_widget_debug_geometry.zig");
const metal_backend = @import("../renderer/metal_backend.zig");

const Shell = app_shell.Shell;
const Color = app_shell.Color;
const CursorPos = terminal_publication.CursorPos;
const Cell = terminal_publication.Cell;
const TerminalFont = terminal_font_mod.TerminalFont;
const hb = terminal_font_mod.c;
const DrawContext = terminal_font_mod.DrawContext;
const Renderer = renderer_mod.Renderer;
const TerminalGlyphPrepEntry = renderer_mod.TerminalGlyphPrepEntry;
const TerminalDisableLigaturesStrategy = renderer_mod.TerminalDisableLigaturesStrategy;
const Rgba = terminal_font_mod.Rgba;
const TextPaintSample = debug_geometry_mod.TextPaintSample;
const TextPaintSource = debug_geometry_mod.TextPaintSource;
const MetalTerminalFallbackSample = debug_geometry_mod.MetalTerminalFallbackSample;

const kitty_unicode_placeholder: u32 = 0x10EEEE;
const TerminalGlyphPrepSet = std.AutoArrayHashMapUnmanaged(TerminalGlyphPrepEntry, void);

pub const BackgroundRunSummary = struct {
    pub const RunSample = struct {
        present: bool = false,
        col: usize = 0,
        codepoint: u32 = 0,
        fg: Color = Color.black,
        bg: Color = Color.black,
        reverse: bool = false,
        resolved_bg: Color = Color.black,
    };

    runs: usize = 0,
    first_start: usize = 0,
    first_end: usize = 0,
    first_color: Color = Color.black,
    first_sample: RunSample = .{},
    second_start: usize = 0,
    second_end: usize = 0,
    second_color: Color = Color.black,
    second_sample: RunSample = .{},
    third_start: usize = 0,
    third_end: usize = 0,
    third_color: Color = Color.black,
    third_sample: RunSample = .{},
};

pub const GlyphDrawStats = struct {
    shaping_spans: usize = 0,
    shaped_glyphs: usize = 0,
    direct_text_glyphs: usize = 0,
    fallback_cells: usize = 0,
    special_sprite_glyphs: usize = 0,
    box_glyphs: usize = 0,
    powerline_special_glyphs: usize = 0,
    shade_special_glyphs: usize = 0,
    braille_special_glyphs: usize = 0,
    shaped_text_glyphs: usize = 0,
    shaped_special_glyphs: usize = 0,
    shaped_space_skips: usize = 0,
    shape_ms: f64 = 0.0,
    submit_ms: f64 = 0.0,
    shaped_text_submit_ms: f64 = 0.0,
    shaped_special_submit_ms: f64 = 0.0,
    special_sprite_submit_ms: f64 = 0.0,
    box_submit_ms: f64 = 0.0,
    box_sprite_submit_ms: f64 = 0.0,
    box_rect_submit_ms: f64 = 0.0,
    special_sprite_lookup_ms: f64 = 0.0,
    special_sprite_cache_hits: usize = 0,
    special_sprite_cache_misses: usize = 0,
    special_sprite_creates: usize = 0,
    direct_lookup_ms: f64 = 0.0,
    direct_draw_ms: f64 = 0.0,
};

const RowSpecialSpriteCache = struct {
    key: ?terminal_font_mod.SpecialGlyphSpriteKey = null,
    sprite: ?terminal_font_mod.SpecialGlyphSprite = null,
};

fn terminalOpaqueColor(color: Color) Color {
    return .{ .r = color.r, .g = color.g, .b = color.b, .a = 255 };
}

fn snapInt(value: f32) i32 {
    return @intFromFloat(std.math.round(value));
}

fn shouldSnapSpecialGlyphHorizontalEdges(render_scale: f32, variant: terminal_font_mod.SpecialGlyphVariant) bool {
    const scale = if (render_scale > 0.0) render_scale else 1.0;
    if (variant != .shade) return true;
    return std.math.approxEqAbs(f32, scale, std.math.round(scale), 0.0001);
}

fn shouldCaptureTextPaint(sample: ?*TextPaintSample, row_idx: usize, cursor_pos: CursorPos, abs_col: usize, width_units: usize) bool {
    return bestTextPaintCapture(sample, row_idx, cursor_pos, abs_col, width_units);
}

fn bestTextPaintCapture(sample: ?*TextPaintSample, row_idx: usize, cursor_pos: CursorPos, abs_col: usize, width_units: usize) bool {
    const s = sample orelse return false;
    if (row_idx != cursor_pos.row) return false;
    const covers_cursor = abs_col <= cursor_pos.col and cursor_pos.col < abs_col + width_units;
    const candidate_distance = if (covers_cursor)
        @as(usize, 0)
    else if (abs_col + width_units <= cursor_pos.col)
        cursor_pos.col - (abs_col + width_units)
    else
        abs_col - cursor_pos.col;
    if (!s.valid) return true;
    if (covers_cursor and !s.covers_cursor) return true;
    if (!covers_cursor and s.covers_cursor) return false;
    return candidate_distance < s.cursor_distance_cols;
}

fn captureTextPaintSample(
    sample: *TextPaintSample,
    publication_generation: u64,
    row_idx: usize,
    cursor_col: usize,
    abs_col: usize,
    cell: Cell,
    width_units: usize,
    cell_x: f32,
    cell_y: f32,
    cell_w: f32,
    cell_h: f32,
    baseline: f32,
    render_scale: f32,
    glyph: terminal_font_mod.Rect,
    source: TextPaintSource,
) void {
    const covers_cursor = abs_col <= cursor_col and cursor_col < abs_col + width_units;
    const cursor_distance_cols = if (covers_cursor)
        @as(usize, 0)
    else if (abs_col + width_units <= cursor_col)
        cursor_col - (abs_col + width_units)
    else
        abs_col - cursor_col;
    sample.* = .{
        .valid = true,
        .generation = publication_generation,
        .row = row_idx,
        .col = abs_col,
        .covers_cursor = covers_cursor,
        .cursor_distance_cols = cursor_distance_cols,
        .codepoint = cell.codepoint,
        .width_units = width_units,
        .cell_x = cell_x,
        .cell_y = cell_y,
        .cell_w = cell_w,
        .cell_h = cell_h,
        .baseline = baseline,
        .render_scale = render_scale,
        .glyph = glyph,
        .source = source,
    };
}

fn rowSlice(cells: []const Cell, cols_count: usize, row: usize) []const Cell {
    const row_start = row * cols_count;
    if (row_start + cols_count > cells.len) return cells[0..0];
    return cells[row_start .. row_start + cols_count];
}

fn resolvedBackgroundColor(cell: Cell, screen_reverse_mode: bool) Color {
    const fg = terminalOpaqueColor(.{ .r = cell.attrs.fg.r, .g = cell.attrs.fg.g, .b = cell.attrs.fg.b, .a = cell.attrs.fg.a });
    const bg = terminalOpaqueColor(.{ .r = cell.attrs.bg.r, .g = cell.attrs.bg.g, .b = cell.attrs.bg.b, .a = cell.attrs.bg.a });
    const cell_reverse = cell.attrs.reverse != screen_reverse_mode;
    return if (cell_reverse) fg else bg;
}

const TerminalCellColors = struct {
    fg: Color,
    bg: Color,
};

const ResolvedTerminalCellStyle = struct {
    width_units: usize,
    fg: Color,
    bg: Color,
    underline_color: Color,
    underline: bool,
    bold: bool,
    block_cursor_here: bool,
    glyph_visible: bool,
};

fn cellWidthUnits(cell: Cell) usize {
    return @as(usize, @max(@as(u8, 1), cell.width));
}

fn blockCursorCoversCell(
    draw_cursor_mode: bool,
    cursor_style: anytype,
    row_idx: usize,
    cursor_pos: CursorPos,
    abs_col: usize,
    width_units: usize,
) bool {
    return draw_cursor_mode and
        cursor_style.shape == .block and
        row_idx == cursor_pos.row and
        abs_col <= cursor_pos.col and
        cursor_pos.col < abs_col + width_units;
}

fn resolvedTerminalCellColors(
    cell: Cell,
    screen_reverse_mode: bool,
    block_cursor_here: bool,
) TerminalCellColors {
    const fg = terminalOpaqueColor(.{ .r = cell.attrs.fg.r, .g = cell.attrs.fg.g, .b = cell.attrs.fg.b, .a = cell.attrs.fg.a });
    const bg = terminalOpaqueColor(.{ .r = cell.attrs.bg.r, .g = cell.attrs.bg.g, .b = cell.attrs.bg.b, .a = cell.attrs.bg.a });
    const cell_reverse = cell.attrs.reverse != screen_reverse_mode;
    const normal_fg = if (cell_reverse) bg else fg;
    const normal_bg = if (cell_reverse) fg else bg;
    return if (block_cursor_here)
        .{ .fg = normal_bg, .bg = normal_fg }
    else
        .{ .fg = normal_fg, .bg = normal_bg };
}

fn terminalCellUnderlineColor(cell: Cell) Color {
    return .{
        .r = cell.attrs.underline_color.r,
        .g = cell.attrs.underline_color.g,
        .b = cell.attrs.underline_color.b,
        .a = cell.attrs.underline_color.a,
    };
}

fn terminalCellUnderlineEnabled(cell: Cell, hover_link: u32) bool {
    var underline = cell.attrs.underline;
    if (cell.attrs.link_id != 0) underline = cell.attrs.link_id == hover_link;
    return underline;
}

fn colorEql(lhs: Color, rhs: Color) bool {
    return lhs.r == rhs.r and lhs.g == rhs.g and lhs.b == rhs.b and lhs.a == rhs.a;
}

fn terminalCellGlyphVisible(cell: Cell, blink_style_mode: anytype, blink_time_s: f64) bool {
    const BlinkStyleT = @TypeOf(blink_style_mode);
    if (!cell.attrs.blink or blink_style_mode == BlinkStyleT.off) return true;
    const period: f64 = if (cell.attrs.blink_fast) 0.5 else 1.0;
    const phase = @mod(blink_time_s, period * 2.0);
    return phase < period;
}

fn resolveCellStyle(
    cell: Cell,
    screen_reverse_mode: bool,
    hover_link: u32,
    blink_style_mode: anytype,
    blink_time_s: f64,
    draw_cursor_mode: bool,
    cursor_pos: CursorPos,
    cursor_style: anytype,
    row_idx: usize,
    abs_col: usize,
) ResolvedTerminalCellStyle {
    const width_units = cellWidthUnits(cell);
    const block_cursor_here = blockCursorCoversCell(draw_cursor_mode, cursor_style, row_idx, cursor_pos, abs_col, width_units);
    const colors = resolvedTerminalCellColors(cell, screen_reverse_mode, block_cursor_here);
    return .{
        .width_units = width_units,
        .fg = colors.fg,
        .bg = colors.bg,
        .underline_color = terminalCellUnderlineColor(cell),
        .underline = terminalCellUnderlineEnabled(cell, hover_link),
        .bold = cell.attrs.bold,
        .block_cursor_here = block_cursor_here,
        .glyph_visible = terminalCellGlyphVisible(cell, blink_style_mode, blink_time_s),
    };
}

fn resolvedDrawBackgroundColor(
    cell: Cell,
    screen_reverse_mode: bool,
    row_idx: usize,
    abs_col: usize,
    draw_cursor_mode: bool,
    cursor_pos: CursorPos,
    cursor_style: anytype,
) Color {
    return resolvedTerminalCellColors(
        cell,
        screen_reverse_mode,
        blockCursorCoversCell(draw_cursor_mode, cursor_style, row_idx, cursor_pos, abs_col, cellWidthUnits(cell)),
    ).bg;
}

fn terminalCellFollowedBySpace(row_cells: []const Cell, cols_count: usize, abs_col: usize, width_units: usize) bool {
    const next_col = abs_col + width_units;
    if (next_col < cols_count) {
        const next_cell = row_cells[next_col];
        return next_cell.codepoint == ' ' or next_cell.codepoint == 0;
    }
    return true;
}

fn sameColor(a: Color, b: Color) bool {
    return a.r == b.r and a.g == b.g and a.b == b.b and a.a == b.a;
}

fn makeRunSample(cell: Cell, col: usize, screen_reverse_mode: bool) BackgroundRunSummary.RunSample {
    return .{
        .present = true,
        .col = col,
        .codepoint = cell.codepoint,
        .fg = .{ .r = cell.attrs.fg.r, .g = cell.attrs.fg.g, .b = cell.attrs.fg.b, .a = cell.attrs.fg.a },
        .bg = .{ .r = cell.attrs.bg.r, .g = cell.attrs.bg.g, .b = cell.attrs.bg.b, .a = cell.attrs.bg.a },
        .reverse = cell.attrs.reverse != screen_reverse_mode,
        .resolved_bg = resolvedBackgroundColor(cell, screen_reverse_mode),
    };
}

fn backgroundRunEnd(
    row_cells: []const Cell,
    cols_count: usize,
    run_start: usize,
    col_end: usize,
    screen_reverse_mode: bool,
    run_color: Color,
) usize {
    const start_cell = row_cells[run_start];
    var col = run_start + @as(usize, @max(@as(u8, 1), start_cell.width));
    while (col <= col_end and col < cols_count) {
        const cell = row_cells[col];
        if (cell.x != 0 or cell.y != 0) {
            col += 1;
            continue;
        }
        if (!sameColor(resolvedBackgroundColor(cell, screen_reverse_mode), run_color)) break;
        col += @as(usize, @max(@as(u8, 1), cell.width));
    }
    return @min(cols_count, col);
}

fn backgroundRunEndForDraw(
    row_cells: []const Cell,
    cols_count: usize,
    run_start: usize,
    col_end: usize,
    screen_reverse_mode: bool,
    run_color: Color,
    row_idx: usize,
    draw_cursor_mode: bool,
    cursor_pos: CursorPos,
    cursor_style: anytype,
) usize {
    const start_cell = row_cells[run_start];
    const start_width_units = @as(usize, @max(@as(u8, 1), start_cell.width));
    if (blockCursorCoversCell(draw_cursor_mode, cursor_style, row_idx, cursor_pos, run_start, start_width_units)) {
        return @min(cols_count, run_start + start_width_units);
    }

    var col = run_start + start_width_units;
    while (col <= col_end and col < cols_count) {
        const cell = row_cells[col];
        if (cell.x != 0 or cell.y != 0) {
            col += 1;
            continue;
        }
        const width_units = @as(usize, @max(@as(u8, 1), cell.width));
        if (blockCursorCoversCell(draw_cursor_mode, cursor_style, row_idx, cursor_pos, col, width_units)) break;
        if (!sameColor(resolvedBackgroundColor(cell, screen_reverse_mode), run_color)) break;
        col += width_units;
    }
    return @min(cols_count, col);
}

pub fn drawRowBackgrounds(
    renderer: *Shell,
    view: shared_types.layout.TerminalViewGeometry,
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
    draw_cursor_mode: bool,
    cursor_pos: CursorPos,
    cursor_style: anytype,
) void {
    const rr = renderer.rendererPtr();
    const cell_w = view.cell_width;
    const cell_h = view.cell_height;
    const padding_x = @as(f32, @floatFromInt(padding_x_i)) * rr.devicePixelStep();

    const row_cells = rowSlice(snapshot_cells, cols_count, row_idx);
    if (row_cells.len != cols_count) return;
    const col_start = @min(col_start_in, cols_count - 1);
    const col_end = @min(col_end_in, cols_count - 1);
    if (col_start > col_end) return;

    var col: usize = col_start;
    while (col <= col_end and col < cols_count) : (col += 1) {
        const cell = row_cells[col];
        if (cell.x != 0 or cell.y != 0) continue;
        const cell_x = base_x_local + @as(f32, @floatFromInt(@as(i32, @intCast(col)))) * cell_w;
        const cell_y = base_y_local + @as(f32, @floatFromInt(@as(i32, @intCast(row_idx)))) * cell_h;
        const width_units = @as(usize, @max(@as(u8, 1), cell.width));
        const colors = resolvedTerminalCellColors(
            cell,
            screen_reverse_mode,
            blockCursorCoversCell(draw_cursor_mode, cursor_style, row_idx, cursor_pos, col, width_units),
        );
        const run_color = colors.bg;
        const run_end = backgroundRunEndForDraw(
            row_cells,
            cols_count,
            col,
            col_end,
            screen_reverse_mode,
            run_color,
            row_idx,
            draw_cursor_mode,
            cursor_pos,
            cursor_style,
        );
        const run_width_cols = run_end - col;
        const rect_x0 = rr.snapLogicalToDevicePixel(cell_x);
        const rect_y0 = rr.snapLogicalToDevicePixel(cell_y);
        const rect_x1 = rr.snapLogicalToDevicePixel(cell_x + cell_w * @as(f32, @floatFromInt(@as(i32, @intCast(run_width_cols)))));
        const rect_y1 = rr.snapLogicalToDevicePixel(cell_y + cell_h);
        renderer_terminal_draw_host.addTerminalRect(rr, snapInt(rect_x0), snapInt(rect_y0), @max(1, snapInt(rect_x1 - rect_x0)), @max(1, snapInt(rect_y1 - rect_y0)), run_color);
        col = run_end - 1;
    }

    if (draw_padding and padding_x_i > 0 and cols_count > 0) {
        const last_cell = row_cells[cols_count - 1];
        const pad_x0 = rr.snapLogicalToDevicePixel(base_x_local + @as(f32, @floatFromInt(@as(i32, @intCast(cols_count)))) * cell_w);
        const pad_y0 = rr.snapLogicalToDevicePixel(base_y_local + @as(f32, @floatFromInt(@as(i32, @intCast(row_idx)))) * cell_h);
        const pad_x1 = rr.snapLogicalToDevicePixel(base_x_local + @as(f32, @floatFromInt(@as(i32, @intCast(cols_count)))) * cell_w + padding_x);
        const pad_y1 = rr.snapLogicalToDevicePixel(base_y_local + @as(f32, @floatFromInt(@as(i32, @intCast(row_idx)))) * cell_h + cell_h);
        renderer_terminal_draw_host.addTerminalRect(rr, snapInt(pad_x0), snapInt(pad_y0), @max(1, snapInt(pad_x1 - pad_x0)), @max(1, snapInt(pad_y1 - pad_y0)), resolvedBackgroundColor(last_cell, screen_reverse_mode));
    }
}

pub fn countRowBackgroundRuns(
    snapshot_cells: []const Cell,
    cols_count: usize,
    row_idx: usize,
    col_start_in: usize,
    col_end_in: usize,
    draw_padding: bool,
    screen_reverse_mode: bool,
) usize {
    const row_cells = rowSlice(snapshot_cells, cols_count, row_idx);
    if (row_cells.len != cols_count) return 0;
    const col_start = @min(col_start_in, cols_count - 1);
    const col_end = @min(col_end_in, cols_count - 1);
    if (col_start > col_end) return 0;

    var run_count: usize = 0;
    var col: usize = col_start;
    while (col <= col_end and col < cols_count) : (col += 1) {
        const cell = row_cells[col];
        if (cell.x != 0 or cell.y != 0) continue;
        const run_color = resolvedBackgroundColor(cell, screen_reverse_mode);
        const run_end = backgroundRunEnd(row_cells, cols_count, col, col_end, screen_reverse_mode, run_color);
        run_count += 1;
        col = run_end - 1;
    }

    if (draw_padding and cols_count > 0) run_count += 1;
    return run_count;
}

pub fn summarizeRowBackgroundRuns(
    snapshot_cells: []const Cell,
    cols_count: usize,
    row_idx: usize,
    col_start_in: usize,
    col_end_in: usize,
    draw_padding: bool,
    screen_reverse_mode: bool,
) BackgroundRunSummary {
    var summary = BackgroundRunSummary{};
    const row_cells = rowSlice(snapshot_cells, cols_count, row_idx);
    if (row_cells.len != cols_count) return summary;
    const col_start = @min(col_start_in, cols_count - 1);
    const col_end = @min(col_end_in, cols_count - 1);
    if (col_start > col_end) return summary;

    var col: usize = col_start;
    while (col <= col_end and col < cols_count) : (col += 1) {
        const cell = row_cells[col];
        if (cell.x != 0 or cell.y != 0) continue;
        const run_color = resolvedBackgroundColor(cell, screen_reverse_mode);
        const run_end_excl = backgroundRunEnd(row_cells, cols_count, col, col_end, screen_reverse_mode, run_color);
        const run_end = run_end_excl - 1;
        switch (summary.runs) {
            0 => {
                summary.first_start = col;
                summary.first_end = run_end;
                summary.first_color = run_color;
                summary.first_sample = makeRunSample(cell, col, screen_reverse_mode);
            },
            1 => {
                summary.second_start = col;
                summary.second_end = run_end;
                summary.second_color = run_color;
                summary.second_sample = makeRunSample(cell, col, screen_reverse_mode);
            },
            2 => {
                summary.third_start = col;
                summary.third_end = run_end;
                summary.third_color = run_color;
                summary.third_sample = makeRunSample(cell, col, screen_reverse_mode);
            },
            else => {},
        }
        summary.runs += 1;
        col = run_end;
    }

    if (draw_padding and cols_count > 0) summary.runs += 1;
    return summary;
}

test "backgroundRunEnd coalesces adjacent cells with same resolved background" {
    const base_bg = Color{ .r = 1, .g = 2, .b = 3, .a = 255 };
    const other_bg = Color{ .r = 9, .g = 8, .b = 7, .a = 255 };
    const fg = Color{ .r = 200, .g = 201, .b = 202, .a = 255 };
    const cells = [_]Cell{
        cellWithColors('a', fg, base_bg, false),
        cellWithColors('b', fg, base_bg, false),
        cellWithColors('c', fg, other_bg, false),
    };
    try std.testing.expectEqual(@as(usize, 2), backgroundRunEnd(&cells, cells.len, 0, cells.len - 1, false, base_bg));
}

test "backgroundRunEnd respects reverse-resolved background color" {
    const fg = Color{ .r = 100, .g = 101, .b = 102, .a = 255 };
    const bg = Color{ .r = 1, .g = 2, .b = 3, .a = 255 };
    const cells = [_]Cell{
        cellWithColors('a', fg, bg, true),
        cellWithColors('b', fg, bg, true),
        cellWithColors('c', fg, bg, false),
    };
    try std.testing.expectEqual(@as(usize, 2), backgroundRunEnd(&cells, cells.len, 0, cells.len - 1, false, fg));
}

test "resolveCellStyle applies block cursor colors and hover underline" {
    const fg = Color{ .r = 200, .g = 201, .b = 202, .a = 255 };
    const bg = Color{ .r = 10, .g = 11, .b = 12, .a = 255 };
    const underline_color = Color{ .r = 50, .g = 51, .b = 52, .a = 255 };
    var cell = cellWithColors('x', fg, bg, false);
    cell.attrs.link_id = 7;
    cell.attrs.underline_color = .{ .r = underline_color.r, .g = underline_color.g, .b = underline_color.b, .a = underline_color.a };
    const cursor_style = struct {
        shape: enum { block, underline, bar } = .block,
    }{};
    const blink_style = enum { off, on }.off;
    const style = resolveCellStyle(
        cell,
        false,
        7,
        blink_style,
        0.0,
        true,
        .{ .row = 3, .col = 4 },
        cursor_style,
        3,
        4,
    );
    try std.testing.expectEqual(@as(usize, 1), style.width_units);
    try std.testing.expect(style.block_cursor_here);
    try std.testing.expect(style.glyph_visible);
    try std.testing.expect(style.underline);
    try std.testing.expectEqual(bg, style.fg);
    try std.testing.expectEqual(fg, style.bg);
    try std.testing.expectEqual(underline_color, style.underline_color);
}

test "resolveCellStyle hides blinked glyphs" {
    var cell = cellWithColors('x', Color.white, Color.black, false);
    cell.attrs.blink = true;
    const cursor_style = struct {
        shape: enum { block, underline, bar } = .bar,
    }{};
    const blink_style = enum { off, on }.on;
    const style = resolveCellStyle(
        cell,
        false,
        0,
        blink_style,
        1.25,
        false,
        .{ .row = 0, .col = 0 },
        cursor_style,
        0,
        0,
    );
    try std.testing.expect(!style.glyph_visible);
}

test "cellCanDirectSpecial routes representative terminal special glyphs" {
    const fg = Color.white;
    const bg = Color.black;
    try std.testing.expect(cellCanDirectSpecial(cellWithColors(0x2500, fg, bg, false)));
    try std.testing.expect(cellCanDirectSpecial(cellWithColors(0x2591, fg, bg, false)));
    try std.testing.expect(cellCanDirectSpecial(cellWithColors(0x2801, fg, bg, false)));
    try std.testing.expect(cellCanDirectSpecial(cellWithColors(0xE0B0, fg, bg, false)));
}

test "spanCanBypassShaping rejects representative terminal special glyphs" {
    const fg = Color.white;
    const bg = Color.black;
    const cells = [_]Cell{
        cellWithColors(0x2500, fg, bg, false),
        cellWithColors(0x2591, fg, bg, false),
        cellWithColors(0x2801, fg, bg, false),
        cellWithColors(0xE0B0, fg, bg, false),
    };
    try std.testing.expect(!spanCanBypassShaping(&cells, 0, cells.len));
}

fn cellWithColors(codepoint: u32, fg: Color, bg: Color, reverse: bool) Cell {
    var cell = std.mem.zeroes(Cell);
    cell.codepoint = codepoint;
    cell.width = 1;
    cell.attrs.fg = .{ .r = fg.r, .g = fg.g, .b = fg.b, .a = fg.a };
    cell.attrs.bg = .{ .r = bg.r, .g = bg.g, .b = bg.b, .a = bg.a };
    cell.attrs.reverse = reverse;
    return cell;
}

fn drawTextureGlyphCache(ctx: *anyopaque, texture: terminal_font_mod.Texture, src: terminal_font_mod.Rect, dest: terminal_font_mod.Rect, color: terminal_font_mod.Rgba, kind: terminal_font_mod.TextureKind) void {
    const draw_ctx: *TerminalGlyphDrawContext = @ptrCast(@alignCast(ctx));
    renderer_terminal_draw_host.addTerminalGlyphQuad(draw_ctx.renderer, texture, src, dest, color, draw_ctx.bg_rgba, kind);
}

fn addTerminalGlyphRect(ctx: *anyopaque, x: i32, y: i32, w: i32, h: i32, color: Color) void {
    const rr: *Renderer = @ptrCast(@alignCast(ctx));
    renderer_terminal_draw_host.addTerminalGlyphRect(rr, x, y, w, h, color);
}

const TerminalGlyphDrawContext = struct {
    renderer: *Renderer,
    bg_rgba: Rgba,
};

fn isTerminalBoxGlyph(codepoint: u32) bool {
    return terminal_glyphs.hasAnalyticBoxGlyphCoverage(codepoint);
}

fn spanCanBypassShaping(
    row_cells: []const Cell,
    span_start_col: usize,
    span_end_excl: usize,
) bool {
    var col = span_start_col;
    while (col < span_end_excl and col < row_cells.len) {
        const cell = row_cells[col];
        if (cell.x != 0 or cell.y != 0) {
            col += 1;
            continue;
        }
        if (cell.width != 1) return false;
        if (cell.combining_len != 0) return false;
        if (cell.codepoint == kitty_unicode_placeholder) return false;
        if (isTerminalBoxGlyph(cell.codepoint)) return false;
        if (terminal_glyphs.specialVariantForCodepoint(cell.codepoint) != null) return false;
        col += 1;
    }
    return true;
}

fn cellCanBypassShaping(cell: Cell) bool {
    if (cell.x != 0 or cell.y != 0) return true;
    if (cell.width != 1) return false;
    if (cell.combining_len != 0) return false;
    if (cell.codepoint == kitty_unicode_placeholder) return false;
    if (isTerminalBoxGlyph(cell.codepoint)) return false;
    if (terminal_glyphs.specialVariantForCodepoint(cell.codepoint) != null) return false;
    return true;
}

fn cellCanDirectSpecial(cell: Cell) bool {
    if (cell.x != 0 or cell.y != 0) return true;
    if (cell.width != 1) return false;
    if (cell.combining_len != 0) return false;
    if (cell.codepoint == 0 or cell.codepoint == kitty_unicode_placeholder) return false;
    return terminal_glyphs.specialVariantForCodepoint(cell.codepoint) != null or isTerminalBoxGlyph(cell.codepoint);
}

fn appendUniqueTerminalGlyphPrepEntry(
    allocator: std.mem.Allocator,
    seen: *TerminalGlyphPrepSet,
    out: *std.ArrayListUnmanaged(TerminalGlyphPrepEntry),
    entry: TerminalGlyphPrepEntry,
) !void {
    const gop = try seen.getOrPut(allocator, entry);
    if (gop.found_existing) return;
    gop.value_ptr.* = {};
    errdefer _ = seen.orderedRemoveAt(gop.index);
    try out.append(allocator, entry);
}

fn collectVisibleTerminalGlyphPrepEntriesForRow(
    allocator: std.mem.Allocator,
    rr: *Renderer,
    snapshot_cells: []const Cell,
    cols_count: usize,
    row_idx: usize,
    col_start_in: usize,
    col_end_in: usize,
    hover_link: u32,
    screen_reverse_mode: bool,
    blink_style_mode: anytype,
    blink_time_s: f64,
    draw_cursor_mode: bool,
    cursor_pos: CursorPos,
    cursor_style: anytype,
    ligature_strategy: TerminalDisableLigaturesStrategy,
    seen: *TerminalGlyphPrepSet,
    out: *std.ArrayListUnmanaged(TerminalGlyphPrepEntry),
) !void {
    if (rr.textRenderingMode() == .unavailable and rr.plannedTextRenderingMode() == .metal_texture_atlas) return;
    const row_cells = rowSlice(snapshot_cells, cols_count, row_idx);
    if (row_cells.len != cols_count) return;
    const col_start = @min(col_start_in, cols_count - 1);
    const col_end = @min(col_end_in, cols_count - 1);
    if (col_start > col_end) return;

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

        const span_fast = rr.terminal_font.directFastGlyphForCodepoint(cell0.codepoint);
        const span_choice = if (span_fast != null) terminal_font_mod.TerminalFont.FontChoice{
            .slot = .primary,
            .face = rr.terminal_font.ft_face,
            .hb_font = rr.terminal_font.hb_font,
            .want_color = false,
        } else rr.terminal_font.pickFontForCodepoint(cell0.codepoint);
        const span_hb_font = span_choice.hb_font;
        const span_can_bypass = cellCanBypassShaping(cell0);
        const span_can_direct_special = cellCanDirectSpecial(cell0);
        const span_start_col = col;
        var scan_col: usize = col;
        if (span_fast != null and span_can_bypass and !span_can_direct_special) {
            while (scan_col <= col_end and scan_col < cols_count) {
                const ccell = row_cells[scan_col];
                if (ccell.x != 0 or ccell.y != 0) {
                    scan_col += 1;
                    continue;
                }
                const cwidth_units = @as(usize, @max(@as(u8, 1), ccell.width));
                if (rr.terminal_font.directFastGlyphForCodepoint(ccell.codepoint) == null) break;
                scan_col += cwidth_units;
            }
        } else {
            while (scan_col <= col_end and scan_col < cols_count) {
                const ccell = row_cells[scan_col];
                if (ccell.x != 0 or ccell.y != 0) {
                    scan_col += 1;
                    continue;
                }
                const cwidth_units = @as(usize, @max(@as(u8, 1), ccell.width));
                if (span_fast != null) {
                    if (rr.terminal_font.directFastGlyphForCodepoint(ccell.codepoint) == null) break;
                } else {
                    const choice = rr.terminal_font.pickFontForCodepoint(ccell.codepoint);
                    if (choice.hb_font != span_hb_font) break;
                }
                if (cellCanBypassShaping(ccell) != span_can_bypass) break;
                if (cellCanDirectSpecial(ccell) != span_can_direct_special) break;
                scan_col += cwidth_units;
            }
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

        if (shape_features_len == 0 and span_can_bypass and spanCanBypassShaping(row_cells, span_start_col, span_end_excl)) {
            var direct_col = span_start_col;
            while (direct_col < span_end_excl and direct_col < row_cells.len) : (direct_col += 1) {
                const cell = row_cells[direct_col];
                if (cell.x != 0 or cell.y != 0) continue;
                const style = resolveCellStyle(cell, screen_reverse_mode, hover_link, blink_style_mode, blink_time_s, draw_cursor_mode, cursor_pos, cursor_style, row_idx, direct_col);
                if (!style.glyph_visible) continue;
                if (cell.codepoint == 0 or cell.codepoint == ' ') continue;

                const choice = if (rr.terminal_font.directFastGlyphForCodepoint(cell.codepoint)) |fast|
                    fast
                else blk: {
                    const picked = rr.terminal_font.pickFontForCodepoint(cell.codepoint);
                    const glyph_id = hb.FT_Get_Char_Index(picked.face, if (cell.codepoint == 0) ' ' else cell.codepoint);
                    if (glyph_id == 0) continue;
                    break :blk terminal_font_mod.TerminalFont.DirectFastGlyph{
                        .slot = picked.slot,
                        .face = picked.face,
                        .want_color = picked.want_color,
                        .glyph_id = glyph_id,
                        .simple_ascii = false,
                    };
                };

                try appendUniqueTerminalGlyphPrepEntry(allocator, seen, out, .{
                    .face_slot = choice.slot,
                    .glyph_id = choice.glyph_id,
                    .want_color = choice.want_color,
                    .italic = false,
                    .hb_x_advance = 0,
                });
            }
            col = span_end_excl;
            continue;
        }

        if (shape_features_len == 0 and span_can_direct_special) {
            col = span_end_excl;
            continue;
        }

        const buffer = rr.terminalShapeBuffer();
        hb.hb_buffer_reset(buffer);
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
                while (j < @as(usize, @intCast(ccell.combining_len)) and j < ccell.combining.len) : (j += 1) {
                    hb.hb_buffer_add(buffer, ccell.combining[j], cluster);
                }
            }
            cc += cwidth_units;
        }
        hb.hb_buffer_guess_segment_properties(buffer);
        hb.hb_shape(span_hb_font, buffer, if (shape_features_len > 0) shape_features_buf[0..].ptr else null, @intCast(shape_features_len));

        var length: c_uint = 0;
        const infos = hb.hb_buffer_get_glyph_infos(buffer, &length);
        const positions = hb.hb_buffer_get_glyph_positions(buffer, &length);
        if (length == 0) {
            col = span_end_excl;
            continue;
        }

        const glyph_len: usize = @intCast(length);
        var i: usize = 0;
        while (i < glyph_len) : (i += 1) {
            const cluster_rel_u32: u32 = infos[i].cluster;
            if (cluster_rel_u32 >= span_cols) continue;
            const cluster_rel: usize = @intCast(cluster_rel_u32);
            const abs_col = span_start_col + cluster_rel;
            if (abs_col >= row_cells.len) continue;
            const cell = row_cells[abs_col];
            if (cell.x != 0 or cell.y != 0) continue;
            const style = resolveCellStyle(cell, screen_reverse_mode, hover_link, blink_style_mode, blink_time_s, draw_cursor_mode, cursor_pos, cursor_style, row_idx, abs_col);
            if (!style.glyph_visible) continue;
            if (cell.codepoint == 0 or cell.codepoint == kitty_unicode_placeholder) continue;
            if (cell.codepoint == ' ' and cell.combining_len == 0) continue;
            if (cell.combining_len == 0 and terminal_glyphs.specialVariantForCodepoint(cell.codepoint) != null) continue;

            try appendUniqueTerminalGlyphPrepEntry(allocator, seen, out, .{
                .face_slot = span_choice.slot,
                .glyph_id = infos[i].codepoint,
                .want_color = span_choice.want_color,
                .italic = false,
                .hb_x_advance = positions[i].x_advance,
            });
        }

        col = span_end_excl;
    }
}

pub fn collectVisibleTerminalGlyphPrepEntries(
    allocator: std.mem.Allocator,
    rr: *Renderer,
    snapshot_cells: []const Cell,
    rows_count: usize,
    cols_count: usize,
    hover_link: u32,
    screen_reverse_mode: bool,
    blink_style_mode: anytype,
    blink_time_s: f64,
    draw_cursor_mode: bool,
    cursor_pos: CursorPos,
    cursor_style: anytype,
    ligature_strategy: TerminalDisableLigaturesStrategy,
    out: *std.ArrayListUnmanaged(TerminalGlyphPrepEntry),
) !void {
    var seen: TerminalGlyphPrepSet = .{};
    defer seen.deinit(allocator);

    var row_idx: usize = 0;
    while (row_idx < rows_count) : (row_idx += 1) {
        try collectVisibleTerminalGlyphPrepEntriesForRow(
            allocator,
            rr,
            snapshot_cells,
            cols_count,
            row_idx,
            0,
            cols_count - 1,
            hover_link,
            screen_reverse_mode,
            blink_style_mode,
            blink_time_s,
            draw_cursor_mode,
            cursor_pos,
            cursor_style,
            ligature_strategy,
            &seen,
            out,
        );
    }
}

fn drawShapedGlyph(
    rr: *Renderer,
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
    baseline_from_top: f32,
    cell_width: f32,
    cell_height: f32,
    followed_by_space: bool,
    color: Rgba,
    capture_sample: ?*TextPaintSample,
    capture_generation: u64,
    capture_row: usize,
    capture_cursor_col: usize,
    capture_col: usize,
    capture_cell: Cell,
    capture_width_units: usize,
    capture_cell_x: f32,
    capture_cell_y: f32,
) void {
    const glyph = font.getGlyphById(face, glyph_id, want_color, false, hb_pos.x_advance) catch |err| {
        const log = app_logger.logger("terminal.draw");
        log.logf(.warning, "shaped glyph lookup failed cp=U+{X} glyph_id={d} err={s}", .{ base_codepoint, glyph_id, @errorName(err) });
        return;
    };
    const render_scale = 1.0 / rr.devicePixelStep();
    const inv_scale = rr.devicePixelStep();
    const baseline = y + baseline_from_top;
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
    _ = followed_by_space;
    const allow_width_overflow = is_symbol_glyph;
    const overflow_scale_x: f32 = 1.0;
    const scaled_w = glyph_w * overflow_scale_x;
    const scaled_h = glyph_h;
    const draw_x = if (allow_width_overflow) origin_x + bearing_x * overflow_scale_x else @max(x, origin_x + bearing_x * overflow_scale_x);
    const draw_y = (baseline - bearing_y) - gy_off;
    const axis_x = rr.quantizeLogicalHorizontalAxis(draw_x, scaled_w);
    const axis_y = rr.quantizeLogicalVerticalAxis(draw_y, scaled_h);
    const snapped_x = axis_x.origin;
    const snapped_y = axis_y.origin;

    const dest = if (is_powerline_thin) blk: {
        const cell_left = rr.snapLogicalToDevicePixel(x);
        const cell_right = rr.snapLogicalToDevicePixel(x + cell_width);
        break :blk terminal_font_mod.Rect{ .x = cell_left, .y = snapped_y, .width = @max(inv_scale, cell_right - cell_left), .height = axis_y.size };
    } else terminal_font_mod.Rect{ .x = snapped_x, .y = snapped_y, .width = axis_x.size, .height = axis_y.size };

    const draw_color = if (glyph.is_color) Rgba{ .r = 255, .g = 255, .b = 255, .a = 255 } else color;
    if (glyph.is_color) {
        ctx_draw.drawTexture(ctx_draw.ctx, font.colorTexture(), glyph.rect, dest, draw_color, .rgba);
    } else {
        ctx_draw.drawTexture(ctx_draw.ctx, font.coverageTexture(), glyph.rect, dest, draw_color, .font_coverage);
    }
    if (capture_sample) |sample| {
        captureTextPaintSample(
            sample,
            capture_generation,
            capture_row,
            capture_cursor_col,
            capture_col,
            capture_cell,
            capture_width_units,
            capture_cell_x,
            capture_cell_y,
            cell_width,
            cell_height,
            baseline,
            render_scale,
            dest,
            .shaped,
        );
    }
}

test "appendUniqueTerminalGlyphPrepEntry deduplicates identical entries" {
    var seen: TerminalGlyphPrepSet = .{};
    defer seen.deinit(std.testing.allocator);
    var entries: std.ArrayListUnmanaged(TerminalGlyphPrepEntry) = .{};
    defer entries.deinit(std.testing.allocator);

    const entry = TerminalGlyphPrepEntry{
        .face_slot = .primary,
        .glyph_id = 17,
        .want_color = false,
        .italic = false,
        .hb_x_advance = 64,
    };

    try appendUniqueTerminalGlyphPrepEntry(std.testing.allocator, &seen, &entries, entry);
    try appendUniqueTerminalGlyphPrepEntry(std.testing.allocator, &seen, &entries, entry);

    try std.testing.expectEqual(@as(usize, 1), entries.items.len);
    try std.testing.expectEqual(@as(usize, 1), seen.count());
}

fn drawDirectGlyphById(
    rr: *Renderer,
    font: *TerminalFont,
    ctx_draw: DrawContext,
    face: hb.FT_Face,
    want_color: bool,
    base_codepoint: u32,
    glyph_id: u32,
    simple_ascii: bool,
    baseline: f32,
    x: f32,
    cell_width: f32,
    cell_height: f32,
    followed_by_space: bool,
    color: Rgba,
    stats: ?*GlyphDrawStats,
    capture_sample: ?*TextPaintSample,
    capture_generation: u64,
    capture_row: usize,
    capture_cursor_col: usize,
    capture_col: usize,
    capture_cell: Cell,
    capture_width_units: usize,
    capture_cell_x: f32,
    capture_cell_y: f32,
) void {
    const glyph_lookup_start = app_shell.getTime();
    const glyph = font.getGlyphById(face, glyph_id, want_color, false, 0) catch |err| {
        const log = app_logger.logger("terminal.draw");
        log.logf(.warning, "direct glyph lookup failed cp=U+{X} glyph_id={d} err={s}", .{ base_codepoint, glyph_id, @errorName(err) });
        return;
    };
    if (stats) |s| s.direct_lookup_ms += (app_shell.getTime() - glyph_lookup_start) * 1000.0;

    const draw_submit_start = app_shell.getTime();
    const render_scale = 1.0 / rr.devicePixelStep();
    const inv_scale = rr.devicePixelStep();
    const glyph_w = @as(f32, @floatFromInt(glyph.width)) * inv_scale;
    const glyph_h = @as(f32, @floatFromInt(glyph.height)) * inv_scale;
    const bearing_x = @as(f32, @floatFromInt(glyph.bearing_x)) * inv_scale;
    const bearing_y = @as(f32, @floatFromInt(glyph.bearing_y)) * inv_scale;
    const dest = if (simple_ascii) blk: {
        const draw_x = @max(x, x + bearing_x);
        const draw_y = baseline - bearing_y;
        const axis_x = rr.quantizeLogicalHorizontalAxis(draw_x, glyph_w);
        const axis_y = rr.quantizeLogicalVerticalAxis(draw_y, glyph_h);
        break :blk terminal_font_mod.Rect{
            .x = axis_x.origin,
            .y = axis_y.origin,
            .width = axis_x.size,
            .height = axis_y.size,
        };
    } else blk: {
        const is_symbol_glyph = (base_codepoint >= 0xE000 and base_codepoint <= 0xF8FF) or
            (base_codepoint >= 0xF0000 and base_codepoint <= 0xFFFFD) or
            (base_codepoint >= 0x100000 and base_codepoint <= 0x10FFFD) or
            (base_codepoint >= 0x2700 and base_codepoint <= 0x27BF) or
            (base_codepoint >= 0x2600 and base_codepoint <= 0x26FF);
        _ = followed_by_space;
        const allow_width_overflow = is_symbol_glyph;
        const overflow_scale_x: f32 = 1.0;
        const scaled_w = glyph_w * overflow_scale_x;
        const scaled_h = glyph_h;
        const draw_x = if (allow_width_overflow) x + bearing_x * overflow_scale_x else @max(x, x + bearing_x * overflow_scale_x);
        const draw_y = baseline - bearing_y;
        const axis_x = rr.quantizeLogicalHorizontalAxis(draw_x, scaled_w);
        const axis_y = rr.quantizeLogicalVerticalAxis(draw_y, scaled_h);
        break :blk if (base_codepoint == 0xE0B1 or base_codepoint == 0xE0B3) blk2: {
            const cell_left = rr.snapLogicalToDevicePixel(x);
            const cell_right = rr.snapLogicalToDevicePixel(x + cell_width);
            break :blk2 terminal_font_mod.Rect{
                .x = cell_left,
                .y = axis_y.origin,
                .width = @max(inv_scale, cell_right - cell_left),
                .height = axis_y.size,
            };
        } else terminal_font_mod.Rect{
            .x = axis_x.origin,
            .y = axis_y.origin,
            .width = axis_x.size,
            .height = axis_y.size,
        };
    };
    const draw_color = if (glyph.is_color) Rgba{ .r = 255, .g = 255, .b = 255, .a = 255 } else color;
    if (glyph.is_color) {
        ctx_draw.drawTexture(ctx_draw.ctx, font.colorTexture(), glyph.rect, dest, draw_color, .rgba);
    } else {
        ctx_draw.drawTexture(ctx_draw.ctx, font.coverageTexture(), glyph.rect, dest, draw_color, .font_coverage);
    }
    if (capture_sample) |sample| {
        captureTextPaintSample(
            sample,
            capture_generation,
            capture_row,
            capture_cursor_col,
            capture_col,
            capture_cell,
            capture_width_units,
            capture_cell_x,
            capture_cell_y,
            cell_width,
            cell_height,
            baseline,
            render_scale,
            dest,
            .direct,
        );
    }
    if (stats) |s| s.direct_draw_ms += (app_shell.getTime() - draw_submit_start) * 1000.0;
}

fn drawAlignedSpecialGlyphSprite(
    rr: *Renderer,
    row_cells: []const Cell,
    abs_col: usize,
    width_units: usize,
    screen_reverse_mode: bool,
    draw_cursor_mode: bool,
    cursor_pos: CursorPos,
    cursor_style: anytype,
    row_idx: usize,
    codepoint: u32,
    variant: terminal_font_mod.SpecialGlyphVariant,
    box_x: f32,
    box_y: f32,
    box_w: f32,
    box_h: f32,
    fg_draw: Color,
    row_sprite_cache: ?*RowSpecialSpriteCache,
    stats: ?*GlyphDrawStats,
    capture_sample: ?*TextPaintSample,
    capture_generation: u64,
    capture_row: usize,
    capture_cursor_col: usize,
    capture_col: usize,
    capture_cell: Cell,
    capture_width_units: usize,
    capture_cell_x: f32,
    capture_cell_y: f32,
) bool {
    const render_scale = 1.0 / rr.devicePixelStep();
    const snap_horizontal_edges = shouldSnapSpecialGlyphHorizontalEdges(render_scale, variant);
    const x0 = if (snap_horizontal_edges) rr.snapLogicalToDevicePixel(box_x) else box_x;
    const x1 = if (snap_horizontal_edges) rr.snapLogicalToDevicePixel(box_x + box_w) else box_x + box_w;
    const use_y_snap = variant == .box or variant == .braille or variant == .shade;
    const y0_unsnapped = box_y;
    const y1_unsnapped = box_y + box_h;
    const y0 = if (use_y_snap) rr.snapLogicalToDevicePixel(y0_unsnapped) else y0_unsnapped;
    const y1 = if (use_y_snap) rr.snapLogicalToDevicePixel(y1_unsnapped) else y1_unsnapped;
    const snapped_w = @max(rr.devicePixelStep(), x1 - x0);
    const snapped_h = @max(rr.devicePixelStep(), y1 - y0);
    const raster_w_i: i32 = @max(1, @as(i32, @intFromFloat(std.math.round(snapped_w * render_scale))));
    const raster_h_i: i32 = @max(1, @as(i32, @intFromFloat(std.math.round(snapped_h * render_scale))));
    const lookup_start = app_shell.getTime();
    const sprite_key = rr.terminal_font.specialGlyphSpriteKey(codepoint, raster_w_i, raster_h_i, variant);
    const sprite_fetch = if (row_sprite_cache) |cache|
        if (cache.key) |cached_key|
            if (std.meta.eql(cached_key, sprite_key) and cache.sprite != null)
                terminal_font_mod.SpecialGlyphSpriteFetch{ .sprite = &cache.sprite.?, .created = false }
            else
                rr.terminal_font.getOrCreateSpecialGlyphSpriteWithStatus(codepoint, raster_w_i, raster_h_i, raster_w_i, raster_h_i, variant)
        else
            rr.terminal_font.getOrCreateSpecialGlyphSpriteWithStatus(codepoint, raster_w_i, raster_h_i, raster_w_i, raster_h_i, variant)
    else
        rr.terminal_font.getOrCreateSpecialGlyphSpriteWithStatus(codepoint, raster_w_i, raster_h_i, raster_w_i, raster_h_i, variant);
    const sprite = sprite_fetch.sprite;
    if (stats) |s| {
        if (sprite_fetch.created) {
            s.special_sprite_cache_misses += 1;
            s.special_sprite_creates += 1;
        } else if (sprite != null) {
            s.special_sprite_cache_hits += 1;
        } else {
            s.special_sprite_cache_misses += 1;
        }
    }
    if (row_sprite_cache) |cache| {
        cache.key = sprite_key;
        cache.sprite = if (sprite) |sp| sp.* else null;
    }
    if (stats) |s| s.special_sprite_lookup_ms += (app_shell.getTime() - lookup_start) * 1000.0;
    if (sprite) |sp| {
        const submit_start = app_shell.getTime();
        var dest_x = x0;
        var dest_w = snapped_w;
        if (variant == .powerline) {
            const seam_overdraw = rr.devicePixelStep();
            if (codepoint == 0xE0B2 or codepoint == 0xE0B6) {
                const next_col = abs_col + width_units;
                if (next_col < row_cells.len) {
                    const next_cell = row_cells[next_col];
                    const next_bg = resolvedDrawBackgroundColor(next_cell, screen_reverse_mode, row_idx, next_col, draw_cursor_mode, cursor_pos, cursor_style);
                    if (next_bg.r == fg_draw.r and next_bg.g == fg_draw.g and next_bg.b == fg_draw.b) dest_w += seam_overdraw;
                }
            } else if (codepoint == 0xE0B0 or codepoint == 0xE0B4) {
                if (abs_col > 0) {
                    const prev_cell = row_cells[abs_col - 1];
                    const prev_bg = resolvedDrawBackgroundColor(prev_cell, screen_reverse_mode, row_idx, abs_col - 1, draw_cursor_mode, cursor_pos, cursor_style);
                    if (prev_bg.r == fg_draw.r and prev_bg.g == fg_draw.g and prev_bg.b == fg_draw.b) {
                        dest_x -= seam_overdraw;
                        dest_w += seam_overdraw;
                    }
                }
            }
        }
        renderer_terminal_draw_host.addTerminalGlyphQuad(rr, rr.terminal_font.coverageTexture(), sp.rect, .{ .x = dest_x, .y = y0, .width = dest_w, .height = snapped_h }, fg_draw.toRgba(), .{ .r = 0, .g = 0, .b = 0, .a = 0 }, .font_coverage);
        if (capture_sample) |sample| {
            captureTextPaintSample(
                sample,
                capture_generation,
                capture_row,
                capture_cursor_col,
                capture_col,
                capture_cell,
                capture_width_units,
                capture_cell_x,
                capture_cell_y,
                box_w,
                box_h,
                capture_cell_y,
                render_scale,
                .{ .x = dest_x, .y = y0, .width = dest_w, .height = snapped_h },
                .special,
            );
        }
        if (stats) |s| {
            s.shaped_special_glyphs += 1;
            const submit_ms = (app_shell.getTime() - submit_start) * 1000.0;
            s.shaped_special_submit_ms += submit_ms;
            if (variant == .box) {
                s.box_glyphs += 1;
                s.box_submit_ms += submit_ms;
                s.box_sprite_submit_ms += submit_ms;
            } else if (variant == .shade) {
                s.shade_special_glyphs += 1;
                s.special_sprite_glyphs += 1;
                s.special_sprite_submit_ms += submit_ms;
            } else if (variant == .powerline) {
                s.powerline_special_glyphs += 1;
                s.special_sprite_glyphs += 1;
                s.special_sprite_submit_ms += submit_ms;
            } else if (variant == .braille) {
                s.braille_special_glyphs += 1;
                s.special_sprite_glyphs += 1;
                s.special_sprite_submit_ms += submit_ms;
            } else {
                s.special_sprite_glyphs += 1;
                s.special_sprite_submit_ms += submit_ms;
            }
        }
        return true;
    }
    return false;
}

test "shade special glyph horizontal snapping matches text policy at fractional scale" {
    try std.testing.expect(shouldSnapSpecialGlyphHorizontalEdges(1.0, .shade));
    try std.testing.expect(shouldSnapSpecialGlyphHorizontalEdges(2.0, .shade));
    try std.testing.expect(!shouldSnapSpecialGlyphHorizontalEdges(1.6, .shade));
    try std.testing.expect(shouldSnapSpecialGlyphHorizontalEdges(1.6, .box));
    try std.testing.expect(shouldSnapSpecialGlyphHorizontalEdges(1.6, .powerline));
}

pub fn drawRowGlyphs(
    renderer: *Shell,
    view: shared_types.layout.TerminalViewGeometry,
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
    cursor_style: anytype,
    ligature_strategy: TerminalDisableLigaturesStrategy,
    publication_generation: u64,
    stats: ?*GlyphDrawStats,
    text_paint_sample: ?*TextPaintSample,
    metal_fallback_sample: ?*MetalTerminalFallbackSample,
) void {
    const row_fixed_start = app_shell.getTime();
    _ = padding_x_i;
    const rr = renderer.rendererPtr();
    const cell_w = view.cell_width;
    const cell_h = view.cell_height;
    const row_cells = rowSlice(snapshot_cells, cols_count, row_idx);
    if (row_cells.len != cols_count) return;
    const col_start = @min(col_start_in, cols_count - 1);
    const col_end = @min(col_end_in, cols_count - 1);
    if (col_start > col_end) return;
    var row_sprite_cache = RowSpecialSpriteCache{};

    if (rr.textRenderingMode() == .unavailable and rr.plannedTextRenderingMode() == .metal_texture_atlas) {
        var fallback_col: usize = col_start;
        while (fallback_col <= col_end and fallback_col < cols_count) {
            const cell = row_cells[fallback_col];
            if (cell.x != 0 or cell.y != 0) {
                fallback_col += 1;
                continue;
            }
            const style = resolveCellStyle(cell, screen_reverse_mode, hover_link, blink_style_mode, blink_time_s, draw_cursor_mode, cursor_pos, cursor_style, row_idx, fallback_col);
            if (!style.glyph_visible) {
                fallback_col += style.width_units;
                continue;
            }
            const cell_x = base_x_local + @as(f32, @floatFromInt(@as(i32, @intCast(fallback_col)))) * cell_w;
            const cell_y = base_y_local + @as(f32, @floatFromInt(@as(i32, @intCast(row_idx)))) * cell_h;
            const cell_w_span = cell_w * @as(f32, @floatFromInt(@as(i32, @intCast(style.width_units))));
            const capture_special = if (shouldCaptureTextPaint(text_paint_sample, row_idx, cursor_pos, fallback_col, style.width_units))
                text_paint_sample
            else
                null;
            if (cell.combining_len == 0) {
                if (terminal_glyphs.specialVariantForCodepoint(cell.codepoint)) |variant| {
                    if (drawAlignedSpecialGlyphSprite(rr, row_cells, fallback_col, style.width_units, screen_reverse_mode, draw_cursor_mode, cursor_pos, cursor_style, row_idx, cell.codepoint, variant, cell_x, cell_y, cell_w_span, cell_h, style.fg, &row_sprite_cache, stats, capture_special, publication_generation, row_idx, cursor_pos.col, fallback_col, cell, style.width_units, cell_x, cell_y)) {
                        if (metal_fallback_sample) |sample| {
                            sample.special_sprite_glyphs += 1;
                            sample.shaped_special_glyphs += 1;
                            if (variant == .shade) sample.shade_special_glyphs += 1;
                            if (variant == .powerline) sample.powerline_special_glyphs += 1;
                            if (variant == .braille) sample.braille_special_glyphs += 1;
                        }
                    }
                    fallback_col += style.width_units;
                    continue;
                }
            }
            const followed_by_space = terminalCellFollowedBySpace(row_cells, cols_count, fallback_col, style.width_units);
            if (cell.combining_len > 0) {
                rr.drawTerminalCellGraphemeBatched(cell.codepoint, cell.combining[0..@intCast(cell.combining_len)], cell_x, cell_y, cell_w_span, cell_h, style.fg, style.bg, style.underline_color, style.bold, style.underline, false, followed_by_space, false);
            } else {
                rr.drawTerminalCellBatched(cell.codepoint, cell_x, cell_y, cell_w_span, cell_h, style.fg, style.bg, style.underline_color, style.bold, style.underline, false, followed_by_space, false);
            }
            if (shouldCaptureTextPaint(text_paint_sample, row_idx, cursor_pos, fallback_col, style.width_units)) {
                captureTextPaintSample(
                    text_paint_sample.?,
                    publication_generation,
                    row_idx,
                    cursor_pos.col,
                    fallback_col,
                    cell,
                    style.width_units,
                    cell_x,
                    cell_y,
                    cell_w_span,
                    cell_h,
                    cell_y,
                    if (rr.terminal_font.render_scale > 0.0) rr.terminal_font.render_scale else 1.0,
                    .{
                        .x = cell_x,
                        .y = cell_y,
                        .width = cell_w_span,
                        .height = cell_h,
                    },
                    .fallback,
                );
            }
            if (stats) |s| s.fallback_cells += 1;
            fallback_col += style.width_units;
        }
        return;
    }

    var draw_ctx = TerminalGlyphDrawContext{
        .renderer = rr,
        .bg_rgba = .{ .r = 0, .g = 0, .b = 0, .a = 0 },
    };
    const font_draw_ctx = DrawContext{ .ctx = @ptrCast(&draw_ctx), .drawTexture = drawTextureGlyphCache };
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
    _ = row_fixed_start;

    var col: usize = col_start;
    while (col <= col_end and col < cols_count) {
        const span_scan_start = app_shell.getTime();
        var span_font_choice_ms: f64 = 0.0;
        const cell0 = row_cells[col];
        if (cell0.x != 0 or cell0.y != 0) {
            col += 1;
            continue;
        }
        const span_fast = rr.terminal_font.directFastGlyphForCodepoint(cell0.codepoint);
        const span_choice = if (span_fast != null) terminal_font_mod.TerminalFont.FontChoice{
            .slot = .primary,
            .face = rr.terminal_font.ft_face,
            .hb_font = rr.terminal_font.hb_font,
            .want_color = false,
        } else blk: {
            const span_choice_start = app_shell.getTime();
            const span_choice = rr.terminal_font.pickFontForCodepoint(cell0.codepoint);
            span_font_choice_ms += (app_shell.getTime() - span_choice_start) * 1000.0;
            break :blk span_choice;
        };
        const span_hb_font = span_choice.hb_font;
        const span_can_bypass = cellCanBypassShaping(cell0);
        const span_can_direct_special = cellCanDirectSpecial(cell0);
        const span_start_col = col;
        var scan_col: usize = col;
        if (span_fast != null and span_can_bypass and !span_can_direct_special) {
            while (scan_col <= col_end and scan_col < cols_count) {
                const ccell = row_cells[scan_col];
                if (ccell.x != 0 or ccell.y != 0) {
                    scan_col += 1;
                    continue;
                }
                const cwidth_units = @as(usize, @max(@as(u8, 1), ccell.width));
                if (rr.terminal_font.directFastGlyphForCodepoint(ccell.codepoint) == null) break;
                scan_col += cwidth_units;
            }
        } else {
            while (scan_col <= col_end and scan_col < cols_count) {
                const ccell = row_cells[scan_col];
                if (ccell.x != 0 or ccell.y != 0) {
                    scan_col += 1;
                    continue;
                }
                const cwidth_units = @as(usize, @max(@as(u8, 1), ccell.width));
                if (span_fast != null) {
                    if (rr.terminal_font.directFastGlyphForCodepoint(ccell.codepoint) == null) break;
                } else {
                    const choice_start = app_shell.getTime();
                    const choice = rr.terminal_font.pickFontForCodepoint(ccell.codepoint);
                    span_font_choice_ms += (app_shell.getTime() - choice_start) * 1000.0;
                    if (choice.hb_font != span_hb_font) break;
                }
                if (cellCanBypassShaping(ccell) != span_can_bypass) break;
                if (cellCanDirectSpecial(ccell) != span_can_direct_special) break;
                scan_col += cwidth_units;
            }
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
        if (stats) |s| s.shaping_spans += 1;

        const disable_programming_ligatures = switch (ligature_strategy) {
            .never => false,
            .always => true,
            .cursor => cursor_row_active and span_start_col == cursor_split_col,
        };
        var shape_features_buf: [16]hb.hb_feature_t = undefined;
        const shape_features_len = rr.collectShapeFeatures(.terminal, disable_programming_ligatures, shape_features_buf[0..]);
        if (shape_features_len == 0 and span_can_bypass and spanCanBypassShaping(row_cells, span_start_col, span_end_excl)) {
            _ = span_scan_start;
            const row_baseline = base_y_local + @as(f32, @floatFromInt(@as(i32, @intCast(row_idx)))) * cell_h + view.baseline_from_top;
            var direct_col = span_start_col;
            while (direct_col < span_end_excl and direct_col < row_cells.len) : (direct_col += 1) {
                const cell = row_cells[direct_col];
                if (cell.x != 0 or cell.y != 0) continue;
                const style = resolveCellStyle(cell, screen_reverse_mode, hover_link, blink_style_mode, blink_time_s, draw_cursor_mode, cursor_pos, cursor_style, row_idx, direct_col);
                if (!style.glyph_visible) continue;
                if (cell.codepoint == 0 or cell.codepoint == ' ') continue;
                var behind_rgba = style.bg.toRgba();
                // Terminal cell backgrounds are already painted as solid rects.
                // Leave alpha at zero so GL font coverage does not apply
                // luminance-based background correction that can erase colored
                // terminal glyphs on overridden cell backgrounds.
                behind_rgba.a = 0;
                draw_ctx.bg_rgba = behind_rgba;

                const direct_choice_start = app_shell.getTime();
                const choice = if (rr.terminal_font.directFastGlyphForCodepoint(cell.codepoint)) |fast|
                    fast
                else blk: {
                    const picked = rr.terminal_font.pickFontForCodepoint(cell.codepoint);
                    const glyph_id = hb.FT_Get_Char_Index(picked.face, if (cell.codepoint == 0) ' ' else cell.codepoint);
                    if (glyph_id == 0) continue;
                    break :blk terminal_font_mod.TerminalFont.DirectFastGlyph{
                        .slot = picked.slot,
                        .face = picked.face,
                        .want_color = picked.want_color,
                        .glyph_id = glyph_id,
                        .simple_ascii = false,
                    };
                };
                _ = direct_choice_start;
                const cell_x = base_x_local + @as(f32, @floatFromInt(@as(i32, @intCast(direct_col)))) * cell_w;
                const followed_by_space = terminalCellFollowedBySpace(row_cells, row_cells.len, direct_col, style.width_units);
                const capture_direct = if (shouldCaptureTextPaint(text_paint_sample, row_idx, cursor_pos, direct_col, style.width_units))
                    text_paint_sample
                else
                    null;
                drawDirectGlyphById(
                    rr,
                    &rr.terminal_font,
                    font_draw_ctx,
                    choice.face,
                    choice.want_color,
                    cell.codepoint,
                    choice.glyph_id,
                    choice.simple_ascii,
                    row_baseline,
                    cell_x,
                    cell_w,
                    cell_h,
                    followed_by_space,
                    style.fg.toRgba(),
                    stats,
                    capture_direct,
                    publication_generation,
                    row_idx,
                    cursor_pos.col,
                    direct_col,
                    cell,
                    style.width_units,
                    cell_x,
                    base_y_local + @as(f32, @floatFromInt(@as(i32, @intCast(row_idx)))) * cell_h,
                );
                if (stats) |s| {
                    s.shaped_glyphs += 1;
                    s.direct_text_glyphs += 1;
                }
            }
            col = span_end_excl;
            continue;
        }
        if (shape_features_len == 0 and span_can_direct_special) {
            var special_col = span_start_col;
            while (special_col < span_end_excl and special_col < row_cells.len) : (special_col += 1) {
                const cell = row_cells[special_col];
                if (cell.x != 0 or cell.y != 0) continue;
                const style = resolveCellStyle(cell, screen_reverse_mode, hover_link, blink_style_mode, blink_time_s, draw_cursor_mode, cursor_pos, cursor_style, row_idx, special_col);
                if (!style.glyph_visible) continue;
                var behind_rgba = style.bg.toRgba();
                // Special terminal glyphs share the same coverage path and
                // must avoid bg-aware luminance correction for colored cells.
                behind_rgba.a = 0;
                draw_ctx.bg_rgba = behind_rgba;
                const box_x = base_x_local + @as(f32, @floatFromInt(@as(i32, @intCast(special_col)))) * cell_w;
                const box_y = base_y_local + @as(f32, @floatFromInt(@as(i32, @intCast(row_idx)))) * cell_h;
                const box_w = cell_w * @as(f32, @floatFromInt(@as(i32, @intCast(style.width_units))));
                const box_h = cell_h;
                const capture_special = if (shouldCaptureTextPaint(text_paint_sample, row_idx, cursor_pos, special_col, style.width_units))
                    text_paint_sample
                else
                    null;
                if (terminal_glyphs.specialVariantForCodepoint(cell.codepoint)) |variant| {
                    _ = drawAlignedSpecialGlyphSprite(rr, row_cells, special_col, style.width_units, screen_reverse_mode, draw_cursor_mode, cursor_pos, cursor_style, row_idx, cell.codepoint, variant, box_x, box_y, box_w, box_h, style.fg, &row_sprite_cache, stats, capture_special, publication_generation, row_idx, cursor_pos.col, special_col, cell, style.width_units, box_x, box_y);
                    continue;
                }
            }
            col = span_end_excl;
            continue;
        }

        if (rr.textRenderingMode() == .unavailable and rr.plannedTextRenderingMode() == .metal_texture_atlas) {
            var metal_col: usize = span_start_col;
            while (metal_col < span_end_excl and metal_col < cols_count and metal_col < row_cells.len) {
                const cell = row_cells[metal_col];
                const style = resolveCellStyle(cell, screen_reverse_mode, hover_link, blink_style_mode, blink_time_s, draw_cursor_mode, cursor_pos, cursor_style, row_idx, metal_col);
                if (cell.x != 0 or cell.y != 0) {
                    metal_col += 1;
                    continue;
                }
                if (!style.glyph_visible) {
                    metal_col += style.width_units;
                    continue;
                }

                const cell_x = base_x_local + @as(f32, @floatFromInt(@as(i32, @intCast(metal_col)))) * cell_w;
                const cell_y = base_y_local + @as(f32, @floatFromInt(@as(i32, @intCast(row_idx)))) * cell_h;
                const cell_w_span = cell_w * @as(f32, @floatFromInt(@as(i32, @intCast(style.width_units))));
                const followed_by_space = terminalCellFollowedBySpace(row_cells, row_cells.len, metal_col, style.width_units);
                if (cell.codepoint != 0 and cell.codepoint != kitty_unicode_placeholder) {
                    if (cell.combining_len > 0) {
                        rr.drawTerminalCellGraphemeBatched(cell.codepoint, cell.combining[0..@intCast(cell.combining_len)], cell_x, cell_y, cell_w_span, cell_h, style.fg, style.bg, style.underline_color, style.bold, style.underline, false, followed_by_space, false);
                    } else {
                        rr.drawTerminalCellBatched(cell.codepoint, cell_x, cell_y, cell_w_span, cell_h, style.fg, style.bg, style.underline_color, style.bold, style.underline, false, followed_by_space, false);
                    }
                }
                if (stats) |s| s.fallback_cells += style.width_units;
                metal_col += style.width_units;
            }
            col = span_end_excl;
            continue;
        }

        const buffer = rr.terminalShapeBuffer();
        const shape_phase_start = app_shell.getTime();
        hb.hb_buffer_reset(buffer);
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
        if (stats) |s| s.shape_ms += (app_shell.getTime() - shape_phase_start) * 1000.0;

        cc = span_start_col;
        while (cc < span_end_excl and cc < cols_count) {
            const ccell = row_cells[cc];
            if (ccell.x != 0 or ccell.y != 0) {
                cc += 1;
                continue;
            }
            const style = resolveCellStyle(ccell, screen_reverse_mode, hover_link, blink_style_mode, blink_time_s, draw_cursor_mode, cursor_pos, cursor_style, row_idx, cc);
            const cell_x = base_x_local + @as(f32, @floatFromInt(@as(i32, @intCast(cc)))) * cell_w;
            const cell_y = base_y_local + @as(f32, @floatFromInt(@as(i32, @intCast(row_idx)))) * cell_h;
            if (!style.glyph_visible) {
                cc += style.width_units;
                continue;
            }
            if (style.underline and ccell.codepoint != 0) {
                terminal_underline.drawUnderline(addTerminalGlyphRect, rr, @as(i32, @intFromFloat(std.math.round(cell_x))), @as(i32, @intFromFloat(std.math.round(cell_y))), @as(i32, @intFromFloat(std.math.round(cell_w * @as(f32, @floatFromInt(@as(i32, @intCast(style.width_units))))))), @as(i32, @intFromFloat(std.math.round(cell_h))), style.underline_color);
            }
            cc += style.width_units;
        }

        rr.terminal_text.shape_first_pen_set.items.len = 0;
        rr.terminal_text.shape_first_pen.items.len = 0;
        rr.terminal_text.shape_first_pen_set.ensureTotalCapacity(rr.allocator, span_cols) catch {
            col = span_end_excl;
            continue;
        };
        rr.terminal_text.shape_first_pen.ensureTotalCapacity(rr.allocator, span_cols) catch {
            col = span_end_excl;
            continue;
        };
        rr.terminal_text.shape_first_pen_set.items.len = span_cols;
        rr.terminal_text.shape_first_pen.items.len = span_cols;
        @memset(rr.terminal_text.shape_first_pen_set.items, false);
        @memset(rr.terminal_text.shape_first_pen.items, 0);

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
                const style = resolveCellStyle(cell, screen_reverse_mode, hover_link, blink_style_mode, blink_time_s, draw_cursor_mode, cursor_pos, cursor_style, row_idx, fb_col);
                const cell_x = base_x_local + @as(f32, @floatFromInt(@as(i32, @intCast(fb_col)))) * cell_w;
                const cell_y = base_y_local + @as(f32, @floatFromInt(@as(i32, @intCast(row_idx)))) * cell_h;
                if (!style.glyph_visible) {
                    fb_col += style.width_units;
                    continue;
                }
                const followed_by_space = terminalCellFollowedBySpace(row_cells, cols_count, fb_col, style.width_units);
                if (cell.combining_len > 0) {
                    rr.drawTerminalCellGraphemeBatched(cell.codepoint, cell.combining[0..@intCast(cell.combining_len)], cell_x, cell_y, cell_w * @as(f32, @floatFromInt(@as(i32, @intCast(style.width_units)))), cell_h, style.fg, style.bg, style.underline_color, style.bold, style.underline, false, followed_by_space, false);
                } else {
                    rr.drawTerminalCellBatched(cell.codepoint, cell_x, cell_y, cell_w * @as(f32, @floatFromInt(@as(i32, @intCast(style.width_units)))), cell_h, style.fg, style.bg, style.underline_color, style.bold, style.underline, false, followed_by_space, false);
                }
                if (shouldCaptureTextPaint(text_paint_sample, row_idx, cursor_pos, fb_col, style.width_units)) {
                    captureTextPaintSample(
                        text_paint_sample.?,
                        publication_generation,
                        row_idx,
                        cursor_pos.col,
                        fb_col,
                        cell,
                        style.width_units,
                        cell_x,
                        cell_y,
                        cell_w * @as(f32, @floatFromInt(@as(i32, @intCast(style.width_units)))),
                        cell_h,
                        cell_y,
                        if (rr.terminal_font.render_scale > 0.0) rr.terminal_font.render_scale else 1.0,
                        .{
                            .x = cell_x,
                            .y = cell_y,
                            .width = cell_w * @as(f32, @floatFromInt(@as(i32, @intCast(style.width_units)))),
                            .height = cell_h,
                        },
                        .fallback,
                    );
                }
                if (stats) |s| s.fallback_cells += 1;
                fb_col += style.width_units;
            }
            col = span_end_excl;
            continue;
        }

        const glyph_len: usize = @intCast(length);
        const inv_scale = rr.devicePixelStep();
        const submit_phase_start = app_shell.getTime();
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
            const style = resolveCellStyle(cell, screen_reverse_mode, hover_link, blink_style_mode, blink_time_s, draw_cursor_mode, cursor_pos, cursor_style, row_idx, abs_col);
            const cell_x = base_x_local + @as(f32, @floatFromInt(@as(i32, @intCast(abs_col)))) * cell_w;
            const cell_y = base_y_local + @as(f32, @floatFromInt(@as(i32, @intCast(row_idx)))) * cell_h;
            const cell_w_span = cell_w * @as(f32, @floatFromInt(@as(i32, @intCast(style.width_units))));
            const cell_h_span = cell_h;

            if (!rr.terminal_text.shape_first_pen_set.items[cluster_rel]) {
                rr.terminal_text.shape_first_pen_set.items[cluster_rel] = true;
                rr.terminal_text.shape_first_pen.items[cluster_rel] = pen_before;
            }
            const pen_rel = pen_before - rr.terminal_text.shape_first_pen.items[cluster_rel];
            if (!style.glyph_visible) continue;
            const followed_by_space = terminalCellFollowedBySpace(row_cells, row_cells.len, abs_col, style.width_units);
            var behind_rgba = style.bg.toRgba();
            // Shaped terminal glyphs use the same GL coverage atlas path as
            // direct glyphs; keep bg alpha clear so cell-local bg overrides do
            // not suppress low-luminance colored foreground text.
            behind_rgba.a = 0;
            draw_ctx.bg_rgba = behind_rgba;

            if (cell.codepoint == 0 or cell.codepoint == kitty_unicode_placeholder) continue;
            if (cell.codepoint == ' ' and cell.combining_len == 0) {
                if (stats) |s| s.shaped_space_skips += 1;
                continue;
            }
            if (cell.combining_len == 0) {
                const box_x = cell_x;
                const box_y = cell_y;
                const box_w = cell_w_span;
                const box_h = cell_h_span;
                const capture_shaped_special = if (shouldCaptureTextPaint(text_paint_sample, row_idx, cursor_pos, abs_col, style.width_units))
                    text_paint_sample
                else
                    null;
                if (terminal_glyphs.specialVariantForCodepoint(cell.codepoint)) |variant| {
                    _ = drawAlignedSpecialGlyphSprite(rr, row_cells, abs_col, style.width_units, screen_reverse_mode, draw_cursor_mode, cursor_pos, cursor_style, row_idx, cell.codepoint, variant, box_x, box_y, box_w, box_h, style.fg, &row_sprite_cache, stats, capture_shaped_special, publication_generation, row_idx, cursor_pos.col, abs_col, cell, style.width_units, box_x, box_y);
                    continue;
                }
            }

            const text_submit_start = app_shell.getTime();
            const capture_shaped = if (shouldCaptureTextPaint(text_paint_sample, row_idx, cursor_pos, abs_col, style.width_units))
                text_paint_sample
            else
                null;
            drawShapedGlyph(
                rr,
                &rr.terminal_font,
                font_draw_ctx,
                span_choice.face,
                span_choice.want_color,
                cell.codepoint,
                infos[i].codepoint,
                positions[i],
                pen_rel,
                cell_x,
                cell_y,
                view.baseline_from_top,
                cell_w_span,
                cell_h_span,
                followed_by_space,
                style.fg.toRgba(),
                capture_shaped,
                publication_generation,
                row_idx,
                cursor_pos.col,
                abs_col,
                cell,
                style.width_units,
                cell_x,
                cell_y,
            );
            if (stats) |s| {
                s.shaped_glyphs += 1;
                s.shaped_text_glyphs += 1;
                s.shaped_text_submit_ms += (app_shell.getTime() - text_submit_start) * 1000.0;
            }
        }
        if (stats) |s| s.submit_ms += (app_shell.getTime() - submit_phase_start) * 1000.0;

        col = span_end_excl;
    }
}
