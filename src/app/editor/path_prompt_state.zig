const std = @import("std");
const app_types = @import("../app_state_types.zig");
const editor_mod = @import("../../editor/editor.zig");

pub const Kind = app_types.PathPromptKind;
pub const PendingAction = app_types.PathPromptPendingAction;
pub const State = app_types.PathPromptState;

const Editor = editor_mod.Editor;

fn cwdInitialPath(allocator: std.mem.Allocator, suffix: []const u8) ![]u8 {
    const cwd = try std.process.getCwdAlloc(allocator);
    defer allocator.free(cwd);
    if (suffix.len == 0) return allocator.dupe(u8, cwd);
    return std.fs.path.join(allocator, &.{ cwd, suffix });
}

pub fn open(state: *State, allocator: std.mem.Allocator, kind: Kind, initial_value: []const u8) !void {
    state.active = true;
    state.kind = kind;
    state.pending_action = null;
    state.query.clearRetainingCapacity();
    try state.query.appendSlice(allocator, initial_value);
    state.select_all = initial_value.len > 0;
    state.error_text = null;
}

pub fn close(state: *State) void {
    state.active = false;
    state.kind = null;
    state.pending_action = null;
    state.query.clearRetainingCapacity();
    state.select_all = false;
    state.error_text = null;
}

pub fn openForOpen(state: *State, allocator: std.mem.Allocator, editor: ?*Editor) !void {
    const initial_value = if (editor) |active_editor|
        if (active_editor.documentCore().filePath()) |path|
            try allocator.dupe(u8, path)
        else
            try cwdInitialPath(allocator, "")
    else
        try cwdInitialPath(allocator, "");
    defer allocator.free(initial_value);
    try open(state, allocator, .open_file, initial_value);
}

pub fn openForSaveAs(state: *State, allocator: std.mem.Allocator, editor: ?*Editor) !void {
    const initial_value = if (editor) |active_editor|
        if (active_editor.documentCore().filePath()) |path|
            try allocator.dupe(u8, path)
        else
            try cwdInitialPath(allocator, "untitled")
    else
        try cwdInitialPath(allocator, "untitled");
    defer allocator.free(initial_value);
    try open(state, allocator, .save_as, initial_value);
}

pub fn openForGoToLine(state: *State, allocator: std.mem.Allocator, editor: ?*Editor) !void {
    const initial_value = if (editor) |active_editor|
        try std.fmt.allocPrint(allocator, "{d}", .{active_editor.cursor.line + 1})
    else
        try allocator.dupe(u8, "1");
    defer allocator.free(initial_value);
    try open(state, allocator, .go_to_line, initial_value);
}

pub fn openForReplace(state: *State, allocator: std.mem.Allocator) !void {
    try open(state, allocator, .replace, "");
}

pub fn openForReplaceAll(state: *State, allocator: std.mem.Allocator) !void {
    try open(state, allocator, .replace_all, "");
}

pub fn openForConfirmDirtyClose(state: *State, allocator: std.mem.Allocator, pending_action: PendingAction) !void {
    try open(state, allocator, .confirm_close_dirty, "");
    state.pending_action = pending_action;
    state.select_all = false;
}

pub fn label(kind: Kind) []const u8 {
    return switch (kind) {
        .open_file => "Open",
        .save_as => "Save As",
        .go_to_line => "Go To Line",
        .replace => "Replace",
        .replace_all => "Replace All",
        .confirm_close_dirty => "Discard Changes",
    };
}

pub fn placeholder(kind: Kind) []const u8 {
    return switch (kind) {
        .open_file => "enter path and press Enter",
        .save_as => "enter destination path and press Enter",
        .go_to_line => "enter line or line:column and press Enter",
        .replace => "enter replacement and press Enter",
        .replace_all => "enter replacement and press Enter",
        .confirm_close_dirty => "type discard and press Enter",
    };
}

test "openForSaveAs seeds cwd untitled path when editor has no file path" {
    var state: State = .{
        .active = false,
        .kind = null,
        .query = .empty,
        .select_all = false,
        .error_text = null,
    };
    defer state.query.deinit(std.testing.allocator);

    try openForSaveAs(&state, std.testing.allocator, null);

    try std.testing.expect(state.active);
    try std.testing.expectEqual(Kind.save_as, state.kind.?);
    try std.testing.expect(state.query.items.len > 0);
    try std.testing.expect(std.mem.endsWith(u8, state.query.items, "untitled"));
    try std.testing.expect(state.select_all);
}

test "openForConfirmDirtyClose starts empty and active" {
    var state: State = .{
        .active = false,
        .kind = null,
        .query = .empty,
        .select_all = false,
        .error_text = null,
    };
    defer state.query.deinit(std.testing.allocator);

    try openForConfirmDirtyClose(&state, std.testing.allocator, .close_active_editor);

    try std.testing.expect(state.active);
    try std.testing.expectEqual(Kind.confirm_close_dirty, state.kind.?);
    try std.testing.expectEqual(PendingAction.close_active_editor, state.pending_action.?);
    try std.testing.expectEqual(@as(usize, 0), state.query.items.len);
    try std.testing.expect(!state.select_all);
}
