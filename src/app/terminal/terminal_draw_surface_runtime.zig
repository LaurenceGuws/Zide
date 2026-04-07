const app_modes = @import("../modes/mod.zig");
const app_terminal_active_widget = @import("terminal_active_widget.zig");
const app_terminal_progress_runtime = @import("terminal_progress_runtime.zig");
const app_terminal_scrollbar_runtime = @import("terminal_scrollbar_runtime.zig");
const app_terminal_surface_gate = @import("terminal_surface_gate.zig");
const renderer_surface_host = @import("../../ui/renderer/renderer_surface_host.zig");
const host_queries = @import("../../terminal/core/session/host_queries.zig");
const shared_types = @import("../../types/mod.zig");

const layout_types = shared_types.layout;

pub fn draw(state: anytype, shell: anytype, layout: layout_types.WidgetLayout) void {
    if (!app_terminal_surface_gate.hasVisibleTerminalTabs(state.app_mode, state.show_terminal, state.terminal_workspace, state.terminals.items.len)) return;

    const term_y = layout.terminal.y;

    if (app_modes.ide.shouldRenderTerminalSeparator(state.app_mode)) {
        shell.setTheme(state.app_theme);
        renderer_surface_host.drawRect(shell.rendererPtr(), @intFromFloat(layout.terminal.x), @intFromFloat(term_y), @intFromFloat(layout.terminal.width), 2, state.app_theme.ui_border);
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
        const progress = host_queries.currentProgress(term_widget.session);
        if (progress.active()) {
            app_terminal_progress_runtime.drawActiveTabProgress(
                shell,
                layout.terminal.x,
                term_y,
                layout.terminal.width,
                progress,
            );
        }
        app_terminal_scrollbar_runtime.draw(
            term_widget,
            shell,
            layout.terminal.x,
            term_y + term_offset_y,
            layout.terminal.width,
            term_height,
            state.last_input.mouse_pos,
            state.terminal_scrollbar_dragging,
        );
        term_widget.stagePresentationFeedback(draw_outcome);
    }
}
