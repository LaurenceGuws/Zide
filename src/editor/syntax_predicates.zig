const std = @import("std");
const text_store = @import("text_store.zig");
const app_logger = @import("../app_logger.zig");
const syntax_registry_mod = @import("syntax_registry.zig");

const ts_api = @import("treesitter_api.zig");
const c = ts_api.c_api;

const TextStore = text_store.TextStore;

pub const InjectionSettings = struct {
    language: ?[]const u8 = null,
    include_children: bool = false,
    combined: bool = false,
    use_self: bool = false,
    use_parent: bool = false,
};

pub const CaptureMeta = struct {
    priority: i32 = 0,
    has_priority: bool = false,
    conceal: ?[]const u8 = null,
    url: ?[]const u8 = null,
    conceal_lines: bool = false,
};

pub const MatchMeta = struct {
    priority: i32 = 0,
    has_priority: bool = false,
    conceal: ?[]const u8 = null,
    url: ?[]const u8 = null,
    conceal_lines: bool = false,
};

const PredicateArg = union(enum) {
    capture: u32,
    string: []const u8,
};

pub fn initCaptureMeta(meta: []CaptureMeta) void {
    for (meta) |*entry| {
        entry.* = .{};
    }
}

pub fn predicatesMatch(
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

pub fn readNodeTextAlloc(
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

pub fn resolveInjectionLanguageName(allocator: std.mem.Allocator, name: []const u8) ?[]u8 {
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

pub fn applyDirectives(
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

pub fn collectInjectionSettings(
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
