const app_draw_frame_runtime = @import("draw_frame_runtime.zig");
const app_frame_render_idle_runtime = @import("frame_render_idle_runtime.zig");
const app_metrics_log_runtime = @import("metrics_log_runtime.zig");
const app_terminal_close_confirm_active_runtime = @import("terminal/terminal_close_confirm_active_runtime.zig");
const app_ui_layout_runtime = @import("ui_layout_runtime.zig");
const shared_types = @import("../types/mod.zig");

const layout_types = shared_types.layout;

fn computeLayout(state: anytype, width: f32, height: f32) layout_types.WidgetLayout {
    return app_ui_layout_runtime.computeLayout(state, width, height);
}

fn applyCurrentTabBarWidthMode(state: anytype) void {
    app_ui_layout_runtime.applyCurrentTabBarWidthMode(state);
}

fn terminalCloseConfirmActive(state: anytype) bool {
    return app_terminal_close_confirm_active_runtime.reconcile(state);
}

fn drawFrame(state: anytype) void {
    const State = @TypeOf(state.*);
    app_draw_frame_runtime.draw(
        state,
        state.shell,
        @ptrCast(state),
        .{
            .compute_layout = struct {
                fn inner(inner_raw: *anyopaque, width: f32, height: f32) layout_types.WidgetLayout {
                    const inner_state: *State = @ptrCast(@alignCast(inner_raw));
                    return computeLayout(inner_state, width, height);
                }
            }.inner,
            .apply_current_tab_bar_width_mode = struct {
                fn inner(inner_raw: *anyopaque) void {
                    const inner_state: *State = @ptrCast(@alignCast(inner_raw));
                    applyCurrentTabBarWidthMode(inner_state);
                }
            }.inner,
            .terminal_close_confirm_active = struct {
                fn inner(inner_raw: *anyopaque) bool {
                    const inner_state: *State = @ptrCast(@alignCast(inner_raw));
                    return terminalCloseConfirmActive(inner_state);
                }
            }.inner,
        },
    );
}

pub fn handle(
    state: anytype,
    input_batch: *shared_types.input.InputBatch,
    poll_ms: f64,
    build_ms: f64,
    update_ms: f64,
) void {
    const State = @TypeOf(state.*);
    app_frame_render_idle_runtime.handle(
        state,
        @ptrCast(state),
        input_batch,
        poll_ms,
        build_ms,
        update_ms,
        .{
            .draw = struct {
                fn cb(cb_raw: *anyopaque) void {
                    const cb_state: *State = @ptrCast(@alignCast(cb_raw));
                    drawFrame(cb_state);
                }
            }.cb,
            .maybe_log_metrics = struct {
                fn cb(cb_raw: *anyopaque, at: f64) void {
                    const cb_state: *State = @ptrCast(@alignCast(cb_raw));
                    app_metrics_log_runtime.maybeLog(cb_state, at);
                }
            }.cb,
        },
    );
}
