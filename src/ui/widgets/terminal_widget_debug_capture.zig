const std = @import("std");

const app_shell = @import("../../app_shell.zig");
const terminal_publication = @import("../../terminal/core/publication/terminal_publication.zig");
const terminal_types = @import("../../terminal/model/types.zig");
const view_state = @import("terminal_widget_view_state.zig");

const Shell = app_shell.Shell;
const Cell = terminal_publication.Cell;

pub const visible_ascii_dump_path = "zide_terminal_view_dump.txt";

pub fn dumpVisibleAsciiView(widget: anytype, shell: *Shell, log: anytype) !void {
    var out = std.ArrayList(u8).empty;
    defer out.deinit(widget.session.allocator);
    const debug = &widget.debug;
    const terminal_view = widget.publication.model();
    const dump_info = terminal_view.visibleViewDumpInfo();
    const metrics = shell.refreshWindowGeometryDiagnostics("terminal_visible_ascii_dump");

    try out.writer(widget.session.allocator).print(
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
    try out.writer(widget.session.allocator).print(
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

    try out.writer(widget.session.allocator).print(
        "view_geometry valid={d} generation={d} base=({d:.3},{d:.3}) viewport=({d:.3}x{d:.3}) rows={d} cols={d} cell_logical=({d:.3}x{d:.3}) cell_device=({d}x{d}) baseline={d:.3} ui_scale={d:.3} render_scale={d:.3}\n",
        .{
            @intFromBool(debug.last_view_geometry.valid),
            debug.last_view_geometry.generation,
            debug.last_view_geometry.base_x,
            debug.last_view_geometry.base_y,
            debug.last_view_geometry.viewport_w,
            debug.last_view_geometry.viewport_h,
            debug.last_view_geometry.rows,
            debug.last_view_geometry.cols,
            debug.last_view_geometry.cell_width_logical,
            debug.last_view_geometry.cell_height_logical,
            debug.last_view_geometry.cell_width_device,
            debug.last_view_geometry.cell_height_device,
            debug.last_view_geometry.baseline_logical,
            debug.last_view_geometry.ui_scale,
            debug.last_view_geometry.render_scale,
        },
    );
    try out.writer(widget.session.allocator).print(
        "cursor_overlay valid={d} generation={d} row={d} col={d} cp={d} width_units={d} cell=({d:.3},{d:.3},{d:.3},{d:.3}) cursor=({d:.3},{d:.3},{d:.3},{d:.3}) text_input_w={d:.3} edge_inset={d:.3} stroke={d:.3} render_scale={d:.3}\n",
        .{
            @intFromBool(debug.last_cursor_overlay.valid),
            debug.last_cursor_overlay.generation,
            debug.last_cursor_overlay.row,
            debug.last_cursor_overlay.col,
            debug.last_cursor_overlay.codepoint,
            debug.last_cursor_overlay.width_units,
            debug.last_cursor_overlay.cell_x,
            debug.last_cursor_overlay.cell_y,
            debug.last_cursor_overlay.cell_w,
            debug.last_cursor_overlay.cell_h,
            debug.last_cursor_overlay.cursor_x,
            debug.last_cursor_overlay.cursor_y,
            debug.last_cursor_overlay.cursor_w,
            debug.last_cursor_overlay.cursor_h,
            debug.last_cursor_overlay.text_input_w,
            debug.last_cursor_overlay.edge_inset,
            debug.last_cursor_overlay.stroke,
            debug.last_cursor_overlay.render_scale,
        },
    );
    try out.writer(widget.session.allocator).print(
        "terminal_present valid={d} mode={s} generation={d} texture_px=({d}x{d}) target_logical=({d:.3}x{d:.3}) source_logical=({d:.3}x{d:.3}) dest=({d:.3},{d:.3},{d:.3},{d:.3}) scale=({d:.6},{d:.6})\n",
        .{
            @intFromBool(debug.last_surface_present.valid),
            @tagName(debug.last_surface_present.mode),
            debug.last_surface_present.generation,
            debug.last_surface_present.texture_w_px,
            debug.last_surface_present.texture_h_px,
            debug.last_surface_present.target_logical_w,
            debug.last_surface_present.target_logical_h,
            debug.last_surface_present.source_logical_w,
            debug.last_surface_present.source_logical_h,
            debug.last_surface_present.dest_x,
            debug.last_surface_present.dest_y,
            debug.last_surface_present.dest_w,
            debug.last_surface_present.dest_h,
            debug.last_surface_present.scale_x,
            debug.last_surface_present.scale_y,
        },
    );
    try out.writer(widget.session.allocator).print(
        "text_paint valid={d} generation={d} row={d} col={d} covers_cursor={d} cursor_distance_cols={d} cp={d} width_units={d} source={s} cell=({d:.3},{d:.3},{d:.3},{d:.3}) glyph=({d:.3},{d:.3},{d:.3},{d:.3}) baseline={d:.3} render_scale={d:.3}\n",
        .{
            @intFromBool(debug.last_text_paint.valid),
            debug.last_text_paint.generation,
            debug.last_text_paint.row,
            debug.last_text_paint.col,
            @intFromBool(debug.last_text_paint.covers_cursor),
            debug.last_text_paint.cursor_distance_cols,
            debug.last_text_paint.codepoint,
            debug.last_text_paint.width_units,
            @tagName(debug.last_text_paint.source),
            debug.last_text_paint.cell_x,
            debug.last_text_paint.cell_y,
            debug.last_text_paint.cell_w,
            debug.last_text_paint.cell_h,
            debug.last_text_paint.glyph.x,
            debug.last_text_paint.glyph.y,
            debug.last_text_paint.glyph.width,
            debug.last_text_paint.glyph.height,
            debug.last_text_paint.baseline,
            debug.last_text_paint.render_scale,
        },
    );
    try out.writer(widget.session.allocator).print(
        "metal_terminal_fallback valid={d} generation={d} grid_row_runs={d} grid_row_cells={d} overlay_row_runs={d} overlay_row_cells={d}\n",
        .{
            @intFromBool(debug.last_metal_terminal_fallback.valid),
            debug.last_metal_terminal_fallback.generation,
            debug.last_metal_terminal_fallback.grid_row_runs,
            debug.last_metal_terminal_fallback.grid_row_cells,
            debug.last_metal_terminal_fallback.overlay_row_runs,
            debug.last_metal_terminal_fallback.overlay_row_cells,
        },
    );
    if (debug.last_cursor_overlay.valid and debug.last_text_paint.valid) {
        try out.writer(widget.session.allocator).print(
            "cursor_vs_text delta_cell_origin=({d:.3},{d:.3}) delta_overlay_to_glyph=({d:.3},{d:.3},{d:.3},{d:.3})\n",
            .{
                debug.last_cursor_overlay.cell_x - debug.last_text_paint.cell_x,
                debug.last_cursor_overlay.cell_y - debug.last_text_paint.cell_y,
                debug.last_cursor_overlay.cursor_x - debug.last_text_paint.glyph.x,
                debug.last_cursor_overlay.cursor_y - debug.last_text_paint.glyph.y,
                debug.last_cursor_overlay.cursor_w - debug.last_text_paint.glyph.width,
                debug.last_cursor_overlay.cursor_h - debug.last_text_paint.glyph.height,
            },
        );
    }
    if (debug.last_surface_present.valid and debug.last_view_geometry.valid) {
        try out.writer(widget.session.allocator).print(
            "surface_vs_view delta_target_minus_view=({d:.3},{d:.3}) delta_source_minus_view=({d:.3},{d:.3})\n",
            .{
                debug.last_surface_present.target_logical_w - debug.last_view_geometry.viewport_w,
                debug.last_surface_present.target_logical_h - debug.last_view_geometry.viewport_h,
                debug.last_surface_present.source_logical_w - debug.last_view_geometry.viewport_w,
                debug.last_surface_present.source_logical_h - debug.last_view_geometry.viewport_h,
            },
        );
    }

    try appendViewportColumnRuler(&out, widget.session.allocator, dump_info.cols);
    try out.append(widget.session.allocator, '\n');

    if (terminal_view.rows == 0 or terminal_view.cols == 0 or terminal_view.cells.len == 0) {
        try out.appendSlice(widget.session.allocator, "# empty draw cache\n");
    } else {
        var row: usize = 0;
        while (row < terminal_view.rows) : (row += 1) {
            try out.writer(widget.session.allocator).print("{d:0>3}|", .{row});
            try appendViewportAsciiRow(&out, widget.session.allocator, terminal_view, row);
            try out.appendSlice(widget.session.allocator, "|\n");
        }
    }

    try out.appendSlice(widget.session.allocator, "\n# resolved_bg_runs\n");
    if (terminal_view.rows == 0 or terminal_view.cols == 0 or terminal_view.cells.len == 0) {
        try out.appendSlice(widget.session.allocator, "none\n");
    } else {
        var row: usize = 0;
        while (row < terminal_view.rows) : (row += 1) {
            try appendResolvedBackgroundRuns(&out, widget.session.allocator, terminal_view, row);
        }
    }

    try out.appendSlice(widget.session.allocator, "\n# non_ascii_cells\n");
    var listed_non_ascii = false;
    if (terminal_view.rows > 0 and terminal_view.cols > 0 and terminal_view.cells.len > 0) {
        var row: usize = 0;
        while (row < terminal_view.rows) : (row += 1) {
            var col: usize = 0;
            while (col < terminal_view.cols) : (col += 1) {
                const idx = row * terminal_view.cols + col;
                if (idx >= terminal_view.cells.len) break;
                const cell = terminal_view.cells[idx];
                if (cell.x != 0 or cell.y != 0) continue;
                if (cell.codepoint == 0) continue;
                if (cell.codepoint >= 32 and cell.codepoint <= 126 and cell.combining_len == 0 and cell.width <= 1) continue;
                listed_non_ascii = true;
                try out.writer(widget.session.allocator).print(
                    "row={d} col={d} cp={d} width={d} combining={d}\n",
                    .{ row, col, cell.codepoint, cell.width, cell.combining_len },
                );
            }
        }
    }
    if (!listed_non_ascii) {
        try out.appendSlice(widget.session.allocator, "none\n");
    }

    try std.fs.cwd().writeFile(.{
        .sub_path = visible_ascii_dump_path,
        .data = out.items,
    });

    log.logf(.info, "visible_ascii_dump path={s} rows={d} cols={d} alt_active={d} generation={d} cursor_overlay={d} text_paint={d}", .{
        visible_ascii_dump_path,
        terminal_view.rows,
        terminal_view.cols,
        @intFromBool(terminal_view.alt_active),
        terminal_view.generation,
        @intFromBool(debug.last_cursor_overlay.valid),
        @intFromBool(debug.last_text_paint.valid),
    });
    log.logf(
        .info,
        "visible_ascii_dump geometry ui_scale={d:.3} render_scale={d:.3} cursor=({d:.3},{d:.3},{d:.3},{d:.3}) text=({d:.3},{d:.3},{d:.3},{d:.3}) surface=({d:.3}->{d:.3} scale={d:.6}) source={s} covers_cursor={d} cursor_distance_cols={d}",
        .{
            shell.uiScaleFactor(),
            1.0 / shell.rendererPtr().devicePixelStep(),
            debug.last_cursor_overlay.cursor_x,
            debug.last_cursor_overlay.cursor_y,
            debug.last_cursor_overlay.cursor_w,
            debug.last_cursor_overlay.cursor_h,
            debug.last_text_paint.glyph.x,
            debug.last_text_paint.glyph.y,
            debug.last_text_paint.glyph.width,
            debug.last_text_paint.glyph.height,
            debug.last_surface_present.target_logical_w,
            debug.last_surface_present.dest_w,
            debug.last_surface_present.scale_x,
            @tagName(debug.last_text_paint.source),
            @intFromBool(debug.last_text_paint.covers_cursor),
            debug.last_text_paint.cursor_distance_cols,
        },
    );
}

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
    terminal_view: view_state.TerminalViewModel,
    row: usize,
) !void {
    if (terminal_view.cols == 0 or row >= terminal_view.rows) return;
    const row_start = row * terminal_view.cols;
    var col: usize = 0;
    while (col < terminal_view.cols) : (col += 1) {
        const idx = row_start + col;
        if (idx >= terminal_view.cells.len) break;
        try out.append(allocator, viewportAsciiChar(terminal_view.cells[idx]));
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
    terminal_view: view_state.TerminalViewModel,
    row: usize,
) !void {
    if (terminal_view.cols == 0 or row >= terminal_view.rows) {
        try out.writer(allocator).print("row={d:0>3} cursor_here=0 cursor_col=-1 runs=none\n", .{row});
        return;
    }

    const row_start = row * terminal_view.cols;
    if (row_start >= terminal_view.cells.len) {
        try out.writer(allocator).print("row={d:0>3} cursor_here=0 cursor_col=-1 runs=none\n", .{row});
        return;
    }

    const run_info = terminal_view.backgroundRunInfo(row);
    try out.writer(allocator).print(
        "row={d:0>3} cursor_here={d} cursor_col={d} runs=",
        .{
            row,
            @intFromBool(run_info.cursor_here),
            if (run_info.cursor_col) |cursor_col| @as(i64, @intCast(cursor_col)) else -1,
        },
    );

    var col: usize = 0;
    while (col < terminal_view.cols) {
        const idx = row_start + col;
        if (idx >= terminal_view.cells.len) break;
        const run_color = resolvedBackgroundColor(terminal_view.cells[idx], run_info.screen_reverse);
        var end_col = col;
        while (end_col + 1 < terminal_view.cols) : (end_col += 1) {
            const next_idx = row_start + end_col + 1;
            if (next_idx >= terminal_view.cells.len) break;
            const next_color = resolvedBackgroundColor(terminal_view.cells[next_idx], run_info.screen_reverse);
            if (!sameColor(run_color, next_color)) break;
        }
        try out.writer(allocator).print(
            "{d}..{d}@{d}:{d}:{d}",
            .{ col, end_col, run_color.r, run_color.g, run_color.b },
        );
        col = end_col + 1;
        if (col < terminal_view.cols) try out.appendSlice(allocator, " ");
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
