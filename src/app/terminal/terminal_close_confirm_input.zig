const app_modes = @import("../modes/mod.zig");
const shared_types = @import("../../types/mod.zig");

const input_actions = @import("../../input/input_actions.zig");
const layout_types = shared_types.layout;

pub fn handleInput(
    actions: []const input_actions.InputAction,
    input_batch: *shared_types.input.InputBatch,
    layout: layout_types.WidgetLayout,
    ui_scale: f32,
    now: f64,
    ctx: *anyopaque,
    apply_fn: *const fn (*anyopaque, app_modes.ide.TerminalCloseConfirmDecision, f64) anyerror!bool,
) !bool {
    const modal = app_modes.ide.terminalCloseConfirmModalLayout(layout, ui_scale);
    const decision = app_modes.ide.decideTerminalCloseConfirmInput(
        actions,
        input_batch,
        modal,
    );
    return apply_fn(ctx, decision, now);
}
