const std = @import("std");
const screen_mod = @import("../model/screen.zig");
const types = @import("../model/types.zig");
const app_logger = @import("../../app_logger.zig");

pub const KittyImageFormat = enum {
    rgb,
    rgba,
    png,
};

pub const KittyImage = struct {
    id: u32,
    width: u32,
    height: u32,
    format: KittyImageFormat,
    data: []u8,
    version: u64,
};

pub const KittyPlacement = struct {
    image_id: u32,
    placement_id: u32,
    row: u16,
    col: u16,
    cols: u16,
    rows: u16,
    z: i32,
    anchor_row: u64,
    is_virtual: bool,
    parent_image_id: u32,
    parent_placement_id: u32,
    offset_x: i32,
    offset_y: i32,
};

pub const Hyperlink = struct {
    uri: []u8,
};

pub const TerminalSnapshot = struct {
    rows: usize,
    cols: usize,
    cells: []const types.Cell,
    dirty_rows: []const bool,
    dirty_cols_start: []const u16,
    dirty_cols_end: []const u16,
    cursor: types.CursorPos,
    cursor_style: types.CursorStyle,
    cursor_visible: bool,
    dirty: screen_mod.Dirty,
    damage: screen_mod.Damage,
    scrollback_count: usize,
    scrollback_offset: usize,
    selection: ?types.TerminalSelection,
    alt_active: bool,
    screen_reverse: bool,
    generation: u64,
    kitty_images: []const KittyImage,
    kitty_placements: []const KittyPlacement,
    kitty_generation: u64,

    pub fn rowSlice(self: *const TerminalSnapshot, row: usize) []const types.Cell {
        const start = row * self.cols;
        return self.cells[start .. start + self.cols];
    }

    pub fn cellAt(self: *const TerminalSnapshot, row: usize, col: usize) types.Cell {
        return self.cells[row * self.cols + col];
    }
};

pub const DebugSnapshot = struct {
    title: []const u8,
    cwd: []const u8,
    osc_clipboard: []const u8,
    osc_clipboard_pending: bool,
    hyperlinks: []const Hyperlink,
    scrollback_count: usize,
    scrollback_offset: usize,
    focus_reporting: bool,
    selection: ?types.TerminalSelection,
    base_default_attrs: types.CellAttrs,
    render_cache: ?*const @import("render_cache.zig").RenderCache = null,
};

pub fn encodeSnapshot(
    allocator: std.mem.Allocator,
    session: anytype,
    snapshot: TerminalSnapshot,
    debug: DebugSnapshot,
    scrollback_row_fn: anytype,
) ![]u8 {
    var out = std.ArrayList(u8).empty;
    errdefer out.deinit(allocator);

    try appendLine(&out, allocator, "TERM_SNAPSHOT v1");
    try appendLineFmt(&out, allocator, "size: {d}x{d}", .{ snapshot.rows, snapshot.cols });
    try appendLineFmt(
        &out,
        allocator,
        "cursor: r={d} c={d} visible={d} style={s}",
        .{
            snapshot.cursor.row,
            snapshot.cursor.col,
            @intFromBool(snapshot.cursor_visible),
            cursorStyleName(snapshot.cursor_style),
        },
    );
    try appendLineFmt(&out, allocator, "alt: {d}", .{@intFromBool(snapshot.alt_active)});
    if (snapshot.screen_reverse) {
        try appendLineFmt(&out, allocator, "screen_reverse: {d}", .{@intFromBool(snapshot.screen_reverse)});
    }
    try appendLineFmt(
        &out,
        allocator,
        "scrollback: count={d} view_offset={d}",
        .{ debug.scrollback_count, debug.scrollback_offset },
    );
    if (debug.focus_reporting) {
        try appendLine(&out, allocator, "focus_reporting: 1");
    }
    try appendQuotedField(&out, allocator, "title", debug.title);
    try appendQuotedField(&out, allocator, "cwd", debug.cwd);
    var clipboard_buf: ?[]u8 = null;
    if (debug.osc_clipboard_pending and debug.osc_clipboard.len > 0) {
        const encoded_len = std.base64.standard.Encoder.calcSize(debug.osc_clipboard.len);
        clipboard_buf = try allocator.alloc(u8, encoded_len);
        _ = std.base64.standard.Encoder.encode(clipboard_buf.?, debug.osc_clipboard);
    }
    defer if (clipboard_buf) |buf| allocator.free(buf);
    try appendQuotedField(&out, allocator, "clipboard", clipboard_buf orelse "");

    try appendSelection(&out, allocator, debug.selection);

    try appendLine(&out, allocator, "grid:");
    try appendGrid(&out, allocator, snapshot);

    try appendLine(&out, allocator, "attrs:");
    try appendAttrs(&out, allocator, snapshot, debug.base_default_attrs);

    try appendLinks(&out, allocator, debug.hyperlinks);
    try appendScrollback(&out, allocator, session, debug.scrollback_count, scrollback_row_fn);
    try appendKittySummary(&out, allocator, snapshot);

    return out.toOwnedSlice(allocator);
}

fn appendSelection(out: *std.ArrayList(u8), allocator: std.mem.Allocator, selection: ?types.TerminalSelection) !void {
    if (selection == null) {
        try appendLine(out, allocator, "selection: none");
        return;
    }
    const sel = selection.?;
    try appendLineFmt(
        out,
        allocator,
        "selection: active={d} selecting={d} start={d},{d} end={d},{d}",
        .{
            @intFromBool(sel.active),
            @intFromBool(sel.selecting),
            sel.start.row,
            sel.start.col,
            sel.end.row,
            sel.end.col,
        },
    );
}

fn appendGrid(out: *std.ArrayList(u8), allocator: std.mem.Allocator, snapshot: TerminalSnapshot) !void {
    const rows = snapshot.rows;
    const cols = snapshot.cols;
    var row: usize = 0;
    while (row < rows) : (row += 1) {
        try out.appendSlice(allocator, "row");
        try appendInt(out, allocator, row);
        try out.appendSlice(allocator, ":");
        var col: usize = 0;
        while (col < cols) : (col += 1) {
            const cell = snapshot.cells[row * cols + col];
            try out.append(allocator, ' ');
            try appendCellToken(out, allocator, cell);
        }
        try out.append(allocator, '\n');
    }
}

fn appendCellToken(out: *std.ArrayList(u8), allocator: std.mem.Allocator, cell: types.Cell) !void {
    if (cell.width == 0) {
        try out.append(allocator, '#');
        return;
    }
    if (cell.codepoint == 0) {
        try out.append(allocator, '.');
        return;
    }
    if (isCombiningMark(cell.codepoint)) {
        try out.append(allocator, '^');
        return;
    }
    try out.append(allocator, '"');
    try appendCodepoint(out, allocator, cell.codepoint);
    if (cell.combining_len > 0) {
        var i: usize = 0;
        while (i < cell.combining_len and i < cell.combining.len) : (i += 1) {
            try appendCodepoint(out, allocator, cell.combining[i]);
        }
    }
    try out.append(allocator, '"');
}

fn appendCodepoint(out: *std.ArrayList(u8), allocator: std.mem.Allocator, codepoint: u32) !void {
    const log = app_logger.logger("terminal.snapshot");
    var buf: [4]u8 = undefined;
    const len = std.unicode.utf8Encode(@intCast(codepoint), &buf) catch 0;
    if (len == 0) {
        try out.appendSlice(allocator, "\\xEF\\xBF\\xBD");
        return;
    }
    var i: usize = 0;
    while (i < len) : (i += 1) {
        const b = buf[i];
        switch (b) {
            '\\' => try out.appendSlice(allocator, "\\\\"),
            '"' => try out.appendSlice(allocator, "\\\""),
            '\n' => try out.appendSlice(allocator, "\\n"),
            '\r' => try out.appendSlice(allocator, "\\r"),
            '\t' => try out.appendSlice(allocator, "\\t"),
            0x00...0x08, 0x0b...0x0c, 0x0e...0x1f, 0x7f => {
                var esc: [4]u8 = undefined;
                _ = std.fmt.bufPrint(&esc, "\\x{x:0>2}", .{b}) catch |err| {
                    log.logf(.warning, "appendCodepoint escape format failed byte={d}: {s}", .{ b, @errorName(err) });
                    continue;
                };
                try out.appendSlice(allocator, esc[0..]);
            },
            else => try out.append(allocator, b),
        }
    }
}

fn appendAttrs(out: *std.ArrayList(u8), allocator: std.mem.Allocator, snapshot: TerminalSnapshot, base_default: types.CellAttrs) !void {
    const rows = snapshot.rows;
    const cols = snapshot.cols;
    var row: usize = 0;
    while (row < rows) : (row += 1) {
        var col: usize = 0;
        while (col < cols) {
            const cell = snapshot.cells[row * cols + col];
            const attrs = cell.attrs;
            var end_col = col;
            while (end_col + 1 < cols) : (end_col += 1) {
                const next_attrs = snapshot.cells[row * cols + end_col + 1].attrs;
                if (!attrsEqual(attrs, next_attrs)) break;
            }
            try appendAttrsRun(out, allocator, row, col, end_col, attrs, base_default);
            col = end_col + 1;
        }
    }
}

fn appendAttrsRun(
    out: *std.ArrayList(u8),
    allocator: std.mem.Allocator,
    row: usize,
    start_col: usize,
    end_col: usize,
    attrs: types.CellAttrs,
    base_default: types.CellAttrs,
) !void {
    const log = app_logger.logger("terminal.snapshot");
    var fg_buf: [16]u8 = undefined;
    var bg_buf: [16]u8 = undefined;
    var ulc_buf: [16]u8 = undefined;
    const fg = formatColorToken(&fg_buf, attrs.fg, base_default.fg);
    const bg = formatColorToken(&bg_buf, attrs.bg, base_default.bg);
    const ulc = formatColorToken(&ulc_buf, attrs.underline_color, base_default.fg);
    var line_buf: [256]u8 = undefined;
    var blink_buf: [32]u8 = undefined;
    const blink_label = if (attrs.blink)
        std.fmt.bufPrint(
            &blink_buf,
            " blink={d} blink_fast={d}",
            .{ @intFromBool(attrs.blink), @intFromBool(attrs.blink_fast) },
        ) catch ""
    else
        "";
    const line = std.fmt.bufPrint(
        &line_buf,
        "row{d}: cols {d}-{d} fg={s} bg={s} bold={d}{s} rev={d} ul={d} ulc={s} link={d}",
        .{
            row,
            start_col,
            end_col,
            fg,
            bg,
            @intFromBool(attrs.bold),
            blink_label,
            @intFromBool(attrs.reverse),
            @intFromBool(attrs.underline),
            ulc,
            attrs.link_id,
        },
    ) catch |err| {
        log.logf(.warning, "appendAttrsRun line format failed row={d}: {s}", .{ row, @errorName(err) });
        return;
    };
    try out.appendSlice(allocator, line);
    try out.append(allocator, '\n');
}

fn formatColorToken(buf: []u8, color: types.Color, default_color: types.Color) []const u8 {
    if (color.r == default_color.r and
        color.g == default_color.g and
        color.b == default_color.b and
        color.a == default_color.a)
    {
        return "default";
    }
    return std.fmt.bufPrint(buf, "#{x:0>2}{x:0>2}{x:0>2}{x:0>2}", .{
        color.r,
        color.g,
        color.b,
        color.a,
    }) catch "err";
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
        a.underline_color.a == b.underline_color.a and
        a.link_id == b.link_id;
}

fn appendLinks(out: *std.ArrayList(u8), allocator: std.mem.Allocator, links: []const Hyperlink) !void {
    if (links.len == 0) {
        try appendLine(out, allocator, "links: none");
        return;
    }
    try appendLine(out, allocator, "links:");
    for (links, 0..) |link, idx| {
        try out.appendSlice(allocator, "id=");
        try appendInt(out, allocator, idx + 1);
        try out.appendSlice(allocator, " uri=\"");
        try appendEscaped(out, allocator, link.uri);
        try out.appendSlice(allocator, "\"\n");
    }
}

fn appendScrollback(
    out: *std.ArrayList(u8),
    allocator: std.mem.Allocator,
    session: anytype,
    count: usize,
    scrollback_row_fn: anytype,
) !void {
    if (count == 0) {
        try appendLine(out, allocator, "scrollback: none");
        return;
    }
    try appendLine(out, allocator, "scrollback:");
    var idx: usize = 0;
    while (idx < count) : (idx += 1) {
        const row_cells = scrollback_row_fn(session, idx) orelse continue;
        try out.appendSlice(allocator, "line");
        try appendInt(out, allocator, idx);
        try out.appendSlice(allocator, ":");
        for (row_cells) |cell| {
            try out.append(allocator, ' ');
            try appendCellToken(out, allocator, cell);
        }
        try out.append(allocator, '\n');
    }
}

fn appendKittySummary(out: *std.ArrayList(u8), allocator: std.mem.Allocator, snapshot: TerminalSnapshot) !void {
    try appendLine(out, allocator, "kitty:");
    try appendLineFmt(out, allocator, "images={d} placements={d}", .{ snapshot.kitty_images.len, snapshot.kitty_placements.len });
    try appendKittyImageIds(out, allocator, snapshot.kitty_images);
    try appendKittyPlacementIds(out, allocator, snapshot.kitty_placements);
}

fn appendKittyImageIds(out: *std.ArrayList(u8), allocator: std.mem.Allocator, images: []const KittyImage) !void {
    try out.appendSlice(allocator, "image ids: [");
    for (images, 0..) |image, idx| {
        if (idx > 0) try out.appendSlice(allocator, ", ");
        try appendInt(out, allocator, image.id);
    }
    try out.appendSlice(allocator, "]\n");
}

fn appendKittyPlacementIds(out: *std.ArrayList(u8), allocator: std.mem.Allocator, placements: []const KittyPlacement) !void {
    try out.appendSlice(allocator, "placement ids: [");
    for (placements, 0..) |placement, idx| {
        if (idx > 0) try out.appendSlice(allocator, ", ");
        try out.appendSlice(allocator, "(img=");
        try appendInt(out, allocator, placement.image_id);
        try out.appendSlice(allocator, " id=");
        try appendInt(out, allocator, placement.placement_id);
        try out.appendSlice(allocator, ")");
    }
    try out.appendSlice(allocator, "]\n");
}

fn cursorStyleName(style: types.CursorStyle) []const u8 {
    return if (style.blink) switch (style.shape) {
        .block => "block-blink",
        .underline => "underline-blink",
        .bar => "bar-blink",
    } else switch (style.shape) {
        .block => "block-steady",
        .underline => "underline-steady",
        .bar => "bar-steady",
    };
}

fn isCombiningMark(codepoint: u32) bool {
    return (codepoint >= 0x0300 and codepoint <= 0x036F) or
        (codepoint >= 0x1AB0 and codepoint <= 0x1AFF) or
        (codepoint >= 0x1DC0 and codepoint <= 0x1DFF) or
        (codepoint >= 0x20D0 and codepoint <= 0x20FF) or
        (codepoint >= 0xFE20 and codepoint <= 0xFE2F);
}

fn appendQuotedField(out: *std.ArrayList(u8), allocator: std.mem.Allocator, label: []const u8, value: []const u8) !void {
    try out.appendSlice(allocator, label);
    try out.appendSlice(allocator, ": \"");
    try appendEscaped(out, allocator, value);
    try out.appendSlice(allocator, "\"\n");
}

fn appendEscaped(out: *std.ArrayList(u8), allocator: std.mem.Allocator, text: []const u8) !void {
    const log = app_logger.logger("terminal.snapshot");
    for (text) |b| {
        switch (b) {
            '\\' => try out.appendSlice(allocator, "\\\\"),
            '"' => try out.appendSlice(allocator, "\\\""),
            '\n' => try out.appendSlice(allocator, "\\n"),
            '\r' => try out.appendSlice(allocator, "\\r"),
            '\t' => try out.appendSlice(allocator, "\\t"),
            0x00...0x08, 0x0b...0x0c, 0x0e...0x1f, 0x7f => {
                var esc: [4]u8 = undefined;
                _ = std.fmt.bufPrint(&esc, "\\x{x:0>2}", .{b}) catch |err| {
                    log.logf(.warning, "appendEscaped escape format failed byte={d}: {s}", .{ b, @errorName(err) });
                    continue;
                };
                try out.appendSlice(allocator, esc[0..]);
            },
            else => try out.append(allocator, b),
        }
    }
}

fn appendInt(out: *std.ArrayList(u8), allocator: std.mem.Allocator, value: anytype) !void {
    const log = app_logger.logger("terminal.snapshot");
    var buf: [32]u8 = undefined;
    const text = std.fmt.bufPrint(&buf, "{d}", .{value}) catch |err| {
        log.logf(.warning, "appendInt format failed: {s}", .{@errorName(err)});
        return;
    };
    try out.appendSlice(allocator, text);
}

fn appendLine(out: *std.ArrayList(u8), allocator: std.mem.Allocator, text: []const u8) !void {
    try out.appendSlice(allocator, text);
    try out.append(allocator, '\n');
}

fn appendLineFmt(out: *std.ArrayList(u8), allocator: std.mem.Allocator, comptime fmt: []const u8, args: anytype) !void {
    const log = app_logger.logger("terminal.snapshot");
    var buf: [512]u8 = undefined;
    const line = std.fmt.bufPrint(&buf, fmt, args) catch |err| {
        log.logf(.warning, "appendLineFmt format failed: {s}", .{@errorName(err)});
        return;
    };
    try out.appendSlice(allocator, line);
    try out.append(allocator, '\n');
}
