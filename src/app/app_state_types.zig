const std = @import("std");
const app_bootstrap = @import("bootstrap.zig");
const mode_build = @import("mode_build.zig");
const app_modes = @import("modes/mod.zig");
const terminal_shell_icon_runtime = @import("terminal/terminal_shell_icon_runtime.zig");
const editor_types = @import("../editor/types.zig");
const app_logger = @import("../app_logger.zig");
const terminal_runtime = @import("../terminal/core/terminal_runtime.zig");
const workspace_host = @import("../terminal/core/workspace_host.zig");
const workspace_mod = @import("../terminal/core/workspace.zig");
const metrics_mod = @import("../terminal/model/metrics.zig");
const term_types = @import("../terminal/model/types.zig");
const shared_types = @import("../types/mod.zig");
const app_shell = @import("../app_shell.zig");
const widgets = @import("../ui/widgets.zig");
const input_actions = @import("../input/input_actions.zig");
const font_sample_view_mod = @import("../ui/font_sample_view.zig");

const editor_mod = if (mode_build.focused_mode == .terminal) struct {
    pub const Editor = opaque {};
} else @import("../editor/editor.zig");

const grammar_manager_mod = if (mode_build.focused_mode == .terminal) struct {
    pub const GrammarManager = struct {
        pub fn init(_: std.mem.Allocator) !@This() {
            return .{};
        }

        pub fn deinit(_: *@This()) void {}
    };
} else @import("../editor/grammar_manager.zig");

const editor_render_cache_mod = if (mode_build.focused_mode == .terminal) struct {
    pub const EditorRenderCache = struct {
        pub fn init(_: std.mem.Allocator, _: usize) @This() {
            return .{};
        }

        pub fn clear(_: *@This()) void {}

        pub fn deinit(_: *@This()) void {}
    };
} else @import("../editor/render/cache.zig");

pub const AppMode = app_bootstrap.AppMode;
pub const ActiveMode = app_modes.ide.ActiveMode;
pub const TerminalCloseModalLayout = app_modes.ide.TerminalCloseConfirmLayout;

pub const Editor = editor_mod.Editor;
pub const CursorPos = editor_types.CursorPos;
pub const GrammarManager = grammar_manager_mod.GrammarManager;
pub const EditorRenderCache = editor_render_cache_mod.EditorRenderCache;
pub const EditorClusterCache = widgets.EditorClusterCache;

pub const TerminalSession = terminal_runtime.TerminalSession;
pub const TerminalWorkspace = workspace_mod.TerminalWorkspace;
pub const TerminalTabId = workspace_mod.TabId;
pub const TerminalCloseConfirmContext = workspace_host.CloseConfirmContext;

pub const Metrics = metrics_mod.Metrics;
pub const Logger = app_logger.Logger;

pub const Theme = app_shell.Theme;
pub const MousePos = app_shell.MousePos;
pub const Shell = app_shell.Shell;
pub const FrameSubmission = app_shell.FrameSubmission;

pub const TabBar = widgets.TabBar;
pub const SharedTopBar = widgets.SharedTopBar;
pub const SideNav = widgets.SideNav;
pub const StatusBar = widgets.StatusBar;
pub const TerminalWidget = widgets.TerminalWidget;

pub const CursorStyle = term_types.CursorStyle;
pub const InputSnapshot = shared_types.input.InputSnapshot;
pub const InputRouter = input_actions.InputRouter;
pub const EditorMode = app_modes.backend.EditorMode;
pub const TerminalMode = app_modes.backend.TerminalMode;
pub const FontSampleView = font_sample_view_mod.FontSampleView;
pub const TerminalWindowChromeMode = @import("../config/lua_config.zig").TerminalWindowChromeMode;
pub const TerminalShellIconMapping = @import("../config/lua_config.zig").TerminalShellIconMapping;
pub const TerminalShellIconCache = terminal_shell_icon_runtime.ShellIconCache;
pub const TerminalNewTabStartLocationMode = enum {
    current,
    default,
};

pub const EditorLiveSmokeState = struct {
    enabled: bool = false,
    scenario: ?[]u8 = null,
    inject_text: ?[]u8 = null,
    inject_frame: u64 = 0,
    capture_start_frame: u64 = 0,
    capture_end_frame: u64 = 0,
    close_after_frame: u64 = 0,
    output_dir: ?[]u8 = null,
    injected: bool = false,
};

pub const WindowCaptionButton = enum {
    minimize,
    maximize_restore,
    close,
};

pub const TerminalFramePacingState = struct {
    last_draw_seq: u64 = 0,
    last_poll_seq: u64 = 0,
    last_observed_generation: u64 = 0,
    last_observed_pending_generation: u64 = 0,
    last_drawn_generation: u64 = 0,
    last_generation_change_time: f64 = 0,
    last_draw_time: f64 = 0,
    idle_frames: u32 = 0,
    recent_generation_followthrough_draws: u8 = 0,
};

pub const SearchPanelState = struct {
    active: bool,
    query: std.ArrayList(u8),
    select_all: bool,

    pub fn init(_: std.mem.Allocator) SearchPanelState {
        return .{
            .active = false,
            .query = std.ArrayList(u8).empty,
            .select_all = false,
        };
    }

    pub fn deinit(self: *SearchPanelState, allocator: std.mem.Allocator) void {
        self.query.deinit(allocator);
    }
};

pub const PathPromptKind = enum {
    open_file,
    save_as,
    go_to_line,
    replace,
    replace_all,
    confirm_close_dirty,
};

pub const PathPromptPendingAction = enum {
    close_active_editor,
};

pub const PathPromptState = struct {
    active: bool,
    kind: ?PathPromptKind,
    pending_action: ?PathPromptPendingAction,
    query: std.ArrayList(u8),
    select_all: bool,
    error_text: ?[]const u8,

    pub fn init() PathPromptState {
        return .{
            .active = false,
            .kind = null,
            .pending_action = null,
            .query = std.ArrayList(u8).empty,
            .select_all = false,
            .error_text = null,
        };
    }

    pub fn deinit(self: *PathPromptState, allocator: std.mem.Allocator) void {
        self.query.deinit(allocator);
    }
};
