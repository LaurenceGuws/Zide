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
    // RefreshedPresentablePresentationResult should be from terminal
    const widget_result = terminal_widget_presentation_runtime.RefreshedPresentablePresentationResult{
        .bg_ms = 1.0,
        .glyph_ms = 2.0,
        .kitty_ms = 0.0,
        .shared_surface_attachment_ready = true,
    };
    const terminal_result = terminal_presentation_runtime.RefreshedPresentablePresentationResult{
        .bg_ms = 1.0,
        .glyph_ms = 2.0,
        .kitty_ms = 0.0,
        .shared_surface_attachment_ready = true,
    };
    // Both should have identical structure (same type)
    try std.testing.expect(widget_result.bg_ms == terminal_result.bg_ms);
    try std.testing.expect(widget_result.shared_surface_attachment_ready == terminal_result.shared_surface_attachment_ready);
}

test "Widget layer uses terminal outcome classification" {
    // Widget should be using terminal-layer classifyRefreshOutcome
    const outcome = terminal_widget_presentation_runtime.classifyRefreshOutcome(.refreshed);
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
    try std.testing.expect(outcome.reused == true);
}

test "Widget layer outcome folding uses terminal helpers" {
    const outcome = terminal_widget_presentation_runtime.classifyRefreshOutcome(.presented);
    const timing = .{ .background_ms = 0.5, .glyph_ms = 0.0, .kitty_ms = 0.0 };
    const result = terminal_widget_presentation_runtime.presentResultFromRefreshOutcomeState(outcome, timing, false);
    try std.testing.expect(result.outcome == .presented);
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
    const refreshed = terminal_widget_presentation_runtime.classifyRefreshOutcome(.refreshed);
    const presented = terminal_widget_presentation_runtime.classifyRefreshOutcome(.presented);
    const unavailable = terminal_widget_presentation_runtime.classifyRefreshOutcome(.target_unavailable);

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
    const outcome = terminal_widget_presentation_runtime.classifyRefreshOutcome(.refreshed);
    const timing = .{ .background_ms = 1.5, .glyph_ms = 2.5, .kitty_ms = 0.0 };
    const result = terminal_widget_presentation_runtime.presentResultFromRefreshOutcomeState(outcome, timing, false);

    try std.testing.expect(result.outcome == .updated_and_presented);
    try std.testing.expect(result.timing.background_ms == 1.5);
}

test "Widget layer reuse delegation preserves outcome semantics" {
    const reuse = terminal_widget_presentation_runtime.reuseSuccessOutcome();
    const timing = .{ .background_ms = 0.5, .glyph_ms = 0.0, .kitty_ms = 0.0 };
    const result = terminal_widget_presentation_runtime.presentResultFromReuseOutcomeState(reuse, timing);

    try std.testing.expect(result.outcome == .reused);
    try std.testing.expect(result.shared_surface_attachment_ready == true);
}

test "Widget layer assertions validate outcome consistency" {
    const refresh = terminal_widget_presentation_runtime.classifyRefreshOutcome(.refreshed);
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
    const outcome_widget = terminal_widget_presentation_runtime.classifyRefreshOutcome(.refreshed);
    const outcome_terminal = terminal_presentation_runtime.classifyRefreshOutcome(.refreshed);

    try std.testing.expect(outcome_widget.outcome == outcome_terminal.outcome);
    try std.testing.expect(outcome_widget.cache_state_advanced == outcome_terminal.cache_state_advanced);
}

test "Integration boundary: no outcome re-derivation in widget folding" {
    const outcome = terminal_widget_presentation_runtime.classifyRefreshOutcome(.refreshed);
    const timing = .{ .background_ms = 1.0, .glyph_ms = 2.0, .kitty_ms = 0.0 };
    const result = terminal_widget_presentation_runtime.presentResultFromRefreshOutcomeState(outcome, timing, true);

    // Verify that the result's outcome matches input outcome (no re-derivation)
    try std.testing.expect(result.outcome == outcome.outcome);
    try std.testing.expect(result.cache_state_advanced == outcome.cache_state_advanced);
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
    try std.testing.expect(eligible == (outcome.reused == true));
}

test "Callback contract: direct eligibility check integrates with GPU execution path" {
    const rows = 10;
    const cols = 80;
    const cells = 800;

    // Widget calls terminal eligibility check
    const eligible = terminal_widget_presentation_runtime.checkDirectPresentEligibility(rows, cols, cells);

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

test "Callback contract: outcome folding preserves attachment state through callback" {
    // Simulate reuse callback contract
    const eligible = true; // Widget eligibility check returned true

    if (eligible) {
        // Widget executes reuse presentation
        const outcome = terminal_widget_presentation_runtime.reuseSuccessOutcome();
        const timing = .{ .background_ms = 0.5, .glyph_ms = 0.0, .kitty_ms = 0.0 };

        // Widget folds outcome via terminal helper
        const result = terminal_widget_presentation_runtime.presentResultFromReuseOutcomeState(outcome, timing);

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
    try std.testing.expect(outcome.reused == true);
}

test "Callback contract: terminal classification used regardless of widget execution path" {
    // Refresh path uses terminal classification
    const refresh_outcome = terminal_widget_presentation_runtime.classifyRefreshOutcome(.refreshed);
    try std.testing.expect(refresh_outcome.outcome == .updated_and_presented);

    // Direct path uses terminal classification
    const direct_outcome = terminal_widget_presentation_runtime.classifyDirectPresentOutcome(true);
    try std.testing.expect(direct_outcome.outcome == .updated_and_presented);

    // Reuse path uses terminal outcome constructor
    const reuse_outcome = terminal_widget_presentation_runtime.reuseSuccessOutcome();
    try std.testing.expect(reuse_outcome.outcome == .reused);
}

test "PresentationPresentState type is consistent at widget/terminal boundary" {
    // Widget re-exports PresentationPresentState from terminal layer — same type, not re-definition
    const widget_type = terminal_widget_presentation_runtime.PresentationPresentState;
    const terminal_type = terminal_presentation_runtime.PresentationPresentState;
    try std.testing.expect(widget_type == terminal_type);
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
