const std = @import("std");
const text_store = @import("text_store.zig");
const app_logger = @import("../app_logger.zig");

const TextStore = text_store.TextStore;

const ts_api = @import("treesitter_api.zig");
const c = ts_api.c_api;

pub const TSLanguage = ts_api.TSLanguage;

extern "c" fn tree_sitter_zig() *const c.TSLanguage;

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
    error_token = 15,
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

pub const SyntaxHighlighter = struct {
    allocator: std.mem.Allocator,
    text_buffer: *TextStore,
    parser: *c.TSParser,
    tree: ?*c.TSTree,
    query_bundle: *QueryBundle,
    cursor: *c.TSQueryCursor,
    read_buffer: []u8,

    pub fn destroy(self: *SyntaxHighlighter) void {
        if (self.tree) |tree| {
            c.ts_tree_delete(tree);
        }
        c.ts_query_cursor_delete(self.cursor);
        c.ts_parser_delete(self.parser);
        self.allocator.free(self.read_buffer);
        self.allocator.destroy(self);
    }

    pub fn reparse(self: *SyntaxHighlighter) bool {
        const input = c.TSInput{
            .payload = self,
            .read = tsRead,
            .encoding = c.TSInputEncodingUTF8,
        };
        const new_tree = c.ts_parser_parse(self.parser, self.tree, input);
        if (new_tree == null) return false;
        if (self.tree) |tree| {
            c.ts_tree_delete(tree);
        }
        self.tree = new_tree;
        return true;
    }

    pub fn reparseFull(self: *SyntaxHighlighter) bool {
        const input = c.TSInput{
            .payload = self,
            .read = tsRead,
            .encoding = c.TSInputEncodingUTF8,
        };
        const new_tree = c.ts_parser_parse(self.parser, null, input);
        if (new_tree == null) return false;
        if (self.tree) |tree| {
            c.ts_tree_delete(tree);
        }
        self.tree = new_tree;
        return true;
    }

    pub const ChangedRange = struct {
        start_byte: usize,
        end_byte: usize,
    };

    pub fn applyEdit(
        self: *SyntaxHighlighter,
        start_byte: usize,
        old_end_byte: usize,
        new_end_byte: usize,
        start_point: c.TSPoint,
        old_end_point: c.TSPoint,
        new_end_point: c.TSPoint,
        allocator: std.mem.Allocator,
    ) ![]ChangedRange {
        const input = c.TSInput{
            .payload = self,
            .read = tsRead,
            .encoding = c.TSInputEncodingUTF8,
        };

        if (self.tree) |tree| {
            const edit = c.TSInputEdit{
                .start_byte = @as(u32, @intCast(start_byte)),
                .old_end_byte = @as(u32, @intCast(old_end_byte)),
                .new_end_byte = @as(u32, @intCast(new_end_byte)),
                .start_point = start_point,
                .old_end_point = old_end_point,
                .new_end_point = new_end_point,
            };
            c.ts_tree_edit(tree, &edit);
        }

        const new_tree = c.ts_parser_parse(self.parser, self.tree, input);
        if (new_tree == null) {
            return allocator.alloc(ChangedRange, 0);
        }

        const old_tree = self.tree;
        self.tree = new_tree;

        if (old_tree == null) {
            return allocator.alloc(ChangedRange, 0);
        }

        var range_count: u32 = 0;
        const ranges_ptr = c.ts_tree_get_changed_ranges(old_tree.?, new_tree, &range_count);
        c.ts_tree_delete(old_tree.?);
        if (ranges_ptr == null or range_count == 0) {
            return allocator.alloc(ChangedRange, 0);
        }
        defer std.c.free(ranges_ptr);

        const ranges = ranges_ptr[0..range_count];
        var out = try allocator.alloc(ChangedRange, ranges.len);
        for (ranges, 0..) |range, i| {
            out[i] = .{
                .start_byte = range.start_byte,
                .end_byte = range.end_byte,
            };
        }
        return out;
    }

    pub fn highlightRange(
        self: *SyntaxHighlighter,
        start: usize,
        end: usize,
        allocator: std.mem.Allocator,
    ) ![]HighlightToken {
        if (self.tree == null) {
            if (!self.reparse()) return emptyTokens(allocator);
        }
        if (self.tree == null) return emptyTokens(allocator);

        const max_u32 = std.math.maxInt(u32);
        if (start >= max_u32) {
            return emptyTokens(allocator);
        }
        const range_start = @as(u32, @intCast(start));
        const range_end = if (end > max_u32) max_u32 else @as(u32, @intCast(end));
        if (range_end <= range_start) {
            return emptyTokens(allocator);
        }

        const tree = self.tree.?;
        const root = c.ts_tree_root_node(tree);
        _ = c.ts_query_cursor_set_byte_range(self.cursor, range_start, range_end);
        c.ts_query_cursor_exec(self.cursor, self.query_bundle.query, root);

        var tokens = std.ArrayList(HighlightToken).empty;
        errdefer tokens.deinit(allocator);

        const capture_count = self.query_bundle.capture_count;
        var capture_meta_stack: [64]CaptureMeta = undefined;
        const capture_meta = if (capture_count <= capture_meta_stack.len)
            capture_meta_stack[0..capture_count]
        else
            try allocator.alloc(CaptureMeta, capture_count);
        defer if (capture_count > capture_meta_stack.len) allocator.free(capture_meta);

        var match: c.TSQueryMatch = undefined;
        while (c.ts_query_cursor_next_match(self.cursor, &match)) {
            if (!predicatesMatch(
                self.query_bundle,
                &match,
                self.text_buffer,
                allocator,
            )) {
                continue;
            }

            initCaptureMeta(capture_meta);
            var match_meta = MatchMeta{};
            applyDirectives(
                self.query_bundle,
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
                if (self.query_bundle.capture_noop[capture.index]) continue;
                const token_kind = self.query_bundle.capture_kinds[capture.index];
                const meta = capture_meta[capture.index];
                const priority = if (meta.has_priority) meta.priority else match_meta.priority;
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

        const out = try tokens.toOwnedSlice(allocator);
        const log = app_logger.logger("editor.highlight");
        log.logf("highlight range bytes={d}-{d} tokens={d}", .{ range_start, range_end, out.len });
        return out;
    }
};

pub fn createZigHighlighter(
    allocator: std.mem.Allocator,
    text_buffer: *TextStore,
) !*SyntaxHighlighter {
    return createHighlighter(allocator, text_buffer, "zig", tree_sitter_zig(), null);
}

pub fn createHighlighterForLanguage(
    allocator: std.mem.Allocator,
    text_buffer: *TextStore,
    language_name: []const u8,
    language: *const c.TSLanguage,
    query_path: ?[]const u8,
) !*SyntaxHighlighter {
    return createHighlighter(allocator, text_buffer, language_name, language, query_path);
}

pub fn createHighlighter(
    allocator: std.mem.Allocator,
    text_buffer: *TextStore,
    language_name: []const u8,
    language: *const c.TSLanguage,
    query_path: ?[]const u8,
) !*SyntaxHighlighter {
    const parser = c.ts_parser_new() orelse return error.InitFailed;
    errdefer c.ts_parser_delete(parser);
    if (!c.ts_parser_set_language(parser, language)) {
        return error.InitFailed;
    }

    const cursor = c.ts_query_cursor_new() orelse {
        return error.InitFailed;
    };
    errdefer c.ts_query_cursor_delete(cursor);

    const query_bundle = try global_query_cache.getOrLoad(
        language_name,
        "highlights",
        language,
        query_path,
    ) orelse return error.InitFailed;

    const self = try allocator.create(SyntaxHighlighter);
    errdefer allocator.destroy(self);

    const read_buffer = try allocator.alloc(u8, 64 * 1024);
    errdefer allocator.free(read_buffer);

    self.* = .{
        .allocator = allocator,
        .text_buffer = text_buffer,
        .parser = parser,
        .tree = null,
        .query_bundle = query_bundle,
        .cursor = cursor,
        .read_buffer = read_buffer,
    };

    _ = self.reparse();
    return self;
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

fn mapCaptureKind(name: []const u8) TokenKind {
    if (std.mem.indexOf(u8, name, "comment") != null) return .comment;
    if (std.mem.indexOf(u8, name, "string") != null) return .string;
    if (std.mem.indexOf(u8, name, "character") != null) return .string;
    if (std.mem.indexOf(u8, name, "keyword") != null) return .keyword;
    if (std.mem.indexOf(u8, name, "number") != null or std.mem.indexOf(u8, name, "float") != null) return .number;
    if (std.mem.indexOf(u8, name, "boolean") != null or std.mem.indexOf(u8, name, "constant") != null) return .constant;
    if (std.mem.indexOf(u8, name, "function") != null) return .function;
    if (std.mem.indexOf(u8, name, "type") != null) return .type_name;
    if (std.mem.indexOf(u8, name, "builtin") != null) return .builtin;
    if (std.mem.indexOf(u8, name, "module") != null or std.mem.indexOf(u8, name, "namespace") != null) return .namespace;
    if (std.mem.indexOf(u8, name, "label") != null) return .label;
    if (std.mem.indexOf(u8, name, "operator") != null) return .operator;
    if (std.mem.indexOf(u8, name, "punctuation") != null) return .punctuation;
    if (std.mem.indexOf(u8, name, "attribute") != null or std.mem.indexOf(u8, name, "parameter") != null) return .attribute;
    if (std.mem.indexOf(u8, name, "variable") != null) return .variable;
    if (std.mem.indexOf(u8, name, "error") != null) return .error_token;
    return .plain;
}

fn shouldSkipCapture(name: []const u8) bool {
    if (name.len == 0) return true;
    if (name[0] == '_') return true;
    if (std.mem.eql(u8, name, "spell") or std.mem.eql(u8, name, "nospell")) return true;
    return false;
}

const PredicateArg = union(enum) {
    capture: u32,
    string: []const u8,
};

fn predicatesMatch(
    bundle: *QueryBundle,
    match: *const c.TSQueryMatch,
    text_buffer: *TextStore,
    allocator: std.mem.Allocator,
) bool {
    var step_count: u32 = 0;
    const steps = c.ts_query_predicates_for_pattern(bundle.query, match.pattern_index, &step_count);
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
                        bundle,
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
                args.append(allocator, .{ .capture = step.value_id }) catch return false;
            },
            c.TSQueryPredicateStepTypeString => {
                var len: u32 = 0;
                const value_ptr = c.ts_query_string_value_for_id(bundle.query, step.value_id, &len);
                const value = value_ptr[0..len];
                if (current_name == null) {
                    current_name = value;
                } else {
                    args.append(allocator, .{ .string = value }) catch return false;
                }
            },
            else => {},
        }
    }

    return true;
}

fn predicateSatisfied(
    bundle: *QueryBundle,
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
        predicateMatch(bundle, args, match, text_buffer, allocator, any)
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
    bundle: *QueryBundle,
    args: []const PredicateArg,
    match: *const c.TSQueryMatch,
    text_buffer: *TextStore,
    allocator: std.mem.Allocator,
    any: bool,
) bool {
    _ = bundle;
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
    var found = false;
    var any_ok = false;
    var i: u32 = 0;
    while (i < match.capture_count) : (i += 1) {
        const capture = match.captures[i];
        if (capture.index != capture_id) continue;
        found = true;
        const text = readNodeTextAlloc(text_buffer, allocator, capture.node) catch return false;
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
    const text = readNodeTextAlloc(text_buffer, allocator, node) catch return false;
    defer allocator.free(text);
    return std.mem.eql(u8, text, needle);
}

fn nodeTextEqualsCapture(
    text_buffer: *TextStore,
    allocator: std.mem.Allocator,
    left: c.TSNode,
    right: c.TSNode,
) bool {
    const left_start = c.ts_node_start_byte(left);
    const left_end = c.ts_node_end_byte(left);
    const right_start = c.ts_node_start_byte(right);
    const right_end = c.ts_node_end_byte(right);
    const left_len = @as(usize, @intCast(left_end - left_start));
    const right_len = @as(usize, @intCast(right_end - right_start));
    if (left_len != right_len) return false;
    const left_text = readNodeTextAlloc(text_buffer, allocator, left) catch return false;
    defer allocator.free(left_text);
    const right_text = readNodeTextAlloc(text_buffer, allocator, right) catch return false;
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

fn nodeTextContains(
    text_buffer: *TextStore,
    allocator: std.mem.Allocator,
    node: c.TSNode,
    needle: []const u8,
) bool {
    const text = readNodeTextAlloc(text_buffer, allocator, node) catch return false;
    defer allocator.free(text);
    return std.mem.indexOf(u8, text, needle) != null;
}

fn applyDirectives(
    bundle: *QueryBundle,
    match: *const c.TSQueryMatch,
    match_meta: *MatchMeta,
    capture_meta: []CaptureMeta,
    allocator: std.mem.Allocator,
) void {
    var step_count: u32 = 0;
    const steps = c.ts_query_predicates_for_pattern(bundle.query, match.pattern_index, &step_count);
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
                args.append(allocator, .{ .capture = step.value_id }) catch return;
            },
            c.TSQueryPredicateStepTypeString => {
                var len: u32 = 0;
                const value_ptr = c.ts_query_string_value_for_id(bundle.query, step.value_id, &len);
                const value = value_ptr[0..len];
                if (current_name == null) {
                    current_name = value;
                } else {
                    args.append(allocator, .{ .string = value }) catch return;
                }
            },
            else => {},
        }
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
    if (std.mem.eql(u8, key, "priority")) {
        const parsed = std.fmt.parseInt(i32, value, 10) catch return;
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

const QueryBundle = struct {
    query: *c.TSQuery,
    capture_kinds: []TokenKind,
    capture_noop: []bool,
    query_source: []u8,
    capture_count: usize,
};

const QueryCache = struct {
    allocator: std.mem.Allocator,
    map: std.StringHashMap(*QueryBundle),

    pub fn init(allocator: std.mem.Allocator) QueryCache {
        return .{
            .allocator = allocator,
            .map = std.StringHashMap(*QueryBundle).init(allocator),
        };
    }

    pub fn getOrLoad(
        self: *QueryCache,
        language_name: []const u8,
        query_name: []const u8,
        language: *const c.TSLanguage,
        query_path: ?[]const u8,
    ) !?*QueryBundle {
        const key = try std.fmt.allocPrint(self.allocator, "{s}:{s}:{s}", .{
            language_name,
            query_name,
            query_path orelse "",
        });
        if (self.map.get(key)) |bundle| {
            self.allocator.free(key);
            return bundle;
        }

        const query_text = try loadQueryText(self.allocator, language_name, query_name, query_path) orelse {
            self.allocator.free(key);
            return null;
        };
        errdefer self.allocator.free(query_text);

        var error_offset: u32 = 0;
        var error_type: c.TSQueryError = c.TSQueryErrorNone;
        const query = c.ts_query_new(
            language,
            query_text.ptr,
            @as(u32, @intCast(query_text.len)),
            &error_offset,
            &error_type,
        ) orelse {
            const log = app_logger.logger("editor.highlight");
            log.logf(
                "query parse failed lang={s} name={s} error_type={d} error_offset={d}",
                .{ language_name, query_name, @as(u32, error_type), error_offset },
            );
            self.allocator.free(key);
            return error.InitFailed;
        };
        errdefer c.ts_query_delete(query);

        const capture_count = c.ts_query_capture_count(query);
        const log = app_logger.logger("editor.highlight");
        log.logf(
            "query loaded lang={s} name={s} bytes={d} captures={d}",
            .{ language_name, query_name, query_text.len, capture_count },
        );
        const capture_kinds = try self.allocator.alloc(TokenKind, capture_count);
        errdefer self.allocator.free(capture_kinds);
        const capture_noop = try self.allocator.alloc(bool, capture_count);
        errdefer self.allocator.free(capture_noop);
        for (capture_kinds, 0..) |*entry, i| {
            var name_len: u32 = 0;
            const name_ptr = c.ts_query_capture_name_for_id(query, @as(u32, @intCast(i)), &name_len);
            const name = name_ptr[0..name_len];
            const kind = mapCaptureKind(name);
            capture_noop[i] = shouldSkipCapture(name) or kind == .plain;
            entry.* = kind;
        }

        const bundle = try self.allocator.create(QueryBundle);
        errdefer self.allocator.destroy(bundle);
        bundle.* = .{
            .query = query,
            .capture_kinds = capture_kinds,
            .capture_noop = capture_noop,
            .query_source = query_text,
            .capture_count = @as(usize, @intCast(capture_count)),
        };

        try self.map.put(key, bundle);
        return bundle;
    }
};

var global_query_cache = QueryCache.init(std.heap.page_allocator);

fn loadQueryText(
    allocator: std.mem.Allocator,
    language_name: []const u8,
    query_name: []const u8,
    query_path: ?[]const u8,
) !?[]u8 {
    if (query_path) |path| {
        if (try readFileAbsoluteIfExists(allocator, path)) |data| {
            const log = app_logger.logger("editor.highlight");
            log.logf("query source path={s} bytes={d}", .{ path, data.len });
            return data;
        }
    }

    const rel_path = try std.fmt.allocPrint(allocator, "queries/{s}/{s}.scm", .{ language_name, query_name });
    defer allocator.free(rel_path);

    const log = app_logger.logger("editor.highlight");
    if (try readFileJoinedIfExists(allocator, &.{ ".zide", rel_path })) |data| {
        log.logf("query source path=.zide/{s} bytes={d}", .{ rel_path, data.len });
        return data;
    }

    if (try configQueryPath(allocator, rel_path)) |path| {
        defer allocator.free(path);
        if (try readFileAbsoluteIfExists(allocator, path)) |data| {
            log.logf("query source path={s} bytes={d}", .{ path, data.len });
            return data;
        }
    }

    if (try readFileJoinedIfExists(allocator, &.{ "assets", rel_path })) |data| {
        log.logf("query source path=assets/{s} bytes={d}", .{ rel_path, data.len });
        return data;
    }

    if (std.mem.eql(u8, language_name, "zig") and std.mem.eql(u8, query_name, "highlights")) {
        const data = try allocator.dupe(u8, zig_highlights_query);
        log.logf("query source embedded lang={s} name={s} bytes={d}", .{ language_name, query_name, data.len });
        return @as(?[]u8, data);
    }

    return null;
}

fn configQueryPath(allocator: std.mem.Allocator, rel_path: []const u8) !?[]u8 {
    if (std.c.getenv("XDG_CONFIG_HOME")) |xdg| {
        const base = std.mem.sliceTo(xdg, 0);
        return @as(?[]u8, try std.fs.path.join(allocator, &.{ base, "zide", rel_path }));
    }
    if (std.c.getenv("HOME")) |home| {
        const base = std.mem.sliceTo(home, 0);
        return @as(?[]u8, try std.fs.path.join(allocator, &.{ base, ".config", "zide", rel_path }));
    }
    return null;
}

fn readFileIfExists(allocator: std.mem.Allocator, path: []const u8) !?[]u8 {
    const file = std.fs.cwd().openFile(path, .{}) catch |err| switch (err) {
        error.FileNotFound => return null,
        else => return err,
    };
    defer file.close();
    return try file.readToEndAlloc(allocator, std.math.maxInt(usize));
}

fn readFileJoinedIfExists(allocator: std.mem.Allocator, parts: []const []const u8) !?[]u8 {
    const path = try std.fs.path.join(allocator, parts);
    defer allocator.free(path);
    return readFileIfExists(allocator, path);
}

fn readFileAbsoluteIfExists(allocator: std.mem.Allocator, path: []const u8) !?[]u8 {
    const file = if (std.fs.path.isAbsolute(path))
        std.fs.openFileAbsolute(path, .{})
    else
        std.fs.cwd().openFile(path, .{});
    const handle = file catch |err| switch (err) {
        error.FileNotFound => return null,
        else => return err,
    };
    defer handle.close();
    return try handle.readToEndAlloc(allocator, std.math.maxInt(usize));
}

/// Default Zig highlights query
pub const zig_highlights_query =
    \\; Comments
    \\(comment) @comment
    \\
    \\; Strings
    \\(string) @string
    \\(multiline_string) @string
    \\(character) @string
    \\
    \\; Numbers
    \\(integer) @number
    \\(float) @number
    \\
    \\; Types / Builtins
    \\(builtin_type) @type
    \\(builtin_identifier) @builtin
    \\
    \\; Variables
    \\(identifier) @variable
    \\
    \\; Functions
    \\(call_expression function: (identifier) @function)
    \\(function_declaration name: (identifier) @function)
;

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
        tree_sitter_zig(),
        query_path,
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
        tree_sitter_zig(),
        query_path,
    );
    defer highlighter.destroy();

    const tokens = try highlighter.highlightRange(0, store.totalLen(), allocator);
    defer allocator.free(tokens);

    try std.testing.expectEqual(@as(usize, 1), tokens.len);
    try std.testing.expectEqualStrings("bar", text[tokens[0].start..tokens[0].end]);
}
