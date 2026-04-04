const app_shell = @import("../app_shell.zig");

const Shell = app_shell.Shell;

pub const Result = struct {
    needs_redraw: bool = false,
    ui_scale_changed: bool = false,
    changes: app_shell.WindowChangeMask = .{},
};

pub fn handle(
    shell: *Shell,
    window_resize_pending: *bool,
    window_resize_last_time: *f64,
) !Result {
    var out: Result = .{};
    out.changes = app_shell.windowChanges();
    if (!out.changes.affectsWindowRefresh()) return out;
    const refresh = try shell.refreshWindowState("window-event", out.changes);
    out.ui_scale_changed = refresh.needsUiLayoutRefresh();
    if (refresh.needsDeferredTerminalResize()) {
        window_resize_pending.* = true;
        window_resize_last_time.* = app_shell.getTime();
    }
    out.needs_redraw = refresh.needsRedraw();
    return out;
}
