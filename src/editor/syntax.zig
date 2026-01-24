const std = @import("std");
const text_store = @import("text_store.zig");
const app_logger = @import("../app_logger.zig");

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

        var match: c.TSQueryMatch = undefined;
        while (c.ts_query_cursor_next_match(self.cursor, &match)) {
            var i: u32 = 0;
            while (i < match.capture_count) : (i += 1) {
                const capture = match.captures[i];
                const node = capture.node;
                const start_b = c.ts_node_start_byte(node);
                const end_b = c.ts_node_end_byte(node);
                if (end_b <= range_start or start_b >= range_end) continue;
                if (self.query_bundle.capture_noop[capture.index]) continue;
                const token_kind = self.query_bundle.capture_kinds[capture.index];
                try tokens.append(allocator, .{
                    .start = start_b,
                    .end = end_b,
                    .kind = token_kind,
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
    return createHighlighter(allocator, text_buffer, "zig", tree_sitter_zig());
}

pub fn createHighlighter(
    allocator: std.mem.Allocator,
    text_buffer: *TextStore,
    language_name: []const u8,
    language: *const c.TSLanguage,
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

const QueryBundle = struct {
    query: *c.TSQuery,
    capture_kinds: []TokenKind,
    capture_noop: []bool,
    query_source: []u8,
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
    ) !?*QueryBundle {
        const key = try std.fmt.allocPrint(self.allocator, "{s}:{s}", .{ language_name, query_name });
        if (self.map.get(key)) |bundle| {
            self.allocator.free(key);
            return bundle;
        }

        const query_text = try loadQueryText(self.allocator, language_name, query_name) orelse {
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
) !?[]u8 {
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
    const file = std.fs.openFileAbsolute(path, .{}) catch |err| switch (err) {
        error.FileNotFound => return null,
        else => return err,
    };
    defer file.close();
    return try file.readToEndAlloc(allocator, std.math.maxInt(usize));
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
