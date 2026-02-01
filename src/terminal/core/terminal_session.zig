const std = @import("std");
const pty_mod = @import("../io/pty.zig");
const input_mod = @import("../input/input.zig");
const history_mod = @import("../model/history.zig");
const scrollback_buffer = @import("../model/scrollback_buffer.zig");
const csi_mod = @import("../parser/csi.zig");
const parser_mod = @import("../parser/parser.zig");
const protocol_csi = @import("../protocol/csi.zig");
const protocol_dcs_apc = @import("../protocol/dcs_apc.zig");
const protocol_osc = @import("../protocol/osc.zig");
const screen_mod = @import("../model/screen.zig");
const snapshot_mod = @import("snapshot.zig");
const types = @import("../model/types.zig");
const app_logger = @import("../../app_logger.zig");
const kitty_mod = @import("../kitty/graphics.zig");
const Pty = pty_mod.Pty;
const PtySize = pty_mod.PtySize;
const Screen = screen_mod.Screen;
const Dirty = screen_mod.Dirty;
const Damage = screen_mod.Damage;
const builtin = @import("builtin");
const OscTerminator = parser_mod.OscTerminator;

const dynamic_color_count: usize = 10;

const SemanticPromptKind = enum {
    primary,
    continuation,
    secondary,
    right,
};

const SemanticPromptState = struct {
    prompt_active: bool = false,
    input_active: bool = false,
    output_active: bool = false,
    kind: SemanticPromptKind = .primary,
    redraw: bool = true,
    special_key: bool = false,
    click_events: bool = false,
    exit_code: ?u8 = null,
};

pub const KittyImageFormat = snapshot_mod.KittyImageFormat;
pub const KittyImage = snapshot_mod.KittyImage;
pub const KittyPlacement = snapshot_mod.KittyPlacement;

const RenderCache = struct {
    cells: std.ArrayList(Cell),
    dirty_rows: std.ArrayList(bool),
    dirty_cols_start: std.ArrayList(u16),
    dirty_cols_end: std.ArrayList(u16),
    selection_rows: std.ArrayList(bool),
    selection_cols_start: std.ArrayList(u16),
    selection_cols_end: std.ArrayList(u16),
    kitty_images: std.ArrayList(KittyImage),
    kitty_placements: std.ArrayList(KittyPlacement),
    rows: usize,
    cols: usize,
    history_len: usize,
    total_lines: usize,
    generation: u64,
    scroll_offset: usize,
    cursor: types.CursorPos,
    cursor_style: types.CursorStyle,
    cursor_visible: bool,
    dirty: screen_mod.Dirty,
    damage: screen_mod.Damage,
    alt_active: bool,
    selection_active: bool,
    sync_updates_active: bool,
    kitty_generation: u64,
    clear_generation: u64,

    fn init() RenderCache {
        return .{
            .cells = std.ArrayList(Cell).empty,
            .dirty_rows = std.ArrayList(bool).empty,
            .dirty_cols_start = std.ArrayList(u16).empty,
            .dirty_cols_end = std.ArrayList(u16).empty,
            .selection_rows = std.ArrayList(bool).empty,
            .selection_cols_start = std.ArrayList(u16).empty,
            .selection_cols_end = std.ArrayList(u16).empty,
            .kitty_images = std.ArrayList(KittyImage).empty,
            .kitty_placements = std.ArrayList(KittyPlacement).empty,
            .rows = 0,
            .cols = 0,
            .history_len = 0,
            .total_lines = 0,
            .generation = 0,
            .scroll_offset = 0,
            .cursor = .{ .row = 0, .col = 0 },
            .cursor_style = types.default_cursor_style,
            .cursor_visible = false,
            .dirty = .none,
            .damage = .{ .start_row = 0, .end_row = 0, .start_col = 0, .end_col = 0 },
            .alt_active = false,
            .selection_active = false,
            .sync_updates_active = false,
            .kitty_generation = 0,
            .clear_generation = 0,
        };
    }

    fn deinit(self: *RenderCache, allocator: std.mem.Allocator) void {
        self.cells.deinit(allocator);
        self.dirty_rows.deinit(allocator);
        self.dirty_cols_start.deinit(allocator);
        self.dirty_cols_end.deinit(allocator);
        self.selection_rows.deinit(allocator);
        self.selection_cols_start.deinit(allocator);
        self.selection_cols_end.deinit(allocator);
        self.kitty_images.deinit(allocator);
        self.kitty_placements.deinit(allocator);
    }
};

fn buildDefaultPalette() [256]types.Color {
    var palette: [256]types.Color = undefined;
    var idx: usize = 0;
    while (idx < palette.len) : (idx += 1) {
        palette[idx] = types.indexToRgb(@intCast(idx));
    }
    return palette;
}

fn logCsiSequences(log: app_logger.Logger, buf: []const u8) void {
    if (!(log.enabled_file or log.enabled_console)) return;
    var i: usize = 0;
    while (i + 1 < buf.len) : (i += 1) {
        if (buf[i] != 0x1b or buf[i + 1] != '[') continue;
        const start = i;
        i += 2;
        while (i < buf.len) : (i += 1) {
            const b = buf[i];
            if (b >= 0x40 and b <= 0x7E) {
                if (b == 'm') {
                    const seq = buf[start .. i + 1];
                    var hex_buf: [256]u8 = undefined;
                    var out: []u8 = hex_buf[0..0];
                    for (seq) |sb| {
                        if (out.len + 3 > hex_buf.len) break;
                        const pos = out.len;
                        _ = std.fmt.bufPrint(hex_buf[pos..], "{x:0>2} ", .{sb}) catch break;
                        out = hex_buf[0 .. pos + 3];
                    }
                    log.logf("csi raw len={d} hex={s}", .{ seq.len, out });
                }
                break;
            }
        }
    }
}

pub const TerminalSnapshot = snapshot_mod.TerminalSnapshot;
pub const DebugSnapshot = snapshot_mod.DebugSnapshot;

pub fn debugSnapshot(self: *TerminalSession) DebugSnapshot {
    if (!debugAccessAllowed()) @panic("debugSnapshot is test-only");
    return .{
        .title = self.title,
        .cwd = self.cwd,
        .osc_clipboard = self.osc_clipboard.items,
        .osc_clipboard_pending = self.osc_clipboard_pending,
        .hyperlinks = self.hyperlink_table.items,
        .scrollback_count = self.history.scrollbackCount(),
        .scrollback_offset = self.history.scrollOffset(),
        .selection = self.selectionState(),
        .base_default_attrs = self.base_default_attrs,
    };
}

pub fn debugScrollbackRow(self: *TerminalSession, index: usize) ?[]const Cell {
    if (!debugAccessAllowed()) @panic("debugScrollbackRow is test-only");
    return self.history.scrollbackRow(index);
}

pub fn debugSetCursor(self: *TerminalSession, row: usize, col: usize) void {
    if (!debugAccessAllowed()) @panic("debugSetCursor is test-only");
    self.activeScreen().setCursor(row, col);
}

pub fn debugFeedBytes(self: *TerminalSession, bytes: []const u8) void {
    if (!debugAccessAllowed()) @panic("debugFeedBytes is test-only");
    self.parser.handleSlice(self, bytes);
}

fn debugAccessAllowed() bool {
    if (builtin.is_test) return true;
    const root = @import("root");
    return @hasDecl(root, "terminal_replay_enabled") and root.terminal_replay_enabled;
}

const ActiveScreen = enum {
    primary,
    alt,
};

/// Minimal terminal stub so the UI panel stays wired while backend is removed.
pub const TerminalSession = struct {
    allocator: std.mem.Allocator,
    title: []const u8,
    title_buffer: std.ArrayList(u8),
    pty: ?Pty,
    primary: Screen,
    alt: Screen,
    active: ActiveScreen,
    history: history_mod.TerminalHistory,
    bracketed_paste: bool,
    app_cursor_keys: bool,
    app_keypad: bool,
    input: input_mod.InputState,
    input_snapshot: InputSnapshot,
    pty_write_mutex: std.Thread.Mutex,
    cell_width: u16,
    cell_height: u16,
    parser: parser_mod.Parser,
    osc_clipboard: std.ArrayList(u8),
    osc_clipboard_pending: bool,
    osc_hyperlink: std.ArrayList(u8),
    osc_hyperlink_active: bool,
    hyperlink_table: std.ArrayList(Hyperlink),
    current_hyperlink_id: u32,
    cwd: []const u8,
    cwd_buffer: std.ArrayList(u8),
    semantic_prompt: SemanticPromptState,
    semantic_prompt_aid: std.ArrayList(u8),
    semantic_cmdline: std.ArrayList(u8),
    semantic_cmdline_valid: bool,
    user_vars: std.StringHashMap([]u8),
    kitty_primary: kitty_mod.KittyState,
    kitty_alt: kitty_mod.KittyState,
    base_default_attrs: types.CellAttrs,
    palette_default: [256]types.Color,
    palette_current: [256]types.Color,
    dynamic_colors: [dynamic_color_count]?types.Color,
    read_thread: ?std.Thread,
    read_thread_running: std.atomic.Value(bool),
    parse_thread: ?std.Thread,
    parse_thread_running: std.atomic.Value(bool),
    state_mutex: std.Thread.Mutex,
    io_mutex: std.Thread.Mutex,
    io_wait_cond: std.Thread.Condition,
    io_buffer: std.ArrayList(u8),
    io_read_offset: usize,
    sync_updates_active: bool,
    output_pending: std.atomic.Value(bool),
    output_generation: std.atomic.Value(u64),
    input_pressure: std.atomic.Value(bool),
    alt_exit_pending: std.atomic.Value(bool),
    alt_exit_time_ms: std.atomic.Value(i64),
    last_parse_log_ms: i64,
    render_caches: [2]RenderCache,
    render_cache_index: std.atomic.Value(u8),
    view_cache_pending: std.atomic.Value(bool),
    view_cache_request_offset: std.atomic.Value(u64),
    alt_last_active: bool,
    clear_generation: std.atomic.Value(u64),
    force_full_damage: std.atomic.Value(bool),

    pub fn init(allocator: std.mem.Allocator, rows: u16, cols: u16) !*TerminalSession {
        const session = try allocator.create(TerminalSession);
        const default_attrs = types.defaultCell().attrs;
        const primary = try Screen.init(allocator, rows, cols, default_attrs);
        const alt = try Screen.init(allocator, rows, cols, default_attrs);
        const history = try history_mod.TerminalHistory.init(allocator, default_scrollback_rows, cols);
        const log = app_logger.logger("terminal.core");
        log.logf("terminal init rows={d} cols={d} scrollback_max={d}", .{ rows, cols, default_scrollback_rows });
        log.logStdout("terminal init rows={d} cols={d}", .{ rows, cols });
        const palette_default = buildDefaultPalette();
        session.* = .{
            .allocator = allocator,
            .title = "Terminal",
            .title_buffer = .empty,
            .pty = null,
            .primary = primary,
            .alt = alt,
            .active = .primary,
            .history = history,
            .bracketed_paste = false,
            .app_cursor_keys = false,
            .app_keypad = false,
            .input = input_mod.InputState.init(),
            .input_snapshot = InputSnapshot.init(),
            .pty_write_mutex = .{},
            .cell_width = 0,
            .cell_height = 0,
            .parser = parser_mod.Parser.init(allocator),
            .osc_clipboard = .empty,
            .osc_clipboard_pending = false,
            .osc_hyperlink = .empty,
            .osc_hyperlink_active = false,
            .hyperlink_table = .empty,
            .current_hyperlink_id = 0,
            .cwd = "",
            .cwd_buffer = .empty,
            .semantic_prompt = .{},
            .semantic_prompt_aid = .empty,
            .semantic_cmdline = .empty,
            .semantic_cmdline_valid = false,
            .user_vars = std.StringHashMap([]u8).init(allocator),
            .kitty_primary = .{
                .images = .empty,
                .placements = .empty,
                .partials = std.AutoHashMap(u32, kitty_mod.KittyPartial).init(allocator),
                .next_id = 1,
                .loading_image_id = null,
                .generation = 0,
                .total_bytes = 0,
                .scrollback_total = 0,
            },
            .kitty_alt = .{
                .images = .empty,
                .placements = .empty,
                .partials = std.AutoHashMap(u32, kitty_mod.KittyPartial).init(allocator),
                .next_id = 1,
                .loading_image_id = null,
                .generation = 0,
                .total_bytes = 0,
                .scrollback_total = 0,
            },
            .base_default_attrs = default_attrs,
            .palette_default = palette_default,
            .palette_current = palette_default,
            .dynamic_colors = [_]?types.Color{null} ** dynamic_color_count,
            .read_thread = null,
            .read_thread_running = std.atomic.Value(bool).init(false),
            .parse_thread = null,
            .parse_thread_running = std.atomic.Value(bool).init(false),
            .state_mutex = .{},
            .io_mutex = .{},
            .io_wait_cond = .{},
            .io_buffer = .empty,
            .io_read_offset = 0,
            .sync_updates_active = false,
            .output_pending = std.atomic.Value(bool).init(false),
            .output_generation = std.atomic.Value(u64).init(0),
            .input_pressure = std.atomic.Value(bool).init(false),
            .alt_exit_pending = std.atomic.Value(bool).init(false),
            .alt_exit_time_ms = std.atomic.Value(i64).init(-1),
            .last_parse_log_ms = 0,
            .render_caches = .{ RenderCache.init(), RenderCache.init() },
            .render_cache_index = std.atomic.Value(u8).init(0),
            .view_cache_pending = std.atomic.Value(bool).init(false),
            .view_cache_request_offset = std.atomic.Value(u64).init(0),
            .alt_last_active = false,
            .clear_generation = std.atomic.Value(u64).init(0),
            .force_full_damage = std.atomic.Value(bool).init(false),
        };
        session.updateInputSnapshot();
        return session;
    }

    pub fn activeScreen(self: *TerminalSession) *Screen {
        return if (self.active == .alt) &self.alt else &self.primary;
    }

    pub fn activeScreenConst(self: *const TerminalSession) *const Screen {
        return if (self.active == .alt) &self.alt else &self.primary;
    }

    pub fn setInputPressure(self: *TerminalSession, value: bool) void {
        self.input_pressure.store(value, .release);
    }

    pub fn updateInputSnapshot(self: *TerminalSession) void {
        self.input_snapshot.app_cursor_keys.store(self.app_cursor_keys, .release);
        self.input_snapshot.app_keypad.store(self.app_keypad, .release);
        self.input_snapshot.key_mode_flags.store(self.keyModeFlags(), .release);
        self.input_snapshot.mouse_mode_x10.store(self.input.mouse_mode_x10, .release);
        self.input_snapshot.mouse_mode_button.store(self.input.mouse_mode_button, .release);
        self.input_snapshot.mouse_mode_any.store(self.input.mouse_mode_any, .release);
        self.input_snapshot.mouse_mode_sgr.store(self.input.mouse_mode_sgr, .release);
    }

    fn updateViewCacheNoLock(self: *TerminalSession, generation: u64, scroll_offset: usize) void {
        const screen = self.activeScreenConst();
        const view = screen.snapshotView();
        const rows = view.rows;
        const cols = view.cols;
        const active_index = self.render_cache_index.load(.acquire);
        const target_index: u8 = if (active_index == 0) 1 else 0;
        var cache = &self.render_caches[target_index];
        if (!self.isAltActive()) {
            self.history.ensureViewCache(@intCast(cols), self.primary.defaultCell());
        }
        const history_len = if (self.isAltActive()) 0 else self.history.scrollbackCount();
        const total_lines = history_len + rows;
        const max_offset = if (total_lines > rows) total_lines - rows else 0;
        const clamped_offset = if (scroll_offset > max_offset) max_offset else scroll_offset;
        const kitty_generation = kitty_mod.kittyStateConst(self).generation;
        const clear_generation = self.clear_generation.load(.acquire);
        const force_full_damage = self.force_full_damage.swap(false, .acq_rel);
        const selection_active = !self.isAltActive() and self.history.selectionState() != null;
        const active_cache = &self.render_caches[active_index];
        if (active_cache.rows == rows and
            active_cache.cols == cols and
            active_cache.history_len == history_len and
            active_cache.total_lines == total_lines and
            active_cache.scroll_offset == clamped_offset and
            active_cache.generation == generation and
            active_cache.clear_generation == clear_generation and
            active_cache.alt_active == self.isAltActive() and
            active_cache.sync_updates_active == self.sync_updates_active and
            active_cache.kitty_generation == kitty_generation and
            !force_full_damage and
            view.dirty == .none and
            active_cache.dirty == .none and
            !selection_active and
            !active_cache.selection_active)
        {
            return;
        }
        if (rows == 0 or cols == 0) {
            cache.cells.clearRetainingCapacity();
            cache.dirty_rows.clearRetainingCapacity();
            cache.dirty_cols_start.clearRetainingCapacity();
            cache.dirty_cols_end.clearRetainingCapacity();
            cache.selection_rows.clearRetainingCapacity();
            cache.selection_cols_start.clearRetainingCapacity();
            cache.selection_cols_end.clearRetainingCapacity();
            cache.rows = 0;
            cache.cols = 0;
            cache.history_len = history_len;
            cache.total_lines = total_lines;
            cache.generation = generation;
            cache.scroll_offset = clamped_offset;
            cache.cursor = view.cursor;
            cache.cursor_style = view.cursor_style;
            cache.cursor_visible = view.cursor_visible;
            cache.dirty = .full;
            cache.damage = .{ .start_row = 0, .end_row = 0, .start_col = 0, .end_col = 0 };
            cache.alt_active = self.isAltActive();
            cache.selection_active = selection_active;
            cache.sync_updates_active = self.sync_updates_active;
            cache.clear_generation = clear_generation;
            self.updateKittyViewNoLock(cache);
            self.render_cache_index.store(target_index, .release);
            return;
        }

        const view_count = rows * cols;
        _ = cache.cells.resize(self.allocator, view_count) catch {};
        _ = cache.dirty_rows.resize(self.allocator, rows) catch {};
        _ = cache.dirty_cols_start.resize(self.allocator, rows) catch {};
        _ = cache.dirty_cols_end.resize(self.allocator, rows) catch {};
        _ = cache.selection_rows.resize(self.allocator, rows) catch {};
        _ = cache.selection_cols_start.resize(self.allocator, rows) catch {};
        _ = cache.selection_cols_end.resize(self.allocator, rows) catch {};

        const start_line = if (total_lines > rows + clamped_offset)
            total_lines - rows - clamped_offset
        else
            0;
        var row: usize = 0;
        while (row < rows) : (row += 1) {
            const global_row = start_line + row;
            const row_start = row * cols;
            const row_dest = cache.cells.items[row_start .. row_start + cols];
            if (global_row < history_len) {
                if (self.history.scrollbackRow(global_row)) |history_row| {
                    std.mem.copyForwards(Cell, row_dest, history_row[0..cols]);
                } else {
                    std.mem.copyForwards(Cell, row_dest, view.cells[0..cols]);
                }
            } else {
                const grid_row = global_row - history_len;
                const src_start = grid_row * cols;
                std.mem.copyForwards(Cell, row_dest, view.cells[src_start .. src_start + cols]);
            }
        }

        if (self.isAltActive()) {
            for (cache.selection_rows.items) |*row_selected| {
                row_selected.* = false;
            }
            cache.selection_active = selection_active;
        } else if (self.history.selectionState()) |selection| {
            cache.selection_active = selection_active;
            var start_sel = selection.start;
            var end_sel = selection.end;
            if (start_sel.row > end_sel.row or (start_sel.row == end_sel.row and start_sel.col > end_sel.col)) {
                const tmp = start_sel;
                start_sel = end_sel;
                end_sel = tmp;
            }
            const total_lines_sel = total_lines;
            if (total_lines_sel > 0) {
                start_sel.row = @min(start_sel.row, total_lines_sel - 1);
                end_sel.row = @min(end_sel.row, total_lines_sel - 1);
                start_sel.col = @min(start_sel.col, cols - 1);
                end_sel.col = @min(end_sel.col, cols - 1);
            } else {
                start_sel.row = 0;
                end_sel.row = 0;
                start_sel.col = 0;
                end_sel.col = 0;
            }

            row = 0;
            while (row < rows) : (row += 1) {
                const global_row = start_line + row;
                if (global_row < start_sel.row or global_row > end_sel.row) {
                    cache.selection_rows.items[row] = false;
                    continue;
                }
                const col_start = if (global_row == start_sel.row) start_sel.col else 0;
                const col_end = if (global_row == end_sel.row) end_sel.col else cols - 1;
                if (col_end < col_start) {
                    cache.selection_rows.items[row] = false;
                    continue;
                }
                cache.selection_rows.items[row] = true;
                cache.selection_cols_start.items[row] = @intCast(col_start);
                cache.selection_cols_end.items[row] = @intCast(col_end);
            }
        } else {
            for (cache.selection_rows.items) |*row_selected| {
                row_selected.* = false;
            }
            cache.selection_active = selection_active;
        }
        const needs_full_damage = force_full_damage or
            scroll_offset != 0 or
            clear_generation != active_cache.clear_generation or
            self.isAltActive() != active_cache.alt_active or
            view.dirty == .full;

        if (view.dirty_rows.len == rows and !needs_full_damage) {
            std.mem.copyForwards(bool, cache.dirty_rows.items, view.dirty_rows);
        } else {
            for (cache.dirty_rows.items) |*row_dirty| {
                row_dirty.* = true;
            }
        }
        if (view.dirty_cols_start.len == rows and view.dirty_cols_end.len == rows and !needs_full_damage) {
            std.mem.copyForwards(u16, cache.dirty_cols_start.items, view.dirty_cols_start);
            std.mem.copyForwards(u16, cache.dirty_cols_end.items, view.dirty_cols_end);
            if (view.dirty == .partial and cols > 0) {
                var row_idx: usize = 0;
                while (row_idx < rows) : (row_idx += 1) {
                    if (!cache.dirty_rows.items[row_idx]) continue;
                    cache.dirty_cols_start.items[row_idx] = 0;
                    cache.dirty_cols_end.items[row_idx] = @intCast(cols - 1);
                }
            }
        } else {
            for (cache.dirty_cols_start.items, cache.dirty_cols_end.items) |*col_start, *col_end| {
                col_start.* = 0;
                col_end.* = if (cols > 0) @intCast(cols - 1) else 0;
            }
        }

        cache.rows = rows;
        cache.cols = cols;
        cache.history_len = history_len;
        cache.total_lines = total_lines;
        cache.generation = generation;
        cache.scroll_offset = clamped_offset;
        cache.cursor = view.cursor;
        cache.cursor_style = view.cursor_style;
        cache.cursor_visible = view.cursor_visible;
        cache.dirty = if (needs_full_damage) .full else view.dirty;
        cache.damage = if (needs_full_damage)
            .{ .start_row = 0, .end_row = if (rows > 0) rows - 1 else 0, .start_col = 0, .end_col = if (cols > 0) cols - 1 else 0 }
        else
            view.damage;
        cache.alt_active = self.isAltActive();
        cache.selection_active = selection_active;
        cache.sync_updates_active = self.sync_updates_active;
        cache.clear_generation = clear_generation;
        self.updateKittyViewNoLock(cache);
        self.render_cache_index.store(target_index, .release);
    }

    fn updateKittyViewNoLock(self: *TerminalSession, cache: *RenderCache) void {
        const kitty = kitty_mod.kittyStateConst(self);
        const kitty_generation = kitty.generation;
        if (kitty_generation == cache.kitty_generation) return;

        _ = cache.kitty_images.resize(self.allocator, kitty.images.items.len) catch {};
        _ = cache.kitty_placements.resize(self.allocator, kitty.placements.items.len) catch {};
        std.mem.copyForwards(kitty_mod.KittyImage, cache.kitty_images.items, kitty.images.items);
        std.mem.copyForwards(kitty_mod.KittyPlacement, cache.kitty_placements.items, kitty.placements.items);
        if (cache.kitty_placements.items.len > 1) {
            std.sort.block(kitty_mod.KittyPlacement, cache.kitty_placements.items, {}, struct {
                fn lessThan(_: void, a: kitty_mod.KittyPlacement, b: kitty_mod.KittyPlacement) bool {
                    if (a.z == b.z) {
                        if (a.row == b.row) return a.col < b.col;
                        return a.row < b.row;
                    }
                    return a.z < b.z;
                }
            }.lessThan);
        }
        cache.kitty_generation = kitty_generation;
    }

    fn inactiveScreen(self: *TerminalSession) *Screen {
        return if (self.active == .alt) &self.primary else &self.alt;
    }

    fn isAltActive(self: *const TerminalSession) bool {
        return self.active == .alt;
    }

    pub fn setDefaultColors(self: *TerminalSession, fg: types.Color, bg: types.Color) void {
        const old_attrs = self.primary.default_attrs;
        var new_attrs = types.defaultCell().attrs;
        new_attrs.fg = fg;
        new_attrs.bg = bg;
        new_attrs.underline_color = fg;

        self.primary.updateDefaultColors(old_attrs, new_attrs);
        self.alt.updateDefaultColors(old_attrs, new_attrs);
        self.history.updateDefaultColors(old_attrs.fg, old_attrs.bg, new_attrs.fg, new_attrs.bg);
    }

    pub fn deinit(self: *TerminalSession) void {
        if (self.read_thread) |thread| {
            self.read_thread_running.store(false, .release);
            thread.join();
            self.read_thread = null;
        }
        if (self.parse_thread) |thread| {
            self.parse_thread_running.store(false, .release);
            self.io_wait_cond.signal();
            thread.join();
            self.parse_thread = null;
        }
        if (self.pty) |*pty| {
            pty.deinit();
        }
        self.render_caches[0].deinit(self.allocator);
        self.render_caches[1].deinit(self.allocator);
        self.io_buffer.deinit(self.allocator);
        self.history.deinit();
        self.primary.deinit();
        self.alt.deinit();
        self.parser.deinit();
        self.osc_clipboard.deinit(self.allocator);
        self.osc_hyperlink.deinit(self.allocator);
        self.cwd_buffer.deinit(self.allocator);
        self.semantic_prompt_aid.deinit(self.allocator);
        self.semantic_cmdline.deinit(self.allocator);
        var user_it = self.user_vars.iterator();
        while (user_it.next()) |entry| {
            self.allocator.free(entry.key_ptr.*);
            self.allocator.free(entry.value_ptr.*);
        }
        self.user_vars.deinit();
        kitty_mod.deinitKittyState(self, &self.kitty_primary);
        kitty_mod.deinitKittyState(self, &self.kitty_alt);
        for (self.hyperlink_table.items) |link| {
            self.allocator.free(link.uri);
        }
        self.hyperlink_table.deinit(self.allocator);
        self.title_buffer.deinit(self.allocator);
        self.allocator.destroy(self);
    }

    pub fn start(self: *TerminalSession, shell: ?[:0]const u8) !void {
        const size = PtySize{
            .rows = self.primary.grid.rows,
            .cols = self.primary.grid.cols,
            .cell_width = self.cell_width,
            .cell_height = self.cell_height,
        };
        const pty = try Pty.init(self.allocator, size, shell);
        self.pty = pty;
        if (builtin.os.tag == .linux or builtin.os.tag == .macos) {
            self.read_thread_running.store(true, .release);
            self.read_thread = try std.Thread.spawn(.{}, readThreadMain, .{self});
            self.parse_thread_running.store(true, .release);
            self.parse_thread = try std.Thread.spawn(.{}, parseThreadMain, .{self});
        }
    }

    pub fn poll(self: *TerminalSession) !void {
        const input_pressure = self.input_pressure.load(.acquire);
        if (self.read_thread != null) {
            if (self.parse_thread != null) {
                _ = self.output_pending.swap(false, .acq_rel);
                return;
            }
            const perf_log = app_logger.logger("terminal.parse");
            _ = self.output_pending.swap(false, .acq_rel);
            var queued_bytes: usize = 0;
            self.io_mutex.lock();
            if (self.io_buffer.items.len > self.io_read_offset) {
                queued_bytes = self.io_buffer.items.len - self.io_read_offset;
            }
            self.io_mutex.unlock();

            var max_bytes_per_poll: usize = if (input_pressure) 32 * 1024 else 64 * 1024;
            var max_ms: i64 = if (input_pressure) 1 else 2;
            if (queued_bytes >= 8 * 1024 * 1024) {
                max_bytes_per_poll = if (input_pressure) 256 * 1024 else 2 * 1024 * 1024;
                max_ms = if (input_pressure) 4 else 16;
            } else if (queued_bytes >= 1024 * 1024) {
                max_bytes_per_poll = if (input_pressure) 128 * 1024 else 512 * 1024;
                max_ms = if (input_pressure) 2 else 8;
            }
            const start_ms = std.time.milliTimestamp();
            var processed: usize = 0;
            var had_data = false;
            var temp: [4096]u8 = undefined;

            while (processed < max_bytes_per_poll and std.time.milliTimestamp() - start_ms < max_ms) {
                var chunk_len: usize = 0;
                self.io_mutex.lock();
                const available = if (self.io_buffer.items.len > self.io_read_offset)
                    self.io_buffer.items.len - self.io_read_offset
                else
                    0;
                if (available > 0) {
                    chunk_len = @min(temp.len, available);
                    std.mem.copyForwards(u8, temp[0..chunk_len], self.io_buffer.items[self.io_read_offset .. self.io_read_offset + chunk_len]);
                    self.io_read_offset += chunk_len;
                    had_data = true;
                    if (self.io_read_offset >= self.io_buffer.items.len) {
                        self.io_buffer.items.len = 0;
                        self.io_read_offset = 0;
                    } else if (self.io_read_offset > 64 * 1024 and self.io_read_offset > self.io_buffer.items.len / 2) {
                        const remaining = self.io_buffer.items.len - self.io_read_offset;
                        std.mem.copyForwards(u8, self.io_buffer.items[0..remaining], self.io_buffer.items[self.io_read_offset..self.io_buffer.items.len]);
                        self.io_buffer.items.len = remaining;
                        self.io_read_offset = 0;
                    }
                }
                self.io_mutex.unlock();

                if (chunk_len == 0) break;

                self.state_mutex.lock();
                self.parser.handleSlice(self, temp[0..chunk_len]);
                self.state_mutex.unlock();
                processed += chunk_len;
                _ = self.output_generation.fetchAdd(1, .acq_rel);
            }

            if (had_data) {
                self.state_mutex.lock();
                self.clearSelection();
                self.force_full_damage.store(true, .release);
                self.updateViewCacheNoLock(self.output_generation.load(.acquire), self.history.scrollOffset());
                self.state_mutex.unlock();
            }

            if (processed > 0 and (perf_log.enabled_file or perf_log.enabled_console)) {
                const end_ms = std.time.milliTimestamp();
                const elapsed_ms = @as(f64, @floatFromInt(end_ms - start_ms));
                const should_log = elapsed_ms >= 8.0 or queued_bytes >= 1024 * 1024 or processed >= 512 * 1024;
                if (should_log and (end_ms - self.last_parse_log_ms) >= 100) {
                    self.last_parse_log_ms = end_ms;
                    perf_log.logf("parse_ms={d:.2} bytes={d} queued_bytes={d} input_pressure={any}", .{
                        elapsed_ms,
                        processed,
                        queued_bytes,
                        input_pressure,
                    });
                }
            }

            self.io_mutex.lock();
            if (self.io_buffer.items.len > self.io_read_offset) {
                self.output_pending.store(true, .release);
            }
            self.io_mutex.unlock();
            if (self.view_cache_pending.swap(false, .acq_rel)) {
                self.state_mutex.lock();
                const offset: usize = @intCast(self.view_cache_request_offset.load(.acquire));
                self.updateViewCacheNoLock(self.output_generation.load(.acquire), offset);
                self.state_mutex.unlock();
            }
            return;
        }

        if (self.pty) |*pty| {
            const perf_log = app_logger.logger("terminal.parse");
            var buf: [262144]u8 = undefined;
            var had_data = false;
            var processed: usize = 0;
            const max_bytes_per_poll: usize = 256 * 1024;
            const start_ms = std.time.milliTimestamp();
            const io_log = app_logger.logger("terminal.io");
            while (true) {
                const n = try pty.read(&buf);
                if (n == null or n.? == 0) break;
                had_data = true;
                processed += n.?;
                logCsiSequences(io_log, buf[0..n.?]);
                self.parser.handleSlice(self, buf[0..n.?]);
                _ = self.output_generation.fetchAdd(1, .acq_rel);
                if (processed >= max_bytes_per_poll) break;
            }
            if (had_data) {
                self.clearSelection();
                self.force_full_damage.store(true, .release);
                self.updateViewCacheNoLock(self.output_generation.load(.acquire), self.history.scrollOffset());
            }
            if (processed > 0 and self.alt_exit_pending.swap(false, .acq_rel)) {
                const elapsed_ms = @as(f64, @floatFromInt(std.time.milliTimestamp() - start_ms));
                io_log.logf("alt_exit_io_ms={d:.2} bytes={d}", .{ elapsed_ms, processed });
            }
            if (processed > 0 and (perf_log.enabled_file or perf_log.enabled_console)) {
                const end_ms = std.time.milliTimestamp();
                const elapsed_ms = @as(f64, @floatFromInt(end_ms - start_ms));
                const should_log = elapsed_ms >= 8.0 or processed >= 512 * 1024;
                if (should_log and (end_ms - self.last_parse_log_ms) >= 100) {
                    self.last_parse_log_ms = end_ms;
                    perf_log.logf("parse_ms={d:.2} bytes={d} input_pressure={any}", .{
                        elapsed_ms,
                        processed,
                        input_pressure,
                    });
                }
            }
            if (self.view_cache_pending.swap(false, .acq_rel)) {
                const offset: usize = @intCast(self.view_cache_request_offset.load(.acquire));
                self.updateViewCacheNoLock(self.output_generation.load(.acquire), offset);
            }
        }
    }

    pub fn hasData(self: *TerminalSession) bool {
        if (self.read_thread != null) {
            if (self.parse_thread != null) {
                return self.output_pending.load(.acquire);
            }
            if (self.output_pending.load(.acquire)) return true;
            var pending = false;
            self.io_mutex.lock();
            if (self.io_buffer.items.len > self.io_read_offset) {
                pending = true;
            }
            self.io_mutex.unlock();
            return pending;
        }
        if (self.pty) |*pty| {
            return pty.hasData();
        }
        return false;
    }

    pub fn lock(self: *TerminalSession) void {
        self.state_mutex.lock();
    }

    pub fn tryLock(self: *TerminalSession) bool {
        return self.state_mutex.tryLock();
    }

    pub fn unlock(self: *TerminalSession) void {
        self.state_mutex.unlock();
    }

    pub fn currentGeneration(self: *TerminalSession) u64 {
        return self.output_generation.load(.acquire);
    }

    pub fn sendKey(self: *TerminalSession, key: Key, mod: Modifier) !void {
        try self.sendKeyAction(key, mod, input_mod.KeyAction.press);
    }

    pub fn sendKeyAction(self: *TerminalSession, key: Key, mod: Modifier, action: input_mod.KeyAction) !void {
        const log = app_logger.logger("terminal.input");
        const input_snapshot = self.input_snapshot;
        const key_mode_flags = input_snapshot.key_mode_flags.load(.acquire);
        const app_cursor = input_snapshot.app_cursor_keys.load(.acquire);
        if (log.enabled_file or log.enabled_console) {
            log.logf("sendKey key={s} code={d} mod=0x{x} action={s} app_cursor={any} key_mode=0x{x}", .{
                keyName(key),
                key,
                mod,
                @tagName(action),
                app_cursor,
                key_mode_flags,
            });
        }
        if (self.pty) |*pty| {
            self.pty_write_mutex.lock();
            defer self.pty_write_mutex.unlock();
            if (key_mode_flags == 0 and app_cursor and mod == types.VTERM_MOD_NONE and action == .press) {
                const seq = switch (key) {
                    VTERM_KEY_UP => "\x1bOA",
                    VTERM_KEY_DOWN => "\x1bOB",
                    VTERM_KEY_RIGHT => "\x1bOC",
                    VTERM_KEY_LEFT => "\x1bOD",
                    VTERM_KEY_HOME => "\x1bOH",
                    VTERM_KEY_END => "\x1bOF",
                    else => "",
                };
                if (seq.len > 0) {
                    _ = try pty.write(seq);
                    return;
                }
            }
            _ = try input_mod.sendKeyAction(pty, key, mod, key_mode_flags, action);
        }
    }

    pub fn sendKeypad(self: *TerminalSession, key: input_mod.KeypadKey, mod: Modifier) !void {
        try self.sendKeypadAction(key, mod, input_mod.KeyAction.press);
    }

    pub fn sendKeypadAction(self: *TerminalSession, key: input_mod.KeypadKey, mod: Modifier, action: input_mod.KeyAction) !void {
        const log = app_logger.logger("terminal.input");
        const input_snapshot = self.input_snapshot;
        const key_mode_flags = input_snapshot.key_mode_flags.load(.acquire);
        const app_keypad = input_snapshot.app_keypad.load(.acquire);
        if (log.enabled_file or log.enabled_console) {
            log.logf("sendKeypad key={s} mod=0x{x} action={s} app_keypad={any} key_mode=0x{x}", .{
                keypadKeyName(key),
                mod,
                @tagName(action),
                app_keypad,
                key_mode_flags,
            });
        }
        if (self.pty) |*pty| {
            self.pty_write_mutex.lock();
            defer self.pty_write_mutex.unlock();
            if (action == .press) {
                _ = try input_mod.sendKeypad(pty, key, mod, app_keypad, key_mode_flags);
            }
        }
    }

    pub fn appKeypadEnabled(self: *const TerminalSession) bool {
        return self.input_snapshot.app_keypad.load(.acquire);
    }

    pub fn sendChar(self: *TerminalSession, char: u32, mod: Modifier) !void {
        try self.sendCharAction(char, mod, input_mod.KeyAction.press);
    }

    pub fn sendCharAction(self: *TerminalSession, char: u32, mod: Modifier, action: input_mod.KeyAction) !void {
        const log = app_logger.logger("terminal.input");
        const input_snapshot = self.input_snapshot;
        const key_mode_flags = input_snapshot.key_mode_flags.load(.acquire);
        if (log.enabled_file or log.enabled_console) {
            log.logf("sendChar cp={d} mod=0x{x} action={s} key_mode=0x{x}", .{
                char,
                mod,
                @tagName(action),
                key_mode_flags,
            });
        }
        if (self.pty) |*pty| {
            self.pty_write_mutex.lock();
            defer self.pty_write_mutex.unlock();
            _ = try input_mod.sendCharAction(pty, char, mod, key_mode_flags, action);
        }
    }

    pub fn reportMouseEvent(self: *TerminalSession, event: MouseEvent) !bool {
        if (self.pty == null) return false;
        const screen = self.activeScreen();
        if (self.pty) |*pty| {
            self.pty_write_mutex.lock();
            defer self.pty_write_mutex.unlock();
            return self.input.reportMouseEvent(pty, event, screen.grid.rows, screen.grid.cols);
        }
        return false;
    }

    pub fn sendText(self: *TerminalSession, text: []const u8) !void {
        if (text.len == 0) return;
        const log = app_logger.logger("terminal.input");
        if (log.enabled_file or log.enabled_console) {
            log.logf("sendText len={d}", .{text.len});
        }
        if (self.pty) |*pty| {
            self.pty_write_mutex.lock();
            defer self.pty_write_mutex.unlock();
            try input_mod.sendText(pty, text);
        }
    }

    pub fn resize(self: *TerminalSession, rows: u16, cols: u16) !void {
        self.state_mutex.lock();
        const old_cols: u16 = self.primary.grid.cols;
        const old_rows: u16 = self.primary.grid.rows;
        self.history.ensureViewCache(old_cols, self.primary.defaultCell());
        const old_history_len: usize = self.history.scrollbackCount();
        const old_total_lines: usize = old_history_len + @as(usize, old_rows);
        const old_scroll_offset: usize = self.history.scrollOffset();
        const old_cursor = self.primary.cursorPos();
        const old_selection = self.history.selectionState();

        if (cols != old_cols and cols > 0 and old_cols > 0) {
            try self.reflowResizePrimary(rows, cols, old_rows, old_cols, old_total_lines, old_scroll_offset, old_cursor, old_selection);
        } else {
            try self.primary.resize(rows, cols);
            try self.alt.resize(rows, cols);
            if (cols != old_cols) {
                try self.history.resizePreserve(cols, self.primary.defaultCell());
            }
            if (self.isAltActive()) {
                const max_offset = self.history.maxScrollOffset(self.primary.grid.rows);
                if (self.history.saved_scrollback_offset > max_offset) {
                    self.history.saved_scrollback_offset = max_offset;
                }
                self.history.scrollback_offset = 0;
            } else {
                self.setScrollOffset(self.history.scrollback_offset);
            }
            self.clearSelection();
        }

        const log = app_logger.logger("terminal.core");
        log.logf("terminal resize rows={d} cols={d} scrollback_cols={d}", .{ rows, cols, self.primary.grid.cols });
        log.logStdout("terminal resize rows={d} cols={d}", .{ rows, cols });
        var pty = self.pty;
        const cell_width = self.cell_width;
        const cell_height = self.cell_height;
        self.state_mutex.unlock();
        if (pty) |*pty_ref| {
            const size = PtySize{
                .rows = rows,
                .cols = cols,
                .cell_width = cell_width,
                .cell_height = cell_height,
            };
            try pty_ref.resize(size);
        }
    }

    const RowMapEntry = struct {
        line_index: usize,
        col_offset: usize,
    };

    fn mapLogicalToGlobal(line_index: usize, col: usize, line_lengths: []const usize, line_row_starts: []const usize, cols: usize) ?struct { row: usize, col: usize } {
        if (line_index >= line_lengths.len or line_index >= line_row_starts.len) return null;
        const line_len = line_lengths[line_index];
        const row_start = line_row_starts[line_index];
        if (line_len == 0) return .{ .row = row_start, .col = 0 };
        const col_index = if (col >= line_len) line_len - 1 else col;
        const row_offset = col_index / cols;
        const col_in_row = col_index % cols;
        return .{ .row = row_start + row_offset, .col = col_in_row };
    }

    fn reflowResizePrimary(
        self: *TerminalSession,
        rows: u16,
        cols: u16,
        old_rows: u16,
        old_cols: u16,
        old_total_lines: usize,
        old_scroll_offset: usize,
        old_cursor: CursorPos,
        old_selection: ?types.TerminalSelection,
    ) !void {
        const allocator = self.allocator;
        const default_cell = self.primary.defaultCell();
        const old_cols_usize = @as(usize, old_cols);
        const new_cols_usize = @as(usize, cols);
        const old_history_len = self.history.scrollbackCount();

        var row_map = std.ArrayList(RowMapEntry).empty;
        defer row_map.deinit(allocator);
        try row_map.resize(allocator, old_total_lines);

        var line_cells = std.ArrayList(Cell).empty;
        defer line_cells.deinit(allocator);
        var all_cells = std.ArrayList(Cell).empty;
        defer all_cells.deinit(allocator);
        var line_starts = std.ArrayList(usize).empty;
        defer line_starts.deinit(allocator);
        var line_lengths = std.ArrayList(usize).empty;
        defer line_lengths.deinit(allocator);
        var line_wrapped = std.ArrayList(bool).empty;
        defer line_wrapped.deinit(allocator);
        const cursor_global_row = old_history_len + old_cursor.row;
        var required_len: usize = 0;

        var fallback_row = std.ArrayList(Cell).empty;
        defer fallback_row.deinit(allocator);
        try fallback_row.resize(allocator, old_cols_usize);
        for (fallback_row.items) |*cell| cell.* = default_cell;

        var line_index: usize = 0;
        var last_row_wrapped = false;
        var global_row: usize = 0;
        while (global_row < old_total_lines) : (global_row += 1) {
            const row_cells = if (global_row < old_history_len)
                self.history.scrollbackRow(global_row) orelse fallback_row.items
            else blk: {
                const row = global_row - old_history_len;
                const row_start = row * old_cols_usize;
                break :blk self.primary.grid.cells.items[row_start .. row_start + old_cols_usize];
            };
            const wrapped = if (global_row < old_history_len)
                self.history.scrollbackRowWrapped(global_row)
            else
                self.primary.grid.rowWrapped(global_row - old_history_len);
            last_row_wrapped = wrapped;

            row_map.items[global_row] = .{ .line_index = line_index, .col_offset = line_cells.items.len };
            const row_offset = row_map.items[global_row].col_offset;
            if (global_row == cursor_global_row) {
                const cursor_offset = row_offset + old_cursor.col + 1;
                if (cursor_offset > required_len) required_len = cursor_offset;
            }
            if (old_selection) |selection| {
                if (global_row == selection.start.row) {
                    const sel_offset = row_offset + selection.start.col + 1;
                    if (sel_offset > required_len) required_len = sel_offset;
                }
                if (global_row == selection.end.row) {
                    const sel_offset = row_offset + selection.end.col + 1;
                    if (sel_offset > required_len) required_len = sel_offset;
                }
            }
            var row_len: usize = old_cols_usize;
            if (!wrapped) {
                row_len = 0;
                var col: usize = old_cols_usize;
                while (col > 0) {
                    col -= 1;
                    const cell = row_cells[col];
                    const is_default = cell.codepoint == default_cell.codepoint and
                        cell.width == default_cell.width and
                        cell.attrs.fg.r == default_cell.attrs.fg.r and
                        cell.attrs.fg.g == default_cell.attrs.fg.g and
                        cell.attrs.fg.b == default_cell.attrs.fg.b and
                        cell.attrs.fg.a == default_cell.attrs.fg.a and
                        cell.attrs.bg.r == default_cell.attrs.bg.r and
                        cell.attrs.bg.g == default_cell.attrs.bg.g and
                        cell.attrs.bg.b == default_cell.attrs.bg.b and
                        cell.attrs.bg.a == default_cell.attrs.bg.a and
                        cell.attrs.bold == default_cell.attrs.bold and
                        cell.attrs.reverse == default_cell.attrs.reverse and
                        cell.attrs.underline == default_cell.attrs.underline and
                        cell.attrs.underline_color.r == default_cell.attrs.underline_color.r and
                        cell.attrs.underline_color.g == default_cell.attrs.underline_color.g and
                        cell.attrs.underline_color.b == default_cell.attrs.underline_color.b and
                        cell.attrs.underline_color.a == default_cell.attrs.underline_color.a and
                        cell.attrs.link_id == default_cell.attrs.link_id;
                    if (!is_default) {
                        row_len = col + 1;
                        break;
                    }
                }
            }
            if (row_len > 0) {
                try line_cells.appendSlice(allocator, row_cells[0..row_len]);
            }

            if (!wrapped) {
                if (required_len > line_cells.items.len) {
                    const prev_len = line_cells.items.len;
                    try line_cells.resize(allocator, required_len);
                    for (line_cells.items[prev_len..required_len]) |*cell| cell.* = default_cell;
                }
                try line_starts.append(allocator, all_cells.items.len);
                try line_lengths.append(allocator, line_cells.items.len);
                try line_wrapped.append(allocator, false);
                try all_cells.appendSlice(allocator, line_cells.items);
                line_cells.clearRetainingCapacity();
                required_len = 0;
                line_index += 1;
            }
        }

        if (line_cells.items.len > 0) {
            if (required_len > line_cells.items.len) {
                const prev_len = line_cells.items.len;
                try line_cells.resize(allocator, required_len);
                for (line_cells.items[prev_len..required_len]) |*cell| cell.* = default_cell;
            }
            try line_starts.append(allocator, all_cells.items.len);
            try line_lengths.append(allocator, line_cells.items.len);
            try line_wrapped.append(allocator, last_row_wrapped);
            try all_cells.appendSlice(allocator, line_cells.items);
            line_cells.clearRetainingCapacity();
        }

        var rows_cells = std.ArrayList(Cell).empty;
        defer rows_cells.deinit(allocator);
        var rows_wraps = std.ArrayList(bool).empty;
        defer rows_wraps.deinit(allocator);
        var line_row_starts = std.ArrayList(usize).empty;
        defer line_row_starts.deinit(allocator);

        var li: usize = 0;
        while (li < line_lengths.items.len) : (li += 1) {
            try line_row_starts.append(allocator, rows_wraps.items.len);
            const line_len = line_lengths.items[li];
            if (line_len == 0) {
                const row_start = rows_cells.items.len;
                try rows_cells.resize(allocator, row_start + new_cols_usize);
                for (rows_cells.items[row_start .. row_start + new_cols_usize]) |*cell| cell.* = default_cell;
                try rows_wraps.append(allocator, line_wrapped.items[li]);
                continue;
            }
            var idx: usize = 0;
            const line_start = line_starts.items[li];
            while (idx < line_len) : (idx += new_cols_usize) {
                const row_start = rows_cells.items.len;
                try rows_cells.resize(allocator, row_start + new_cols_usize);
                for (rows_cells.items[row_start .. row_start + new_cols_usize]) |*cell| cell.* = default_cell;
                const remaining = line_len - idx;
                const copy_len = if (remaining > new_cols_usize) new_cols_usize else remaining;
                std.mem.copyForwards(Cell, rows_cells.items[row_start .. row_start + copy_len], all_cells.items[line_start + idx .. line_start + idx + copy_len]);
                const is_last = remaining <= new_cols_usize;
                try rows_wraps.append(allocator, if (is_last) line_wrapped.items[li] else true);
            }
        }

        const total_rows = rows_wraps.items.len;
        const max_scrollback = self.history.scrollbackCapacity();
        const visible_rows = @as(usize, rows);
        const keep_rows = if (total_rows > max_scrollback + visible_rows) max_scrollback + visible_rows else total_rows;
        const drop_rows = total_rows - keep_rows;
        const scrollback_rows = if (keep_rows > visible_rows) keep_rows - visible_rows else 0;

        var new_scrollback = try scrollback_buffer.ScrollbackBuffer.init(allocator, max_scrollback);
        var row_idx: usize = 0;
        while (row_idx < scrollback_rows) : (row_idx += 1) {
            const src_row = drop_rows + row_idx;
            const src_start = src_row * new_cols_usize;
            const slice = rows_cells.items[src_start .. src_start + new_cols_usize];
            _ = try new_scrollback.pushLine(slice, rows_wraps.items[src_row]);
        }

        self.history.scrollback.deinit();
        self.history.scrollback = new_scrollback;
        self.history.markScrollbackChanged();

        try self.primary.resize(rows, cols);
        try self.alt.resize(rows, cols);

        row_idx = 0;
        while (row_idx < visible_rows) : (row_idx += 1) {
            const src_row = drop_rows + scrollback_rows + row_idx;
            const dest_start = row_idx * new_cols_usize;
            if (src_row < keep_rows) {
                const src_start = src_row * new_cols_usize;
                std.mem.copyForwards(Cell, self.primary.grid.cells.items[dest_start .. dest_start + new_cols_usize], rows_cells.items[src_start .. src_start + new_cols_usize]);
                self.primary.grid.setRowWrapped(row_idx, rows_wraps.items[src_row]);
            } else {
                for (self.primary.grid.cells.items[dest_start .. dest_start + new_cols_usize]) |*cell| cell.* = default_cell;
                self.primary.grid.setRowWrapped(row_idx, false);
            }
        }
        self.primary.grid.markDirtyAll();

        const old_start_line = if (old_total_lines > @as(usize, old_rows) + old_scroll_offset)
            old_total_lines - @as(usize, old_rows) - old_scroll_offset
        else
            0;
        var new_start_line = if (keep_rows > visible_rows) keep_rows - visible_rows else 0;
        if (old_scroll_offset > 0 and old_start_line < row_map.items.len) {
            const mapping = row_map.items[old_start_line];
            if (mapLogicalToGlobal(mapping.line_index, mapping.col_offset, line_lengths.items, line_row_starts.items, new_cols_usize)) |pos| {
                if (pos.row >= drop_rows) {
                    const adjusted = pos.row - drop_rows;
                    if (adjusted <= keep_rows - visible_rows) {
                        new_start_line = adjusted;
                    }
                }
            }
        }
        const new_total_lines = scrollback_rows + visible_rows;
        var new_scroll_offset = if (new_total_lines > visible_rows) new_total_lines - visible_rows - new_start_line else 0;
        if (old_scroll_offset == 0) {
            new_scroll_offset = 0;
        }

        if (self.isAltActive()) {
            self.history.scrollback_offset = 0;
        } else {
            self.history.scrollback_offset = new_scroll_offset;
            self.view_cache_request_offset.store(@intCast(self.history.scrollback_offset), .release);
            self.view_cache_pending.store(true, .release);
            self.io_wait_cond.signal();
        }
        const max_offset = self.history.maxScrollOffset(rows);
        if (self.history.saved_scrollback_offset > max_offset) {
            self.history.saved_scrollback_offset = max_offset;
        }

        if (old_selection) |selection| {
            const start_row = selection.start.row;
            const end_row = selection.end.row;
            const start_col = selection.start.col;
            const end_col = selection.end.col;
            if (start_row < row_map.items.len and end_row < row_map.items.len) {
                const start_map = row_map.items[start_row];
                const end_map = row_map.items[end_row];
                const start_pos = mapLogicalToGlobal(start_map.line_index, start_map.col_offset + start_col, line_lengths.items, line_row_starts.items, new_cols_usize);
                const end_pos = mapLogicalToGlobal(end_map.line_index, end_map.col_offset + end_col, line_lengths.items, line_row_starts.items, new_cols_usize);
                if (start_pos != null and end_pos != null) {
                    const start_global = start_pos.?;
                    const end_global = end_pos.?;
                    if (start_global.row >= drop_rows and end_global.row >= drop_rows) {
                        const new_start_row = start_global.row - drop_rows;
                        const new_end_row = end_global.row - drop_rows;
                        self.history.selection.selection.active = selection.active;
                        self.history.selection.selection.selecting = selection.selecting;
                        self.history.selection.selection.start = .{ .row = new_start_row, .col = start_global.col };
                        self.history.selection.selection.end = .{ .row = new_end_row, .col = end_global.col };
                    } else {
                        self.history.clearSelection();
                    }
                } else {
                    self.history.clearSelection();
                }
            } else {
                self.history.clearSelection();
            }
        } else {
            self.history.clearSelection();
        }

        if (cursor_global_row < row_map.items.len) {
            const cursor_map = row_map.items[cursor_global_row];
            const cursor_pos = mapLogicalToGlobal(cursor_map.line_index, cursor_map.col_offset + old_cursor.col, line_lengths.items, line_row_starts.items, new_cols_usize);
            if (cursor_pos) |pos| {
                const row_after_drop = if (pos.row >= drop_rows) pos.row - drop_rows else 0;
                const screen_row = if (row_after_drop >= scrollback_rows) row_after_drop - scrollback_rows else 0;
                const clamped_row = if (screen_row >= visible_rows) visible_rows - 1 else screen_row;
                const clamped_col = if (pos.col >= new_cols_usize) new_cols_usize - 1 else pos.col;
                self.primary.setCursor(clamped_row, clamped_col);
            }
        }

        self.primary.wrap_next = false;
    }

    pub fn setCellSize(self: *TerminalSession, cell_width: u16, cell_height: u16) void {
        self.cell_width = cell_width;
        self.cell_height = cell_height;
    }

    pub fn handleControl(self: *TerminalSession, byte: u8) void {
        const screen = self.activeScreen();
        switch (byte) {
            0x08 => { // BS
                screen.backspace();
            },
            0x09 => { // TAB (every 8 columns)
                screen.tab();
            },
            0x0A => { // LF
                self.newline();
                const log = app_logger.logger("terminal.trace.control");
                if (log.enabled_file or log.enabled_console) {
                    log.logf("control=LF row={d} col={d}", .{ screen.cursor.row, screen.cursor.col });
                }
            },
            0x0D => { // CR
                screen.carriageReturn();
                const log = app_logger.logger("terminal.trace.control");
                if (log.enabled_file or log.enabled_console) {
                    log.logf("control=CR row={d} col={d}", .{ screen.cursor.row, screen.cursor.col });
                }
            },
            0x0E => { // SO (Shift Out) -> G1
                self.parser.gl_charset = self.parser.g1_charset;
            },
            0x0F => { // SI (Shift In) -> G0
                self.parser.gl_charset = self.parser.g0_charset;
            },
            0x1B => { // ESC
                self.parser.esc_state = .esc;
                self.parser.stream.reset();
                self.parser.csi.reset();
                self.parser.osc_state = .idle;
                self.parser.apc_state = .idle;
                self.parser.dcs_state = .idle;
            },
            else => {},
        }
    }

    pub fn parseDcs(self: *TerminalSession, payload: []const u8) void {
        protocol_dcs_apc.parseDcs(self, payload);
    }

    pub fn parseApc(self: *TerminalSession, payload: []const u8) void {
        protocol_dcs_apc.parseApc(self, payload);
    }

    pub fn parseOsc(self: *TerminalSession, payload: []const u8, terminator: OscTerminator) void {
        protocol_osc.parseOsc(self, payload, terminator);
    }
    pub fn appendHyperlink(self: *TerminalSession, uri: []const u8) ?u32 {
        if (uri.len == 0) return 0;
        if (self.hyperlink_table.items.len >= max_hyperlinks) {
            for (self.hyperlink_table.items) |link| {
                self.allocator.free(link.uri);
            }
            self.hyperlink_table.clearRetainingCapacity();
        }
        const duped = self.allocator.dupe(u8, uri) catch return null;
        _ = self.hyperlink_table.append(self.allocator, .{ .uri = duped }) catch {
            self.allocator.free(duped);
            return null;
        };
        return @intCast(self.hyperlink_table.items.len);
    }

    pub fn parseKittyGraphics(self: *TerminalSession, payload: []const u8) void {
        kitty_mod.parseKittyGraphics(self, payload);
    }

    pub fn handleCsi(self: *TerminalSession, action: csi_mod.CsiAction) void {
        protocol_csi.handleCsi(self, action);
    }

    pub fn resetState(self: *TerminalSession) void {
        self.parser.reset();
        self.primary.resetState();
        self.alt.resetState();
        self.input.resetMouse();
        self.current_hyperlink_id = 0;
        self.app_keypad = false;
        self.primary.clear();
        self.alt.clear();
        kitty_mod.clearKittyImages(self);
        _ = self.clear_generation.fetchAdd(1, .acq_rel);
    }

    pub fn eraseDisplay(self: *TerminalSession, mode: i32) void {
        const screen = self.activeScreen();
        const blank_cell = screen.blankCell();
        screen.eraseDisplay(mode, blank_cell);
        self.force_full_damage.store(true, .release);
        if (mode == 2 or mode == 3) {
            _ = self.clear_generation.fetchAdd(1, .acq_rel);
        }
    }

    pub fn eraseLine(self: *TerminalSession, mode: i32) void {
        const screen = self.activeScreen();
        const blank_cell = screen.blankCell();
        screen.eraseLine(mode, blank_cell);
        self.force_full_damage.store(true, .release);
    }

    pub fn insertChars(self: *TerminalSession, count: usize) void {
        const screen = self.activeScreen();
        const blank_cell = screen.blankCell();
        screen.insertChars(count, blank_cell);
    }

    pub fn deleteChars(self: *TerminalSession, count: usize) void {
        const screen = self.activeScreen();
        const blank_cell = screen.blankCell();
        screen.deleteChars(count, blank_cell);
    }

    pub fn eraseChars(self: *TerminalSession, count: usize) void {
        const screen = self.activeScreen();
        const blank_cell = screen.blankCell();
        screen.eraseChars(count, blank_cell);
    }

    pub fn insertLines(self: *TerminalSession, count: usize) void {
        const screen = self.activeScreen();
        const blank_cell = screen.blankCell();
        screen.insertLines(count, blank_cell);
    }

    pub fn deleteLines(self: *TerminalSession, count: usize) void {
        const screen = self.activeScreen();
        const blank_cell = screen.blankCell();
        screen.deleteLines(count, blank_cell);
    }

    fn isFullScrollRegion(self: *TerminalSession) bool {
        return self.activeScreenConst().isFullScrollRegion();
    }

    fn pushScrollbackRow(self: *TerminalSession, row: usize) void {
        if (self.isAltActive()) return;
        const screen = &self.primary;
        const cols = @as(usize, screen.grid.cols);
        if (cols == 0 or screen.grid.rows == 0) return;
        if (row >= @as(usize, screen.grid.rows)) return;
        const row_start = row * cols;
        const wrapped = screen.grid.rowWrapped(row);
        self.history.pushRow(screen.grid.cells.items[row_start .. row_start + cols], wrapped);
        self.kitty_primary.scrollback_total += 1;
        const log = app_logger.logger("terminal.core");
        log.logf("scrollback push row={d} total={d}", .{ row, self.history.scrollbackCount() });
        log.logStdout("scrollback push total={d}", .{self.history.scrollbackCount()});
    }

    pub fn scrollRegionUp(self: *TerminalSession, count: usize) void {
        const log = app_logger.logger("terminal.core");
        const screen = self.activeScreen();
        log.logf("scroll region up count={d} top={d} bottom={d}", .{ count, screen.scroll_top, screen.scroll_bottom });
        log.logStdout("scroll region up count={d}", .{count});
        const cols = @as(usize, screen.grid.cols);
        if (cols == 0 or screen.grid.rows == 0) return;
        const n = @min(count, screen.scroll_bottom - screen.scroll_top + 1);
        if (n == 0) return;
        const blank_cell = screen.blankCell();
        if (self.isFullScrollRegion()) {
            var row: usize = 0;
            while (row < n) : (row += 1) {
                self.pushScrollbackRow(screen.scroll_top + row);
            }
            kitty_mod.updateKittyPlacementsForScroll(self);
            _ = self.clear_generation.fetchAdd(1, .acq_rel);
        }
        screen.scrollRegionUpBy(n, blank_cell);
        self.force_full_damage.store(true, .release);
        if (!self.isFullScrollRegion()) {
            kitty_mod.shiftKittyPlacementsUp(self, screen.scroll_top, screen.scroll_bottom, n);
        }
    }

    pub fn scrollRegionDown(self: *TerminalSession, count: usize) void {
        const screen = self.activeScreen();
        const cols = @as(usize, screen.grid.cols);
        if (cols == 0 or screen.grid.rows == 0) return;
        const n = @min(count, screen.scroll_bottom - screen.scroll_top + 1);
        if (n == 0) return;
        const blank_cell = screen.blankCell();
        screen.scrollRegionDownBy(n, blank_cell);
        kitty_mod.shiftKittyPlacementsDown(self, screen.scroll_top, screen.scroll_bottom, n);
        _ = self.clear_generation.fetchAdd(1, .acq_rel);
        self.force_full_damage.store(true, .release);
    }

    fn applySgr(self: *TerminalSession, action: csi_mod.CsiAction) void {
        protocol_csi.applySgr(self, action);
    }

    pub fn paletteColor(self: *const TerminalSession, idx: u8) types.Color {
        return self.palette_current[idx];
    }

    pub fn handleCodepoint(self: *TerminalSession, codepoint: u32) void {
        if (codepoint == 0) return;
        if (codepoint > 0x10FFFF or (codepoint >= 0xD800 and codepoint <= 0xDFFF)) return;

        var cp = codepoint;
        if (self.parser.gl_charset == .dec_special) {
            cp = screen_mod.mapDecSpecial(codepoint);
        }

        const screen = self.activeScreen();
        const rows = @as(usize, screen.grid.rows);
        const cols = @as(usize, screen.grid.cols);
        if (rows == 0 or cols == 0) return;
        if (screen.cursor.row >= rows) return;
        while (true) {
            switch (screen.prepareWrite()) {
                .done => return,
                .need_newline => self.newline(),
                .proceed => break,
            }
        }

        var attrs = screen.current_attrs;
        if (self.osc_hyperlink_active and self.current_hyperlink_id > 0) {
            attrs.link_id = self.current_hyperlink_id;
            attrs.underline = true;
        } else {
            attrs.link_id = 0;
        }
        if (cp == 0x2502) {
            const log = app_logger.logger("terminal.trace.scope");
            if (log.enabled_file or log.enabled_console) {
                log.logf(
                    "scope_glyph row={d} col={d} origin={any} scroll_top={d} scroll_bottom={d}",
                    .{ screen.cursor.row, screen.cursor.col, screen.origin_mode, screen.scroll_top, screen.scroll_bottom },
                );
            }
        }
        screen.writeCodepoint(cp, attrs);
    }

    pub fn handleAsciiSlice(self: *TerminalSession, bytes: []const u8) void {
        if (bytes.len == 0) return;
        const screen = self.activeScreen();
        const rows = @as(usize, screen.grid.rows);
        const cols = @as(usize, screen.grid.cols);
        if (rows == 0 or cols == 0) return;
        if (screen.cursor.row >= rows) return;

        var attrs = screen.current_attrs;
        if (self.osc_hyperlink_active and self.current_hyperlink_id > 0) {
            attrs.link_id = self.current_hyperlink_id;
            attrs.underline = true;
        } else {
            attrs.link_id = 0;
        }
        const use_dec_special = self.parser.gl_charset == .dec_special;

        var i: usize = 0;
        while (i < bytes.len) {
            switch (screen.prepareWrite()) {
                .done => break,
                .need_newline => {
                    self.newline();
                    continue;
                },
                .proceed => {},
            }

            const run_len = screen.writeAsciiRun(bytes[i..], attrs, use_dec_special);
            if (run_len == 0) break;
            i += run_len;
        }
    }

    pub fn newline(self: *TerminalSession) void {
        const screen = self.activeScreen();
        switch (screen.newlineAction()) {
            .moved => {},
            .scroll_region => self.scrollRegionUp(1),
            .scroll_full => self.scrollUp(),
        }
    }

    fn scrollUp(self: *TerminalSession) void {
        const log = app_logger.logger("terminal.core");
        const screen = self.activeScreen();
        log.logf("scroll up rows={d} cols={d}", .{ screen.grid.rows, screen.grid.cols });
        log.logStdout("scroll up rows={d} cols={d}", .{ screen.grid.rows, screen.grid.cols });
        const cols = @as(usize, screen.grid.cols);
        const rows = @as(usize, screen.grid.rows);
        if (rows == 0 or cols == 0) return;

        if (self.isFullScrollRegion()) {
            self.pushScrollbackRow(0);
            kitty_mod.updateKittyPlacementsForScroll(self);
            _ = self.clear_generation.fetchAdd(1, .acq_rel);
        }
        const blank_cell = screen.blankCell();
        screen.scrollUp(blank_cell);
        self.force_full_damage.store(true, .release);
        if (!self.isFullScrollRegion()) {
            kitty_mod.shiftKittyPlacementsUp(self, 0, rows - 1, 1);
        }
    }

    pub fn getCell(self: *TerminalSession, row: usize, col: usize) Cell {
        const screen = self.activeScreenConst();
        return screen.cellAtOr(row, col, self.primary.defaultCell());
    }

    pub fn getCursorPos(self: *TerminalSession) CursorPos {
        return self.activeScreenConst().cursorPos();
    }

    pub fn gridRows(self: *TerminalSession) usize {
        return self.activeScreenConst().rowCount();
    }

    pub fn gridCols(self: *TerminalSession) usize {
        return self.activeScreenConst().colCount();
    }

    pub fn scrollbackCount(self: *TerminalSession) usize {
        if (self.isAltActive()) return 0;
        self.history.ensureViewCache(self.primary.grid.cols, self.primary.defaultCell());
        return self.history.scrollbackCount();
    }

    pub fn scrollbackRow(self: *TerminalSession, index: usize) ?[]const Cell {
        if (self.isAltActive()) return null;
        self.history.ensureViewCache(self.primary.grid.cols, self.primary.defaultCell());
        return self.history.scrollbackRow(index);
    }

    pub fn scrollOffset(self: *TerminalSession) usize {
        if (self.isAltActive()) return 0;
        return self.history.scrollOffset();
    }

    pub fn setScrollOffset(self: *TerminalSession, offset: usize) void {
        if (self.isAltActive()) {
            self.history.scrollback_offset = 0;
            return;
        }
        self.history.ensureViewCache(self.primary.grid.cols, self.primary.defaultCell());
        self.history.setScrollOffset(self.primary.grid.rows, offset);
        self.primary.markDirtyAll();
        self.view_cache_request_offset.store(@intCast(self.history.scrollOffset()), .release);
        self.view_cache_pending.store(true, .release);
        self.io_wait_cond.signal();
        self.updateViewCacheForScroll();
        const log = app_logger.logger("terminal.core");
        const max_offset = self.history.maxScrollOffset(self.primary.grid.rows);
        log.logf("set scroll offset={d} max={d}", .{ self.history.scrollOffset(), max_offset });
        log.logStdout("set scroll offset={d} max={d}", .{ self.history.scrollOffset(), max_offset });
    }

    pub fn scrollBy(self: *TerminalSession, delta: isize) void {
        if (self.isAltActive()) return;
        if (delta == 0) return;
        self.history.ensureViewCache(self.primary.grid.cols, self.primary.defaultCell());
        self.history.scrollBy(self.primary.grid.rows, delta);
        self.primary.markDirtyAll();
        self.view_cache_request_offset.store(@intCast(self.history.scrollOffset()), .release);
        self.view_cache_pending.store(true, .release);
        self.io_wait_cond.signal();
        self.updateViewCacheForScroll();
        const log = app_logger.logger("terminal.core");
        const max_offset = self.history.maxScrollOffset(self.primary.grid.rows);
        log.logf("scroll by delta={d} offset={d} max={d}", .{ delta, self.history.scrollOffset(), max_offset });
        log.logStdout("scroll by delta={d} offset={d} max={d}", .{ delta, self.history.scrollOffset(), max_offset });
    }

    pub fn updateViewCacheForScroll(self: *TerminalSession) void {
        if (self.state_mutex.tryLock()) {
            const offset: usize = @intCast(self.view_cache_request_offset.load(.acquire));
            self.updateViewCacheNoLock(self.output_generation.load(.acquire), offset);
            self.state_mutex.unlock();
        }
    }

    pub fn updateViewCacheForScrollLocked(self: *TerminalSession) void {
        const offset: usize = @intCast(self.view_cache_request_offset.load(.acquire));
        self.updateViewCacheNoLock(self.output_generation.load(.acquire), offset);
    }

    fn keyModeFlags(self: *TerminalSession) u32 {
        return self.activeScreen().keyModeFlags();
    }

    pub fn keyModeFlagsValue(self: *TerminalSession) u32 {
        return self.keyModeFlags();
    }

    pub fn keyModePush(self: *TerminalSession, flags: u32) void {
        self.activeScreen().keyModePush(flags);
        self.updateInputSnapshot();
    }

    pub fn keyModePop(self: *TerminalSession, count: usize) void {
        self.activeScreen().keyModePop(count);
        self.updateInputSnapshot();
    }

    pub fn keyModeModify(self: *TerminalSession, flags: u32, mode: u32) void {
        self.activeScreen().keyModeModify(flags, mode);
        self.updateInputSnapshot();
    }

    pub fn keyModeQuery(self: *TerminalSession) void {
        const flags = self.keyModeFlags();
        if (self.pty) |*pty| {
            var buf: [32]u8 = undefined;
            const seq = std.fmt.bufPrint(&buf, "\x1b[?{d}u", .{flags}) catch return;
            _ = pty.write(seq) catch {};
        }
    }

    pub fn setCursorStyle(self: *TerminalSession, mode: i32) void {
        self.activeScreen().setCursorStyle(mode);
    }

    pub fn saveCursor(self: *TerminalSession) void {
        self.activeScreen().saveCursor();
    }

    pub fn setKeypadMode(self: *TerminalSession, enabled: bool) void {
        self.app_keypad = enabled;
        self.updateInputSnapshot();
    }

    pub fn restoreCursor(self: *TerminalSession) void {
        self.activeScreen().restoreCursor();
    }

    pub fn enterAltScreen(self: *TerminalSession, clear: bool, save_cursor: bool) void {
        if (self.isAltActive()) return;
        if (save_cursor) {
            self.saveCursor();
        }
        self.history.saveScrollOffset();
        self.clearSelection();
        self.active = .alt;
        kitty_mod.clearKittyImages(self);
        if (clear) {
            self.activeScreen().clear();
            self.activeScreen().setCursor(0, 0);
        }
        self.activeScreen().markDirtyAll();
    }

    pub fn exitAltScreen(self: *TerminalSession, restore_cursor: bool) void {
        if (!self.isAltActive()) return;
        kitty_mod.clearKittyImages(self);
        self.active = .primary;
        self.alt_exit_pending.store(true, .release);
        self.alt_exit_time_ms.store(std.time.milliTimestamp(), .release);
        self.history.restoreScrollOffset(self.primary.grid.rows);
        self.clearSelection();
        if (restore_cursor) {
            self.restoreCursor();
        }
        self.activeScreen().markDirtyAll();
    }

    pub fn snapshot(self: *TerminalSession) TerminalSnapshot {
        const screen = self.activeScreenConst();
        const view = screen.snapshotView();
        const alt_active = self.isAltActive();
        const kitty = kitty_mod.kittyStateConst(self);
        return TerminalSnapshot{
            .rows = view.rows,
            .cols = view.cols,
            .cells = view.cells,
            .dirty_rows = view.dirty_rows,
            .dirty_cols_start = view.dirty_cols_start,
            .dirty_cols_end = view.dirty_cols_end,
            .cursor = view.cursor,
            .cursor_style = view.cursor_style,
            .cursor_visible = view.cursor_visible,
            .dirty = view.dirty,
            .damage = view.damage,
            .alt_active = alt_active,
            .generation = self.output_generation.load(.acquire),
            .kitty_images = kitty.images.items,
            .kitty_placements = kitty.placements.items,
            .kitty_generation = kitty.generation,
        };
    }

    pub fn renderCache(self: *TerminalSession) *const RenderCache {
        const idx = self.render_cache_index.load(.acquire);
        return &self.render_caches[idx];
    }

    pub fn syncUpdatesActive(self: *const TerminalSession) bool {
        return self.sync_updates_active;
    }

    pub fn setSyncUpdates(self: *TerminalSession, enabled: bool) void {
        if (self.sync_updates_active == enabled) return;
        self.sync_updates_active = enabled;
        if (!enabled) {
            self.activeScreen().markDirtyAll();
        }
        self.force_full_damage.store(true, .release);
        const offset: usize = self.history.scrollOffset();
        self.updateViewCacheNoLock(self.output_generation.load(.acquire), offset);
    }

    pub fn takeOscClipboard(self: *TerminalSession) ?[]const u8 {
        if (!self.osc_clipboard_pending) return null;
        self.osc_clipboard_pending = false;
        return self.osc_clipboard.items;
    }

    pub fn hyperlinkUri(self: *const TerminalSession, link_id: u32) ?[]const u8 {
        if (link_id == 0) return null;
        const idx = link_id - 1;
        if (idx >= self.hyperlink_table.items.len) return null;
        return self.hyperlink_table.items[idx].uri;
    }

    pub fn currentCwd(self: *const TerminalSession) []const u8 {
        return self.cwd;
    }

    pub fn clearDirty(self: *TerminalSession) void {
        self.activeScreen().clearDirty();
    }

    pub fn clearSelection(self: *TerminalSession) void {
        self.history.clearSelection();
        self.view_cache_request_offset.store(@intCast(self.history.scrollOffset()), .release);
        self.view_cache_pending.store(true, .release);
        self.io_wait_cond.signal();
    }

    pub fn startSelection(self: *TerminalSession, row: usize, col: usize) void {
        if (self.isAltActive()) return;
        self.history.startSelection(row, col);
        self.view_cache_request_offset.store(@intCast(self.history.scrollOffset()), .release);
        self.view_cache_pending.store(true, .release);
        self.io_wait_cond.signal();
    }

    pub fn updateSelection(self: *TerminalSession, row: usize, col: usize) void {
        if (self.isAltActive()) return;
        self.history.updateSelection(row, col);
        self.view_cache_request_offset.store(@intCast(self.history.scrollOffset()), .release);
        self.view_cache_pending.store(true, .release);
        self.io_wait_cond.signal();
    }

    pub fn finishSelection(self: *TerminalSession) void {
        if (self.isAltActive()) return;
        self.history.finishSelection();
        self.view_cache_request_offset.store(@intCast(self.history.scrollOffset()), .release);
        self.view_cache_pending.store(true, .release);
        self.io_wait_cond.signal();
    }

    pub fn selectionState(self: *TerminalSession) ?TerminalSelection {
        if (self.isAltActive()) return null;
        return self.history.selectionState();
    }

    pub fn bracketedPasteEnabled(self: *TerminalSession) bool {
        return self.bracketed_paste;
    }

    pub fn mouseReportingEnabled(self: *TerminalSession) bool {
        const input_snapshot = self.input_snapshot;
        return input_snapshot.mouse_mode_x10.load(.acquire) or input_snapshot.mouse_mode_button.load(.acquire) or input_snapshot.mouse_mode_any.load(.acquire);
    }

    pub fn isAlive(self: *TerminalSession) bool {
        _ = self;
        return false;
    }

    pub fn getDamage(self: *TerminalSession) ?struct {
        start_row: usize,
        end_row: usize,
        start_col: usize,
        end_col: usize,
    } {
        return self.activeScreenConst().getDamage();
    }

    pub fn markDirty(self: *TerminalSession) void {
        self.activeScreen().markDirtyAll();
    }
};

pub const InputSnapshot = struct {
    app_cursor_keys: std.atomic.Value(bool),
    app_keypad: std.atomic.Value(bool),
    key_mode_flags: std.atomic.Value(u32),
    mouse_mode_x10: std.atomic.Value(bool),
    mouse_mode_button: std.atomic.Value(bool),
    mouse_mode_any: std.atomic.Value(bool),
    mouse_mode_sgr: std.atomic.Value(bool),

    pub fn init() InputSnapshot {
        return .{
            .app_cursor_keys = std.atomic.Value(bool).init(false),
            .app_keypad = std.atomic.Value(bool).init(false),
            .key_mode_flags = std.atomic.Value(u32).init(0),
            .mouse_mode_x10 = std.atomic.Value(bool).init(false),
            .mouse_mode_button = std.atomic.Value(bool).init(false),
            .mouse_mode_any = std.atomic.Value(bool).init(false),
            .mouse_mode_sgr = std.atomic.Value(bool).init(false),
        };
    }
};

fn readThreadMain(session: *TerminalSession) void {
    const max_read: usize = 64 * 1024;
    var buf: [max_read]u8 = undefined;

    while (session.read_thread_running.load(.acquire)) {
        if (session.pty) |*pty| {
            if (!pty.waitForData(50)) {
                continue;
            }
            var processed: usize = 0;
            const start_ms = std.time.milliTimestamp();
            const io_log = app_logger.logger("terminal.io");
            while (session.read_thread_running.load(.acquire)) {
                const n = pty.read(&buf) catch break;
                if (n == null or n.? == 0) break;
                processed += n.?;
                logCsiSequences(io_log, buf[0..n.?]);
                session.io_mutex.lock();
                _ = session.io_buffer.appendSlice(session.allocator, buf[0..n.?]) catch {};
                session.io_mutex.unlock();
                session.io_wait_cond.signal();
                if (session.parse_thread == null) {
                    session.output_pending.store(true, .release);
                    _ = session.output_generation.fetchAdd(1, .acq_rel);
                }
            }
            if (processed > 0 and session.alt_exit_pending.swap(false, .acq_rel)) {
                const elapsed_ms = @as(f64, @floatFromInt(std.time.milliTimestamp() - start_ms));
                io_log.logf("alt_exit_io_ms={d:.2} bytes={d}", .{ elapsed_ms, processed });
            }
        } else {
            break;
        }
    }
}

fn parseThreadMain(session: *TerminalSession) void {
    var temp: [4096]u8 = undefined;

    while (session.parse_thread_running.load(.acquire)) {
        const input_pressure = session.input_pressure.load(.acquire);
        var max_bytes: usize = if (input_pressure) 64 * 1024 else 512 * 1024;
        var max_ms: i64 = if (input_pressure) 2 else 8;
        var pending_offset: ?usize = null;
        if (session.view_cache_pending.swap(false, .acq_rel)) {
            pending_offset = @intCast(session.view_cache_request_offset.load(.acquire));
        }

        var queued_bytes: usize = 0;
        session.io_mutex.lock();
        if (session.io_buffer.items.len > session.io_read_offset) {
            queued_bytes = session.io_buffer.items.len - session.io_read_offset;
        } else {
            if (pending_offset == null) {
                session.io_wait_cond.timedWait(&session.io_mutex, 10 * std.time.ns_per_ms) catch {};
            }
            if (!session.parse_thread_running.load(.acquire)) {
                session.io_mutex.unlock();
                break;
            }
            if (session.io_buffer.items.len > session.io_read_offset) {
                queued_bytes = session.io_buffer.items.len - session.io_read_offset;
            }
        }
        session.io_mutex.unlock();

        if (queued_bytes == 0) {
            if (pending_offset) |offset| {
                session.state_mutex.lock();
                session.updateViewCacheNoLock(session.output_generation.load(.acquire), offset);
                session.state_mutex.unlock();
            }
            continue;
        }

        if (queued_bytes >= 8 * 1024 * 1024) {
            max_bytes = if (input_pressure) 256 * 1024 else 2 * 1024 * 1024;
            max_ms = if (input_pressure) 4 else 16;
        } else if (queued_bytes >= 1024 * 1024) {
            max_bytes = if (input_pressure) 128 * 1024 else 512 * 1024;
            max_ms = if (input_pressure) 2 else 8;
        }

        const perf_log = app_logger.logger("terminal.parse");
        const start_ms = std.time.milliTimestamp();
        var processed: usize = 0;
        var had_data = false;

        while (processed < max_bytes and std.time.milliTimestamp() - start_ms < max_ms) {
            var chunk_len: usize = 0;
            session.io_mutex.lock();
            const available = if (session.io_buffer.items.len > session.io_read_offset)
                session.io_buffer.items.len - session.io_read_offset
            else
                0;
            if (available > 0) {
                chunk_len = @min(temp.len, available);
                std.mem.copyForwards(u8, temp[0..chunk_len], session.io_buffer.items[session.io_read_offset .. session.io_read_offset + chunk_len]);
                session.io_read_offset += chunk_len;
                had_data = true;
                if (session.io_read_offset >= session.io_buffer.items.len) {
                    session.io_buffer.items.len = 0;
                    session.io_read_offset = 0;
                } else if (session.io_read_offset > 64 * 1024 and session.io_read_offset > session.io_buffer.items.len / 2) {
                    const remaining = session.io_buffer.items.len - session.io_read_offset;
                    std.mem.copyForwards(u8, session.io_buffer.items[0..remaining], session.io_buffer.items[session.io_read_offset..session.io_buffer.items.len]);
                    session.io_buffer.items.len = remaining;
                    session.io_read_offset = 0;
                }
            }
            session.io_mutex.unlock();

            if (chunk_len == 0) break;

            session.state_mutex.lock();
            session.parser.handleSlice(session, temp[0..chunk_len]);
            session.state_mutex.unlock();
            processed += chunk_len;
            _ = session.output_generation.fetchAdd(1, .acq_rel);
        }

        if (had_data or pending_offset != null) {
            const target_offset = pending_offset orelse session.history.scrollOffset();
            session.state_mutex.lock();
            session.clearSelection();
            session.updateViewCacheNoLock(session.output_generation.load(.acquire), target_offset);
            session.state_mutex.unlock();
            session.output_pending.store(true, .release);
        }

        if (processed > 0 and (perf_log.enabled_file or perf_log.enabled_console)) {
            const end_ms = std.time.milliTimestamp();
            const elapsed_ms = @as(f64, @floatFromInt(end_ms - start_ms));
            const should_log = elapsed_ms >= 8.0 or queued_bytes >= 1024 * 1024 or processed >= 512 * 1024;
            if (should_log and (end_ms - session.last_parse_log_ms) >= 100) {
                session.last_parse_log_ms = end_ms;
                perf_log.logf("parse_ms={d:.2} bytes={d} queued_bytes={d} input_pressure={any}", .{
                    elapsed_ms,
                    processed,
                    queued_bytes,
                    input_pressure,
                });
            }
        }
    }
}

pub const Hyperlink = snapshot_mod.Hyperlink;

pub const VTERM_KEY_NONE = types.VTERM_KEY_NONE;
pub const VTERM_KEY_ENTER = types.VTERM_KEY_ENTER;
pub const VTERM_KEY_TAB = types.VTERM_KEY_TAB;
pub const VTERM_KEY_BACKSPACE = types.VTERM_KEY_BACKSPACE;
pub const VTERM_KEY_ESCAPE = types.VTERM_KEY_ESCAPE;
pub const VTERM_KEY_UP = types.VTERM_KEY_UP;
pub const VTERM_KEY_DOWN = types.VTERM_KEY_DOWN;
pub const VTERM_KEY_LEFT = types.VTERM_KEY_LEFT;
pub const VTERM_KEY_RIGHT = types.VTERM_KEY_RIGHT;
pub const VTERM_KEY_INS = types.VTERM_KEY_INS;
pub const VTERM_KEY_DEL = types.VTERM_KEY_DEL;
pub const VTERM_KEY_HOME = types.VTERM_KEY_HOME;
pub const VTERM_KEY_END = types.VTERM_KEY_END;
pub const VTERM_KEY_PAGEUP = types.VTERM_KEY_PAGEUP;
pub const VTERM_KEY_PAGEDOWN = types.VTERM_KEY_PAGEDOWN;
pub const VTERM_KEY_LEFT_SHIFT = types.VTERM_KEY_LEFT_SHIFT;
pub const VTERM_KEY_RIGHT_SHIFT = types.VTERM_KEY_RIGHT_SHIFT;
pub const VTERM_KEY_LEFT_CTRL = types.VTERM_KEY_LEFT_CTRL;
pub const VTERM_KEY_RIGHT_CTRL = types.VTERM_KEY_RIGHT_CTRL;
pub const VTERM_KEY_LEFT_ALT = types.VTERM_KEY_LEFT_ALT;
pub const VTERM_KEY_RIGHT_ALT = types.VTERM_KEY_RIGHT_ALT;
pub const VTERM_KEY_LEFT_SUPER = types.VTERM_KEY_LEFT_SUPER;
pub const VTERM_KEY_RIGHT_SUPER = types.VTERM_KEY_RIGHT_SUPER;
pub const KeypadKey = input_mod.KeypadKey;
pub const KeyAction = input_mod.KeyAction;

pub const VTERM_MOD_NONE = types.VTERM_MOD_NONE;
pub const VTERM_MOD_SHIFT = types.VTERM_MOD_SHIFT;
pub const VTERM_MOD_ALT = types.VTERM_MOD_ALT;
pub const VTERM_MOD_CTRL = types.VTERM_MOD_CTRL;

const default_scrollback_rows: usize = 1000;
const key_mode_disambiguate: u32 = 1;
const key_mode_report_all_event_types: u32 = 2;
const key_mode_report_alternate_key: u32 = 4;
const key_mode_report_text: u32 = 8;
const key_mode_embed_text: u32 = 16;

fn keyName(key: Key) []const u8 {
    return switch (key) {
        VTERM_KEY_ENTER => "enter",
        VTERM_KEY_TAB => "tab",
        VTERM_KEY_BACKSPACE => "backspace",
        VTERM_KEY_ESCAPE => "escape",
        VTERM_KEY_UP => "up",
        VTERM_KEY_DOWN => "down",
        VTERM_KEY_LEFT => "left",
        VTERM_KEY_RIGHT => "right",
        VTERM_KEY_INS => "insert",
        VTERM_KEY_DEL => "delete",
        VTERM_KEY_HOME => "home",
        VTERM_KEY_END => "end",
        VTERM_KEY_PAGEUP => "page_up",
        VTERM_KEY_PAGEDOWN => "page_down",
        else => "unknown",
    };
}

fn keypadKeyName(key: input_mod.KeypadKey) []const u8 {
    return switch (key) {
        .kp0 => "kp0",
        .kp1 => "kp1",
        .kp2 => "kp2",
        .kp3 => "kp3",
        .kp4 => "kp4",
        .kp5 => "kp5",
        .kp6 => "kp6",
        .kp7 => "kp7",
        .kp8 => "kp8",
        .kp9 => "kp9",
        .kp_decimal => "kp_decimal",
        .kp_divide => "kp_divide",
        .kp_multiply => "kp_multiply",
        .kp_subtract => "kp_subtract",
        .kp_add => "kp_add",
        .kp_enter => "kp_enter",
        .kp_equal => "kp_equal",
    };
}
const mouse_button_left_mask: u8 = 1;
const mouse_button_middle_mask: u8 = 2;
const mouse_button_right_mask: u8 = 4;
const max_hyperlinks: usize = 2048;

pub const CursorPos = types.CursorPos;
pub const SelectionPos = types.SelectionPos;
pub const TerminalSelection = types.TerminalSelection;
pub const Cell = types.Cell;
pub const CellAttrs = types.CellAttrs;
pub const Color = types.Color;
pub const Key = types.Key;
pub const Modifier = types.Modifier;
pub const MouseButton = types.MouseButton;
pub const MouseEventKind = types.MouseEventKind;
pub const MouseEvent = types.MouseEvent;
