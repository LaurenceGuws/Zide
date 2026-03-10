const std = @import("std");
const text_store = @import("text_store.zig");
const grammar_manager_mod = @import("grammar_manager.zig");
const ts_api = @import("treesitter_api.zig");
const syntax_queries = @import("syntax_queries.zig");

const TextStore = text_store.TextStore;
const c = ts_api.c_api;

pub fn SyntaxRuntime(
    comptime HighlightToken: type,
    comptime TokenKind: type,
    comptime QueryInfra: type,
    comptime PlainCaptureSampler: type,
    comptime Helpers: type,
) type {
    _ = TokenKind;
    return struct {
        pub const InjectedLanguage = struct {
            language_name: []u8,
            parser: *c.TSParser,
            cursor: *c.TSQueryCursor,
            ts_language: *const c.TSLanguage,
            highlight_query: *QueryInfra.QueryBundle,
            injection_query: ?*QueryInfra.InjectionQuery,
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
            query_bundle: *QueryInfra.QueryBundle,
            injection_query: ?*QueryInfra.InjectionQuery,
            cursor: *c.TSQueryCursor,
            read_buffer: []u8,
            injected_languages: std.StringHashMap(*InjectedLanguage),
            plain_capture_sampler: PlainCaptureSampler,

            pub const ChangedRange = struct {
                start_byte: usize,
                end_byte: usize,
            };

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
                    .read = Helpers.tsRead,
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
                    .read = Helpers.tsRead,
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
                    .read = Helpers.tsRead,
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
                    if (!self.reparse()) return Helpers.emptyTokens(allocator);
                }
                if (self.tree == null) return Helpers.emptyTokens(allocator);

                const max_u32 = std.math.maxInt(u32);
                if (start >= max_u32) {
                    return Helpers.emptyTokens(allocator);
                }
                const range_start = @as(u32, @intCast(start));
                const range_end = if (end > max_u32) max_u32 else @as(u32, @intCast(end));
                if (range_end <= range_start) {
                    return Helpers.emptyTokens(allocator);
                }

                var tokens = std.ArrayList(HighlightToken).empty;
                errdefer tokens.deinit(allocator);

                const tree = self.tree.?;
                const full_range = Helpers.fullDocumentRange(self.text_buffer);
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
                out = try Helpers.splitHighlightOverlaps(allocator, out);
                return out;
            }

            fn highlightLayer(
                self: *SyntaxHighlighter,
                language_name: []const u8,
                tree: *c.TSTree,
                query_bundle: *QueryInfra.QueryBundle,
                injection_query: ?*QueryInfra.InjectionQuery,
                cursor: *c.TSQueryCursor,
                range_start: u32,
                range_end: u32,
                parent_ranges: []const c.TSRange,
                depth: usize,
                parent_language: ?[]const u8,
                allocator: std.mem.Allocator,
                tokens: *std.ArrayList(HighlightToken),
            ) anyerror!void {
                try Helpers.appendHighlightTokens(
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
                if (depth >= Helpers.max_injection_depth) return;

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
                injection_query: *QueryInfra.InjectionQuery,
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
                    if (!Helpers.predicatesMatch(
                        injection_query.query,
                        &match,
                        self.text_buffer,
                        allocator,
                    )) continue;

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
                                captured_language = Helpers.readNodeTextAlloc(self.text_buffer, allocator, capture.node) catch null;
                            }
                        }
                    }
                    if (content_nodes.items.len == 0) continue;

                    var settings = Helpers.InjectionSettings{};
                    Helpers.collectInjectionSettings(
                        injection_query.query,
                        &match,
                        allocator,
                        &settings,
                    );

                    var resolved_language: ?[]u8 = null;
                    if (captured_language) |raw| resolved_language = Helpers.resolveInjectionLanguageName(allocator, raw);
                    if (resolved_language == null and settings.language != null) resolved_language = Helpers.resolveInjectionLanguageName(allocator, settings.language.?);
                    if (resolved_language == null and settings.use_self) resolved_language = Helpers.resolveInjectionLanguageName(allocator, language_name);
                    if (resolved_language == null and settings.use_parent and parent_language != null) resolved_language = Helpers.resolveInjectionLanguageName(allocator, parent_language.?);
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

                const ranges = try Helpers.intersectRanges(allocator, parent_ranges, nodes, include_children);
                defer allocator.free(ranges);
                if (ranges.len == 0) return;

                if (!c.ts_parser_set_included_ranges(injected.parser, ranges.ptr, @as(u32, @intCast(ranges.len)))) return;

                const input = c.TSInput{
                    .payload = self,
                    .read = Helpers.tsRead,
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

            fn getOrLoadInjectedLanguage(self: *SyntaxHighlighter, language_name: []const u8) !?*InjectedLanguage {
                if (self.injected_languages.get(language_name)) |entry| return entry;

                const manager = self.grammar_manager orelse return null;
                const grammar = try manager.getOrLoad(language_name) orelse return null;

                const parser = c.ts_parser_new() orelse return error.InitFailed;
                errdefer c.ts_parser_delete(parser);
                if (!c.ts_parser_set_language(parser, grammar.ts_language)) return error.InitFailed;

                const cursor = c.ts_query_cursor_new() orelse {
                    c.ts_parser_delete(parser);
                    return error.InitFailed;
                };
                errdefer c.ts_query_cursor_delete(cursor);

                const highlight_query = try QueryInfra.loadHighlightQuery(
                    language_name,
                    grammar.ts_language,
                    grammar.query_paths.highlights,
                ) orelse {
                    c.ts_query_cursor_delete(cursor);
                    c.ts_parser_delete(parser);
                    return null;
                };

                const injection_query = try QueryInfra.loadInjectionQuery(
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

        pub fn createHighlighter(
            allocator: std.mem.Allocator,
            text_buffer: *TextStore,
            language_name: []const u8,
            language: *const c.TSLanguage,
            query_paths: syntax_queries.QueryPaths,
            grammar_manager: ?*grammar_manager_mod.GrammarManager,
            plain_capture_sampler: PlainCaptureSampler,
        ) !*SyntaxHighlighter {
            const parser = c.ts_parser_new() orelse return error.InitFailed;
            errdefer c.ts_parser_delete(parser);
            if (!c.ts_parser_set_language(parser, language)) return error.InitFailed;

            const cursor = c.ts_query_cursor_new() orelse return error.InitFailed;
            errdefer c.ts_query_cursor_delete(cursor);

            const query_bundle = try QueryInfra.loadHighlightQuery(
                language_name,
                language,
                query_paths.highlights,
            ) orelse return error.InitFailed;

            const self = try allocator.create(SyntaxHighlighter);
            errdefer allocator.destroy(self);

            const read_buffer = try allocator.alloc(u8, 64 * 1024);
            errdefer allocator.free(read_buffer);

            var injected_languages = std.StringHashMap(*InjectedLanguage).init(allocator);
            errdefer injected_languages.deinit();

            const injection_query = try QueryInfra.loadInjectionQuery(
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
                .plain_capture_sampler = plain_capture_sampler,
            };

            _ = self.reparse();
            return self;
        }
    };
}
