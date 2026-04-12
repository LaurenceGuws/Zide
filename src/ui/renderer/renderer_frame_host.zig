const app_logger = @import("../../app_logger.zig");
const present_feedback_state = @import("present_feedback_state.zig");
const present_trace_runtime = @import("present_trace_runtime.zig");
const std = @import("std");

pub const FrameExecutionOutcome = present_feedback_state.FrameExecutionOutcome;
pub const FrameExecutionOutcomeKind = present_feedback_state.FrameExecutionOutcomeKind;

pub fn beginFrameHost(renderer: anytype) void {
    renderer.present.frame_seq +%= 1;
    renderer.present.frame_execution_state = .not_attempted;
    renderer.present.frame_family_current = .{};
    const present_log = app_logger.logger("renderer.present");
    renderer.present.trace_enabled = present_log.enabled_file or present_log.enabled_console;
    renderer.present.trace_current = .{ .frame_seq = renderer.present.frame_seq };
    renderer.clip_depth = 0;

    const display_metrics = renderer.display_metrics;
    renderer.width = display_metrics.window_w;
    renderer.height = display_metrics.window_h;
    renderer.render_width = display_metrics.drawable_w;
    renderer.render_height = display_metrics.drawable_h;

}

pub fn noteFrameReady(renderer: anytype) void {
    renderer.present.frame_execution_state = .ready;
}

pub fn noteFrameBeginFailed(renderer: anytype) void {
    renderer.present.frame_execution_state = .begin_failed;
}

pub fn noteFrameAbandoned(renderer: anytype) void {
    renderer.present.frame_execution_state = .abandoned;
}

pub fn frameReadyForDraw(renderer: anytype) bool {
    return renderer.present.frame_execution_state == .ready;
}

pub fn finishFrameSubmission(renderer: anytype, outcome: FrameExecutionOutcome) present_feedback_state.FrameSubmission {
    renderer.present.last_swap_ms = outcome.present_ms;
    renderer.present.main_composition_target = .default_target;
    renderer.present.trace_last = renderer.present.trace_current;
    switch (outcome.kind) {
        .submitted, .submit_failed => {
            renderer.present.capture_path = null;
            renderer.present.capture_armed = false;
            renderer.present.capture_frame_seq = 0;
        },
        .not_attempted, .begin_failed, .abandoned => {},
    }
    renderer.present.frame_execution_state = .not_attempted;
    const succeeded = outcome.kind == .submitted;
    const family_summary = present_feedback_state.finalizedFrameFamilySummary(
        renderer.present.frame_family_current,
        succeeded,
    );
    if (succeeded) renderer.present.submission_sequence += 1;
    return .{
        .succeeded = succeeded,
        .sequence = renderer.present.submission_sequence,
        .family_summary = family_summary,
    };
}

const FakeDisplayMetrics = struct {
    window_w: i32 = 0,
    window_h: i32 = 0,
    drawable_w: i32 = 0,
    drawable_h: i32 = 0,
};

const FakeRenderer = struct {
    present: present_trace_runtime.PresentState = .{},
    clip_depth: usize = 0,
    display_metrics: FakeDisplayMetrics = .{},
    width: i32 = 0,
    height: i32 = 0,
    render_width: i32 = 0,
    render_height: i32 = 0,
};

test "beginFrameHost resets per-frame prelude state" {
    var renderer: FakeRenderer = .{
        .present = .{
            .frame_seq = 9,
            .frame_execution_state = .ready,
            .trace_current = .{
                .frame_seq = 3,
                .terminal_presentation_count = 2,
            },
        },
        .clip_depth = 4,
        .display_metrics = .{
            .window_w = 101,
            .window_h = 55,
            .drawable_w = 202,
            .drawable_h = 110,
        },
    };

    beginFrameHost(&renderer);

    try std.testing.expectEqual(@as(u64, 10), renderer.present.frame_seq);
    try std.testing.expectEqual(present_feedback_state.FrameExecutionState.not_attempted, renderer.present.frame_execution_state);
    try std.testing.expectEqual(@as(u64, 10), renderer.present.trace_current.frame_seq);
    try std.testing.expectEqual(@as(usize, 0), renderer.present.trace_current.terminal_presentation_count);
    try std.testing.expectEqual(@as(usize, 0), renderer.clip_depth);
    try std.testing.expectEqual(@as(i32, 101), renderer.width);
    try std.testing.expectEqual(@as(i32, 55), renderer.height);
    try std.testing.expectEqual(@as(i32, 202), renderer.render_width);
    try std.testing.expectEqual(@as(i32, 110), renderer.render_height);
}

test "finishFrameSubmission submitted advances sequence and clears capture" {
    var renderer: FakeRenderer = .{
        .present = .{
            .submission_sequence = 11,
            .frame_execution_state = .ready,
            .main_composition_target = .backend_surface,
            .trace_current = .{
                .frame_seq = 44,
                .terminal_presentation_count = 1,
                .terminal_presented_generation = 77,
            },
            .capture_path = "capture.ppm",
            .capture_armed = true,
            .capture_frame_seq = 44,
        },
    };

    const submission = finishFrameSubmission(&renderer, .{
        .kind = .submitted,
        .present_ms = 3.25,
    });

    try std.testing.expect(submission.succeeded);
    try std.testing.expectEqual(@as(u64, 12), submission.sequence);
    try std.testing.expect(submission.family_summary.terminal.touched);
    try std.testing.expect(submission.family_summary.terminal.presented);
    try std.testing.expectEqual(@as(?u64, 77), submission.family_summary.terminal.presented_generation);
    try std.testing.expect(!submission.family_summary.chrome_band.touched);
    try std.testing.expect(!submission.family_summary.chrome_band.presented);
    try std.testing.expectEqual(@as(f64, 3.25), renderer.present.last_swap_ms);
    try std.testing.expectEqual(@as(u64, 12), renderer.present.submission_sequence);
    try std.testing.expectEqual(present_feedback_state.MainCompositionTarget.default_target, renderer.present.main_composition_target);
    try std.testing.expectEqual(renderer.present.trace_current, renderer.present.trace_last);
    try std.testing.expectEqual(@as(?[]const u8, null), renderer.present.capture_path);
    try std.testing.expect(!renderer.present.capture_armed);
    try std.testing.expectEqual(@as(u64, 0), renderer.present.capture_frame_seq);
    try std.testing.expectEqual(present_feedback_state.FrameExecutionState.not_attempted, renderer.present.frame_execution_state);
}

test "finishFrameSubmission begin_failed preserves capture and does not advance sequence" {
    var renderer: FakeRenderer = .{
        .present = .{
            .submission_sequence = 5,
            .frame_execution_state = .begin_failed,
            .main_composition_target = .backend_surface,
            .trace_current = .{ .frame_seq = 12 },
            .capture_path = "capture.ppm",
            .capture_armed = true,
            .capture_frame_seq = 12,
        },
    };

    const submission = finishFrameSubmission(&renderer, .{
        .kind = .begin_failed,
        .present_ms = 0.0,
    });

    try std.testing.expect(!submission.succeeded);
    try std.testing.expectEqual(@as(u64, 5), submission.sequence);
    try std.testing.expect(!submission.family_summary.terminal.presented);
    try std.testing.expect(!submission.family_summary.chrome_band.presented);
    try std.testing.expectEqual(@as(u64, 5), renderer.present.submission_sequence);
    try std.testing.expectEqual(@as(?[]const u8, "capture.ppm"), renderer.present.capture_path);
    try std.testing.expect(renderer.present.capture_armed);
    try std.testing.expectEqual(@as(u64, 12), renderer.present.capture_frame_seq);
    try std.testing.expectEqual(present_feedback_state.MainCompositionTarget.default_target, renderer.present.main_composition_target);
    try std.testing.expectEqual(renderer.present.trace_current, renderer.present.trace_last);
    try std.testing.expectEqual(present_feedback_state.FrameExecutionState.not_attempted, renderer.present.frame_execution_state);
}

test "finishFrameSubmission submit_failed clears capture but does not advance sequence" {
    var renderer: FakeRenderer = .{
        .present = .{
            .submission_sequence = 8,
            .frame_execution_state = .ready,
            .main_composition_target = .backend_surface,
            .trace_current = .{
                .frame_seq = 21,
                .terminal_presentation_count = 1,
                .terminal_presented_generation = 55,
            },
            .capture_path = "capture.ppm",
            .capture_armed = true,
            .capture_frame_seq = 21,
        },
    };

    const submission = finishFrameSubmission(&renderer, .{
        .kind = .submit_failed,
        .present_ms = 4.5,
    });

    try std.testing.expect(!submission.succeeded);
    try std.testing.expectEqual(@as(u64, 8), submission.sequence);
    try std.testing.expect(submission.family_summary.terminal.touched);
    try std.testing.expect(!submission.family_summary.terminal.presented);
    try std.testing.expect(!submission.family_summary.chrome_band.presented);
    try std.testing.expectEqual(@as(u64, 8), renderer.present.submission_sequence);
    try std.testing.expectEqual(@as(?[]const u8, null), renderer.present.capture_path);
    try std.testing.expect(!renderer.present.capture_armed);
    try std.testing.expectEqual(@as(u64, 0), renderer.present.capture_frame_seq);
    try std.testing.expectEqual(@as(f64, 4.5), renderer.present.last_swap_ms);
    try std.testing.expectEqual(present_feedback_state.MainCompositionTarget.default_target, renderer.present.main_composition_target);
    try std.testing.expectEqual(present_feedback_state.FrameExecutionState.not_attempted, renderer.present.frame_execution_state);
}

test "finishFrameSubmission submitted reports chrome band through shared family summary" {
    var renderer: FakeRenderer = .{
        .present = .{
            .submission_sequence = 2,
            .frame_execution_state = .ready,
            .frame_family_current = .{
                .chrome_band = .{ .touched = true },
            },
            .trace_current = .{
                .frame_seq = 8,
            },
        },
    };

    const submission = finishFrameSubmission(&renderer, .{
        .kind = .submitted,
        .present_ms = 1.0,
    });

    try std.testing.expect(submission.succeeded);
    try std.testing.expect(submission.family_summary.chrome_band.touched);
    try std.testing.expect(submission.family_summary.chrome_band.presented);
    try std.testing.expect(!submission.family_summary.terminal.touched);
}

test "finishFrameSubmission submitted reports editor row-band through shared family summary" {
    var renderer: FakeRenderer = .{
        .present = .{
            .submission_sequence = 4,
            .frame_execution_state = .ready,
            .frame_family_current = .{
                .editor_row_band = .{ .touched = true },
            },
            .trace_current = .{
                .frame_seq = 14,
            },
        },
    };

    const submission = finishFrameSubmission(&renderer, .{
        .kind = .submitted,
        .present_ms = 2.0,
    });

    try std.testing.expect(submission.succeeded);
    try std.testing.expect(submission.family_summary.editor_row_band.touched);
    try std.testing.expect(submission.family_summary.editor_row_band.presented);
    try std.testing.expect(!submission.family_summary.chrome_band.touched);
    try std.testing.expect(!submission.family_summary.terminal.touched);
}

test "finishFrameSubmission submitted reports sample section through shared family summary" {
    var renderer: FakeRenderer = .{
        .present = .{
            .submission_sequence = 6,
            .frame_execution_state = .ready,
            .frame_family_current = .{
                .sample_section = .{ .touched = true },
            },
            .trace_current = .{
                .frame_seq = 18,
            },
        },
    };

    const submission = finishFrameSubmission(&renderer, .{
        .kind = .submitted,
        .present_ms = 2.5,
    });

    try std.testing.expect(submission.succeeded);
    try std.testing.expect(submission.family_summary.sample_section.touched);
    try std.testing.expect(submission.family_summary.sample_section.presented);
    try std.testing.expect(!submission.family_summary.editor_row_band.touched);
    try std.testing.expect(!submission.family_summary.chrome_band.touched);
    try std.testing.expect(!submission.family_summary.terminal.touched);
}
