const app_shell = @import("../app_shell.zig");
const app_logger = @import("../app_logger.zig");
const shared_types = @import("../types/mod.zig");
const terminal_widget_draw = @import("../ui/widgets/terminal_widget_draw.zig");

const input_types = shared_types.input;
const TerminalDrawLatencyMetrics = terminal_widget_draw.FrameLatencyMetrics;

var last_terminal_draw_seq: u64 = 0;
var last_terminal_poll_seq: u64 = 0;
var terminal_pressure_since: ?f64 = null;
var last_terminal_statebug_log_time: f64 = 0.0;
var last_terminal_observed_generation: u64 = 0;
var last_terminal_drawn_generation: u64 = 0;
var last_terminal_generation_change_time: f64 = 0.0;

const TerminalLatencyContext = struct {
    poll: ?PollMetrics = null,
    draw: ?TerminalDrawLatencyMetrics = null,
};

const PollMetrics = struct {
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

pub const Hooks = struct {
    draw: *const fn (*anyopaque) void,
    maybe_log_metrics: *const fn (*anyopaque, f64) void,
};

fn maybeConsumeTerminalDrawMetrics() ?TerminalDrawLatencyMetrics {
    const metrics = terminal_widget_draw.latestFrameLatencyMetrics();
    if (metrics.seq == 0 or metrics.seq == last_terminal_draw_seq) return null;
    last_terminal_draw_seq = metrics.seq;
    return metrics;
}

fn maybeConsumeTerminalPollMetrics(state: anytype) ?PollMetrics {
    const State = @TypeOf(state.*);
    if (!@hasField(State, "terminal_workspace")) return null;

    if (state.terminal_workspace) |*workspace| {
        const metrics = workspace.lastPollFrameMetrics();
        if (metrics.seq == 0 or metrics.seq == last_terminal_poll_seq) return null;
        last_terminal_poll_seq = metrics.seq;
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

fn logInputLatency(state: anytype, poll_ms: f64, build_ms: f64, update_ms: f64, draw_ms: f64, term_ctx: TerminalLatencyContext) void {
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

fn hasTerminalOutputPressure(state: anytype) bool {
    const State = @TypeOf(state.*);
    if (!@hasField(State, "terminal_workspace")) return false;

    if (state.terminal_workspace) |*workspace| {
        if (workspace.activeSession()) |session| {
            return session.hasData();
        }
    }
    return false;
}

fn latestTerminalPollSeq(state: anytype) u64 {
    const State = @TypeOf(state.*);
    if (!@hasField(State, "terminal_workspace")) return 0;

    if (state.terminal_workspace) |*workspace| {
        return workspace.lastPollFrameMetrics().seq;
    }
    return 0;
}

fn latestTerminalPublishedGeneration(state: anytype) u64 {
    const State = @TypeOf(state.*);
    if (!@hasField(State, "terminal_workspace")) return 0;

    if (state.terminal_workspace) |*workspace| {
        if (workspace.activeSession()) |session| {
            return session.publishedGeneration();
        }
    }
    return 0;
}

pub fn handle(
    state: anytype,
    ctx: *anyopaque,
    input_batch: *input_types.InputBatch,
    poll_ms: f64,
    build_ms: f64,
    update_ms: f64,
    hooks: Hooks,
) void {
    var draw_ms: f64 = 0.0;
    const now = app_shell.getTime();
    const active_generation = latestTerminalPublishedGeneration(state);
    if (active_generation != last_terminal_observed_generation) {
        last_terminal_observed_generation = active_generation;
        last_terminal_generation_change_time = now;
    }
    const terminal_redraw_pending = active_generation != last_terminal_drawn_generation;
    const terminal_output_pressure = hasTerminalOutputPressure(state);
    if (terminal_redraw_pending) {
        state.needs_redraw = true;
    }

    if (state.needs_redraw) {
        const draw_start = app_shell.getTime();
        hooks.draw(ctx);
        const draw_end = app_shell.getTime();
        draw_ms = (draw_end - draw_start) * 1000.0;
        const terminal_draw_metrics = maybeConsumeTerminalDrawMetrics();
        if (terminal_draw_metrics) |metrics| {
            last_terminal_drawn_generation = metrics.generation;
        }
        state.metrics.recordDraw(draw_start, draw_end);
        if (state.perf_mode and state.perf_frames_done > 0) {
            const draw_ms_perf = (draw_end - draw_start) * 1000.0;
            const editor_idx = if (state.editors.items.len > 0) @min(state.active_tab, state.editors.items.len - 1) else 0;
            if (state.editors.items.len > 0) {
                const editor = state.editors.items[editor_idx];
                state.perf_logger.logf(
                    .info,
                    "frame={d} draw_ms={d:.2} scroll_line={d} scroll_row_offset={d} scroll_col={d}",
                    .{ state.perf_frames_done, draw_ms_perf, editor.scroll_line, editor.scroll_row_offset, editor.scroll_col },
                );
            } else {
                state.perf_logger.logf(.info, "frame={d} draw_ms={d:.2}", .{ state.perf_frames_done, draw_ms_perf });
            }
        }
        hooks.maybe_log_metrics(ctx, draw_end);
        state.needs_redraw = false;
        state.idle_frames = 0;
        terminal_pressure_since = null;
        if (input_batch.events.items.len > 0) {
            const total_ms = poll_ms + build_ms + update_ms + draw_ms;
            if (total_ms >= 1.0) {
                logInputLatency(state, poll_ms, build_ms, update_ms, draw_ms, .{
                    .poll = maybeConsumeTerminalPollMetrics(state),
                    .draw = terminal_draw_metrics,
                });
            }
        }
        return;
    }

    state.idle_frames +|= 1;
    if (terminal_redraw_pending) {
        if (terminal_pressure_since == null) terminal_pressure_since = now;
        const pressure_ms = (now - terminal_pressure_since.?) * 1000.0;
        if (pressure_ms >= 100.0 and (now - last_terminal_statebug_log_time) >= 0.1) {
            last_terminal_statebug_log_time = now;
            const statebug_log = app_logger.logger("terminal.ui.statebug");
            statebug_log.logf(
                .info,
                "idle_generation_backlog_ms={d:.2} idle_frames={d} needs_redraw={d} pending_gen={d} drawn_gen={d} draw_seq={d} poll_seq={d} win_px={d}x{d}",
                .{
                    pressure_ms,
                    state.idle_frames,
                    @intFromBool(state.needs_redraw),
                    active_generation,
                    last_terminal_drawn_generation,
                    terminal_widget_draw.latestFrameLatencyMetrics().seq,
                    latestTerminalPollSeq(state),
                    state.shell.width(),
                    state.shell.height(),
                },
            );
        }
    } else {
        terminal_pressure_since = null;
    }

    if (input_batch.events.items.len > 0) {
        const total_ms = poll_ms + build_ms + update_ms;
        if (total_ms >= 1.0) {
            logInputLatency(state, poll_ms, build_ms, update_ms, 0.0, .{
                .poll = maybeConsumeTerminalPollMetrics(state),
                .draw = null,
            });
        }
    }

    const uptime = now;
    const generation_recently_advanced = last_terminal_generation_change_time > 0 and (now - last_terminal_generation_change_time) <= 0.25;
    const sleep_ms: f64 = if (terminal_redraw_pending or terminal_output_pressure or generation_recently_advanced)
        0.001
    else if (uptime < 3.0)
        0.016
    else if (state.idle_frames < 10)
        0.016
    else if (state.idle_frames < 60)
        0.033
    else
        0.100;

    if (!terminal_redraw_pending and !terminal_output_pressure and !generation_recently_advanced and sleep_ms >= 0.033) {
        const gen_advance_ms = (now - last_terminal_generation_change_time) * 1000.0;
        if (last_terminal_generation_change_time > 0 and gen_advance_ms <= 200.0 and (now - last_terminal_statebug_log_time) >= 0.1) {
            last_terminal_statebug_log_time = now;
            app_logger.logger("terminal.ui.statebug").logf(
                .info,
                "idle_backoff_after_gen_advance gen={d} drawn_gen={d} gen_advance_ms={d:.2} sleep_ms={d:.3} hasData={d} idle_frames={d} win_px={d}x{d}",
                .{
                    active_generation,
                    last_terminal_drawn_generation,
                    gen_advance_ms,
                    sleep_ms,
                    @intFromBool(terminal_output_pressure),
                    state.idle_frames,
                    state.shell.width(),
                    state.shell.height(),
                },
            );
        }
    }

    app_shell.waitTime(sleep_ms);
    hooks.maybe_log_metrics(ctx, app_shell.getTime());
}
