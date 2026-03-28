const std = @import("std");
const app_logger = @import("../../app_logger.zig");
const runtime_policy = @import("../runtime_policy.zig");
const terminal_widget_draw = @import("../../ui/widgets/terminal_widget_draw.zig");

const TerminalDrawLatencyMetrics = terminal_widget_draw.FrameLatencyMetrics;
const LogField = app_logger.Field;

pub const SleepPolicy = struct {
    active_sleep_s: f64,
    startup_window_s: f64,
    startup_sleep_s: f64,
    recent_generation_window_s: f64,
    short_idle_frame_limit: u32,
    medium_idle_frame_limit: u32,
    short_idle_sleep_s: f64,
    medium_idle_sleep_s: f64,
    deep_idle_sleep_s: f64,
};

pub const default_sleep_policy: SleepPolicy = .{
    .active_sleep_s = 0.001,
    .startup_window_s = 3.0,
    .startup_sleep_s = 0.016,
    .recent_generation_window_s = 0.25,
    .short_idle_frame_limit = 10,
    .medium_idle_frame_limit = 60,
    .short_idle_sleep_s = 0.016,
    .medium_idle_sleep_s = 0.033,
    .deep_idle_sleep_s = 0.100,
};

pub const PollMetrics = struct {
    tab_count: usize,
    active_lifecycle: runtime_policy.LifecycleTier,
    background_lifecycle: runtime_policy.LifecycleTier,
    active_work_class: runtime_policy.WorkClass,
    background_work_class: runtime_policy.WorkClass,
    active_polled: usize,
    background_polled: usize,
    total_polled: usize,
    active_budget: usize,
    background_budget: usize,
    background_inspected: usize,
    budget_tabs: usize,
    budget_exhausted_hint: bool,
    active_spillover_hint: bool,
    background_backlog_hint: bool,
};

pub const PollCounters = struct {
    epoch: u64,
    frames: u64,
    active_polled: u64,
    background_polled: u64,
    active_budget: u64,
    background_budget: u64,
    budget_exhausted_frames: u64,
    active_spillover_frames: u64,
    background_backlog_frames: u64,
};

pub const LatencyContext = struct {
    poll: ?PollMetrics = null,
    poll_counters: ?PollCounters = null,
    draw: ?TerminalDrawLatencyMetrics = null,
};

pub const Snapshot = struct {
    session_ptr: usize = 0,
    current_generation: u64 = 0,
    published_generation: u64 = 0,
    presented_generation: u64 = 0,
    redraw_pending: bool = false,
    parse_backlog: bool = false,
    output_pressure: bool = false,
};

pub fn observe(state: anytype, now: f64) Snapshot {
    const pacing = &state.terminal_frame_pacing;
    const frame_state = activeFrameState(state);
    const current_generation = frame_state.current_generation;
    const published_generation = frame_state.published_generation;
    if (current_generation != pacing.last_observed_current_generation) {
        pacing.last_observed_current_generation = current_generation;
        pacing.last_generation_change_time = now;
    }
    if (published_generation != pacing.last_observed_generation) {
        pacing.last_observed_generation = published_generation;
        pacing.last_generation_change_time = now;
    }

    const redraw_pending = published_generation != frame_state.presented_generation;
    const parse_backlog = current_generation != published_generation;
    return .{
        .session_ptr = frame_state.session_ptr,
        .current_generation = current_generation,
        .published_generation = published_generation,
        .presented_generation = frame_state.presented_generation,
        .redraw_pending = redraw_pending,
        .parse_backlog = parse_backlog,
        .output_pressure = frame_state.has_data or parse_backlog,
    };
}

pub fn consumeDrawMetrics(state: anytype) ?TerminalDrawLatencyMetrics {
    const pacing = &state.terminal_frame_pacing;
    const metrics = terminal_widget_draw.latestFrameLatencyMetrics();
    if (metrics.seq == 0 or metrics.seq == pacing.last_draw_seq) return null;
    pacing.last_draw_seq = metrics.seq;
    return metrics;
}

pub fn consumePollMetrics(state: anytype) ?PollMetrics {
    const State = @TypeOf(state.*);
    if (!@hasField(State, "terminal_workspace")) return null;

    if (state.terminal_workspace) |*workspace| {
        const pacing = &state.terminal_frame_pacing;
        const metrics = workspace.lastPollFrameMetrics();
        if (metrics.seq == 0 or metrics.seq == pacing.last_poll_seq) return null;
        pacing.last_poll_seq = metrics.seq;
        return .{
            .tab_count = metrics.tab_count,
            .active_lifecycle = metrics.active_lifecycle,
            .background_lifecycle = metrics.background_lifecycle,
            .active_work_class = metrics.active_work_class,
            .background_work_class = metrics.background_work_class,
            .active_polled = metrics.active_polled,
            .background_polled = metrics.background_polled,
            .total_polled = metrics.total_polled,
            .active_budget = metrics.active_budget,
            .background_budget = metrics.background_budget,
            .background_inspected = metrics.background_inspected,
            .budget_tabs = metrics.budget_tabs,
            .budget_exhausted_hint = metrics.budget_exhausted_hint,
            .active_spillover_hint = metrics.active_spillover_hint,
            .background_backlog_hint = metrics.background_backlog_hint,
        };
    }

    return null;
}

pub fn pollCounters(state: anytype) ?PollCounters {
    const State = @TypeOf(state.*);
    if (!@hasField(State, "terminal_workspace")) return null;

    if (state.terminal_workspace) |*workspace| {
        const counters = workspace.pollRuntimeCounters();
        return .{
            .epoch = counters.epoch,
            .frames = counters.frames,
            .active_polled = counters.active_polled,
            .background_polled = counters.background_polled,
            .active_budget = counters.active_budget,
            .background_budget = counters.background_budget,
            .budget_exhausted_frames = counters.budget_exhausted_frames,
            .active_spillover_frames = counters.active_spillover_frames,
            .background_backlog_frames = counters.background_backlog_frames,
        };
    }

    return null;
}

pub fn noteDraw(state: anytype) void {
    state.terminal_frame_pacing.idle_frames = 0;
}

pub fn noteIdle(state: anytype) void {
    state.terminal_frame_pacing.idle_frames +|= 1;
}

pub fn sleepDuration(state: anytype, now: f64, snapshot: Snapshot) f64 {
    return sleepDurationWithPolicy(default_sleep_policy, state, now, snapshot);
}

pub fn generationRecentlyAdvanced(state: anytype, now: f64) bool {
    return generationRecentlyAdvancedWithPolicy(default_sleep_policy, state, now);
}

pub fn generationRecentlyAdvancedWithPolicy(policy: SleepPolicy, state: anytype, now: f64) bool {
    const pacing = &state.terminal_frame_pacing;
    return pacing.last_generation_change_time > 0 and
        (now - pacing.last_generation_change_time) <= policy.recent_generation_window_s;
}

pub fn sleepDurationWithPolicy(policy: SleepPolicy, state: anytype, now: f64, snapshot: Snapshot) f64 {
    const pacing = &state.terminal_frame_pacing;
    const generation_recently_advanced = generationRecentlyAdvancedWithPolicy(policy, state, now);
    const intent = runtime_policy.terminalVisibleIntent(snapshot.output_pressure or snapshot.redraw_pending or generation_recently_advanced);
    const sleep_lifecycle = runtime_policy.terminalSleepLifecycle(
        pacing.idle_frames,
        policy.short_idle_frame_limit,
        policy.medium_idle_frame_limit,
    );
    return if (snapshot.redraw_pending or snapshot.output_pressure or generation_recently_advanced)
        policy.active_sleep_s
    else if (now < policy.startup_window_s)
        policy.startup_sleep_s
    else if (intent.isLatencySensitive() or sleep_lifecycle == .focused_visible)
        policy.short_idle_sleep_s
    else if (sleep_lifecycle == .visible_inactive)
        policy.medium_idle_sleep_s
    else
        policy.deep_idle_sleep_s;
}

fn frameIntentWithPolicy(policy: SleepPolicy, state: anytype, now: f64, snapshot: Snapshot) runtime_policy.RuntimeIntent {
    return runtime_policy.terminalVisibleIntent(
        snapshot.output_pressure or snapshot.redraw_pending or generationRecentlyAdvancedWithPolicy(policy, state, now),
    );
}

fn appendTerminalRuntimeFields(fields: []LogField, next: *usize) void {
    fields[next.*] = .{ .key = "runtime_kind", .value = .{ .string = runtime_policy.runtimeKindLabel(.terminal_session) } };
    next.* += 1;
}

fn appendTerminalPollRuntimeFields(fields: []LogField, next: *usize, poll_metrics: PollMetrics) void {
    appendTerminalRuntimeFields(fields, next);
    fields[next.*] = .{ .key = "term_active_lifecycle", .value = .{ .string = runtime_policy.lifecycleLabel(poll_metrics.active_lifecycle) } };
    next.* += 1;
    fields[next.*] = .{ .key = "term_background_lifecycle", .value = .{ .string = runtime_policy.lifecycleLabel(poll_metrics.background_lifecycle) } };
    next.* += 1;
    fields[next.*] = .{ .key = "term_active_work_class", .value = .{ .string = runtime_policy.workClassLabel(poll_metrics.active_work_class) } };
    next.* += 1;
    fields[next.*] = .{ .key = "term_background_work_class", .value = .{ .string = runtime_policy.workClassLabel(poll_metrics.background_work_class) } };
    next.* += 1;
}

fn appendLatencyBaseFields(fields: []LogField, next: *usize, poll_ms: f64, build_ms: f64, update_ms: f64, draw_ms: f64) void {
    fields[next.*] = .{ .key = "poll_ms", .value = .{ .float = poll_ms } };
    next.* += 1;
    fields[next.*] = .{ .key = "build_ms", .value = .{ .float = build_ms } };
    next.* += 1;
    fields[next.*] = .{ .key = "update_ms", .value = .{ .float = update_ms } };
    next.* += 1;
    fields[next.*] = .{ .key = "draw_ms", .value = .{ .float = draw_ms } };
    next.* += 1;
}

fn appendDrawLatencyFields(fields: []LogField, next: *usize, draw_metrics: TerminalDrawLatencyMetrics) void {
    fields[next.*] = .{ .key = "term_draw_lock_ms", .value = .{ .float = draw_metrics.lock_ms } };
    next.* += 1;
    fields[next.*] = .{ .key = "term_draw_cache_copy_ms", .value = .{ .float = draw_metrics.cache_copy_ms } };
    next.* += 1;
    fields[next.*] = .{ .key = "term_draw_texture_ms", .value = .{ .float = draw_metrics.texture_update_ms } };
    next.* += 1;
    fields[next.*] = .{ .key = "term_draw_overlay_ms", .value = .{ .float = draw_metrics.overlay_ms } };
    next.* += 1;
    fields[next.*] = .{ .key = "term_draw_render_ms", .value = .{ .float = draw_metrics.render_ms } };
    next.* += 1;
}

fn appendPollMetricFields(fields: []LogField, next: *usize, poll_metrics: PollMetrics) void {
    fields[next.*] = .{ .key = "term_poll_tabs", .value = .{ .unsigned = poll_metrics.tab_count } };
    next.* += 1;
    fields[next.*] = .{ .key = "term_poll_total", .value = .{ .unsigned = poll_metrics.total_polled } };
    next.* += 1;
    fields[next.*] = .{ .key = "term_poll_active", .value = .{ .unsigned = poll_metrics.active_polled } };
    next.* += 1;
    fields[next.*] = .{ .key = "term_poll_active_budget", .value = .{ .unsigned = poll_metrics.active_budget } };
    next.* += 1;
    fields[next.*] = .{ .key = "term_poll_bg", .value = .{ .unsigned = poll_metrics.background_polled } };
    next.* += 1;
    fields[next.*] = .{ .key = "term_poll_bg_budget", .value = .{ .unsigned = poll_metrics.background_budget } };
    next.* += 1;
    fields[next.*] = .{ .key = "term_poll_bg_inspected", .value = .{ .unsigned = poll_metrics.background_inspected } };
    next.* += 1;
    fields[next.*] = .{ .key = "term_poll_budget_tabs", .value = .{ .unsigned = poll_metrics.budget_tabs } };
    next.* += 1;
    fields[next.*] = .{ .key = "term_poll_budget_exhausted_hint", .value = .{ .boolean = poll_metrics.budget_exhausted_hint } };
    next.* += 1;
    fields[next.*] = .{ .key = "term_poll_active_spillover_hint", .value = .{ .boolean = poll_metrics.active_spillover_hint } };
    next.* += 1;
    fields[next.*] = .{ .key = "term_poll_background_backlog_hint", .value = .{ .boolean = poll_metrics.background_backlog_hint } };
    next.* += 1;
}

fn appendPollCounterFields(fields: []LogField, next: *usize, poll_counters: PollCounters) void {
    fields[next.*] = .{ .key = "term_poll_epoch", .value = .{ .unsigned = poll_counters.epoch } };
    next.* += 1;
    fields[next.*] = .{ .key = "term_poll_frames", .value = .{ .unsigned = poll_counters.frames } };
    next.* += 1;
    fields[next.*] = .{ .key = "term_poll_active_total", .value = .{ .unsigned = poll_counters.active_polled } };
    next.* += 1;
    fields[next.*] = .{ .key = "term_poll_background_total", .value = .{ .unsigned = poll_counters.background_polled } };
    next.* += 1;
    fields[next.*] = .{ .key = "term_poll_active_budget_total", .value = .{ .unsigned = poll_counters.active_budget } };
    next.* += 1;
    fields[next.*] = .{ .key = "term_poll_background_budget_total", .value = .{ .unsigned = poll_counters.background_budget } };
    next.* += 1;
    fields[next.*] = .{ .key = "term_poll_budget_exhausted_frames", .value = .{ .unsigned = poll_counters.budget_exhausted_frames } };
    next.* += 1;
    fields[next.*] = .{ .key = "term_poll_active_spillover_frames", .value = .{ .unsigned = poll_counters.active_spillover_frames } };
    next.* += 1;
    fields[next.*] = .{ .key = "term_poll_background_backlog_frames", .value = .{ .unsigned = poll_counters.background_backlog_frames } };
    next.* += 1;
}

pub fn logFramePacing(state: anytype, now: f64, snapshot: Snapshot, drew: bool, draw_ms: f64, sleep_s: ?f64) void {
    const log = app_logger.logger("terminal.frame");
    if (!log.enabled_file and !log.enabled_console) return;

    const pacing = &state.terminal_frame_pacing;
    const intent = frameIntentWithPolicy(default_sleep_policy, state, now, snapshot);
    const sleep_lifecycle = runtime_policy.terminalSleepLifecycle(
        pacing.idle_frames,
        default_sleep_policy.short_idle_frame_limit,
        default_sleep_policy.medium_idle_frame_limit,
    );
    const published_delta = snapshot.published_generation -| snapshot.presented_generation;
    const current_delta = snapshot.current_generation -| snapshot.published_generation;
    const draw_gap_ms = if (pacing.last_draw_time > 0) (now - pacing.last_draw_time) * 1000.0 else 0.0;

    log.logFields(.info, "frame_pacing", &.{
        .{ .key = "runtime_kind", .value = .{ .string = runtime_policy.runtimeKindLabel(intent.runtime) } },
        .{ .key = "lifecycle", .value = .{ .string = runtime_policy.lifecycleLabel(intent.lifecycle) } },
        .{ .key = "work_class", .value = .{ .string = runtime_policy.workClassLabel(intent.work_class) } },
        .{ .key = "sleep_lifecycle", .value = .{ .string = runtime_policy.lifecycleLabel(sleep_lifecycle) } },
        .{ .key = "drew", .value = .{ .boolean = drew } },
        .{ .key = "draw_ms", .value = .{ .float = draw_ms } },
        .{ .key = "draw_gap_ms", .value = .{ .float = draw_gap_ms } },
        .{ .key = "sleep_ms", .value = .{ .float = if (sleep_s) |v| v * 1000.0 else 0.0 } },
        .{ .key = "redraw_pending", .value = .{ .boolean = snapshot.redraw_pending } },
        .{ .key = "parse_backlog", .value = .{ .boolean = snapshot.parse_backlog } },
        .{ .key = "output_pressure", .value = .{ .boolean = snapshot.output_pressure } },
        .{ .key = "idle_frames", .value = .{ .unsigned = pacing.idle_frames } },
        .{ .key = "presented_generation", .value = .{ .unsigned = snapshot.presented_generation } },
        .{ .key = "published_generation", .value = .{ .unsigned = snapshot.published_generation } },
        .{ .key = "current_generation", .value = .{ .unsigned = snapshot.current_generation } },
        .{ .key = "published_delta", .value = .{ .unsigned = published_delta } },
        .{ .key = "current_delta", .value = .{ .unsigned = current_delta } },
    });

    if (drew) pacing.last_draw_time = now;

    const handoff_log = app_logger.logger("terminal.generation_handoff");
    if ((handoff_log.enabled_file or handoff_log.enabled_console) and
        (snapshot.redraw_pending or snapshot.parse_backlog or drew))
    {
        handoff_log.logf(
            .info,
            "stage=frame_state sid={x} drew={d} has_output_pressure={d} redraw_pending={d} parse_backlog={d} draw_ms={d:.2} sleep_ms={d:.2} gen={d}/{d}/{d}",
            .{
                snapshot.session_ptr,
                @intFromBool(drew),
                @intFromBool(snapshot.output_pressure),
                @intFromBool(snapshot.redraw_pending),
                @intFromBool(snapshot.parse_backlog),
                draw_ms,
                if (sleep_s) |v| v * 1000.0 else 0.0,
                snapshot.presented_generation,
                snapshot.published_generation,
                snapshot.current_generation,
            },
        );
    }
}

pub fn logInputLatency(state: anytype, poll_ms: f64, build_ms: f64, update_ms: f64, draw_ms: f64, term_ctx: LatencyContext) void {
    const poll_metrics = term_ctx.poll;
    const draw_metrics = term_ctx.draw;
    const poll_counters = term_ctx.poll_counters;

    if (poll_metrics != null and draw_metrics != null and poll_counters != null) {
        var fields: [32]LogField = undefined;
        var next: usize = 0;
        appendTerminalPollRuntimeFields(fields[0..], &next, poll_metrics.?);
        appendLatencyBaseFields(fields[0..], &next, poll_ms, build_ms, update_ms, draw_ms);
        appendDrawLatencyFields(fields[0..], &next, draw_metrics.?);
        appendPollMetricFields(fields[0..], &next, poll_metrics.?);
        appendPollCounterFields(fields[0..], &next, poll_counters.?);
        state.input_latency_logger.logFields(.info, "frame_latency", fields[0..next]);
        return;
    }

    if (draw_metrics != null) {
        var fields: [10]LogField = undefined;
        var next: usize = 0;
        appendTerminalRuntimeFields(fields[0..], &next);
        appendLatencyBaseFields(fields[0..], &next, poll_ms, build_ms, update_ms, draw_ms);
        appendDrawLatencyFields(fields[0..], &next, draw_metrics.?);
        state.input_latency_logger.logFields(.info, "frame_latency", fields[0..next]);
        return;
    }

    if (poll_metrics != null and poll_counters != null) {
        var fields: [27]LogField = undefined;
        var next: usize = 0;
        appendTerminalPollRuntimeFields(fields[0..], &next, poll_metrics.?);
        appendLatencyBaseFields(fields[0..], &next, poll_ms, build_ms, update_ms, draw_ms);
        appendPollMetricFields(fields[0..], &next, poll_metrics.?);
        appendPollCounterFields(fields[0..], &next, poll_counters.?);
        state.input_latency_logger.logFields(.info, "frame_latency", fields[0..next]);
        return;
    }

    var fields: [5]LogField = undefined;
    var next: usize = 0;
    appendTerminalRuntimeFields(fields[0..], &next);
    appendLatencyBaseFields(fields[0..], &next, poll_ms, build_ms, update_ms, draw_ms);
    state.input_latency_logger.logFields(.info, "frame_latency", fields[0..next]);
}

fn activeFrameState(state: anytype) struct {
    has_data: bool,
    session_ptr: usize,
    current_generation: u64,
    published_generation: u64,
    presented_generation: u64,
} {
    const State = @TypeOf(state.*);
    if (!@hasField(State, "terminal_workspace")) {
        return .{
            .has_data = false,
            .session_ptr = 0,
            .current_generation = 0,
            .published_generation = 0,
            .presented_generation = 0,
        };
    }

    if (state.terminal_workspace) |*workspace| {
        const frame_state = workspace.activeFrameState();
        return .{
            .has_data = frame_state.has_data,
            .session_ptr = frame_state.session_ptr,
            .current_generation = frame_state.current_generation,
            .published_generation = frame_state.published_generation,
            .presented_generation = frame_state.presented_generation,
        };
    }
    return .{
        .has_data = false,
        .session_ptr = 0,
        .current_generation = 0,
        .published_generation = 0,
        .presented_generation = 0,
    };
}

test "default sleep policy stays hot while redraw or backlog is active" {
    const State = struct {
        terminal_frame_pacing: struct {
            idle_frames: u32 = 0,
            last_generation_change_time: f64 = 0,
        } = .{},
    };

    var state = State{};
    try std.testing.expectEqual(default_sleep_policy.active_sleep_s, sleepDurationWithPolicy(default_sleep_policy, &state, 10.0, .{
        .redraw_pending = true,
        .output_pressure = false,
    }));
    try std.testing.expectEqual(default_sleep_policy.active_sleep_s, sleepDurationWithPolicy(default_sleep_policy, &state, 10.0, .{
        .redraw_pending = false,
        .output_pressure = true,
    }));
}

test "default sleep policy backs off by startup and idle tiers" {
    const State = struct {
        terminal_frame_pacing: struct {
            idle_frames: u32 = 0,
            last_generation_change_time: f64 = 0,
        } = .{},
    };

    var state = State{};
    try std.testing.expectEqual(default_sleep_policy.startup_sleep_s, sleepDurationWithPolicy(default_sleep_policy, &state, 2.0, .{}));

    state.terminal_frame_pacing.idle_frames = default_sleep_policy.short_idle_frame_limit - 1;
    try std.testing.expectEqual(default_sleep_policy.short_idle_sleep_s, sleepDurationWithPolicy(default_sleep_policy, &state, 10.0, .{}));

    state.terminal_frame_pacing.idle_frames = default_sleep_policy.short_idle_frame_limit;
    try std.testing.expectEqual(default_sleep_policy.medium_idle_sleep_s, sleepDurationWithPolicy(default_sleep_policy, &state, 10.0, .{}));

    state.terminal_frame_pacing.idle_frames = default_sleep_policy.medium_idle_frame_limit;
    try std.testing.expectEqual(default_sleep_policy.deep_idle_sleep_s, sleepDurationWithPolicy(default_sleep_policy, &state, 10.0, .{}));
}

test "default sleep policy stays hot briefly after generation advancement" {
    const State = struct {
        terminal_frame_pacing: struct {
            idle_frames: u32 = 0,
            last_generation_change_time: f64 = 0,
        } = .{},
    };

    var state = State{};
    state.terminal_frame_pacing.last_generation_change_time = 9.9;
    try std.testing.expectEqual(default_sleep_policy.active_sleep_s, sleepDurationWithPolicy(default_sleep_policy, &state, 10.0, .{}));

    state.terminal_frame_pacing.last_generation_change_time = 9.0;
    try std.testing.expectEqual(default_sleep_policy.short_idle_sleep_s, sleepDurationWithPolicy(default_sleep_policy, &state, 10.0, .{}));
}

test "observe keeps redraw pending until published generation is presented" {
    const Workspace = struct {
        fn activeFrameState(_: *@This()) struct {
            has_data: bool,
            session_ptr: usize,
            current_generation: u64,
            published_generation: u64,
            presented_generation: u64,
        } {
            return .{
                .has_data = false,
                .session_ptr = 0x1234,
                .current_generation = 14,
                .published_generation = 13,
                .presented_generation = 12,
            };
        }
    };
    const State = struct {
        terminal_frame_pacing: @import("../app_state_types.zig").TerminalFramePacingState = .{},
        terminal_workspace: ?Workspace = Workspace{},
    };

    var state = State{};
    const snapshot = observe(&state, 10.0);
    try std.testing.expect(snapshot.redraw_pending);
    try std.testing.expectEqual(@as(u64, 12), snapshot.presented_generation);
    try std.testing.expectEqual(@as(u64, 13), snapshot.published_generation);
}
