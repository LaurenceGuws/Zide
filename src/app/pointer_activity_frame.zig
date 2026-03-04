const shared_types = @import("../types/mod.zig");
const app_shell = @import("../app_shell.zig");

const layout_types = shared_types.layout;
const input_types = shared_types.input;

pub const Result = struct {
    needs_redraw: bool = false,
    note_input: bool = false,
};

pub fn handle(
    show_terminal: bool,
    input_batch: *input_types.InputBatch,
    layout: layout_types.WidgetLayout,
    mouse: input_types.MousePos,
    now: f64,
    last_mouse_pos: *app_shell.MousePos,
    last_mouse_redraw_time: *f64,
    last_ctrl_down: *bool,
) Result {
    var out: Result = .{};
    const mouse_down = input_batch.mouseDown(.left);
    const mouse_moved = mouse.x != last_mouse_pos.x or mouse.y != last_mouse_pos.y;
    const wheel = input_batch.scroll.y;
    const mouse_pressed = input_batch.mousePressed(.left) or input_batch.mousePressed(.right);
    const has_mouse_action = mouse_pressed or wheel != 0 or mouse_down;

    const terminal_visible = show_terminal and layout.terminal.height > 0;
    const term_y = layout.terminal.y;
    const in_terminal_area = terminal_visible and mouse.y >= term_y;
    const ctrl_down = input_batch.mods.ctrl;

    if (has_mouse_action) {
        out.needs_redraw = true;
        out.note_input = true;
    } else if (mouse_moved) {
        if (!in_terminal_area) {
            const interval: f64 = 1.0 / 60.0;
            if (now - last_mouse_redraw_time.* >= interval) {
                out.needs_redraw = true;
                last_mouse_redraw_time.* = now;
            }
        }
    }
    if (in_terminal_area and (ctrl_down != last_ctrl_down.* or (ctrl_down and mouse_moved))) {
        const interval: f64 = 1.0 / 60.0;
        if (now - last_mouse_redraw_time.* >= interval) {
            out.needs_redraw = true;
            last_mouse_redraw_time.* = now;
        }
    }
    if (mouse_moved) {
        last_mouse_pos.* = .{ .x = mouse.x, .y = mouse.y };
    }
    last_ctrl_down.* = ctrl_down;
    return out;
}
