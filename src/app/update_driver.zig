const shared_types = @import("../types/mod.zig");
const app_shell = @import("../app_shell.zig");

const input_types = shared_types.input;
const Shell = app_shell.Shell;

pub const Prelude = struct {
    now: f64,
    suppress_terminal_shortcuts: bool,
    terminal_close_modal_active: bool,
};

pub const Frame = struct {
    layout: shared_types.layout.WidgetLayout,
    mouse: input_types.MousePos,
    term_y: f32,
};

pub const Hooks = struct {
    handle_update_prelude_frame: *const fn (*anyopaque, *Shell, *input_types.InputBatch) anyerror!?Prelude,
    handle_post_preinput_frame: *const fn (*anyopaque, *Shell, *input_types.InputBatch, f64) anyerror!Frame,
    handle_interactive_frame: *const fn (
        *anyopaque,
        *Shell,
        Frame,
        *input_types.InputBatch,
        bool,
        bool,
        f64,
    ) anyerror!void,
};

pub fn handle(
    shell: *Shell,
    input_batch: *input_types.InputBatch,
    ctx: *anyopaque,
    hooks: Hooks,
) !void {
    const prelude = (try hooks.handle_update_prelude_frame(ctx, shell, input_batch)) orelse return;
    const frame = try hooks.handle_post_preinput_frame(ctx, shell, input_batch, prelude.now);
    try hooks.handle_interactive_frame(
        ctx,
        shell,
        frame,
        input_batch,
        prelude.suppress_terminal_shortcuts,
        prelude.terminal_close_modal_active,
        prelude.now,
    );
}
