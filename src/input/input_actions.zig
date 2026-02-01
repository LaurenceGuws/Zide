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
        for (self.bindings.items) |binding| {
            if (!scopeMatches(binding.scope, focus)) continue;
            if (!modsMatch(binding.mods, batch.mods)) continue;
            const pressed = batch.keyPressed(binding.key);
            const repeated = binding.repeat and batch.keyRepeated(binding.key);
            if (!pressed and !repeated) continue;
            _ = self.actions.append(self.allocator, .{ .kind = binding.action, .consumed = false }) catch {};
            if (log.enabled_file or log.enabled_console) {
                log.logf(
                    "action={s} key={s} scope={s} focus={s} shift={d} ctrl={d} alt={d} super={d} repeat={d}",
                    .{ actionName(binding.action), @tagName(binding.key), @tagName(binding.scope), @tagName(focus), @intFromBool(binding.mods.shift), @intFromBool(binding.mods.ctrl), @intFromBool(binding.mods.alt), @intFromBool(binding.mods.super), @intFromBool(binding.repeat) },
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
        expected.super == actual.super;
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
    };
}
