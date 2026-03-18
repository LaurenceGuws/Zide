const std = @import("std");
const config_mod = @import("../config/lua_config.zig");

pub const QueryMergeMode = config_mod.EditorManualHighlightMode;

pub const Resolved = struct {
    parser: []const u8,
    query_path: ?[]const u8,
    mode: QueryMergeMode,
};

const Rule = struct {
    extension: []u8,
    parser: []u8,
    query_path: ?[]u8,
    mode: QueryMergeMode,
};

const BuiltinRule = struct {
    extension: []const u8,
    parser: []const u8,
    query_path: []const u8,
    mode: QueryMergeMode,
};

const builtin_rules = [_]BuiltinRule{};

const builtin_unsupported = Resolved{
    .parser = "comment",
    .query_path = "assets/queries/manual/log_levels.scm",
    .mode = .append,
};

var arena: ?std.heap.ArenaAllocator = null;
var rules: []Rule = &.{};
var unsupported: ?Resolved = null;

pub fn applyConfig(allocator: std.mem.Allocator, config: *const config_mod.Config) !void {
    reset();

    var new_arena = std.heap.ArenaAllocator.init(allocator);
    errdefer new_arena.deinit();
    const arena_alloc = new_arena.allocator();

    if (config.editor_manual_highlight_rules) |configured| {
        rules = try arena_alloc.alloc(Rule, configured.len);
        for (configured, 0..) |rule, i| {
            rules[i] = .{
                .extension = try arena_alloc.dupe(u8, rule.extension),
                .parser = try arena_alloc.dupe(u8, rule.parser),
                .query_path = try resolveQueryPath(arena_alloc, rule.builtin, rule.query_path),
                .mode = rule.mode,
            };
        }
    } else {
        rules = &.{};
    }

    if (config.editor_manual_highlight_unsupported) |fallback| {
        unsupported = .{
            .parser = try arena_alloc.dupe(u8, fallback.parser),
            .query_path = try resolveQueryPath(arena_alloc, fallback.builtin, fallback.query_path),
            .mode = fallback.mode,
        };
    } else {
        unsupported = null;
    }

    arena = new_arena;
}

pub fn reset() void {
    if (arena) |*owned| owned.deinit();
    arena = null;
    rules = &.{};
    unsupported = null;
}

pub fn resolve(path: ?[]const u8, default_language: ?[]const u8) ?Resolved {
    const ext = extensionName(path) orelse return if (default_language == null) (unsupported orelse builtin_unsupported) else null;

    for (rules) |rule| {
        if (std.ascii.eqlIgnoreCase(rule.extension, ext)) {
            return .{
                .parser = rule.parser,
                .query_path = rule.query_path,
                .mode = rule.mode,
            };
        }
    }

    for (builtin_rules) |rule| {
        if (std.ascii.eqlIgnoreCase(rule.extension, ext)) {
            return .{
                .parser = rule.parser,
                .query_path = rule.query_path,
                .mode = rule.mode,
            };
        }
    }

    if (default_language == null) return unsupported orelse builtin_unsupported;
    return null;
}

fn extensionName(path: ?[]const u8) ?[]const u8 {
    const slice = path orelse return null;
    const ext = std.fs.path.extension(slice);
    if (ext.len <= 1) return null;
    return ext[1..];
}

fn resolveQueryPath(allocator: std.mem.Allocator, builtin: ?[]const u8, explicit_path: ?[]const u8) !?[]u8 {
    if (explicit_path) |path| return try allocator.dupe(u8, path);
    if (builtin) |name| return try std.fmt.allocPrint(allocator, "assets/queries/manual/{s}.scm", .{name});
    return null;
}

test "built-in unsupported fallback resolves to comment parser for log files" {
    const resolved = resolve("server.log", null).?;
    try std.testing.expectEqualStrings("comment", resolved.parser);
    try std.testing.expectEqualStrings("assets/queries/manual/log_levels.scm", resolved.query_path.?);
    try std.testing.expectEqual(QueryMergeMode.append, resolved.mode);
}

test "built-in unsupported fallback resolves to comment parser for txt files" {
    const resolved = resolve("notes.txt", null).?;
    try std.testing.expectEqualStrings("comment", resolved.parser);
    try std.testing.expectEqualStrings("assets/queries/manual/log_levels.scm", resolved.query_path.?);
    try std.testing.expectEqual(QueryMergeMode.append, resolved.mode);
}

test "built-in unsupported fallback resolves for untitled buffers" {
    const resolved = resolve(null, null).?;
    try std.testing.expectEqualStrings("comment", resolved.parser);
    try std.testing.expectEqualStrings("assets/queries/manual/log_levels.scm", resolved.query_path.?);
    try std.testing.expectEqual(QueryMergeMode.append, resolved.mode);
}

test "unsupported fallback applies only when language is unresolved" {
    var config = config_mod.emptyConfig();
    defer config_mod.freeConfig(std.testing.allocator, &config);

    config.editor_manual_highlight_unsupported = .{
        .parser = try std.testing.allocator.dupe(u8, "comment"),
        .builtin = try std.testing.allocator.dupe(u8, "log_levels"),
    };
    try applyConfig(std.testing.allocator, &config);
    defer reset();

    const unsupported_resolved = resolve("notes.unknown", null).?;
    try std.testing.expectEqualStrings("comment", unsupported_resolved.parser);
    try std.testing.expectEqualStrings("assets/queries/manual/log_levels.scm", unsupported_resolved.query_path.?);
    try std.testing.expectEqual(QueryMergeMode.append, unsupported_resolved.mode);
    try std.testing.expect(resolve("notes.unknown", "zig") == null);
}
