const app_logger = @import("../app_logger.zig");
const mode_build = @import("mode_build.zig");

pub fn handle(state: anytype) void {
    if (state.font_sample_view) |*view| {
        view.deinit();
    }
    if (comptime mode_build.focused_mode != .terminal) {
        for (state.editors.items) |e| {
            e.deinit();
        }
    }
    state.editors.deinit(state.allocator);

    for (state.terminal_widgets.items) |*widget| {
        widget.deinit();
    }
    state.terminal_widgets.deinit(state.allocator);
    if (state.terminal_workspace) |*workspace| {
        workspace.deinit();
        state.terminal_workspace = null;
    } else {
        for (state.terminals.items) |t| {
            t.deinit();
        }
    }
    state.terminals.deinit(state.allocator);

    state.tab_bar.deinit();
    state.shell.deinit(state.allocator);
    state.editor_render_cache.deinit();
    state.editor_cluster_cache.deinit();
    if (state.grammar_manager) |*grammar_manager| {
        grammar_manager.deinit();
    }
    state.input_router.deinit();
    if (state.editor_mode_adapter) |*editor_mode_adapter| {
        editor_mode_adapter.deinit(state.allocator);
    }
    state.terminal_mode_adapter.deinit(state.allocator);
    state.search_panel.query.deinit(state.allocator);
    if (state.perf_file_path) |path| {
        state.allocator.free(path);
    }
    if (state.terminal_default_start_location) |path| {
        state.allocator.free(path);
    }
    app_logger.deinit();
    state.allocator.destroy(state);
}
