const app_shell = @import("../../app_shell.zig");
const app_logger = @import("../../app_logger.zig");
const shared_types = @import("../../types/mod.zig");
const editor_types = @import("../../editor/types.zig");
const widgets = @import("../../ui/widgets.zig");

const EditorWidget = widgets.EditorWidget;
const layout_types = shared_types.layout;
const input_types = shared_types.input;
const CursorPos = editor_types.CursorPos;

pub const SelectionState = struct {
    dragging: *bool,
    drag_start: *CursorPos,
    drag_rect: *bool,
};

pub const SelectionResult = struct {
    needs_redraw: bool = false,
    note_input: bool = false,
};

pub fn handleScrollbarInput(
    widget: *EditorWidget,
    shell: *app_shell.Shell,
    layout: layout_types.WidgetLayout,
    mouse: input_types.MousePos,
    input_batch: *input_types.InputBatch,
    hscroll_dragging: *bool,
    hscroll_grab_offset: *f32,
    vscroll_dragging: *bool,
    vscroll_grab_offset: *f32,
) bool {
    const editor_x = layout.editor.x;
    const editor_y = layout.editor.y;
    const mouse_shell = app_shell.MousePos{ .x = mouse.x, .y = mouse.y };
    const hscroll_handled = widget.handleHorizontalScrollbarInput(
        shell,
        editor_x,
        editor_y,
        layout.editor.width,
        layout.editor.height,
        mouse_shell,
        hscroll_dragging,
        hscroll_grab_offset,
        input_batch,
    );
    const vscroll_handled = widget.handleVerticalScrollbarInput(
        shell,
        editor_x,
        editor_y,
        layout.editor.width,
        layout.editor.height,
        mouse_shell,
        vscroll_dragging,
        vscroll_grab_offset,
        input_batch,
    );
    return hscroll_handled or vscroll_handled;
}

pub fn handleMouseSelectionInput(
    widget: *EditorWidget,
    shell: *app_shell.Shell,
    layout: layout_types.WidgetLayout,
    mouse: input_types.MousePos,
    input_batch: *input_types.InputBatch,
    scrollbar_blocking: bool,
    selection: SelectionState,
) SelectionResult {
    const log = app_logger.logger("editor.input");
    var out: SelectionResult = .{};
    const editor_x = layout.editor.x;
    const editor_y = layout.editor.y;
    const in_editor = mouse.x >= editor_x and mouse.x <= editor_x + layout.editor.width and
        mouse.y >= editor_y and mouse.y <= editor_y + layout.editor.height;
    const alt = input_batch.mods.alt;

    if (!scrollbar_blocking and input_batch.mousePressed(.left) and in_editor) {
        if (widget.cursorFromMouse(shell, editor_x, editor_y, layout.editor.width, layout.editor.height, mouse.x, mouse.y, false)) |pos| {
            widget.editor.setCursor(pos.line, pos.col);
            widget.editor.selection = null;
            widget.editor.clearSelections();
            selection.dragging.* = true;
            selection.drag_start.* = pos;
            selection.drag_rect.* = alt;
            if (alt) {
                widget.editor.expandRectSelection(pos.line, pos.line, pos.col, pos.col) catch |err| {
                    log.logf(.warning, 
                        "expandRectSelection start failed line={d} col={d} err={s}",
                        .{ pos.line, pos.col, @errorName(err) },
                    );
                };
            } else {
                widget.editor.selection = .{ .start = pos, .end = pos };
            }
            out.needs_redraw = true;
            out.note_input = true;
        }
    }

    if (!scrollbar_blocking and selection.dragging.* and input_batch.mouseDown(.left)) {
        if (widget.cursorFromMouse(shell, editor_x, editor_y, layout.editor.width, layout.editor.height, mouse.x, mouse.y, true)) |pos| {
            widget.editor.setCursorNoClear(pos.line, pos.col);
            if (selection.drag_rect.*) {
                widget.editor.clearSelections();
                const start_line = @min(selection.drag_start.line, pos.line);
                const end_line = @max(selection.drag_start.line, pos.line);
                const start_col = @min(selection.drag_start.col, pos.col);
                const end_col = @max(selection.drag_start.col, pos.col);
                widget.editor.expandRectSelection(start_line, end_line, start_col, end_col) catch |err| {
                    log.logf(.warning, 
                        "expandRectSelection drag failed start={d}:{d} end={d}:{d} err={s}",
                        .{ start_line, start_col, end_line, end_col, @errorName(err) },
                    );
                };
                widget.editor.selection = null;
            } else {
                widget.editor.selection = .{ .start = selection.drag_start.*, .end = pos };
                widget.editor.clearSelections();
            }
            out.needs_redraw = true;
            out.note_input = true;
        }
    }

    if (selection.dragging.* and input_batch.mouseReleased(.left)) {
        selection.dragging.* = false;
        if (!selection.drag_rect.*) {
            if (widget.editor.selection) |sel| {
                if (sel.start.offset == sel.end.offset) {
                    widget.editor.selection = null;
                }
            }
        } else if (widget.editor.selectionCount() == 0) {
            widget.editor.selection = null;
        }
        out.needs_redraw = true;
    }

    return out;
}
