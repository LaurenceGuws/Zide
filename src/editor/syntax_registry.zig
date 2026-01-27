const std = @import("std");

pub const SyntaxRegistry = struct {
    pub fn resolveLanguage(path: ?[]const u8) ?[]const u8 {
        if (path == null) return "zig";
        const slice = path.?;
        const base = std.fs.path.basename(slice);

        if (basenameLanguage(base)) |lang| return lang;

        if (globLanguage(slice)) |lang| return lang;

        if (extensionLanguage(slice)) |lang| return lang;

        return null;
    }

    pub fn resolveExtension(path: ?[]const u8) ?[]const u8 {
        if (path == null) return null;
        return extensionName(path.?);
    }

    pub fn resolveInjectionLanguage(name: []const u8) ?[]const u8 {
        if (name.len == 0) return null;
        const maps = loadMaps();
        if (maps.injections.get(name)) |lang| return lang;
        return name;
    }
};

const MapTable = struct {
    extensions: std.StringHashMap([]const u8),
    basenames: std.StringHashMap([]const u8),
    globs: []GlobEntry,
    injections: std.StringHashMap([]const u8),
};

var map_loaded: bool = false;
var map_tables: MapTable = undefined;
var map_arena: std.heap.ArenaAllocator = undefined;

const GlobEntry = struct {
    pattern: []const u8,
    lang: []const u8,
};

fn basenameLanguage(name: []const u8) ?[]const u8 {
    const maps = loadMaps();
    if (maps.basenames.get(name)) |lang| return lang;
    return null;
}

fn globLanguage(path: []const u8) ?[]const u8 {
    const maps = loadMaps();
    if (maps.globs.len == 0) return null;
    const base = std.fs.path.basename(path);
    for (maps.globs) |entry| {
        const target = if (std.mem.indexOfScalar(u8, entry.pattern, '/')) |_| path else base;
        if (globMatch(entry.pattern, target)) return entry.lang;
    }
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

fn globMatch(pattern: []const u8, target: []const u8) bool {
    var p: usize = 0;
    var t: usize = 0;
    var star: ?usize = null;
    var match: usize = 0;
    while (t < target.len) {
        if (p < pattern.len and (pattern[p] == target[t] or pattern[p] == '?')) {
            p += 1;
            t += 1;
            continue;
        }
        if (p < pattern.len and pattern[p] == '*') {
            star = p;
            match = t;
            p += 1;
            continue;
        }
        if (star) |s| {
            p = s + 1;
            match += 1;
            t = match;
            continue;
        }
        return false;
    }
    while (p < pattern.len and pattern[p] == '*') : (p += 1) {}
    return p == pattern.len;
}

fn loadMaps() *MapTable {
    if (map_loaded) return &map_tables;
    map_loaded = true;
    map_arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    const allocator = map_arena.allocator();
    map_tables = .{
        .extensions = std.StringHashMap([]const u8).init(allocator),
        .basenames = std.StringHashMap([]const u8).init(allocator),
        .globs = &.{},
        .injections = std.StringHashMap([]const u8).init(allocator),
    };

    _ = loadLuaMap(allocator, "assets/syntax/generated.lua") catch {};
    _ = loadLuaMap(allocator, "assets/syntax/overrides.lua") catch {};
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

    var section: enum { none, extensions, basenames, globs, injections } = .none;
    var globs_list = std.ArrayList(GlobEntry).empty;
    defer globs_list.deinit(allocator);
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
        if (std.mem.startsWith(u8, line, "globs")) {
            section = .globs;
            continue;
        }
        if (std.mem.startsWith(u8, line, "injections")) {
            section = .injections;
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
            .globs => try globs_list.append(allocator, .{ .pattern = key, .lang = value }),
            .injections => _ = try map_tables.injections.put(key, value),
            else => {},
        }
    }

    if (globs_list.items.len > 0) {
        const old = map_tables.globs;
        const total = old.len + globs_list.items.len;
        const combined = try allocator.alloc(GlobEntry, total);
        if (old.len > 0) {
            std.mem.copyForwards(GlobEntry, combined[0..old.len], old);
        }
        std.mem.copyForwards(GlobEntry, combined[old.len..], globs_list.items);
        if (old.len > 0) {
            allocator.free(old);
        }
        map_tables.globs = combined;
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

test "globMatch handles basic wildcards" {
    try std.testing.expect(globMatch("*.blade.php", "index.blade.php"));
    try std.testing.expect(globMatch("templates/*.yaml", "templates/values.yaml"));
    try std.testing.expect(globMatch("templates/_*.tpl", "templates/_helpers.tpl"));
    try std.testing.expect(!globMatch("templates/*.yaml", "templates/values.yml"));
}
