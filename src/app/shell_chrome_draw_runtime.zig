const app_modes = @import("modes/mod.zig");
const app_top_bar_frame_runtime = @import("top_bar_frame_runtime.zig");
const app_active_editor_runtime = @import("editor/active_editor_runtime.zig");
const mode_build = @import("mode_build.zig");
const app_path_prompt_state = @import("editor/path_prompt_state.zig");
const widgets_common = @import("../ui/widgets/common.zig");
const shared_types = @import("../types/mod.zig");

const layout_types = shared_types.layout;

pub fn draw(state: anytype, shell: anytype, layout: layout_types.WidgetLayout, tab_tooltip: ?widgets_common.Tooltip) void {
    app_top_bar_frame_runtime.draw(state, shell, layout);

    if (app_modes.ide.canToggleTerminal(state.app_mode)) {
        shell.setTheme(state.app_theme);
        state.side_nav.draw(shell, layout.side_nav.height, layout.side_nav.y);
    }

    if (comptime mode_build.focused_mode != .terminal) {
        if (app_modes.ide.supportsEditorSurface(state.app_mode) and state.editors.items.len > 0 and layout.status_bar.height > 0) {
            shell.setTheme(state.app_theme);
            const editor = app_active_editor_runtime.fromState(state) orelse return;
            const doc = editor.documentCore();
            state.status_bar.draw(
                shell,
                layout.window.width,
                layout.status_bar.y,
                .editor,
                .{
                    .mode = state.mode,
                    .imported_theme_name = state.editor_imported_theme_name,
                    .file_path = doc.filePath(),
                    .line = editor.cursor.line,
                    .col = editor.cursor.col,
                    .modified = doc.isModified(),
                },
                if (state.path_prompt.active and state.path_prompt.kind != null)
                    .{ .path = .{
                        .active = true,
                        .label = app_path_prompt_state.label(state.path_prompt.kind.?),
                        .value = state.path_prompt.query.items,
                        .select_all = state.path_prompt.select_all,
                        .placeholder = app_path_prompt_state.placeholder(state.path_prompt.kind.?),
                        .error_text = state.path_prompt.error_text,
                    } }
                else if (state.search_panel.active)
                    .{ .search = .{
                        .active = true,
                        .query = state.search_panel.query.items,
                        .select_all = state.search_panel.select_all,
                        .match_count = editor.searchMatches().len,
                        .active_index = editor.searchActiveIndex(),
                    } }
                else
                    null,
            );
        }
    }

    if (tab_tooltip) |tip| {
        widgets_common.drawTooltip(shell, tip.text, tip.x, tip.y);
    }
}
