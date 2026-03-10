const app_modes = @import("../modes/mod.zig");
const shared_types = @import("../../types/mod.zig");
const widgets = @import("../../ui/widgets.zig");

const layout_types = shared_types.layout;
const input_types = shared_types.input;
const TabBar = widgets.TabBar;

pub const Result = struct {
    needs_redraw: bool = false,
    note_input: bool = false,
};

pub const TerminalHooks = struct {
    apply_terminal_action: *const fn (ctx: *anyopaque, action: app_modes.shared.actions.TabAction) anyerror!void,
    route_activate_by_tab_id: *const fn (ctx: *anyopaque, tab_id: ?u64) anyerror!void,
    focus_terminal_tab_index: *const fn (ctx: *anyopaque, index: usize) bool,
};

pub fn handleTerminal(
    tab_bar: *TabBar,
    input_batch: *input_types.InputBatch,
    layout: layout_types.WidgetLayout,
    mouse: input_types.MousePos,
    terminal_bar_visible: bool,
    ctx: *anyopaque,
    hooks: TerminalHooks,
) !Result {
    var out: Result = .{};
    const drag_frame = app_modes.ide.processTabDragFrame(
        tab_bar,
        input_batch,
        mouse,
        layout.tab_bar.x,
        layout.tab_bar.y,
        layout.tab_bar.width,
        terminal_bar_visible,
    );
    if (drag_frame.updated) {
        out.needs_redraw = true;
        out.note_input = true;
    }
    if (drag_frame.release) |drag_end| {
        const release_plan = app_modes.ide.terminalTabDragReleasePlan(drag_end);
        if (release_plan.intent) |intent| {
            try hooks.apply_terminal_action(ctx, intent);
        }
        if (release_plan.handle_click) {
            if (tab_bar.handleClick(mouse.x, mouse.y, layout.tab_bar.x, layout.tab_bar.y, layout.tab_bar.width)) {
                try hooks.route_activate_by_tab_id(ctx, tab_bar.terminalTabIdAtVisual(tab_bar.active_index));
                if (hooks.focus_terminal_tab_index(ctx, tab_bar.active_index)) {
                    out.needs_redraw = true;
                    out.note_input = true;
                }
            }
        }
        if (release_plan.mark_redraw) {
            out.needs_redraw = true;
            out.note_input = true;
        }
    }
    return out;
}

pub const IdeHooks = struct {
    apply_editor_action: *const fn (ctx: *anyopaque, action: app_modes.shared.actions.TabAction) anyerror!void,
};

pub fn handleIde(
    tab_bar: *TabBar,
    input_batch: *input_types.InputBatch,
    layout: layout_types.WidgetLayout,
    mouse: input_types.MousePos,
    active_tab: *usize,
    ctx: *anyopaque,
    hooks: IdeHooks,
) !Result {
    var out: Result = .{};
    const drag_frame = app_modes.ide.processTabDragFrame(
        tab_bar,
        input_batch,
        mouse,
        layout.tab_bar.x,
        layout.tab_bar.y,
        layout.tab_bar.width,
        true,
    );
    if (drag_frame.updated) {
        out.needs_redraw = true;
        out.note_input = true;
    }
    if (drag_frame.release) |drag_end| {
        const release_plan = app_modes.ide.ideEditorTabDragReleasePlan(drag_end);
        if (release_plan.intent) |intent| {
            try hooks.apply_editor_action(ctx, intent);
            if (release_plan.sync_active_tab) {
                active_tab.* = tab_bar.active_index;
            }
            if (release_plan.mark_redraw) {
                out.needs_redraw = true;
                out.note_input = true;
            }
        }
    }
    return out;
}
