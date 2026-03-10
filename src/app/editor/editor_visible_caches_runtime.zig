const app_editor_display_prepare = @import("editor_display_prepare.zig");
const shared_types = @import("../../types/mod.zig");
const app_shell = @import("../../app_shell.zig");
const widgets = @import("../../ui/widgets.zig");
const editor_draw = @import("../../ui/widgets/editor_widget_draw.zig");

const layout_types = shared_types.layout;
const Shell = app_shell.Shell;
const EditorWidget = widgets.EditorWidget;

pub fn precompute(
    widget: *EditorWidget,
    editor_shell: *Shell,
    editor_layout: layout_types.WidgetLayout,
    editor_render_cache: anytype,
    editor_highlight_budget: ?usize,
    editor_width_budget: ?usize,
) void {
    if (editor_layout.editor.width <= 0 or editor_layout.editor.height <= 0) return;
    app_editor_display_prepare.prepare(widget.editor, editor_render_cache);
    const visible_lines = @as(usize, @intFromFloat(editor_layout.editor.height / editor_shell.charHeight()));
    const default_budget = if (visible_lines > 0) visible_lines + 1 else 0;
    const highlight_budget = editor_highlight_budget orelse default_budget;
    editor_draw.precomputeHighlightTokens(widget, editor_render_cache, editor_shell, editor_layout.editor.height, highlight_budget);
    const width_budget = editor_width_budget orelse highlight_budget;
    editor_draw.precomputeLineWidths(widget, editor_render_cache, editor_shell, editor_layout.editor.height, width_budget);
    editor_draw.precomputeWrapCounts(widget, editor_render_cache, editor_shell, editor_layout.editor.height, width_budget);
}
