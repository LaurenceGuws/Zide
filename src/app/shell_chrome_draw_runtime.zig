const app_modes = @import("modes/mod.zig");
const mode_build = @import("mode_build.zig");
const widgets_common = @import("../ui/widgets/common.zig");
const shared_types = @import("../types/mod.zig");

const layout_types = shared_types.layout;

pub fn draw(state: anytype, shell: anytype, layout: layout_types.WidgetLayout, tab_tooltip: ?widgets_common.Tooltip) void {
    if (app_modes.ide.canToggleTerminal(state.app_mode)) {
        shell.setTheme(state.app_theme);
        state.side_nav.draw(shell, layout.side_nav.height, layout.side_nav.y);
    }

    if (comptime mode_build.focused_mode != .terminal) {
        if (app_modes.ide.canToggleTerminal(state.app_mode) and state.editors.items.len > 0) {
            shell.setTheme(state.app_theme);
            const editor_idx = @min(state.active_tab, state.editors.items.len - 1);
            const editor = state.editors.items[editor_idx];
            state.status_bar.draw(
                shell,
                layout.window.width,
                layout.status_bar.y,
                state.mode,
                editor.file_path,
                editor.cursor.line,
                editor.cursor.col,
                editor.modified,
                if (state.search_panel.active)
                    .{
                        .active = true,
                        .query = state.search_panel.query.items,
                        .match_count = editor.searchMatches().len,
                        .active_index = editor.searchActiveIndex(),
                    }
                else
                    null,
            );
        }
    }

    if (tab_tooltip) |tip| {
        widgets_common.drawTooltip(shell, tip.text, tip.x, tip.y);
    }
}
