const app_bootstrap = @import("../bootstrap.zig");
const app_modes = @import("../modes/mod.zig");
const shared_types = @import("../../types/mod.zig");

const layout_types = shared_types.layout;
const input_types = shared_types.input;

pub const Result = struct {
    needs_redraw: bool = false,
    note_input: bool = false,
    new_terminal_height: ?f32 = null,
};

pub fn handle(
    app_mode: app_bootstrap.AppMode,
    show_terminal: bool,
    input_batch: *input_types.InputBatch,
    layout: layout_types.WidgetLayout,
    height: f32,
    options_bar_height: f32,
    tab_bar_height: f32,
    status_bar_height: f32,
    resizing_terminal: *bool,
    resize_start_y: *f32,
    resize_start_height: *f32,
    current_terminal_height: f32,
) Result {
    var out: Result = .{};
    if (!app_modes.ide.canResizeTerminalSplit(app_mode, show_terminal)) return out;

    const mouse = input_batch.mouse_pos;
    const mouse_down = input_batch.mouseDown(.left);
    const separator_y = layout.terminal.y;
    const hit_zone: f32 = 6;
    const over_separator = mouse.y >= separator_y - hit_zone and mouse.y <= separator_y + hit_zone;
    const max_terminal_h = @max(0, height - options_bar_height - tab_bar_height - status_bar_height);

    if (!resizing_terminal.* and mouse_down and over_separator) {
        resizing_terminal.* = true;
        resize_start_y.* = mouse.y;
        resize_start_height.* = layout.terminal.height;
        out.needs_redraw = true;
        out.note_input = true;
    } else if (resizing_terminal.* and mouse_down) {
        const delta = mouse.y - resize_start_y.*;
        const min_terminal_h: f32 = 80;
        const new_height = @max(min_terminal_h, @min(resize_start_height.* - delta, max_terminal_h));
        if (new_height != current_terminal_height) {
            out.new_terminal_height = new_height;
            out.needs_redraw = true;
            out.note_input = true;
        }
    } else if (resizing_terminal.* and !mouse_down) {
        resizing_terminal.* = false;
    }

    return out;
}
