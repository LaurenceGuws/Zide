const terminal_widget_draw = @import("../ui/widgets/terminal_widget_draw.zig");

const TerminalDrawLatencyMetrics = terminal_widget_draw.FrameLatencyMetrics;

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
    current_generation: u64 = 0,
    published_generation: u64 = 0,
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
        .current_generation = current_generation,
        .published_generation = published_generation,
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

pub fn sleepDuration(state: anytype, now: f64, snapshot: Snapshot) f64 {
    const pacing = &state.terminal_frame_pacing;
    const generation_recently_advanced = pacing.last_generation_change_time > 0 and
        (now - pacing.last_generation_change_time) <= 0.25;
    return if (snapshot.redraw_pending or snapshot.output_pressure or generation_recently_advanced)
        0.001
    else if (now < 3.0)
        0.016
    else if (state.idle_frames < 10)
        0.016
    else if (state.idle_frames < 60)
        0.033
    else
        0.100;
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
    current_generation: u64,
    published_generation: u64,
} {
    const State = @TypeOf(state.*);
    if (!@hasField(State, "terminal_workspace")) {
        return .{
            .has_data = false,
            .current_generation = 0,
            .published_generation = 0,
        };
    }

    if (state.terminal_workspace) |*workspace| {
        const frame_state = workspace.activeFrameState();
        return .{
            .has_data = frame_state.has_data,
            .current_generation = frame_state.current_generation,
            .published_generation = frame_state.published_generation,
        };
    }
    return .{
        .has_data = false,
        .current_generation = 0,
        .published_generation = 0,
    };
}
