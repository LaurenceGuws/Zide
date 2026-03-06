const std = @import("std");
const text_store = @import("text_store.zig");
const app_logger = @import("../app_logger.zig");
const grammar_manager_mod = @import("grammar_manager.zig");
const syntax_registry_mod = @import("syntax_registry.zig");

const TextStore = text_store.TextStore;

const ts_api = @import("treesitter_api.zig");
const c = ts_api.c_api;
const zig_language_mod = @import("zig_language.zig");

pub const TSLanguage = ts_api.TSLanguage;
pub const QueryPaths = grammar_manager_mod.QueryPaths;

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
    highlight_query: *QueryBundle,
    injection_query: ?*InjectionQuery,
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
        for (self.entries.items) |*entry| {
            if (!std.mem.eql(u8, entry.name, capture_name)) continue;
            entry.hits += 1;
            self.total_hits += 1;
            self.maybeLogSample();
            return;
        }

        const owned_name = self.allocator.dupe(u8, capture_name) catch return;
        self.entries.append(self.allocator, .{
            .name = owned_name,
            .hits = 1,
        }) catch {
            self.allocator.free(owned_name);
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
        top.appendSlice(self.allocator, self.entries.items) catch return;
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
                buf.appendSlice(self.allocator, ", ") catch return;
            }
            buf.writer(self.allocator).print("{s}:{d}", .{ entry.name, entry.hits }) catch return;
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

const CombinedInjection = struct {
    language_name: []u8,
    include_children: bool,
    nodes: std.ArrayList(c.TSNode),
};

pub const SyntaxHighlighter = struct {
    allocator: std.mem.Allocator,
    text_buffer: *TextStore,
    language_name: []const u8,
    grammar_manager: ?*grammar_manager_mod.GrammarManager,
    parser: *c.TSParser,
    tree: ?*c.TSTree,
    query_bundle: *QueryBundle,
    injection_query: ?*InjectionQuery,
    cursor: *c.TSQueryCursor,
    read_buffer: []u8,
    injected_languages: std.StringHashMap(*InjectedLanguage),
    plain_capture_sampler: PlainCaptureSampler,

    pub fn destroy(self: *SyntaxHighlighter) void {
        if (self.tree) |tree| {
            c.ts_tree_delete(tree);
        }
        c.ts_query_cursor_delete(self.cursor);
        c.ts_parser_delete(self.parser);
        self.destroyInjectedLanguages();
        self.plain_capture_sampler.deinit();
        self.allocator.free(self.read_buffer);
        self.allocator.destroy(self);
    }

    fn destroyInjectedLanguages(self: *SyntaxHighlighter) void {
        var it = self.injected_languages.iterator();
        while (it.next()) |entry| {
            const injected = entry.value_ptr.*;
            c.ts_query_cursor_delete(injected.cursor);
            c.ts_parser_delete(injected.parser);
            self.allocator.free(injected.language_name);
            self.allocator.destroy(injected);
        }
        self.injected_languages.deinit();
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

        var tokens = std.ArrayList(HighlightToken).empty;
        errdefer tokens.deinit(allocator);

        const tree = self.tree.?;
        const full_range = fullDocumentRange(self.text_buffer);
        var full_ranges = [1]c.TSRange{full_range};

        try self.highlightLayer(
            self.language_name,
            tree,
            self.query_bundle,
            self.injection_query,
            self.cursor,
            range_start,
            range_end,
            full_ranges[0..],
            0,
            null,
            allocator,
            &tokens,
        );

        var out = try tokens.toOwnedSlice(allocator);
        out = try splitHighlightOverlaps(allocator, out);
        return out;
    }

    fn highlightLayer(
        self: *SyntaxHighlighter,
        language_name: []const u8,
        tree: *c.TSTree,
        query_bundle: *QueryBundle,
        injection_query: ?*InjectionQuery,
        cursor: *c.TSQueryCursor,
        range_start: u32,
        range_end: u32,
        parent_ranges: []const c.TSRange,
        depth: usize,
        parent_language: ?[]const u8,
        allocator: std.mem.Allocator,
        tokens: *std.ArrayList(HighlightToken),
    ) anyerror!void {
        try appendHighlightTokens(
            self.text_buffer,
            query_bundle,
            cursor,
            tree,
            range_start,
            range_end,
            depth,
            allocator,
            tokens,
            &self.plain_capture_sampler,
        );

        if (injection_query == null) return;
        if (self.grammar_manager == null) return;
        if (depth >= max_injection_depth) return;

        try self.highlightInjectedLanguages(
            language_name,
            parent_language,
            tree,
            injection_query.?,
            range_start,
            range_end,
            parent_ranges,
            depth,
            allocator,
            tokens,
        );
    }

    fn highlightInjectedLanguages(
        self: *SyntaxHighlighter,
        language_name: []const u8,
        parent_language: ?[]const u8,
        tree: *c.TSTree,
        injection_query: *InjectionQuery,
        range_start: u32,
        range_end: u32,
        parent_ranges: []const c.TSRange,
        depth: usize,
        allocator: std.mem.Allocator,
        tokens: *std.ArrayList(HighlightToken),
    ) anyerror!void {
        if (injection_query.content_capture == null) return;

        const cursor = c.ts_query_cursor_new() orelse return;
        defer c.ts_query_cursor_delete(cursor);

        const root = c.ts_tree_root_node(tree);
        c.ts_query_cursor_exec(cursor, injection_query.query, root);

        var combined = std.AutoHashMap(u32, CombinedInjection).init(allocator);
        defer {
            var it = combined.iterator();
            while (it.next()) |entry| {
                entry.value_ptr.nodes.deinit(allocator);
                allocator.free(entry.value_ptr.language_name);
            }
            combined.deinit();
        }

        var match: c.TSQueryMatch = undefined;
        while (c.ts_query_cursor_next_match(cursor, &match)) {
            if (!predicatesMatch(
                injection_query.query,
                &match,
                self.text_buffer,
                allocator,
            )) {
                continue;
            }

            var content_nodes = std.ArrayList(c.TSNode).empty;
            defer content_nodes.deinit(allocator);

            var captured_language: ?[]u8 = null;
            defer if (captured_language) |value| allocator.free(value);

            var i: u32 = 0;
            while (i < match.capture_count) : (i += 1) {
                const capture = match.captures[i];
                if (capture.index == injection_query.content_capture.?) {
                    content_nodes.append(allocator, capture.node) catch continue;
                } else if (injection_query.language_capture) |lang_capture| {
                    if (capture.index == lang_capture) {
                        if (captured_language) |old| allocator.free(old);
                        captured_language = readNodeTextAlloc(self.text_buffer, allocator, capture.node) catch null;
                    }
                }
            }

            if (content_nodes.items.len == 0) continue;

            var settings = InjectionSettings{};
            collectInjectionSettings(
                injection_query.query,
                &match,
                allocator,
                &settings,
            );

            var resolved_language: ?[]u8 = null;
            if (captured_language) |raw| {
                resolved_language = resolveInjectionLanguageName(allocator, raw);
            }
            if (resolved_language == null and settings.language != null) {
                resolved_language = resolveInjectionLanguageName(allocator, settings.language.?);
            }
            if (resolved_language == null and settings.use_self) {
                resolved_language = resolveInjectionLanguageName(allocator, language_name);
            }
            if (resolved_language == null and settings.use_parent and parent_language != null) {
                resolved_language = resolveInjectionLanguageName(allocator, parent_language.?);
            }

            if (resolved_language == null) continue;
            var include_children = settings.include_children;
            if (!include_children and resolved_language != null and std.mem.eql(u8, resolved_language.?, "markdown_inline")) {
                include_children = true;
            }

            if (settings.combined) {
                const entry = try combined.getOrPut(match.pattern_index);
                if (!entry.found_existing) {
                    entry.value_ptr.* = .{
                        .language_name = resolved_language.?,
                        .include_children = include_children,
                        .nodes = std.ArrayList(c.TSNode).empty,
                    };
                } else {
                    if (!std.mem.eql(u8, entry.value_ptr.language_name, resolved_language.?)) {
                        allocator.free(resolved_language.?);
                        continue;
                    }
                    allocator.free(resolved_language.?);
                    entry.value_ptr.include_children = entry.value_ptr.include_children or include_children;
                }
                try entry.value_ptr.nodes.appendSlice(allocator, content_nodes.items);
                continue;
            }

            const lang_name = resolved_language.?;
            defer allocator.free(lang_name);
            for (content_nodes.items) |node| {
                try self.highlightInjectionNodes(
                    lang_name,
                    &.{node},
                    include_children,
                    range_start,
                    range_end,
                    parent_ranges,
                    depth,
                    language_name,
                    allocator,
                    tokens,
                );
            }
        }

        var it = combined.iterator();
        while (it.next()) |entry| {
            const group = entry.value_ptr.*;
            if (group.nodes.items.len == 0) continue;
            try self.highlightInjectionNodes(
                group.language_name,
                group.nodes.items,
                group.include_children,
                range_start,
                range_end,
                parent_ranges,
                depth,
                language_name,
                allocator,
                tokens,
            );
        }
    }

    fn highlightInjectionNodes(
        self: *SyntaxHighlighter,
        language_name: []const u8,
        nodes: []const c.TSNode,
        include_children: bool,
        range_start: u32,
        range_end: u32,
        parent_ranges: []const c.TSRange,
        depth: usize,
        parent_language: []const u8,
        allocator: std.mem.Allocator,
        tokens: *std.ArrayList(HighlightToken),
    ) anyerror!void {
        const injected = try self.getOrLoadInjectedLanguage(language_name) orelse return;
        if (nodes.len == 0) return;

        const ranges = try intersectRanges(allocator, parent_ranges, nodes, include_children);
        defer allocator.free(ranges);
        if (ranges.len == 0) return;

        if (!c.ts_parser_set_included_ranges(
            injected.parser,
            ranges.ptr,
            @as(u32, @intCast(ranges.len)),
        )) {
            return;
        }

        const input = c.TSInput{
            .payload = self,
            .read = tsRead,
            .encoding = c.TSInputEncodingUTF8,
        };
        const injected_tree = c.ts_parser_parse(injected.parser, null, input) orelse return;
        defer c.ts_tree_delete(injected_tree);

        try self.highlightLayer(
            injected.language_name,
            injected_tree,
            injected.highlight_query,
            injected.injection_query,
            injected.cursor,
            range_start,
            range_end,
            ranges,
            depth + 1,
            parent_language,
            allocator,
            tokens,
        );
    }

    fn getOrLoadInjectedLanguage(
        self: *SyntaxHighlighter,
        language_name: []const u8,
    ) !?*InjectedLanguage {
        if (self.injected_languages.get(language_name)) |entry| {
            return entry;
        }

        const manager = self.grammar_manager orelse return null;
        const grammar = try manager.getOrLoad(language_name) orelse return null;

        const parser = c.ts_parser_new() orelse return error.InitFailed;
        errdefer c.ts_parser_delete(parser);
        if (!c.ts_parser_set_language(parser, grammar.ts_language)) {
            return error.InitFailed;
        }

        const cursor = c.ts_query_cursor_new() orelse {
            c.ts_parser_delete(parser);
            return error.InitFailed;
        };
        errdefer c.ts_query_cursor_delete(cursor);

        const highlight_query = try global_query_cache.getOrLoad(
            language_name,
            "highlights",
            grammar.ts_language,
            grammar.query_paths.highlights,
        ) orelse {
            c.ts_query_cursor_delete(cursor);
            c.ts_parser_delete(parser);
            return null;
        };

        const injection_query = try global_injection_query_cache.getOrLoad(
            language_name,
            grammar.ts_language,
            grammar.query_paths.injections,
        );

        const name = try self.allocator.dupe(u8, language_name);
        errdefer self.allocator.free(name);
        const injected = try self.allocator.create(InjectedLanguage);
        errdefer self.allocator.destroy(injected);

        injected.* = .{
            .language_name = name,
            .parser = parser,
            .cursor = cursor,
            .ts_language = grammar.ts_language,
            .highlight_query = highlight_query,
            .injection_query = injection_query,
        };

        try self.injected_languages.put(name, injected);
        return injected;
    }
};

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
        query_paths.highlights,
    ) orelse return error.InitFailed;

    const self = try allocator.create(SyntaxHighlighter);
    errdefer allocator.destroy(self);

    const read_buffer = try allocator.alloc(u8, 64 * 1024);
    errdefer allocator.free(read_buffer);

    var injected_languages = std.StringHashMap(*InjectedLanguage).init(allocator);
    errdefer injected_languages.deinit();

    const injection_query = try global_injection_query_cache.getOrLoad(
        language_name,
        language,
        query_paths.injections,
    );

    self.* = .{
        .allocator = allocator,
        .text_buffer = text_buffer,
        .language_name = language_name,
        .grammar_manager = grammar_manager,
        .parser = parser,
        .tree = null,
        .query_bundle = query_bundle,
        .injection_query = injection_query,
        .cursor = cursor,
        .read_buffer = read_buffer,
        .injected_languages = injected_languages,
        .plain_capture_sampler = PlainCaptureSampler.init(allocator, language_name),
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
    query_bundle: *QueryBundle,
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
    if (captureNameIsOrHasPrefix(name, "keyword.control")) return .keyword_control;
    if (captureNameIsOrHasPrefix(name, "function.method")) return .function_method;
    if (captureNameIsOrHasPrefix(name, "type.builtin")) return .type_builtin;
    if (std.mem.startsWith(u8, name, "comment")) return .comment;
    if (std.mem.indexOf(u8, name, "builtin") != null) return .builtin;
    if (std.mem.startsWith(u8, name, "preproc")) return .preproc;
    if (std.mem.startsWith(u8, name, "keyword.directive")) return .preproc;
    if (std.mem.startsWith(u8, name, "function.macro")) return .macro;
    if (std.mem.startsWith(u8, name, "string.escape")) return .escape;
    if (std.mem.startsWith(u8, name, "string")) return .string;
    if (std.mem.startsWith(u8, name, "markup.link")) return .link;
    if (std.mem.startsWith(u8, name, "markup")) return .string;
    if (std.mem.startsWith(u8, name, "character")) return .string;
    if (std.mem.startsWith(u8, name, "number")) return .number;
    if (std.mem.startsWith(u8, name, "float")) return .number;
    if (std.mem.startsWith(u8, name, "boolean")) return .constant;
    if (std.mem.startsWith(u8, name, "constant")) return .constant;
    if (std.mem.startsWith(u8, name, "keyword")) return .keyword;
    if (std.mem.startsWith(u8, name, "function")) return .function;
    if (std.mem.startsWith(u8, name, "method")) return .function;
    if (std.mem.startsWith(u8, name, "constructor")) return .function;
    if (std.mem.startsWith(u8, name, "type")) return .type_name;
    if (std.mem.startsWith(u8, name, "class")) return .type_name;
    if (std.mem.startsWith(u8, name, "interface")) return .type_name;
    if (std.mem.startsWith(u8, name, "struct")) return .type_name;
    if (std.mem.startsWith(u8, name, "enum")) return .type_name;
    if (std.mem.startsWith(u8, name, "tag")) return .type_name;
    if (std.mem.startsWith(u8, name, "module")) return .namespace;
    if (std.mem.startsWith(u8, name, "namespace")) return .namespace;
    if (std.mem.startsWith(u8, name, "label")) return .label;
    if (std.mem.startsWith(u8, name, "operator")) return .operator;
    if (std.mem.startsWith(u8, name, "punctuation")) return .punctuation;
    if (std.mem.startsWith(u8, name, "attribute")) return .attribute;
    if (std.mem.startsWith(u8, name, "property")) return .variable;
    if (std.mem.startsWith(u8, name, "field")) return .variable;
    if (std.mem.startsWith(u8, name, "parameter")) return .variable;
    if (std.mem.startsWith(u8, name, "variable")) return .variable;
    if (std.mem.startsWith(u8, name, "error")) return .error_token;

    // Common alias captures used by upstream query packs (especially nvim-treesitter).
    if (std.mem.eql(u8, name, "none")) return .constant;
    if (std.mem.eql(u8, name, "import")) return .keyword;
    if (std.mem.eql(u8, name, "cImport")) return .keyword;
    if (std.mem.eql(u8, name, "include")) return .keyword;
    if (std.mem.eql(u8, name, "use")) return .keyword;
    if (std.mem.eql(u8, name, "package")) return .keyword;

    if (std.mem.eql(u8, name, "if")) return .keyword;
    if (std.mem.eql(u8, name, "else")) return .keyword;
    if (std.mem.eql(u8, name, "for")) return .keyword;
    if (std.mem.eql(u8, name, "while")) return .keyword;
    if (std.mem.eql(u8, name, "try")) return .keyword;
    if (std.mem.eql(u8, name, "catch")) return .keyword;
    if (std.mem.eql(u8, name, "finally")) return .keyword;
    if (std.mem.eql(u8, name, "throw")) return .keyword;
    if (std.mem.eql(u8, name, "return")) return .keyword;
    if (std.mem.eql(u8, name, "as")) return .keyword;
    if (std.mem.eql(u8, name, "async")) return .keyword;
    if (std.mem.eql(u8, name, "var")) return .keyword;

    if (std.mem.eql(u8, name, "private")) return .keyword;
    if (std.mem.eql(u8, name, "protected")) return .keyword;
    if (std.mem.eql(u8, name, "public")) return .keyword;
    if (std.mem.eql(u8, name, "protocol")) return .keyword;

    if (std.mem.eql(u8, name, "annotation")) return .attribute;
    if (std.mem.eql(u8, name, "deprecated")) return .attribute;
    if (std.mem.eql(u8, name, "diagnostic")) return .attribute;
    if (std.mem.eql(u8, name, "meta")) return .attribute;
    if (std.mem.eql(u8, name, "nodiscard")) return .attribute;
    if (std.mem.eql(u8, name, "noreturn")) return .attribute;

    if (std.mem.eql(u8, name, "func")) return .function;
    if (std.mem.eql(u8, name, "callback")) return .function;
    if (std.mem.eql(u8, name, "handler")) return .function;

    if (std.mem.eql(u8, name, "arg")) return .variable;
    if (std.mem.eql(u8, name, "argument")) return .variable;
    if (std.mem.eql(u8, name, "param")) return .variable;
    if (std.mem.eql(u8, name, "prop")) return .variable;
    if (std.mem.eql(u8, name, "local")) return .variable;
    if (std.mem.eql(u8, name, "identifier")) return .variable;

    if (std.mem.eql(u8, name, "diff.plus")) return .operator;
    if (std.mem.eql(u8, name, "diff.minus")) return .operator;
    if (std.mem.eql(u8, name, "define")) return .preproc;
    if (std.mem.eql(u8, name, "charset")) return .escape;
    return .plain;
}

fn captureNameIsOrHasPrefix(name: []const u8, prefix: []const u8) bool {
    if (std.mem.eql(u8, name, prefix)) return true;
    if (!std.mem.startsWith(u8, name, prefix)) return false;
    return name.len > prefix.len and name[prefix.len] == '.';
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
    query: *c.TSQuery,
    match: *const c.TSQueryMatch,
    text_buffer: *TextStore,
    allocator: std.mem.Allocator,
) bool {
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
                args.append(allocator, .{ .capture = step.value_id }) catch return false;
            },
            c.TSQueryPredicateStepTypeString => {
                var len: u32 = 0;
                const value_ptr = c.ts_query_string_value_for_id(query, step.value_id, &len);
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
    const text = readNodeTextAlloc(text_buffer, allocator, node) catch return false;
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
                args.append(allocator, .{ .capture = step.value_id }) catch return;
            },
            c.TSQueryPredicateStepTypeString => {
                var len: u32 = 0;
                const value_ptr = c.ts_query_string_value_for_id(query, step.value_id, &len);
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

fn collectInjectionSettings(
    query: *c.TSQuery,
    match: *const c.TSQueryMatch,
    allocator: std.mem.Allocator,
    settings: *InjectionSettings,
) void {
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
                args.append(allocator, .{ .capture = step.value_id }) catch return;
            },
            c.TSQueryPredicateStepTypeString => {
                var len: u32 = 0;
                const value_ptr = c.ts_query_string_value_for_id(query, step.value_id, &len);
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
    capture_names: [][]const u8,
    capture_kinds: []TokenKind,
    capture_noop: []bool,
    query_source: []u8,
    capture_count: usize,
};

const InjectionQuery = struct {
    query: *c.TSQuery,
    query_source: []u8,
    capture_count: usize,
    content_capture: ?u32,
    language_capture: ?u32,
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
        if (query_text.len == 0) {
            self.allocator.free(query_text);
            self.allocator.free(key);
            return null;
        }
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
            log.logf(.info, 
                "query parse failed lang={s} name={s} error_type={d} error_offset={d}",
                .{ language_name, query_name, @as(u32, @intCast(error_type)), error_offset },
            );
            self.allocator.free(key);
            return error.InitFailed;
        };
        errdefer c.ts_query_delete(query);

        const capture_count = c.ts_query_capture_count(query);
        const log = app_logger.logger("editor.highlight");
        log.logf(.info, 
            "query loaded lang={s} name={s} bytes={d} captures={d}",
            .{ language_name, query_name, query_text.len, capture_count },
        );
        const capture_kinds = try self.allocator.alloc(TokenKind, capture_count);
        errdefer self.allocator.free(capture_kinds);
        const capture_noop = try self.allocator.alloc(bool, capture_count);
        errdefer self.allocator.free(capture_noop);
        const capture_names = try self.allocator.alloc([]const u8, capture_count);
        var capture_names_loaded: usize = 0;
        errdefer {
            for (capture_names[0..capture_names_loaded]) |capture_name| {
                self.allocator.free(capture_name);
            }
            self.allocator.free(capture_names);
        }
        var skipped_count: usize = 0;
        var plain_count: usize = 0;
        var mapped_count: usize = 0;
        var plain_examples = std.ArrayList(u8).empty;
        defer plain_examples.deinit(self.allocator);
        const max_plain_examples: usize = 8;
        var plain_examples_written: usize = 0;
        for (capture_kinds, 0..) |*entry, i| {
            var name_len: u32 = 0;
            const name_ptr = c.ts_query_capture_name_for_id(query, @as(u32, @intCast(i)), &name_len);
            const name = name_ptr[0..name_len];
            capture_names[i] = try self.allocator.dupe(u8, name);
            capture_names_loaded += 1;
            const kind = mapCaptureKind(name);
            const skip = shouldSkipCapture(name);
            capture_noop[i] = skip or kind == .plain;
            if (skip) {
                skipped_count += 1;
            } else if (kind == .plain) {
                plain_count += 1;
                if (plain_examples_written < max_plain_examples) {
                    if (plain_examples_written > 0) {
                        plain_examples.appendSlice(self.allocator, ", ") catch |err| {
                            log.logf(.warning, "plain capture examples append separator failed: {s}", .{@errorName(err)});
                        };
                    }
                    plain_examples.appendSlice(self.allocator, name) catch |err| {
                        log.logf(.warning, "plain capture examples append name failed: {s}", .{@errorName(err)});
                    };
                    plain_examples_written += 1;
                }
            } else {
                mapped_count += 1;
            }
            entry.* = kind;
        }
        const effective_count = mapped_count + plain_count;
        const plain_pct = if (effective_count > 0)
            (@as(f64, @floatFromInt(plain_count)) * 100.0) / @as(f64, @floatFromInt(effective_count))
        else
            0.0;
        log.logf(.info, 
            "query capture coverage lang={s} name={s} mapped={d} plain={d} skipped={d} plain_pct={d:.1} plain_examples=\"{s}\"",
            .{
                language_name,
                query_name,
                mapped_count,
                plain_count,
                skipped_count,
                plain_pct,
                plain_examples.items,
            },
        );

        const bundle = try self.allocator.create(QueryBundle);
        errdefer self.allocator.destroy(bundle);
        bundle.* = .{
            .query = query,
            .capture_names = capture_names,
            .capture_kinds = capture_kinds,
            .capture_noop = capture_noop,
            .query_source = query_text,
            .capture_count = @as(usize, @intCast(capture_count)),
        };

        try self.map.put(key, bundle);
        return bundle;
    }
};

const InjectionQueryCache = struct {
    allocator: std.mem.Allocator,
    map: std.StringHashMap(*InjectionQuery),

    pub fn init(allocator: std.mem.Allocator) InjectionQueryCache {
        return .{
            .allocator = allocator,
            .map = std.StringHashMap(*InjectionQuery).init(allocator),
        };
    }

    pub fn getOrLoad(
        self: *InjectionQueryCache,
        language_name: []const u8,
        language: *const c.TSLanguage,
        query_path: ?[]const u8,
    ) !?*InjectionQuery {
        const key = try std.fmt.allocPrint(self.allocator, "{s}:injections:{s}", .{
            language_name,
            query_path orelse "",
        });
        if (self.map.get(key)) |bundle| {
            self.allocator.free(key);
            return bundle;
        }

        const query_text = try loadQueryText(self.allocator, language_name, "injections", query_path) orelse {
            self.allocator.free(key);
            return null;
        };
        if (query_text.len == 0) {
            self.allocator.free(query_text);
            self.allocator.free(key);
            return null;
        }
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
            log.logf(.info, 
                "injection query parse failed lang={s} error_type={d} error_offset={d}",
                .{ language_name, @as(u32, @intCast(error_type)), error_offset },
            );
            self.allocator.free(key);
            return error.InitFailed;
        };
        errdefer c.ts_query_delete(query);

        const capture_count = c.ts_query_capture_count(query);
        var content_capture: ?u32 = null;
        var language_capture: ?u32 = null;
        var i: u32 = 0;
        while (i < capture_count) : (i += 1) {
            var name_len: u32 = 0;
            const name_ptr = c.ts_query_capture_name_for_id(query, i, &name_len);
            const name = name_ptr[0..name_len];
            if (std.mem.eql(u8, name, "injection.content")) {
                content_capture = i;
            } else if (std.mem.eql(u8, name, "injection.language")) {
                language_capture = i;
            }
        }

        const bundle = try self.allocator.create(InjectionQuery);
        errdefer self.allocator.destroy(bundle);
        bundle.* = .{
            .query = query,
            .query_source = query_text,
            .capture_count = @as(usize, @intCast(capture_count)),
            .content_capture = content_capture,
            .language_capture = language_capture,
        };

        try self.map.put(key, bundle);
        return bundle;
    }
};

var global_query_cache = QueryCache.init(std.heap.page_allocator);
var global_injection_query_cache = InjectionQueryCache.init(std.heap.page_allocator);

fn loadQueryText(
    allocator: std.mem.Allocator,
    language_name: []const u8,
    query_name: []const u8,
    query_path: ?[]const u8,
) !?[]u8 {
    if (query_path) |path| {
        if (try readFileAbsoluteIfExists(allocator, path)) |data| {
            if (data.len == 0) {
                allocator.free(data);
                return null;
            }
            const log = app_logger.logger("editor.highlight");
            log.logf(.info, "query source path={s} bytes={d}", .{ path, data.len });
            return data;
        }
    }

    const rel_path = try std.fmt.allocPrint(allocator, "queries/{s}/{s}.scm", .{ language_name, query_name });
    defer allocator.free(rel_path);

    const log = app_logger.logger("editor.highlight");
    if (try readFileJoinedIfExists(allocator, &.{ ".zide", rel_path })) |data| {
        if (data.len == 0) {
            allocator.free(data);
            return null;
        }
        log.logf(.info, "query source path=.zide/{s} bytes={d}", .{ rel_path, data.len });
        return data;
    }

    if (try configQueryPath(allocator, rel_path)) |path| {
        defer allocator.free(path);
        if (try readFileAbsoluteIfExists(allocator, path)) |data| {
            if (data.len == 0) {
                allocator.free(data);
                return null;
            }
            log.logf(.info, "query source path={s} bytes={d}", .{ path, data.len });
            return data;
        }
    }

    if (try readFileJoinedIfExists(allocator, &.{ "assets", rel_path })) |data| {
        if (data.len == 0) {
            allocator.free(data);
            return null;
        }
        log.logf(.info, "query source path=assets/{s} bytes={d}", .{ rel_path, data.len });
        return data;
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
