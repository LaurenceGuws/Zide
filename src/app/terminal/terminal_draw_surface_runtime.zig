const app_modes = @import("../modes/mod.zig");
const app_terminal_active_widget = @import("terminal_active_widget.zig");
const app_terminal_surface_gate = @import("terminal_surface_gate.zig");
const shared_types = @import("../../types/mod.zig");

const layout_types = shared_types.layout;

pub fn draw(state: anytype, shell: anytype, layout: layout_types.WidgetLayout) void {
    if (!app_terminal_surface_gate.hasVisibleTerminalTabs(state.app_mode, state.show_terminal, state.terminal_workspace, state.terminals.items.len)) return;

    const term_y = layout.terminal.y;

    if (app_modes.ide.shouldRenderTerminalSeparator(state.app_mode)) {
        shell.setTheme(state.app_theme);
        shell.drawRect(@intFromFloat(layout.terminal.x), @intFromFloat(term_y), @intFromFloat(layout.terminal.width), 2, state.app_theme.ui_border);
    }

    shell.setTheme(state.terminal_theme);
    if (app_terminal_active_widget.resolveActive(
        state.app_mode,
        &state.terminal_workspace,
        state.terminals.items.len,
        state.terminal_widgets.items,
    )) |term_widget| {
        const strip = app_modes.ide.terminalStrip(state.app_mode, layout.terminal.height);
        const term_offset_y: f32 = strip.offset_y;
        const term_height = strip.draw_height;
        if (layout.terminal.width > 0 and term_height > 0) {
            shell.beginClip(
                @intFromFloat(layout.terminal.x),
                @intFromFloat(term_y + term_offset_y),
                @intFromFloat(layout.terminal.width),
                @intFromFloat(term_height),
            );
        }
        const draw_outcome = term_widget.draw(shell, layout.terminal.x, term_y + term_offset_y, layout.terminal.width, term_height, state.last_input);
        if (layout.terminal.width > 0 and term_height > 0) {
            shell.endClip();
        }
        state.pending_terminal_presentation_feedback = .{
            .session = term_widget.session,
            .feedback = draw_outcome,
        };
    }
}

pub fn flushPresentationFeedback(state: anytype, submission: anytype) void {
    if (state.pending_terminal_presentation_feedback) |pending| {
        if (submission.succeeded) {
            pending.session.finishFramePresentation(pending.feedback);
            state.last_terminal_submission_sequence = submission.sequence;
        }
        state.pending_terminal_presentation_feedback = null;
    }
}
