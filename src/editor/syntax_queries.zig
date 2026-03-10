const std = @import("std");
const grammar_manager_mod = @import("grammar_manager.zig");
const ts_api = @import("treesitter_api.zig");
const app_logger = @import("../app_logger.zig");

const c = ts_api.c_api;

pub const QueryPaths = grammar_manager_mod.QueryPaths;

pub fn QueryInfra(comptime HighlightToken: type, comptime TokenKind: type) type {
    _ = HighlightToken;
    return struct {
        pub const QueryBundle = struct {
            query: *c.TSQuery,
            capture_names: [][]const u8,
            capture_kinds: []TokenKind,
            capture_noop: []bool,
            query_source: []u8,
            capture_count: usize,
        };

        pub const InjectionQuery = struct {
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
                    log.logf(.info, "query parse failed lang={s} name={s} error_type={d} error_offset={d}", .{
                        language_name,
                        query_name,
                        @as(u32, @intCast(error_type)),
                        error_offset,
                    });
                    self.allocator.free(key);
                    return error.InitFailed;
                };
                errdefer c.ts_query_delete(query);

                const capture_count = c.ts_query_capture_count(query);
                const log = app_logger.logger("editor.highlight");
                log.logf(.info, "query loaded lang={s} name={s} bytes={d} captures={d}", .{
                    language_name,
                    query_name,
                    query_text.len,
                    capture_count,
                });
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
                    const kind = mapCaptureKind(TokenKind, name);
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
                log.logf(.info, "query capture coverage lang={s} name={s} mapped={d} plain={d} skipped={d} plain_pct={d:.1} plain_examples=\"{s}\"", .{
                    language_name,
                    query_name,
                    mapped_count,
                    plain_count,
                    skipped_count,
                    plain_pct,
                    plain_examples.items,
                });

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
                    log.logf(.info, "injection query parse failed lang={s} error_type={d} error_offset={d}", .{
                        language_name,
                        @as(u32, @intCast(error_type)),
                        error_offset,
                    });
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

        pub fn loadHighlightQuery(
            language_name: []const u8,
            language: *const c.TSLanguage,
            query_path: ?[]const u8,
        ) !?*QueryBundle {
            return global_query_cache.getOrLoad(language_name, "highlights", language, query_path);
        }

        pub fn loadInjectionQuery(
            language_name: []const u8,
            language: *const c.TSLanguage,
            query_path: ?[]const u8,
        ) !?*InjectionQuery {
            return global_injection_query_cache.getOrLoad(language_name, language, query_path);
        }
    };
}

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

pub fn mapCaptureKind(comptime TokenKind: type, name: []const u8) TokenKind {
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

pub fn shouldSkipCapture(name: []const u8) bool {
    if (name.len == 0) return true;
    if (name[0] == '_') return true;
    if (std.mem.eql(u8, name, "spell") or std.mem.eql(u8, name, "nospell")) return true;
    return false;
}
