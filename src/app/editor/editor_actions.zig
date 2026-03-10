const input_actions = @import("../../input/input_actions.zig");
const editor_mod = @import("../../editor/editor.zig");

const Editor = editor_mod.Editor;

pub fn visualExtendDeltaForAction(action: input_actions.ActionKind, jump_rows: usize) ?i32 {
    const jump: i32 = @intCast(jump_rows);
    return switch (action) {
        .editor_extend_up => -1,
        .editor_extend_down => 1,
        .editor_extend_large_up => -jump,
        .editor_extend_large_down => jump,
        else => null,
    };
}

pub fn visualMoveDeltaForAction(action: input_actions.ActionKind, jump_rows: usize) ?i32 {
    const jump: i32 = @intCast(jump_rows);
    return switch (action) {
        .editor_move_large_up => -jump,
        .editor_move_large_down => jump,
        else => null,
    };
}

pub fn applyRepeatedVisualDelta(
    delta: i32,
    ctx: *anyopaque,
    step_fn: *const fn (ctx: *anyopaque, step: i32) bool,
) bool {
    var changed = false;
    var remaining = if (delta < 0) -delta else delta;
    const step: i32 = if (delta < 0) -1 else 1;
    while (remaining > 0) : (remaining -= 1) {
        if (!step_fn(ctx, step)) break;
        changed = true;
    }
    return changed;
}

pub fn applyDirectEditorAction(editor: *Editor, action: input_actions.ActionKind) bool {
    switch (action) {
        .editor_move_word_left => editor.moveCursorWordLeft(),
        .editor_move_word_right => editor.moveCursorWordRight(),
        .editor_extend_left => editor.extendSelectionLeft(),
        .editor_extend_right => editor.extendSelectionRight(),
        .editor_extend_line_start => editor.extendSelectionToLineStart(),
        .editor_extend_line_end => editor.extendSelectionToLineEnd(),
        .editor_extend_word_left => editor.extendSelectionWordLeft(),
        .editor_extend_word_right => editor.extendSelectionWordRight(),
        else => return false,
    }
    return true;
}

pub fn applyCaretEditorAction(editor: *Editor, action: input_actions.ActionKind) !bool {
    return switch (action) {
        .editor_add_caret_up => try editor.addCaretUp(),
        .editor_add_caret_down => try editor.addCaretDown(),
        else => false,
    };
}
