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

    return snapshot_mod.encodeSnapshot(allocator, session, snapshot, debug, terminal.debugScrollbackRow);
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
