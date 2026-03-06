const std = @import("std");
const app_logger = @import("app_logger.zig");
const harness = @import("terminal/replay_harness.zig");

pub const terminal_replay_enabled = true;

const Mode = enum {
    none,
    list,
    fixture,
    all,
};

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    if (std.c.getenv("ZIDE_LOG") == null and
        std.c.getenv("ZIDE_LOG_CONSOLE") == null and
        std.c.getenv("ZIDE_LOG_FILE") == null)
    {
        app_logger.setConsoleFilterString("terminal.replay") catch |err| {
            std.log.warn("terminal_replay: failed to set console log filter: {s}", .{@errorName(err)});
        };
    }
    app_logger.init() catch |err| {
        std.log.warn("terminal_replay: logger init failed: {s}", .{@errorName(err)});
    };
    defer app_logger.deinit();

    const log = app_logger.logger("terminal.replay");

    var args = std.process.args();
    _ = args.next();

    var mode: Mode = .none;
    var fixture_name: ?[]const u8 = null;
    var update_goldens = false;

    while (args.next()) |arg| {
        if (std.mem.eql(u8, arg, "--list")) {
            mode = .list;
        } else if (std.mem.eql(u8, arg, "--all")) {
            mode = .all;
        } else if (std.mem.eql(u8, arg, "--fixture")) {
            fixture_name = args.next() orelse return error.MissingFixtureName;
            mode = .fixture;
        } else if (std.mem.eql(u8, arg, "--update-goldens")) {
            update_goldens = true;
        }
    }

    switch (mode) {
        .list => log.logf(.info, "mode=list", .{}),
        .fixture => log.logf(.info, "mode=fixture name={s}", .{fixture_name.?}),
        .all => log.logf(.info, "mode=all", .{}),
        .none => log.logf(.info, "mode=none", .{}),
    }

    const vt_dir = "fixtures/terminal";
    const encoder_dir = "fixtures/terminal/encoder";

    const vt_fixtures = try loadFixturesOptional(allocator, vt_dir, false);
    defer harness.deinitFixtures(allocator, vt_fixtures);
    const encoder_fixtures = try loadFixturesOptional(allocator, encoder_dir, true);
    defer harness.deinitFixtures(allocator, encoder_fixtures);

    sortFixtures(vt_fixtures);
    sortFixtures(encoder_fixtures);

    if (mode == .list) {
        listFixtures(log, allocator, vt_fixtures, encoder_fixtures);
        return;
    }

    if (mode == .fixture) {
        const name = fixture_name.?;
        if (std.mem.startsWith(u8, name, "encoder:")) {
            const encoder_name = name["encoder:".len..];
            if (findFixture(encoder_fixtures, encoder_name)) |fixture| {
                try runEncoderFixture(log, allocator, fixture, update_goldens);
                return;
            }
            return error.FixtureNotFound;
        }
        if (findFixture(vt_fixtures, name)) |fixture| {
            try runVtFixture(log, allocator, fixture, update_goldens);
            return;
        }
        if (findFixture(encoder_fixtures, name)) |fixture| {
            try runEncoderFixture(log, allocator, fixture, update_goldens);
            return;
        }
        return error.FixtureNotFound;
    }

    if (mode == .all) {
        if (vt_fixtures.len == 0 and encoder_fixtures.len == 0) {
            log.logf(.info, "no fixtures found", .{});
            return;
        }
        for (vt_fixtures) |*fixture| {
            log.logf(.info, "running fixture {s}", .{fixture.name});
            try runVtFixture(log, allocator, fixture, update_goldens);
        }
        for (encoder_fixtures) |*fixture| {
            log.logf(.info, "running fixture encoder:{s}", .{fixture.name});
            try runEncoderFixture(log, allocator, fixture, update_goldens);
        }
    }
}

fn loadFixturesOptional(
    allocator: std.mem.Allocator,
    dir_path: []const u8,
    encoder_only: bool,
) ![]harness.Fixture {
    return if (encoder_only)
        harness.loadEncoderFixtures(allocator, dir_path) catch |err| switch (err) {
            error.FileNotFound, error.NotDir => allocator.alloc(harness.Fixture, 0),
            else => return err,
        }
    else
        harness.loadFixtures(allocator, dir_path) catch |err| switch (err) {
            error.FileNotFound, error.NotDir => allocator.alloc(harness.Fixture, 0),
            else => return err,
        };
}

fn sortFixtures(fixtures: []harness.Fixture) void {
    std.sort.block(harness.Fixture, fixtures, {}, struct {
        fn lessThan(_: void, a: harness.Fixture, b: harness.Fixture) bool {
            return std.mem.lessThan(u8, a.name, b.name);
        }
    }.lessThan);
}

fn listFixtures(
    log: app_logger.Logger,
    allocator: std.mem.Allocator,
    vt_fixtures: []harness.Fixture,
    encoder_fixtures: []harness.Fixture,
) void {
    if (vt_fixtures.len == 0 and encoder_fixtures.len == 0) {
        log.logf(.info, "fixtures: (none)", .{});
        return;
    }
    var out = std.ArrayList(u8).empty;
    defer out.deinit(allocator);

    for (vt_fixtures, 0..) |fixture, idx| {
        if (idx > 0) tryAppend(&out, allocator, ", ");
        tryAppend(&out, allocator, fixture.name);
    }
    for (encoder_fixtures, 0..) |fixture, idx| {
        if (vt_fixtures.len > 0 or idx > 0) tryAppend(&out, allocator, ", ");
        tryAppend(&out, allocator, "encoder:");
        tryAppend(&out, allocator, fixture.name);
    }
    log.logf(.info, "fixtures: {s}", .{out.items});
}

fn runVtFixture(
    log: app_logger.Logger,
    allocator: std.mem.Allocator,
    fixture: *const harness.Fixture,
    update_goldens: bool,
) !void {
    const output = try harness.runFixture(allocator, fixture);
    defer allocator.free(output);
    const path = try writeOutputFile(allocator, fixture.name, false, output);
    defer allocator.free(path);
    log.logf(.info, "wrote {s}", .{path});
    if (update_goldens) {
        const golden_path = try writeGoldenFile(allocator, fixture.name, false, output);
        defer allocator.free(golden_path);
        log.logf(.info, "updated golden {s}", .{golden_path});
        return;
    }
    try compareGolden(fixture.name, fixture.golden, output);
}

fn runEncoderFixture(
    log: app_logger.Logger,
    allocator: std.mem.Allocator,
    fixture: *const harness.Fixture,
    update_goldens: bool,
) !void {
    const bytes = try harness.runEncoderFixture(allocator, fixture);
    defer allocator.free(bytes);
    const output = try formatEncoderOutput(allocator, bytes);
    defer allocator.free(output);
    const path = try writeOutputFile(allocator, fixture.name, true, output);
    defer allocator.free(path);
    log.logf(.info, "wrote {s}", .{path});
    if (update_goldens) {
        const golden_path = try writeGoldenFile(allocator, fixture.name, true, output);
        defer allocator.free(golden_path);
        log.logf(.info, "updated golden {s}", .{golden_path});
        return;
    }
    try compareGolden(fixture.name, fixture.golden, output);
}

fn formatEncoderOutput(allocator: std.mem.Allocator, bytes: []const u8) ![]u8 {
    var out = std.ArrayList(u8).empty;
    errdefer out.deinit(allocator);
    try out.appendSlice(allocator, "ENCODER_BYTES v1\nbytes: \"");
    for (bytes) |b| {
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
    try out.appendSlice(allocator, "\"\n");
    return out.toOwnedSlice(allocator);
}

fn writeOutputFile(
    allocator: std.mem.Allocator,
    name: []const u8,
    is_encoder: bool,
    contents: []const u8,
) ![]u8 {
    const dir_path = "zig-cache/terminal-replay";
    try std.fs.cwd().makePath(dir_path);
    const file_name = if (is_encoder)
        try std.fmt.allocPrint(allocator, "encoder-{s}.out", .{name})
    else
        try std.fmt.allocPrint(allocator, "{s}.out", .{name});
    defer allocator.free(file_name);
    const full_path = try std.fs.path.join(allocator, &.{ dir_path, file_name });
    var file = try std.fs.cwd().createFile(full_path, .{ .truncate = true });
    defer file.close();
    try file.writeAll(contents);
    return full_path;
}

fn writeGoldenFile(
    allocator: std.mem.Allocator,
    name: []const u8,
    is_encoder: bool,
    contents: []const u8,
) ![]u8 {
    const dir_path = if (is_encoder)
        "fixtures/terminal/encoder"
    else
        "fixtures/terminal";
    const file_name = try std.fmt.allocPrint(allocator, "{s}.golden", .{name});
    defer allocator.free(file_name);
    const full_path = try std.fs.path.join(allocator, &.{ dir_path, file_name });
    var file = try std.fs.cwd().createFile(full_path, .{ .truncate = true });
    defer file.close();
    try file.writeAll(contents);
    return full_path;
}

fn findFixture(fixtures: []harness.Fixture, name: []const u8) ?*harness.Fixture {
    for (fixtures) |*fixture| {
        if (std.mem.eql(u8, fixture.name, name)) return fixture;
    }
    return null;
}

fn tryAppend(out: *std.ArrayList(u8), allocator: std.mem.Allocator, text: []const u8) void {
    _ = out.appendSlice(allocator, text) catch {};
}

fn compareGolden(name: []const u8, golden: ?[]const u8, output: []const u8) !void {
    const expected = golden orelse return;
    if (std.mem.eql(u8, expected, output)) return;
    reportGoldenDiff(name, expected, output);
    return error.GoldenMismatch;
}

fn reportGoldenDiff(name: []const u8, expected: []const u8, actual: []const u8) void {
    std.debug.print("golden mismatch: {s}\n", .{name});
    std.debug.print("expected bytes: {d} actual bytes: {d}\n", .{ expected.len, actual.len });
    var exp_idx: usize = 0;
    var act_idx: usize = 0;
    var line_no: usize = 1;
    while (exp_idx < expected.len or act_idx < actual.len) : (line_no += 1) {
        const exp_line = readLine(expected, &exp_idx);
        const act_line = readLine(actual, &act_idx);
        if (!std.mem.eql(u8, exp_line, act_line)) {
            const col = firstDiffColumn(exp_line, act_line);
            std.debug.print("first diff at line {d} col {d}\n", .{ line_no, col + 1 });
            std.debug.print("expected: {s}\n", .{exp_line});
            std.debug.print("actual:   {s}\n", .{act_line});
            return;
        }
    }
}

fn readLine(data: []const u8, idx: *usize) []const u8 {
    if (idx.* >= data.len) return &.{};
    const start = idx.*;
    var i = start;
    while (i < data.len and data[i] != '\n') : (i += 1) {}
    const line = data[start..i];
    if (i < data.len and data[i] == '\n') i += 1;
    idx.* = i;
    return line;
}

fn firstDiffColumn(expected: []const u8, actual: []const u8) usize {
    const min_len = @min(expected.len, actual.len);
    var col: usize = 0;
    while (col < min_len) : (col += 1) {
        if (expected[col] != actual[col]) break;
    }
    return col;
}
