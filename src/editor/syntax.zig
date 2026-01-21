const std = @import("std");
const text_store = @import("text_store.zig");

const TextStore = text_store.TextStore;

const c = @cImport({
    @cInclude("tree_sitter/api.h");
});

pub const TSLanguage = c.TSLanguage;

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
};

pub const SyntaxHighlighter = struct {
    allocator: std.mem.Allocator,
    text_buffer: *TextStore,
    parser: *c.TSParser,
    tree: ?*c.TSTree,
    query: *c.TSQuery,
    cursor: *c.TSQueryCursor,
    read_buffer: []u8,
    capture_kinds: []TokenKind,
    query_source: ?[]u8,

    pub fn destroy(self: *SyntaxHighlighter) void {
        if (self.tree) |tree| {
            c.ts_tree_delete(tree);
        }
        c.ts_query_cursor_delete(self.cursor);
        c.ts_query_delete(self.query);
        c.ts_parser_delete(self.parser);
        self.allocator.free(self.read_buffer);
        self.allocator.free(self.capture_kinds);
        if (self.query_source) |src| {
            self.allocator.free(src);
        }
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
        c.ts_query_cursor_exec(self.cursor, self.query, root);

        var tokens = std.ArrayList(HighlightToken).empty;
        errdefer tokens.deinit(allocator);

        var match: c.TSQueryMatch = undefined;
        while (c.ts_query_cursor_next_match(self.cursor, &match)) {
            var i: u32 = 0;
            while (i < match.capture_count) : (i += 1) {
                const capture = match.captures[i];
                const node = capture.node;
                const start_b = c.ts_node_start_byte(node);
                const end_b = c.ts_node_end_byte(node);
                if (end_b <= range_start or start_b >= range_end) continue;
                const token_kind = self.capture_kinds[capture.index];
                try tokens.append(allocator, .{
                    .start = start_b,
                    .end = end_b,
                    .kind = token_kind,
                });
            }
        }

        return tokens.toOwnedSlice(allocator);
    }
};

pub fn createZigHighlighter(
    allocator: std.mem.Allocator,
    text_buffer: *TextStore,
) !*SyntaxHighlighter {
    return createHighlighter(allocator, text_buffer, tree_sitter_zig(), zig_highlights_query);
}

pub fn createHighlighter(
    allocator: std.mem.Allocator,
    text_buffer: *TextStore,
    language: *const c.TSLanguage,
    query_src: []const u8,
) !*SyntaxHighlighter {
    const parser = c.ts_parser_new() orelse return error.InitFailed;
    errdefer c.ts_parser_delete(parser);
    if (!c.ts_parser_set_language(parser, language)) {
        return error.InitFailed;
    }

    const owned_query = try allocator.alloc(u8, query_src.len);
    std.mem.copyForwards(u8, owned_query, query_src);

    var error_offset: u32 = 0;
    var error_type: c.TSQueryError = c.TSQueryErrorNone;
    const query = c.ts_query_new(
        language,
        owned_query.ptr,
        @as(u32, @intCast(owned_query.len)),
        &error_offset,
        &error_type,
    ) orelse {
        allocator.free(owned_query);
        return error.InitFailed;
    };
    errdefer c.ts_query_delete(query);

    const cursor = c.ts_query_cursor_new() orelse {
        allocator.free(owned_query);
        return error.InitFailed;
    };
    errdefer c.ts_query_cursor_delete(cursor);

    const self = try allocator.create(SyntaxHighlighter);
    errdefer allocator.destroy(self);

    const capture_count = c.ts_query_capture_count(query);
    const capture_kinds = try allocator.alloc(TokenKind, capture_count);
    errdefer allocator.free(capture_kinds);
    for (capture_kinds, 0..) |*entry, i| {
        var name_len: u32 = 0;
        const name_ptr = c.ts_query_capture_name_for_id(query, @as(u32, @intCast(i)), &name_len);
        const name = name_ptr[0..name_len];
        entry.* = mapCaptureKind(name);
    }

    const read_buffer = try allocator.alloc(u8, 64 * 1024);
    errdefer allocator.free(read_buffer);

    self.* = .{
        .allocator = allocator,
        .text_buffer = text_buffer,
        .parser = parser,
        .tree = null,
        .query = query,
        .cursor = cursor,
        .read_buffer = read_buffer,
        .capture_kinds = capture_kinds,
        .query_source = owned_query,
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

fn mapCaptureKind(name: []const u8) TokenKind {
    if (std.mem.indexOf(u8, name, "comment") != null) return .comment;
    if (std.mem.indexOf(u8, name, "string") != null) return .string;
    if (std.mem.indexOf(u8, name, "keyword") != null) return .keyword;
    if (std.mem.indexOf(u8, name, "number") != null) return .number;
    if (std.mem.indexOf(u8, name, "function") != null) return .function;
    if (std.mem.indexOf(u8, name, "variable") != null) return .variable;
    if (std.mem.indexOf(u8, name, "type") != null) return .type_name;
    if (std.mem.indexOf(u8, name, "operator") != null) return .operator;
    if (std.mem.indexOf(u8, name, "builtin") != null) return .builtin;
    if (std.mem.indexOf(u8, name, "punctuation") != null) return .punctuation;
    if (std.mem.indexOf(u8, name, "constant") != null) return .constant;
    if (std.mem.indexOf(u8, name, "attribute") != null) return .attribute;
    if (std.mem.indexOf(u8, name, "namespace") != null) return .namespace;
    if (std.mem.indexOf(u8, name, "label") != null) return .label;
    if (std.mem.indexOf(u8, name, "error") != null) return .error_token;
    return .plain;
}

/// Default Zig highlights query
pub const zig_highlights_query =
    \\; Keywords
    \\(keyword) @keyword
    \\
    \\; Comments
    \\(line_comment) @comment
    \\(doc_comment) @comment
    \\
    \\; Strings
    \\(string_literal) @string
    \\(char_literal) @string
    \\
    \\; Numbers
    \\(integer) @number
    \\(float) @number
    \\
    \\; Types
    \\(builtin_type) @type
    \\(identifier) @variable
    \\
    \\; Functions
    \\(call_expression function: (identifier) @function)
    \\(function_declaration name: (identifier) @function)
    \\
    \\; Operators
    \\(binary_expression operator: _ @operator)
    \\(unary_expression operator: _ @operator)
;
