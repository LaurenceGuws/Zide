const std = @import("std");
const app_logger = @import("../../app_logger.zig");
const osc_util = @import("osc_util.zig");

pub fn parseSemanticPrompt(self: anytype, text: []const u8) void {
    if (text.len == 0) return;
    const log = app_logger.logger("terminal.osc");
    const kind = text[0];
    const rest = if (text.len > 1 and text[1] == ';') text[2..] else if (text.len == 1) "" else text[1..];

    switch (kind) {
        'A' => {
            self.semantic_prompt.prompt_active = true;
            self.semantic_prompt.input_active = false;
            self.semantic_prompt.output_active = false;
            self.semantic_prompt.kind = .primary;
            self.semantic_prompt.redraw = true;
            self.semantic_prompt.special_key = false;
            self.semantic_prompt.click_events = false;
            self.semantic_prompt.exit_code = null;
            self.semantic_prompt_aid.clearRetainingCapacity();
            self.semantic_cmdline_valid = false;
            applySemanticPromptOptions(self, rest, true);
        },
        'B' => {
            self.semantic_prompt.prompt_active = false;
            self.semantic_prompt.input_active = true;
            self.semantic_prompt.output_active = false;
            applySemanticPromptOptions(self, rest, false);
        },
        'C' => {
            self.semantic_prompt.prompt_active = false;
            self.semantic_prompt.input_active = false;
            self.semantic_prompt.output_active = true;
            applySemanticPromptEndInput(self, rest);
        },
        'D' => {
            self.semantic_prompt.prompt_active = false;
            self.semantic_prompt.input_active = false;
            self.semantic_prompt.output_active = false;
            applySemanticPromptEndCommand(self, rest);
        },
        else => {
            if (log.enabled_file or log.enabled_console) {
                log.logf(.info, "osc 133: unknown kind={c}", .{kind});
            }
        },
    }
}

pub fn parseUserVar(self: anytype, text: []const u8) void {
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
    defer decoded.deinit(self.allocator);
    if (encoded.len > 0) {
        const decoded_len = std.base64.standard.Decoder.calcSizeForSlice(encoded) catch return;
        if (decoded_len > max_bytes) return;
        decoded.resize(self.allocator, decoded_len) catch return;
        _ = std.base64.standard.Decoder.decode(decoded.items, encoded) catch return;
    }

    setUserVar(self, name, decoded.items);
}

fn applySemanticPromptOptions(self: anytype, text: []const u8, allow_aid: bool) void {
    if (text.len == 0) return;
    var it = std.mem.splitScalar(u8, text, ';');
    while (it.next()) |kv| {
        if (kv.len == 0) continue;
        const eq = std.mem.indexOfScalar(u8, kv, '=');
        const key = if (eq) |idx| kv[0..idx] else kv;
        const value = if (eq) |idx| kv[idx + 1 ..] else "";
        if (allow_aid and std.mem.eql(u8, key, "aid")) {
            self.semantic_prompt_aid.clearRetainingCapacity();
            self.semantic_prompt_aid.appendSlice(self.allocator, value) catch |err| {
                app_logger.logger("terminal.osc").logf(.warning, "osc 133 aid append failed len={d} err={s}", .{ value.len, @errorName(err) });
            };
            continue;
        }
        if (std.mem.eql(u8, key, "k")) {
            if (value.len == 1) {
                self.semantic_prompt.kind = switch (value[0]) {
                    'c' => .continuation,
                    's' => .secondary,
                    'r' => .right,
                    else => .primary,
                };
            }
            continue;
        }
        if (std.mem.eql(u8, key, "redraw")) {
            self.semantic_prompt.redraw = parseBoolFlag(value, self.semantic_prompt.redraw);
            continue;
        }
        if (std.mem.eql(u8, key, "special_key")) {
            self.semantic_prompt.special_key = parseBoolFlag(value, self.semantic_prompt.special_key);
            continue;
        }
        if (std.mem.eql(u8, key, "click_events")) {
            self.semantic_prompt.click_events = parseBoolFlag(value, self.semantic_prompt.click_events);
            continue;
        }
    }
}

fn applySemanticPromptEndInput(self: anytype, text: []const u8) void {
    if (text.len == 0) return;
    var it = std.mem.splitScalar(u8, text, ';');
    while (it.next()) |kv| {
        if (kv.len == 0) continue;
        const eq = std.mem.indexOfScalar(u8, kv, '=');
        const key = if (eq) |idx| kv[0..idx] else kv;
        const value = if (eq) |idx| kv[idx + 1 ..] else "";
        if (std.mem.eql(u8, key, "cmdline_url")) {
            setSemanticCmdlineUrl(self, value);
            continue;
        }
        if (std.mem.eql(u8, key, "cmdline")) {
            setSemanticCmdline(self, value);
            continue;
        }
    }
}

fn applySemanticPromptEndCommand(self: anytype, text: []const u8) void {
    if (text.len == 0) {
        self.semantic_prompt.exit_code = null;
        return;
    }
    if (text.len >= 2 and text[0] == ';') {
        const value = text[1..];
        self.semantic_prompt.exit_code = std.fmt.parseUnsigned(u8, value, 10) catch null;
        return;
    }
    self.semantic_prompt.exit_code = std.fmt.parseUnsigned(u8, text, 10) catch null;
}

fn setSemanticCmdline(self: anytype, value: []const u8) void {
    self.semantic_cmdline.clearRetainingCapacity();
    if (value.len == 0) {
        self.semantic_cmdline_valid = false;
        return;
    }
    _ = self.semantic_cmdline.appendSlice(self.allocator, value) catch return;
    self.semantic_cmdline_valid = true;
}

fn setSemanticCmdlineUrl(self: anytype, value: []const u8) void {
    var decoded = std.ArrayList(u8).empty;
    defer decoded.deinit(self.allocator);
    if (!osc_util.decodeOscPercent(self.allocator, &decoded, value)) {
        self.semantic_cmdline_valid = false;
        return;
    }
    self.semantic_cmdline.clearRetainingCapacity();
    _ = self.semantic_cmdline.appendSlice(self.allocator, decoded.items) catch return;
    self.semantic_cmdline_valid = true;
}

fn parseBoolFlag(value: []const u8, default_value: bool) bool {
    if (value.len != 1) return default_value;
    return switch (value[0]) {
        '0' => false,
        '1' => true,
        else => default_value,
    };
}

fn setUserVar(self: anytype, name: []const u8, value: []const u8) void {
    const name_owned = self.allocator.dupe(u8, name) catch return;
    const value_owned = self.allocator.dupe(u8, value) catch {
        self.allocator.free(name_owned);
        return;
    };
    const entry = self.user_vars.getOrPut(name_owned) catch {
        self.allocator.free(name_owned);
        self.allocator.free(value_owned);
        return;
    };
    if (entry.found_existing) {
        self.allocator.free(name_owned);
        self.allocator.free(entry.value_ptr.*);
        entry.value_ptr.* = value_owned;
    } else {
        entry.value_ptr.* = value_owned;
    }
}
