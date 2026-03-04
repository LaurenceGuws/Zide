pub const Input = struct {
    cursor_visible: bool,
    cursor_blink: bool,
    scroll_offset: usize,
};

pub const Result = struct {
    has_active_terminal: bool = false,
    blink_armed: bool = false,
    blink_armed_changed: bool = false,
    blink_on_changed: bool = false,
    blink_on: bool = false,
    needs_redraw: bool = false,
};

pub fn handle(
    cache: ?Input,
    now: f64,
    last_cursor_blink_armed: *bool,
    last_cursor_blink_on: *bool,
) Result {
    var out: Result = .{};
    if (cache == null) return out;
    const c = cache.?;
    out.has_active_terminal = true;
    const blink_armed = c.cursor_visible and c.cursor_blink and c.scroll_offset == 0;
    out.blink_armed = blink_armed;
    if (blink_armed != last_cursor_blink_armed.*) {
        last_cursor_blink_armed.* = blink_armed;
        out.blink_armed_changed = true;
    }
    if (blink_armed) {
        const period: f64 = 0.5;
        const phase = @mod(now, period * 2.0);
        const blink_on = phase < period;
        out.blink_on = blink_on;
        if (blink_on != last_cursor_blink_on.*) {
            last_cursor_blink_on.* = blink_on;
            out.blink_on_changed = true;
            out.needs_redraw = true;
        }
    }
    return out;
}
