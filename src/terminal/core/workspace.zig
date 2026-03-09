const std = @import("std");
const session_mod = @import("terminal_session.zig");
const app_logger = @import("../../app_logger.zig");
const polling = @import("workspace_polling.zig");

pub const TerminalSession = session_mod.TerminalSession;
pub const TabId = u64;

const Tab = struct {
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
        return self.tabs.items[self.activeIndex()].session.shouldConfirmClose();
    }

    pub fn activeSessionHasData(self: *const TerminalWorkspace) bool {
        if (self.tabs.items.len == 0) return false;
        return self.tabs.items[self.activeIndex()].session.hasData();
    }

    pub fn activeSessionPublishedGeneration(self: *const TerminalWorkspace) u64 {
        if (self.tabs.items.len == 0) return 0;
        return self.tabs.items[self.activeIndex()].session.publishedGeneration();
    }

    pub fn activeSessionCurrentGeneration(self: *const TerminalWorkspace) u64 {
        if (self.tabs.items.len == 0) return 0;
        return self.tabs.items[self.activeIndex()].session.currentGeneration();
    }

    pub fn publishedGenerationAt(self: *const TerminalWorkspace, index: usize) ?u64 {
        if (index >= self.tabs.items.len) return null;
        return self.tabs.items[index].session.publishedGeneration();
    }

    pub fn shouldConfirmCloseAt(self: *const TerminalWorkspace, index: usize) bool {
        if (index >= self.tabs.items.len) return false;
        return self.tabs.items[index].session.shouldConfirmClose();
    }

    pub fn copyMetadataAt(
        self: *TerminalWorkspace,
        allocator: std.mem.Allocator,
        index: usize,
        title_out: *std.ArrayList(u8),
        cwd_out: *std.ArrayList(u8),
    ) !?TabMetadata {
        const session = self.sessionAt(index) orelse return null;
        const metadata = try session.copyMetadata(allocator, title_out, cwd_out);
        return .{
            .id = self.tabs.items[index].id,
            .title = metadata.title,
            .cwd = metadata.cwd,
            .alive = metadata.alive,
            .exit_code = metadata.exit_code,
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

    pub fn pollForFrame(self: *TerminalWorkspace, input_active_index: ?usize, has_input: bool) !bool {
        return polling.pollForFrame(self, input_active_index, has_input);
    }

    pub fn lastPollFrameMetrics(self: *const TerminalWorkspace) PollFrameMetrics {
        return self.last_poll_metrics;
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
