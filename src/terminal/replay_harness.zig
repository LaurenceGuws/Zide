const std = @import("std");
const terminal = @import("core/terminal.zig");
const input_mod = @import("input/input.zig");
const types = @import("model/types.zig");

pub const FixtureType = enum {
    vt,
    harness_api,
    encoder,
};

pub const LineEnding = enum {
    lf,
    crlf,
    cr,
};

pub const SelectionOp = enum {
    start,
    update,
    finish,
};

pub const SelectionAction = struct {
    op: SelectionOp,
    row: usize = 0,
    col: usize = 0,
};

pub const EncoderSpec = struct {
    key: ?u32 = null,
    char: ?u32 = null,
    mod: u8 = 0,
    flags: u32 = 0,
};

pub const FixtureMeta = struct {
    fixture_type: FixtureType,
    rows: u16,
    cols: u16,
    cursor: types.CursorPos = .{ .row = 0, .col = 0 },
    line_ending: LineEnding = .lf,
    assertions: []const []const u8 = &.{},
    selection: []const SelectionAction = &.{},
    encoder: ?EncoderSpec = null,
};

pub const Fixture = struct {
    name: []const u8,
    meta: FixtureMeta,
    input: []const u8,
    golden: ?[]const u8,
    parsed: std.json.Parsed(FixtureMeta),
};

pub fn loadFixtures(allocator: std.mem.Allocator, dir_path: []const u8) ![]Fixture {
    var dir = try std.fs.cwd().openDir(dir_path, .{ .iterate = true });
    defer dir.close();

    var fixtures = std.ArrayList(Fixture).empty;
    errdefer {
        for (fixtures.items) |*fixture| {
            deinitFixture(allocator, fixture);
        }
        fixtures.deinit(allocator);
    }

    var it = dir.iterate();
    while (try it.next()) |entry| {
        if (entry.kind != .file) continue;
        if (!std.mem.endsWith(u8, entry.name, ".vt")) continue;

        const stem_len = entry.name.len - 3;
        const stem = entry.name[0..stem_len];
        const name = try allocator.dupe(u8, stem);
        errdefer allocator.free(name);

        const file_bytes = try dir.readFileAlloc(allocator, entry.name, 1024 * 1024);
        errdefer allocator.free(file_bytes);

        const meta_name = try std.fmt.allocPrint(allocator, "{s}.json", .{ stem });
        defer allocator.free(meta_name);
        const meta_bytes = try dir.readFileAlloc(allocator, meta_name, 64 * 1024);
        defer allocator.free(meta_bytes);
        const parsed = try std.json.parseFromSlice(
            FixtureMeta,
            allocator,
            meta_bytes,
            .{
                .ignore_unknown_fields = true,
                .allocate = .alloc_always,
            },
        );
        errdefer parsed.deinit();

        var golden: ?[]const u8 = null;
        const golden_name = try std.fmt.allocPrint(allocator, "{s}.golden", .{ stem });
        defer allocator.free(golden_name);
        if (dir.openFile(golden_name, .{})) |golden_file| {
            defer golden_file.close();
            golden = try golden_file.readToEndAlloc(allocator, 4 * 1024 * 1024);
        } else |_| {}

        try fixtures.append(allocator, .{
            .name = name,
            .meta = parsed.value,
            .input = file_bytes,
            .golden = golden,
            .parsed = parsed,
        });
    }

    return fixtures.toOwnedSlice(allocator);
}

pub fn loadEncoderFixtures(allocator: std.mem.Allocator, dir_path: []const u8) ![]Fixture {
    var dir = try std.fs.cwd().openDir(dir_path, .{ .iterate = true });
    defer dir.close();

    var fixtures = std.ArrayList(Fixture).empty;
    errdefer {
        for (fixtures.items) |*fixture| {
            deinitFixture(allocator, fixture);
        }
        fixtures.deinit(allocator);
    }

    var it = dir.iterate();
    while (try it.next()) |entry| {
        if (entry.kind != .file) continue;
        if (!std.mem.endsWith(u8, entry.name, ".json")) continue;

        const stem_len = entry.name.len - 5;
        const stem = entry.name[0..stem_len];
        const name = try allocator.dupe(u8, stem);
        errdefer allocator.free(name);

        const meta_bytes = try dir.readFileAlloc(allocator, entry.name, 64 * 1024);
        defer allocator.free(meta_bytes);
        const parsed = try std.json.parseFromSlice(
            FixtureMeta,
            allocator,
            meta_bytes,
            .{
                .ignore_unknown_fields = true,
                .allocate = .alloc_always,
            },
        );
        errdefer parsed.deinit();

        var golden: ?[]const u8 = null;
        const golden_name = try std.fmt.allocPrint(allocator, "{s}.golden", .{ stem });
        defer allocator.free(golden_name);
        if (dir.openFile(golden_name, .{})) |golden_file| {
            defer golden_file.close();
            golden = try golden_file.readToEndAlloc(allocator, 64 * 1024);
        } else |_| {}

        try fixtures.append(allocator, .{
            .name = name,
            .meta = parsed.value,
            .input = &.{},
            .golden = golden,
            .parsed = parsed,
        });
    }

    return fixtures.toOwnedSlice(allocator);
}

pub fn deinitFixtures(allocator: std.mem.Allocator, fixtures: []Fixture) void {
    for (fixtures) |*fixture| {
        deinitFixture(allocator, fixture);
    }
    allocator.free(fixtures);
}

fn deinitFixture(allocator: std.mem.Allocator, fixture: *Fixture) void {
    allocator.free(fixture.name);
    allocator.free(fixture.input);
    if (fixture.golden) |golden| allocator.free(golden);
    fixture.parsed.deinit();
}

pub fn runFixture(
    allocator: std.mem.Allocator,
    fixture: *const Fixture,
) ![]u8 {
    if (fixture.meta.rows == 0 or fixture.meta.cols == 0) {
        return error.InvalidFixtureSize;
    }

    var session = try terminal.TerminalSession.init(allocator, fixture.meta.rows, fixture.meta.cols);
    defer session.deinit();

    terminal.debugSetCursor(session, fixture.meta.cursor.row, fixture.meta.cursor.col);

    const normalized = try normalizeLineEndings(allocator, fixture.input, fixture.meta.line_ending);
    defer allocator.free(normalized);
    terminal.debugFeedBytes(session, normalized);

    if (fixture.meta.fixture_type == .harness_api) {
        applySelectionActions(session, fixture.meta.selection);
    }

    const snapshot = session.snapshot();
    const debug = terminal.debugSnapshot(session);

    return encodeSnapshot(allocator, session, snapshot, debug);
}

pub fn runEncoderFixture(
    allocator: std.mem.Allocator,
    fixture: *const Fixture,
) ![]u8 {
    const encoder = fixture.meta.encoder orelse return error.MissingEncoderSpec;
    if (encoder.key == null and encoder.char == null) return error.MissingEncoderValue;
    if (encoder.key != null and encoder.char != null) return error.InvalidEncoderSpec;

    if (encoder.key) |key| {
        return input_mod.encodeKeyBytesForTest(allocator, key, encoder.mod, encoder.flags);
    }
    return input_mod.encodeCharBytesForTest(allocator, encoder.char.?, encoder.mod, encoder.flags);
}

fn applySelectionActions(session: *terminal.TerminalSession, actions: []const SelectionAction) void {
    for (actions) |action| {
        switch (action.op) {
            .start => session.startSelection(action.row, action.col),
            .update => session.updateSelection(action.row, action.col),
            .finish => session.finishSelection(),
        }
    }
}

fn normalizeLineEndings(
    allocator: std.mem.Allocator,
    input_bytes: []const u8,
    mode: LineEnding,
) ![]u8 {
    if (input_bytes.len == 0) return allocator.alloc(u8, 0);
    var out = std.ArrayList(u8).empty;
    errdefer out.deinit(allocator);

    var i: usize = 0;
    while (i < input_bytes.len) {
        const b = input_bytes[i];
        if (b == '\r') {
            if (i + 1 < input_bytes.len and input_bytes[i + 1] == '\n') {
                i += 2;
            } else {
                i += 1;
            }
            switch (mode) {
                .lf => try out.append(allocator, '\n'),
                .crlf => try out.appendSlice(allocator, "\r\n"),
                .cr => try out.append(allocator, '\r'),
            }
            continue;
        }
        if (b == '\n') {
            i += 1;
            switch (mode) {
                .lf => try out.append(allocator, '\n'),
                .crlf => try out.appendSlice(allocator, "\r\n"),
                .cr => try out.append(allocator, '\r'),
            }
            continue;
        }
        try out.append(allocator, b);
        i += 1;
    }
    return out.toOwnedSlice(allocator);
}

pub fn encodeSnapshot(
    allocator: std.mem.Allocator,
    session: *terminal.TerminalSession,
    snapshot: terminal.TerminalSnapshot,
    debug: terminal.DebugSnapshot,
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
    try appendLineFmt(
        &out,
        allocator,
        "scrollback: count={d} view_offset={d}",
        .{ debug.scrollback_count, debug.scrollback_offset },
    );
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
    try appendScrollback(&out, allocator, session, debug.scrollback_count);
    try appendKittySummary(&out, allocator, snapshot);

    return out.toOwnedSlice(allocator);
}

fn appendSelection(out: *std.ArrayList(u8), allocator: std.mem.Allocator, selection: ?terminal.TerminalSelection) !void {
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

fn appendGrid(out: *std.ArrayList(u8), allocator: std.mem.Allocator, snapshot: terminal.TerminalSnapshot) !void {
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

fn appendCellToken(out: *std.ArrayList(u8), allocator: std.mem.Allocator, cell: terminal.Cell) !void {
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
    try out.append(allocator, '"');
}

fn appendCodepoint(out: *std.ArrayList(u8), allocator: std.mem.Allocator, codepoint: u32) !void {
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
                _ = std.fmt.bufPrint(&esc, "\\x{x:0>2}", .{b}) catch continue;
                try out.appendSlice(allocator, esc[0..]);
            },
            else => try out.append(allocator, b),
        }
    }
}

fn appendAttrs(out: *std.ArrayList(u8), allocator: std.mem.Allocator, snapshot: terminal.TerminalSnapshot, base_default: types.CellAttrs) !void {
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
    var fg_buf: [16]u8 = undefined;
    var bg_buf: [16]u8 = undefined;
    var ulc_buf: [16]u8 = undefined;
    const fg = formatColorToken(&fg_buf, attrs.fg, base_default.fg);
    const bg = formatColorToken(&bg_buf, attrs.bg, base_default.bg);
    const ulc = formatColorToken(&ulc_buf, attrs.underline_color, base_default.fg);
    var line_buf: [256]u8 = undefined;
    const line = std.fmt.bufPrint(
        &line_buf,
        "row{d}: cols {d}-{d} fg={s} bg={s} bold={d} rev={d} ul={d} ulc={s} link={d}",
        .{
            row,
            start_col,
            end_col,
            fg,
            bg,
            @intFromBool(attrs.bold),
            @intFromBool(attrs.reverse),
            @intFromBool(attrs.underline),
            ulc,
            attrs.link_id,
        },
    ) catch return;
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
        a.reverse == b.reverse and
        a.underline == b.underline and
        a.underline_color.r == b.underline_color.r and
        a.underline_color.g == b.underline_color.g and
        a.underline_color.b == b.underline_color.b and
        a.underline_color.a == b.underline_color.a and
        a.link_id == b.link_id;
}

fn appendLinks(out: *std.ArrayList(u8), allocator: std.mem.Allocator, links: []const terminal.Hyperlink) !void {
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

fn appendScrollback(out: *std.ArrayList(u8), allocator: std.mem.Allocator, session: *terminal.TerminalSession, count: usize) !void {
    if (count == 0) {
        try appendLine(out, allocator, "scrollback: none");
        return;
    }
    try appendLine(out, allocator, "scrollback:");
    var idx: usize = 0;
    while (idx < count) : (idx += 1) {
        const row_cells = terminal.debugScrollbackRow(session, idx) orelse continue;
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

fn appendKittySummary(out: *std.ArrayList(u8), allocator: std.mem.Allocator, snapshot: terminal.TerminalSnapshot) !void {
    try appendLine(out, allocator, "kitty:");
    try appendLineFmt(out, allocator, "images={d} placements={d}", .{ snapshot.kitty_images.len, snapshot.kitty_placements.len });
    try appendKittyImageIds(out, allocator, snapshot.kitty_images);
    try appendKittyPlacementIds(out, allocator, snapshot.kitty_placements);
}

fn appendKittyImageIds(out: *std.ArrayList(u8), allocator: std.mem.Allocator, images: []const terminal.KittyImage) !void {
    try out.appendSlice(allocator, "image ids: [");
    for (images, 0..) |image, idx| {
        if (idx > 0) try out.appendSlice(allocator, ", ");
        try appendInt(out, allocator, image.id);
    }
    try out.appendSlice(allocator, "]\n");
}

fn appendKittyPlacementIds(out: *std.ArrayList(u8), allocator: std.mem.Allocator, placements: []const terminal.KittyPlacement) !void {
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
    for (text) |b| {
        switch (b) {
            '\\' => try out.appendSlice(allocator, "\\\\"),
            '"' => try out.appendSlice(allocator, "\\\""),
            '\n' => try out.appendSlice(allocator, "\\n"),
            '\r' => try out.appendSlice(allocator, "\\r"),
            '\t' => try out.appendSlice(allocator, "\\t"),
            0x00...0x08, 0x0b...0x0c, 0x0e...0x1f, 0x7f => {
                var esc: [4]u8 = undefined;
                _ = std.fmt.bufPrint(&esc, "\\x{x:0>2}", .{b}) catch continue;
                try out.appendSlice(allocator, esc[0..]);
            },
            else => try out.append(allocator, b),
        }
    }
}

fn appendInt(out: *std.ArrayList(u8), allocator: std.mem.Allocator, value: anytype) !void {
    var buf: [32]u8 = undefined;
    const text = std.fmt.bufPrint(&buf, "{d}", .{value}) catch return;
    try out.appendSlice(allocator, text);
}

fn appendLine(out: *std.ArrayList(u8), allocator: std.mem.Allocator, text: []const u8) !void {
    try out.appendSlice(allocator, text);
    try out.append(allocator, '\n');
}

fn appendLineFmt(out: *std.ArrayList(u8), allocator: std.mem.Allocator, comptime fmt: []const u8, args: anytype) !void {
    var buf: [512]u8 = undefined;
    const line = std.fmt.bufPrint(&buf, fmt, args) catch return;
    try out.appendSlice(allocator, line);
    try out.append(allocator, '\n');
}
