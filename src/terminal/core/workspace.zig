const std = @import("std");
const session_mod = @import("terminal_session.zig");
const app_logger = @import("../../app_logger.zig");

pub const TerminalSession = session_mod.TerminalSession;
pub const TabId = u64;

pub const Tab = struct {
    id: TabId,
    session: *TerminalSession,
};

pub const TabMetadata = struct {
    id: TabId,
    title: []const u8,
    cwd: []const u8,
    alive: bool,
    exit_code: ?i32,
};

pub const TerminalWorkspace = struct {
    pub const PollBudget = struct {
        /// Maximum number of sessions to inspect for data and poll in a single frame.
        max_tabs_per_frame: usize = 4,
        /// Maximum number of background (non-active) sessions to inspect per frame.
        max_background_tabs_per_frame: usize = 2,
        /// Maximum number of poll passes for the active tab in one frame.
        /// This helps high-throughput active tabs stay smooth without unbounded all-tab polling.
        max_active_polls_per_frame: usize = 1,
    };
    pub const PollFrameMetrics = struct {
        seq: u64 = 0,
        tab_count: usize = 0,
        active_index: usize = 0,
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

    allocator: std.mem.Allocator,
    init_options: TerminalSession.InitOptions,
    tabs: std.ArrayList(Tab),
    active_index: usize,
    next_tab_id: TabId,
    background_poll_cursor: usize,
    input_pressure_index: ?usize,
    poll_metrics_seq: u64,
    last_poll_metrics: PollFrameMetrics,

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

    pub fn tabsSlice(self: *const TerminalWorkspace) []const Tab {
        return self.tabs.items;
    }

    pub fn tabIdAt(self: *const TerminalWorkspace, index: usize) ?TabId {
        if (index >= self.tabs.items.len) return null;
        return self.tabs.items[index].id;
    }

    pub fn activeTabId(self: *const TerminalWorkspace) ?TabId {
        if (self.tabs.items.len == 0) return null;
        return self.tabs.items[self.activeIndex()].id;
    }

    pub fn sessionAt(self: *TerminalWorkspace, index: usize) ?*TerminalSession {
        if (index >= self.tabs.items.len) return null;
        return self.tabs.items[index].session;
    }

    pub fn activeSession(self: *TerminalWorkspace) ?*TerminalSession {
        if (self.tabs.items.len == 0) return null;
        return self.tabs.items[self.activeIndex()].session;
    }

    pub fn metadataAt(self: *TerminalWorkspace, index: usize) ?TabMetadata {
        const session = self.sessionAt(index) orelse return null;
        return .{
            .id = self.tabs.items[index].id,
            .title = session.currentTitle(),
            .cwd = session.currentCwd(),
            .alive = session.isAlive(),
            .exit_code = session.childExitCode(),
        };
    }

    pub fn createTab(self: *TerminalWorkspace, rows: u16, cols: u16) !TabId {
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
        return tab_id;
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
        self.clearInputPressure();
        const removed = self.tabs.orderedRemove(idx);
        removed.session.deinit();
        self.normalizeActiveAfterRemoval(idx);
        self.normalizePollCursor();
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

        self.clearInputPressure();
        const active_id = self.activeTabId();
        const moved = self.tabs.orderedRemove(from_index);
        self.tabs.insert(self.allocator, to_index, moved) catch |err| {
            log.logf(.warning, "move tab insert failed from={d} to={d}: {s}", .{ from_index, to_index, @errorName(err) });
            return false;
        };
        if (active_id) |id| {
            self.active_index = self.indexOfTabId(id) orelse 0;
        }
        self.normalizePollCursor();
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

    pub fn pollAll(self: *TerminalWorkspace, input_active_index: ?usize, has_input: bool) !bool {
        const count = self.tabs.items.len;
        const active_idx = normalizeIndex(input_active_index, count) orelse self.activeIndex();
        var any_polled = false;
        var total_polled: usize = 0;
        var active_polled: usize = 0;
        var background_polled: usize = 0;
        for (self.tabs.items, 0..) |tab, i| {
            const is_input_target = input_active_index != null and input_active_index.? == i;
            tab.session.setInputPressure(has_input and is_input_target);
            if (tab.session.hasData()) {
                try tab.session.poll();
                any_polled = true;
                total_polled += 1;
                if (i == active_idx) {
                    active_polled += 1;
                } else {
                    background_polled += 1;
                }
            }
        }
        self.recordPollMetrics(.{
            .tab_count = count,
            .active_index = active_idx,
            .active_budget = 1,
            .active_polled = active_polled,
            .background_budget = if (count > 0) count - 1 else 0,
            .background_inspected = if (count > 0) count - 1 else 0,
            .background_polled = background_polled,
            .total_polled = total_polled,
            .budget_tabs = count,
            .budget_exhausted_hint = false,
            .active_spillover_hint = false,
            .background_backlog_hint = false,
        });
        return any_polled;
    }

    pub fn pollBudgeted(self: *TerminalWorkspace, input_active_index: ?usize, has_input: bool, budget: PollBudget) !bool {
        const count = self.tabs.items.len;
        if (count == 0) {
            self.clearInputPressure();
            self.background_poll_cursor = 0;
            self.recordPollMetrics(.{});
            return false;
        }

        self.normalizePollCursor();
        self.updateInputPressure(input_active_index, has_input);

        const active_idx = normalizeIndex(input_active_index, count) orelse self.activeIndex();
        if (budget.max_tabs_per_frame == 0) {
            self.recordPollMetrics(.{
                .tab_count = count,
                .active_index = active_idx,
                .budget_tabs = 0,
                .background_backlog_hint = count > 1,
            });
            return false;
        }

        var any_polled = false;
        const active_polls = @max(@as(usize, 1), budget.max_active_polls_per_frame);
        var active_polled_success: usize = 0;
        var active_polled: usize = 0;
        while (active_polled < active_polls) : (active_polled += 1) {
            if (try self.pollIndexIfReady(active_idx)) {
                any_polled = true;
                active_polled_success += 1;
            } else {
                break;
            }
        }

        var background_budget_used: usize = 0;
        var background_inspected: usize = 0;
        var background_polled: usize = 0;
        var budget_exhausted_hint = false;
        var background_backlog_hint = false;

        if (count == 1 or budget.max_tabs_per_frame == 1 or budget.max_background_tabs_per_frame == 0) {
            background_backlog_hint = count > 1 and (budget.max_tabs_per_frame <= 1 or budget.max_background_tabs_per_frame == 0);
            self.background_poll_cursor = (active_idx + 1) % count;
            self.recordPollMetrics(.{
                .tab_count = count,
                .active_index = active_idx,
                .active_budget = active_polls,
                .active_polled = active_polled_success,
                .background_budget = background_budget_used,
                .background_inspected = background_inspected,
                .background_polled = background_polled,
                .total_polled = active_polled_success,
                .budget_tabs = budget.max_tabs_per_frame,
                .budget_exhausted_hint = budget_exhausted_hint,
                .active_spillover_hint = active_polled_success >= active_polls and self.tabs.items[active_idx].session.hasData(),
                .background_backlog_hint = background_backlog_hint,
            });
            return any_polled;
        }

        const remaining_slots = budget.max_tabs_per_frame - 1;
        const background_slots = @min(remaining_slots, budget.max_background_tabs_per_frame);
        background_budget_used = background_slots;
        if (background_slots == 0) {
            background_backlog_hint = count > 1;
            self.background_poll_cursor = (active_idx + 1) % count;
            self.recordPollMetrics(.{
                .tab_count = count,
                .active_index = active_idx,
                .active_budget = active_polls,
                .active_polled = active_polled_success,
                .background_budget = background_budget_used,
                .background_inspected = background_inspected,
                .background_polled = background_polled,
                .total_polled = active_polled_success,
                .budget_tabs = budget.max_tabs_per_frame,
                .budget_exhausted_hint = budget_exhausted_hint,
                .active_spillover_hint = active_polled_success >= active_polls and self.tabs.items[active_idx].session.hasData(),
                .background_backlog_hint = background_backlog_hint,
            });
            return any_polled;
        }

        var cursor = self.background_poll_cursor % count;
        while (background_inspected < background_slots) {
            if (cursor == active_idx) {
                cursor = (cursor + 1) % count;
                continue;
            }
            if (try self.pollIndexIfReady(cursor)) {
                any_polled = true;
                background_polled += 1;
            }
            background_inspected += 1;
            cursor = (cursor + 1) % count;
        }
        self.background_poll_cursor = cursor;
        budget_exhausted_hint = background_inspected >= background_slots and background_slots >= @min(count - 1, budget.max_background_tabs_per_frame);
        background_backlog_hint = count > 1 and background_slots < (count - 1);
        self.recordPollMetrics(.{
            .tab_count = count,
            .active_index = active_idx,
            .active_budget = active_polls,
            .active_polled = active_polled_success,
            .background_budget = background_budget_used,
            .background_inspected = background_inspected,
            .background_polled = background_polled,
            .total_polled = active_polled_success + background_polled,
            .budget_tabs = budget.max_tabs_per_frame,
            .budget_exhausted_hint = budget_exhausted_hint,
            .active_spillover_hint = active_polled_success >= active_polls and self.tabs.items[active_idx].session.hasData(),
            .background_backlog_hint = background_backlog_hint,
        });
        return any_polled;
    }

    pub fn lastPollFrameMetrics(self: *const TerminalWorkspace) PollFrameMetrics {
        return self.last_poll_metrics;
    }

    fn pollIndexIfReady(self: *TerminalWorkspace, index: usize) !bool {
        if (index >= self.tabs.items.len) return false;
        const session = self.tabs.items[index].session;
        if (!session.hasData()) return false;
        try session.poll();
        return true;
    }

    fn updateInputPressure(self: *TerminalWorkspace, input_active_index: ?usize, has_input: bool) void {
        const count = self.tabs.items.len;
        const desired_index = if (has_input) normalizeIndex(input_active_index, count) else null;
        if (self.input_pressure_index) |current_index| {
            if (desired_index == null or desired_index.? != current_index) {
                if (current_index < count) {
                    self.tabs.items[current_index].session.setInputPressure(false);
                }
            }
        }
        if (desired_index) |idx| {
            self.tabs.items[idx].session.setInputPressure(true);
        }
        self.input_pressure_index = desired_index;
    }

    fn clearInputPressure(self: *TerminalWorkspace) void {
        if (self.input_pressure_index) |idx| {
            if (idx < self.tabs.items.len) {
                self.tabs.items[idx].session.setInputPressure(false);
            }
            self.input_pressure_index = null;
        }
    }

    fn normalizePollCursor(self: *TerminalWorkspace) void {
        const count = self.tabs.items.len;
        if (count == 0) {
            self.background_poll_cursor = 0;
            self.input_pressure_index = null;
            return;
        }
        self.background_poll_cursor %= count;
        if (self.input_pressure_index) |idx| {
            if (idx >= count) self.input_pressure_index = null;
        }
    }

    fn normalizeIndex(index: ?usize, count: usize) ?usize {
        if (count == 0) return null;
        if (index) |idx| {
            if (idx < count) return idx;
        }
        return null;
    }

    fn recordPollMetrics(self: *TerminalWorkspace, metrics: PollFrameMetrics) void {
        self.poll_metrics_seq +%= 1;
        self.last_poll_metrics = metrics;
        self.last_poll_metrics.seq = self.poll_metrics_seq;
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
