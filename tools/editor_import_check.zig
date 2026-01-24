const std = @import("std");

const Layer = enum {
    core,
    text,
    syntax,
    view,
    render,
    shared,
    other,
};

pub fn main() !void {
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();
    const allocator = arena.allocator();

    const cwd = std.fs.cwd();
    const root_path = try cwd.realpathAlloc(allocator, ".");
    const editor_root = try std.fs.path.join(allocator, &.{ root_path, "src", "editor" });
    const editor_root_sep = try std.mem.concat(allocator, u8, &.{ editor_root, std.fs.path.sep_str });

    var editor_dir = try cwd.openDir("src/editor", .{ .iterate = true });
    defer editor_dir.close();
    var walker = try editor_dir.walk(allocator);
    defer walker.deinit();

    var had_error = false;
    const stderr_file = std.fs.File.stderr();

    while (try walker.next()) |entry| {
        if (entry.kind != .file) continue;
        if (!std.mem.endsWith(u8, entry.basename, ".zig")) continue;

        const rel_path = try std.fs.path.join(allocator, &.{ "src/editor", entry.path });
        const abs_path = try std.fs.path.join(allocator, &.{ root_path, rel_path });
        const from_layer = layerForPath(abs_path, editor_root_sep);
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
            if (!std.mem.startsWith(u8, resolved, editor_root_sep)) continue;

            const to_layer = layerForPath(resolved, editor_root_sep);
            if (!isAllowed(from_layer, to_layer)) {
                had_error = true;
                var line_buf: [2048]u8 = undefined;
                const msg = try std.fmt.bufPrint(
                    &line_buf,
                    "editor import check: {s} imports {s} ({s}) which is not allowed ({s} -> {s})\n",
                    .{ rel_path, import_path, resolved, layerName(from_layer), layerName(to_layer) },
                );
                try stderr_file.writeAll(msg);
            }
        }
    }

    if (had_error) return error.ForbiddenImport;
}

fn layerForPath(path: []const u8, editor_root: []const u8) Layer {
    if (!std.mem.startsWith(u8, path, editor_root)) return .other;
    const rel = path[editor_root.len..];
    if (std.mem.eql(u8, rel, "editor.zig")) return .core;
    if (std.mem.eql(u8, rel, "rope.zig")) return .text;
    if (std.mem.eql(u8, rel, "text_store.zig")) return .text;
    if (std.mem.eql(u8, rel, "syntax.zig")) return .syntax;
    if (std.mem.eql(u8, rel, "types.zig")) return .shared;
    const sep_index = std.mem.indexOfScalar(u8, rel, std.fs.path.sep) orelse return .other;
    const first = rel[0..sep_index];
    if (std.mem.eql(u8, first, "view")) return .view;
    if (std.mem.eql(u8, first, "render")) return .render;
    return .other;
}

fn isAllowed(from: Layer, to: Layer) bool {
    if (to == .other or from == .other) return true;
    if (to == .shared or from == .shared) return true;
    if (from == to) return true;
    return switch (from) {
        .core => to == .text or to == .syntax,
        .text => to == .text,
        .syntax => to == .text,
        .view => to == .core or to == .text or to == .syntax,
        .render => to == .view or to == .syntax,
        .shared, .other => true,
    };
}

fn layerName(layer: Layer) []const u8 {
    return switch (layer) {
        .core => "core",
        .text => "text",
        .syntax => "syntax",
        .view => "view",
        .render => "render",
        .shared => "shared",
        .other => "other",
    };
}
