const app_editor_create_intent_runtime = @import("editor_create_intent_runtime.zig");
const app_mode_adapter_sync_runtime = @import("mode_adapter_sync_runtime.zig");
const editor_mod = @import("../editor/editor.zig");

const Editor = editor_mod.Editor;

pub fn handle(state: anytype) !void {
    const grammar_manager = if (state.grammar_manager) |*gm| gm else return error.UnsupportedMode;
    _ = try app_editor_create_intent_runtime.routeCreateAndSync(state);
    const editor = try Editor.init(state.allocator, grammar_manager);
    try state.editors.append(state.allocator, editor);
    try state.tab_bar.addTab("untitled", .editor);
    state.active_tab = state.tab_bar.tabs.items.len - 1;
    state.active_kind = .editor;
    try app_mode_adapter_sync_runtime.sync(state);
}
