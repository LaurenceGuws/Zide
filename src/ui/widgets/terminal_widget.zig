const std = @import("std");
const builtin = @import("builtin");
const app_shell = @import("../../app_shell.zig");
const terminal_mod = @import("../../terminal/core/terminal.zig");
const app_logger = @import("../../app_logger.zig");
const shared_types = @import("../../types/mod.zig");
const gl = @import("../renderer/gl.zig");
const types = @import("../renderer/types.zig");
const image_decode = @import("../image_decode.zig");

const Shell = app_shell.Shell;
const Color = app_shell.Color;
const TerminalSession = terminal_mod.TerminalSession;
const CursorPos = terminal_mod.CursorPos;
const Cell = terminal_mod.Cell;
const KittyImage = terminal_mod.KittyImage;
const KittyPlacement = terminal_mod.KittyPlacement;

const KittyTexture = struct {
    texture: types.Texture,
    width: i32,
    height: i32,
    version: u64,
};

/// Terminal widget for drawing a terminal view
pub const TerminalWidget = struct {
    session: *TerminalSession,
    last_scroll_offset: usize = 0,
    kitty_images_view: std.ArrayList(KittyImage),
    kitty_placements_view: std.ArrayList(KittyPlacement),
    kitty_textures: std.AutoHashMap(u32, KittyTexture),
    last_kitty_generation: u64 = 0,
    last_hover_link_id: u32 = 0,
    last_hover_row: isize = -1,
    last_hover_col: isize = -1,
    last_hover_ctrl: bool = false,
    hover_dirty: bool = false,
    pending_open_path: ?[]u8 = null,

    pub fn init(session: *TerminalSession) TerminalWidget {
        return .{
            .session = session,
            .last_scroll_offset = 0,
            .kitty_images_view = .empty,
            .kitty_placements_view = .empty,
            .kitty_textures = std.AutoHashMap(u32, KittyTexture).init(session.allocator),
            .last_kitty_generation = 0,
            .last_hover_link_id = 0,
            .last_hover_row = -1,
            .last_hover_col = -1,
            .last_hover_ctrl = false,
            .pending_open_path = null,
        };
    }

    pub fn deinit(self: *TerminalWidget) void {
        if (self.pending_open_path) |path| {
            self.session.allocator.free(path);
            self.pending_open_path = null;
        }
        var it = self.kitty_textures.iterator();
        while (it.next()) |entry| {
            if (entry.value_ptr.texture.id != 0) {
                gl.DeleteTextures(1, &entry.value_ptr.texture.id);
            }
        }
        self.kitty_textures.deinit();
        self.kitty_images_view.deinit(self.session.allocator);
        self.kitty_placements_view.deinit(self.session.allocator);
    }

    pub fn takePendingOpenPath(self: *TerminalWidget) ?[]u8 {
        const value = self.pending_open_path;
        self.pending_open_path = null;
        return value;
    }

    fn decodePercent(allocator: std.mem.Allocator, text: []const u8) ?[]u8 {
        if (text.len == 0) return allocator.dupe(u8, "") catch null;
        var out = std.ArrayList(u8).empty;
        errdefer out.deinit(allocator);
        var i: usize = 0;
        while (i < text.len) : (i += 1) {
            const b = text[i];
            if (b == '%' and i + 2 < text.len) {
                const hi = std.fmt.charToDigit(text[i + 1], 16) catch return null;
                const lo = std.fmt.charToDigit(text[i + 2], 16) catch return null;
                _ = out.append(allocator, @as(u8, (hi << 4) | lo)) catch return null;
                i += 2;
                continue;
            }
            _ = out.append(allocator, b) catch return null;
        }
        return out.toOwnedSlice(allocator) catch null;
    }

    fn resolveLinkPath(self: *TerminalWidget, uri: []const u8) ?[]u8 {
        if (uri.len == 0) return null;
        const allocator = self.session.allocator;
        if (std.mem.startsWith(u8, uri, "file://")) {
            var rest = uri["file://".len..];
            if (rest.len == 0) return null;
            if (rest[0] != '/') {
                if (std.mem.indexOfScalar(u8, rest, '/')) |slash| {
                    const host = rest[0..slash];
                    if (!(host.len == 0 or std.mem.eql(u8, host, "localhost"))) return null;
                    rest = rest[slash..];
                } else {
                    return null;
                }
            }
            return decodePercent(allocator, rest);
        }
        if (uri[0] == '/') {
            return allocator.dupe(u8, uri) catch null;
        }
        const cwd = self.session.currentCwd();
        if (cwd.len == 0) return null;
        return std.fs.path.join(allocator, &.{ cwd, uri }) catch null;
    }

    fn linkIdAtCell(
        self: *TerminalWidget,
        snapshot: terminal_mod.TerminalSnapshot,
        history_len: usize,
        start_line: usize,
        rows: usize,
        cols: usize,
        row: usize,
        col: usize,
    ) u32 {
        if (rows == 0 or cols == 0) return 0;
        if (row >= rows or col >= cols) return 0;
        const global_row = start_line + row;
        if (global_row < history_len) {
            if (self.session.scrollbackRow(global_row)) |history_row| {
                return history_row[col].attrs.link_id;
            }
            return 0;
        }
        const grid_row = global_row - history_len;
        if (grid_row < rows and snapshot.cells.len >= rows * cols) {
            return snapshot.cells[grid_row * cols + col].attrs.link_id;
        }
        return 0;
    }

    pub fn updateHoverState(
        self: *TerminalWidget,
        x: f32,
        y: f32,
        width: f32,
        height: f32,
        cell_width: f32,
        cell_height: f32,
        snapshot: terminal_mod.TerminalSnapshot,
        history_len: usize,
        start_line: usize,
        input_batch: *shared_types.input.InputBatch,
    ) void {
        const rows = snapshot.rows;
        const cols = snapshot.cols;
        const mouse = input_batch.mouse_pos;
        const ctrl = input_batch.mods.ctrl;
        const scrollbar_w: f32 = 10;
        const scrollbar_x = x + width - scrollbar_w;
        var hover_row: isize = -1;
        var hover_col: isize = -1;
        var hover_link_id: u32 = 0;
        if (rows > 0 and cols > 0) {
            const in_terminal = mouse.x >= x and mouse.x <= x + width and mouse.y >= y and mouse.y <= y + height;
            const in_cells = in_terminal and mouse.x < scrollbar_x;
            if (in_cells) {
                const base_x = @as(f32, @floatFromInt(@as(i32, @intFromFloat(std.math.round(x)))));
                const base_y = @as(f32, @floatFromInt(@as(i32, @intFromFloat(std.math.round(y)))));
                const col = @as(usize, @intFromFloat((mouse.x - base_x) / cell_width));
                const row = @as(usize, @intFromFloat((mouse.y - base_y) / cell_height));
                if (row < rows and col < cols) {
                    hover_row = @intCast(row);
                    hover_col = @intCast(col);
                    if (ctrl) {
                        hover_link_id = self.linkIdAtCell(
                            snapshot,
                            history_len,
                            start_line,
                            rows,
                            cols,
                            row,
                            col,
                        );
                    }
                }
            }
        }
        const hover_changed = ctrl != self.last_hover_ctrl or
            hover_link_id != self.last_hover_link_id or
            hover_row != self.last_hover_row or
            hover_col != self.last_hover_col;
        if (hover_changed) {
            const log = app_logger.logger("terminal.hover");
            log.logf("ctrl={any} row={d} col={d} link={d}", .{ ctrl, hover_row, hover_col, hover_link_id });
            self.hover_dirty = true;
        }
        self.last_hover_ctrl = ctrl;
        self.last_hover_link_id = hover_link_id;
        self.last_hover_row = hover_row;
        self.last_hover_col = hover_col;
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
        _ = input;
        const r = shell.rendererPtr();
        if (!self.session.tryLock()) {
            r.drawRect(
                @intFromFloat(x),
                @intFromFloat(y),
                @intFromFloat(width),
                @intFromFloat(height),
                r.theme.background,
            );
            r.drawTerminalTexture(x, y);
            return;
        }
        const sync_updates = self.session.syncUpdatesActive();
        if (sync_updates and self.session.view_cells.items.len > 0) {
            const view_cells = self.session.view_cells.items;
            const bg_color = if (view_cells.len > 0) Color{
                .r = view_cells[0].attrs.bg.r,
                .g = view_cells[0].attrs.bg.g,
                .b = view_cells[0].attrs.bg.b,
            } else r.theme.background;
            self.session.unlock();
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
        const snapshot = self.session.snapshot();
        const alt_exit = self.session.alt_last_active and !snapshot.alt_active;
        self.session.alt_last_active = snapshot.alt_active;
        const draw_start_time = if (alt_exit) app_shell.getTime() else 0;
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
        const draw_cursor = scroll_offset == 0 and snapshot.cursor_visible;
        const cursor = if (draw_cursor) snapshot.cursor else CursorPos{ .row = rows + 1, .col = cols + 1 };
        const cursor_style = snapshot.cursor_style;
        const selection = self.session.selectionState();
        const kitty_generation = snapshot.kitty_generation;

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

            _ = self.kitty_images_view.resize(self.session.allocator, snapshot.kitty_images.len) catch {};
            std.mem.copyForwards(KittyImage, self.kitty_images_view.items, snapshot.kitty_images);
            _ = self.kitty_placements_view.resize(self.session.allocator, snapshot.kitty_placements.len) catch {};
            std.mem.copyForwards(KittyPlacement, self.kitty_placements_view.items, snapshot.kitty_placements);
            if (self.kitty_placements_view.items.len > 1) {
                sortKittyPlacements(self.kitty_placements_view.items);
            }
        } else {
            self.session.view_cells.clearRetainingCapacity();
            self.session.view_dirty_rows.clearRetainingCapacity();
            self.session.view_dirty_cols_start.clearRetainingCapacity();
            self.session.view_dirty_cols_end.clearRetainingCapacity();
            self.kitty_images_view.clearRetainingCapacity();
            self.kitty_placements_view.clearRetainingCapacity();
        }
        self.session.unlock();

        const view_cells = self.session.view_cells.items;
        const view_dirty_rows = self.session.view_dirty_rows.items;
        const has_kitty = self.kitty_images_view.items.len > 0 and self.kitty_placements_view.items.len > 0;
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
        const hover_changed = self.hover_dirty;
        self.hover_dirty = false;
        const hover_link_id = if (self.last_hover_ctrl) self.last_hover_link_id else 0;

        const rowSlice = struct {
            fn get(cells: []const Cell, cols_count: usize, row: usize) []const Cell {
                const row_start = row * cols_count;
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
            ) void {
                const rr = renderer.rendererPtr();
                const cell_w_i: i32 = @intFromFloat(std.math.round(rr.terminal_cell_width));
                const cell_h_i: i32 = @intFromFloat(std.math.round(rr.terminal_cell_height));
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
                        fg = rr.theme.link;
                    }

                    rr.addTerminalRect(
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
                    rr.addTerminalRect(
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
            ) void {
                _ = padding_x_i;
                const rr = renderer.rendererPtr();
                const cell_w_i: i32 = @intFromFloat(std.math.round(rr.terminal_cell_width));
                const cell_h_i: i32 = @intFromFloat(std.math.round(rr.terminal_cell_height));
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

                    const followed_by_space = blk: {
                        const next_col = col + cell_width_units;
                        if (next_col < cols_count) {
                            const next_cell = row_cells[next_col];
                            break :blk next_cell.codepoint == ' ' or next_cell.codepoint == 0;
                        }
                        break :blk true;
                    };

                    rr.drawTerminalCellBatched(
                        cell.codepoint,
                        @as(f32, @floatFromInt(cell_x_i)),
                        @as(f32, @floatFromInt(cell_y_i)),
                        @as(f32, @floatFromInt(cell_w_i * @as(i32, @intCast(cell_width_units)))),
                        @as(f32, @floatFromInt(cell_h_i)),
                        if (cell.attrs.reverse) bg else fg,
                        if (cell.attrs.reverse) fg else bg,
                        underline_color,
                        cell.attrs.bold,
                        underline,
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
            const kitty_changed = kitty_generation != self.last_kitty_generation;
            const needs_full = recreated or snapshot.alt_active or snapshot.dirty == .full or scroll_changed or (snapshot.dirty != .none and scroll_offset > 0) or has_kitty or kitty_changed or hover_changed;
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
                    r.beginTerminalBatch();
                    r.addTerminalRect(0, 0, texture_w, texture_h, bg);
                    var row: usize = 0;
                    while (row < rows) : (row += 1) {
                        drawRowBackgrounds(shell, view_cells, cols, row, 0, cols - 1, base_x_local, base_y_local, padding_x_i);
                    }
                    r.flushTerminalBatch();
                    if (has_kitty) {
                        self.cleanupKittyTextures(self.kitty_images_view.items);
                        self.drawKittyImages(shell, base_x_local, base_y_local, false, start_line, rows, cols);
                    }
                    r.beginTerminalBatch();
                    row = 0;
                    while (row < rows) : (row += 1) {
                        drawRowGlyphs(shell, view_cells, cols, row, 0, cols - 1, base_x_local, base_y_local, padding_x_i, hover_link_id);
                    }
                    r.flushTerminalBatch();
                    if (has_kitty) {
                        self.drawKittyImages(shell, base_x_local, base_y_local, true, start_line, rows, cols);
                    }
                } else if (needs_partial) {
                    r.beginTerminalBatch();
                    var row: usize = 0;
                    while (row < rows) : (row += 1) {
                        if (row < view_dirty_rows.len and view_dirty_rows[row]) {
                            var draw_start: usize = 0;
                            var draw_end: usize = cols - 1;
                            if (row < self.session.view_dirty_cols_start.items.len and row < self.session.view_dirty_cols_end.items.len) {
                                draw_start = @min(@as(usize, self.session.view_dirty_cols_start.items[row]), cols - 1);
                                draw_end = @min(@as(usize, self.session.view_dirty_cols_end.items[row]), cols - 1);
                            }
                            drawRowBackgrounds(shell, view_cells, cols, row, draw_start, draw_end, base_x_local, base_y_local, padding_x_i);
                            if (row > 0) {
                                drawRowBackgrounds(shell, view_cells, cols, row - 1, draw_start, draw_end, base_x_local, base_y_local, padding_x_i);
                            }
                            if (row + 1 < rows) {
                                drawRowBackgrounds(shell, view_cells, cols, row + 1, draw_start, draw_end, base_x_local, base_y_local, padding_x_i);
                            }
                        }
                    }
                    r.flushTerminalBatch();
                    r.beginTerminalBatch();
                    row = 0;
                    while (row < rows) : (row += 1) {
                        if (row < view_dirty_rows.len and view_dirty_rows[row]) {
                            var draw_start: usize = 0;
                            var draw_end: usize = cols - 1;
                            if (row < self.session.view_dirty_cols_start.items.len and row < self.session.view_dirty_cols_end.items.len) {
                                draw_start = @min(@as(usize, self.session.view_dirty_cols_start.items[row]), cols - 1);
                                draw_end = @min(@as(usize, self.session.view_dirty_cols_end.items[row]), cols - 1);
                            }
                            drawRowGlyphs(shell, view_cells, cols, row, draw_start, draw_end, base_x_local, base_y_local, padding_x_i, hover_link_id);
                            if (row > 0) {
                                drawRowGlyphs(shell, view_cells, cols, row - 1, draw_start, draw_end, base_x_local, base_y_local, padding_x_i, hover_link_id);
                            }
                            if (row + 1 < rows) {
                                drawRowGlyphs(shell, view_cells, cols, row + 1, draw_start, draw_end, base_x_local, base_y_local, padding_x_i, hover_link_id);
                            }
                        }
                    }
                    r.flushTerminalBatch();
                }
                r.endTerminalTexture();
                if (kitty_changed) {
                    self.last_kitty_generation = kitty_generation;
                }
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
        if (!has_kitty and self.kitty_textures.count() > 0) {
            self.cleanupKittyTextures(self.kitty_images_view.items);
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
                    r.drawTerminalCell(
                        cell.codepoint,
                        cell_x,
                        cell_y,
                        @as(f32, @floatFromInt(cursor_w_i)),
                        @as(f32, @floatFromInt(cell_h_i)),
                        if (cell.attrs.reverse) bg else fg,
                        if (cell.attrs.reverse) fg else bg,
                        underline_color,
                        cell.attrs.bold,
                        underline,
                        true,
                        followed_by_space,
                        true,
                    );
                },
                .underline => {
                    r.drawRect(cell_x_i, cell_y_i + cell_h_i - 2, cursor_w_i, 2, r.theme.cursor);
                },
                .bar => {
                    r.drawRect(cell_x_i, cell_y_i, 2, cell_h_i, r.theme.cursor);
                },
            }
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

        if (!sync_updates and (updated or snapshot.dirty == .none)) {
            if (self.session.tryLock()) {
                const current_gen = self.session.currentGeneration();
                if (current_gen == snapshot.generation) {
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
    }

    fn sortKittyPlacements(placements: []KittyPlacement) void {
        std.sort.heap(KittyPlacement, placements, {}, struct {
            fn lessThan(_: void, a: KittyPlacement, b: KittyPlacement) bool {
                if (a.z == b.z) {
                    if (a.row == b.row) return a.col < b.col;
                    return a.row < b.row;
                }
                return a.z < b.z;
            }
        }.lessThan);
    }

    fn cleanupKittyTextures(self: *TerminalWidget, images: []const KittyImage) void {
        var stale = std.ArrayList(u32).empty;
        defer stale.deinit(self.session.allocator);
        var it = self.kitty_textures.iterator();
        while (it.next()) |entry| {
            var found = false;
            for (images) |img| {
                if (img.id == entry.key_ptr.*) {
                    found = true;
                    break;
                }
            }
            if (!found) {
                _ = stale.append(self.session.allocator, entry.key_ptr.*) catch {};
            }
        }
        for (stale.items) |id| {
            if (self.kitty_textures.fetchRemove(id)) |entry| {
                if (entry.value.texture.id != 0) {
                    gl.DeleteTextures(1, &entry.value.texture.id);
                }
            }
        }
    }

    fn drawKittyImages(
        self: *TerminalWidget,
        shell: *Shell,
        base_x: f32,
        base_y: f32,
        above_text: bool,
        start_line: usize,
        rows: usize,
        cols: usize,
    ) void {
        const r = shell.rendererPtr();
        const cell_w: f32 = r.terminal_cell_width;
        const cell_h: f32 = r.terminal_cell_height;
        const start_line_i: i32 = @intCast(start_line);
        const rows_i: i32 = @intCast(rows);
        const cols_i: i32 = @intCast(cols);

        for (self.kitty_placements_view.items) |placement| {
            if (placement.is_virtual) continue;
            if (above_text) {
                if (placement.z < 0) continue;
            } else {
                if (placement.z >= 0) continue;
            }
            const image = findKittyImage(self.kitty_images_view.items, placement.image_id) orelse continue;
            const tex = self.ensureKittyTexture(shell, image) orelse continue;

            const col_i: i32 = @as(i32, @intCast(placement.col));
            if (col_i < 0 or col_i >= cols_i) continue;
            const row_i: i32 = @as(i32, @intCast(placement.row)) - start_line_i;

            const draw_w = if (placement.cols > 0) cell_w * @as(f32, @floatFromInt(placement.cols)) else @as(f32, @floatFromInt(tex.width));
            const draw_h = if (placement.rows > 0) cell_h * @as(f32, @floatFromInt(placement.rows)) else @as(f32, @floatFromInt(tex.height));

            const row_span: i32 = if (placement.rows > 0)
                @as(i32, @intCast(placement.rows))
            else
                @as(i32, @intCast(@max(@as(i32, 1), @as(i32, @intFromFloat(@ceil(draw_h / cell_h))))));
            if (row_i >= rows_i or row_i + row_span <= 0) continue;

            const x = base_x + @as(f32, @floatFromInt(col_i)) * cell_w;
            const y = base_y + @as(f32, @floatFromInt(row_i)) * cell_h;

            const dest = types.Rect{ .x = x, .y = y, .width = draw_w, .height = draw_h };
            const src = types.Rect{
                .x = 0,
                .y = 0,
                .width = @as(f32, @floatFromInt(tex.texture.width)),
                .height = @as(f32, @floatFromInt(tex.texture.height)),
            };
            r.drawTexture(tex.texture, src, dest, Color.white);
        }
    }

    fn findKittyImage(images: []const KittyImage, image_id: u32) ?KittyImage {
        for (images) |img| {
            if (img.id == image_id) return img;
        }
        return null;
    }

    fn ensureKittyTexture(self: *TerminalWidget, shell: *Shell, image: KittyImage) ?KittyTexture {
        if (self.kitty_textures.getEntry(image.id)) |entry| {
            if (entry.value_ptr.version == image.version) return entry.value_ptr.*;
            if (entry.value_ptr.texture.id != 0) {
                gl.DeleteTextures(1, &entry.value_ptr.texture.id);
            }
            _ = self.kitty_textures.remove(image.id);
        }

        const texture = loadKittyTexture(shell.rendererPtr(), image) orelse {
            const log = app_logger.logger("terminal.kitty");
            if (log.enabled_file or log.enabled_console) {
                log.logf("kitty texture load failed id={d} format={s} bytes={d}", .{ image.id, @tagName(image.format), image.data.len });
            }
            return null;
        };
        const stored = KittyTexture{
            .texture = texture,
            .width = texture.width,
            .height = texture.height,
            .version = image.version,
        };
        _ = self.kitty_textures.put(image.id, stored) catch {};
        const log = app_logger.logger("terminal.kitty");
        if (log.enabled_file or log.enabled_console) {
            log.logf("kitty texture ok id={d} w={d} h={d}", .{ image.id, texture.width, texture.height });
        }
        return stored;
    }

    fn loadKittyTexture(renderer: anytype, image: KittyImage) ?types.Texture {
        switch (image.format) {
            .png => {
                const decoded = image_decode.decodePngRgba(renderer.allocator, image.data) catch return null;
                defer renderer.allocator.free(decoded.data);
                return renderer.createTextureFromRgba(@intCast(decoded.width), @intCast(decoded.height), decoded.data, gl.c.GL_LINEAR);
            },
            .rgba => {
                if (image.width == 0 or image.height == 0) return null;
                return renderer.createTextureFromRgba(@intCast(image.width), @intCast(image.height), image.data, gl.c.GL_LINEAR);
            },
        }
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
        input_batch: *shared_types.input.InputBatch,
    ) !bool {
        if (!self.session.tryLock()) return false;
        defer self.session.unlock();
        var handled = false;
        const mouse = input_batch.mouse_pos;
        const in_terminal = mouse.x >= x and mouse.x <= x + width and mouse.y >= y and mouse.y <= y + height;
        const scrollbar_w: f32 = 10;
        const scrollbar_x = x + width - scrollbar_w;
        const scrollbar_y = y;
        const scrollbar_h = height;

        const history_len = self.session.scrollbackCount();
        const snapshot = self.session.snapshot();
        const rows = snapshot.rows;
        const cols = snapshot.cols;
        const total_lines = history_len + rows;
        const scroll_offset = self.session.scrollOffset();
        const end_line = total_lines - scroll_offset;
        const start_line = if (end_line > rows) end_line - rows else 0;
        const max_scroll_offset = if (total_lines > rows) total_lines - rows else 0;

        const r = shell.rendererPtr();
        self.updateHoverState(
            x,
            y,
            width,
            height,
            r.terminal_cell_width,
            r.terminal_cell_height,
            snapshot,
            history_len,
            start_line,
            input_batch,
        );

        const ctrl = input_batch.mods.ctrl;
        const shift = input_batch.mods.shift;
        const alt = input_batch.mods.alt;
        const super = input_batch.mods.super;
        var mod: terminal_mod.Modifier = terminal_mod.VTERM_MOD_NONE;
        if (shift) mod |= terminal_mod.VTERM_MOD_SHIFT;
        if (alt) mod |= terminal_mod.VTERM_MOD_ALT;
        if (ctrl) mod |= terminal_mod.VTERM_MOD_CTRL;

        const wheel_delta = if (in_terminal) input_batch.scroll.y else 0;
        var wheel_steps: i32 = 0;
        if (wheel_delta != 0) {
            const abs_delta = @abs(wheel_delta);
            const rounded: i32 = @intFromFloat(@round(abs_delta));
            wheel_steps = if (rounded > 0) rounded else 1;
            if (wheel_delta < 0) wheel_steps = -wheel_steps;
        }
        const mouse_reporting = allow_input and in_terminal and self.session.mouseReportingEnabled();
        var skip_mouse_click = false;
        if (allow_input and in_terminal and ctrl and input_batch.mousePressed(.left)) {
            if (rows > 0 and cols > 0 and snapshot.cells.len >= rows * cols) {
                const col = @as(usize, @intFromFloat((mouse.x - x) / shell.terminalCellWidth()));
                const row = @as(usize, @intFromFloat((mouse.y - y) / shell.terminalCellHeight()));
                if (row < rows and col < cols) {
                    const link_id = self.linkIdAtCell(snapshot, history_len, start_line, rows, cols, row, col);
                    if (link_id != 0) {
                        if (self.session.hyperlinkUri(link_id)) |link| {
                            if (self.resolveLinkPath(link)) |path| {
                                if (self.pending_open_path) |old| {
                                    self.session.allocator.free(old);
                                }
                                self.pending_open_path = path;
                                handled = true;
                                skip_mouse_click = true;
                            }
                        }
                    }
                }
            }
        }

        if (self.session.takeOscClipboard()) |clip| {
            const cstr: [*:0]const u8 = @ptrCast(clip.ptr);
            shell.setClipboardText(cstr);
            handled = true;
        }

        if (mouse_reporting and rows > 0 and cols > 0) {
            const mouse_left_down = input_batch.mouseDown(.left);
            const mouse_middle_down = input_batch.mouseDown(.middle);
            const mouse_right_down = input_batch.mouseDown(.right);
            var buttons_down: u8 = 0;
            if (mouse_left_down) buttons_down |= 1;
            if (mouse_middle_down) buttons_down |= 2;
            if (mouse_right_down) buttons_down |= 4;

            var col: usize = 0;
            if (mouse.x > x) {
                col = @as(usize, @intFromFloat((mouse.x - x) / shell.terminalCellWidth()));
            }
            var row: usize = 0;
            if (mouse.y > y) {
                row = @as(usize, @intFromFloat((mouse.y - y) / shell.terminalCellHeight()));
            }
            row = @min(row, rows - 1);
            col = @min(col, cols - 1);

            if (wheel_steps != 0) {
                var remaining = wheel_steps;
                while (remaining != 0) {
                    const button: terminal_mod.MouseButton = if (remaining > 0) .wheel_up else .wheel_down;
                    if (try self.session.reportMouseEvent(.{ .kind = .wheel, .button = button, .row = row, .col = col, .mod = mod, .buttons_down = buttons_down })) {
                        handled = true;
                    }
                    remaining += if (remaining > 0) -1 else 1;
                }
            }

            if (input_batch.mousePressed(.left) and !skip_mouse_click) {
                if (try self.session.reportMouseEvent(.{ .kind = .press, .button = .left, .row = row, .col = col, .mod = mod, .buttons_down = buttons_down })) {
                    handled = true;
                }
            }
            if (input_batch.mousePressed(.middle)) {
                if (try self.session.reportMouseEvent(.{ .kind = .press, .button = .middle, .row = row, .col = col, .mod = mod, .buttons_down = buttons_down })) {
                    handled = true;
                }
            }
            if (input_batch.mousePressed(.right)) {
                if (try self.session.reportMouseEvent(.{ .kind = .press, .button = .right, .row = row, .col = col, .mod = mod, .buttons_down = buttons_down })) {
                    handled = true;
                }
            }

            if (input_batch.mouseReleased(.left)) {
                if (try self.session.reportMouseEvent(.{ .kind = .release, .button = .left, .row = row, .col = col, .mod = mod, .buttons_down = buttons_down })) {
                    handled = true;
                }
            }
            if (input_batch.mouseReleased(.middle)) {
                if (try self.session.reportMouseEvent(.{ .kind = .release, .button = .middle, .row = row, .col = col, .mod = mod, .buttons_down = buttons_down })) {
                    handled = true;
                }
            }
            if (input_batch.mouseReleased(.right)) {
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
            const applyTerminalKey = struct {
                fn apply(widget: *TerminalWidget, key: shared_types.input.Key, key_mod: terminal_mod.Modifier) !bool {
                    switch (key) {
                        .enter => {
                            try widget.session.sendKey(terminal_mod.VTERM_KEY_ENTER, key_mod);
                            return true;
                        },
                        .backspace => {
                            try widget.session.sendKey(terminal_mod.VTERM_KEY_BACKSPACE, key_mod);
                            return true;
                        },
                        .tab => {
                            try widget.session.sendKey(terminal_mod.VTERM_KEY_TAB, key_mod);
                            return true;
                        },
                        .escape => {
                            try widget.session.sendKey(terminal_mod.VTERM_KEY_ESCAPE, key_mod);
                            return true;
                        },
                        .up => {
                            try widget.session.sendKey(terminal_mod.VTERM_KEY_UP, key_mod);
                            return true;
                        },
                        .down => {
                            try widget.session.sendKey(terminal_mod.VTERM_KEY_DOWN, key_mod);
                            return true;
                        },
                        .left => {
                            try widget.session.sendKey(terminal_mod.VTERM_KEY_LEFT, key_mod);
                            return true;
                        },
                        .right => {
                            try widget.session.sendKey(terminal_mod.VTERM_KEY_RIGHT, key_mod);
                            return true;
                        },
                        .home => {
                            try widget.session.sendKey(terminal_mod.VTERM_KEY_HOME, key_mod);
                            return true;
                        },
                        .end => {
                            try widget.session.sendKey(terminal_mod.VTERM_KEY_END, key_mod);
                            return true;
                        },
                        .page_up => {
                            try widget.session.sendKey(terminal_mod.VTERM_KEY_PAGEUP, key_mod);
                            return true;
                        },
                        .page_down => {
                            try widget.session.sendKey(terminal_mod.VTERM_KEY_PAGEDOWN, key_mod);
                            return true;
                        },
                        .insert => {
                            try widget.session.sendKey(terminal_mod.VTERM_KEY_INS, key_mod);
                            return true;
                        },
                        .delete => {
                            try widget.session.sendKey(terminal_mod.VTERM_KEY_DEL, key_mod);
                            return true;
                        },
                        .kp_0 => {
                            try widget.session.sendKeypad(terminal_mod.KeypadKey.kp0, key_mod);
                            return true;
                        },
                        .kp_1 => {
                            try widget.session.sendKeypad(terminal_mod.KeypadKey.kp1, key_mod);
                            return true;
                        },
                        .kp_2 => {
                            try widget.session.sendKeypad(terminal_mod.KeypadKey.kp2, key_mod);
                            return true;
                        },
                        .kp_3 => {
                            try widget.session.sendKeypad(terminal_mod.KeypadKey.kp3, key_mod);
                            return true;
                        },
                        .kp_4 => {
                            try widget.session.sendKeypad(terminal_mod.KeypadKey.kp4, key_mod);
                            return true;
                        },
                        .kp_5 => {
                            try widget.session.sendKeypad(terminal_mod.KeypadKey.kp5, key_mod);
                            return true;
                        },
                        .kp_6 => {
                            try widget.session.sendKeypad(terminal_mod.KeypadKey.kp6, key_mod);
                            return true;
                        },
                        .kp_7 => {
                            try widget.session.sendKeypad(terminal_mod.KeypadKey.kp7, key_mod);
                            return true;
                        },
                        .kp_8 => {
                            try widget.session.sendKeypad(terminal_mod.KeypadKey.kp8, key_mod);
                            return true;
                        },
                        .kp_9 => {
                            try widget.session.sendKeypad(terminal_mod.KeypadKey.kp9, key_mod);
                            return true;
                        },
                        .kp_decimal => {
                            try widget.session.sendKeypad(terminal_mod.KeypadKey.kp_decimal, key_mod);
                            return true;
                        },
                        .kp_divide => {
                            try widget.session.sendKeypad(terminal_mod.KeypadKey.kp_divide, key_mod);
                            return true;
                        },
                        .kp_multiply => {
                            try widget.session.sendKeypad(terminal_mod.KeypadKey.kp_multiply, key_mod);
                            return true;
                        },
                        .kp_subtract => {
                            try widget.session.sendKeypad(terminal_mod.KeypadKey.kp_subtract, key_mod);
                            return true;
                        },
                        .kp_add => {
                            try widget.session.sendKeypad(terminal_mod.KeypadKey.kp_add, key_mod);
                            return true;
                        },
                        .kp_enter => {
                            try widget.session.sendKeypad(terminal_mod.KeypadKey.kp_enter, key_mod);
                            return true;
                        },
                        .kp_equal => {
                            try widget.session.sendKeypad(terminal_mod.KeypadKey.kp_equal, key_mod);
                            return true;
                        },
                        else => return false,
                    }
                }
            }.apply;

            if (ctrl and shift and input_batch.keyPressed(.v) and in_terminal) {
                if (shell.getClipboardText()) |clip| {
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

            if (ctrl and shift and input_batch.keyPressed(.c)) {
                if (self.session.selectionState()) |selection| {
                    const sel_snapshot = self.session.snapshot();
                    const rows_snapshot = sel_snapshot.rows;
                    const cols_snapshot = sel_snapshot.cols;
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
                                if (cell.codepoint == 0) {
                                    _ = text.append(self.session.allocator, ' ') catch {};
                                    continue;
                                }
                                var buf: [4]u8 = undefined;
                                const len = std.unicode.utf8Encode(@intCast(cell.codepoint), &buf) catch 0;
                                if (len > 0) {
                                    _ = text.appendSlice(self.session.allocator, buf[0..len]) catch {};
                                }
                            }

                            // Trim trailing spaces
                            while (text.items.len > 0 and text.items[text.items.len - 1] == ' ') {
                                _ = text.pop();
                            }

                            if (row_idx != end_sel.row) {
                                _ = text.append(self.session.allocator, '\n') catch {};
                            }
                        }

                        _ = text.append(self.session.allocator, 0) catch {};
                        const cstr: [*:0]const u8 = @ptrCast(text.items.ptr);
                        shell.setClipboardText(cstr);
                        handled = true;
                        skip_chars = true;
                    }
                }
            }

            if (allow_terminal_key) {
                var handled_keys: [32]shared_types.input.Key = undefined;
                var handled_key_count: usize = 0;
                const markHandled = struct {
                    fn apply(keys: *[32]shared_types.input.Key, count: *usize, key: shared_types.input.Key) void {
                        if (count.* >= keys.len) return;
                        keys[count.*] = key;
                        count.* += 1;
                    }
                }.apply;
                const wasHandled = struct {
                    fn apply(keys: *const [32]shared_types.input.Key, count: usize, key: shared_types.input.Key) bool {
                        var idx: usize = 0;
                        while (idx < count) : (idx += 1) {
                            if (keys[idx] == key) return true;
                        }
                        return false;
                    }
                }.apply;
                const repeat_keys = [_]shared_types.input.Key{
                    .enter,
                    .backspace,
                    .tab,
                    .escape,
                    .up,
                    .down,
                    .left,
                    .right,
                    .home,
                    .end,
                    .page_up,
                    .page_down,
                    .insert,
                    .delete,
                    .kp_0,
                    .kp_1,
                    .kp_2,
                    .kp_3,
                    .kp_4,
                    .kp_5,
                    .kp_6,
                    .kp_7,
                    .kp_8,
                    .kp_9,
                    .kp_decimal,
                    .kp_divide,
                    .kp_multiply,
                    .kp_subtract,
                    .kp_add,
                    .kp_enter,
                    .kp_equal,
                };
                const isRepeatKey = struct {
                    fn apply(keys: []const shared_types.input.Key, key: shared_types.input.Key) bool {
                        for (keys) |value| {
                            if (value == key) return true;
                        }
                        return false;
                    }
                }.apply;

                for (input_batch.events.items) |event| {
                    if (event != .key) continue;
                    if (!event.key.pressed) continue;
                    const key = event.key.key;
                    if (isRepeatKey(&repeat_keys, key)) {
                        continue;
                    }
                    const handled_key = try applyTerminalKey(self, key, mod);

                    if (handled_key) {
                        clearLiveState(self);
                        markHandled(&handled_keys, &handled_key_count, key);
                        handled = true;
                        skip_chars = true;
                        continue;
                    }

                    if (ctrl or alt) {
                        var maybe_char: u32 = 0;
                        switch (key) {
                            .a => maybe_char = if (shift) 'A' else 'a',
                            .b => maybe_char = if (shift) 'B' else 'b',
                            .c => maybe_char = if (shift) 'C' else 'c',
                            .d => maybe_char = if (shift) 'D' else 'd',
                            .e => maybe_char = if (shift) 'E' else 'e',
                            .f => maybe_char = if (shift) 'F' else 'f',
                            .g => maybe_char = if (shift) 'G' else 'g',
                            .h => maybe_char = if (shift) 'H' else 'h',
                            .i => maybe_char = if (shift) 'I' else 'i',
                            .j => maybe_char = if (shift) 'J' else 'j',
                            .k => maybe_char = if (shift) 'K' else 'k',
                            .l => maybe_char = if (shift) 'L' else 'l',
                            .m => maybe_char = if (shift) 'M' else 'm',
                            .n => maybe_char = if (shift) 'N' else 'n',
                            .o => maybe_char = if (shift) 'O' else 'o',
                            .p => maybe_char = if (shift) 'P' else 'p',
                            .q => maybe_char = if (shift) 'Q' else 'q',
                            .r => maybe_char = if (shift) 'R' else 'r',
                            .s => maybe_char = if (shift) 'S' else 's',
                            .t => maybe_char = if (shift) 'T' else 't',
                            .u => maybe_char = if (shift) 'U' else 'u',
                            .v => maybe_char = if (shift) 'V' else 'v',
                            .w => maybe_char = if (shift) 'W' else 'w',
                            .x => maybe_char = if (shift) 'X' else 'x',
                            .y => maybe_char = if (shift) 'Y' else 'y',
                            .z => maybe_char = if (shift) 'Z' else 'z',
                            .zero => maybe_char = if (shift) ')' else '0',
                            .one => maybe_char = if (shift) '!' else '1',
                            .two => maybe_char = if (shift) '@' else '2',
                            .three => maybe_char = if (shift) '#' else '3',
                            .four => maybe_char = if (shift) '$' else '4',
                            .five => maybe_char = if (shift) '%' else '5',
                            .six => maybe_char = if (shift) '^' else '6',
                            .seven => maybe_char = if (shift) '&' else '7',
                            .eight => maybe_char = if (shift) '*' else '8',
                            .nine => maybe_char = if (shift) '(' else '9',
                            .space => maybe_char = ' ',
                            .minus => maybe_char = if (shift) '_' else '-',
                            .equal => maybe_char = if (shift) '+' else '=',
                            .left_bracket => maybe_char = if (shift) '{' else '[',
                            .right_bracket => maybe_char = if (shift) '}' else ']',
                            .backslash => maybe_char = if (shift) '|' else '\\',
                            .semicolon => maybe_char = if (shift) ':' else ';',
                            .apostrophe => maybe_char = if (shift) '"' else '\'',
                            .grave => maybe_char = if (shift) '~' else '`',
                            .comma => maybe_char = if (shift) '<' else ',',
                            .period => maybe_char = if (shift) '>' else '.',
                            .slash => maybe_char = if (shift) '?' else '/',
                            else => {},
                        }
                        if (maybe_char != 0) {
                            clearLiveState(self);
                            try self.session.sendChar(maybe_char, mod);
                            markHandled(&handled_keys, &handled_key_count, key);
                            handled = true;
                            skip_chars = true;
                        }
                    }
                }

                for (repeat_keys) |key| {
                    if (wasHandled(&handled_keys, handled_key_count, key)) continue;
                    if (input_batch.keyRepeated(key)) {
                        if (try applyTerminalKey(self, key, mod)) {
                            clearLiveState(self);
                            handled = true;
                            skip_chars = true;
                        }
                    }
                }
            }

            if (!skip_chars) {
                for (input_batch.events.items) |event| {
                    if (event == .text) {
                        const char = event.text.codepoint;
                        if (char >= 32) {
                            clearLiveState(self);
                            try self.session.sendChar(char, mod);
                            handled = true;
                        }
                    }
                }
            }

            if (!mouse_reporting and in_terminal) {
                if (input_batch.mousePressed(.left)) {
                    const local_x = mouse.x - x;
                    const local_y = mouse.y - y;
                    const col = @as(usize, @intFromFloat(local_x / shell.terminalCellWidth()));
                    const row = @as(usize, @intFromFloat(local_y / shell.terminalCellHeight()));
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

                if (input_batch.mouseDown(.left)) {
                    if (self.session.selectionState()) |_| {
                        const local_x = mouse.x - x;
                        const local_y = mouse.y - y;
                        const col = @as(usize, @intFromFloat(local_x / shell.terminalCellWidth()));
                        const row = @as(usize, @intFromFloat(local_y / shell.terminalCellHeight()));
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

                if (input_batch.mouseReleased(.left)) {
                    if (self.session.selectionState() != null) {
                        self.session.finishSelection();
                        handled = true;
                    }
                }
            }

            if (!mouse_reporting and in_terminal) {
                if (input_batch.mousePressed(.middle)) {
                    if (shell.getClipboardText()) |clip| {
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
                if (wheel_steps != 0) {
                    const delta: isize = @intCast(wheel_steps * 3);
                    self.session.scrollBy(delta);
                    handled = true;
                }
            }

            const mouse_on_scrollbar = mouse.x >= scrollbar_x and mouse.x <= scrollbar_x + scrollbar_w and mouse.y >= scrollbar_y and mouse.y <= scrollbar_y + scrollbar_h;
            if (!mouse_reporting and in_terminal and mouse_on_scrollbar) {
                if (input_batch.mousePressed(.left)) {
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
                if (input_batch.mouseDown(.left)) {
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
