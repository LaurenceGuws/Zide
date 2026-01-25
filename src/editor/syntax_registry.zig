const std = @import("std");

pub const SyntaxRegistry = struct {
    pub fn resolveLanguage(path: ?[]const u8) ?[]const u8 {
        if (path == null) return "zig";
        const slice = path.?;
        const base = std.fs.path.basename(slice);

        if (basenameLanguage(base)) |lang| return lang;

        if (extensionLanguage(slice)) |lang| return lang;

        return null;
    }

    pub fn resolveExtension(path: ?[]const u8) ?[]const u8 {
        if (path == null) return null;
        return extensionName(path.?);
    }
};

const MapTable = struct {
    extensions: std.StringHashMap([]const u8),
    basenames: std.StringHashMap([]const u8),
};

var map_loaded: bool = false;
var map_tables: MapTable = undefined;
var map_arena: std.heap.ArenaAllocator = undefined;

fn basenameLanguage(name: []const u8) ?[]const u8 {
    const maps = loadMaps();
    if (maps.basenames.get(name)) |lang| return lang;
    return null;
}

fn extensionLanguage(path: []const u8) ?[]const u8 {
    const needle = extensionName(path) orelse return null;
    const maps = loadMaps();
    if (maps.extensions.get(needle)) |lang| return lang;
    return null;
}

fn extensionName(path: []const u8) ?[]const u8 {
    const ext = std.fs.path.extension(path);
    if (ext.len <= 1) return null;
    return ext[1..];
}

fn loadMaps() *MapTable {
    if (map_loaded) return &map_tables;
    map_loaded = true;
    map_arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    const allocator = map_arena.allocator();
    map_tables = .{
        .extensions = std.StringHashMap([]const u8).init(allocator),
        .basenames = std.StringHashMap([]const u8).init(allocator),
    };

    _ = loadLuaMap(allocator, "assets/syntax/default.lua") catch {};
    if (configSyntaxPath(allocator)) |path| {
        _ = loadLuaMap(allocator, path) catch {};
        allocator.free(path);
    }
    _ = loadLuaMap(allocator, ".zide/syntax.lua") catch {};

    return &map_tables;
}

fn configSyntaxPath(allocator: std.mem.Allocator) ?[]u8 {
    if (std.c.getenv("XDG_CONFIG_HOME")) |xdg| {
        const base = std.mem.sliceTo(xdg, 0);
        return std.fs.path.join(allocator, &.{ base, "zide", "syntax.lua" }) catch null;
    }
    if (std.c.getenv("HOME")) |home| {
        const base = std.mem.sliceTo(home, 0);
        return std.fs.path.join(allocator, &.{ base, ".config", "zide", "syntax.lua" }) catch null;
    }
    return null;
}

fn loadLuaMap(allocator: std.mem.Allocator, path: []const u8) !void {
    const file = if (std.fs.path.isAbsolute(path))
        std.fs.openFileAbsolute(path, .{})
    else
        std.fs.cwd().openFile(path, .{});
    const handle = file catch |err| switch (err) {
        error.FileNotFound => return,
        else => return err,
    };
    defer handle.close();

    const data = try handle.readToEndAlloc(allocator, std.math.maxInt(usize));
    defer allocator.free(data);

    var section: enum { none, extensions, basenames } = .none;
    var it = std.mem.splitScalar(u8, data, '\n');
    while (it.next()) |line_raw| {
        const line = std.mem.trim(u8, line_raw, " \t\r");
        if (line.len == 0) continue;
        if (std.mem.startsWith(u8, line, "--")) continue;
        if (std.mem.startsWith(u8, line, "extensions")) {
            section = .extensions;
            continue;
        }
        if (std.mem.startsWith(u8, line, "basenames")) {
            section = .basenames;
            continue;
        }
        if (line[0] == '}') {
            section = .none;
            continue;
        }
        if (section == .none) continue;
        const pair = parseLuaPair(line) orelse continue;
        const key = try allocator.dupe(u8, pair.key);
        const value = try allocator.dupe(u8, pair.value);
        switch (section) {
            .extensions => _ = try map_tables.extensions.put(key, value),
            .basenames => _ = try map_tables.basenames.put(key, value),
            else => {},
        }
    }
}

const Pair = struct {
    key: []const u8,
    value: []const u8,
};

fn parseLuaPair(line: []const u8) ?Pair {
    const first_quote = std.mem.indexOfAny(u8, line, "'\"") orelse return null;
    const quote_char = line[first_quote];
    const key_start = first_quote + 1;
    const key_end = std.mem.indexOfScalarPos(u8, line, key_start, quote_char) orelse return null;
    const after_key = key_end + 1;
    const value_quote = std.mem.indexOfAnyPos(u8, line, after_key, "'\"") orelse return null;
    const value_char = line[value_quote];
    const value_start = value_quote + 1;
    const value_end = std.mem.indexOfScalarPos(u8, line, value_start, value_char) orelse return null;
    return .{
        .key = line[key_start..key_end],
        .value = line[value_start..value_end],
    };
}

test "resolveLanguage matches common extensions" {
    try std.testing.expectEqualStrings("zig", SyntaxRegistry.resolveLanguage("main.zig").?);
    try std.testing.expectEqualStrings("bash", SyntaxRegistry.resolveLanguage(".bashrc").?);
    try std.testing.expectEqualStrings("bash", SyntaxRegistry.resolveLanguage("script.sh").?);
    try std.testing.expectEqualStrings("java", SyntaxRegistry.resolveLanguage("Main.java").?);
    try std.testing.expectEqualStrings("rs", SyntaxRegistry.resolveExtension("lib.rs").?);
}
