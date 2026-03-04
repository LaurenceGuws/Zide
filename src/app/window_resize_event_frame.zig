const app_shell = @import("../app_shell.zig");

const Shell = app_shell.Shell;

pub const Result = struct {
    needs_redraw: bool = false,
    ui_scale_changed: bool = false,
};

pub fn handle(
    shell: *Shell,
    window_resize_pending: *bool,
    window_resize_last_time: *f64,
) !Result {
    var out: Result = .{};
    if (!app_shell.isWindowResized()) return out;
    _ = shell.refreshWindowMetrics("window-event");
    out.ui_scale_changed = try shell.refreshUiScale();
    window_resize_pending.* = true;
    window_resize_last_time.* = app_shell.getTime();
    out.needs_redraw = true;
    return out;
}
