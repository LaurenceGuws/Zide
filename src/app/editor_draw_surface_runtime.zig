const app_editor_display_prepare = @import("editor_display_prepare.zig");
const app_modes = @import("modes/mod.zig");
const shared_types = @import("../types/mod.zig");
const widgets = @import("../ui/widgets.zig");

const layout_types = shared_types.layout;
const EditorWidget = widgets.EditorWidget;

pub fn draw(state: anytype, shell: anytype, layout: layout_types.WidgetLayout) void {
    if (!app_modes.ide.supportsEditorSurface(state.app_mode) or state.editors.items.len == 0) return;

    shell.setTheme(state.editor_theme);
    const editor_idx = @min(state.active_tab, state.editors.items.len - 1);
    const editor = state.editors.items[editor_idx];
    app_editor_display_prepare.prepare(editor, &state.editor_render_cache);
    var widget = EditorWidget.initWithCache(editor, &state.editor_cluster_cache, state.editor_wrap);
    widget.drawCached(
        shell,
        &state.editor_render_cache,
        layout.editor.x,
        layout.editor.y,
        layout.editor.width,
        layout.editor.height,
        state.frame_id,
        state.last_input,
    );
}
