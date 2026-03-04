const std = @import("std");
const app_bootstrap = @import("bootstrap.zig");
const app_deinit_runtime = @import("deinit_runtime.zig");
const app_init_runtime = @import("init_runtime.zig");
const app_new_editor_runtime = @import("new_editor_runtime.zig");
const app_new_terminal_runtime = @import("new_terminal_runtime.zig");
const app_open_file_runtime = @import("open_file_runtime.zig");
const app_run_entry_hooks_runtime = @import("run_entry_hooks_runtime.zig");
const app_modes = @import("modes/mod.zig");
const editor_mod = @import("../editor/editor.zig");
const types = @import("../editor/types.zig");
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

const Editor = editor_mod.Editor;
const TerminalSession = terminal_mod.TerminalSession;
const TerminalWorkspace = terminal_mod.TerminalWorkspace;
const Metrics = metrics_mod.Metrics;
const Logger = app_logger.Logger;
const Shell = app_shell.Shell;
const TabBar = widgets.TabBar;
const OptionsBar = widgets.OptionsBar;
const SideNav = widgets.SideNav;
const StatusBar = widgets.StatusBar;
const EditorClusterCache = widgets.EditorClusterCache;
const EditorRenderCache = editor_render_cache_mod.EditorRenderCache;
const TerminalWidget = widgets.TerminalWidget;

pub const AppMode = app_bootstrap.AppMode;

pub const AppState = struct {
    pub const SearchPanelState = struct {
        active: bool,
        query: std.ArrayList(u8),

        pub fn init(_: std.mem.Allocator) SearchPanelState {
            return .{
                .active = false,
                .query = std.ArrayList(u8).empty,
            };
        }

        fn deinit(self: *SearchPanelState, allocator: std.mem.Allocator) void {
            self.query.deinit(allocator);
        }
    };

    pub const TerminalCloseModalLayout = app_modes.ide.TerminalCloseConfirmLayout;

    allocator: std.mem.Allocator,
    shell: *Shell,
    options_bar: OptionsBar,
    tab_bar: TabBar,
    side_nav: SideNav,
    status_bar: StatusBar,

    editors: std.ArrayList(*Editor),
    terminals: std.ArrayList(*TerminalSession),
    terminal_widgets: std.ArrayList(TerminalWidget),
    terminal_workspace: ?TerminalWorkspace,

    app_theme: app_shell.Theme,
    editor_theme: app_shell.Theme,
    terminal_theme: app_shell.Theme,
    shell_base_theme: app_shell.Theme,

    active_tab: usize,
    active_kind: app_modes.ide.ActiveMode,

    mode: []const u8,
    show_terminal: bool,
    terminal_height: f32,
    terminal_blink_style: TerminalWidget.BlinkStyle,
    terminal_cursor_style: ?term_types.CursorStyle,
    terminal_scrollback_rows: ?usize,
    editor_tab_bar_width_mode: TabBar.WidthMode,
    terminal_tab_bar_show_single_tab: bool,
    terminal_tab_bar_width_mode: TabBar.WidthMode,
    terminal_focus_report_window_events: bool,
    terminal_focus_report_pane_events: bool,
    last_terminal_pane_focus_reported: ?bool,
    config_reload_notice_until: f64,
    config_reload_notice_success: bool,

    needs_redraw: bool,
    idle_frames: u32,
    last_mouse_pos: app_shell.MousePos,
    resizing_terminal: bool,
    resize_start_y: f32,
    resize_start_height: f32,
    window_resize_pending: bool,
    window_resize_last_time: f64,
    mouse_debug: bool,
    terminal_scroll_dragging: bool,
    terminal_scroll_grab_offset: f32,
    last_mouse_redraw_time: f64,
    last_ctrl_down: bool,
    editor_dragging: bool,
    editor_drag_start: types.CursorPos,
    editor_drag_rect: bool,
    editor_hscroll_dragging: bool,
    editor_hscroll_grab_offset: f32,
    editor_vscroll_dragging: bool,
    editor_vscroll_grab_offset: f32,
    editor_cluster_cache: EditorClusterCache,
    editor_render_cache: EditorRenderCache,
    grammar_manager: grammar_manager_mod.GrammarManager,
    last_cursor_blink_on: bool,
    last_cursor_blink_armed: bool,
    frame_id: u64,
    metrics: Metrics,
    metrics_logger: Logger,
    input_latency_logger: Logger,
    app_logger: Logger,
    last_metrics_log_time: f64,
    editor_wrap: bool,
    editor_large_jump_rows: usize,
    editor_highlight_budget: ?usize,
    editor_width_budget: ?usize,
    perf_mode: bool,
    perf_frames_total: u64,
    perf_frames_done: u64,
    perf_scroll_delta: i32,
    perf_file_path: ?[]u8,
    perf_logger: Logger,
    last_input: shared_types.input.InputSnapshot,
    app_mode: AppMode,
    input_router: input_actions.InputRouter,
    editor_mode_adapter: app_modes.backend.EditorMode,
    terminal_mode_adapter: app_modes.backend.TerminalMode,
    font_sample_view: ?font_sample_view_mod.FontSampleView,
    font_sample_auto_close_frames: u64,
    font_sample_close_pending: bool,
    font_sample_screenshot_path: ?[]const u8,
    search_panel: SearchPanelState,
    terminal_close_confirm_tab: ?terminal_mod.TerminalTabId,

    pub fn init(allocator: std.mem.Allocator, app_mode: AppMode) !*AppState {
        return try app_init_runtime.init(AppState, allocator, app_mode);
    }

    pub fn deinit(self: *AppState) void {
        app_deinit_runtime.handle(self);
    }

    pub fn newEditor(self: *AppState) !void {
        try app_new_editor_runtime.handle(self);
    }

    pub fn openFile(self: *AppState, path: []const u8) !void {
        try app_open_file_runtime.open(self, path);
    }

    pub fn openFileAt(self: *AppState, path: []const u8, line_1: usize, col_1: ?usize) !void {
        try app_open_file_runtime.openAt(self, path, line_1, col_1);
    }

    pub fn newTerminal(self: *AppState) !void {
        try app_new_terminal_runtime.handle(self);
    }

    pub fn run(self: *AppState) !void {
        try app_run_entry_hooks_runtime.run(self);
    }
};
