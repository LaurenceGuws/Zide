const std = @import("std");
const text_store = @import("text_store.zig");
const app_logger = @import("../app_logger.zig");
const grammar_manager_mod = @import("grammar_manager.zig");
const syntax_registry_mod = @import("syntax_registry.zig");
const syntax_queries = @import("syntax_queries.zig");
const syntax_predicates = @import("syntax_predicates.zig");
const syntax_runtime = @import("syntax_runtime.zig");
const syntax_tokens = @import("syntax_tokens.zig");

const TextStore = text_store.TextStore;

const ts_api = @import("treesitter_api.zig");
const c = ts_api.c_api;
const zig_language_mod = @import("zig_language.zig");

pub const TSLanguage = ts_api.TSLanguage;
pub const QueryPaths = grammar_manager_mod.QueryPaths;
const QueryInfra = syntax_queries.QueryInfra(HighlightToken, TokenKind);
const SyntaxTokensMod = syntax_tokens.SyntaxTokens(HighlightToken);

pub const TokenKind = enum(u8) {
    plain = 0,
    comment = 1,
    string = 2,
    keyword = 3,
    number = 4,
    function = 5,
    variable = 6,
    type_name = 7,
    operator = 8,
    builtin = 9,
    punctuation = 10,
    constant = 11,
    attribute = 12,
    namespace = 13,
    label = 14,
    link = 15,
    error_token = 16,
    preproc = 17,
    macro = 18,
    escape = 19,
    keyword_control = 20,
    function_method = 21,
    type_builtin = 22,
};

pub const HighlightToken = struct {
    start: usize,
    end: usize,
    kind: TokenKind,
    priority: i32,
    conceal: ?[]const u8,
    url: ?[]const u8,
    conceal_lines: bool,
};

pub fn highlightTokenLessThanStable(a: HighlightToken, b: HighlightToken) bool {
    if (a.start != b.start) return a.start < b.start;
    if (a.priority != b.priority) return a.priority < b.priority;
    if (a.end != b.end) return a.end < b.end;
    if (a.kind != b.kind) return @intFromEnum(a.kind) < @intFromEnum(b.kind);
    if (a.conceal_lines != b.conceal_lines) return !a.conceal_lines and b.conceal_lines;
    if (optionalSliceLessThan(a.conceal, b.conceal)) return true;
    if (optionalSliceLessThan(b.conceal, a.conceal)) return false;
    if (optionalSliceLessThan(a.url, b.url)) return true;
    if (optionalSliceLessThan(b.url, a.url)) return false;
    return false;
}

fn optionalSliceLessThan(a: ?[]const u8, b: ?[]const u8) bool {
    if (a == null) return b != null;
    if (b == null) return false;
    return std.mem.order(u8, a.?, b.?) == .lt;
}

const InjectedLanguage = struct {
    language_name: []u8,
    parser: *c.TSParser,
    cursor: *c.TSQueryCursor,
    ts_language: *const c.TSLanguage,
    highlight_query: *QueryInfra.QueryBundle,
    injection_query: ?*QueryInfra.InjectionQuery,
};

const PlainCaptureEntry = struct {
    name: []u8,
    hits: usize,
};

const PlainCaptureSampler = struct {
    allocator: std.mem.Allocator,
    language_name: []const u8,
    entries: std.ArrayList(PlainCaptureEntry),
    total_hits: usize,
    next_report_threshold: usize,

    pub fn init(allocator: std.mem.Allocator, language_name: []const u8) PlainCaptureSampler {
        return .{
            .allocator = allocator,
            .language_name = language_name,
            .entries = std.ArrayList(PlainCaptureEntry).empty,
            .total_hits = 0,
            .next_report_threshold = 128,
        };
    }

    pub fn deinit(self: *PlainCaptureSampler) void {
        self.logSummary("final");
        for (self.entries.items) |entry| {
            self.allocator.free(entry.name);
        }
        self.entries.deinit(self.allocator);
    }

    pub fn observe(self: *PlainCaptureSampler, capture_name: []const u8) void {
        const log = app_logger.logger("editor.highlight");
        for (self.entries.items) |*entry| {
            if (!std.mem.eql(u8, entry.name, capture_name)) continue;
            entry.hits += 1;
            self.total_hits += 1;
            self.maybeLogSample();
            return;
        }

        const owned_name = self.allocator.dupe(u8, capture_name) catch |err| {
            log.logf(.warning, "plain capture sampler name dup failed capture={s} err={s}", .{ capture_name, @errorName(err) });
            return;
        };
        self.entries.append(self.allocator, .{
            .name = owned_name,
            .hits = 1,
        }) catch |err| {
            self.allocator.free(owned_name);
            log.logf(.warning, "plain capture sampler entry append failed capture={s} err={s}", .{ capture_name, @errorName(err) });
            return;
        };
        self.total_hits += 1;
        self.maybeLogSample();
    }

    fn maybeLogSample(self: *PlainCaptureSampler) void {
        if (self.total_hits < self.next_report_threshold) return;
        self.logSummary("sample");
        if (self.next_report_threshold <= (std.math.maxInt(usize) / 2)) {
            self.next_report_threshold *= 2;
        }
    }

    fn logSummary(self: *PlainCaptureSampler, phase: []const u8) void {
        if (self.entries.items.len == 0 or self.total_hits == 0) return;
        const log = app_logger.logger("editor.highlight");
        var top = std.ArrayList(PlainCaptureEntry).empty;
        defer top.deinit(self.allocator);
        top.appendSlice(self.allocator, self.entries.items) catch |err| {
            log.logf(.warning, "plain capture sampler top append failed phase={s} err={s}", .{ phase, @errorName(err) });
            return;
        };
        std.sort.heap(PlainCaptureEntry, top.items, {}, struct {
            fn lessThan(_: void, a: PlainCaptureEntry, b: PlainCaptureEntry) bool {
                if (a.hits != b.hits) return a.hits > b.hits;
                return std.mem.order(u8, a.name, b.name) == .lt;
            }
        }.lessThan);

        var buf = std.ArrayList(u8).empty;
        defer buf.deinit(self.allocator);
        const top_count: usize = @min(top.items.len, 8);
        for (top.items[0..top_count], 0..) |entry, i| {
            if (i > 0) {
                buf.appendSlice(self.allocator, ", ") catch |err| {
                    log.logf(.warning, "plain capture sampler summary separator append failed phase={s} err={s}", .{ phase, @errorName(err) });
                    return;
                };
            }
            buf.writer(self.allocator).print("{s}:{d}", .{ entry.name, entry.hits }) catch |err| {
                log.logf(.warning, "plain capture sampler summary print failed phase={s} err={s}", .{ phase, @errorName(err) });
                return;
            };
        }
        log.logf(.info, 
            "runtime unmapped captures phase={s} lang={s} total_hits={d} distinct={d} top=\"{s}\"",
            .{
                phase,
                self.language_name,
                self.total_hits,
                self.entries.items.len,
                buf.items,
            },
        );
    }
};

const max_injection_depth: usize = 6;
const injection_priority_bias: i32 = 100000;

const InjectionSettings = syntax_predicates.InjectionSettings;

const RuntimeHelpers = struct {
    pub const max_injection_depth = @import("syntax.zig").max_injection_depth;
    pub const InjectionSettings = @import("syntax.zig").InjectionSettings;
    pub const tsRead = @import("syntax.zig").tsRead;
    pub const emptyTokens = @import("syntax.zig").emptyTokens;
    pub const fullDocumentRange = @import("syntax.zig").fullDocumentRange;
    pub const splitHighlightOverlaps = @import("syntax.zig").splitHighlightOverlaps;
    pub const appendHighlightTokens = @import("syntax.zig").appendHighlightTokens;
    pub const predicatesMatch = @import("syntax.zig").predicatesMatch;
    pub const readNodeTextAlloc = @import("syntax.zig").readNodeTextAlloc;
    pub const collectInjectionSettings = @import("syntax.zig").collectInjectionSettings;
    pub const resolveInjectionLanguageName = @import("syntax.zig").resolveInjectionLanguageName;
    pub const intersectRanges = @import("syntax.zig").intersectRanges;
};

const SyntaxRuntimeMod = syntax_runtime.SyntaxRuntime(
    HighlightToken,
    TokenKind,
    QueryInfra,
    PlainCaptureSampler,
    RuntimeHelpers,
);

pub const SyntaxHighlighter = SyntaxRuntimeMod.SyntaxHighlighter;

pub fn createHighlighterForLanguage(
    allocator: std.mem.Allocator,
    text_buffer: *TextStore,
    language_name: []const u8,
    language: *const c.TSLanguage,
    query_paths: QueryPaths,
    grammar_manager: ?*grammar_manager_mod.GrammarManager,
) !*SyntaxHighlighter {
    return createHighlighter(allocator, text_buffer, language_name, language, query_paths, grammar_manager);
}

pub fn createHighlighter(
    allocator: std.mem.Allocator,
    text_buffer: *TextStore,
    language_name: []const u8,
    language: *const c.TSLanguage,
    query_paths: QueryPaths,
    grammar_manager: ?*grammar_manager_mod.GrammarManager,
) !*SyntaxHighlighter {
    return SyntaxRuntimeMod.createHighlighter(
        allocator,
        text_buffer,
        language_name,
        language,
        query_paths,
        grammar_manager,
        PlainCaptureSampler.init(allocator, language_name),
    );
}

pub fn tsRead(
    payload: ?*anyopaque,
    byte_offset: u32,
    _: c.TSPoint,
    bytes_read: [*c]u32,
) callconv(.c) [*c]const u8 {
    const self: *SyntaxHighlighter = @ptrCast(@alignCast(payload.?));
    const total = self.text_buffer.totalLen();
    if (byte_offset >= total) {
        bytes_read.* = 0;
        return self.read_buffer.ptr;
    }
    const max_len = self.read_buffer.len;
    const remaining = total - byte_offset;
    const to_read = if (remaining > max_len) max_len else remaining;
    const written = self.text_buffer.readRange(byte_offset, self.read_buffer[0..to_read]);
    bytes_read[0] = @as(u32, @intCast(written));
    return self.read_buffer.ptr;
}

fn pointForByte(buffer: *TextStore, byte_offset: usize) c.TSPoint {
    const line = buffer.lineIndexForOffset(byte_offset);
    const line_start = buffer.lineStart(line);
    return .{
        .row = @as(u32, @intCast(line)),
        .column = @as(u32, @intCast(byte_offset - line_start)),
    };
}

pub fn fullDocumentRange(buffer: *TextStore) c.TSRange {
    const total = buffer.totalLen();
    return .{
        .start_point = .{ .row = 0, .column = 0 },
        .end_point = pointForByte(buffer, total),
        .start_byte = 0,
        .end_byte = @as(u32, @intCast(@min(total, std.math.maxInt(u32)))),
    };
}

pub fn emptyTokens(allocator: std.mem.Allocator) ![]HighlightToken {
    return allocator.alloc(HighlightToken, 0);
}

const CaptureMeta = syntax_predicates.CaptureMeta;
const MatchMeta = syntax_predicates.MatchMeta;
const initCaptureMeta = syntax_predicates.initCaptureMeta;

fn addPriorityBias(priority: i32, depth: usize) i32 {
    if (depth == 0) return priority;
    const bias = @as(i64, @intCast(depth)) * @as(i64, injection_priority_bias);
    const value = @as(i64, priority) + bias;
    if (value > std.math.maxInt(i32)) return std.math.maxInt(i32);
    if (value < std.math.minInt(i32)) return std.math.minInt(i32);
    return @as(i32, @intCast(value));
}

fn appendHighlightTokens(
    text_buffer: *TextStore,
    query_bundle: *QueryInfra.QueryBundle,
    cursor: *c.TSQueryCursor,
    tree: *c.TSTree,
    range_start: u32,
    range_end: u32,
    depth: usize,
    allocator: std.mem.Allocator,
    tokens: *std.ArrayList(HighlightToken),
    plain_capture_sampler: *PlainCaptureSampler,
) !void {
    const root = c.ts_tree_root_node(tree);
    _ = c.ts_query_cursor_set_byte_range(cursor, range_start, range_end);
    c.ts_query_cursor_exec(cursor, query_bundle.query, root);

    const capture_count = query_bundle.capture_count;
    var capture_meta_stack: [64]CaptureMeta = undefined;
    const capture_meta = if (capture_count <= capture_meta_stack.len)
        capture_meta_stack[0..capture_count]
    else
        try allocator.alloc(CaptureMeta, capture_count);
    defer if (capture_count > capture_meta_stack.len) allocator.free(capture_meta);

    var match: c.TSQueryMatch = undefined;
    while (c.ts_query_cursor_next_match(cursor, &match)) {
        if (!predicatesMatch(
            query_bundle.query,
            &match,
            text_buffer,
            allocator,
        )) {
            continue;
        }

        initCaptureMeta(capture_meta);
        var match_meta = MatchMeta{};
        applyDirectives(
            query_bundle.query,
            &match,
            &match_meta,
            capture_meta,
            allocator,
        );

        var i: u32 = 0;
        while (i < match.capture_count) : (i += 1) {
            const capture = match.captures[i];
            const node = capture.node;
            const start_b = c.ts_node_start_byte(node);
            const end_b = c.ts_node_end_byte(node);
            if (end_b <= range_start or start_b >= range_end) continue;
            if (query_bundle.capture_noop[capture.index]) {
                if (query_bundle.capture_kinds[capture.index] == .plain) {
                    plain_capture_sampler.observe(query_bundle.capture_names[capture.index]);
                }
                continue;
            }
            const token_kind = query_bundle.capture_kinds[capture.index];
            const meta = capture_meta[capture.index];
            const base_priority = if (meta.has_priority) meta.priority else match_meta.priority;
            const priority = addPriorityBias(base_priority, depth);
            const conceal = if (meta.conceal != null) meta.conceal else match_meta.conceal;
            const url = if (meta.url != null) meta.url else match_meta.url;
            const conceal_lines = if (meta.conceal_lines) true else match_meta.conceal_lines;
            try tokens.append(allocator, .{
                .start = start_b,
                .end = end_b,
                .kind = token_kind,
                .priority = priority,
                .conceal = conceal,
                .url = url,
                .conceal_lines = conceal_lines,
            });
        }
    }
}

fn mapCaptureKind(name: []const u8) TokenKind {
    return syntax_queries.mapCaptureKind(TokenKind, name);
}

fn shouldSkipCapture(name: []const u8) bool {
    return syntax_queries.shouldSkipCapture(name);
}

const predicatesMatch = syntax_predicates.predicatesMatch;
const readNodeTextAlloc = syntax_predicates.readNodeTextAlloc;
const resolveInjectionLanguageName = syntax_predicates.resolveInjectionLanguageName;
const applyDirectives = syntax_predicates.applyDirectives;
const collectInjectionSettings = syntax_predicates.collectInjectionSettings;

fn intersectRanges(
    allocator: std.mem.Allocator,
    parent_ranges: []const c.TSRange,
    nodes: []const c.TSNode,
    include_children: bool,
) ![]c.TSRange {
    if (parent_ranges.len == 0 or nodes.len == 0) {
        return allocator.alloc(c.TSRange, 0);
    }

    const sorted_nodes = try allocator.alloc(c.TSNode, nodes.len);
    defer allocator.free(sorted_nodes);
    std.mem.copyForwards(c.TSNode, sorted_nodes, nodes);
    std.sort.heap(c.TSNode, sorted_nodes, {}, struct {
        fn lessThan(_: void, a: c.TSNode, b: c.TSNode) bool {
            const start_a = c.ts_node_start_byte(a);
            const start_b = c.ts_node_start_byte(b);
            if (start_a != start_b) return start_a < start_b;
            return c.ts_node_end_byte(a) < c.ts_node_end_byte(b);
        }
    }.lessThan);

    var result = std.ArrayList(c.TSRange).empty;
    errdefer result.deinit(allocator);

    var parent_index: usize = 0;
    var parent_range = parent_ranges[parent_index];
    const max_byte = std.math.maxInt(u32);
    const max_point = c.TSPoint{ .row = max_byte, .column = max_byte };

    for (sorted_nodes) |node| {
        var preceding = c.TSRange{
            .start_byte = 0,
            .end_byte = c.ts_node_start_byte(node),
            .start_point = .{ .row = 0, .column = 0 },
            .end_point = c.ts_node_start_point(node),
        };

        const following = c.TSRange{
            .start_byte = c.ts_node_end_byte(node),
            .end_byte = max_byte,
            .start_point = c.ts_node_end_point(node),
            .end_point = max_point,
        };

        const child_count = if (include_children) 0 else c.ts_node_child_count(node);
        var child_index: u32 = 0;
        while (child_index <= child_count) : (child_index += 1) {
            const excluded = if (child_index == child_count)
                following
            else blk: {
                const child = c.ts_node_child(node, child_index);
                break :blk c.TSRange{
                    .start_byte = c.ts_node_start_byte(child),
                    .end_byte = c.ts_node_end_byte(child),
                    .start_point = c.ts_node_start_point(child),
                    .end_point = c.ts_node_end_point(child),
                };
            };

            var range = c.TSRange{
                .start_byte = preceding.end_byte,
                .end_byte = excluded.start_byte,
                .start_point = preceding.end_point,
                .end_point = excluded.start_point,
            };
            preceding = excluded;

            if (range.end_byte < parent_range.start_byte) {
                continue;
            }

            while (parent_range.start_byte <= range.end_byte) {
                if (parent_range.end_byte > range.start_byte) {
                    if (range.start_byte < parent_range.start_byte) {
                        range.start_byte = parent_range.start_byte;
                        range.start_point = parent_range.start_point;
                    }

                    if (parent_range.end_byte < range.end_byte) {
                        if (range.start_byte < parent_range.end_byte) {
                            try result.append(allocator, .{
                                .start_byte = range.start_byte,
                                .end_byte = parent_range.end_byte,
                                .start_point = range.start_point,
                                .end_point = parent_range.end_point,
                            });
                        }
                        range.start_byte = parent_range.end_byte;
                        range.start_point = parent_range.end_point;
                    } else {
                        if (range.start_byte < range.end_byte) {
                            try result.append(allocator, range);
                        }
                        break;
                    }
                }

                parent_index += 1;
                if (parent_index >= parent_ranges.len) {
                    return result.toOwnedSlice(allocator);
                }
                parent_range = parent_ranges[parent_index];
            }
        }
    }

    return result.toOwnedSlice(allocator);
}

pub const splitHighlightOverlaps = SyntaxTokensMod.splitHighlightOverlaps;

test "map capture kind covers common alias captures" {
    try std.testing.expectEqual(TokenKind.keyword, mapCaptureKind("import"));
    try std.testing.expectEqual(TokenKind.keyword, mapCaptureKind("cImport"));
    try std.testing.expectEqual(TokenKind.constant, mapCaptureKind("none"));
    try std.testing.expectEqual(TokenKind.attribute, mapCaptureKind("annotation"));
    try std.testing.expectEqual(TokenKind.function, mapCaptureKind("func"));
    try std.testing.expectEqual(TokenKind.variable, mapCaptureKind("argument"));
    try std.testing.expectEqual(TokenKind.operator, mapCaptureKind("diff.plus"));
    try std.testing.expectEqual(TokenKind.preproc, mapCaptureKind("define"));
    try std.testing.expectEqual(TokenKind.preproc, mapCaptureKind("keyword.directive"));
    try std.testing.expectEqual(TokenKind.macro, mapCaptureKind("function.macro"));
    try std.testing.expectEqual(TokenKind.escape, mapCaptureKind("string.escape"));
    try std.testing.expectEqual(TokenKind.keyword_control, mapCaptureKind("keyword.control.conditional"));
    try std.testing.expectEqual(TokenKind.function_method, mapCaptureKind("function.method.call"));
    try std.testing.expectEqual(TokenKind.type_builtin, mapCaptureKind("type.builtin"));
}

const CaptureMappingFixture = struct {
    name: []const u8,
    path: []const u8,
};

const capture_mapping_fixtures = [_]CaptureMappingFixture{
    .{ .name = "java", .path = "fixtures/editor/treesitter_capture_coverage/java.txt" },
    .{ .name = "python", .path = "fixtures/editor/treesitter_capture_coverage/python.txt" },
    .{ .name = "go", .path = "fixtures/editor/treesitter_capture_coverage/go.txt" },
    .{ .name = "bash", .path = "fixtures/editor/treesitter_capture_coverage/bash.txt" },
};

test "capture mapping fixtures stay stable across major languages" {
    const allocator = std.testing.allocator;
    for (capture_mapping_fixtures) |fixture| {
        const data = try std.fs.cwd().readFileAlloc(allocator, fixture.path, 64 * 1024);
        defer allocator.free(data);

        var lines = std.mem.splitScalar(u8, data, '\n');
        var line_no: usize = 0;
        while (lines.next()) |line_raw| {
            line_no += 1;
            const line = std.mem.trim(u8, line_raw, " \t\r");
            if (line.len == 0 or line[0] == '#') continue;
            var parts = std.mem.tokenizeScalar(u8, line, ' ');
            const capture_name = parts.next() orelse return error.InvalidFixture;
            const expected_kind_name = parts.next() orelse return error.InvalidFixture;
            if (parts.next() != null) return error.InvalidFixture;

            const expected_kind = std.meta.stringToEnum(TokenKind, expected_kind_name) orelse {
                std.debug.print("invalid expected token kind in fixture={s} line={d}: {s}\n", .{
                    fixture.name,
                    line_no,
                    expected_kind_name,
                });
                return error.InvalidFixture;
            };
            const actual_kind = mapCaptureKind(capture_name);
            try std.testing.expectEqual(expected_kind, actual_kind);
        }
    }
}

test "predicates + priority metadata filter highlights" {
    const allocator = std.testing.allocator;
    const text = "const foo = 1;\nconst bar = 2;\n";
    var store = try TextStore.init(allocator, text);
    defer store.deinit();

    var tmp = std.testing.tmpDir(.{});
    defer tmp.cleanup();

    const query =
        \\((identifier) @variable (#eq? @variable "foo") (#set! @variable priority 50))
        \\((identifier) @variable (#any-of? @variable "bar" "baz") (#set! @variable priority 10))
    ;
    try tmp.dir.writeFile(.{ .sub_path = "highlights.scm", .data = query });
    const query_path = try tmp.dir.realpathAlloc(allocator, "highlights.scm");
    defer allocator.free(query_path);

    const highlighter = try createHighlighterForLanguage(
        allocator,
        store,
        "zig",
        try zig_language_mod.language(),
        .{ .highlights = query_path },
        null,
    );
    defer highlighter.destroy();

    const tokens = try highlighter.highlightRange(0, store.totalLen(), allocator);
    defer allocator.free(tokens);

    try std.testing.expectEqual(@as(usize, 2), tokens.len);
    var foo_priority: ?i32 = null;
    var bar_priority: ?i32 = null;
    for (tokens) |token| {
        const slice = text[token.start..token.end];
        if (std.mem.eql(u8, slice, "foo")) foo_priority = token.priority;
        if (std.mem.eql(u8, slice, "bar")) bar_priority = token.priority;
    }
    try std.testing.expectEqual(@as(?i32, 50), foo_priority);
    try std.testing.expectEqual(@as(?i32, 10), bar_priority);
}

test "split highlight overlaps by priority" {
    const allocator = std.testing.allocator;
    var tokens = try allocator.alloc(HighlightToken, 3);
    tokens[0] = .{
        .start = 0,
        .end = 10,
        .kind = .string,
        .priority = 0,
        .conceal = null,
        .url = null,
        .conceal_lines = false,
    };
    tokens[1] = .{
        .start = 2,
        .end = 5,
        .kind = .keyword,
        .priority = 10,
        .conceal = null,
        .url = null,
        .conceal_lines = false,
    };
    tokens[2] = .{
        .start = 6,
        .end = 9,
        .kind = .number,
        .priority = 5,
        .conceal = null,
        .url = null,
        .conceal_lines = false,
    };

    const split = try splitHighlightOverlaps(allocator, tokens);
    defer allocator.free(split);

    try std.testing.expectEqual(@as(usize, 5), split.len);
    try std.testing.expectEqual(@as(usize, 0), split[0].start);
    try std.testing.expectEqual(@as(usize, 2), split[0].end);
    try std.testing.expectEqual(TokenKind.string, split[0].kind);
    try std.testing.expectEqual(@as(usize, 2), split[1].start);
    try std.testing.expectEqual(@as(usize, 5), split[1].end);
    try std.testing.expectEqual(TokenKind.keyword, split[1].kind);
    try std.testing.expectEqual(@as(usize, 5), split[2].start);
    try std.testing.expectEqual(@as(usize, 6), split[2].end);
    try std.testing.expectEqual(TokenKind.string, split[2].kind);
    try std.testing.expectEqual(@as(usize, 6), split[3].start);
    try std.testing.expectEqual(@as(usize, 9), split[3].end);
    try std.testing.expectEqual(TokenKind.number, split[3].kind);
    try std.testing.expectEqual(@as(usize, 9), split[4].start);
    try std.testing.expectEqual(@as(usize, 10), split[4].end);
    try std.testing.expectEqual(TokenKind.string, split[4].kind);
}

test "highlight token comparator is deterministic across metadata" {
    const allocator = std.testing.allocator;
    var tokens = try allocator.alloc(HighlightToken, 5);
    defer allocator.free(tokens);

    tokens[0] = .{ .start = 10, .end = 20, .kind = .link, .priority = 50, .conceal = null, .url = "https://z.dev", .conceal_lines = false };
    tokens[1] = .{ .start = 10, .end = 20, .kind = .link, .priority = 50, .conceal = null, .url = "https://a.dev", .conceal_lines = false };
    tokens[2] = .{ .start = 10, .end = 20, .kind = .keyword, .priority = 50, .conceal = null, .url = null, .conceal_lines = false };
    tokens[3] = .{ .start = 10, .end = 20, .kind = .keyword, .priority = 50, .conceal = "*", .url = null, .conceal_lines = false };
    tokens[4] = .{ .start = 10, .end = 20, .kind = .keyword, .priority = 50, .conceal = null, .url = null, .conceal_lines = true };

    std.sort.heap(HighlightToken, tokens, {}, struct {
        fn lessThan(_: void, a: HighlightToken, b: HighlightToken) bool {
            return highlightTokenLessThanStable(a, b);
        }
    }.lessThan);

    try std.testing.expectEqual(TokenKind.keyword, tokens[0].kind);
    try std.testing.expectEqual(false, tokens[0].conceal_lines);
    try std.testing.expectEqual(null, tokens[0].conceal);

    try std.testing.expectEqual(TokenKind.keyword, tokens[1].kind);
    try std.testing.expectEqualStrings("*", tokens[1].conceal.?);

    try std.testing.expectEqual(TokenKind.keyword, tokens[2].kind);
    try std.testing.expectEqual(true, tokens[2].conceal_lines);

    try std.testing.expectEqual(TokenKind.link, tokens[3].kind);
    try std.testing.expectEqualStrings("https://a.dev", tokens[3].url.?);

    try std.testing.expectEqual(TokenKind.link, tokens[4].kind);
    try std.testing.expectEqualStrings("https://z.dev", tokens[4].url.?);
}

test "match predicate filters captures" {
    const allocator = std.testing.allocator;
    const text = "const foo = 1;\nconst bar = 2;\n";
    var store = try TextStore.init(allocator, text);
    defer store.deinit();

    var tmp = std.testing.tmpDir(.{});
    defer tmp.cleanup();

    const query =
        \\((identifier) @variable (#match? @variable "^ba"))
    ;
    try tmp.dir.writeFile(.{ .sub_path = "highlights.scm", .data = query });
    const query_path = try tmp.dir.realpathAlloc(allocator, "highlights.scm");
    defer allocator.free(query_path);

    const highlighter = try createHighlighterForLanguage(
        allocator,
        store,
        "zig",
        try zig_language_mod.language(),
        .{ .highlights = query_path },
        null,
    );
    defer highlighter.destroy();

    const tokens = try highlighter.highlightRange(0, store.totalLen(), allocator);
    defer allocator.free(tokens);

    try std.testing.expectEqual(@as(usize, 1), tokens.len);
    try std.testing.expectEqualStrings("bar", text[tokens[0].start..tokens[0].end]);
}
