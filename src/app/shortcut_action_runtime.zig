const app_bootstrap = @import("bootstrap.zig");
const app_logger = @import("../app_logger.zig");
const app_modes = @import("modes/mod.zig");
const app_shell = @import("../app_shell.zig");
const input_actions = @import("../input/input_actions.zig");

const Logger = app_logger.Logger;
const Shell = app_shell.Shell;

pub const Result = struct {
    handled: bool = false,
    handled_zoom: bool = false,
    needs_redraw: bool = false,
    note_input: bool = false,
};

pub const Hooks = struct {
    new_editor: *const fn (*anyopaque) anyerror!void,
    new_terminal: *const fn (*anyopaque) anyerror!void,
    handle_terminal_shortcut_intent: *const fn (*anyopaque, app_modes.ide.TerminalShortcutIntent, f64) anyerror!bool,
};

pub fn handle(
    kind: input_actions.ActionKind,
    app_mode: app_bootstrap.AppMode,
    show_terminal: *bool,
    terminal_count: usize,
    shell: *Shell,
    now: f64,
    zoom_log: Logger,
    ctx: *anyopaque,
    hooks: Hooks,
) !Result {
    var out: Result = .{};
    switch (kind) {
        .new_editor => {
            if (app_modes.ide.canCreateEditorFromShortcut(app_mode)) {
                try hooks.new_editor(ctx);
                out.handled = true;
                out.needs_redraw = true;
                out.note_input = true;
                return out;
            }
        },
        .zoom_in => {
            const prev_zoom = shell.userZoomFactor();
            const prev_target = shell.userZoomTargetFactor();
            const changed = shell.queueUserZoom(0.1, now);
            if (changed) out.note_input = true;
            if (zoom_log.enabled_file or zoom_log.enabled_console) {
                zoom_log.logf(.info, 
                    "action=zoom_in changed={d} zoom={d:.3}->{d:.3} target={d:.3}->{d:.3} base_font={d:.2} layout_font={d:.2} ui_scale={d:.3} render_scale={d:.3} term_cell={d:.2}x{d:.2}",
                    .{
                        @intFromBool(changed),
                        prev_zoom,
                        shell.userZoomFactor(),
                        prev_target,
                        shell.userZoomTargetFactor(),
                        shell.baseFontSize(),
                        shell.fontSize(),
                        shell.uiScaleFactor(),
                        shell.renderScaleFactor(),
                        shell.terminalCellWidth(),
                        shell.terminalCellHeight(),
                    },
                );
            }
            out.handled_zoom = true;
        },
        .zoom_out => {
            const prev_zoom = shell.userZoomFactor();
            const prev_target = shell.userZoomTargetFactor();
            const changed = shell.queueUserZoom(-0.1, now);
            if (changed) out.note_input = true;
            if (zoom_log.enabled_file or zoom_log.enabled_console) {
                zoom_log.logf(.info, 
                    "action=zoom_out changed={d} zoom={d:.3}->{d:.3} target={d:.3}->{d:.3} base_font={d:.2} layout_font={d:.2} ui_scale={d:.3} render_scale={d:.3} term_cell={d:.2}x{d:.2}",
                    .{
                        @intFromBool(changed),
                        prev_zoom,
                        shell.userZoomFactor(),
                        prev_target,
                        shell.userZoomTargetFactor(),
                        shell.baseFontSize(),
                        shell.fontSize(),
                        shell.uiScaleFactor(),
                        shell.renderScaleFactor(),
                        shell.terminalCellWidth(),
                        shell.terminalCellHeight(),
                    },
                );
            }
            out.handled_zoom = true;
        },
        .zoom_reset => {
            const prev_zoom = shell.userZoomFactor();
            const prev_target = shell.userZoomTargetFactor();
            const changed = shell.resetUserZoomTarget(now);
            if (changed) out.note_input = true;
            if (zoom_log.enabled_file or zoom_log.enabled_console) {
                zoom_log.logf(.info, 
                    "action=zoom_reset changed={d} zoom={d:.3}->{d:.3} target={d:.3}->{d:.3} base_font={d:.2} layout_font={d:.2} ui_scale={d:.3} render_scale={d:.3} term_cell={d:.2}x{d:.2}",
                    .{
                        @intFromBool(changed),
                        prev_zoom,
                        shell.userZoomFactor(),
                        prev_target,
                        shell.userZoomTargetFactor(),
                        shell.baseFontSize(),
                        shell.fontSize(),
                        shell.uiScaleFactor(),
                        shell.renderScaleFactor(),
                        shell.terminalCellWidth(),
                        shell.terminalCellHeight(),
                    },
                );
            }
            out.handled_zoom = true;
        },
        .toggle_terminal => {
            if (app_modes.ide.canToggleTerminal(app_mode)) {
                if (show_terminal.*) {
                    show_terminal.* = false;
                } else {
                    if (terminal_count == 0) {
                        try hooks.new_terminal(ctx);
                    }
                    show_terminal.* = true;
                }
                out.handled = true;
                out.needs_redraw = true;
                out.note_input = true;
                return out;
            }
        },
        else => {},
    }

    if (app_modes.ide.terminalShortcutIntentForAction(kind)) |intent| {
        if (try hooks.handle_terminal_shortcut_intent(ctx, intent, now)) {
            out.handled = true;
            return out;
        }
    }
    return out;
}
