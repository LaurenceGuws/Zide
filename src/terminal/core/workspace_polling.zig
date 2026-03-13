const std = @import("std");
const app_logger = @import("../../app_logger.zig");

pub fn pollBudgeted(self: anytype, input_active_index: ?usize, policy: anytype) !bool {
    const count = self.tabs.items.len;
    if (count == 0) {
        clearInputPressure(self);
        self.background_poll_cursor = 0;
        recordPollMetrics(self, .{});
        return false;
    }

    normalizePollCursor(self);
    updateInputPressure(self, input_active_index, policy.has_input);

    const active_idx = normalizeIndex(input_active_index, count) orelse self.activeIndex();
    if (policy.max_tabs_per_frame == 0) {
        recordPollMetrics(self, .{
            .tab_count = count,
            .active_index = active_idx,
            .budget_tabs = 0,
            .background_backlog_hint = count > 1,
        });
        return false;
    }

    var any_polled = false;
    const active_polls = @max(@as(usize, 1), policy.max_active_polls_per_frame);
    var active_polled_success: usize = 0;
    var active_polled: usize = 0;
    while (active_polled < active_polls) : (active_polled += 1) {
        if (try pollIndexIfReady(self, active_idx)) {
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

    if (count == 1 or policy.max_tabs_per_frame == 1 or policy.max_background_tabs_per_frame == 0) {
        background_backlog_hint = count > 1 and (policy.max_tabs_per_frame <= 1 or policy.max_background_tabs_per_frame == 0);
        self.background_poll_cursor = (active_idx + 1) % count;
        recordPollMetrics(self, .{
            .tab_count = count,
            .active_index = active_idx,
            .active_budget = active_polls,
            .active_polled = active_polled_success,
            .background_budget = background_budget_used,
            .background_inspected = background_inspected,
            .background_polled = background_polled,
            .total_polled = active_polled_success,
            .budget_tabs = policy.max_tabs_per_frame,
            .budget_exhausted_hint = budget_exhausted_hint,
            .active_spillover_hint = activePolledBacklogHint(self, active_idx, active_polled_success, active_polls),
            .background_backlog_hint = background_backlog_hint,
        });
        return any_polled;
    }

    const remaining_slots = policy.max_tabs_per_frame - 1;
    const background_slots = @min(remaining_slots, policy.max_background_tabs_per_frame);
    background_budget_used = background_slots;
    if (background_slots == 0) {
        background_backlog_hint = count > 1;
        self.background_poll_cursor = (active_idx + 1) % count;
        recordPollMetrics(self, .{
            .tab_count = count,
            .active_index = active_idx,
            .active_budget = active_polls,
            .active_polled = active_polled_success,
            .background_budget = background_budget_used,
            .background_inspected = background_inspected,
            .background_polled = background_polled,
            .total_polled = active_polled_success,
            .budget_tabs = policy.max_tabs_per_frame,
            .budget_exhausted_hint = budget_exhausted_hint,
            .active_spillover_hint = activePolledBacklogHint(self, active_idx, active_polled_success, active_polls),
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
        if (try pollIndexIfReady(self, cursor)) {
            any_polled = true;
            background_polled += 1;
        }
        background_inspected += 1;
        cursor = (cursor + 1) % count;
    }
    self.background_poll_cursor = cursor;
    budget_exhausted_hint = background_inspected >= background_slots and background_slots >= @min(count - 1, policy.max_background_tabs_per_frame);
    background_backlog_hint = count > 1 and background_slots < (count - 1);
    recordPollMetrics(self, .{
        .tab_count = count,
        .active_index = active_idx,
        .active_budget = active_polls,
        .active_polled = active_polled_success,
        .background_budget = background_budget_used,
        .background_inspected = background_inspected,
        .background_polled = background_polled,
        .total_polled = active_polled_success + background_polled,
        .budget_tabs = policy.max_tabs_per_frame,
        .budget_exhausted_hint = budget_exhausted_hint,
        .active_spillover_hint = activePolledBacklogHint(self, active_idx, active_polled_success, active_polls),
        .background_backlog_hint = background_backlog_hint,
    });
    return any_polled;
}

pub fn pollForFrame(self: anytype, input_active_index: ?usize, policy: anytype) !@TypeOf(self.*).PollFrameResult {
    const wake_log = app_logger.logger("terminal.wake");
    const count = self.tabs.items.len;
    const active_idx = normalizeIndex(input_active_index, count);
    const session_ptr = if (active_idx) |idx|
        @intFromPtr(self.tabs.items[idx].session)
    else
        0;
    const current_pre = if (active_idx) |idx|
        self.tabs.items[idx].session.currentGeneration()
    else
        0;
    const published_pre = if (active_idx) |idx|
        self.tabs.items[idx].session.publishedGeneration()
    else
        0;
    const presented_pre = if (active_idx) |idx|
        self.tabs.items[idx].session.presentedGeneration()
    else
        0;
    const active_has_data_pre = if (active_idx) |idx|
        self.tabs.items[idx].session.hasData()
    else
        false;
    const any_polled = try pollBudgeted(self, input_active_index, policy);
    const current_post = if (active_idx) |idx|
        self.tabs.items[idx].session.currentGeneration()
    else
        0;
    const published_post = if (active_idx) |idx|
        self.tabs.items[idx].session.publishedGeneration()
    else
        0;
    const presented_post = if (active_idx) |idx|
        self.tabs.items[idx].session.presentedGeneration()
    else
        0;
    const active_has_data_post = if (active_idx) |idx|
        self.tabs.items[idx].session.hasData()
    else
        false;
    const active_published_changed = published_post != published_pre;
    if (wake_log.enabled_file or wake_log.enabled_console) {
        wake_log.logf(
            .info,
            "stage=workspace_poll sid={x} tabs={d} active_idx={d} has_input={d} any_polled={d} active_has_data={d}->{d} cur={d}->{d} published_changed={d} pub={d}->{d} presented={d}->{d}",
            .{
                session_ptr,
                count,
                if (active_idx) |idx| idx else std.math.maxInt(usize),
                @intFromBool(policy.has_input),
                @intFromBool(any_polled),
                @intFromBool(active_has_data_pre),
                @intFromBool(active_has_data_post),
                current_pre,
                current_post,
                @intFromBool(active_published_changed),
                published_pre,
                published_post,
                presented_pre,
                presented_post,
            },
        );
    }
    return @TypeOf(self.*).PollFrameResult{
        .any_polled = any_polled,
        .active_published_changed = active_published_changed,
    };
}

pub fn clearInputPressure(self: anytype) void {
    if (self.input_pressure_index) |idx| {
        if (idx < self.tabs.items.len) {
            self.tabs.items[idx].session.setInputPressure(false);
        }
        self.input_pressure_index = null;
    }
}

pub fn normalizePollCursor(self: anytype) void {
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

fn pollIndexIfReady(self: anytype, index: usize) !bool {
    if (index >= self.tabs.items.len) return false;
    const session = self.tabs.items[index].session;
    if (!session.hasData()) return false;
    try session.poll();
    return true;
}

fn updateInputPressure(self: anytype, input_active_index: ?usize, has_input: bool) void {
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

fn normalizeIndex(index: ?usize, count: usize) ?usize {
    if (count == 0) return null;
    if (index) |idx| {
        if (idx < count) return idx;
    }
    return null;
}

fn activePolledBacklogHint(self: anytype, active_idx: usize, active_polled_success: usize, active_polls: usize) bool {
    if (active_polled_success < active_polls) return false;
    if (active_idx >= self.tabs.items.len) return false;
    return self.tabs.items[active_idx].session.pollBacklogHint();
}

fn recordPollMetrics(self: anytype, metrics: @TypeOf(self.last_poll_metrics)) void {
    self.poll_metrics_seq +%= 1;
    self.last_poll_metrics = metrics;
    self.last_poll_metrics.seq = self.poll_metrics_seq;
}
