const std = @import("std");
const app_logger = @import("../../app_logger.zig");
const terminal_widget_draw = @import("../../ui/widgets/terminal_widget_draw.zig");

const TerminalDrawLatencyMetrics = terminal_widget_draw.FrameLatencyMetrics;

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

pub const LatencyContext = struct {
    poll: ?PollMetrics = null,
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

    const redraw_pending = published_generation != pacing.last_drawn_generation;
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

pub fn noteDraw(state: anytype) void {
    state.terminal_frame_pacing.idle_frames = 0;
}

pub fn noteIdle(state: anytype) void {
    state.terminal_frame_pacing.idle_frames +|= 1;
}

pub fn sleepDuration(state: anytype, now: f64, snapshot: Snapshot) f64 {
    return sleepDurationWithPolicy(default_sleep_policy, state, now, snapshot);
}

pub fn sleepDurationWithPolicy(policy: SleepPolicy, state: anytype, now: f64, snapshot: Snapshot) f64 {
    const pacing = &state.terminal_frame_pacing;
    const generation_recently_advanced = pacing.last_generation_change_time > 0 and
        (now - pacing.last_generation_change_time) <= policy.recent_generation_window_s;
    return if (snapshot.redraw_pending or snapshot.output_pressure or generation_recently_advanced)
        policy.active_sleep_s
    else if (now < policy.startup_window_s)
        policy.startup_sleep_s
    else if (pacing.idle_frames < policy.short_idle_frame_limit)
        policy.short_idle_sleep_s
    else if (pacing.idle_frames < policy.medium_idle_frame_limit)
        policy.medium_idle_sleep_s
    else
        policy.deep_idle_sleep_s;
}

pub fn logFramePacing(state: anytype, now: f64, snapshot: Snapshot, drew: bool, draw_ms: f64, sleep_s: ?f64) void {
    const log = app_logger.logger("terminal.frame");
    if (!log.enabled_file and !log.enabled_console) return;

    const pacing = &state.terminal_frame_pacing;
    const published_delta = snapshot.published_generation -| pacing.last_drawn_generation;
    const current_delta = snapshot.current_generation -| snapshot.published_generation;
    const draw_gap_ms = if (pacing.last_draw_time > 0) (now - pacing.last_draw_time) * 1000.0 else 0.0;

    log.logf(
        .info,
        "drew={d} draw_ms={d:.2} draw_gap_ms={d:.2} sleep_ms={d:.2} redraw_pending={d} parse_backlog={d} output_pressure={d} idle_frames={d} gen={d}/{d}/{d} delta={d}/{d}",
        .{
            @intFromBool(drew),
            draw_ms,
            draw_gap_ms,
            if (sleep_s) |v| v * 1000.0 else 0.0,
            @intFromBool(snapshot.redraw_pending),
            @intFromBool(snapshot.parse_backlog),
            @intFromBool(snapshot.output_pressure),
            pacing.idle_frames,
            pacing.last_drawn_generation,
            snapshot.published_generation,
            snapshot.current_generation,
            published_delta,
            current_delta,
        },
    );

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

    if (poll_metrics != null and draw_metrics != null) {
        state.input_latency_logger.logf(
            .info,
            "poll_ms={d:.2} build_ms={d:.2} update_ms={d:.2} draw_ms={d:.2} term_draw_lock_ms={d:.2} term_draw_cache_copy_ms={d:.2} term_draw_texture_ms={d:.2} term_draw_overlay_ms={d:.2} term_draw_render_ms={d:.2} term_poll_tabs={d} term_poll_total={d} term_poll_active={d}/{d} term_poll_bg={d}/{d} term_poll_bg_inspected={d} term_poll_budget_tabs={d} term_poll_hints={d}/{d}/{d}",
            .{
                poll_ms,
                build_ms,
                update_ms,
                draw_ms,
                draw_metrics.?.lock_ms,
                draw_metrics.?.cache_copy_ms,
                draw_metrics.?.texture_update_ms,
                draw_metrics.?.overlay_ms,
                draw_metrics.?.render_ms,
                poll_metrics.?.tab_count,
                poll_metrics.?.total_polled,
                poll_metrics.?.active_polled,
                poll_metrics.?.active_budget,
                poll_metrics.?.background_polled,
                poll_metrics.?.background_budget,
                poll_metrics.?.background_inspected,
                poll_metrics.?.budget_tabs,
                @intFromBool(poll_metrics.?.budget_exhausted_hint),
                @intFromBool(poll_metrics.?.active_spillover_hint),
                @intFromBool(poll_metrics.?.background_backlog_hint),
            },
        );
        return;
    }

    if (draw_metrics != null) {
        state.input_latency_logger.logf(
            .info,
            "poll_ms={d:.2} build_ms={d:.2} update_ms={d:.2} draw_ms={d:.2} term_draw_lock_ms={d:.2} term_draw_cache_copy_ms={d:.2} term_draw_texture_ms={d:.2} term_draw_overlay_ms={d:.2} term_draw_render_ms={d:.2}",
            .{
                poll_ms,
                build_ms,
                update_ms,
                draw_ms,
                draw_metrics.?.lock_ms,
                draw_metrics.?.cache_copy_ms,
                draw_metrics.?.texture_update_ms,
                draw_metrics.?.overlay_ms,
                draw_metrics.?.render_ms,
            },
        );
        return;
    }

    if (poll_metrics != null) {
        state.input_latency_logger.logf(
            .info,
            "poll_ms={d:.2} build_ms={d:.2} update_ms={d:.2} draw_ms={d:.2} term_poll_tabs={d} term_poll_total={d} term_poll_active={d}/{d} term_poll_bg={d}/{d} term_poll_bg_inspected={d} term_poll_budget_tabs={d} term_poll_hints={d}/{d}/{d}",
            .{
                poll_ms,
                build_ms,
                update_ms,
                draw_ms,
                poll_metrics.?.tab_count,
                poll_metrics.?.total_polled,
                poll_metrics.?.active_polled,
                poll_metrics.?.active_budget,
                poll_metrics.?.background_polled,
                poll_metrics.?.background_budget,
                poll_metrics.?.background_inspected,
                poll_metrics.?.budget_tabs,
                @intFromBool(poll_metrics.?.budget_exhausted_hint),
                @intFromBool(poll_metrics.?.active_spillover_hint),
                @intFromBool(poll_metrics.?.background_backlog_hint),
            },
        );
        return;
    }

    state.input_latency_logger.logf(
        .info,
        "poll_ms={d:.2} build_ms={d:.2} update_ms={d:.2} draw_ms={d:.2}",
        .{ poll_ms, build_ms, update_ms, draw_ms },
    );
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
