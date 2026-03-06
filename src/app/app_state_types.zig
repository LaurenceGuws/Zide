const std = @import("std");
const app_bootstrap = @import("bootstrap.zig");
const app_modes = @import("modes/mod.zig");
const editor_mod = @import("../editor/editor.zig");
const editor_types = @import("../editor/types.zig");
const editor_render_cache_mod = @import("../editor/render/cache.zig");
const grammar_manager_mod = @import("../editor/grammar_manager.zig");
const app_logger = @import("../app_logger.zig");
const terminal_mod = @import("../terminal/core/terminal.zig");
const metrics_mod = @import("../terminal/model/metrics.zig");
const term_types = @import("../terminal/model/types.zig");
const shared_types = @import("../types/mod.zig");
const app_shell = @import("../app_shell.zig");
const widgets = @import("../ui/widgets.zig");
const input_actions = @import("../input/input_actions.zig");
const font_sample_view_mod = @import("../ui/font_sample_view.zig");

pub const AppMode = app_bootstrap.AppMode;
pub const ActiveMode = app_modes.ide.ActiveMode;
pub const TerminalCloseModalLayout = app_modes.ide.TerminalCloseConfirmLayout;

pub const Editor = editor_mod.Editor;
pub const CursorPos = editor_types.CursorPos;
pub const GrammarManager = grammar_manager_mod.GrammarManager;
pub const EditorRenderCache = editor_render_cache_mod.EditorRenderCache;
pub const EditorClusterCache = widgets.EditorClusterCache;

pub const TerminalSession = terminal_mod.TerminalSession;
pub const TerminalWorkspace = terminal_mod.TerminalWorkspace;
pub const TerminalTabId = terminal_mod.TerminalTabId;

pub const Metrics = metrics_mod.Metrics;
pub const Logger = app_logger.Logger;

pub const Theme = app_shell.Theme;
pub const MousePos = app_shell.MousePos;
pub const Shell = app_shell.Shell;

pub const TabBar = widgets.TabBar;
pub const OptionsBar = widgets.OptionsBar;
pub const SideNav = widgets.SideNav;
pub const StatusBar = widgets.StatusBar;
pub const TerminalWidget = widgets.TerminalWidget;

pub const CursorStyle = term_types.CursorStyle;
pub const InputSnapshot = shared_types.input.InputSnapshot;
pub const InputRouter = input_actions.InputRouter;
pub const EditorMode = app_modes.backend.EditorMode;
pub const TerminalMode = app_modes.backend.TerminalMode;
pub const FontSampleView = font_sample_view_mod.FontSampleView;
pub const TerminalNewTabStartLocationMode = enum {
    current,
    default,
};

pub const SearchPanelState = struct {
    active: bool,
    query: std.ArrayList(u8),

    pub fn init(_: std.mem.Allocator) SearchPanelState {
        return .{
            .active = false,
            .query = std.ArrayList(u8).empty,
        };
    }

    pub fn deinit(self: *SearchPanelState, allocator: std.mem.Allocator) void {
        self.query.deinit(allocator);
    }
};
