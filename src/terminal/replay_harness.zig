const std = @import("std");
const terminal = @import("core/terminal.zig");
const snapshot_mod = @import("core/snapshot.zig");
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
    try validateAssertions(fixture, snapshot, debug);

    return snapshot_mod.encodeSnapshot(allocator, session, snapshot, debug, terminal.debugScrollbackRow);
}

pub fn runEncoderFixture(
    allocator: std.mem.Allocator,
    fixture: *const Fixture,
) ![]u8 {
    const encoder = fixture.meta.encoder orelse return error.MissingEncoderSpec;
    if (encoder.key == null and encoder.char == null) return error.MissingEncoderValue;
    if (encoder.key != null and encoder.char != null) return error.InvalidEncoderSpec;
    try validateEncoderAssertions(fixture);

    if (encoder.key) |key| {
        return input_mod.encodeKeyBytesForTest(allocator, key, encoder.mod, encoder.flags);
    }
    return input_mod.encodeCharBytesForTest(allocator, encoder.char.?, encoder.mod, encoder.flags);
}

fn validateEncoderAssertions(fixture: *const Fixture) !void {
    for (fixture.meta.assertions) |tag| {
        if (std.mem.eql(u8, tag, "encoder")) continue;
        return error.UnknownAssertionTag;
    }
}

fn validateAssertions(
    fixture: *const Fixture,
    snapshot: terminal.TerminalSnapshot,
    debug: terminal.DebugSnapshot,
) !void {
    for (fixture.meta.assertions) |tag| {
        if (std.mem.eql(u8, tag, "grid")) {
            if (!snapshotHasNonDefaultGrid(snapshot)) return error.AssertionGridNotExercised;
            continue;
        }
        if (std.mem.eql(u8, tag, "cursor")) {
            if (snapshot.cursor.row == fixture.meta.cursor.row and snapshot.cursor.col == fixture.meta.cursor.col) {
                return error.AssertionCursorNotExercised;
            }
            continue;
        }
        if (std.mem.eql(u8, tag, "attrs")) {
            if (!snapshotHasNonDefaultAttrs(snapshot, debug.base_default_attrs)) return error.AssertionAttrsNotExercised;
            continue;
        }
        if (std.mem.eql(u8, tag, "clipboard")) {
            if (debug.osc_clipboard.len == 0) return error.AssertionClipboardNotExercised;
            continue;
        }
        if (std.mem.eql(u8, tag, "hyperlinks")) {
            if (debug.hyperlinks.len == 0) return error.AssertionHyperlinksNotExercised;
            continue;
        }
        if (std.mem.eql(u8, tag, "selection")) {
            if (debug.selection == null) return error.AssertionSelectionNotExercised;
            continue;
        }
        if (std.mem.eql(u8, tag, "scrollback")) {
            if (!fixtureExercisesScrollbackOrScrollSemantics(fixture, debug)) {
                return error.AssertionScrollbackNotExercised;
            }
            continue;
        }
        if (std.mem.eql(u8, tag, "title")) {
            if (std.mem.eql(u8, debug.title, "Terminal")) return error.AssertionTitleNotExercised;
            continue;
        }
        if (std.mem.eql(u8, tag, "cwd")) {
            if (debug.cwd.len == 0) return error.AssertionCwdNotExercised;
            continue;
        }
        if (std.mem.eql(u8, tag, "kitty")) {
            if (snapshot.kitty_generation == 0) return error.AssertionKittyNotExercised;
            continue;
        }
        if (std.mem.eql(u8, tag, "alt-screen")) {
            const input = fixture.input;
            const has_alt = std.mem.indexOf(u8, input, "\x1b[?47h") != null or
                std.mem.indexOf(u8, input, "\x1b[?47l") != null or
                std.mem.indexOf(u8, input, "\x1b[?1047h") != null or
                std.mem.indexOf(u8, input, "\x1b[?1047l") != null or
                std.mem.indexOf(u8, input, "\x1b[?1049h") != null or
                std.mem.indexOf(u8, input, "\x1b[?1049l") != null;
            if (!has_alt) return error.AssertionAltScreenNotExercised;
            continue;
        }
        return error.UnknownAssertionTag;
    }
}

fn snapshotHasNonDefaultGrid(snapshot: terminal.TerminalSnapshot) bool {
    for (snapshot.cells) |cell| {
        if (cell.width == 0) return true;
        if (cell.codepoint != 0) return true;
        if (cell.combining_len > 0) return true;
    }
    return false;
}

fn snapshotHasNonDefaultAttrs(snapshot: terminal.TerminalSnapshot, base_default: terminal.CellAttrs) bool {
    for (snapshot.cells) |cell| {
        if (!attrsEqual(cell.attrs, base_default)) return true;
    }
    return false;
}

fn fixtureExercisesScrollbackOrScrollSemantics(fixture: *const Fixture, debug: terminal.DebugSnapshot) bool {
    if (debug.scrollback_count > 0 or debug.scrollback_offset > 0) return true;
    const input = fixture.input;
    if (inputHasCsiFinal(input, 'r') or // DECSTBM set/reset scroll region
        inputHasCsiFinal(input, 'S') or // SU
        inputHasCsiFinal(input, 'T'))
    {
        return true;
    }
    return inputLineBreakCount(input) >= fixture.meta.rows;
}

fn inputHasCsiFinal(input: []const u8, final: u8) bool {
    var i: usize = 0;
    while (i + 2 < input.len) : (i += 1) {
        if (input[i] != 0x1b or input[i + 1] != '[') continue;
        var j = i + 2;
        while (j < input.len) : (j += 1) {
            const b = input[j];
            if (b >= 0x40 and b <= 0x7e) {
                if (b == final) return true;
                break;
            }
        }
        i = j;
    }
    return false;
}

fn inputLineBreakCount(input: []const u8) usize {
    var count: usize = 0;
    var i: usize = 0;
    while (i < input.len) : (i += 1) {
        if (input[i] == '\n') {
            count += 1;
            continue;
        }
        if (input[i] == '\r') {
            count += 1;
            if (i + 1 < input.len and input[i + 1] == '\n') i += 1;
        }
    }
    return count;
}

fn attrsEqual(a: terminal.CellAttrs, b: terminal.CellAttrs) bool {
    return a.fg.r == b.fg.r and a.fg.g == b.fg.g and a.fg.b == b.fg.b and a.fg.a == b.fg.a and
        a.bg.r == b.bg.r and a.bg.g == b.bg.g and a.bg.b == b.bg.b and a.bg.a == b.bg.a and
        a.bold == b.bold and a.blink == b.blink and a.blink_fast == b.blink_fast and
        a.reverse == b.reverse and a.underline == b.underline and
        a.underline_color.r == b.underline_color.r and
        a.underline_color.g == b.underline_color.g and
        a.underline_color.b == b.underline_color.b and
        a.underline_color.a == b.underline_color.a and
        a.link_id == b.link_id;
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
