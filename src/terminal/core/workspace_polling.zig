const std = @import("std");
const app_logger = @import("../../app_logger.zig");
const runtime_policy = @import("../../app/runtime_policy.zig");

pub fn pollBudgeted(self: anytype, input_active_index: ?usize, policy: anytype) !bool {
    const count = self.tabs.items.len;
    const active_intent = policy.active_intent;
    const background_intent = policy.background_intent;
    if (count == 0) {
        clearInputPressure(self);
        self.background_poll_cursor = 0;
        recordPollMetrics(self, .{});
        return false;
    }

    normalizePollCursor(self);
    updateInputPressure(self, input_active_index, policy.active_intent.user_input_active);

    const active_idx = normalizeIndex(input_active_index, count) orelse self.activeIndex();
    if (policy.max_tabs_per_frame == 0) {
        recordPollMetrics(self, .{
            .tab_count = count,
            .active_index = active_idx,
            .active_lifecycle = active_intent.lifecycle,
            .background_lifecycle = background_intent.lifecycle,
            .active_work_class = active_intent.work_class,
            .background_work_class = background_intent.work_class,
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
            .active_lifecycle = active_intent.lifecycle,
            .background_lifecycle = background_intent.lifecycle,
            .active_work_class = active_intent.work_class,
            .background_work_class = background_intent.work_class,
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
            .active_lifecycle = active_intent.lifecycle,
            .background_lifecycle = background_intent.lifecycle,
            .active_work_class = active_intent.work_class,
            .background_work_class = background_intent.work_class,
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
        .active_lifecycle = active_intent.lifecycle,
        .background_lifecycle = background_intent.lifecycle,
        .active_work_class = active_intent.work_class,
        .background_work_class = background_intent.work_class,
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
        wake_log.logFields(.info, "workspace_poll", &.{
            .{ .key = "session_ptr", .value = .{ .unsigned = session_ptr } },
            .{ .key = "tabs", .value = .{ .unsigned = count } },
            .{ .key = "active_idx", .value = .{ .unsigned = if (active_idx) |idx| idx else std.math.maxInt(usize) } },
            .{ .key = "has_input", .value = .{ .boolean = policy.active_intent.user_input_active } },
            .{ .key = "active_lifecycle", .value = .{ .string = runtime_policy.lifecycleLabel(policy.active_intent.lifecycle) } },
            .{ .key = "background_lifecycle", .value = .{ .string = runtime_policy.lifecycleLabel(policy.background_intent.lifecycle) } },
            .{ .key = "active_work_class", .value = .{ .string = runtime_policy.workClassLabel(policy.active_intent.work_class) } },
            .{ .key = "background_work_class", .value = .{ .string = runtime_policy.workClassLabel(policy.background_intent.work_class) } },
            .{ .key = "any_polled", .value = .{ .boolean = any_polled } },
            .{ .key = "active_has_data_pre", .value = .{ .boolean = active_has_data_pre } },
            .{ .key = "active_has_data_post", .value = .{ .boolean = active_has_data_post } },
            .{ .key = "current_generation_pre", .value = .{ .unsigned = current_pre } },
            .{ .key = "current_generation_post", .value = .{ .unsigned = current_post } },
            .{ .key = "published_changed", .value = .{ .boolean = active_published_changed } },
            .{ .key = "published_generation_pre", .value = .{ .unsigned = published_pre } },
            .{ .key = "published_generation_post", .value = .{ .unsigned = published_post } },
            .{ .key = "presented_generation_pre", .value = .{ .unsigned = presented_pre } },
            .{ .key = "presented_generation_post", .value = .{ .unsigned = presented_post } },
        });
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
    self.poll_runtime_counters.frames +%= 1;
    self.poll_runtime_counters.active_polled +%= @intCast(self.last_poll_metrics.active_polled);
    self.poll_runtime_counters.background_polled +%= @intCast(self.last_poll_metrics.background_polled);
    self.poll_runtime_counters.active_budget +%= @intCast(self.last_poll_metrics.active_budget);
    self.poll_runtime_counters.background_budget +%= @intCast(self.last_poll_metrics.background_budget);
    if (self.last_poll_metrics.budget_exhausted_hint) self.poll_runtime_counters.budget_exhausted_frames +%= 1;
    if (self.last_poll_metrics.active_spillover_hint) self.poll_runtime_counters.active_spillover_frames +%= 1;
    if (self.last_poll_metrics.background_backlog_hint) self.poll_runtime_counters.background_backlog_frames +%= 1;
}
