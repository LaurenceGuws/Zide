const editor_mod = @import("../../editor/editor.zig");
const editor_render_cache_mod = @import("../../editor/render/cache.zig");

const Editor = editor_mod.Editor;
const EditorRenderCache = editor_render_cache_mod.EditorRenderCache;

pub fn prepare(
    editor: *Editor,
    editor_render_cache: *EditorRenderCache,
) void {
    editor.applyPendingSearchWork();
    const total_lines = editor.lineCount();
    if (editor.takeHighlightDirtyRange()) |range| {
        const end_line = @min(range.end_line, total_lines);
        editor_render_cache.invalidateHighlightRange(range.start_line, end_line);
    }
    editor.ensureHighlighter();
}
