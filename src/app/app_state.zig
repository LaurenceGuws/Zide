const std = @import("std");
const app_state_runtime_wiring = @import("app_state_runtime_wiring.zig");
const t = @import("app_state_types.zig");

pub const AppMode = t.AppMode;

pub const AppState = struct {
    pub const SearchPanelState = t.SearchPanelState;
    pub const TerminalCloseModalLayout = t.TerminalCloseModalLayout;

    allocator: std.mem.Allocator,
    shell: *t.Shell,
    options_bar: t.OptionsBar,
    tab_bar: t.TabBar,
    side_nav: t.SideNav,
    status_bar: t.StatusBar,

    editors: std.ArrayList(*t.Editor),
    terminals: std.ArrayList(*t.TerminalSession),
    terminal_widgets: std.ArrayList(t.TerminalWidget),
    terminal_workspace: ?t.TerminalWorkspace,

    app_theme: t.Theme,
    editor_theme: t.Theme,
    terminal_theme: t.Theme,
    shell_base_theme: t.Theme,

    active_tab: usize,
    active_kind: t.ActiveMode,

    mode: []const u8,
    show_terminal: bool,
    terminal_height: f32,
    terminal_blink_style: t.TerminalWidget.BlinkStyle,
    terminal_cursor_style: ?t.CursorStyle,
    terminal_scrollback_rows: ?usize,
    editor_tab_bar_width_mode: t.TabBar.WidthMode,
    terminal_tab_bar_show_single_tab: bool,
    terminal_tab_bar_width_mode: t.TabBar.WidthMode,
    terminal_focus_report_window_events: bool,
    terminal_focus_report_pane_events: bool,
    last_terminal_pane_focus_reported: ?bool,
    config_reload_notice_until: f64,
    config_reload_notice_success: bool,

    needs_redraw: bool,
    idle_frames: u32,
    last_mouse_pos: t.MousePos,
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
    editor_drag_start: t.CursorPos,
    editor_drag_rect: bool,
    editor_hscroll_dragging: bool,
    editor_hscroll_grab_offset: f32,
    editor_vscroll_dragging: bool,
    editor_vscroll_grab_offset: f32,
    editor_cluster_cache: t.EditorClusterCache,
    editor_render_cache: t.EditorRenderCache,
    grammar_manager: t.GrammarManager,
    last_cursor_blink_on: bool,
    last_cursor_blink_armed: bool,
    frame_id: u64,
    metrics: t.Metrics,
    metrics_logger: t.Logger,
    input_latency_logger: t.Logger,
    app_logger: t.Logger,
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
    perf_logger: t.Logger,
    last_input: t.InputSnapshot,
    app_mode: AppMode,
    input_router: t.InputRouter,
    editor_mode_adapter: t.EditorMode,
    terminal_mode_adapter: t.TerminalMode,
    font_sample_view: ?t.FontSampleView,
    font_sample_auto_close_frames: u64,
    font_sample_close_pending: bool,
    font_sample_screenshot_path: ?[]const u8,
    search_panel: SearchPanelState,
    terminal_close_confirm_tab: ?t.TerminalTabId,

    pub fn init(allocator: std.mem.Allocator, app_mode: AppMode) !*AppState {
        return try app_state_runtime_wiring.init(AppState, allocator, app_mode);
    }

    pub fn initFocused(allocator: std.mem.Allocator, comptime app_mode: AppMode) !*AppState {
        return try app_state_runtime_wiring.initFocused(AppState, allocator, app_mode);
    }

    pub fn deinit(self: *AppState) void {
        app_state_runtime_wiring.deinit(self);
    }

    pub fn newEditor(self: *AppState) !void {
        try app_state_runtime_wiring.newEditor(self);
    }

    pub fn openFile(self: *AppState, path: []const u8) !void {
        try app_state_runtime_wiring.openFile(self, path);
    }

    pub fn openFileAt(self: *AppState, path: []const u8, line_1: usize, col_1: ?usize) !void {
        try app_state_runtime_wiring.openFileAt(self, path, line_1, col_1);
    }

    pub fn newTerminal(self: *AppState) !void {
        try app_state_runtime_wiring.newTerminal(self);
    }

    pub fn run(self: *AppState) !void {
        try app_state_runtime_wiring.run(self);
    }
};
