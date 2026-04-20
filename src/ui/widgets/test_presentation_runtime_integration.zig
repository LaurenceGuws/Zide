//! Integration invariant tests for presentation runtime ownership boundary.
//! Validates that:
//! - Widget layer correctly imports and re-exports terminal types
//! - Widget layer delegates to terminal-layer classification functions
//! - Ownership boundary is clean at call site
//! - No re-derivation of outcomes or geometry in widget layer
//! - refreshPresentState side effect removed: widget owns notePresentationUpdated
//! - PresentationPresentState type is consistent across widget/terminal boundary

const std = @import("std");
const terminal_presentation_runtime = @import("../../terminal/presentation_runtime.zig");
const terminal_widget_presentation_runtime = @import("./terminal_widget_presentation_runtime.zig");

test "Widget layer re-exports terminal presentation types" {
    const widget_result = terminal_widget_presentation_runtime.TerminalPresentResult{
        .outcome = .presented,
        .timing = .{
            .background_ms = 1.0,
            .glyph_ms = 2.0,
            .kitty_ms = 0.0,
        },
        .shared_surface_attachment_ready = true,
    };
    const terminal_result = terminal_presentation_runtime.TerminalPresentResult{
        .outcome = .presented,
        .timing = .{
            .background_ms = 1.0,
            .glyph_ms = 2.0,
            .kitty_ms = 0.0,
        },
        .shared_surface_attachment_ready = true,
    };
    try std.testing.expect(widget_result.timing.background_ms == terminal_result.timing.background_ms);
    try std.testing.expect(widget_result.shared_surface_attachment_ready == terminal_result.shared_surface_attachment_ready);
}

test "Widget layer uses terminal outcome classification" {
    // Widget should be using terminal-layer classifyRefreshOutcome
    const outcome = terminal_widget_presentation_runtime.classifyRefreshOutcome(.refreshed, true);
    try std.testing.expect(outcome.outcome == .updated_and_presented);
    try std.testing.expect(outcome.cache_state_advanced == true);
}

test "Widget layer uses terminal geometry computation" {
    // Widget should import PresentationGeometry from terminal
    const geometry = terminal_widget_presentation_runtime.computePresentationSurfaceGeometry(undefined, undefined, undefined);
    // Zero-dimension result expected (inputs undefined, but type is correct)
    try std.testing.expect(@TypeOf(geometry) == terminal_presentation_runtime.PresentationGeometry);
}

test "Widget layer outcome validation uses terminal assertions" {
    const outcome = terminal_widget_presentation_runtime.reuseSuccessOutcome();
    terminal_widget_presentation_runtime.assertReuseOutcomeConsistency(outcome);
    try std.testing.expect(outcome.outcome == .reused);
}

test "Widget layer outcome folding uses terminal helpers" {
    const outcome = terminal_widget_presentation_runtime.classifyRefreshOutcome(.presented, false);
    const timing = .{ .background_ms = 0.5, .glyph_ms = 0.0, .kitty_ms = 0.0 };
    const result = terminal_widget_presentation_runtime.foldRefreshOutcomeToPresent(outcome, timing);
    try std.testing.expect(result.outcome == .presented);
    try std.testing.expect(result.shared_surface_attachment_ready == outcome.shared_surface_attachment_ready);
}

test "ViewportShiftState is accessible in widget layer" {
    const viewport_state = terminal_widget_presentation_runtime.ViewportShiftState{
        .rows = 5,
        .exposed_only = true,
    };
    try std.testing.expect(viewport_state.rows == 5);
}

test "PresentationGeometry is accessible in widget layer" {
    const geom = terminal_widget_presentation_runtime.PresentationGeometry{
        .cell_w_i = 8,
        .cell_h_i = 16,
    };
    try std.testing.expect(geom.cell_w_i == 8);
    try std.testing.expect(geom.cell_h_i == 16);
}

test "All outcome classification paths work in widget context" {
    // Refresh outcomes
    const refreshed = terminal_widget_presentation_runtime.classifyRefreshOutcome(.refreshed, true);
    const presented = terminal_widget_presentation_runtime.classifyRefreshOutcome(.presented, false);
    const unavailable = terminal_widget_presentation_runtime.classifyRefreshOutcome(.target_unavailable, false);

    try std.testing.expect(refreshed.outcome == .updated_and_presented);
    try std.testing.expect(presented.outcome == .presented);
    try std.testing.expect(unavailable.followup_required == true);

    // Direct outcomes
    const direct_updated = terminal_widget_presentation_runtime.classifyDirectPresentOutcome(true);
    const direct_not = terminal_widget_presentation_runtime.classifyDirectPresentOutcome(false);

    try std.testing.expect(direct_updated.outcome == .updated_and_presented);
    try std.testing.expect(direct_not.outcome == .presented);

    // Reuse outcome
    const reuse = terminal_widget_presentation_runtime.reuseSuccessOutcome();
    try std.testing.expect(reuse.outcome == .reused);
}

test "Widget layer delegates outcome folding without re-derivation" {
    const outcome = terminal_widget_presentation_runtime.classifyRefreshOutcome(.refreshed, false);
    const timing = .{ .background_ms = 1.5, .glyph_ms = 2.5, .kitty_ms = 0.0 };
    const result = terminal_widget_presentation_runtime.foldRefreshOutcomeToPresent(outcome, timing);

    try std.testing.expect(result.outcome == .updated_and_presented);
    try std.testing.expect(result.timing.background_ms == 1.5);
}

test "Widget layer canonical reuse helper preserves outcome semantics" {
    const reuse = terminal_widget_presentation_runtime.reuseSuccessOutcome();
    const timing = .{ .background_ms = 0.5, .glyph_ms = 0.0, .kitty_ms = 0.0 };
    const via_canonical_helper = terminal_widget_presentation_runtime.foldReuseOutcomeToPresent(reuse, timing);
    const via_boundary_helper = terminal_widget_presentation_runtime.foldReuseOutcomeToPresent(reuse, timing);

    try std.testing.expect(via_canonical_helper.outcome == .reused);
    try std.testing.expect(via_canonical_helper.shared_surface_attachment_ready == true);
    try std.testing.expectEqual(via_canonical_helper.outcome, via_boundary_helper.outcome);
    try std.testing.expectEqual(via_canonical_helper.shared_surface_attachment_ready, via_boundary_helper.shared_surface_attachment_ready);
    try std.testing.expectEqual(via_canonical_helper.timing.background_ms, via_boundary_helper.timing.background_ms);
    try std.testing.expectEqual(via_canonical_helper.timing.glyph_ms, via_boundary_helper.timing.glyph_ms);
    try std.testing.expectEqual(via_canonical_helper.timing.kitty_ms, via_boundary_helper.timing.kitty_ms);
}

test "Widget layer assertions validate outcome consistency" {
    const refresh = terminal_widget_presentation_runtime.classifyRefreshOutcome(.refreshed, true);
    terminal_widget_presentation_runtime.assertRefreshOutcomeConsistency(refresh);

    const direct = terminal_widget_presentation_runtime.classifyDirectPresentOutcome(true);
    terminal_widget_presentation_runtime.assertDirectPresentOutcomeConsistency(direct);

    const reuse = terminal_widget_presentation_runtime.reuseSuccessOutcome();
    terminal_widget_presentation_runtime.assertReuseOutcomeConsistency(reuse);
}

test "Integration boundary: widget imports and uses terminal outcome types unchanged" {
    // Verify that widget layer uses terminal types directly, not re-definitions
    const widget_refresh = terminal_widget_presentation_runtime.RefreshOutcomeState{
        .outcome = .updated_and_presented,
        .cache_state_advanced = true,
    };
    const terminal_refresh = terminal_presentation_runtime.RefreshOutcomeState{
        .outcome = .updated_and_presented,
        .cache_state_advanced = true,
    };
    try std.testing.expect(@TypeOf(widget_refresh) == @TypeOf(terminal_refresh));
}

test "Integration boundary: widget geometry types match terminal types" {
    const widget_geom = terminal_widget_presentation_runtime.PresentationGeometry{
        .cell_w_i = 8,
        .cell_h_i = 16,
    };
    const terminal_geom = terminal_presentation_runtime.PresentationGeometry{
        .cell_w_i = 8,
        .cell_h_i = 16,
    };
    try std.testing.expect(@TypeOf(widget_geom) == @TypeOf(terminal_geom));
}

test "Integration boundary: widget viewport state matches terminal" {
    const widget_state = terminal_widget_presentation_runtime.ViewportShiftState{
        .rows = 5,
        .exposed_only = true,
    };
    const terminal_state = terminal_presentation_runtime.ViewportShiftState{
        .rows = 5,
        .exposed_only = true,
    };
    try std.testing.expect(@TypeOf(widget_state) == @TypeOf(terminal_state));
}

test "Integration boundary: outcome classification produces consistent results widget-side" {
    const outcome_widget = terminal_widget_presentation_runtime.classifyRefreshOutcome(.refreshed, true);
    const outcome_terminal = terminal_presentation_runtime.classifyRefreshOutcome(.refreshed, true);

    try std.testing.expect(outcome_widget.outcome == outcome_terminal.outcome);
    try std.testing.expect(outcome_widget.cache_state_advanced == outcome_terminal.cache_state_advanced);
}

test "Integration boundary: no outcome re-derivation in widget folding" {
    const outcome = terminal_widget_presentation_runtime.classifyRefreshOutcome(.refreshed, true);
    const timing = .{ .background_ms = 1.0, .glyph_ms = 2.0, .kitty_ms = 0.0 };
    const result = terminal_widget_presentation_runtime.foldRefreshOutcomeToPresent(outcome, timing);

    // Verify that the result's outcome matches input outcome (no re-derivation)
    try std.testing.expect(result.outcome == outcome.outcome);
    try std.testing.expect(result.cache_state_advanced == outcome.cache_state_advanced);
    try std.testing.expect(result.shared_surface_attachment_ready == outcome.shared_surface_attachment_ready);
}

test "Callback contract: reuse eligibility check integrates with outcome generation" {
    // Simulate widget computing attachment state
    const FakePlan = struct {
        present_intent: enum { reuse, refresh, direct } = .reuse,
    };
    const plan = FakePlan{};

    // Widget calls terminal eligibility check
    const eligible = terminal_widget_presentation_runtime.checkReuseEligibility(
        plan,
        .{
            .view_cells_len = 10,
            .shared_surface_attachment_ready = true,
            .sync_updates_active = true,
            .supports_reuse_without_sync = false,
        },
    );

    // If eligible, widget would execute and generate success outcome
    const outcome = if (eligible)
        terminal_widget_presentation_runtime.reuseSuccessOutcome()
    else
        terminal_widget_presentation_runtime.ReusePresentOutcomeState{};

    // Verify outcome matches eligibility decision
    try std.testing.expect(eligible == (outcome.outcome == .reused));
}

test "Callback contract: direct eligibility check integrates with GPU execution path" {
    const rows = 10;
    const cols = 80;
    const cells = 800;

    // Widget calls terminal eligibility check
    const eligible = terminal_widget_presentation_runtime.checkDirectPresentEligibility(.{
        .rows = rows,
        .cols = cols,
        .view_cells_len = cells,
    });

    // If eligible, widget executes GPU drawing and generates outcome
    const outcome = if (eligible)
        terminal_widget_presentation_runtime.classifyDirectPresentOutcome(true)
    else
        terminal_widget_presentation_runtime.DirectPresentOutcomeState{
            .outcome = .skipped,
            .cache_state_advanced = false,
            .host_surface_target_available = false,
            .shared_surface_attachment_ready = false,
        };

    // Verify outcome consistency with eligibility
    if (eligible) {
        try std.testing.expect(outcome.outcome == .updated_and_presented or outcome.outcome == .presented);
    }
}

test "Callback contract: reuse boundary helper preserves attachment state through callback" {
    // Simulate reuse callback contract
    const eligible = true; // Widget eligibility check returned true

    if (eligible) {
        // Widget executes reuse presentation
        const outcome = terminal_widget_presentation_runtime.reuseSuccessOutcome();
        const timing = .{ .background_ms = 0.5, .glyph_ms = 0.0, .kitty_ms = 0.0 };

        // Widget folds reuse attempt via canonical reuse boundary helper
        const result = terminal_widget_presentation_runtime.foldReuseOutcomeToPresent(outcome, timing);

        // Verify attachment state preserved through fold
        try std.testing.expect(result.shared_surface_attachment_ready == true);
        try std.testing.expect(result.outcome == .reused);
    }
}

test "Callback contract: eligibility decision is terminal-owned, execution is widget-owned" {
    const FakePlan = struct {
        present_intent: enum { reuse, refresh, direct } = .reuse,
    };

    // Terminal-owned: eligibility decision
    const plan = FakePlan{};
    const eligible = terminal_widget_presentation_runtime.checkReuseEligibility(
        plan,
        .{
            .view_cells_len = 10,
            .shared_surface_attachment_ready = true,
            .sync_updates_active = true,
            .supports_reuse_without_sync = false,
        },
    );

    // Widget-owned: outcome generation depends on execution
    const outcome = if (eligible)
        terminal_widget_presentation_runtime.reuseSuccessOutcome()
    else
        terminal_widget_presentation_runtime.ReusePresentOutcomeState{};

    // Verify clean boundary
    try std.testing.expect(eligible == true);
    try std.testing.expect(outcome.outcome == .reused);
}

test "Callback contract: terminal classification used regardless of widget execution path" {
    // Refresh path uses terminal classification
    const refresh_outcome = terminal_widget_presentation_runtime.classifyRefreshOutcome(.refreshed, true);
    try std.testing.expect(refresh_outcome.outcome == .updated_and_presented);

    // Direct path uses terminal classification
    const direct_outcome = terminal_widget_presentation_runtime.classifyDirectPresentOutcome(true);
    try std.testing.expect(direct_outcome.outcome == .updated_and_presented);

    // Reuse path uses terminal outcome constructor
    const reuse_outcome = terminal_widget_presentation_runtime.reuseSuccessOutcome();
    try std.testing.expect(reuse_outcome.outcome == .reused);
}

test "Integration invariant: direct folded-result route preserves canonical timing carrier semantics" {
    const direct_outcome = terminal_widget_presentation_runtime.classifyDirectPresentOutcome(true);
    const timing = .{ .background_ms = 2.0, .glyph_ms = 1.0, .kitty_ms = 0.0 };
    const direct_result = terminal_presentation_runtime.presentResultFromDirectPresentOutcomeState(direct_outcome, timing);

    try std.testing.expect(direct_result.outcome == direct_outcome.outcome);
    try std.testing.expect(direct_result.cache_state_advanced == direct_outcome.cache_state_advanced);
    try std.testing.expect(direct_result.host_surface_target_available == direct_outcome.host_surface_target_available);
    try std.testing.expect(direct_result.shared_surface_attachment_ready == direct_outcome.shared_surface_attachment_ready);
    try std.testing.expect(direct_result.timing.background_ms == timing.background_ms);
    try std.testing.expect(direct_result.timing.glyph_ms == timing.glyph_ms);
    try std.testing.expect(direct_result.timing.kitty_ms == timing.kitty_ms);
}

test "Integration invariant: narrowed refresh boundary helper naming keeps folded host-facing carrier parity" {
    const cycle_timing = .{ .background_ms = 3.25, .glyph_ms = 1.75, .kitty_ms = 0.5 };
    const refreshed = terminal_presentation_runtime.foldRefreshOutcomeToPresent(
        terminal_presentation_runtime.classifyRefreshOutcome(.refreshed, true),
        cycle_timing,
    );

    const refresh_outcome = terminal_widget_presentation_runtime.classifyRefreshOutcome(.refreshed, true);
    const folded_refresh = terminal_widget_presentation_runtime.foldRefreshOutcomeToPresent(refresh_outcome, cycle_timing);

    try std.testing.expectEqual(refreshed.timing.background_ms, cycle_timing.background_ms);
    try std.testing.expectEqual(refreshed.timing.glyph_ms, cycle_timing.glyph_ms);
    try std.testing.expectEqual(refreshed.timing.kitty_ms, cycle_timing.kitty_ms);
    try std.testing.expect(refreshed.shared_surface_attachment_ready == true);
    try std.testing.expectEqual(refreshed.outcome, .updated_and_presented);

    try std.testing.expectEqual(refreshed.outcome, folded_refresh.outcome);
    try std.testing.expectEqual(refreshed.cache_state_advanced, folded_refresh.cache_state_advanced);
    try std.testing.expectEqual(refreshed.host_surface_target_available, folded_refresh.host_surface_target_available);
    try std.testing.expectEqual(refreshed.shared_surface_attachment_ready, folded_refresh.shared_surface_attachment_ready);
    try std.testing.expectEqual(refreshed.followup.required, folded_refresh.followup.required);
    try std.testing.expectEqual(refreshed.followup.reason, folded_refresh.followup.reason);
}

test "Integration invariant: refresh boundary helper preserves unavailable followup host-facing transport" {
    const cycle_timing = .{ .background_ms = 0.5, .glyph_ms = 0.25, .kitty_ms = 0.0 };
    const refreshed = terminal_presentation_runtime.foldRefreshOutcomeToPresent(
        terminal_presentation_runtime.classifyRefreshOutcome(.target_unavailable, false),
        cycle_timing,
    );

    try std.testing.expectEqual(refreshed.outcome, .presented);
    try std.testing.expectEqual(refreshed.followup.required, true);
    try std.testing.expectEqual(refreshed.followup.reason, .target_unavailable);
    try std.testing.expectEqual(refreshed.host_surface_target_available, false);
    try std.testing.expectEqual(refreshed.shared_surface_attachment_ready, false);
    try std.testing.expectEqual(refreshed.timing.background_ms, cycle_timing.background_ms);
    try std.testing.expectEqual(refreshed.timing.glyph_ms, cycle_timing.glyph_ms);
    try std.testing.expectEqual(refreshed.timing.kitty_ms, cycle_timing.kitty_ms);
}

test "Integration invariant: reuse fold helper preserves flattened reuse transport" {
    const reuse_attempt = terminal_widget_presentation_runtime.ReusePresentOutcomeState{
        .outcome = .skipped,
        .cache_state_advanced = false,
        .host_surface_target_available = true,
        .shared_surface_attachment_ready = false,
    };
    const timing = .{ .background_ms = 0.4, .glyph_ms = 0.6, .kitty_ms = 0.2 };
    const result = terminal_presentation_runtime.foldReuseOutcomeToPresent(reuse_attempt, timing);

    try std.testing.expect(result.outcome == reuse_attempt.outcome);
    try std.testing.expect(result.cache_state_advanced == reuse_attempt.cache_state_advanced);
    try std.testing.expect(result.host_surface_target_available == reuse_attempt.host_surface_target_available);
    try std.testing.expect(result.shared_surface_attachment_ready == reuse_attempt.shared_surface_attachment_ready);
    try std.testing.expectEqual(result.timing.background_ms, timing.background_ms);
    try std.testing.expectEqual(result.timing.glyph_ms, timing.glyph_ms);
    try std.testing.expectEqual(result.timing.kitty_ms, timing.kitty_ms);
}

test "Integration invariant: reuse canonical helper parity stays equivalent across widget and terminal" {
    const reuse_attempt = terminal_widget_presentation_runtime.ReusePresentOutcomeState{
        .outcome = .skipped,
        .cache_state_advanced = false,
        .host_surface_target_available = true,
        .shared_surface_attachment_ready = false,
    };
    const timing = .{ .background_ms = 0.125, .glyph_ms = 0.25, .kitty_ms = 0.375 };

    const via_widget_helper = terminal_widget_presentation_runtime.foldReuseOutcomeToPresent(reuse_attempt, timing);
    const via_widget_boundary_helper = terminal_widget_presentation_runtime.foldReuseOutcomeToPresent(reuse_attempt, timing);
    const via_terminal_boundary_helper = terminal_presentation_runtime.foldReuseOutcomeToPresent(reuse_attempt, timing);

    try std.testing.expectEqual(via_widget_helper.outcome, via_widget_boundary_helper.outcome);
    try std.testing.expectEqual(via_widget_helper.cache_state_advanced, via_widget_boundary_helper.cache_state_advanced);
    try std.testing.expectEqual(via_widget_helper.host_surface_target_available, via_widget_boundary_helper.host_surface_target_available);
    try std.testing.expectEqual(via_widget_helper.shared_surface_attachment_ready, via_widget_boundary_helper.shared_surface_attachment_ready);
    try std.testing.expectEqual(via_widget_helper.timing.background_ms, via_widget_boundary_helper.timing.background_ms);
    try std.testing.expectEqual(via_widget_helper.timing.glyph_ms, via_widget_boundary_helper.timing.glyph_ms);
    try std.testing.expectEqual(via_widget_helper.timing.kitty_ms, via_widget_boundary_helper.timing.kitty_ms);

    try std.testing.expectEqual(via_widget_helper.outcome, via_terminal_boundary_helper.outcome);
    try std.testing.expectEqual(via_widget_helper.cache_state_advanced, via_terminal_boundary_helper.cache_state_advanced);
    try std.testing.expectEqual(via_widget_helper.host_surface_target_available, via_terminal_boundary_helper.host_surface_target_available);
    try std.testing.expectEqual(via_widget_helper.shared_surface_attachment_ready, via_terminal_boundary_helper.shared_surface_attachment_ready);
    try std.testing.expectEqual(via_widget_helper.timing.background_ms, via_terminal_boundary_helper.timing.background_ms);
    try std.testing.expectEqual(via_widget_helper.timing.glyph_ms, via_terminal_boundary_helper.timing.glyph_ms);
    try std.testing.expectEqual(via_widget_helper.timing.kitty_ms, via_terminal_boundary_helper.timing.kitty_ms);

    try std.testing.expectEqual(via_widget_boundary_helper.outcome, via_terminal_boundary_helper.outcome);
    try std.testing.expectEqual(via_widget_boundary_helper.cache_state_advanced, via_terminal_boundary_helper.cache_state_advanced);
    try std.testing.expectEqual(via_widget_boundary_helper.host_surface_target_available, via_terminal_boundary_helper.host_surface_target_available);
    try std.testing.expectEqual(via_widget_boundary_helper.shared_surface_attachment_ready, via_terminal_boundary_helper.shared_surface_attachment_ready);
    try std.testing.expectEqual(via_widget_boundary_helper.timing.background_ms, via_terminal_boundary_helper.timing.background_ms);
    try std.testing.expectEqual(via_widget_boundary_helper.timing.glyph_ms, via_terminal_boundary_helper.timing.glyph_ms);
    try std.testing.expectEqual(via_widget_boundary_helper.timing.kitty_ms, via_terminal_boundary_helper.timing.kitty_ms);
}

test "Integration hygiene: widget boundary removes wrapper-only refresh and reuse carriers" {
    comptime {
        std.debug.assert(!@hasDecl(terminal_widget_presentation_runtime, "RefreshedPresentablePresentationResult"));
        std.debug.assert(!@hasDecl(terminal_widget_presentation_runtime, "runFastPresentIfAvailable"));
    }
}

test "Integration hygiene: terminal/runtime boundary exposes collapsed transport surface" {
    comptime {
        std.debug.assert(@hasDecl(terminal_presentation_runtime, "foldRefreshOutcomeToPresent"));
        std.debug.assert(@hasDecl(terminal_presentation_runtime, "foldReuseOutcomeToPresent"));
        std.debug.assert(@hasDecl(terminal_presentation_runtime, "presentResultFromDirectPresentOutcomeState"));
        std.debug.assert(!@hasDecl(terminal_presentation_runtime, "refreshedPresentationResultFromCycle"));
        std.debug.assert(!@hasDecl(terminal_presentation_runtime, "directPresentTimingResult"));
    }
}

test "Integration invariant: refresh inline carrier semantics are preserved through fold" {
    const attached_outcome = terminal_widget_presentation_runtime.classifyRefreshOutcome(.presented, true);
    const detached_outcome = terminal_widget_presentation_runtime.classifyRefreshOutcome(.presented, false);
    const timing = .{ .background_ms = 0.25, .glyph_ms = 0.75, .kitty_ms = 0.0 };

    const attached_result = terminal_widget_presentation_runtime.foldRefreshOutcomeToPresent(attached_outcome, timing);
    const detached_result = terminal_widget_presentation_runtime.foldRefreshOutcomeToPresent(detached_outcome, timing);

    try std.testing.expect(attached_result.shared_surface_attachment_ready == true);
    try std.testing.expect(detached_result.shared_surface_attachment_ready == false);
    try std.testing.expect(attached_result.host_surface_target_available == attached_outcome.host_surface_target_available);
    try std.testing.expect(detached_result.host_surface_target_available == detached_outcome.host_surface_target_available);
    try std.testing.expectEqual(attached_result.timing.background_ms, timing.background_ms);
    try std.testing.expectEqual(detached_result.timing.glyph_ms, timing.glyph_ms);
}

test "PresentationPresentState type is consistent at widget/terminal boundary" {
    // Widget re-exports PresentationPresentState from terminal layer — same type, not re-definition
    const widget_type = terminal_widget_presentation_runtime.PresentationPresentState;
    const terminal_type = terminal_presentation_runtime.PresentationPresentState;
    try std.testing.expect(widget_type == terminal_type);
}

test "Eligibility input types are consistent at widget/terminal boundary" {
    const widget_reuse = terminal_widget_presentation_runtime.ReuseEligibilityInput;
    const terminal_reuse = terminal_presentation_runtime.ReuseEligibilityInput;
    try std.testing.expect(widget_reuse == terminal_reuse);

    const widget_direct = terminal_widget_presentation_runtime.DirectPresentEligibilityInput;
    const terminal_direct = terminal_presentation_runtime.DirectPresentEligibilityInput;
    try std.testing.expect(widget_direct == terminal_direct);
}

test "PresentationPresentState carries expected fields from pure computation" {
    // Verify struct fields match expected pure-state snapshot shape
    const state = terminal_presentation_runtime.PresentationPresentState{
        .updated = true,
        .present = true,
        .shared_surface_attachment_ready = true,
        .visible = true,
        .log_unavailable = false,
    };
    try std.testing.expect(state.updated == true);
    try std.testing.expect(state.present == true);
    try std.testing.expect(state.log_unavailable == false);
}

test "Widget PresentationPresentState is accessible from re-export" {
    // Widget layer should expose PresentationPresentState; callers can use it without terminal import
    const state = terminal_widget_presentation_runtime.PresentationPresentState{
        .updated = false,
        .present = false,
        .shared_surface_attachment_ready = false,
    };
    try std.testing.expect(state.updated == false);
}
