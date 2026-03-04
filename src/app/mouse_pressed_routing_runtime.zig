const app_modes = @import("modes/mod.zig");
const shared_types = @import("../types/mod.zig");
const widgets = @import("../ui/widgets.zig");

const layout_types = shared_types.layout;
const input_types = shared_types.input;
const TabBar = widgets.TabBar;
const ActiveMode = app_modes.ide.ActiveMode;

pub const Result = struct {
    needs_redraw: bool = false,
    note_input: bool = false,
};

pub const IdeHooks = struct {
    route_editor_activate_by_index: *const fn (ctx: *anyopaque, index: usize) anyerror!void,
    sync_mode_adapters: *const fn (ctx: *anyopaque) anyerror!void,
};

pub fn handleIde(
    tab_bar: *TabBar,
    options_bar_height: f32,
    layout: layout_types.WidgetLayout,
    mouse: input_types.MousePos,
    term_y: f32,
    show_terminal: bool,
    active_tab: *usize,
    active_kind: *ActiveMode,
    ctx: *anyopaque,
    hooks: IdeHooks,
) !Result {
    var out: Result = .{};
    const tab_bar_y = options_bar_height;
    _ = tab_bar.beginDrag(mouse.x, mouse.y, layout.side_nav.width, tab_bar_y, layout.tab_bar.width);
    if (tab_bar.handleClick(mouse.x, mouse.y, layout.side_nav.width, tab_bar_y, layout.tab_bar.width)) {
        active_tab.* = tab_bar.active_index;
        try hooks.route_editor_activate_by_index(ctx, active_tab.*);
        out.needs_redraw = true;
        out.note_input = true;
    }

    const editor_x = layout.editor.x;
    const editor_y = layout.editor.y;
    const in_editor = mouse.x >= editor_x and mouse.x <= editor_x + layout.editor.width and
        mouse.y >= editor_y and mouse.y <= editor_y + layout.editor.height;

    const in_terminal = layout.terminal.height > 0 and mouse.y >= term_y and mouse.y <= term_y + layout.terminal.height;

    if (in_terminal and show_terminal) {
        if (active_kind.* != .terminal) {
            active_kind.* = .terminal;
            try hooks.sync_mode_adapters(ctx);
            out.needs_redraw = true;
            out.note_input = true;
        }
    } else if (in_editor) {
        if (active_kind.* != .editor) {
            active_kind.* = .editor;
            try hooks.sync_mode_adapters(ctx);
            out.needs_redraw = true;
            out.note_input = true;
        }
    }

    return out;
}

pub const TerminalHooks = struct {
    sync_mode_adapters: *const fn (ctx: *anyopaque) anyerror!void,
    route_terminal_activate: *const fn (ctx: *anyopaque) anyerror!void,
};

pub fn handleTerminal(
    tab_bar: *TabBar,
    layout: layout_types.WidgetLayout,
    mouse: input_types.MousePos,
    terminal_bar_visible: bool,
    active_kind: *ActiveMode,
    ctx: *anyopaque,
    hooks: TerminalHooks,
) !Result {
    if (terminal_bar_visible) {
        _ = tab_bar.beginDrag(mouse.x, mouse.y, layout.tab_bar.x, layout.tab_bar.y, layout.tab_bar.width);
    }
    if (active_kind.* != .terminal) {
        active_kind.* = .terminal;
        try hooks.sync_mode_adapters(ctx);
    }
    try hooks.route_terminal_activate(ctx);
    return .{};
}
