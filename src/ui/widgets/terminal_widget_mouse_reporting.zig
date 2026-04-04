const terminal_runtime = @import("../../terminal/core/terminal_runtime.zig");
const session_input = @import("../../terminal/core/session/input.zig");
const terminal_types = @import("../../terminal/model/types.zig");
const shared_types = @import("../../types/mod.zig");

pub const MouseReportingParams = struct {
    mouse: shared_types.input.MousePos,
    view: shared_types.layout.TerminalViewGeometry,
    mod: terminal_types.Modifier,
};

pub fn handleMouseReporting(
    self: anytype,
    params: MouseReportingParams,
    input_batch: *shared_types.input.InputBatch,
    skip_mouse_click: bool,
    wheel_steps: i32,
) !bool {
    var handled = false;
    if (params.view.rows == 0 or params.view.cols == 0) return false;

    self.session.lock();
    defer self.session.unlock();

    var buttons_down: u8 = 0;
    if (input_batch.mouseDown(.left)) buttons_down |= 1;
    if (input_batch.mouseDown(.middle)) buttons_down |= 2;
    if (input_batch.mouseDown(.right)) buttons_down |= 4;

    var col: usize = 0;
    if (params.mouse.x > params.view.origin_x) col = @as(usize, @intFromFloat((params.mouse.x - params.view.origin_x) / params.view.cell_width));
    var row: usize = 0;
    if (params.mouse.y > params.view.origin_y) row = @as(usize, @intFromFloat((params.mouse.y - params.view.origin_y) / params.view.cell_height));
    row = @min(row, params.view.rows - 1);
    col = @min(col, params.view.cols - 1);
    const grid_px_w = @as(u32, @intCast(params.view.cols)) * @as(u32, @intFromFloat(params.view.cell_width));
    const grid_px_h = @as(u32, @intCast(params.view.rows)) * @as(u32, @intFromFloat(params.view.cell_height));
    const raw_px_x_f = @max(0.0, params.mouse.x - params.view.origin_x);
    const raw_px_y_f = @max(0.0, params.mouse.y - params.view.origin_y);
    var pixel_x: u32 = @intFromFloat(raw_px_x_f);
    var pixel_y: u32 = @intFromFloat(raw_px_y_f);
    if (grid_px_w > 0) pixel_x = @min(pixel_x, grid_px_w - 1);
    if (grid_px_h > 0) pixel_y = @min(pixel_y, grid_px_h - 1);

    if (wheel_steps != 0) {
        var remaining = wheel_steps;
        while (remaining != 0) {
            const button: terminal_types.MouseButton = if (remaining > 0) .wheel_up else .wheel_down;
            if (try session_input.reportMouseEvent(self.session, .{
                .kind = .wheel,
                .button = button,
                .row = row,
                .col = col,
                .pixel_x = pixel_x,
                .pixel_y = pixel_y,
                .mod = params.mod,
                .buttons_down = buttons_down,
            })) {
                handled = true;
            }
            remaining += if (remaining > 0) -1 else 1;
        }
    }
    if (input_batch.mousePressed(.left) and !skip_mouse_click) {
        if (try session_input.reportMouseEvent(self.session, .{
            .kind = .press,
            .button = .left,
            .row = row,
            .col = col,
            .pixel_x = pixel_x,
            .pixel_y = pixel_y,
            .mod = params.mod,
            .buttons_down = buttons_down,
        })) handled = true;
    }
    if (input_batch.mousePressed(.middle)) {
        if (try session_input.reportMouseEvent(self.session, .{
            .kind = .press,
            .button = .middle,
            .row = row,
            .col = col,
            .pixel_x = pixel_x,
            .pixel_y = pixel_y,
            .mod = params.mod,
            .buttons_down = buttons_down,
        })) handled = true;
    }
    if (input_batch.mousePressed(.right)) {
        if (try session_input.reportMouseEvent(self.session, .{
            .kind = .press,
            .button = .right,
            .row = row,
            .col = col,
            .pixel_x = pixel_x,
            .pixel_y = pixel_y,
            .mod = params.mod,
            .buttons_down = buttons_down,
        })) handled = true;
    }
    if (input_batch.mouseReleased(.left)) {
        if (try session_input.reportMouseEvent(self.session, .{
            .kind = .release,
            .button = .left,
            .row = row,
            .col = col,
            .pixel_x = pixel_x,
            .pixel_y = pixel_y,
            .mod = params.mod,
            .buttons_down = buttons_down,
        })) handled = true;
    }
    if (input_batch.mouseReleased(.middle)) {
        if (try session_input.reportMouseEvent(self.session, .{
            .kind = .release,
            .button = .middle,
            .row = row,
            .col = col,
            .pixel_x = pixel_x,
            .pixel_y = pixel_y,
            .mod = params.mod,
            .buttons_down = buttons_down,
        })) handled = true;
    }
    if (input_batch.mouseReleased(.right)) {
        if (try session_input.reportMouseEvent(self.session, .{
            .kind = .release,
            .button = .right,
            .row = row,
            .col = col,
            .pixel_x = pixel_x,
            .pixel_y = pixel_y,
            .mod = params.mod,
            .buttons_down = buttons_down,
        })) handled = true;
    }
    if (try session_input.reportMouseEvent(self.session, .{
        .kind = .move,
        .button = .none,
        .row = row,
        .col = col,
        .pixel_x = pixel_x,
        .pixel_y = pixel_y,
        .mod = params.mod,
        .buttons_down = buttons_down,
    })) handled = true;

    return handled;
}
