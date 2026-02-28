const std = @import("std");
const shared_types = @import("../types/mod.zig");
const app_logger = @import("../app_logger.zig");

pub const FocusKind = enum {
    editor,
    terminal,
};

pub const BindScope = enum {
    global,
    editor,
    terminal,
};

pub const ActionKind = enum {
    none,
    copy,
    paste,
    zoom_in,
    zoom_out,
    zoom_reset,
    new_editor,
    toggle_terminal,
    save,
    undo,
    redo,
    cut,
    reload_config,
    terminal_scrollback_pager,
};

pub const InputAction = struct {
    kind: ActionKind,
    consumed: bool,
};

pub const BindSpec = struct {
    scope: BindScope,
    key: shared_types.input.Key,
    mods: shared_types.input.Modifiers,
    action: ActionKind,
    repeat: bool,
};

pub const InputRouter = struct {
    allocator: std.mem.Allocator,
    actions: std.ArrayList(InputAction),
    bindings: std.ArrayList(BindSpec),

    pub fn init(allocator: std.mem.Allocator) InputRouter {
        return .{
            .allocator = allocator,
            .actions = std.ArrayList(InputAction).empty,
            .bindings = std.ArrayList(BindSpec).empty,
        };
    }

    pub fn deinit(self: *InputRouter) void {
        self.actions.deinit(self.allocator);
        self.bindings.deinit(self.allocator);
    }

    pub fn clear(self: *InputRouter) void {
        self.actions.clearRetainingCapacity();
    }

    pub fn actionsSlice(self: *InputRouter) []const InputAction {
        return self.actions.items;
    }

    pub fn setBindings(self: *InputRouter, bindings: []const BindSpec) void {
        self.bindings.clearRetainingCapacity();
        _ = self.bindings.appendSlice(self.allocator, bindings) catch {};
    }

    pub fn route(self: *InputRouter, batch: *shared_types.input.InputBatch, focus: FocusKind) void {
        self.clear();
        const log = app_logger.logger("input.router");
        var text_events: usize = 0;
        const keyEventMatches = struct {
            fn apply(batch_in: *shared_types.input.InputBatch, binding: BindSpec) bool {
                for (batch_in.events.items) |event| {
                    if (event != .key) continue;
                    const key_event = event.key;
                    if (!key_event.pressed) continue;
                    if (key_event.key != binding.key) continue;
                    if (!modsMatch(binding.mods, key_event.mods)) continue;
                    if (key_event.repeated and !binding.repeat) continue;
                    return true;
                }
                return false;
            }
        }.apply;
        for (self.bindings.items) |binding| {
            if (!scopeMatches(binding.scope, focus)) continue;
            if (!keyEventMatches(batch, binding)) continue;
            _ = self.actions.append(self.allocator, .{ .kind = binding.action, .consumed = false }) catch {};
            if (log.enabled_file or log.enabled_console) {
                log.logf(
                    "action={s} key={s} scope={s} focus={s} shift={d} ctrl={d} alt={d} super={d} altgr={d} repeat={d}",
                    .{ actionName(binding.action), @tagName(binding.key), @tagName(binding.scope), @tagName(focus), @intFromBool(binding.mods.shift), @intFromBool(binding.mods.ctrl), @intFromBool(binding.mods.alt), @intFromBool(binding.mods.super), @intFromBool(binding.mods.altgr), @intFromBool(binding.repeat) },
                );
            }
        }
        for (batch.events.items) |event| {
            if (event == .text) text_events += 1;
        }
        if (text_events > 0 and (log.enabled_file or log.enabled_console)) {
            log.logf("text_input events={d}", .{text_events});
        }
    }
};

fn scopeMatches(scope: BindScope, focus: FocusKind) bool {
    return switch (scope) {
        .global => true,
        .editor => focus == .editor,
        .terminal => focus == .terminal,
    };
}

fn modsMatch(expected: shared_types.input.Modifiers, actual: shared_types.input.Modifiers) bool {
    return expected.shift == actual.shift and
        expected.ctrl == actual.ctrl and
        expected.alt == actual.alt and
        expected.super == actual.super and
        expected.altgr == actual.altgr;
}

fn actionName(kind: ActionKind) []const u8 {
    return switch (kind) {
        .none => "none",
        .copy => "copy",
        .paste => "paste",
        .zoom_in => "zoom_in",
        .zoom_out => "zoom_out",
        .zoom_reset => "zoom_reset",
        .new_editor => "new_editor",
        .toggle_terminal => "toggle_terminal",
        .save => "save",
        .undo => "undo",
        .redo => "redo",
        .cut => "cut",
        .reload_config => "reload_config",
        .terminal_scrollback_pager => "terminal_scrollback_pager",
    };
}
