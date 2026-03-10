const std = @import("std");
const text_store = @import("text_store.zig");
const app_logger = @import("../app_logger.zig");
const grammar_manager_mod = @import("grammar_manager.zig");
const syntax_registry_mod = @import("syntax_registry.zig");
const syntax_queries = @import("syntax_queries.zig");
const syntax_runtime = @import("syntax_runtime.zig");

const TextStore = text_store.TextStore;

const ts_api = @import("treesitter_api.zig");
const c = ts_api.c_api;
const zig_language_mod = @import("zig_language.zig");

pub const TSLanguage = ts_api.TSLanguage;
pub const QueryPaths = grammar_manager_mod.QueryPaths;
const QueryInfra = syntax_queries.QueryInfra(HighlightToken, TokenKind);

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

const InjectionSettings = struct {
    language: ?[]const u8 = null,
    include_children: bool = false,
    combined: bool = false,
    use_self: bool = false,
    use_parent: bool = false,
};

const RuntimeHelpers = struct {
    const max_injection_depth = @import("syntax.zig").max_injection_depth;
    const InjectionSettings = @import("syntax.zig").InjectionSettings;
    const tsRead = @import("syntax.zig").tsRead;
    const emptyTokens = @import("syntax.zig").emptyTokens;
    const fullDocumentRange = @import("syntax.zig").fullDocumentRange;
    const splitHighlightOverlaps = @import("syntax.zig").splitHighlightOverlaps;
    const appendHighlightTokens = @import("syntax.zig").appendHighlightTokens;
    const predicatesMatch = @import("syntax.zig").predicatesMatch;
    const readNodeTextAlloc = @import("syntax.zig").readNodeTextAlloc;
    const collectInjectionSettings = @import("syntax.zig").collectInjectionSettings;
    const resolveInjectionLanguageName = @import("syntax.zig").resolveInjectionLanguageName;
    const intersectRanges = @import("syntax.zig").intersectRanges;
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

fn tsRead(
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

fn fullDocumentRange(buffer: *TextStore) c.TSRange {
    const total = buffer.totalLen();
    return .{
        .start_point = .{ .row = 0, .column = 0 },
        .end_point = pointForByte(buffer, total),
        .start_byte = 0,
        .end_byte = @as(u32, @intCast(@min(total, std.math.maxInt(u32)))),
    };
}

fn emptyTokens(allocator: std.mem.Allocator) ![]HighlightToken {
    return allocator.alloc(HighlightToken, 0);
}

const CaptureMeta = struct {
    priority: i32 = 0,
    has_priority: bool = false,
    conceal: ?[]const u8 = null,
    url: ?[]const u8 = null,
    conceal_lines: bool = false,
};

const MatchMeta = struct {
    priority: i32 = 0,
    has_priority: bool = false,
    conceal: ?[]const u8 = null,
    url: ?[]const u8 = null,
    conceal_lines: bool = false,
};

fn initCaptureMeta(meta: []CaptureMeta) void {
    for (meta) |*entry| {
        entry.* = .{};
    }
}

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

const PredicateArg = union(enum) {
    capture: u32,
    string: []const u8,
};

fn predicatesMatch(
    query: *c.TSQuery,
    match: *const c.TSQueryMatch,
    text_buffer: *TextStore,
    allocator: std.mem.Allocator,
) bool {
    const log = app_logger.logger("editor.syntax");
    var step_count: u32 = 0;
    const steps = c.ts_query_predicates_for_pattern(query, match.pattern_index, &step_count);
    if (steps == null or step_count == 0) return true;

    var args = std.ArrayList(PredicateArg).empty;
    defer args.deinit(allocator);

    var current_name: ?[]const u8 = null;
    var i: u32 = 0;
    while (i < step_count) : (i += 1) {
        const step = steps[i];
        switch (step.type) {
            c.TSQueryPredicateStepTypeDone => {
                if (current_name) |name| {
                    if (!predicateSatisfied(
                        query,
                        name,
                        args.items,
                        match,
                        text_buffer,
                        allocator,
                    )) {
                        return false;
                    }
                }
                args.clearRetainingCapacity();
                current_name = null;
            },
            c.TSQueryPredicateStepTypeCapture => {
                if (current_name == null) continue;
                args.append(allocator, .{ .capture = step.value_id }) catch |err| {
                    log.logf(.warning, "predicate capture arg append failed pattern={d} err={s}", .{ match.pattern_index, @errorName(err) });
                    return false;
                };
            },
            c.TSQueryPredicateStepTypeString => {
                var len: u32 = 0;
                const value_ptr = c.ts_query_string_value_for_id(query, step.value_id, &len);
                const value = value_ptr[0..len];
                if (current_name == null) {
                    current_name = value;
                } else {
                    args.append(allocator, .{ .string = value }) catch |err| {
                        log.logf(.warning, "predicate string arg append failed pattern={d} err={s}", .{ match.pattern_index, @errorName(err) });
                        return false;
                    };
                }
            },
            else => {},
        }
    }

    return true;
}

fn predicateSatisfied(
    query: *c.TSQuery,
    name_raw: []const u8,
    args: []const PredicateArg,
    match: *const c.TSQueryMatch,
    text_buffer: *TextStore,
    allocator: std.mem.Allocator,
) bool {
    if (name_raw.len == 0) return true;
    if (isDirectiveName(name_raw)) return true;

    var name = name_raw;
    var negate = false;
    var any = false;
    while (true) {
        if (std.mem.startsWith(u8, name, "not-")) {
            negate = !negate;
            name = name[4..];
            continue;
        }
        if (std.mem.startsWith(u8, name, "any-") and !std.mem.eql(u8, name, "any-of?")) {
            any = true;
            name = name[4..];
            continue;
        }
        break;
    }

    const result = if (std.mem.eql(u8, name, "eq?"))
        predicateEq(args, match, text_buffer, allocator, any)
    else if (std.mem.eql(u8, name, "any-of?"))
        predicateAnyOf(args, match, text_buffer, allocator)
    else if (std.mem.eql(u8, name, "contains?"))
        predicateContains(args, match, text_buffer, allocator, any)
    else if (std.mem.eql(u8, name, "match?"))
        predicateMatch(query, args, match, text_buffer, allocator, any)
    else
        true;

    return if (negate) !result else result;
}

fn predicateEq(
    args: []const PredicateArg,
    match: *const c.TSQueryMatch,
    text_buffer: *TextStore,
    allocator: std.mem.Allocator,
    any: bool,
) bool {
    if (args.len < 2) return false;
    const cap = args[0];
    if (cap != .capture) return false;
    const capture_id = cap.capture;
    const rhs = args[1];

    return switch (rhs) {
        .string => |value| captureMatchesString(
            match,
            capture_id,
            text_buffer,
            allocator,
            value,
            any,
            nodeTextEquals,
        ),
        .capture => |rhs_capture| captureMatchesCapture(
            match,
            capture_id,
            rhs_capture,
            text_buffer,
            allocator,
            any,
        ),
    };
}

fn predicateAnyOf(
    args: []const PredicateArg,
    match: *const c.TSQueryMatch,
    text_buffer: *TextStore,
    allocator: std.mem.Allocator,
) bool {
    if (args.len < 2) return false;
    const cap = args[0];
    if (cap != .capture) return false;
    const capture_id = cap.capture;
    var ok = false;
    for (args[1..]) |arg| {
        if (arg == .string) {
            if (captureMatchesString(
                match,
                capture_id,
                text_buffer,
                allocator,
                arg.string,
                true,
                nodeTextEquals,
            )) {
                ok = true;
                break;
            }
        }
    }
    return ok;
}

fn predicateContains(
    args: []const PredicateArg,
    match: *const c.TSQueryMatch,
    text_buffer: *TextStore,
    allocator: std.mem.Allocator,
    any: bool,
) bool {
    if (args.len < 2) return false;
    const cap = args[0];
    if (cap != .capture) return false;
    const capture_id = cap.capture;
    var ok = false;
    for (args[1..]) |arg| {
        if (arg == .string) {
            if (captureMatchesString(
                match,
                capture_id,
                text_buffer,
                allocator,
                arg.string,
                any,
                nodeTextContains,
            )) {
                ok = true;
                if (any) break;
            } else if (!any) {
                return false;
            }
        }
    }
    return ok;
}

fn predicateMatch(
    query: *c.TSQuery,
    args: []const PredicateArg,
    match: *const c.TSQueryMatch,
    text_buffer: *TextStore,
    allocator: std.mem.Allocator,
    any: bool,
) bool {
    _ = query;
    if (args.len < 2) return false;
    const cap = args[0];
    if (cap != .capture) return false;
    const capture_id = cap.capture;
    const rhs = args[1];
    if (rhs != .string) return false;
    return captureMatchesPattern(
        match,
        capture_id,
        text_buffer,
        allocator,
        rhs.string,
        any,
    );
}

fn captureMatchesString(
    match: *const c.TSQueryMatch,
    capture_id: u32,
    text_buffer: *TextStore,
    allocator: std.mem.Allocator,
    needle: []const u8,
    any: bool,
    predicate: anytype,
) bool {
    var found = false;
    var any_ok = false;
    var i: u32 = 0;
    while (i < match.capture_count) : (i += 1) {
        const capture = match.captures[i];
        if (capture.index != capture_id) continue;
        found = true;
        const ok = predicate(text_buffer, allocator, capture.node, needle);
        if (any) {
            if (ok) return true;
        } else if (!ok) {
            return false;
        }
        any_ok = any_ok or ok;
    }
    if (!found) return false;
    return if (any) any_ok else true;
}

fn captureMatchesPattern(
    match: *const c.TSQueryMatch,
    capture_id: u32,
    text_buffer: *TextStore,
    allocator: std.mem.Allocator,
    pattern: []const u8,
    any: bool,
) bool {
    const log = app_logger.logger("editor.syntax");
    var found = false;
    var any_ok = false;
    var i: u32 = 0;
    while (i < match.capture_count) : (i += 1) {
        const capture = match.captures[i];
        if (capture.index != capture_id) continue;
        found = true;
        const text = readNodeTextAlloc(text_buffer, allocator, capture.node) catch |err| {
            log.logf(.warning, "captureMatchesPattern read text failed capture={d} err={s}", .{ capture_id, @errorName(err) });
            return false;
        };
        defer allocator.free(text);
        const ok = simpleRegexMatch(pattern, text);
        if (any) {
            if (ok) return true;
        } else if (!ok) {
            return false;
        }
        any_ok = any_ok or ok;
    }
    if (!found) return false;
    return if (any) any_ok else true;
}

fn captureMatchesCapture(
    match: *const c.TSQueryMatch,
    capture_id: u32,
    other_capture_id: u32,
    text_buffer: *TextStore,
    allocator: std.mem.Allocator,
    any: bool,
) bool {
    const other = firstCaptureNode(match, other_capture_id) orelse return false;
    var found = false;
    var any_ok = false;
    var i: u32 = 0;
    while (i < match.capture_count) : (i += 1) {
        const capture = match.captures[i];
        if (capture.index != capture_id) continue;
        found = true;
        const ok = nodeTextEqualsCapture(text_buffer, allocator, capture.node, other);
        if (any) {
            if (ok) return true;
        } else if (!ok) {
            return false;
        }
        any_ok = any_ok or ok;
    }
    if (!found) return false;
    return if (any) any_ok else true;
}

fn firstCaptureNode(match: *const c.TSQueryMatch, capture_id: u32) ?c.TSNode {
    var i: u32 = 0;
    while (i < match.capture_count) : (i += 1) {
        const capture = match.captures[i];
        if (capture.index == capture_id) return capture.node;
    }
    return null;
}

fn nodeTextEquals(
    text_buffer: *TextStore,
    allocator: std.mem.Allocator,
    node: c.TSNode,
    needle: []const u8,
) bool {
    const log = app_logger.logger("editor.syntax");
    const text = readNodeTextAlloc(text_buffer, allocator, node) catch |err| {
        log.logf(.warning, "nodeTextEquals read text failed err={s}", .{@errorName(err)});
        return false;
    };
    defer allocator.free(text);
    return std.mem.eql(u8, text, needle);
}

fn nodeTextEqualsCapture(
    text_buffer: *TextStore,
    allocator: std.mem.Allocator,
    left: c.TSNode,
    right: c.TSNode,
) bool {
    const log = app_logger.logger("editor.syntax");
    const left_start = c.ts_node_start_byte(left);
    const left_end = c.ts_node_end_byte(left);
    const right_start = c.ts_node_start_byte(right);
    const right_end = c.ts_node_end_byte(right);
    const left_len = @as(usize, @intCast(left_end - left_start));
    const right_len = @as(usize, @intCast(right_end - right_start));
    if (left_len != right_len) return false;
    const left_text = readNodeTextAlloc(text_buffer, allocator, left) catch |err| {
        log.logf(.warning, "nodeTextEqualsCapture read left failed err={s}", .{@errorName(err)});
        return false;
    };
    defer allocator.free(left_text);
    const right_text = readNodeTextAlloc(text_buffer, allocator, right) catch |err| {
        log.logf(.warning, "nodeTextEqualsCapture read right failed err={s}", .{@errorName(err)});
        return false;
    };
    defer allocator.free(right_text);
    return std.mem.eql(u8, left_text, right_text);
}

fn readNodeTextAlloc(
    text_buffer: *TextStore,
    allocator: std.mem.Allocator,
    node: c.TSNode,
) ![]u8 {
    const start_b = c.ts_node_start_byte(node);
    const end_b = c.ts_node_end_byte(node);
    if (end_b <= start_b) return allocator.alloc(u8, 0);
    const len = @as(usize, @intCast(end_b - start_b));
    var out = try allocator.alloc(u8, len);
    const written = text_buffer.readRange(start_b, out);
    if (written < len) {
        out = try allocator.realloc(out, written);
    }
    return out;
}

fn resolveInjectionLanguageName(allocator: std.mem.Allocator, name: []const u8) ?[]u8 {
    const trimmed = std.mem.trim(u8, name, " \t\r\n");
    if (trimmed.len == 0) return null;
    const resolved = syntax_registry_mod.SyntaxRegistry.resolveInjectionLanguage(trimmed) orelse return null;
    return allocator.dupe(u8, resolved) catch null;
}

fn nodeTextContains(
    text_buffer: *TextStore,
    allocator: std.mem.Allocator,
    node: c.TSNode,
    needle: []const u8,
) bool {
    const log = app_logger.logger("editor.syntax");
    const text = readNodeTextAlloc(text_buffer, allocator, node) catch |err| {
        log.logf(.warning, "nodeTextContains read text failed err={s}", .{@errorName(err)});
        return false;
    };
    defer allocator.free(text);
    return std.mem.indexOf(u8, text, needle) != null;
}

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

fn applyDirectives(
    query: *c.TSQuery,
    match: *const c.TSQueryMatch,
    match_meta: *MatchMeta,
    capture_meta: []CaptureMeta,
    allocator: std.mem.Allocator,
) void {
    const log = app_logger.logger("editor.syntax");
    var step_count: u32 = 0;
    const steps = c.ts_query_predicates_for_pattern(query, match.pattern_index, &step_count);
    if (steps == null or step_count == 0) return;

    var args = std.ArrayList(PredicateArg).empty;
    defer args.deinit(allocator);

    var current_name: ?[]const u8 = null;
    var i: u32 = 0;
    while (i < step_count) : (i += 1) {
        const step = steps[i];
        switch (step.type) {
            c.TSQueryPredicateStepTypeDone => {
                if (current_name) |name| {
                    if (isDirectiveName(name)) {
                        applyDirective(name, args.items, match_meta, capture_meta);
                    }
                }
                args.clearRetainingCapacity();
                current_name = null;
            },
            c.TSQueryPredicateStepTypeCapture => {
                if (current_name == null) continue;
                args.append(allocator, .{ .capture = step.value_id }) catch |err| {
                    log.logf(.warning, "applyDirectives capture append failed pattern={d} err={s}", .{ match.pattern_index, @errorName(err) });
                    return;
                };
            },
            c.TSQueryPredicateStepTypeString => {
                var len: u32 = 0;
                const value_ptr = c.ts_query_string_value_for_id(query, step.value_id, &len);
                const value = value_ptr[0..len];
                if (current_name == null) {
                    current_name = value;
                } else {
                    args.append(allocator, .{ .string = value }) catch |err| {
                        log.logf(.warning, "applyDirectives string append failed pattern={d} err={s}", .{ match.pattern_index, @errorName(err) });
                        return;
                    };
                }
            },
            else => {},
        }
    }
}

fn collectInjectionSettings(
    query: *c.TSQuery,
    match: *const c.TSQueryMatch,
    allocator: std.mem.Allocator,
    settings: *InjectionSettings,
) void {
    const log = app_logger.logger("editor.syntax");
    var step_count: u32 = 0;
    const steps = c.ts_query_predicates_for_pattern(query, match.pattern_index, &step_count);
    if (steps == null or step_count == 0) return;

    var args = std.ArrayList(PredicateArg).empty;
    defer args.deinit(allocator);

    var current_name: ?[]const u8 = null;
    var i: u32 = 0;
    while (i < step_count) : (i += 1) {
        const step = steps[i];
        switch (step.type) {
            c.TSQueryPredicateStepTypeDone => {
                if (current_name) |name| {
                    if (isDirectiveName(name)) {
                        applyInjectionDirective(name, args.items, settings);
                    }
                }
                args.clearRetainingCapacity();
                current_name = null;
            },
            c.TSQueryPredicateStepTypeCapture => {
                if (current_name == null) continue;
                args.append(allocator, .{ .capture = step.value_id }) catch |err| {
                    log.logf(.warning, "collectInjectionSettings capture append failed pattern={d} err={s}", .{ match.pattern_index, @errorName(err) });
                    return;
                };
            },
            c.TSQueryPredicateStepTypeString => {
                var len: u32 = 0;
                const value_ptr = c.ts_query_string_value_for_id(query, step.value_id, &len);
                const value = value_ptr[0..len];
                if (current_name == null) {
                    current_name = value;
                } else {
                    args.append(allocator, .{ .string = value }) catch |err| {
                        log.logf(.warning, "collectInjectionSettings string append failed pattern={d} err={s}", .{ match.pattern_index, @errorName(err) });
                        return;
                    };
                }
            },
            else => {},
        }
    }
}

fn applyInjectionDirective(
    name: []const u8,
    args: []const PredicateArg,
    settings: *InjectionSettings,
) void {
    if (!std.mem.eql(u8, name, "set!")) return;
    if (args.len == 0) return;

    var arg_index: usize = 0;
    if (args[0] == .capture) {
        if (args.len < 2) return;
        arg_index = 1;
    }

    if (arg_index >= args.len) return;
    if (args[arg_index] != .string) return;
    const key = args[arg_index].string;
    const value = if (arg_index + 1 < args.len and args[arg_index + 1] == .string)
        args[arg_index + 1].string
    else
        null;

    if (std.mem.eql(u8, key, "injection.language")) {
        if (value != null) settings.language = value;
        return;
    }
    if (std.mem.eql(u8, key, "injection.combined")) {
        settings.combined = true;
        return;
    }
    if (std.mem.eql(u8, key, "injection.include-children")) {
        settings.include_children = true;
        return;
    }
    if (std.mem.eql(u8, key, "injection.self")) {
        settings.use_self = true;
        return;
    }
    if (std.mem.eql(u8, key, "injection.parent")) {
        settings.use_parent = true;
        return;
    }
}

fn applyDirective(
    name: []const u8,
    args: []const PredicateArg,
    match_meta: *MatchMeta,
    capture_meta: []CaptureMeta,
) void {
    if (!std.mem.eql(u8, name, "set!")) return;
    if (args.len < 2) return;

    var arg_index: usize = 0;
    var capture_id: ?u32 = null;
    if (args[0] == .capture and args.len >= 3) {
        capture_id = args[0].capture;
        arg_index = 1;
    }

    if (arg_index + 1 >= args.len) return;
    if (args[arg_index] != .string or args[arg_index + 1] != .string) return;
    const key = args[arg_index].string;
    const value = args[arg_index + 1].string;

    if (capture_id) |cid| {
        if (cid >= capture_meta.len) return;
        applyDirectiveValue(&capture_meta[cid], key, value);
    } else {
        applyDirectiveValue(match_meta, key, value);
    }
}

fn applyDirectiveValue(meta: anytype, key: []const u8, value: []const u8) void {
    const log = app_logger.logger("editor.syntax");
    if (std.mem.eql(u8, key, "priority")) {
        const parsed = std.fmt.parseInt(i32, value, 10) catch |err| {
            log.logf(.debug, "directive priority parse failed value={s} err={s}", .{ value, @errorName(err) });
            return;
        };
        meta.priority = parsed;
        meta.has_priority = true;
        return;
    }
    if (std.mem.eql(u8, key, "conceal")) {
        meta.conceal = value;
        return;
    }
    if (std.mem.eql(u8, key, "conceal_lines")) {
        meta.conceal_lines = true;
        return;
    }
    if (std.mem.eql(u8, key, "url")) {
        meta.url = value;
        return;
    }
}

fn isDirectiveName(name: []const u8) bool {
    return name.len > 0 and name[name.len - 1] == '!';
}

fn simpleRegexMatch(pattern: []const u8, text: []const u8) bool {
    var pat = pattern;
    var anchored_start = false;
    var anchored_end = false;
    if (pat.len > 0 and pat[0] == '^') {
        anchored_start = true;
        pat = pat[1..];
    }
    if (pat.len > 0 and pat[pat.len - 1] == '$') {
        anchored_end = true;
        pat = pat[0 .. pat.len - 1];
    }
    if (anchored_start) {
        return simpleRegexMatchHere(pat, text, anchored_end);
    }
    var i: usize = 0;
    while (i <= text.len) : (i += 1) {
        if (simpleRegexMatchHere(pat, text[i..], anchored_end)) return true;
        if (i == text.len) break;
    }
    return false;
}

fn simpleRegexMatchHere(pattern: []const u8, text: []const u8, anchored_end: bool) bool {
    if (pattern.len == 0) return !anchored_end or text.len == 0;
    const token = simpleRegexNextToken(pattern);
    const rest = pattern[token.next_index..];
    if (token.quantifier == '*') {
        return simpleRegexMatchStar(token, rest, text, anchored_end);
    }
    if (token.quantifier == '+') {
        return simpleRegexMatchPlus(token, rest, text, anchored_end);
    }
    if (token.quantifier == '?') {
        return simpleRegexMatchQuestion(token, rest, text, anchored_end);
    }
    if (text.len == 0) return false;
    if (!simpleRegexTokenMatch(token, text[0])) return false;
    return simpleRegexMatchHere(rest, text[1..], anchored_end);
}

const SimpleRegexToken = struct {
    byte: u8,
    any: bool,
    next_index: usize,
    quantifier: u8,
};

fn simpleRegexNextToken(pattern: []const u8) SimpleRegexToken {
    if (pattern.len == 0) return .{ .byte = 0, .any = false, .next_index = 0, .quantifier = 0 };
    var idx: usize = 0;
    var byte = pattern[0];
    var any = false;
    if (byte == '\\' and pattern.len > 1) {
        byte = pattern[1];
        idx = 2;
    } else {
        idx = 1;
        if (byte == '.') any = true;
    }
    var quantifier: u8 = 0;
    if (idx < pattern.len) {
        const q = pattern[idx];
        if (q == '*' or q == '+' or q == '?') {
            quantifier = q;
            idx += 1;
        }
    }
    return .{
        .byte = byte,
        .any = any,
        .next_index = idx,
        .quantifier = quantifier,
    };
}

fn simpleRegexTokenMatch(token: SimpleRegexToken, value: u8) bool {
    return token.any or token.byte == value;
}

fn simpleRegexMatchStar(
    token: SimpleRegexToken,
    rest: []const u8,
    text: []const u8,
    anchored_end: bool,
) bool {
    var i: usize = 0;
    while (true) {
        if (simpleRegexMatchHere(rest, text[i..], anchored_end)) return true;
        if (i >= text.len) break;
        if (!simpleRegexTokenMatch(token, text[i])) break;
        i += 1;
    }
    return false;
}

fn simpleRegexMatchPlus(
    token: SimpleRegexToken,
    rest: []const u8,
    text: []const u8,
    anchored_end: bool,
) bool {
    if (text.len == 0) return false;
    if (!simpleRegexTokenMatch(token, text[0])) return false;
    return simpleRegexMatchStar(token, rest, text[1..], anchored_end);
}

fn simpleRegexMatchQuestion(
    token: SimpleRegexToken,
    rest: []const u8,
    text: []const u8,
    anchored_end: bool,
) bool {
    if (simpleRegexMatchHere(rest, text, anchored_end)) return true;
    if (text.len == 0) return false;
    if (!simpleRegexTokenMatch(token, text[0])) return false;
    return simpleRegexMatchHere(rest, text[1..], anchored_end);
}


const HighlightEvent = struct {
    pos: usize,
    is_start: bool,
    token_index: usize,
};

fn splitHighlightOverlaps(
    allocator: std.mem.Allocator,
    tokens: []HighlightToken,
) ![]HighlightToken {
    if (tokens.len <= 1) return tokens;

    var events = try allocator.alloc(HighlightEvent, tokens.len * 2);
    defer allocator.free(events);

    var event_count: usize = 0;
    for (tokens, 0..) |token, i| {
        if (token.end <= token.start) continue;
        events[event_count] = .{ .pos = token.start, .is_start = true, .token_index = i };
        event_count += 1;
        events[event_count] = .{ .pos = token.end, .is_start = false, .token_index = i };
        event_count += 1;
    }

    if (event_count == 0) return tokens;
    const events_slice = events[0..event_count];

    std.sort.heap(HighlightEvent, events_slice, {}, struct {
        fn lessThan(_: void, a: HighlightEvent, b: HighlightEvent) bool {
            if (a.pos != b.pos) return a.pos < b.pos;
            if (a.is_start != b.is_start) return b.is_start;
            return a.token_index < b.token_index;
        }
    }.lessThan);

    var active = std.ArrayList(usize).empty;
    defer active.deinit(allocator);

    var output = std.ArrayList(HighlightToken).empty;
    errdefer output.deinit(allocator);

    var cursor_pos = events_slice[0].pos;
    var idx: usize = 0;
    while (idx < events_slice.len) {
        const pos = events_slice[idx].pos;
        if (pos > cursor_pos) {
            if (pickBestToken(tokens, active.items)) |best_index| {
                const best = tokens[best_index];
                try appendHighlightSegment(&output, allocator, .{
                    .start = cursor_pos,
                    .end = pos,
                    .kind = best.kind,
                    .priority = best.priority,
                    .conceal = best.conceal,
                    .url = best.url,
                    .conceal_lines = best.conceal_lines,
                });
            }
            cursor_pos = pos;
        }

        while (idx < events_slice.len and events_slice[idx].pos == pos and !events_slice[idx].is_start) : (idx += 1) {
            removeActiveToken(&active, events_slice[idx].token_index);
        }
        while (idx < events_slice.len and events_slice[idx].pos == pos and events_slice[idx].is_start) : (idx += 1) {
            try active.append(allocator, events_slice[idx].token_index);
        }
    }

    allocator.free(tokens);
    return output.toOwnedSlice(allocator);
}

fn removeActiveToken(active: *std.ArrayList(usize), token_index: usize) void {
    var i: usize = 0;
    while (i < active.items.len) : (i += 1) {
        if (active.items[i] == token_index) {
            _ = active.swapRemove(i);
            return;
        }
    }
}

fn pickBestToken(tokens: []HighlightToken, active: []const usize) ?usize {
    if (active.len == 0) return null;
    var best_index = active[0];
    for (active[1..]) |idx| {
        const candidate = tokens[idx];
        const best = tokens[best_index];
        if (candidate.priority > best.priority) {
            best_index = idx;
        } else if (candidate.priority == best.priority and idx > best_index) {
            best_index = idx;
        }
    }
    return best_index;
}

fn appendHighlightSegment(
    output: *std.ArrayList(HighlightToken),
    allocator: std.mem.Allocator,
    segment: HighlightToken,
) !void {
    if (segment.end <= segment.start) return;
    if (output.items.len > 0) {
        const last_index = output.items.len - 1;
        const last = output.items[last_index];
        if (last.end == segment.start and last.kind == segment.kind and last.priority == segment.priority and
            stringOptEqual(last.conceal, segment.conceal) and stringOptEqual(last.url, segment.url) and
            last.conceal_lines == segment.conceal_lines)
        {
            output.items[last_index].end = segment.end;
            return;
        }
    }
    try output.append(allocator, segment);
}

fn stringOptEqual(a: ?[]const u8, b: ?[]const u8) bool {
    if (a == null) return b == null;
    if (b == null) return false;
    return std.mem.eql(u8, a.?, b.?);
}

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
