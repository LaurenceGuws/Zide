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
    terminal_new_tab,
    terminal_close_tab,
    terminal_next_tab,
    terminal_prev_tab,
    terminal_focus_tab_1,
    terminal_focus_tab_2,
    terminal_focus_tab_3,
    terminal_focus_tab_4,
    terminal_focus_tab_5,
    terminal_focus_tab_6,
    terminal_focus_tab_7,
    terminal_focus_tab_8,
    terminal_focus_tab_9,
    editor_add_caret_up,
    editor_add_caret_down,
    editor_move_word_left,
    editor_move_word_right,
    editor_move_large_up,
    editor_move_large_down,
    editor_extend_left,
    editor_extend_right,
    editor_extend_line_start,
    editor_extend_line_end,
    editor_extend_word_left,
    editor_extend_word_right,
    editor_extend_up,
    editor_extend_down,
    editor_extend_large_up,
    editor_extend_large_down,
    editor_search_open,
    editor_search_next,
    editor_search_prev,
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
        self.bindings.appendSlice(self.allocator, bindings) catch |err| {
            app_logger.logger("input.router").logf(.warning, "set bindings failed count={d} err={s}", .{ bindings.len, @errorName(err) });
        };
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
            self.actions.append(self.allocator, .{ .kind = binding.action, .consumed = false }) catch |err| {
                app_logger.logger("input.router").logf(.warning, "route action append failed action={s} err={s}", .{ actionName(binding.action), @errorName(err) });
                continue;
            };
                            log.logf(.info, 
                    "action={s} key={s} scope={s} focus={s} shift={d} ctrl={d} alt={d} super={d} altgr={d} repeat={d}",
                    .{ actionName(binding.action), @tagName(binding.key), @tagName(binding.scope), @tagName(focus), @intFromBool(binding.mods.shift), @intFromBool(binding.mods.ctrl), @intFromBool(binding.mods.alt), @intFromBool(binding.mods.super), @intFromBool(binding.mods.altgr), @intFromBool(binding.repeat) },
                );
        }
        for (batch.events.items) |event| {
            if (event == .text) text_events += 1;
        }
        if (text_events > 0 and (log.enabled_file or log.enabled_console)) {
            log.logf(.info, "text_input events={d}", .{text_events});
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
        .terminal_new_tab => "terminal_new_tab",
        .terminal_close_tab => "terminal_close_tab",
        .terminal_next_tab => "terminal_next_tab",
        .terminal_prev_tab => "terminal_prev_tab",
        .terminal_focus_tab_1 => "terminal_focus_tab_1",
        .terminal_focus_tab_2 => "terminal_focus_tab_2",
        .terminal_focus_tab_3 => "terminal_focus_tab_3",
        .terminal_focus_tab_4 => "terminal_focus_tab_4",
        .terminal_focus_tab_5 => "terminal_focus_tab_5",
        .terminal_focus_tab_6 => "terminal_focus_tab_6",
        .terminal_focus_tab_7 => "terminal_focus_tab_7",
        .terminal_focus_tab_8 => "terminal_focus_tab_8",
        .terminal_focus_tab_9 => "terminal_focus_tab_9",
        .editor_add_caret_up => "editor_add_caret_up",
        .editor_add_caret_down => "editor_add_caret_down",
        .editor_move_word_left => "editor_move_word_left",
        .editor_move_word_right => "editor_move_word_right",
        .editor_move_large_up => "editor_move_large_up",
        .editor_move_large_down => "editor_move_large_down",
        .editor_extend_left => "editor_extend_left",
        .editor_extend_right => "editor_extend_right",
        .editor_extend_line_start => "editor_extend_line_start",
        .editor_extend_line_end => "editor_extend_line_end",
        .editor_extend_word_left => "editor_extend_word_left",
        .editor_extend_word_right => "editor_extend_word_right",
        .editor_extend_up => "editor_extend_up",
        .editor_extend_down => "editor_extend_down",
        .editor_extend_large_up => "editor_extend_large_up",
        .editor_extend_large_down => "editor_extend_large_down",
        .editor_search_open => "editor_search_open",
        .editor_search_next => "editor_search_next",
        .editor_search_prev => "editor_search_prev",
    };
}

test "input router routes editor multi-caret actions by keycode and exact mods" {
    const allocator = std.testing.allocator;
    var router = InputRouter.init(allocator);
    defer router.deinit();

    var batch = shared_types.input.InputBatch.init(allocator);
    defer batch.deinit();

    router.setBindings(&.{
        .{
            .scope = .editor,
            .key = .up,
            .mods = .{ .shift = true, .alt = true },
            .action = .editor_add_caret_up,
            .repeat = false,
        },
        .{
            .scope = .editor,
            .key = .down,
            .mods = .{ .shift = true, .alt = true },
            .action = .editor_add_caret_down,
            .repeat = false,
        },
    });

    try batch.append(.{ .key = .{
        .key = .up,
        .mods = .{ .shift = true, .alt = true },
        .pressed = true,
        .repeated = false,
    } });
    router.route(&batch, .editor);
    try std.testing.expectEqual(@as(usize, 1), router.actionsSlice().len);
    try std.testing.expectEqual(ActionKind.editor_add_caret_up, router.actionsSlice()[0].kind);

    batch.clear();
    try batch.append(.{ .key = .{
        .key = .up,
        .mods = .{ .shift = true },
        .pressed = true,
        .repeated = false,
    } });
    router.route(&batch, .editor);
    try std.testing.expectEqual(@as(usize, 0), router.actionsSlice().len);
}

test "input router routes editor search actions by scope and modifiers" {
    const allocator = std.testing.allocator;
    var router = InputRouter.init(allocator);
    defer router.deinit();

    var batch = shared_types.input.InputBatch.init(allocator);
    defer batch.deinit();

    router.setBindings(&.{
        .{
            .scope = .editor,
            .key = .f,
            .mods = .{ .ctrl = true },
            .action = .editor_search_open,
            .repeat = false,
        },
        .{
            .scope = .editor,
            .key = .f3,
            .mods = .{},
            .action = .editor_search_next,
            .repeat = false,
        },
        .{
            .scope = .editor,
            .key = .f3,
            .mods = .{ .shift = true },
            .action = .editor_search_prev,
            .repeat = false,
        },
    });

    try batch.append(.{ .key = .{
        .key = .f,
        .mods = .{ .ctrl = true },
        .pressed = true,
        .repeated = false,
    } });
    router.route(&batch, .editor);
    try std.testing.expectEqual(@as(usize, 1), router.actionsSlice().len);
    try std.testing.expectEqual(ActionKind.editor_search_open, router.actionsSlice()[0].kind);

    batch.clear();
    try batch.append(.{ .key = .{
        .key = .f3,
        .mods = .{},
        .pressed = true,
        .repeated = false,
    } });
    router.route(&batch, .editor);
    try std.testing.expectEqual(@as(usize, 1), router.actionsSlice().len);
    try std.testing.expectEqual(ActionKind.editor_search_next, router.actionsSlice()[0].kind);

    batch.clear();
    try batch.append(.{ .key = .{
        .key = .f3,
        .mods = .{ .shift = true },
        .pressed = true,
        .repeated = false,
    } });
    router.route(&batch, .editor);
    try std.testing.expectEqual(@as(usize, 1), router.actionsSlice().len);
    try std.testing.expectEqual(ActionKind.editor_search_prev, router.actionsSlice()[0].kind);
}

test "input router routes editor movement actions by scope and modifiers" {
    const allocator = std.testing.allocator;
    var router = InputRouter.init(allocator);
    defer router.deinit();

    var batch = shared_types.input.InputBatch.init(allocator);
    defer batch.deinit();

    router.setBindings(&.{
        .{
            .scope = .editor,
            .key = .left,
            .mods = .{ .ctrl = true },
            .action = .editor_move_word_left,
            .repeat = true,
        },
        .{
            .scope = .editor,
            .key = .up,
            .mods = .{ .ctrl = true },
            .action = .editor_move_large_up,
            .repeat = true,
        },
        .{
            .scope = .editor,
            .key = .right,
            .mods = .{ .ctrl = true, .shift = true },
            .action = .editor_extend_word_right,
            .repeat = true,
        },
        .{
            .scope = .editor,
            .key = .home,
            .mods = .{ .shift = true },
            .action = .editor_extend_line_start,
            .repeat = true,
        },
        .{
            .scope = .editor,
            .key = .up,
            .mods = .{ .shift = true },
            .action = .editor_extend_up,
            .repeat = true,
        },
        .{
            .scope = .editor,
            .key = .down,
            .mods = .{ .ctrl = true, .shift = true },
            .action = .editor_extend_large_down,
            .repeat = true,
        },
    });

    try batch.append(.{ .key = .{
        .key = .left,
        .mods = .{ .ctrl = true },
        .pressed = true,
        .repeated = false,
    } });
    router.route(&batch, .editor);
    try std.testing.expectEqual(@as(usize, 1), router.actionsSlice().len);
    try std.testing.expectEqual(ActionKind.editor_move_word_left, router.actionsSlice()[0].kind);

    batch.clear();
    try batch.append(.{ .key = .{
        .key = .up,
        .mods = .{ .ctrl = true },
        .pressed = true,
        .repeated = false,
    } });
    router.route(&batch, .editor);
    try std.testing.expectEqual(@as(usize, 1), router.actionsSlice().len);
    try std.testing.expectEqual(ActionKind.editor_move_large_up, router.actionsSlice()[0].kind);

    batch.clear();
    try batch.append(.{ .key = .{
        .key = .right,
        .mods = .{ .ctrl = true, .shift = true },
        .pressed = true,
        .repeated = false,
    } });
    router.route(&batch, .editor);
    try std.testing.expectEqual(@as(usize, 1), router.actionsSlice().len);
    try std.testing.expectEqual(ActionKind.editor_extend_word_right, router.actionsSlice()[0].kind);

    batch.clear();
    try batch.append(.{ .key = .{
        .key = .home,
        .mods = .{ .shift = true },
        .pressed = true,
        .repeated = true,
    } });
    router.route(&batch, .editor);
    try std.testing.expectEqual(@as(usize, 1), router.actionsSlice().len);
    try std.testing.expectEqual(ActionKind.editor_extend_line_start, router.actionsSlice()[0].kind);

    batch.clear();
    try batch.append(.{ .key = .{
        .key = .up,
        .mods = .{ .shift = true },
        .pressed = true,
        .repeated = false,
    } });
    router.route(&batch, .editor);
    try std.testing.expectEqual(@as(usize, 1), router.actionsSlice().len);
    try std.testing.expectEqual(ActionKind.editor_extend_up, router.actionsSlice()[0].kind);

    batch.clear();
    try batch.append(.{ .key = .{
        .key = .down,
        .mods = .{ .ctrl = true, .shift = true },
        .pressed = true,
        .repeated = false,
    } });
    router.route(&batch, .editor);
    try std.testing.expectEqual(@as(usize, 1), router.actionsSlice().len);
    try std.testing.expectEqual(ActionKind.editor_extend_large_down, router.actionsSlice()[0].kind);
}

test "input router treats altgr as part of exact modifier identity" {
    const allocator = std.testing.allocator;
    var router = InputRouter.init(allocator);
    defer router.deinit();

    var batch = shared_types.input.InputBatch.init(allocator);
    defer batch.deinit();

    router.setBindings(&.{
        .{
            .scope = .editor,
            .key = .e,
            .mods = .{ .ctrl = true, .alt = true, .altgr = true },
            .action = .copy,
            .repeat = false,
        },
    });

    try batch.append(.{ .key = .{
        .key = .e,
        .mods = .{ .ctrl = true, .alt = true, .altgr = true },
        .pressed = true,
        .repeated = false,
    } });
    router.route(&batch, .editor);
    try std.testing.expectEqual(@as(usize, 1), router.actionsSlice().len);

    batch.clear();
    try batch.append(.{ .key = .{
        .key = .e,
        .mods = .{ .ctrl = true, .alt = true, .altgr = false },
        .pressed = true,
        .repeated = false,
    } });
    router.route(&batch, .editor);
    try std.testing.expectEqual(@as(usize, 0), router.actionsSlice().len);
}
