const std = @import("std");
const harness = @import("terminal/replay_harness.zig");

test "terminal replay harness" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    var args = std.process.args();
    _ = args.next();

    var run_all = false;
    var list_only = false;
    var fixture_name: ?[]const u8 = null;

    while (args.next()) |arg| {
        if (std.mem.eql(u8, arg, "--all")) {
            run_all = true;
        } else if (std.mem.eql(u8, arg, "--list")) {
            list_only = true;
        } else if (std.mem.eql(u8, arg, "--fixture")) {
            fixture_name = args.next() orelse return error.MissingFixtureName;
        }
    }

    const vt_dir = "fixtures/terminal";
    const encoder_dir = "fixtures/terminal/encoder";

    const vt_fixtures = try loadFixturesOptional(allocator, vt_dir, false);
    defer harness.deinitFixtures(allocator, vt_fixtures);
    const encoder_fixtures = try loadFixturesOptional(allocator, encoder_dir, true);
    defer harness.deinitFixtures(allocator, encoder_fixtures);

    sortFixtures(vt_fixtures);
    sortFixtures(encoder_fixtures);

    if (list_only) {
        listFixtures(vt_fixtures, encoder_fixtures);
        return;
    }

    if (!run_all and fixture_name == null) {
        return;
    }

    if (run_all) {
        var first = true;
        for (vt_fixtures) |*fixture| {
            if (fixture.meta.fixture_type == .encoder) continue;
            if (!first) std.debug.print("\n---\n", .{});
            first = false;
            std.debug.print("fixture: {s}\n", .{fixture.name});
            const output = try harness.runFixture(allocator, fixture);
            defer allocator.free(output);
            std.debug.print("{s}", .{output});
        }
        for (encoder_fixtures) |*fixture| {
            if (!first) std.debug.print("\n---\n", .{});
            first = false;
            std.debug.print("fixture: encoder:{s}\n", .{fixture.name});
            const output = try harness.runEncoderFixture(allocator, fixture);
            defer allocator.free(output);
            printEncoderBytes(output);
        }
        return;
    }

    const name = fixture_name.?;
    if (std.mem.startsWith(u8, name, "encoder:")) {
        const encoder_name = name["encoder:".len..];
        if (findFixture(encoder_fixtures, encoder_name)) |fixture| {
            const output = try harness.runEncoderFixture(allocator, fixture);
            defer allocator.free(output);
            printEncoderBytes(output);
            return;
        }
        return error.FixtureNotFound;
    }

    if (findFixture(vt_fixtures, name)) |fixture| {
        const output = try harness.runFixture(allocator, fixture);
        defer allocator.free(output);
        std.debug.print("{s}", .{output});
        return;
    }
    if (findFixture(encoder_fixtures, name)) |fixture| {
        const output = try harness.runEncoderFixture(allocator, fixture);
        defer allocator.free(output);
        printEncoderBytes(output);
        return;
    }
    return error.FixtureNotFound;
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

fn listFixtures(vt_fixtures: []harness.Fixture, encoder_fixtures: []harness.Fixture) void {
    for (vt_fixtures) |fixture| {
        std.debug.print("{s}\n", .{fixture.name});
    }
    for (encoder_fixtures) |fixture| {
        std.debug.print("encoder:{s}\n", .{fixture.name});
    }
}

fn findFixture(fixtures: []harness.Fixture, name: []const u8) ?*harness.Fixture {
    for (fixtures) |*fixture| {
        if (std.mem.eql(u8, fixture.name, name)) return fixture;
    }
    return null;
}

fn printEncoderBytes(bytes: []const u8) void {
    std.debug.print("ENCODER_BYTES v1\nbytes: \"", .{});
    for (bytes) |b| {
        switch (b) {
            '\\' => std.debug.print("\\\\", .{}),
            '"' => std.debug.print("\\\"", .{}),
            '\n' => std.debug.print("\\n", .{}),
            '\r' => std.debug.print("\\r", .{}),
            '\t' => std.debug.print("\\t", .{}),
            0x00...0x08, 0x0b...0x0c, 0x0e...0x1f, 0x7f => std.debug.print("\\x{x:0>2}", .{b}),
            else => std.debug.print("{c}", .{b}),
        }
    }
    std.debug.print("\"\n", .{});
}
