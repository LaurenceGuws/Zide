//! Helper-level invariant tests for terminal presentation runtime ownership.
//! Validates that:
//! - Outcome classification is pure (no widget dependencies)
//! - Geometry computation is pure
//! - Outcome folding is pure
//! - `refreshPresentState` is pure state computation (no side effects)
//! - Ownership boundary is clean (terminal layer can be used without widget imports)

const std = @import("std");
const presentation_runtime = @import("./presentation_runtime.zig");
const renderer_presentable_host = @import("../ui/renderer/renderer_presentable_host.zig");

test "outcome classification from refresh cycle is pure" {
    const outcome_refreshed = presentation_runtime.classifyRefreshOutcome(.refreshed);
    try std.testing.expect(outcome_refreshed.outcome == .updated_and_presented);
    try std.testing.expect(outcome_refreshed.cache_state_advanced == true);

    const outcome_presented = presentation_runtime.classifyRefreshOutcome(.presented);
    try std.testing.expect(outcome_presented.outcome == .presented);
    try std.testing.expect(outcome_presented.cache_state_advanced == false);

    const outcome_unsupported = presentation_runtime.classifyRefreshOutcome(.unsupported);
    try std.testing.expect(outcome_unsupported.host_surface_target_available == false);
}

test "Direct present outcome classification is pure" {
    const outcome_updated = presentation_runtime.classifyDirectPresentOutcome(true);
    try std.testing.expect(outcome_updated.outcome == .updated_and_presented);
    try std.testing.expect(outcome_updated.cache_state_advanced == true);
    try std.testing.expect(outcome_updated.host_surface_target_available == true);

    const outcome_not_updated = presentation_runtime.classifyDirectPresentOutcome(false);
    try std.testing.expect(outcome_not_updated.outcome == .presented);
    try std.testing.expect(outcome_not_updated.cache_state_advanced == true);
}

test "Reuse success outcome invariants hold" {
    const outcome = presentation_runtime.reuseSuccessOutcome();
    try std.testing.expect(outcome.reused == true);
    try std.testing.expect(outcome.outcome == .reused);
    try std.testing.expect(outcome.cache_state_advanced == true);
    try std.testing.expect(outcome.host_surface_target_available == true);
    try std.testing.expect(outcome.shared_surface_attachment_ready == true);
}

test "Outcome folding produces consistent results" {
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

test "Reuse outcome folding preserves attachment state" {
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

test "Geometry struct is defined and initializable" {
    var geometry = presentation_runtime.PresentationGeometry{};
    try std.testing.expect(geometry.render_scale == 1.0);
    try std.testing.expect(geometry.cell_w_i == 0);
    geometry.cell_w_i = 8;
    try std.testing.expect(geometry.cell_w_i == 8);
}

test "RefreshedPresentablePresentationResult is defined in terminal layer" {
    const result = presentation_runtime.RefreshedPresentablePresentationResult{
        .bg_ms = 1.5,
        .glyph_ms = 2.5,
        .kitty_ms = 0.0,
        .shared_surface_attachment_ready = true,
    };
    try std.testing.expect(result.bg_ms == 1.5);
    try std.testing.expect(result.shared_surface_attachment_ready == true);
}

test "RefreshOutcomeState validates followup coupling" {
    const state_with_followup = presentation_runtime.RefreshOutcomeState{
        .followup_required = true,
        .followup_reason = .target_unavailable,
    };
    presentation_runtime.assertRefreshOutcomeConsistency(state_with_followup);

    const state_without_followup = presentation_runtime.RefreshOutcomeState{
        .followup_required = false,
        .followup_reason = .none,
    };
    presentation_runtime.assertRefreshOutcomeConsistency(state_without_followup);
}

test "DirectPresentOutcomeState validates invariant fields" {
    const outcome = presentation_runtime.classifyDirectPresentOutcome(true);
    presentation_runtime.assertDirectPresentOutcomeConsistency(outcome);
    try std.testing.expect(outcome.cache_state_advanced == true);
    try std.testing.expect(outcome.host_surface_target_available == true);
    try std.testing.expect(outcome.shared_surface_attachment_ready == false);
}

test "ReusePresentOutcomeState validates success coupling" {
    const outcome = presentation_runtime.reuseSuccessOutcome();
    presentation_runtime.assertReuseOutcomeConsistency(outcome);
}

test "Outcome functions produce consistent results across multiple calls" {
    const refresh_1 = presentation_runtime.classifyRefreshOutcome(.refreshed);
    const refresh_2 = presentation_runtime.classifyRefreshOutcome(.refreshed);
    try std.testing.expect(refresh_1.outcome == refresh_2.outcome);
    try std.testing.expect(refresh_1.cache_state_advanced == refresh_2.cache_state_advanced);

    const direct_1 = presentation_runtime.classifyDirectPresentOutcome(true);
    const direct_2 = presentation_runtime.classifyDirectPresentOutcome(true);
    try std.testing.expect(direct_1.outcome == direct_2.outcome);

    const reuse_1 = presentation_runtime.reuseSuccessOutcome();
    const reuse_2 = presentation_runtime.reuseSuccessOutcome();
    try std.testing.expect(reuse_1.outcome == reuse_2.outcome);
}

test "Outcome classification remains idempotent across fold/unfold cycles" {
    const outcome = presentation_runtime.classifyRefreshOutcome(.refreshed);
    const timing = renderer_presentable_host.TerminalPresentTiming{
        .background_ms = 1.5,
        .glyph_ms = 2.5,
        .kitty_ms = 0.0,
    };
    const result = presentation_runtime.presentResultFromRefreshOutcomeState(outcome, timing, true);
    try std.testing.expect(result.outcome == outcome.outcome);
    try std.testing.expect(result.cache_state_advanced == outcome.cache_state_advanced);
}

test "All outcome classification paths maintain invariants" {
    const outcomes = [_]presentation_runtime.RefreshOutcomeState{
        presentation_runtime.classifyRefreshOutcome(.refreshed),
        presentation_runtime.classifyRefreshOutcome(.presented),
        presentation_runtime.classifyRefreshOutcome(.target_unavailable),
        presentation_runtime.classifyRefreshOutcome(.unsupported),
    };
    for (outcomes) |outcome| {
        presentation_runtime.assertRefreshOutcomeConsistency(outcome);
    }
}

test "Direct present outcome paths maintain host availability coupling" {
    const updated = presentation_runtime.classifyDirectPresentOutcome(true);
    const not_updated = presentation_runtime.classifyDirectPresentOutcome(false);

    try std.testing.expect(updated.host_surface_target_available == true);
    try std.testing.expect(not_updated.host_surface_target_available == true);

    try std.testing.expect(updated.cache_state_advanced == true);
    try std.testing.expect(not_updated.cache_state_advanced == true);
}

test "Reuse eligibility decision is pure and deterministic" {
    const FakePlan = struct {
        present_intent: enum { reuse, refresh, direct } = .reuse,
    };
    const plan = FakePlan{};

    const eligible_1 = presentation_runtime.checkReuseEligibility(plan, .{
        .view_cells_len = 10,
        .shared_surface_attachment_ready = true,
        .sync_updates_active = true,
        .supports_reuse_without_sync = false,
    });
    const eligible_2 = presentation_runtime.checkReuseEligibility(plan, .{
        .view_cells_len = 10,
        .shared_surface_attachment_ready = true,
        .sync_updates_active = true,
        .supports_reuse_without_sync = false,
    });
    try std.testing.expect(eligible_1 == eligible_2);
}

test "Reuse eligibility requires view cells" {
    const FakePlan = struct {
        present_intent: enum { reuse, refresh, direct } = .reuse,
    };
    const plan = FakePlan{};

    const with_cells = presentation_runtime.checkReuseEligibility(plan, .{
        .view_cells_len = 10,
        .shared_surface_attachment_ready = true,
        .sync_updates_active = true,
        .supports_reuse_without_sync = false,
    });
    const no_cells = presentation_runtime.checkReuseEligibility(plan, .{
        .view_cells_len = 0,
        .shared_surface_attachment_ready = true,
        .sync_updates_active = true,
        .supports_reuse_without_sync = false,
    });

    try std.testing.expect(with_cells == true);
    try std.testing.expect(no_cells == false);
}

test "Reuse eligibility requires attachment ready" {
    const FakePlan = struct {
        present_intent: enum { reuse, refresh, direct } = .reuse,
    };
    const plan = FakePlan{};

    const attachment_ready = presentation_runtime.checkReuseEligibility(plan, .{
        .view_cells_len = 10,
        .shared_surface_attachment_ready = true,
        .sync_updates_active = true,
        .supports_reuse_without_sync = false,
    });
    const attachment_not_ready = presentation_runtime.checkReuseEligibility(plan, .{
        .view_cells_len = 10,
        .shared_surface_attachment_ready = false,
        .sync_updates_active = true,
        .supports_reuse_without_sync = false,
    });

    try std.testing.expect(attachment_ready == true);
    try std.testing.expect(attachment_not_ready == false);
}

test "Reuse eligibility accepts sync_updates_active OR supports_reuse_without_sync" {
    const FakePlan = struct {
        present_intent: enum { reuse, refresh, direct } = .reuse,
    };
    const plan = FakePlan{};

    const with_sync = presentation_runtime.checkReuseEligibility(plan, .{
        .view_cells_len = 10,
        .shared_surface_attachment_ready = true,
        .sync_updates_active = true,
        .supports_reuse_without_sync = false,
    });
    const without_sync_support = presentation_runtime.checkReuseEligibility(plan, .{
        .view_cells_len = 10,
        .shared_surface_attachment_ready = true,
        .sync_updates_active = false,
        .supports_reuse_without_sync = false,
    });
    const without_sync_with_support = presentation_runtime.checkReuseEligibility(plan, .{
        .view_cells_len = 10,
        .shared_surface_attachment_ready = true,
        .sync_updates_active = false,
        .supports_reuse_without_sync = true,
    });

    try std.testing.expect(with_sync == true);
    try std.testing.expect(without_sync_support == false);
    try std.testing.expect(without_sync_with_support == true);
}

test "Reuse eligibility rejects non-reuse intent" {
    const FakePlan = struct {
        present_intent: enum { reuse, refresh, direct },
    };
    const refresh_plan = FakePlan{ .present_intent = .refresh };
    const direct_plan = FakePlan{ .present_intent = .direct };

    const refresh_result = presentation_runtime.checkReuseEligibility(refresh_plan, .{
        .view_cells_len = 10,
        .shared_surface_attachment_ready = true,
        .sync_updates_active = true,
        .supports_reuse_without_sync = false,
    });
    const direct_result = presentation_runtime.checkReuseEligibility(direct_plan, .{
        .view_cells_len = 10,
        .shared_surface_attachment_ready = true,
        .sync_updates_active = true,
        .supports_reuse_without_sync = false,
    });

    try std.testing.expect(refresh_result == false);
    try std.testing.expect(direct_result == false);
}

test "Direct present eligibility is pure and deterministic" {
    const eligible_1 = presentation_runtime.checkDirectPresentEligibility(.{
        .rows = 10,
        .cols = 80,
        .view_cells_len = 800,
    });
    const eligible_2 = presentation_runtime.checkDirectPresentEligibility(.{
        .rows = 10,
        .cols = 80,
        .view_cells_len = 800,
    });
    try std.testing.expect(eligible_1 == eligible_2);
}

test "Direct present eligibility requires rows > 0" {
    const with_rows = presentation_runtime.checkDirectPresentEligibility(.{
        .rows = 10,
        .cols = 80,
        .view_cells_len = 800,
    });
    const no_rows = presentation_runtime.checkDirectPresentEligibility(.{
        .rows = 0,
        .cols = 80,
        .view_cells_len = 800,
    });

    try std.testing.expect(with_rows == true);
    try std.testing.expect(no_rows == false);
}

test "Direct present eligibility requires cols > 0" {
    const with_cols = presentation_runtime.checkDirectPresentEligibility(.{
        .rows = 10,
        .cols = 80,
        .view_cells_len = 800,
    });
    const no_cols = presentation_runtime.checkDirectPresentEligibility(.{
        .rows = 10,
        .cols = 0,
        .view_cells_len = 800,
    });

    try std.testing.expect(with_cols == true);
    try std.testing.expect(no_cols == false);
}

test "Direct present eligibility requires view_cells_len > 0" {
    const with_cells = presentation_runtime.checkDirectPresentEligibility(.{
        .rows = 10,
        .cols = 80,
        .view_cells_len = 800,
    });
    const no_cells = presentation_runtime.checkDirectPresentEligibility(.{
        .rows = 10,
        .cols = 80,
        .view_cells_len = 0,
    });

    try std.testing.expect(with_cells == true);
    try std.testing.expect(no_cells == false);
}

// refreshPresentState purity: verifies the function performs pure state computation.
// Fake types simulate the duck-typed interface (notePresentableAvailability, backend.presentableInfo).

const FakeBackend = struct {
    available: bool,
    pub fn presentableInfo(self: @This(), _: anytype) ?bool {
        return if (self.available) true else null;
    }
};

const FakeRenderer = struct {
    backend: FakeBackend,
};

const FakeSurface = struct {
    attachment_ready: bool,
    pub fn notePresentableAvailability(self: @This(), _: bool) bool {
        return self.attachment_ready;
    }
};

const FakeView = struct {
    rows: usize = 24,
    cols: usize = 80,
};

test "refreshPresentState is pure and deterministic" {
    var surface = FakeSurface{ .attachment_ready = true };
    const renderer = FakeRenderer{ .backend = .{ .available = true } };
    const view = FakeView{};

    const s1 = presentation_runtime.refreshPresentState(&surface, &renderer, &view, .refreshed, 800, 600, 1920);
    const s2 = presentation_runtime.refreshPresentState(&surface, &renderer, &view, .refreshed, 800, 600, 1920);

    try std.testing.expect(s1.updated == s2.updated);
    try std.testing.expect(s1.present == s2.present);
    try std.testing.expect(s1.shared_surface_attachment_ready == s2.shared_surface_attachment_ready);
}

test "refreshPresentState updated flag reflects refresh result" {
    var surface = FakeSurface{ .attachment_ready = true };
    const renderer = FakeRenderer{ .backend = .{ .available = true } };
    const view = FakeView{};

    const refreshed = presentation_runtime.refreshPresentState(&surface, &renderer, &view, .refreshed, 800, 600, 1920);
    const presented = presentation_runtime.refreshPresentState(&surface, &renderer, &view, .presented, 800, 600, 1920);

    try std.testing.expect(refreshed.updated == true);
    try std.testing.expect(presented.updated == false);
}

test "refreshPresentState visible requires non-zero dimensions" {
    var surface = FakeSurface{ .attachment_ready = true };
    const renderer = FakeRenderer{ .backend = .{ .available = true } };
    const view = FakeView{};

    const visible = presentation_runtime.refreshPresentState(&surface, &renderer, &view, .refreshed, 800, 600, 1920);
    const invisible_w = presentation_runtime.refreshPresentState(&surface, &renderer, &view, .refreshed, 0, 600, 1920);
    const invisible_h = presentation_runtime.refreshPresentState(&surface, &renderer, &view, .refreshed, 800, 0, 1920);

    try std.testing.expect(visible.present == true);
    try std.testing.expect(invisible_w.present == false);
    try std.testing.expect(invisible_h.present == false);
}

test "refreshPresentState log_unavailable when attachment absent and cells present" {
    var surface = FakeSurface{ .attachment_ready = false };
    const renderer = FakeRenderer{ .backend = .{ .available = false } };
    const view = FakeView{};

    const state = presentation_runtime.refreshPresentState(&surface, &renderer, &view, .refreshed, 800, 600, 1920);

    try std.testing.expect(state.shared_surface_attachment_ready == false);
    try std.testing.expect(state.log_unavailable == true);
}

test "refreshPresentState log_unavailable suppressed when no view cells" {
    var surface = FakeSurface{ .attachment_ready = false };
    const renderer = FakeRenderer{ .backend = .{ .available = false } };
    const view = FakeView{};

    const state = presentation_runtime.refreshPresentState(&surface, &renderer, &view, .refreshed, 800, 600, 0);

    try std.testing.expect(state.log_unavailable == false);
}
