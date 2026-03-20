const mode_build = @import("mode_build.zig");
const widgets = @import("../ui/widgets.zig");

const app_active_editor_runtime = if (mode_build.focused_mode == .terminal) struct {
    pub fn fromState(_: anytype) ?*anyopaque {
        return null;
    }
} else @import("editor/active_editor_runtime.zig");

const app_path_prompt_state = if (mode_build.focused_mode == .terminal) struct {
    pub fn openForOpen(_: anytype, _: anytype, _: anytype) !void {
        return error.UnsupportedMode;
    }

    pub fn openForSaveAs(_: anytype, _: anytype, _: anytype) !void {
        return error.UnsupportedMode;
    }

    pub fn openForReplace(_: anytype, _: anytype) !void {
        return error.UnsupportedMode;
    }

    pub fn openForReplaceAll(_: anytype, _: anytype) !void {
        return error.UnsupportedMode;
    }

    pub fn close(_: anytype) void {}
} else @import("editor/path_prompt_state.zig");

const app_search_panel_state = if (mode_build.focused_mode == .terminal) struct {
    pub fn openPanel(_: anytype, _: anytype, _: anytype, _: anytype, _: anytype) !void {
        return error.UnsupportedMode;
    }
} else @import("search/search_panel_state.zig");

const app_imported_theme_runtime = if (mode_build.focused_mode == .terminal) struct {
    pub fn cyclePrev(_: anytype) !void {
        return error.UnsupportedMode;
    }

    pub fn cycleNext(_: anytype) !void {
        return error.UnsupportedMode;
    }
} else @import("editor/imported_theme_runtime.zig");

pub fn apply(state: anytype, action: widgets.SharedTopBar.Action) !void {
    const active_editor = app_active_editor_runtime.fromState(state);
    switch (action) {
        .new_file => try state.newEditor(),
        .open_file => {
            state.search_panel.active = false;
            try app_path_prompt_state.openForOpen(&state.path_prompt, state.allocator, active_editor);
        },
        .save => {
            if (active_editor) |editor| {
                if (editor.documentCore().filePath() != null) {
                    try editor.save();
                } else {
                    state.search_panel.active = false;
                    try app_path_prompt_state.openForSaveAs(&state.path_prompt, state.allocator, editor);
                }
            }
        },
        .save_as => {
            state.search_panel.active = false;
            try app_path_prompt_state.openForSaveAs(&state.path_prompt, state.allocator, active_editor);
        },
        .find => {
            if (active_editor) |editor| {
                app_path_prompt_state.close(&state.path_prompt);
                try app_search_panel_state.openPanel(
                    state.allocator,
                    &state.search_panel.active,
                    &state.search_panel.select_all,
                    &state.search_panel.query,
                    editor,
                );
            }
        },
        .replace => {
            if (active_editor) |editor| {
                if (editor.searchQuery() != null) {
                    try app_path_prompt_state.openForReplace(&state.path_prompt, state.allocator);
                } else {
                    app_path_prompt_state.close(&state.path_prompt);
                    try app_search_panel_state.openPanel(
                        state.allocator,
                        &state.search_panel.active,
                        &state.search_panel.select_all,
                        &state.search_panel.query,
                        editor,
                    );
                }
            }
        },
        .replace_all => {
            if (active_editor) |editor| {
                if (editor.searchQuery() != null) {
                    try app_path_prompt_state.openForReplaceAll(&state.path_prompt, state.allocator);
                } else {
                    app_path_prompt_state.close(&state.path_prompt);
                    try app_search_panel_state.openPanel(
                        state.allocator,
                        &state.search_panel.active,
                        &state.search_panel.select_all,
                        &state.search_panel.query,
                        editor,
                    );
                }
            }
        },
        .cycle_imported_theme_prev => try app_imported_theme_runtime.cyclePrev(state),
        .cycle_imported_theme => try app_imported_theme_runtime.cycleNext(state),
    }
}
