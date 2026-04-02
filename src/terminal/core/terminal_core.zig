const std = @import("std");
const history_mod = @import("../model/history.zig");
const parser_mod = @import("../parser/parser.zig");
const screen_mod = @import("../model/screen.zig");
const snapshot_mod = @import("publication/snapshot.zig");
const types = @import("../model/types.zig");
const kitty_mod = @import("../kitty/graphics.zig");
const semantic_prompt_mod = @import("semantic_prompt.zig");
const host_types = @import("session/host_types.zig");
const palette_mod = @import("../protocol/palette.zig");

const Screen = screen_mod.Screen;
const Charset = parser_mod.Charset;
const CharsetTarget = parser_mod.CharsetTarget;
const SemanticPromptState = semantic_prompt_mod.SemanticPromptState;
const ProgressState = host_types.ProgressState;
const Hyperlink = snapshot_mod.Hyperlink;
const Cell = types.Cell;

const dynamic_color_count: usize = 10;

pub const ActiveScreen = enum {
    primary,
    alt,
};

pub const SavedCharsetState = struct {
    active: bool = false,
    g0: Charset = .ascii,
    g1: Charset = .ascii,
    gl: Charset = .ascii,
    target: CharsetTarget = .g0,
};

pub const InitOptions = struct {
    scrollback_rows: usize,
    cursor_style: ?types.CursorStyle = null,
};

pub const TerminalCore = struct {
    allocator: std.mem.Allocator,
    title: []const u8,
    title_buffer: std.ArrayList(u8),
    primary: Screen,
    alt: Screen,
    active: ActiveScreen,
    history: history_mod.TerminalHistory,
    parser: parser_mod.Parser,
    osc_clipboard: std.ArrayList(u8),
    osc_clipboard_pending: bool,
    kitty_osc5522_clipboard_text: std.ArrayList(u8),
    kitty_osc5522_clipboard_html: std.ArrayList(u8),
    kitty_osc5522_clipboard_uri_list: std.ArrayList(u8),
    kitty_osc5522_clipboard_png: std.ArrayList(u8),
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
    progress_state: ProgressState,
    progress_value: ?u8,
    user_vars: std.StringHashMap([]u8),
    kitty_primary: kitty_mod.KittyState,
    kitty_alt: kitty_mod.KittyState,
    base_default_attrs: types.CellAttrs,
    palette_default: [256]types.Color,
    palette_current: [256]types.Color,
    dynamic_colors: [dynamic_color_count]?types.Color,
    sync_updates_active: bool,
    column_mode_132: bool,
    alt_last_active: bool,
    clear_generation: std.atomic.Value(u64),
    saved_charset: SavedCharsetState,

    pub fn init(allocator: std.mem.Allocator, rows: u16, cols: u16, options: InitOptions) !TerminalCore {
        const default_attrs = types.defaultCell().attrs;
        var primary = try Screen.init(allocator, rows, cols, default_attrs);
        var alt = try Screen.init(allocator, rows, cols, default_attrs);
        if (options.cursor_style) |cursor_style| {
            primary.cursor_style = cursor_style;
            alt.cursor_style = cursor_style;
        }
        const history = try history_mod.TerminalHistory.init(allocator, options.scrollback_rows, cols);
        const palette_default = palette_mod.buildDefaultPalette();
        return .{
            .allocator = allocator,
            .title = "Terminal",
            .title_buffer = .empty,
            .primary = primary,
            .alt = alt,
            .active = .primary,
            .history = history,
            .parser = parser_mod.Parser.init(allocator),
            .osc_clipboard = .empty,
            .osc_clipboard_pending = false,
            .kitty_osc5522_clipboard_text = .empty,
            .kitty_osc5522_clipboard_html = .empty,
            .kitty_osc5522_clipboard_uri_list = .empty,
            .kitty_osc5522_clipboard_png = .empty,
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
            .progress_state = .none,
            .progress_value = null,
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
            .sync_updates_active = false,
            .column_mode_132 = false,
            .alt_last_active = false,
            .clear_generation = std.atomic.Value(u64).init(0),
            .saved_charset = .{},
        };
    }

    pub fn deinit(self: *TerminalCore, owner: anytype) void {
        self.history.deinit();
        self.primary.deinit();
        self.alt.deinit();
        self.parser.deinit();
        self.osc_clipboard.deinit(self.allocator);
        self.kitty_osc5522_clipboard_text.deinit(self.allocator);
        self.kitty_osc5522_clipboard_html.deinit(self.allocator);
        self.kitty_osc5522_clipboard_uri_list.deinit(self.allocator);
        self.kitty_osc5522_clipboard_png.deinit(self.allocator);
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
        kitty_mod.deinitKittyState(owner, &self.kitty_primary);
        kitty_mod.deinitKittyState(owner, &self.kitty_alt);
        for (self.hyperlink_table.items) |link| {
            self.allocator.free(link.uri);
        }
        self.hyperlink_table.deinit(self.allocator);
        self.title_buffer.deinit(self.allocator);
    }

    pub fn activeScreen(self: *TerminalCore) *Screen {
        return if (self.active == .alt) &self.alt else &self.primary;
    }

    pub fn glCharset(self: *const TerminalCore) Charset {
        return self.parser.gl_charset;
    }

    pub fn applyHyperlinkAttrs(self: *const TerminalCore, attrs: *types.CellAttrs) void {
        if (self.osc_hyperlink_active and self.current_hyperlink_id > 0) {
            attrs.link_id = self.current_hyperlink_id;
            attrs.underline = true;
        } else {
            attrs.link_id = 0;
        }
    }

    pub fn activeScreenConst(self: *const TerminalCore) *const Screen {
        return if (self.active == .alt) &self.alt else &self.primary;
    }

    pub fn inactiveScreen(self: *TerminalCore) *Screen {
        return if (self.active == .alt) &self.primary else &self.alt;
    }

    pub fn isAltActive(self: *const TerminalCore) bool {
        return self.active == .alt;
    }

    pub fn titleText(self: *const TerminalCore) []const u8 {
        return self.title;
    }

    pub fn cwdText(self: *const TerminalCore) []const u8 {
        return self.cwd;
    }

    pub fn scrollbackOffset(self: *const TerminalCore) usize {
        return if (self.active == .alt) 0 else self.history.scrollOffset();
    }

    pub fn scrollbackCount(self: *const TerminalCore) usize {
        return if (self.active == .alt) 0 else self.history.scrollbackCount();
    }

    pub const ScrollbackInfo = struct {
        total_rows: usize,
        cols: usize,
    };

    pub const ScrollbackRange = struct {
        total_rows: usize,
        row_count: usize,
        cols: usize,
    };

    pub fn ensureScrollbackView(self: *TerminalCore, cols: u16, default_cell: types.Cell) void {
        if (self.active == .alt) return;
        self.history.ensureViewCache(cols, default_cell);
    }

    pub fn scrollbackRow(self: *TerminalCore, cols: u16, default_cell: types.Cell, index: usize) ?[]const types.Cell {
        if (self.active == .alt) return null;
        self.history.ensureViewCache(cols, default_cell);
        return self.history.scrollbackRow(index);
    }

    pub fn scrollbackInfo(self: *TerminalCore) ScrollbackInfo {
        if (self.active == .alt) {
            return .{
                .total_rows = 0,
                .cols = self.primary.grid.cols,
            };
        }
        self.ensureScrollbackView(self.primary.grid.cols, self.primary.defaultCell());
        return .{
            .total_rows = self.scrollbackCount(),
            .cols = self.primary.grid.cols,
        };
    }

    pub fn copyScrollbackRange(
        self: *TerminalCore,
        allocator: std.mem.Allocator,
        start_row: usize,
        max_rows: usize,
        out: *std.ArrayList(Cell),
    ) !ScrollbackRange {
        out.clearRetainingCapacity();
        const info = self.scrollbackInfo();
        const total_rows = info.total_rows;
        const cols = info.cols;
        if (start_row > total_rows) return error.InvalidArgument;

        const available = total_rows - start_row;
        const requested = if (max_rows == 0) available else @min(available, max_rows);

        try out.ensureTotalCapacityPrecise(allocator, requested * cols);

        var row_index: usize = 0;
        while (row_index < requested) : (row_index += 1) {
            const row = self.scrollbackRow(@intCast(cols), self.primary.defaultCell(), start_row + row_index) orelse return error.InvalidArgument;
            try out.appendSlice(allocator, row);
        }

        return .{
            .total_rows = total_rows,
            .row_count = requested,
            .cols = cols,
        };
    }

    pub fn maxScrollbackOffset(self: *TerminalCore, rows: u16, cols: u16, default_cell: types.Cell) usize {
        if (self.active == .alt) return 0;
        self.history.ensureViewCache(cols, default_cell);
        return self.history.maxScrollOffset(rows);
    }

    pub fn setScrollbackOffset(self: *TerminalCore, rows: u16, cols: u16, default_cell: types.Cell, offset: usize) usize {
        if (self.active == .alt) {
            self.history.scrollback_offset = 0;
            return 0;
        }
        self.history.ensureViewCache(cols, default_cell);
        self.history.setScrollOffset(rows, offset);
        return self.history.scrollOffset();
    }

    pub fn scrollScrollbackBy(self: *TerminalCore, rows: u16, cols: u16, default_cell: types.Cell, delta: isize) usize {
        if (self.active == .alt) return 0;
        self.history.ensureViewCache(cols, default_cell);
        self.history.scrollBy(rows, delta);
        return self.history.scrollOffset();
    }

    pub fn clearSelection(self: *TerminalCore) void {
        self.history.clearSelection();
    }

    pub fn startSelection(self: *TerminalCore, row: usize, col: usize) void {
        self.history.startSelection(row, col);
    }

    pub fn updateSelection(self: *TerminalCore, row: usize, col: usize) void {
        self.history.updateSelection(row, col);
    }

    pub fn finishSelection(self: *TerminalCore) void {
        self.history.finishSelection();
    }

    pub fn selectionState(self: *TerminalCore) ?types.TerminalSelection {
        if (self.active == .alt) return null;
        return self.history.selectionState();
    }

    pub fn scrollbackPlainTextAlloc(self: *TerminalCore, allocator: std.mem.Allocator) ![]u8 {
        const screen = self.activeScreenConst();
        const view = screen.snapshotView();
        const rows = view.rows;
        const cols = view.cols;
        const history = self.scrollbackCount();

        var out = std.ArrayList(u8).empty;
        errdefer out.deinit(allocator);

        var line_idx: usize = 0;
        while (line_idx < history + rows) : (line_idx += 1) {
            const row_cells = coreVisibleRow(self, view.cells, rows, cols, history, line_idx) orelse continue;
            try appendPlainRow(&out, allocator, row_cells);
        }

        return out.toOwnedSlice(allocator);
    }

    pub fn scrollbackAnsiTextAlloc(self: *TerminalCore, allocator: std.mem.Allocator) ![]u8 {
        const screen = self.activeScreenConst();
        const view = screen.snapshotView();
        const rows = view.rows;
        const cols = view.cols;
        const history = self.scrollbackCount();

        var out = std.ArrayList(u8).empty;
        errdefer out.deinit(allocator);

        var line_idx: usize = 0;
        while (line_idx < history + rows) : (line_idx += 1) {
            const row_cells = coreVisibleRow(self, view.cells, rows, cols, history, line_idx) orelse continue;
            try appendAnsiRow(&out, allocator, row_cells);
        }

        return out.toOwnedSlice(allocator);
    }

    pub fn selectionPlainTextAlloc(self: *TerminalCore, allocator: std.mem.Allocator) !?[]u8 {
        const selection = self.selectionState() orelse return null;
        const screen = self.activeScreenConst();
        const view = screen.snapshotView();
        const rows = view.rows;
        const cols = view.cols;
        const history = self.scrollbackCount();
        const total_lines = history + rows;
        if (rows == 0 or cols == 0 or total_lines == 0) return null;

        var start_sel = selection.start;
        var end_sel = selection.end;
        if (start_sel.row > end_sel.row or (start_sel.row == end_sel.row and start_sel.col > end_sel.col)) {
            const tmp = start_sel;
            start_sel = end_sel;
            end_sel = tmp;
        }
        start_sel.row = @min(start_sel.row, total_lines - 1);
        end_sel.row = @min(end_sel.row, total_lines - 1);
        start_sel.col = @min(start_sel.col, cols - 1);
        end_sel.col = @min(end_sel.col, cols - 1);

        var out = std.ArrayList(u8).empty;
        errdefer out.deinit(allocator);

        var row_idx: usize = start_sel.row;
        while (row_idx <= end_sel.row and row_idx < total_lines) : (row_idx += 1) {
            const row_cells = coreVisibleRow(self, view.cells, rows, cols, history, row_idx) orelse continue;
            const col_start = if (row_idx == start_sel.row) start_sel.col else 0;
            const col_end = if (row_idx == end_sel.row) end_sel.col else cols - 1;
            try appendSelectionRange(&out, allocator, row_cells, cols, col_start, col_end);
            if (row_idx != end_sel.row) try out.append(allocator, '\n');
        }

        return try out.toOwnedSlice(allocator);
    }

    pub fn setSelectionState(self: *TerminalCore, selection: types.TerminalSelection) void {
        self.history.selection.selection = selection;
    }

    pub fn resetState(self: *TerminalCore, owner: anytype) void {
        self.resetParserState();
        self.clearSavedCharsetState();
        self.primary.resetState();
        self.alt.resetState();
        self.current_hyperlink_id = 0;
        self.primary.clear();
        self.alt.clear();
        kitty_mod.clearKittyImages(owner);
        _ = self.clear_generation.fetchAdd(1, .acq_rel);
    }

    pub fn semanticPromptActive(self: *const TerminalCore) bool {
        return self.semantic_prompt.input_active or self.semantic_prompt.output_active;
    }

    pub fn syncUpdatesActive(self: *const TerminalCore) bool {
        return self.sync_updates_active;
    }

    pub fn setSyncUpdates(self: *TerminalCore, enabled: bool) bool {
        if (self.sync_updates_active == enabled) return false;
        self.sync_updates_active = enabled;
        return true;
    }

    pub fn saveCursorState(self: *TerminalCore) void {
        self.activeScreen().saveCursor();
        self.saved_charset = .{
            .active = true,
            .g0 = self.parser.g0_charset,
            .g1 = self.parser.g1_charset,
            .gl = self.parser.gl_charset,
            .target = self.parser.charset_target,
        };
    }

    pub fn restoreCursorState(self: *TerminalCore) void {
        self.activeScreen().restoreCursor();
        if (!self.saved_charset.active) return;
        self.parser.g0_charset = self.saved_charset.g0;
        self.parser.g1_charset = self.saved_charset.g1;
        self.parser.gl_charset = self.saved_charset.gl;
        self.parser.charset_target = self.saved_charset.target;
    }

    pub fn shiftOutCharset(self: *TerminalCore) void {
        self.parser.gl_charset = self.parser.g1_charset;
    }

    pub fn shiftInCharset(self: *TerminalCore) void {
        self.parser.gl_charset = self.parser.g0_charset;
    }

    pub fn enterEscapeState(self: *TerminalCore) void {
        self.parser.esc_state = .esc;
        self.parser.stream.reset();
        self.parser.csi.reset();
        self.parser.osc_state = .idle;
        self.parser.apc_state = .idle;
        self.parser.dcs_state = .idle;
    }

    pub fn resetParserState(self: *TerminalCore) void {
        self.parser.reset();
    }

    pub fn clearSavedCharsetState(self: *TerminalCore) void {
        self.saved_charset = .{};
    }

    pub fn clearTitleBuffer(self: *TerminalCore) void {
        self.title_buffer.clearRetainingCapacity();
    }

    pub fn appendTitleSlice(self: *TerminalCore, allocator: std.mem.Allocator, text: []const u8) !void {
        try self.title_buffer.appendSlice(allocator, text);
    }

    pub fn publishTitleBuffer(self: *TerminalCore) void {
        self.title = self.title_buffer.items;
    }

    pub fn setDefaultTitle(self: *TerminalCore) void {
        self.title = "Terminal";
    }

    pub fn setProgress(self: *TerminalCore, state: ProgressState, value: ?u8) void {
        self.progress_state = state;
        self.progress_value = value;
    }

    pub fn clearProgress(self: *TerminalCore) void {
        self.progress_state = .none;
        self.progress_value = null;
    }

    pub fn clearCwdBuffer(self: *TerminalCore) void {
        self.cwd_buffer.clearRetainingCapacity();
    }

    pub fn appendCwdByte(self: *TerminalCore, allocator: std.mem.Allocator, b: u8) !void {
        try self.cwd_buffer.append(allocator, b);
    }

    pub fn appendCwdSlice(self: *TerminalCore, allocator: std.mem.Allocator, text: []const u8) !void {
        _ = try self.cwd_buffer.appendSlice(allocator, text);
    }

    pub fn publishCwdBuffer(self: *TerminalCore) void {
        self.cwd = self.cwd_buffer.items;
    }

    pub fn cwdBufferLen(self: *const TerminalCore) usize {
        return self.cwd_buffer.items.len;
    }

    pub fn truncateCwdBuffer(self: *TerminalCore, len: usize) void {
        self.cwd_buffer.items.len = len;
    }

    pub fn cwdBufferLast(self: *const TerminalCore) ?u8 {
        if (self.cwd_buffer.items.len == 0) return null;
        return self.cwd_buffer.items[self.cwd_buffer.items.len - 1];
    }

    pub fn setColumnMode132(self: *TerminalCore, enabled: bool) bool {
        if (self.column_mode_132 == enabled) return false;
        self.column_mode_132 = enabled;
        if (!enabled) return true;
        self.primary.clear();
        self.alt.clear();
        self.primary.setCursor(0, 0);
        self.alt.setCursor(0, 0);
        _ = self.clear_generation.fetchAdd(1, .acq_rel);
        return true;
    }

    pub fn setDefaultColors(self: *TerminalCore, fg: types.Color, bg: types.Color) void {
        const old_attrs = self.primary.default_attrs;
        var new_attrs = types.defaultCell().attrs;
        new_attrs.fg = fg;
        new_attrs.bg = bg;
        new_attrs.underline_color = fg;

        self.primary.updateDefaultColors(old_attrs, new_attrs);
        self.alt.updateDefaultColors(old_attrs, new_attrs);
        self.history.updateDefaultColors(old_attrs.fg, old_attrs.bg, new_attrs.fg, new_attrs.bg);
    }

    pub fn setAnsiColors(self: *TerminalCore, colors: [16]types.Color) void {
        for (0..16) |i| {
            self.palette_default[i] = colors[i];
            self.palette_current[i] = colors[i];
        }
    }

    pub fn remapAnsiColors(self: *TerminalCore, old_colors: [16]types.Color, new_colors: [16]types.Color) void {
        self.primary.updateAnsiColors(old_colors, new_colors);
        self.alt.updateAnsiColors(old_colors, new_colors);
        self.history.updateAnsiColors(old_colors, new_colors);
    }

    pub fn snapshotAnsiColors(self: *const TerminalCore) [16]types.Color {
        var colors: [16]types.Color = undefined;
        for (0..16) |i| {
            colors[i] = self.palette_current[i];
        }
        return colors;
    }

    pub fn setPaletteColor(self: *TerminalCore, idx: usize, color: types.Color) void {
        if (idx >= self.palette_current.len) return;
        self.palette_current[idx] = color;
    }

    pub fn resetPaletteColor(self: *TerminalCore, idx: usize) void {
        if (idx >= self.palette_current.len) return;
        self.palette_current[idx] = self.palette_default[idx];
    }

    pub fn resetAllPaletteColors(self: *TerminalCore) void {
        self.palette_current = self.palette_default;
    }

    pub fn setDynamicColorCode(self: *TerminalCore, code: u8, color: ?types.Color) void {
        switch (code) {
            10 => {
                const default_attrs = self.primary.default_attrs;
                self.setDefaultColors(color orelse self.base_default_attrs.fg, default_attrs.bg);
            },
            11 => {
                const default_attrs = self.primary.default_attrs;
                self.setDefaultColors(default_attrs.fg, color orelse self.base_default_attrs.bg);
            },
            else => {
                const idx = @as(usize, code - 10);
                if (idx < self.dynamic_colors.len) {
                    self.dynamic_colors[idx] = color;
                }
            },
        }
    }

    pub fn takeOscClipboardCopy(
        self: *TerminalCore,
        allocator: std.mem.Allocator,
        out: *std.ArrayList(u8),
    ) !bool {
        out.clearRetainingCapacity();
        if (!self.osc_clipboard_pending) return false;
        try out.appendSlice(allocator, self.osc_clipboard.items);
        self.osc_clipboard_pending = false;
        return true;
    }

    pub fn setKittyOsc5522Clipboard(
        self: *TerminalCore,
        allocator: std.mem.Allocator,
        clip: []const u8,
        html: ?[]const u8,
        uri_list: ?[]const u8,
        png: ?[]const u8,
    ) !void {
        self.kitty_osc5522_clipboard_text.clearRetainingCapacity();
        try self.kitty_osc5522_clipboard_text.ensureTotalCapacity(allocator, clip.len);
        try self.kitty_osc5522_clipboard_text.appendSlice(allocator, clip);

        self.kitty_osc5522_clipboard_html.clearRetainingCapacity();
        if (html) |html_bytes| {
            try self.kitty_osc5522_clipboard_html.ensureTotalCapacity(allocator, html_bytes.len);
            try self.kitty_osc5522_clipboard_html.appendSlice(allocator, html_bytes);
        }

        self.kitty_osc5522_clipboard_uri_list.clearRetainingCapacity();
        if (uri_list) |uri_bytes| {
            try self.kitty_osc5522_clipboard_uri_list.ensureTotalCapacity(allocator, uri_bytes.len);
            try self.kitty_osc5522_clipboard_uri_list.appendSlice(allocator, uri_bytes);
        }

        self.kitty_osc5522_clipboard_png.clearRetainingCapacity();
        if (png) |png_bytes| {
            try self.kitty_osc5522_clipboard_png.ensureTotalCapacity(allocator, png_bytes.len);
            try self.kitty_osc5522_clipboard_png.appendSlice(allocator, png_bytes);
        }
    }
};

fn rowLastContentCol(row_cells: []const Cell, cols_count: usize) ?usize {
    if (cols_count == 0 or row_cells.len < cols_count) return null;
    var last: ?usize = null;
    var col_idx: usize = 0;
    while (col_idx < cols_count) : (col_idx += 1) {
        const cell = row_cells[col_idx];
        if (cell.x != 0 or cell.y != 0) continue;
        if (cell.codepoint == 0 and cell.combining_len == 0) continue;
        const width_units = @as(usize, @max(@as(u8, 1), cell.width));
        const end_col = @min(cols_count - 1, col_idx + width_units - 1);
        last = end_col;
    }
    return last;
}

fn appendCellText(out: *std.ArrayList(u8), allocator: std.mem.Allocator, cell: Cell) !void {
    if (cell.x != 0 or cell.y != 0) return;
    if (cell.codepoint == 0) {
        try out.append(allocator, ' ');
        return;
    }

    var buf: [4]u8 = undefined;
    const len = std.unicode.utf8Encode(@intCast(cell.codepoint), &buf) catch 0;
    if (len > 0) try out.appendSlice(allocator, buf[0..len]);

    if (cell.combining_len > 0) {
        var ci: usize = 0;
        while (ci < @as(usize, @intCast(cell.combining_len)) and ci < cell.combining.len) : (ci += 1) {
            const cp = cell.combining[ci];
            const c_len = std.unicode.utf8Encode(@intCast(cp), &buf) catch 0;
            if (c_len > 0) try out.appendSlice(allocator, buf[0..c_len]);
        }
    }
}

fn appendPlainRow(out: *std.ArrayList(u8), allocator: std.mem.Allocator, row_cells: []const Cell) !void {
    var line = std.ArrayList(u8).empty;
    defer line.deinit(allocator);

    for (row_cells) |cell| {
        try appendCellText(&line, allocator, cell);
    }

    while (line.items.len > 0 and line.items[line.items.len - 1] == ' ') {
        _ = line.pop();
    }

    try out.appendSlice(allocator, line.items);
    try out.append(allocator, '\n');
}

fn appendSelectionRange(
    out: *std.ArrayList(u8),
    allocator: std.mem.Allocator,
    row_cells: []const Cell,
    cols: usize,
    col_start: usize,
    col_end: usize,
) !void {
    const last_content_col = rowLastContentCol(row_cells, cols) orelse return;
    const clamped_end = @min(col_end, last_content_col);
    if (clamped_end < col_start) return;

    var col_idx: usize = col_start;
    while (col_idx <= clamped_end and col_idx < cols) : (col_idx += 1) {
        try appendCellText(out, allocator, row_cells[col_idx]);
    }

    while (out.items.len > 0 and out.items[out.items.len - 1] == ' ') {
        _ = out.pop();
    }
}

fn attrsEqual(a: types.CellAttrs, b: types.CellAttrs) bool {
    return a.fg.r == b.fg.r and
        a.fg.g == b.fg.g and
        a.fg.b == b.fg.b and
        a.fg.a == b.fg.a and
        a.bg.r == b.bg.r and
        a.bg.g == b.bg.g and
        a.bg.b == b.bg.b and
        a.bg.a == b.bg.a and
        a.bold == b.bold and
        a.blink == b.blink and
        a.blink_fast == b.blink_fast and
        a.reverse == b.reverse and
        a.underline == b.underline and
        a.underline_color.r == b.underline_color.r and
        a.underline_color.g == b.underline_color.g and
        a.underline_color.b == b.underline_color.b and
        a.underline_color.a == b.underline_color.a;
}

fn appendSgrForAttrs(out: *std.ArrayList(u8), allocator: std.mem.Allocator, attrs: types.CellAttrs) !void {
    try out.writer(allocator).print(
        "\x1b[0{s}{s}{s}{s};38;2;{d};{d};{d};48;2;{d};{d};{d};58;2;{d};{d};{d}m",
        .{
            if (attrs.bold) ";1" else "",
            if (attrs.underline) ";4" else "",
            if (attrs.reverse) ";7" else "",
            if (attrs.blink) (if (attrs.blink_fast) ";6" else ";5") else "",
            attrs.fg.r,
            attrs.fg.g,
            attrs.fg.b,
            attrs.bg.r,
            attrs.bg.g,
            attrs.bg.b,
            attrs.underline_color.r,
            attrs.underline_color.g,
            attrs.underline_color.b,
        },
    );
}

fn appendAnsiRow(out: *std.ArrayList(u8), allocator: std.mem.Allocator, row_cells: []const Cell) !void {
    var active_attrs: ?types.CellAttrs = null;
    var col_idx: usize = 0;
    while (col_idx < row_cells.len) : (col_idx += 1) {
        const cell = row_cells[col_idx];
        if (cell.x != 0 or cell.y != 0) continue;

        if (active_attrs == null or !attrsEqual(active_attrs.?, cell.attrs)) {
            try appendSgrForAttrs(out, allocator, cell.attrs);
            active_attrs = cell.attrs;
        }
        try appendCellText(out, allocator, cell);
    }

    if (active_attrs != null) {
        try out.appendSlice(allocator, "\x1b[0m");
    }
    try out.append(allocator, '\n');
}

fn coreVisibleRow(self: *TerminalCore, cells: []const Cell, rows: usize, cols: usize, history: usize, line_idx: usize) ?[]const Cell {
    if (line_idx < history) return self.scrollbackRow(@intCast(cols), self.primary.defaultCell(), line_idx);
    const grid_row = line_idx - history;
    if (grid_row >= rows or cols == 0) return null;
    const row_start = grid_row * cols;
    return cells[row_start .. row_start + cols];
}
