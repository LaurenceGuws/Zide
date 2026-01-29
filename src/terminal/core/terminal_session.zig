const std = @import("std");
const pty_mod = @import("../io/pty.zig");
const input_mod = @import("../input/input.zig");
const history_mod = @import("../model/history.zig");
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
    view_cells: std.ArrayList(Cell),
    view_dirty_rows: std.ArrayList(bool),
    view_dirty_cols_start: std.ArrayList(u16),
    view_dirty_cols_end: std.ArrayList(u16),
    kitty_view_images: std.ArrayList(kitty_mod.KittyImage),
    kitty_view_placements: std.ArrayList(kitty_mod.KittyPlacement),
    kitty_view_generation: std.atomic.Value(u64),
    view_cache_generation: std.atomic.Value(u64),
    view_cache_rows: std.atomic.Value(u16),
    view_cache_cols: std.atomic.Value(u16),
    view_cache_scroll_offset: std.atomic.Value(u64),
    view_cache_pending: std.atomic.Value(bool),
    view_cache_request_offset: std.atomic.Value(u64),
    alt_last_active: bool,

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
            .view_cells = .empty,
            .view_dirty_rows = .empty,
            .view_dirty_cols_start = .empty,
            .view_dirty_cols_end = .empty,
            .kitty_view_images = .empty,
            .kitty_view_placements = .empty,
            .kitty_view_generation = std.atomic.Value(u64).init(0),
            .view_cache_generation = std.atomic.Value(u64).init(0),
            .view_cache_rows = std.atomic.Value(u16).init(0),
            .view_cache_cols = std.atomic.Value(u16).init(0),
            .view_cache_scroll_offset = std.atomic.Value(u64).init(0),
            .view_cache_pending = std.atomic.Value(bool).init(false),
            .view_cache_request_offset = std.atomic.Value(u64).init(0),
            .alt_last_active = false,
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
        const history_len = if (self.isAltActive()) 0 else self.history.scrollbackCount();
        const total_lines = history_len + rows;
        const max_offset = if (total_lines > rows) total_lines - rows else 0;
        const clamped_offset = if (scroll_offset > max_offset) max_offset else scroll_offset;
        if (rows == 0 or cols == 0) {
            self.view_cells.clearRetainingCapacity();
            self.view_dirty_rows.clearRetainingCapacity();
            self.view_dirty_cols_start.clearRetainingCapacity();
            self.view_dirty_cols_end.clearRetainingCapacity();
            self.view_cache_rows.store(0, .release);
            self.view_cache_cols.store(0, .release);
            self.view_cache_generation.store(generation, .release);
            self.view_cache_scroll_offset.store(@intCast(clamped_offset), .release);
            self.updateKittyViewNoLock();
            return;
        }

        const view_count = rows * cols;
        _ = self.view_cells.resize(self.allocator, view_count) catch {};
        _ = self.view_dirty_rows.resize(self.allocator, rows) catch {};
        _ = self.view_dirty_cols_start.resize(self.allocator, rows) catch {};
        _ = self.view_dirty_cols_end.resize(self.allocator, rows) catch {};

        const start_line = if (total_lines > rows + clamped_offset)
            total_lines - rows - clamped_offset
        else
            0;
        var row: usize = 0;
        while (row < rows) : (row += 1) {
            const global_row = start_line + row;
            const row_start = row * cols;
            const row_dest = self.view_cells.items[row_start .. row_start + cols];
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
        if (view.dirty_rows.len == rows) {
            std.mem.copyForwards(bool, self.view_dirty_rows.items, view.dirty_rows);
        } else {
            for (self.view_dirty_rows.items) |*row_dirty| {
                row_dirty.* = true;
            }
        }
        if (view.dirty_cols_start.len == rows and view.dirty_cols_end.len == rows) {
            std.mem.copyForwards(u16, self.view_dirty_cols_start.items, view.dirty_cols_start);
            std.mem.copyForwards(u16, self.view_dirty_cols_end.items, view.dirty_cols_end);
        } else {
            for (self.view_dirty_cols_start.items, self.view_dirty_cols_end.items) |*col_start, *col_end| {
                col_start.* = 0;
                col_end.* = if (cols > 0) @intCast(cols - 1) else 0;
            }
        }

        self.view_cache_rows.store(@intCast(rows), .release);
        self.view_cache_cols.store(@intCast(cols), .release);
        self.view_cache_generation.store(generation, .release);
        self.view_cache_scroll_offset.store(@intCast(clamped_offset), .release);
        self.updateKittyViewNoLock();
    }

    fn updateKittyViewNoLock(self: *TerminalSession) void {
        const kitty = kitty_mod.kittyStateConst(self);
        const kitty_generation = kitty.generation;
        if (kitty_generation == self.kitty_view_generation.load(.acquire)) return;

        _ = self.kitty_view_images.resize(self.allocator, kitty.images.items.len) catch {};
        _ = self.kitty_view_placements.resize(self.allocator, kitty.placements.items.len) catch {};
        std.mem.copyForwards(kitty_mod.KittyImage, self.kitty_view_images.items, kitty.images.items);
        std.mem.copyForwards(kitty_mod.KittyPlacement, self.kitty_view_placements.items, kitty.placements.items);
        if (self.kitty_view_placements.items.len > 1) {
            std.sort.block(kitty_mod.KittyPlacement, self.kitty_view_placements.items, {}, struct {
                fn lessThan(_: void, a: kitty_mod.KittyPlacement, b: kitty_mod.KittyPlacement) bool {
                    if (a.z == b.z) {
                        if (a.row == b.row) return a.col < b.col;
                        return a.row < b.row;
                    }
                    return a.z < b.z;
                }
            }.lessThan);
        }
        self.kitty_view_generation.store(kitty_generation, .release);
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
        self.view_cells.deinit(self.allocator);
        self.view_dirty_rows.deinit(self.allocator);
        self.view_dirty_cols_start.deinit(self.allocator);
        self.view_dirty_cols_end.deinit(self.allocator);
        self.kitty_view_images.deinit(self.allocator);
        self.kitty_view_placements.deinit(self.allocator);
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
        const old_cols = self.primary.grid.cols;
        try self.primary.resize(rows, cols);
        try self.alt.resize(rows, cols);
        if (cols != old_cols) {
            try self.history.resizePreserve(cols, self.primary.defaultCell());
        }
        const log = app_logger.logger("terminal.core");
        log.logf("terminal resize rows={d} cols={d} scrollback_cols={d}", .{ rows, cols, self.primary.grid.cols });
        log.logStdout("terminal resize rows={d} cols={d}", .{ rows, cols });
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
        if (self.pty) |*pty| {
            const size = PtySize{
                .rows = rows,
                .cols = cols,
                .cell_width = self.cell_width,
                .cell_height = self.cell_height,
            };
            try pty.resize(size);
        }
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
            },
            0x0D => { // CR
                screen.carriageReturn();
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
    }

    pub fn eraseDisplay(self: *TerminalSession, mode: i32) void {
        const screen = self.activeScreen();
        const blank_cell = screen.blankCell();
        screen.eraseDisplay(mode, blank_cell);
    }

    pub fn eraseLine(self: *TerminalSession, mode: i32) void {
        const screen = self.activeScreen();
        const blank_cell = screen.blankCell();
        screen.eraseLine(mode, blank_cell);
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
        self.history.pushRow(screen.grid.cells.items[row_start .. row_start + cols]);
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
        }
        screen.scrollRegionUpBy(n, blank_cell);
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
        }
        const blank_cell = screen.blankCell();
        screen.scrollUp(blank_cell);
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
        return self.history.scrollbackCount();
    }

    pub fn scrollbackRow(self: *TerminalSession, index: usize) ?[]const Cell {
        if (self.isAltActive()) return null;
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
        self.history.setScrollOffset(self.primary.grid.rows, offset);
        self.primary.markDirtyAll();
        self.view_cache_request_offset.store(@intCast(self.history.scrollOffset()), .release);
        self.view_cache_pending.store(true, .release);
        self.io_wait_cond.signal();
        const log = app_logger.logger("terminal.core");
        const max_offset = self.history.maxScrollOffset(self.primary.grid.rows);
        log.logf("set scroll offset={d} max={d}", .{ self.history.scrollOffset(), max_offset });
        log.logStdout("set scroll offset={d} max={d}", .{ self.history.scrollOffset(), max_offset });
    }

    pub fn scrollBy(self: *TerminalSession, delta: isize) void {
        if (self.isAltActive()) return;
        if (delta == 0) return;
        self.history.scrollBy(self.primary.grid.rows, delta);
        self.primary.markDirtyAll();
        self.view_cache_request_offset.store(@intCast(self.history.scrollOffset()), .release);
        self.view_cache_pending.store(true, .release);
        self.io_wait_cond.signal();
        const log = app_logger.logger("terminal.core");
        const max_offset = self.history.maxScrollOffset(self.primary.grid.rows);
        log.logf("scroll by delta={d} offset={d} max={d}", .{ delta, self.history.scrollOffset(), max_offset });
        log.logStdout("scroll by delta={d} offset={d} max={d}", .{ delta, self.history.scrollOffset(), max_offset });
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

    pub fn syncUpdatesActive(self: *const TerminalSession) bool {
        return self.sync_updates_active;
    }

    pub fn setSyncUpdates(self: *TerminalSession, enabled: bool) void {
        if (self.sync_updates_active == enabled) return;
        self.sync_updates_active = enabled;
        if (!enabled) {
            self.activeScreen().markDirtyAll();
        }
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
    }

    pub fn startSelection(self: *TerminalSession, row: usize, col: usize) void {
        if (self.isAltActive()) return;
        self.history.startSelection(row, col);
    }

    pub fn updateSelection(self: *TerminalSession, row: usize, col: usize) void {
        if (self.isAltActive()) return;
        self.history.updateSelection(row, col);
    }

    pub fn finishSelection(self: *TerminalSession) void {
        if (self.isAltActive()) return;
        self.history.finishSelection();
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
