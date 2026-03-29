const app_logger = @import("../app_logger.zig");
const manual_highlights_mod = @import("../editor/manual_highlights.zig");
const mode_build = @import("mode_build.zig");
const app_terminal_shell_icon_runtime = @import("terminal/terminal_shell_icon_runtime.zig");
const app_editor_live_smoke_runtime = @import("editor/live_smoke_runtime.zig");
const app_lifecycle_runtime = @import("lifecycle_runtime.zig");

pub fn handle(state: anytype) void {
    const lifecycle_log = app_logger.logger("app.lifecycle");
    lifecycle_log.logFields(.info, "shutdown_begin", &.{
        .{ .key = "editors", .value = .{ .unsigned = state.editors.items.len } },
        .{ .key = "terminals", .value = .{ .unsigned = state.terminals.items.len } },
    });
    app_lifecycle_runtime.noteShutdownBegin();

    if (comptime mode_build.focused_mode != .terminal) {
        for (state.editors.items, 0..) |e, idx| {
            lifecycle_log.logFields(.info, "editor_shutdown_prepare_begin", &.{
                .{ .key = "index", .value = .{ .unsigned = idx } },
                .{ .key = "editor_ptr", .value = .{ .unsigned = @intFromPtr(e) } },
            });
            e.prepareForShutdown();
            lifecycle_log.logFields(.info, "editor_shutdown_prepare_end", &.{
                .{ .key = "index", .value = .{ .unsigned = idx } },
            });
        }
    }

    state.terminal_shell_icon_cache.deinit(state.shell.rendererPtr());
    app_terminal_shell_icon_runtime.freeMappings(state.allocator, state.terminal_tab_bar_shell_icons);
    state.tab_bar.deinit();

    // Tear down GUI first so window close is immediate; backend cleanup can
    // continue after renderer shutdown without keeping the UI visible.
    lifecycle_log.logf(.info, "shell_deinit_begin", .{});
    state.shell.deinit(state.allocator);
    app_lifecycle_runtime.noteShellDeinitialized();
    lifecycle_log.logf(.info, "shell_deinit_end", .{});

    if (state.font_sample_view) |*view| {
        view.deinit();
    }
    if (comptime mode_build.focused_mode != .terminal) {
        for (state.editors.items, 0..) |e, idx| {
            lifecycle_log.logFields(.info, "editor_deinit_begin", &.{
                .{ .key = "index", .value = .{ .unsigned = idx } },
                .{ .key = "editor_ptr", .value = .{ .unsigned = @intFromPtr(e) } },
            });
            e.deinit();
            lifecycle_log.logFields(.info, "editor_deinit_end", &.{
                .{ .key = "index", .value = .{ .unsigned = idx } },
            });
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
    state.path_prompt.deinit(state.allocator);
    if (state.perf_file_path) |path| {
        state.allocator.free(path);
    }
    if (state.startup_file_paths) |paths| {
        for (paths) |path| {
            state.allocator.free(path);
        }
        state.allocator.free(paths);
    }
    if (state.terminal_default_start_location) |path| {
        state.allocator.free(path);
    }
    if (state.terminal_shell_path) |path| {
        state.allocator.free(path);
    }
    if (state.editor_imported_theme_name) |name| {
        state.allocator.free(name);
    }
    app_editor_live_smoke_runtime.deinitState(state.allocator, &state.editor_live_smoke);
    manual_highlights_mod.reset();
    app_logger.deinit();
    state.allocator.destroy(state);
}
