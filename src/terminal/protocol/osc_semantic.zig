const std = @import("std");
const app_logger = @import("../../app_logger.zig");
const osc_util = @import("osc_util.zig");
const semantic_prompt_mod = @import("../core/semantic_prompt.zig");

pub const SessionFacade = struct {
    ctx: *anyopaque,
    parse_semantic_prompt_fn: *const fn (ctx: *anyopaque, text: []const u8) void,
    parse_user_var_fn: *const fn (ctx: *anyopaque, text: []const u8) void,

    pub fn from(session: anytype) SessionFacade {
        const SessionPtr = @TypeOf(session);
        return .{
            .ctx = @ptrCast(session),
            .parse_semantic_prompt_fn = struct {
                fn call(ctx: *anyopaque, text: []const u8) void {
                    const s: SessionPtr = @ptrCast(@alignCast(ctx));
                    parseSemanticPromptOnSession(s, text);
                }
            }.call,
            .parse_user_var_fn = struct {
                fn call(ctx: *anyopaque, text: []const u8) void {
                    const s: SessionPtr = @ptrCast(@alignCast(ctx));
                    parseUserVarOnSession(s, text);
                }
            }.call,
        };
    }

    pub fn parseSemanticPrompt(self: *const SessionFacade, text: []const u8) void {
        self.parse_semantic_prompt_fn(self.ctx, text);
    }

    pub fn parseUserVar(self: *const SessionFacade, text: []const u8) void {
        self.parse_user_var_fn(self.ctx, text);
    }
};

const SessionState = struct {
    allocator: std.mem.Allocator,
    semantic_prompt: *semantic_prompt_mod.SemanticPromptState,
    semantic_prompt_aid: *std.ArrayList(u8),
    semantic_cmdline: *std.ArrayList(u8),
    semantic_cmdline_valid: *bool,
    user_vars: *std.StringHashMap([]u8),

    pub fn from(session: anytype) SessionState {
        return .{
            .allocator = session.allocator,
            .semantic_prompt = &session.semantic_prompt,
            .semantic_prompt_aid = &session.semantic_prompt_aid,
            .semantic_cmdline = &session.semantic_cmdline,
            .semantic_cmdline_valid = &session.semantic_cmdline_valid,
            .user_vars = &session.user_vars,
        };
    }
};

pub fn parseSemanticPrompt(session: SessionFacade, text: []const u8) void {
    session.parseSemanticPrompt(text);
}

pub fn parseUserVar(session: SessionFacade, text: []const u8) void {
    session.parseUserVar(text);
}

fn parseSemanticPromptOnSession(self: anytype, text: []const u8) void {
    var state = SessionState.from(self);
    if (text.len == 0) return;
    const log = app_logger.logger("terminal.osc");
    const kind = text[0];
    const rest = if (text.len > 1 and text[1] == ';') text[2..] else if (text.len == 1) "" else text[1..];

    switch (kind) {
        'A' => {
            state.semantic_prompt.prompt_active = true;
            state.semantic_prompt.input_active = false;
            state.semantic_prompt.output_active = false;
            state.semantic_prompt.kind = .primary;
            state.semantic_prompt.redraw = true;
            state.semantic_prompt.special_key = false;
            state.semantic_prompt.click_events = false;
            state.semantic_prompt.exit_code = null;
            state.semantic_prompt_aid.clearRetainingCapacity();
            state.semantic_cmdline_valid.* = false;
            applySemanticPromptOptions(&state, rest, true);
        },
        'B' => {
            state.semantic_prompt.prompt_active = false;
            state.semantic_prompt.input_active = true;
            state.semantic_prompt.output_active = false;
            applySemanticPromptOptions(&state, rest, false);
        },
        'C' => {
            state.semantic_prompt.prompt_active = false;
            state.semantic_prompt.input_active = false;
            state.semantic_prompt.output_active = true;
            applySemanticPromptEndInput(&state, rest);
        },
        'D' => {
            state.semantic_prompt.prompt_active = false;
            state.semantic_prompt.input_active = false;
            state.semantic_prompt.output_active = false;
            applySemanticPromptEndCommand(&state, rest);
        },
        else => {
                            log.logf(.debug, "osc 133: unknown kind={c}", .{kind});
        },
    }
}

fn parseUserVarOnSession(self: anytype, text: []const u8) void {
    var state = SessionState.from(self);
    const log = app_logger.logger("terminal.osc");
    const prefix = "SetUserVar=";
    if (!std.mem.startsWith(u8, text, prefix)) return;
    const rest = text[prefix.len..];
    const split = std.mem.indexOfScalar(u8, rest, '=') orelse return;
    const name = rest[0..split];
    const encoded = rest[split + 1 ..];
    if (name.len == 0) return;

    const max_bytes: usize = 1024 * 1024;
    if (encoded.len > max_bytes * 2) return;

    var decoded = std.ArrayList(u8).empty;
    defer decoded.deinit(state.allocator);
    if (encoded.len > 0) {
        const decoded_len = std.base64.standard.Decoder.calcSizeForSlice(encoded) catch |err| {
            log.logf(.warning, "osc user var decoded length failed: {s}", .{@errorName(err)});
            return;
        };
        if (decoded_len > max_bytes) return;
        decoded.resize(state.allocator, decoded_len) catch |err| {
            log.logf(.warning, "osc user var decoded buffer resize failed: {s}", .{@errorName(err)});
            return;
        };
        _ = std.base64.standard.Decoder.decode(decoded.items, encoded) catch |err| {
            log.logf(.warning, "osc user var base64 decode failed: {s}", .{@errorName(err)});
            return;
        };
    }

    setUserVar(&state, name, decoded.items);
}

fn applySemanticPromptOptions(state: *SessionState, text: []const u8, allow_aid: bool) void {
    if (text.len == 0) return;
    var it = std.mem.splitScalar(u8, text, ';');
    while (it.next()) |kv| {
        if (kv.len == 0) continue;
        const eq = std.mem.indexOfScalar(u8, kv, '=');
        const key = if (eq) |idx| kv[0..idx] else kv;
        const value = if (eq) |idx| kv[idx + 1 ..] else "";
        if (allow_aid and std.mem.eql(u8, key, "aid")) {
            state.semantic_prompt_aid.clearRetainingCapacity();
            state.semantic_prompt_aid.appendSlice(state.allocator, value) catch |err| {
                app_logger.logger("terminal.osc").logf(.warning, "osc 133 aid append failed len={d} err={s}", .{ value.len, @errorName(err) });
            };
            continue;
        }
        if (std.mem.eql(u8, key, "k")) {
            if (value.len == 1) {
                state.semantic_prompt.kind = switch (value[0]) {
                    'c' => .continuation,
                    's' => .secondary,
                    'r' => .right,
                    else => .primary,
                };
            }
            continue;
        }
        if (std.mem.eql(u8, key, "redraw")) {
            state.semantic_prompt.redraw = parseBoolFlag(value, state.semantic_prompt.redraw);
            continue;
        }
        if (std.mem.eql(u8, key, "special_key")) {
            state.semantic_prompt.special_key = parseBoolFlag(value, state.semantic_prompt.special_key);
            continue;
        }
        if (std.mem.eql(u8, key, "click_events")) {
            state.semantic_prompt.click_events = parseBoolFlag(value, state.semantic_prompt.click_events);
            continue;
        }
    }
}

fn applySemanticPromptEndInput(state: *SessionState, text: []const u8) void {
    if (text.len == 0) return;
    var it = std.mem.splitScalar(u8, text, ';');
    while (it.next()) |kv| {
        if (kv.len == 0) continue;
        const eq = std.mem.indexOfScalar(u8, kv, '=');
        const key = if (eq) |idx| kv[0..idx] else kv;
        const value = if (eq) |idx| kv[idx + 1 ..] else "";
        if (std.mem.eql(u8, key, "cmdline_url")) {
            setSemanticCmdlineUrl(state, value);
            continue;
        }
        if (std.mem.eql(u8, key, "cmdline")) {
            setSemanticCmdline(state, value);
            continue;
        }
    }
}

fn applySemanticPromptEndCommand(state: *SessionState, text: []const u8) void {
    const log = app_logger.logger("terminal.osc");
    if (text.len == 0) {
        state.semantic_prompt.exit_code = null;
        return;
    }
    if (text.len >= 2 and text[0] == ';') {
        const value = text[1..];
        state.semantic_prompt.exit_code = std.fmt.parseUnsigned(u8, value, 10) catch blk: {
            log.logf(.debug, "osc semantic exit parse failed value={s}", .{ value });
            break :blk null;
        };
        return;
    }
    state.semantic_prompt.exit_code = std.fmt.parseUnsigned(u8, text, 10) catch blk: {
        log.logf(.debug, "osc semantic exit parse failed value={s}", .{ text });
        break :blk null;
    };
}

fn setSemanticCmdline(state: *SessionState, value: []const u8) void {
    const log = app_logger.logger("terminal.osc");
    state.semantic_cmdline.clearRetainingCapacity();
    if (value.len == 0) {
        state.semantic_cmdline_valid.* = false;
        return;
    }
    _ = state.semantic_cmdline.appendSlice(state.allocator, value) catch |err| {
        log.logf(.warning, "osc semantic cmdline append failed: {s}", .{@errorName(err)});
        return;
    };
    state.semantic_cmdline_valid.* = true;
}

fn setSemanticCmdlineUrl(state: *SessionState, value: []const u8) void {
    const log = app_logger.logger("terminal.osc");
    var decoded = std.ArrayList(u8).empty;
    defer decoded.deinit(state.allocator);
    if (!osc_util.decodeOscPercent(state.allocator, &decoded, value)) {
        state.semantic_cmdline_valid.* = false;
        return;
    }
    state.semantic_cmdline.clearRetainingCapacity();
    _ = state.semantic_cmdline.appendSlice(state.allocator, decoded.items) catch |err| {
        log.logf(.warning, "osc semantic cmdline url append failed: {s}", .{@errorName(err)});
        return;
    };
    state.semantic_cmdline_valid.* = true;
}

fn parseBoolFlag(value: []const u8, default_value: bool) bool {
    if (value.len != 1) return default_value;
    return switch (value[0]) {
        '0' => false,
        '1' => true,
        else => default_value,
    };
}

fn setUserVar(state: *SessionState, name: []const u8, value: []const u8) void {
    const log = app_logger.logger("terminal.osc");
    const name_owned = state.allocator.dupe(u8, name) catch |err| {
        log.logf(.warning, "osc user var name alloc failed: {s}", .{@errorName(err)});
        return;
    };
    const value_owned = state.allocator.dupe(u8, value) catch |err| {
        log.logf(.warning, "osc user var value alloc failed: {s}", .{@errorName(err)});
        state.allocator.free(name_owned);
        return;
    };
    const entry = state.user_vars.getOrPut(name_owned) catch |err| {
        log.logf(.warning, "osc user var map insert failed: {s}", .{@errorName(err)});
        state.allocator.free(name_owned);
        state.allocator.free(value_owned);
        return;
    };
    if (entry.found_existing) {
        state.allocator.free(name_owned);
        state.allocator.free(entry.value_ptr.*);
        entry.value_ptr.* = value_owned;
    } else {
        entry.value_ptr.* = value_owned;
    }
}
