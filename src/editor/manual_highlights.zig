const std = @import("std");
const config_mod = @import("../config/lua_config.zig");
const tree_sitter_assets = @import("tree_sitter_assets.zig");

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

var allocator_instance: ?std.mem.Allocator = null;
var rules: []Rule = &.{};
var unsupported: ?Resolved = null;

pub fn applyConfig(allocator: std.mem.Allocator, config: *const config_mod.Config) !void {
    reset();

    allocator_instance = allocator;

    if (config.editor_manual_highlight_rules) |configured| {
        rules = try allocator.alloc(Rule, configured.len);
        var i: usize = 0;
        errdefer {
            while (i > 0) : (i -= 1) {
                freeRule(rules[i - 1]);
            }
            allocator.free(rules);
            rules = &.{};
        }
        for (configured, 0..) |rule, idx| {
            i = idx;
            rules[i] = .{
                .extension = try allocator.dupe(u8, rule.extension),
                .parser = try allocator.dupe(u8, rule.parser),
                .query_path = try resolveQueryPath(allocator, rule.builtin, rule.query_path),
                .mode = rule.mode,
            };
            i += 1;
        }
    } else {
        rules = &.{};
    }

    if (config.editor_manual_highlight_unsupported) |fallback| {
        const parser = try allocator.dupe(u8, fallback.parser);
        errdefer allocator.free(parser);
        const query_path = try resolveQueryPath(allocator, fallback.builtin, fallback.query_path);
        errdefer if (query_path) |path| allocator.free(path);
        unsupported = .{
            .parser = parser,
            .query_path = query_path,
            .mode = fallback.mode,
        };
    } else {
        unsupported = null;
    }
}

pub fn reset() void {
    if (allocator_instance) |allocator| {
        for (rules) |rule| {
            freeRuleWithAllocator(allocator, rule);
        }
        if (rules.len != 0) allocator.free(rules);
        if (unsupported) |value| {
            allocator.free(value.parser);
            if (value.query_path) |path| allocator.free(path);
        }
    }
    allocator_instance = null;
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
    if (builtin) |name| {
        const rel_path = try std.fmt.allocPrint(allocator, "queries/manual/{s}.scm", .{name});
        defer allocator.free(rel_path);
        if (try tree_sitter_assets.resolveSharedAssetPath(allocator, rel_path)) |path| return path;
        return try std.fmt.allocPrint(allocator, "assets/{s}", .{rel_path});
    }
    return null;
}

fn freeRule(rule: Rule) void {
    if (allocator_instance) |allocator| {
        freeRuleWithAllocator(allocator, rule);
    }
}

fn freeRuleWithAllocator(allocator: std.mem.Allocator, rule: Rule) void {
    allocator.free(rule.extension);
    allocator.free(rule.parser);
    if (rule.query_path) |path| allocator.free(path);
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
    const qpath = unsupported_resolved.query_path.?;
    try std.testing.expect(
        std.mem.eql(u8, qpath, "assets/queries/manual/log_levels.scm") or
            std.mem.endsWith(u8, qpath, "/tree-sitter-assets/queries/manual/log_levels.scm"),
    );
    try std.testing.expectEqual(QueryMergeMode.append, unsupported_resolved.mode);
    try std.testing.expect(resolve("notes.unknown", "zig") == null);
}
