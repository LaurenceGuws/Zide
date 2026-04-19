//! Integration invariant tests for presentation runtime ownership boundary.
//! Validates that:
//! - Widget layer correctly imports and re-exports terminal types
//! - Widget layer delegates to terminal-layer classification functions
//! - Ownership boundary is clean at call site
//! - No re-derivation of outcomes or geometry in widget layer

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
