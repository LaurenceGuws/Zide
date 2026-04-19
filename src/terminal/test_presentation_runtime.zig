//! CZH-877: Helper-level invariant tests for terminal presentation runtime ownership (`CZH-S33`).
//! Validates that:
//! - Outcome classification is pure (no widget dependencies)
//! - Geometry computation is pure
//! - Outcome folding is pure
//! - Ownership boundary is clean (terminal layer can be used without widget imports)

const std = @import("std");
const presentation_runtime = @import("./presentation_runtime.zig");
const renderer_presentable_host = @import("../ui/renderer/renderer_presentable_host.zig");

test "CZH-877: Outcome classification from refresh cycle is pure" {
    const outcome_refreshed = presentation_runtime.classifyRefreshOutcome(.refreshed);
    try std.testing.expect(outcome_refreshed.outcome == .updated_and_presented);
    try std.testing.expect(outcome_refreshed.cache_state_advanced == true);

    const outcome_presented = presentation_runtime.classifyRefreshOutcome(.presented);
    try std.testing.expect(outcome_presented.outcome == .presented);
    try std.testing.expect(outcome_presented.cache_state_advanced == false);

    const outcome_unsupported = presentation_runtime.classifyRefreshOutcome(.unsupported);
    try std.testing.expect(outcome_unsupported.host_surface_target_available == false);
}

test "CZH-877: Direct present outcome classification is pure" {
    const outcome_updated = presentation_runtime.classifyDirectPresentOutcome(true);
    try std.testing.expect(outcome_updated.outcome == .updated_and_presented);
    try std.testing.expect(outcome_updated.cache_state_advanced == true);
    try std.testing.expect(outcome_updated.host_surface_target_available == true);

    const outcome_not_updated = presentation_runtime.classifyDirectPresentOutcome(false);
    try std.testing.expect(outcome_not_updated.outcome == .presented);
    try std.testing.expect(outcome_not_updated.cache_state_advanced == true);
}

test "CZH-877: Reuse success outcome invariants hold" {
    const outcome = presentation_runtime.reuseSuccessOutcome();
    try std.testing.expect(outcome.reused == true);
    try std.testing.expect(outcome.outcome == .reused);
    try std.testing.expect(outcome.cache_state_advanced == true);
    try std.testing.expect(outcome.host_surface_target_available == true);
    try std.testing.expect(outcome.shared_surface_attachment_ready == true);
}

test "CZH-877: Outcome folding produces consistent results" {
    const outcome = presentation_runtime.classifyRefreshOutcome(.refreshed);
    const timing = renderer_presentable_host.TerminalPresentTiming{
        .background_ms = 1.0,
        .glyph_ms = 2.0,
        .kitty_ms = 0.0,
    };
    const result = presentation_runtime.presentResultFromRefreshOutcomeState(outcome, timing, true);

    try std.testing.expect(result.outcome == .updated_and_presented);
    try std.testing.expect(result.timing.background_ms == 1.0);
    try std.testing.expect(result.timing.glyph_ms == 2.0);
    try std.testing.expect(result.shared_surface_attachment_ready == true);
}

test "CZH-877: Reuse outcome folding preserves attachment state" {
    const outcome = presentation_runtime.reuseSuccessOutcome();
    const timing = renderer_presentable_host.TerminalPresentTiming{
        .background_ms = 0.5,
        .glyph_ms = 0.0,
        .kitty_ms = 0.0,
    };
    const result = presentation_runtime.presentResultFromReuseOutcomeState(outcome, timing);

    try std.testing.expect(result.outcome == .reused);
    try std.testing.expect(result.cache_state_advanced == true);
    try std.testing.expect(result.shared_surface_attachment_ready == true);
}

test "CZH-877: Geometry struct is defined and initializable" {
    var geometry = presentation_runtime.PresentationGeometry{};
    try std.testing.expect(geometry.render_scale == 1.0);
    try std.testing.expect(geometry.cell_w_i == 0);
    geometry.cell_w_i = 8;
    try std.testing.expect(geometry.cell_w_i == 8);
}

test "CZH-877: RefreshedPresentablePresentationResult is defined in terminal layer" {
    const result = presentation_runtime.RefreshedPresentablePresentationResult{
        .bg_ms = 1.5,
        .glyph_ms = 2.5,
        .kitty_ms = 0.0,
        .shared_surface_attachment_ready = true,
    };
    try std.testing.expect(result.bg_ms == 1.5);
    try std.testing.expect(result.shared_surface_attachment_ready == true);
}

test "CZH-877: RefreshOutcomeState validates followup coupling" {
    var state_with_followup = presentation_runtime.RefreshOutcomeState{
        .followup_required = true,
        .followup_reason = .target_unavailable,
    };
    presentation_runtime.assertRefreshOutcomeConsistency(state_with_followup);

    var state_without_followup = presentation_runtime.RefreshOutcomeState{
        .followup_required = false,
        .followup_reason = .none,
    };
    presentation_runtime.assertRefreshOutcomeConsistency(state_without_followup);
}

test "CZH-877: DirectPresentOutcomeState validates invariant fields" {
    const outcome = presentation_runtime.classifyDirectPresentOutcome(true);
    presentation_runtime.assertDirectPresentOutcomeConsistency(outcome);
    try std.testing.expect(outcome.cache_state_advanced == true);
    try std.testing.expect(outcome.host_surface_target_available == true);
    try std.testing.expect(outcome.shared_surface_attachment_ready == false);
}

test "CZH-877: ReusePresentOutcomeState validates success coupling" {
    const outcome = presentation_runtime.reuseSuccessOutcome();
    presentation_runtime.assertReuseOutcomeConsistency(outcome);
}
