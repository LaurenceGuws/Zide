const std = @import("std");

const Layer = enum {
    core,
    model,
    parser,
    protocol,
    io,
    input,
    kitty,
    harness,
    other,
};

pub fn main() !void {
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();
    const allocator = arena.allocator();

    const cwd = std.fs.cwd();
    const root_path = try cwd.realpathAlloc(allocator, ".");
    const terminal_root = try std.fs.path.join(allocator, &.{ root_path, "src", "terminal" });
    const terminal_root_sep = try std.mem.concat(allocator, u8, &.{ terminal_root, std.fs.path.sep_str });

    var terminal_dir = try cwd.openDir("src/terminal", .{ .iterate = true });
    defer terminal_dir.close();
    var walker = try terminal_dir.walk(allocator);
    defer walker.deinit();

    var had_error = false;
    const stderr_file = std.fs.File.stderr();

    while (try walker.next()) |entry| {
        if (entry.kind != .file) continue;
        if (!std.mem.endsWith(u8, entry.basename, ".zig")) continue;

        const rel_path = try std.fs.path.join(allocator, &.{ "src/terminal", entry.path });
        const abs_path = try std.fs.path.join(allocator, &.{ root_path, rel_path });
        const from_layer = layerForPath(abs_path, terminal_root_sep);
        if (from_layer == .other) continue;

        const data = try cwd.readFileAlloc(allocator, rel_path, 1024 * 1024);
        var i: usize = 0;
        while (true) {
            const start = std.mem.indexOfPos(u8, data, i, "@import(\"") orelse break;
            const import_start = start + "@import(\"".len;
            const end = std.mem.indexOfPos(u8, data, import_start, "\")") orelse break;
            const import_path = data[import_start..end];
            i = end + 2;

            if (!std.mem.endsWith(u8, import_path, ".zig")) continue;

            const dir = std.fs.path.dirname(abs_path) orelse continue;
            const resolved = std.fs.path.resolve(allocator, &.{ dir, import_path }) catch continue;
            if (!std.mem.startsWith(u8, resolved, terminal_root_sep)) continue;

            const to_layer = layerForPath(resolved, terminal_root_sep);
            if (!isAllowed(from_layer, to_layer)) {
                had_error = true;
                var line_buf: [2048]u8 = undefined;
                const msg = try std.fmt.bufPrint(
                    &line_buf,
                    "terminal import check: {s} imports {s} ({s}) which is not allowed ({s} -> {s})\n",
                    .{ rel_path, import_path, resolved, layerName(from_layer), layerName(to_layer) },
                );
                try stderr_file.writeAll(msg);
            }
        }
    }

    if (had_error) return error.ForbiddenImport;
}

fn layerForPath(path: []const u8, terminal_root: []const u8) Layer {
    if (!std.mem.startsWith(u8, path, terminal_root)) return .other;
    const rel = path[terminal_root.len..];
    if (std.mem.eql(u8, rel, "replay_harness.zig")) return .harness;
    const sep_index = std.mem.indexOfScalar(u8, rel, std.fs.path.sep) orelse return .other;
    const first = rel[0..sep_index];
    if (std.mem.eql(u8, first, "core")) return .core;
    if (std.mem.eql(u8, first, "model")) return .model;
    if (std.mem.eql(u8, first, "parser")) return .parser;
    if (std.mem.eql(u8, first, "protocol")) return .protocol;
    if (std.mem.eql(u8, first, "io")) return .io;
    if (std.mem.eql(u8, first, "input")) return .input;
    if (std.mem.eql(u8, first, "kitty")) return .kitty;
    return .other;
}

fn isAllowed(from: Layer, to: Layer) bool {
    if (to == .other or from == .other) return true;
    if (from == .harness) return true;
    if (from == to) return true;
    return switch (from) {
        .core => to == .model or to == .parser or to == .protocol or to == .io or to == .input or to == .kitty,
        .protocol => to == .parser or to == .model or to == .io,
        .parser => to == .parser,
        .model => to == .model,
        .input => to == .io or to == .model,
        .io => to == .io,
        .kitty => to == .core,
        .harness, .other => true,
    };
}

fn layerName(layer: Layer) []const u8 {
    return switch (layer) {
        .core => "core",
        .model => "model",
        .parser => "parser",
        .protocol => "protocol",
        .io => "io",
        .input => "input",
        .kitty => "kitty",
        .harness => "harness",
        .other => "other",
    };
}
