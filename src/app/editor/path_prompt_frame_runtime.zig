const std = @import("std");
const app_active_editor_runtime = @import("active_editor_runtime.zig");
const app_logger = @import("../../app_logger.zig");
const app_prompt_state = @import("path_prompt_state.zig");
const app_shell = @import("../../app_shell.zig");
const app_text_field_input = @import("../text_field_input.zig");
const shared_types = @import("../../types/mod.zig");
const editor_mod = @import("../../editor/editor.zig");

const Editor = editor_mod.Editor;
const PathPromptState = app_prompt_state.State;
const PathPromptKind = app_prompt_state.Kind;
const Shell = app_shell.Shell;
const GoToLocation = struct {
    line_1: usize,
    col_1: ?usize,
};

pub const Result = struct {
    consumed_input: bool = false,
    clear_editor_cluster_cache: bool = false,
    needs_redraw: bool = false,
    note_input: bool = false,
};

pub const Hooks = struct {
    open_file: *const fn (ctx: *anyopaque, path: []const u8) anyerror!void,
};

const Command = enum {
    none,
    close,
    submit,
    backspace,
};

fn commandForInput(input_batch: *const shared_types.input.InputBatch) Command {
    if (input_batch.keyPressed(.escape)) return .close;
    if (input_batch.keyPressed(.enter) or input_batch.keyPressed(.kp_enter)) return .submit;
    if (input_batch.keyPressed(.backspace) or input_batch.keyRepeated(.backspace)) return .backspace;
    return .none;
}

fn appendTextEvents(
    allocator: std.mem.Allocator,
    query: *std.ArrayList(u8),
    select_all: *bool,
    input_batch: *const shared_types.input.InputBatch,
) !bool {
    return try app_text_field_input.appendTextEvents(allocator, query, select_all, input_batch);
}

fn popQueryScalar(query: *std.ArrayList(u8)) void {
    if (query.items.len == 0) return;
    var idx = query.items.len - 1;
    while (idx > 0 and (query.items[idx] & 0b1100_0000) == 0b1000_0000) : (idx -= 1) {}
    query.items.len = idx;
}

fn activeEditor(tab_bar: anytype, editors: []*Editor, active_tab: usize) ?*Editor {
    return app_active_editor_runtime.fromVisualIndex(tab_bar, editors, active_tab);
}

fn parsePositivePart(part: []const u8) !usize {
    const trimmed = std.mem.trim(u8, part, " \t");
    if (trimmed.len == 0) return error.InvalidLocation;
    return std.fmt.parseUnsigned(usize, trimmed, 10);
}

fn parseGoToLocation(query: []const u8) !GoToLocation {
    const trimmed = std.mem.trim(u8, query, " \t");
    if (trimmed.len == 0) return error.InvalidLocation;

    if (std.mem.indexOfAny(u8, trimmed, ":,")) |sep| {
        const line_1 = try parsePositivePart(trimmed[0..sep]);
        const col_1 = try parsePositivePart(trimmed[sep + 1 ..]);
        if (line_1 == 0 or col_1 == 0) return error.InvalidLocation;
        return .{ .line_1 = line_1, .col_1 = col_1 };
    }

    const line_1 = try parsePositivePart(trimmed);
    if (line_1 == 0) return error.InvalidLocation;
    return .{ .line_1 = line_1, .col_1 = null };
}

pub fn handle(
    allocator: std.mem.Allocator,
    shell: *Shell,
    prompt: *PathPromptState,
    editors: []*Editor,
    active_tab: usize,
    tab_bar: anytype,
    input_batch: *shared_types.input.InputBatch,
    ctx: *anyopaque,
    hooks: Hooks,
) !Result {
    var out: Result = .{};
    if (!prompt.active or prompt.kind == null) return out;
    out.consumed_input = true;
    out.needs_redraw = true;
    out.note_input = true;

    var handled = false;
    var query_changed = false;
    const command = commandForInput(input_batch);
    switch (command) {
        .close => {
            app_prompt_state.close(prompt);
            handled = true;
        },
        .submit => {
            handled = true;
            if (prompt.query.items.len > 0) {
                const log = app_logger.logger("app.editor.prompt");
                var submit_succeeded = true;
                switch (prompt.kind.?) {
                    .open_file => {
                        hooks.open_file(ctx, prompt.query.items) catch |err| {
                            log.logf(.warning, "open prompt submit failed path=\"{s}\" err={s}", .{ prompt.query.items, @errorName(err) });
                            submit_succeeded = false;
                            prompt.error_text = "open failed";
                        };
                    },
                    .save_as => {
                        const editor = activeEditor(tab_bar, editors, active_tab) orelse return out;
                        editor.saveAs(prompt.query.items) catch |err| {
                            log.logf(.warning, "save-as prompt submit failed path=\"{s}\" err={s}", .{ prompt.query.items, @errorName(err) });
                            submit_succeeded = false;
                            prompt.error_text = "save failed";
                        };
                    },
                    .go_to_line => {
                        const editor = activeEditor(tab_bar, editors, active_tab) orelse return out;
                        const maybe_location: ?GoToLocation = parseGoToLocation(prompt.query.items) catch |err| blk: {
                            log.logf(.warning, "go-to-line prompt parse failed query=\"{s}\" err={s}", .{ prompt.query.items, @errorName(err) });
                            submit_succeeded = false;
                            prompt.error_text = "invalid location";
                            break :blk null;
                        };
                        if (maybe_location) |location| {
                            const line0 = if (location.line_1 > 0) location.line_1 - 1 else 0;
                            const clamped_line = @min(line0, editor.lineCount() -| 1);
                            const line_len = editor.lineLen(clamped_line);
                            const col0 = if (location.col_1) |col_1| if (col_1 > 0) col_1 - 1 else 0 else 0;
                            const clamped_col = @min(col0, line_len);
                            editor.setCursor(clamped_line, clamped_col);
                        }
                    },
                    .replace => {
                        const editor = activeEditor(tab_bar, editors, active_tab) orelse return out;
                        if (editor.searchActiveMatch() == null) {
                            _ = editor.focusSearchActiveMatch();
                        }
                        _ = editor.replaceActiveSearchMatch(prompt.query.items) catch |err| {
                            log.logf(.warning, "replace prompt submit failed err={s}", .{@errorName(err)});
                            submit_succeeded = false;
                            prompt.error_text = "replace failed";
                        };
                    },
                    .replace_all => {
                        const editor = activeEditor(tab_bar, editors, active_tab) orelse return out;
                        _ = editor.replaceAllSearchMatches(prompt.query.items) catch |err| {
                            log.logf(.warning, "replace-all prompt submit failed err={s}", .{@errorName(err)});
                            submit_succeeded = false;
                            prompt.error_text = "replace all failed";
                        };
                    },
                }
                if (submit_succeeded) {
                    app_prompt_state.close(prompt);
                    out.clear_editor_cluster_cache = true;
                } else {
                    prompt.select_all = true;
                }
            }
        },
        .backspace => {
            if (prompt.select_all) {
                prompt.query.clearRetainingCapacity();
                prompt.select_all = false;
            } else {
                popQueryScalar(&prompt.query);
            }
            prompt.error_text = null;
            handled = true;
            query_changed = true;
        },
        .none => {},
    }

    if (try app_text_field_input.handleShortcuts(allocator, shell, &prompt.query, &prompt.select_all, input_batch)) {
        prompt.error_text = null;
        handled = true;
        query_changed = true;
    }

    if (try appendTextEvents(allocator, &prompt.query, &prompt.select_all, input_batch)) {
        prompt.error_text = null;
        handled = true;
        query_changed = true;
    }

    if (!handled and !query_changed) {
        out.needs_redraw = false;
        out.note_input = false;
    }
    return out;
}

test "parseGoToLocation accepts line and line:column forms" {
    const only_line = try parseGoToLocation("42");
    try std.testing.expectEqual(@as(usize, 42), only_line.line_1);
    try std.testing.expectEqual(@as(?usize, null), only_line.col_1);

    const with_col = try parseGoToLocation("42:7");
    try std.testing.expectEqual(@as(usize, 42), with_col.line_1);
    try std.testing.expectEqual(@as(?usize, 7), with_col.col_1);

    const with_comma = try parseGoToLocation("42,7");
    try std.testing.expectEqual(@as(usize, 42), with_comma.line_1);
    try std.testing.expectEqual(@as(?usize, 7), with_comma.col_1);
}
