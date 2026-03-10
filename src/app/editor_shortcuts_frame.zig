const std = @import("std");
const app_editor_actions = @import("editor_actions.zig");
const app_search_panel_state = @import("search/search_panel_state.zig");
const app_shell = @import("../app_shell.zig");
const editor_mod = @import("../editor/editor.zig");
const shared_types = @import("../types/mod.zig");
const widgets = @import("../ui/widgets.zig");
const input_actions = @import("../input/input_actions.zig");

const Editor = editor_mod.Editor;
const EditorWidget = widgets.EditorWidget;
const EditorClusterCache = widgets.EditorClusterCache;
const layout_types = shared_types.layout;

pub const Result = struct {
    handled: bool = false,
    needs_redraw: bool = false,
};

pub fn handle(
    actions: []const input_actions.InputAction,
    allocator: std.mem.Allocator,
    shell: *app_shell.Shell,
    action_layout: layout_types.WidgetLayout,
    editor: *Editor,
    editor_cluster_cache: *EditorClusterCache,
    editor_wrap: bool,
    editor_large_jump_rows: usize,
    search_panel_active: *bool,
    search_panel_query: *std.ArrayList(u8),
) !Result {
    var editor_widget = EditorWidget.initWithCache(editor, editor_cluster_cache, editor_wrap);
    var out: Result = .{};

    for (actions) |action| {
        switch (action.kind) {
            .copy => {
                if (try editor.selectionTextAlloc()) |text| {
                    defer allocator.free(text);
                    const buf = try allocator.alloc(u8, text.len + 1);
                    defer allocator.free(buf);
                    std.mem.copyForwards(u8, buf[0..text.len], text);
                    buf[text.len] = 0;
                    const cstr: [*:0]const u8 = @ptrCast(buf.ptr);
                    shell.setClipboardText(cstr);
                    out.handled = true;
                }
            },
            .cut => {
                if (try editor.selectionTextAlloc()) |text| {
                    defer allocator.free(text);
                    const buf = try allocator.alloc(u8, text.len + 1);
                    defer allocator.free(buf);
                    std.mem.copyForwards(u8, buf[0..text.len], text);
                    buf[text.len] = 0;
                    const cstr: [*:0]const u8 = @ptrCast(buf.ptr);
                    shell.setClipboardText(cstr);
                    try editor.deleteSelection();
                    out.needs_redraw = true;
                    out.handled = true;
                }
            },
            .paste => {
                if (shell.getClipboardText()) |clip| {
                    try editor.insertText(clip);
                    out.needs_redraw = true;
                    out.handled = true;
                }
            },
            .save => {
                try editor.save();
                out.needs_redraw = true;
                out.handled = true;
            },
            .undo => {
                _ = try editor.undo();
                out.needs_redraw = true;
                out.handled = true;
            },
            .redo => {
                _ = try editor.redo();
                out.needs_redraw = true;
                out.handled = true;
            },
            .editor_add_caret_up => {
                if (try app_editor_actions.applyCaretEditorAction(editor, action.kind)) {
                    out.needs_redraw = true;
                    out.handled = true;
                }
            },
            .editor_add_caret_down => {
                if (try app_editor_actions.applyCaretEditorAction(editor, action.kind)) {
                    out.needs_redraw = true;
                    out.handled = true;
                }
            },
            .editor_move_word_left,
            .editor_move_word_right,
            .editor_extend_left,
            .editor_extend_right,
            .editor_extend_line_start,
            .editor_extend_line_end,
            .editor_extend_word_left,
            .editor_extend_word_right,
            => {
                if (app_editor_actions.applyDirectEditorAction(editor, action.kind)) {
                    out.needs_redraw = true;
                    out.handled = true;
                }
            },
            .editor_move_large_up, .editor_move_large_down => {
                const delta = app_editor_actions.visualMoveDeltaForAction(action.kind, editor_large_jump_rows).?;
                const Ctx = struct {
                    widget: *EditorWidget,
                    shell: *app_shell.Shell,
                };
                var ctx = Ctx{ .widget = &editor_widget, .shell = shell };
                const moved = app_editor_actions.applyRepeatedVisualDelta(
                    delta,
                    @ptrCast(&ctx),
                    struct {
                        fn step(raw: *anyopaque, dir: i32) bool {
                            const payload: *Ctx = @ptrCast(@alignCast(raw));
                            return payload.widget.moveCursorVisual(payload.shell, dir);
                        }
                    }.step,
                );
                if (moved) {
                    editor_widget.ensureCursorVisible(shell, action_layout.editor.height);
                    out.needs_redraw = true;
                    out.handled = true;
                }
            },
            .editor_extend_up, .editor_extend_down, .editor_extend_large_up, .editor_extend_large_down => {
                const delta = app_editor_actions.visualExtendDeltaForAction(action.kind, editor_large_jump_rows).?;
                const Ctx = struct {
                    widget: *EditorWidget,
                    shell: *app_shell.Shell,
                };
                var ctx = Ctx{ .widget = &editor_widget, .shell = shell };
                const extended = app_editor_actions.applyRepeatedVisualDelta(
                    delta,
                    @ptrCast(&ctx),
                    struct {
                        fn step(raw: *anyopaque, dir: i32) bool {
                            const payload: *Ctx = @ptrCast(@alignCast(raw));
                            return payload.widget.extendSelectionVisual(payload.shell, dir);
                        }
                    }.step,
                );
                if (extended) {
                    editor_widget.ensureCursorVisible(shell, action_layout.editor.height);
                    out.needs_redraw = true;
                    out.handled = true;
                }
            },
            .editor_search_open => {
                try app_search_panel_state.openPanel(
                    allocator,
                    search_panel_active,
                    search_panel_query,
                    editor,
                );
                out.needs_redraw = true;
                out.handled = true;
            },
            .editor_search_next => {
                if (editor.activateNextSearchMatch()) {
                    out.needs_redraw = true;
                    out.handled = true;
                }
            },
            .editor_search_prev => {
                if (editor.activatePrevSearchMatch()) {
                    out.needs_redraw = true;
                    out.handled = true;
                }
            },
            else => {},
        }
    }

    return out;
}
