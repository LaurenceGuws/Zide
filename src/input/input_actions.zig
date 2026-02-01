const std = @import("std");
const shared_types = @import("../types/mod.zig");
const app_logger = @import("../app_logger.zig");

pub const FocusKind = enum {
    editor,
    terminal,
};

pub const ActionKind = enum {
    none,
    copy,
    paste,
};

pub const InputAction = struct {
    kind: ActionKind,
    consumed: bool,
};

pub const InputRouter = struct {
    allocator: std.mem.Allocator,
    actions: std.ArrayList(InputAction),

    pub fn init(allocator: std.mem.Allocator) InputRouter {
        return .{
            .allocator = allocator,
            .actions = std.ArrayList(InputAction).empty,
        };
    }

    pub fn deinit(self: *InputRouter) void {
        self.actions.deinit(self.allocator);
    }

    pub fn clear(self: *InputRouter) void {
        self.actions.clearRetainingCapacity();
    }

    pub fn actionsSlice(self: *InputRouter) []const InputAction {
        return self.actions.items;
    }

    pub fn route(self: *InputRouter, batch: *shared_types.input.InputBatch, focus: FocusKind) void {
        self.clear();
        const log = app_logger.logger("input.router");
        var text_events: usize = 0;
        for (batch.events.items) |event| {
            switch (event) {
                .key => |key_event| {
                    if (!key_event.pressed) continue;
                    const kind = matchShortcut(key_event.key, key_event.mods);
                    _ = self.actions.append(self.allocator, .{ .kind = kind, .consumed = false }) catch {};
                    if (kind != .none and (log.enabled_file or log.enabled_console)) {
                        log.logf(
                            "action={s} key={s} focus={s} shift={d} ctrl={d} alt={d} super={d}",
                            .{ actionName(kind), @tagName(key_event.key), @tagName(focus), @intFromBool(key_event.mods.shift), @intFromBool(key_event.mods.ctrl), @intFromBool(key_event.mods.alt), @intFromBool(key_event.mods.super) },
                        );
                    }
                },
                .text => text_events += 1,
                else => {},
            }
        }
        if (text_events > 0 and (log.enabled_file or log.enabled_console)) {
            log.logf("text_input events={d}", .{text_events});
        }
    }
};

fn matchShortcut(key: shared_types.input.Key, mods: shared_types.input.Modifiers) ActionKind {
    if (mods.ctrl and mods.shift) {
        switch (key) {
            .c => return .copy,
            .v => return .paste,
            else => {},
        }
    }
    return .none;
}

fn actionName(kind: ActionKind) []const u8 {
    return switch (kind) {
        .none => "none",
        .copy => "copy",
        .paste => "paste",
    };
}
