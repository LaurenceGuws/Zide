const std = @import("std");
const session_mod = @import("terminal_session.zig");
const app_logger = @import("../../app_logger.zig");
const runtime_policy = @import("../../app/runtime_policy.zig");
const polling = @import("workspace_polling.zig");

pub const TerminalSession = session_mod.TerminalSession;
pub const TabId = u64;

const Tab = struct {
    id: TabId,
    session: *TerminalSession,
};

pub const TabSyncEntry = struct {
    id: TabId,
    title_offset: usize,
    title_len: usize,
    foreground_process_label_offset: usize,
    foreground_process_label_len: usize,
    foreground_process_command_offset: usize,
    foreground_process_command_len: usize,
    cwd_offset: usize,
    cwd_len: usize,
    shell_path_offset: usize,
    shell_path_len: usize,
    alive: bool,
    exit_code: ?i32,
    progress_state: session_mod.ProgressState = .none,
    progress_value: ?u8 = null,

    pub fn title(self: TabSyncEntry, strings: []const u8) []const u8 {
        return strings[self.title_offset .. self.title_offset + self.title_len];
    }

    pub fn cwd(self: TabSyncEntry, strings: []const u8) []const u8 {
        return strings[self.cwd_offset .. self.cwd_offset + self.cwd_len];
    }

    pub fn foregroundProcessLabel(self: TabSyncEntry, strings: []const u8) []const u8 {
        return strings[self.foreground_process_label_offset .. self.foreground_process_label_offset + self.foreground_process_label_len];
    }

    pub fn foregroundProcessCommand(self: TabSyncEntry, strings: []const u8) []const u8 {
        return strings[self.foreground_process_command_offset .. self.foreground_process_command_offset + self.foreground_process_command_len];
    }

    pub fn shellPath(self: TabSyncEntry, strings: []const u8) []const u8 {
        return strings[self.shell_path_offset .. self.shell_path_offset + self.shell_path_len];
    }
};

pub const TabSyncState = struct {
    active_tab_id: ?TabId,
    strings: []const u8,
    tabs: []const TabSyncEntry,
};

pub const TabTarget = struct {
    index: usize,
    id: TabId,
};

pub const TerminalWorkspace = struct {
    pub const CloseConfirmContext = struct {
        foreground_process_present: bool = false,
        foreground_process_label: []const u8 = "",
        semantic_command_active: bool = false,
    };

    pub const ActiveFrameState = struct {
        has_data: bool = false,
        session_ptr: usize = 0,
        current_generation: u64 = 0,
        published_generation: u64 = 0,
        presented_generation: u64 = 0,
    };

    pub const PollFrameResult = struct {
        any_polled: bool = false,
        active_published_changed: bool = false,
    };

    pub const PollPolicy = struct {
        active_intent: runtime_policy.RuntimeIntent,
        background_intent: runtime_policy.RuntimeIntent,
        max_tabs_per_frame: usize,
        max_background_tabs_per_frame: usize,
        max_active_polls_per_frame: usize,
    };

    pub const PollFrameMetrics = struct {
        seq: u64 = 0,
        tab_count: usize = 0,
        active_index: usize = 0,
        active_lifecycle: runtime_policy.LifecycleTier = .hidden_warm,
        background_lifecycle: runtime_policy.LifecycleTier = .hidden_warm,
        active_work_class: runtime_policy.WorkClass = .background,
        background_work_class: runtime_policy.WorkClass = .background,
        active_budget: usize = 0,
        active_polled: usize = 0,
        background_budget: usize = 0,
        background_inspected: usize = 0,
        background_polled: usize = 0,
        total_polled: usize = 0,
        budget_tabs: usize = 0,
        budget_exhausted_hint: bool = false,
        active_spillover_hint: bool = false,
        background_backlog_hint: bool = false,
    };

    pub const PollRuntimeCounters = struct {
        frames: u64 = 0,
        active_polled: u64 = 0,
        background_polled: u64 = 0,
        active_budget: u64 = 0,
        background_budget: u64 = 0,
        budget_exhausted_frames: u64 = 0,
        active_spillover_frames: u64 = 0,
        background_backlog_frames: u64 = 0,
    };

    allocator: std.mem.Allocator,
    init_options: TerminalSession.InitOptions,
    tabs: std.ArrayList(Tab),
    active_index: usize,
    next_tab_id: TabId,
    background_poll_cursor: usize,
    input_pressure_index: ?usize,
    poll_metrics_seq: u64,
    last_poll_metrics: PollFrameMetrics,
    poll_runtime_counters: PollRuntimeCounters,

    pub fn init(allocator: std.mem.Allocator, init_options: TerminalSession.InitOptions) TerminalWorkspace {
        return .{
            .allocator = allocator,
            .init_options = init_options,
            .tabs = .empty,
            .active_index = 0,
            .next_tab_id = 1,
            .background_poll_cursor = 0,
            .input_pressure_index = null,
            .poll_metrics_seq = 0,
            .last_poll_metrics = .{},
            .poll_runtime_counters = .{},
        };
    }

    pub fn deinit(self: *TerminalWorkspace) void {
        for (self.tabs.items) |tab| {
            tab.session.deinit();
        }
        self.tabs.deinit(self.allocator);
    }

    pub fn tabCount(self: *const TerminalWorkspace) usize {
        return self.tabs.items.len;
    }

    pub fn activeIndex(self: *const TerminalWorkspace) usize {
        if (self.tabs.items.len == 0) return 0;
        return @min(self.active_index, self.tabs.items.len - 1);
    }

    pub fn tabIdAt(self: *const TerminalWorkspace, index: usize) ?TabId {
        if (index >= self.tabs.items.len) return null;
        return self.tabs.items[index].id;
    }

    pub fn activeTabId(self: *const TerminalWorkspace) ?TabId {
        if (self.tabs.items.len == 0) return null;
        return self.tabs.items[self.activeIndex()].id;
    }

    fn sessionAt(self: *TerminalWorkspace, index: usize) ?*TerminalSession {
        if (index >= self.tabs.items.len) return null;
        return self.tabs.items[index].session;
    }

    fn activeSession(self: *TerminalWorkspace) ?*TerminalSession {
        if (self.tabs.items.len == 0) return null;
        return self.tabs.items[self.activeIndex()].session;
    }

    fn sessionNeedsCloseConfirm(session: *TerminalSession) bool {
        if (!session.isAlive()) return false;
        const activity = session.currentActivityMetadata();
        return activity.foreground_process_present or
            activity.semantic_input_active or
            activity.semantic_output_active or
            session.core.isAltActive() or
            session.mouseReportingEnabled();
    }

    pub fn copyActiveSessionCwd(
        self: *TerminalWorkspace,
        allocator: std.mem.Allocator,
        out: *std.ArrayList(u8),
    ) ![]const u8 {
        const session = self.activeSession() orelse {
            out.clearRetainingCapacity();
            return "";
        };
        var title_buf = std.ArrayList(u8).empty;
        defer title_buf.deinit(allocator);
        const metadata = try session.copyMetadata(allocator, &title_buf, out);
        return metadata.cwd;
    }

    pub fn activeSessionShouldConfirmClose(self: *const TerminalWorkspace) bool {
        if (self.tabs.items.len == 0) return false;
        return sessionNeedsCloseConfirm(self.tabs.items[self.activeIndex()].session);
    }

    pub fn activeSessionAlive(self: *const TerminalWorkspace) bool {
        if (self.tabs.items.len == 0) return false;
        return self.tabs.items[self.activeIndex()].session.isAlive();
    }

    pub fn refreshActiveSessionChildExit(self: *TerminalWorkspace) void {
        if (self.tabs.items.len == 0) return;
        self.tabs.items[self.activeIndex()].session.refreshChildExit();
    }

    pub fn activeFrameState(self: *const TerminalWorkspace) ActiveFrameState {
        if (self.tabs.items.len == 0) return .{};
        const session = self.tabs.items[self.activeIndex()].session;
        return .{
            .has_data = session.hasData(),
            .session_ptr = @intFromPtr(session),
            .current_generation = session.currentGeneration(),
            .published_generation = session.publishedGeneration(),
            .presented_generation = session.presentedGeneration(),
        };
    }

    pub fn firstConfirmCloseTab(self: *const TerminalWorkspace) ?TabTarget {
        for (self.tabs.items, 0..) |tab, idx| {
            if (!sessionNeedsCloseConfirm(tab.session)) continue;
            return .{
                .index = idx,
                .id = tab.id,
            };
        }
        return null;
    }

    pub fn closeConfirmContextForTabId(self: *const TerminalWorkspace, tab_id: TabId) ?CloseConfirmContext {
        for (self.tabs.items) |tab| {
            if (tab.id != tab_id) continue;
            const activity = tab.session.currentActivityMetadata();
            return .{
                .foreground_process_present = activity.foreground_process_present,
                .foreground_process_label = activity.foreground_process_label,
                .semantic_command_active = activity.semantic_input_active or activity.semantic_output_active,
            };
        }
        return null;
    }

    pub fn copyTabSyncState(
        self: *TerminalWorkspace,
        allocator: std.mem.Allocator,
        entries_out: *std.ArrayList(TabSyncEntry),
        strings_out: *std.ArrayList(u8),
    ) !TabSyncState {
        entries_out.clearRetainingCapacity();
        strings_out.clearRetainingCapacity();

        var title_buf = std.ArrayList(u8).empty;
        defer title_buf.deinit(allocator);
        var cwd_buf = std.ArrayList(u8).empty;
        defer cwd_buf.deinit(allocator);

        for (self.tabs.items) |tab| {
            const metadata = try tab.session.copyMetadata(allocator, &title_buf, &cwd_buf);
            const activity = tab.session.currentActivityMetadata();

            const title_offset = strings_out.items.len;
            try strings_out.appendSlice(allocator, metadata.title);
            const foreground_process_label_offset = strings_out.items.len;
            try strings_out.appendSlice(allocator, activity.foreground_process_label);
            const foreground_process_command_offset = strings_out.items.len;
            try strings_out.appendSlice(allocator, activity.foreground_process_command);
            const cwd_offset = strings_out.items.len;
            try strings_out.appendSlice(allocator, metadata.cwd);
            const shell_path = tab.session.launchShellPath();
            const shell_path_offset = strings_out.items.len;
            try strings_out.appendSlice(allocator, shell_path);

            try entries_out.append(allocator, .{
                .id = tab.id,
                .title_offset = title_offset,
                .title_len = metadata.title.len,
                .foreground_process_label_offset = foreground_process_label_offset,
                .foreground_process_label_len = activity.foreground_process_label.len,
                .foreground_process_command_offset = foreground_process_command_offset,
                .foreground_process_command_len = activity.foreground_process_command.len,
                .cwd_offset = cwd_offset,
                .cwd_len = metadata.cwd.len,
                .shell_path_offset = shell_path_offset,
                .shell_path_len = shell_path.len,
                .alive = metadata.alive,
                .exit_code = metadata.exit_code,
                .progress_state = activity.progress.state,
                .progress_value = activity.progress.value,
            });
        }

        return .{
            .active_tab_id = self.activeTabId(),
            .strings = strings_out.items,
            .tabs = entries_out.items,
        };
    }

    pub const CreatedTab = struct {
        id: TabId,
        session: *TerminalSession,
    };

    pub fn createTabWithSession(self: *TerminalWorkspace, rows: u16, cols: u16) !CreatedTab {
        const session = try TerminalSession.initWithOptions(self.allocator, rows, cols, self.init_options);
        errdefer session.deinit();

        const tab_id = self.next_tab_id;
        self.next_tab_id += 1;
        try self.tabs.append(self.allocator, .{
            .id = tab_id,
            .session = session,
        });
        self.active_index = self.tabs.items.len - 1;
        self.background_poll_cursor = self.active_index;
        return .{
            .id = tab_id,
            .session = session,
        };
    }

    pub fn createTab(self: *TerminalWorkspace, rows: u16, cols: u16) !TabId {
        return (try self.createTabWithSession(rows, cols)).id;
    }

    pub fn activateIndex(self: *TerminalWorkspace, index: usize) bool {
        if (index >= self.tabs.items.len) return false;
        self.active_index = index;
        return true;
    }

    pub fn activateTab(self: *TerminalWorkspace, tab_id: TabId) bool {
        const idx = self.indexOfTabId(tab_id) orelse return false;
        self.active_index = idx;
        return true;
    }

    pub fn activateNext(self: *TerminalWorkspace) bool {
        const count = self.tabs.items.len;
        if (count <= 1) return false;
        self.active_index = (self.activeIndex() + 1) % count;
        return true;
    }

    pub fn activatePrev(self: *TerminalWorkspace) bool {
        const count = self.tabs.items.len;
        if (count <= 1) return false;
        const idx = self.activeIndex();
        self.active_index = if (idx == 0) count - 1 else idx - 1;
        return true;
    }

    pub fn closeTab(self: *TerminalWorkspace, tab_id: TabId) bool {
        const idx = self.indexOfTabId(tab_id) orelse return false;
        polling.clearInputPressure(self);
        const removed = self.tabs.orderedRemove(idx);
        removed.session.deinit();
        self.normalizeActiveAfterRemoval(idx);
        polling.normalizePollCursor(self);
        return true;
    }

    pub fn closeActiveTab(self: *TerminalWorkspace) bool {
        const tab_id = self.activeTabId() orelse return false;
        return self.closeTab(tab_id);
    }

    pub fn moveTab(self: *TerminalWorkspace, tab_id: TabId, to_index: usize) bool {
        const log = app_logger.logger("terminal.workspace");
        const from_index = self.indexOfTabId(tab_id) orelse return false;
        if (to_index >= self.tabs.items.len) return false;
        if (from_index == to_index) return true;

        polling.clearInputPressure(self);
        const active_id = self.activeTabId();
        const moved = self.tabs.orderedRemove(from_index);
        self.tabs.insert(self.allocator, to_index, moved) catch |err| {
            log.logf(.warning, "move tab insert failed from={d} to={d}: {s}", .{ from_index, to_index, @errorName(err) });
            return false;
        };
        if (active_id) |id| {
            self.active_index = self.indexOfTabId(id) orelse 0;
        }
        polling.normalizePollCursor(self);
        return true;
    }

    pub fn setCellSizeAll(self: *TerminalWorkspace, cell_width: u16, cell_height: u16) void {
        for (self.tabs.items) |tab| {
            tab.session.setCellSize(cell_width, cell_height);
        }
    }

    pub fn resizeAll(self: *TerminalWorkspace, rows: u16, cols: u16) !void {
        for (self.tabs.items) |tab| {
            try tab.session.resize(rows, cols);
        }
    }

    pub fn pollForFrame(self: *TerminalWorkspace, input_active_index: ?usize, policy: PollPolicy) !PollFrameResult {
        return polling.pollForFrame(self, input_active_index, policy);
    }

    pub fn lastPollFrameMetrics(self: *const TerminalWorkspace) PollFrameMetrics {
        return self.last_poll_metrics;
    }

    pub fn pollRuntimeCounters(self: *const TerminalWorkspace) PollRuntimeCounters {
        return self.poll_runtime_counters;
    }

    fn indexOfTabId(self: *const TerminalWorkspace, tab_id: TabId) ?usize {
        for (self.tabs.items, 0..) |tab, i| {
            if (tab.id == tab_id) return i;
        }
        return null;
    }

    fn normalizeActiveAfterRemoval(self: *TerminalWorkspace, removed_index: usize) void {
        if (self.tabs.items.len == 0) {
            self.active_index = 0;
            return;
        }
        if (self.active_index > removed_index) {
            self.active_index -= 1;
            return;
        }
        if (self.active_index >= self.tabs.items.len) {
            self.active_index = self.tabs.items.len - 1;
        }
    }
};
