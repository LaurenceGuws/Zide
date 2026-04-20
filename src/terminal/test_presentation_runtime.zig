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
const presentable_contract = @import("../ui/renderer/presentable_contract.zig");

test "outcome classification from refresh cycle is pure" {
    const outcome_refreshed = presentation_runtime.classifyRefreshOutcome(.refreshed, true);
    try std.testing.expect(outcome_refreshed.outcome == .updated_and_presented);
    try std.testing.expect(outcome_refreshed.cache_state_advanced == true);
    try std.testing.expect(outcome_refreshed.shared_surface_attachment_ready == true);

    const outcome_presented = presentation_runtime.classifyRefreshOutcome(.presented, false);
    try std.testing.expect(outcome_presented.outcome == .presented);
    try std.testing.expect(outcome_presented.cache_state_advanced == false);
    try std.testing.expect(outcome_presented.shared_surface_attachment_ready == false);

    const outcome_unsupported = presentation_runtime.classifyRefreshOutcome(.unsupported, false);
    try std.testing.expect(outcome_unsupported.host_surface_target_available == false);
    try std.testing.expect(outcome_unsupported.shared_surface_attachment_ready == false);
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
    try std.testing.expect(outcome.outcome == .reused);
    try std.testing.expect(outcome.cache_state_advanced == true);
    try std.testing.expect(outcome.host_surface_target_available == true);
    try std.testing.expect(outcome.shared_surface_attachment_ready == true);
}

test "Outcome folding produces consistent results" {
    const outcome = presentation_runtime.classifyRefreshOutcome(.refreshed, true);
    const timing = renderer_presentable_host.TerminalPresentTiming{
        .background_ms = 1.0,
        .glyph_ms = 2.0,
        .kitty_ms = 0.0,
    };
    const result = presentation_runtime.foldRefreshOutcomeToPresent(outcome, timing);

    try std.testing.expect(result.outcome == .updated_and_presented);
    try std.testing.expect(result.timing.background_ms == 1.0);
    try std.testing.expect(result.timing.glyph_ms == 2.0);
    try std.testing.expect(result.shared_surface_attachment_ready == true);
}

test "Refresh classification carries inline conjunction coupling" {
    const attached = presentation_runtime.classifyRefreshOutcome(.presented, true);
    try std.testing.expect(attached.shared_surface_attachment_ready == true);
    try std.testing.expect(attached.host_surface_target_available == true);

    const detached = presentation_runtime.classifyRefreshOutcome(.presented, false);
    try std.testing.expect(detached.shared_surface_attachment_ready == false);
    try std.testing.expect(detached.host_surface_target_available == true);

    const unavailable = presentation_runtime.classifyRefreshOutcome(.target_unavailable, false);
    try std.testing.expect(unavailable.shared_surface_attachment_ready == false);
    try std.testing.expect(unavailable.host_surface_target_available == false);
    try std.testing.expect(unavailable.followup.required == true);
    try std.testing.expectEqual(unavailable.followup.reason, .target_unavailable);
}

test "Direct present folding uses canonical helper" {
    const outcome = presentation_runtime.classifyDirectPresentOutcome(true);
    const timing = renderer_presentable_host.TerminalPresentTiming{
        .background_ms = 0.25,
        .glyph_ms = 0.75,
        .kitty_ms = 0.0,
    };
    const result = presentation_runtime.foldDirectOutcomeToPresent(outcome, timing);

    try std.testing.expect(result.outcome == .updated_and_presented);
    try std.testing.expect(result.cache_state_advanced == true);
    try std.testing.expect(result.host_surface_target_available == true);
    try std.testing.expect(result.shared_surface_attachment_ready == false);
}

test "Refresh result helper preserves folded refresh transport fields" {
    const timing = renderer_presentable_host.TerminalPresentTiming{
        .background_ms = 4.25,
        .glyph_ms = 1.5,
        .kitty_ms = 0.75,
    };
    const refreshed = presentation_runtime.foldRefreshOutcomeToPresent(
        presentation_runtime.classifyRefreshOutcome(.refreshed, true),
        timing,
    );

    try std.testing.expectEqual(refreshed.outcome, .updated_and_presented);
    try std.testing.expectEqual(refreshed.timing.background_ms, timing.background_ms);
    try std.testing.expectEqual(refreshed.timing.glyph_ms, timing.glyph_ms);
    try std.testing.expectEqual(refreshed.timing.kitty_ms, timing.kitty_ms);
    try std.testing.expect(refreshed.shared_surface_attachment_ready == true);
}

test "Refresh result helper preserves followup fields for target_unavailable transport" {
    const timing = renderer_presentable_host.TerminalPresentTiming{
        .background_ms = 0.9,
        .glyph_ms = 0.4,
        .kitty_ms = 0.0,
    };
    const refreshed = presentation_runtime.foldRefreshOutcomeToPresent(
        presentation_runtime.classifyRefreshOutcome(.target_unavailable, false),
        timing,
    );

    try std.testing.expectEqual(refreshed.outcome, .presented);
    try std.testing.expectEqual(refreshed.followup.required, true);
    try std.testing.expectEqual(refreshed.followup.reason, .target_unavailable);
    try std.testing.expectEqual(refreshed.host_surface_target_available, false);
    try std.testing.expectEqual(refreshed.shared_surface_attachment_ready, false);
}

test "Reuse fold helper preserves non-reused transport state" {
    const attempt = presentation_runtime.ReusePresentOutcomeState{
        .outcome = .skipped,
        .cache_state_advanced = false,
        .host_surface_target_available = true,
        .shared_surface_attachment_ready = false,
    };
    const timing = renderer_presentable_host.TerminalPresentTiming{
        .background_ms = 0.1,
        .glyph_ms = 0.2,
        .kitty_ms = 0.3,
    };
    const result = presentation_runtime.foldReuseOutcomeToPresent(attempt, timing);

    try std.testing.expectEqual(result.outcome, attempt.outcome);
    try std.testing.expectEqual(result.cache_state_advanced, attempt.cache_state_advanced);
    try std.testing.expectEqual(result.host_surface_target_available, attempt.host_surface_target_available);
    try std.testing.expectEqual(result.shared_surface_attachment_ready, attempt.shared_surface_attachment_ready);
    try std.testing.expectEqual(result.timing.background_ms, timing.background_ms);
    try std.testing.expectEqual(result.timing.glyph_ms, timing.glyph_ms);
    try std.testing.expectEqual(result.timing.kitty_ms, timing.kitty_ms);
}

test "Reuse boundary helper forwards reused and non-reused transport consistently" {
    const reused_attempt = presentation_runtime.reuseSuccessOutcome();
    const non_reused_attempt = presentation_runtime.ReusePresentOutcomeState{
        .outcome = .skipped,
        .cache_state_advanced = false,
        .host_surface_target_available = false,
        .shared_surface_attachment_ready = false,
    };
    const timing = renderer_presentable_host.TerminalPresentTiming{
        .background_ms = 1.1,
        .glyph_ms = 0.0,
        .kitty_ms = 0.0,
    };

    const reused_result = presentation_runtime.foldReuseOutcomeToPresent(reused_attempt, timing);
    const non_reused_result = presentation_runtime.foldReuseOutcomeToPresent(non_reused_attempt, timing);

    try std.testing.expectEqual(reused_result.outcome, .reused);
    try std.testing.expectEqual(reused_result.cache_state_advanced, true);
    try std.testing.expectEqual(reused_result.shared_surface_attachment_ready, true);
    try std.testing.expectEqual(non_reused_result.outcome, .skipped);
    try std.testing.expectEqual(non_reused_result.cache_state_advanced, false);
    try std.testing.expectEqual(non_reused_result.shared_surface_attachment_ready, false);
    try std.testing.expectEqual(reused_result.timing.background_ms, timing.background_ms);
    try std.testing.expectEqual(non_reused_result.timing.background_ms, timing.background_ms);
}

test "Direct boundary timing carrier preserves explicit timing transport" {
    const timing = renderer_presentable_host.TerminalPresentTiming{
        .background_ms = 2.0,
        .glyph_ms = 3.5,
        .kitty_ms = 1.25,
    };

    try std.testing.expectEqual(timing.background_ms, 2.0);
    try std.testing.expectEqual(timing.glyph_ms, 3.5);
    try std.testing.expectEqual(timing.kitty_ms, 1.25);
}

test "Helper contraction keeps one canonical reuse fold helper declaration" {
    comptime {
        std.debug.assert(@hasDecl(presentation_runtime, "foldReuseOutcomeToPresent"));
        std.debug.assert(!@hasDecl(presentation_runtime, "foldReuseAttemptOutcome"));
        std.debug.assert(!@hasDecl(presentation_runtime, "presentResultFromReuseOutcomeState"));
    }
}

test "Helper contraction keeps collapsed refresh and direct transport surface" {
    comptime {
        std.debug.assert(@hasDecl(presentation_runtime, "foldRefreshOutcomeToPresent"));
        std.debug.assert(@hasDecl(presentation_runtime, "foldDirectOutcomeToPresent"));
        std.debug.assert(@hasDecl(presentation_runtime, "FoldTransportFields"));
        std.debug.assert(!@hasDecl(presentation_runtime, "presentResultFromOutcomeState"));
        std.debug.assert(!@hasDecl(presentation_runtime, "applyOutcomeSpecificFields"));
        std.debug.assert(!@hasDecl(presentation_runtime, "refreshedPresentationResultFromCycle"));
        std.debug.assert(!@hasDecl(presentation_runtime, "directPresentTimingResult"));
    }
}

test "Helper contraction removes boundary mapping helper callsites" {
    comptime {
        std.debug.assert(!@hasDecl(presentation_runtime, "foldFieldsFromRefreshOutcome"));
        std.debug.assert(!@hasDecl(presentation_runtime, "foldFieldsFromReuseOutcome"));
        std.debug.assert(!@hasDecl(presentation_runtime, "foldFieldsFromDirectOutcome"));
        std.debug.assert(@hasDecl(presentation_runtime, "foldRefreshEntry"));
        std.debug.assert(@hasDecl(presentation_runtime, "foldReuseEntry"));
        std.debug.assert(@hasDecl(presentation_runtime, "foldDirectEntry"));
        std.debug.assert(@hasDecl(presentation_runtime, "refreshTransportFromResult"));
        std.debug.assert(@hasDecl(presentation_runtime, "reuseTransportFromOutcome"));
        std.debug.assert(@hasDecl(presentation_runtime, "directTransportFromUpdated"));
    }
}

test "Fold routes consume contracted transport carrier directly" {
    const timing = renderer_presentable_host.TerminalPresentTiming{ .background_ms = 0.1, .glyph_ms = 0.2, .kitty_ms = 0.3 };

    const refresh = presentation_runtime.classifyRefreshOutcome(.presented, true);
    const refresh_folded = presentation_runtime.foldRefreshOutcomeToPresent(refresh, timing);
    try std.testing.expectEqual(refresh_folded.outcome, refresh.transport.outcome);

    const reuse = presentation_runtime.ReusePresentOutcomeState{
        .transport = .{ .outcome = .skipped, .cache_state_advanced = false, .host_surface_target_available = true, .shared_surface_attachment_ready = false },
        .outcome = .skipped,
        .cache_state_advanced = false,
        .host_surface_target_available = true,
        .shared_surface_attachment_ready = false,
    };
    const reuse_folded = presentation_runtime.foldReuseOutcomeToPresent(reuse, timing);
    try std.testing.expectEqual(reuse_folded.outcome, reuse.transport.outcome);

    const direct = presentation_runtime.classifyDirectPresentOutcome(true);
    const direct_folded = presentation_runtime.foldDirectOutcomeToPresent(direct, timing);
    try std.testing.expectEqual(direct_folded.outcome, direct.transport.outcome);
}

test "Boundary field routes stay locked to transport carriers" {
    const refresh = presentation_runtime.classifyRefreshOutcome(.presented, true);
    try std.testing.expectEqual(refresh.transport.outcome, refresh.outcome);
    try std.testing.expectEqual(refresh.transport.cache_state_advanced, refresh.cache_state_advanced);

    const reuse = presentation_runtime.reuseSuccessOutcome();
    try std.testing.expectEqual(reuse.transport.outcome, reuse.outcome);
    try std.testing.expectEqual(reuse.transport.shared_surface_attachment_ready, reuse.shared_surface_attachment_ready);

    const direct = presentation_runtime.classifyDirectPresentOutcome(false);
    try std.testing.expectEqual(direct.transport.outcome, direct.outcome);
    try std.testing.expectEqual(direct.transport.host_surface_target_available, direct.host_surface_target_available);
}

test "Unified fold transport fields map through canonical reuse fold helper" {
    const timing = renderer_presentable_host.TerminalPresentTiming{
        .background_ms = 0.25,
        .glyph_ms = 0.5,
        .kitty_ms = 0.75,
    };
    const outcome = presentation_runtime.ReusePresentOutcomeState{
        .outcome = .skipped,
        .cache_state_advanced = false,
        .host_surface_target_available = true,
        .shared_surface_attachment_ready = false,
    };
    const result = presentation_runtime.foldReuseOutcomeToPresent(outcome, timing);
    try std.testing.expectEqual(result.outcome, outcome.outcome);
    try std.testing.expectEqual(result.cache_state_advanced, outcome.cache_state_advanced);
    try std.testing.expectEqual(result.host_surface_target_available, outcome.host_surface_target_available);
    try std.testing.expectEqual(result.shared_surface_attachment_ready, outcome.shared_surface_attachment_ready);
}

test "Refresh boundary carrier narrows to TerminalPresentResult" {
    const timing = renderer_presentable_host.TerminalPresentTiming{
        .background_ms = 0.2,
        .glyph_ms = 0.3,
        .kitty_ms = 0.4,
    };
    const result = presentation_runtime.foldRefreshOutcomeToPresent(
        presentation_runtime.classifyRefreshOutcome(.presented, true),
        timing,
    );
    try std.testing.expect(@TypeOf(result) == renderer_presentable_host.TerminalPresentResult);
    try std.testing.expectEqual(result.timing.background_ms, timing.background_ms);
}

test "Outcome carriers keep locked canonical field shapes" {
    comptime {
        {
            const fields = @typeInfo(presentation_runtime.RefreshOutcomeState).@"struct".fields;
            var followup_fields: usize = 0;
            for (fields) |f| {
                if (std.mem.eql(u8, f.name, "followup")) followup_fields += 1;
            }
            std.debug.assert(followup_fields == 1);
        }
        {
            const fields = @typeInfo(presentation_runtime.FoldTransportFields).@"struct".fields;
            var outcome: usize = 0;
            var cache: usize = 0;
            var host: usize = 0;
            var attachment: usize = 0;
            for (fields) |f| {
                if (std.mem.eql(u8, f.name, "outcome")) outcome += 1;
                if (std.mem.eql(u8, f.name, "cache_state_advanced")) cache += 1;
                if (std.mem.eql(u8, f.name, "host_surface_target_available")) host += 1;
                if (std.mem.eql(u8, f.name, "shared_surface_attachment_ready")) attachment += 1;
            }
            std.debug.assert(outcome == 1 and cache == 1 and host == 1 and attachment == 1);
        }
        {
            var transport_count: usize = 0;
            for (@typeInfo(presentation_runtime.ReusePresentOutcomeState).@"struct".fields) |f| {
                if (std.mem.eql(u8, f.name, "transport")) transport_count += 1;
            }
            std.debug.assert(transport_count == 1);
        }
        {
            var transport_count: usize = 0;
            for (@typeInfo(presentation_runtime.DirectPresentOutcomeState).@"struct".fields) |f| {
                if (std.mem.eql(u8, f.name, "transport")) transport_count += 1;
            }
            std.debug.assert(transport_count == 1);
        }
    }
}

test "Reuse outcome folding preserves attachment state" {
    const outcome = presentation_runtime.reuseSuccessOutcome();
    const timing = renderer_presentable_host.TerminalPresentTiming{
        .background_ms = 0.5,
        .glyph_ms = 0.0,
        .kitty_ms = 0.0,
    };
    const result = presentation_runtime.foldReuseOutcomeToPresent(outcome, timing);

    try std.testing.expect(result.outcome == .reused);
    try std.testing.expect(result.cache_state_advanced == true);
    try std.testing.expect(result.shared_surface_attachment_ready == true);
}

test "Reuse boundary helper route is deterministic across repeated folds" {
    const attempt = presentation_runtime.ReusePresentOutcomeState{
        .outcome = .skipped,
        .cache_state_advanced = false,
        .host_surface_target_available = true,
        .shared_surface_attachment_ready = false,
    };
    const timing = renderer_presentable_host.TerminalPresentTiming{
        .background_ms = 0.7,
        .glyph_ms = 0.8,
        .kitty_ms = 0.9,
    };

    const first_fold = presentation_runtime.foldReuseOutcomeToPresent(attempt, timing);
    const second_fold = presentation_runtime.foldReuseOutcomeToPresent(attempt, timing);

    try std.testing.expectEqual(first_fold.outcome, second_fold.outcome);
    try std.testing.expectEqual(first_fold.cache_state_advanced, second_fold.cache_state_advanced);
    try std.testing.expectEqual(first_fold.host_surface_target_available, second_fold.host_surface_target_available);
    try std.testing.expectEqual(first_fold.shared_surface_attachment_ready, second_fold.shared_surface_attachment_ready);
    try std.testing.expectEqual(first_fold.timing.background_ms, second_fold.timing.background_ms);
    try std.testing.expectEqual(first_fold.timing.glyph_ms, second_fold.timing.glyph_ms);
    try std.testing.expectEqual(first_fold.timing.kitty_ms, second_fold.timing.kitty_ms);
}

test "Refresh boundary helper route matches canonical refresh folded result route" {
    const timing = renderer_presentable_host.TerminalPresentTiming{
        .background_ms = 0.3,
        .glyph_ms = 0.6,
        .kitty_ms = 0.9,
    };
    const via_boundary = presentation_runtime.foldRefreshOutcomeToPresent(
        presentation_runtime.classifyRefreshOutcome(.refreshed, true),
        timing,
    );

    const outcome_state = presentation_runtime.classifyRefreshOutcome(.refreshed, true);
    const via_canonical_fold = presentation_runtime.foldRefreshOutcomeToPresent(outcome_state, timing);

    try std.testing.expectEqual(via_boundary.outcome, via_canonical_fold.outcome);
    try std.testing.expectEqual(via_boundary.cache_state_advanced, via_canonical_fold.cache_state_advanced);
    try std.testing.expectEqual(via_boundary.host_surface_target_available, via_canonical_fold.host_surface_target_available);
    try std.testing.expectEqual(via_boundary.shared_surface_attachment_ready, via_canonical_fold.shared_surface_attachment_ready);
    try std.testing.expectEqual(via_boundary.followup.required, via_canonical_fold.followup.required);
    try std.testing.expectEqual(via_boundary.followup.reason, via_canonical_fold.followup.reason);
    try std.testing.expectEqual(via_boundary.timing.background_ms, via_canonical_fold.timing.background_ms);
    try std.testing.expectEqual(via_boundary.timing.glyph_ms, via_canonical_fold.timing.glyph_ms);
    try std.testing.expectEqual(via_boundary.timing.kitty_ms, via_canonical_fold.timing.kitty_ms);
}

test "Geometry struct is defined and initializable" {
    var geometry = presentation_runtime.PresentationGeometry{};
    try std.testing.expect(geometry.render_scale == 1.0);
    try std.testing.expect(geometry.cell_w_i == 0);
    geometry.cell_w_i = 8;
    try std.testing.expect(geometry.cell_w_i == 8);
}

test "Refresh boundary result carrier is terminal present result" {
    const result = renderer_presentable_host.TerminalPresentResult{
        .outcome = .presented,
        .shared_surface_attachment_ready = true,
        .timing = .{
            .background_ms = 1.5,
            .glyph_ms = 2.5,
            .kitty_ms = 0.0,
        },
    };
    try std.testing.expect(result.timing.background_ms == 1.5);
    try std.testing.expect(result.shared_surface_attachment_ready == true);
}

test "RefreshOutcomeState validates followup coupling" {
    const state_with_followup = presentation_runtime.RefreshOutcomeState{
        .followup = .{ .required = true, .reason = .target_unavailable },
    };
    presentation_runtime.assertRefreshOutcomeConsistency(state_with_followup);

    const state_without_followup = presentation_runtime.RefreshOutcomeState{
        .followup = .{ .required = false, .reason = .none },
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
    const refresh_1 = presentation_runtime.classifyRefreshOutcome(.refreshed, true);
    const refresh_2 = presentation_runtime.classifyRefreshOutcome(.refreshed, true);
    try std.testing.expect(refresh_1.outcome == refresh_2.outcome);
    try std.testing.expect(refresh_1.cache_state_advanced == refresh_2.cache_state_advanced);
    try std.testing.expect(refresh_1.shared_surface_attachment_ready == refresh_2.shared_surface_attachment_ready);

    const direct_1 = presentation_runtime.classifyDirectPresentOutcome(true);
    const direct_2 = presentation_runtime.classifyDirectPresentOutcome(true);
    try std.testing.expect(direct_1.outcome == direct_2.outcome);

    const reuse_1 = presentation_runtime.reuseSuccessOutcome();
    const reuse_2 = presentation_runtime.reuseSuccessOutcome();
    try std.testing.expect(reuse_1.outcome == reuse_2.outcome);
}

test "Outcome classification remains idempotent across fold/unfold cycles" {
    const outcome = presentation_runtime.classifyRefreshOutcome(.refreshed, true);
    const timing = renderer_presentable_host.TerminalPresentTiming{
        .background_ms = 1.5,
        .glyph_ms = 2.5,
        .kitty_ms = 0.0,
    };
    const result = presentation_runtime.foldRefreshOutcomeToPresent(outcome, timing);
    try std.testing.expect(result.outcome == outcome.outcome);
    try std.testing.expect(result.cache_state_advanced == outcome.cache_state_advanced);
    try std.testing.expect(result.shared_surface_attachment_ready == outcome.shared_surface_attachment_ready);
}

test "All outcome classification paths maintain invariants" {
    const outcomes = [_]presentation_runtime.RefreshOutcomeState{
        presentation_runtime.classifyRefreshOutcome(.refreshed, true),
        presentation_runtime.classifyRefreshOutcome(.presented, true),
        presentation_runtime.classifyRefreshOutcome(.target_unavailable, false),
        presentation_runtime.classifyRefreshOutcome(.unsupported, false),
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

test "Direct folded-result route preserves classification fields" {
    const direct_updated = presentation_runtime.classifyDirectPresentOutcome(true);
    const timing = renderer_presentable_host.TerminalPresentTiming{
        .background_ms = 3.0,
        .glyph_ms = 1.0,
        .kitty_ms = 0.0,
    };
    const result = presentation_runtime.foldDirectOutcomeToPresent(direct_updated, timing);

    try std.testing.expect(result.outcome == direct_updated.outcome);
    try std.testing.expect(result.cache_state_advanced == direct_updated.cache_state_advanced);
    try std.testing.expect(result.host_surface_target_available == direct_updated.host_surface_target_available);
    try std.testing.expect(result.shared_surface_attachment_ready == direct_updated.shared_surface_attachment_ready);
    try std.testing.expect(result.timing.background_ms == timing.background_ms);
    try std.testing.expect(result.timing.glyph_ms == timing.glyph_ms);
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

    const s1 = presentation_runtime.refreshPresentState(&surface, &renderer, .refreshed, 800, 600);
    const s2 = presentation_runtime.refreshPresentState(&surface, &renderer, .refreshed, 800, 600);

    try std.testing.expect(s1.updated == s2.updated);
    try std.testing.expect(s1.present == s2.present);
    try std.testing.expect(s1.shared_surface_attachment_ready == s2.shared_surface_attachment_ready);
}

test "refreshPresentState updated flag reflects refresh result" {
    var surface = FakeSurface{ .attachment_ready = true };
    const renderer = FakeRenderer{ .backend = .{ .available = true } };
    const view = FakeView{};

    const refreshed = presentation_runtime.refreshPresentState(&surface, &renderer, .refreshed, 800, 600);
    const presented = presentation_runtime.refreshPresentState(&surface, &renderer, .presented, 800, 600);

    try std.testing.expect(refreshed.updated == true);
    try std.testing.expect(presented.updated == false);
}

test "refreshPresentState visible requires non-zero dimensions" {
    var surface = FakeSurface{ .attachment_ready = true };
    const renderer = FakeRenderer{ .backend = .{ .available = true } };
    const view = FakeView{};

    const visible = presentation_runtime.refreshPresentState(&surface, &renderer, .refreshed, 800, 600);
    const invisible_w = presentation_runtime.refreshPresentState(&surface, &renderer, .refreshed, 0, 600);
    const invisible_h = presentation_runtime.refreshPresentState(&surface, &renderer, .refreshed, 800, 0);

    try std.testing.expect(visible.present == true);
    try std.testing.expect(invisible_w.present == false);
    try std.testing.expect(invisible_h.present == false);
}

test "attachment state computed via canonical path only" {
    // Test binding for CZH-1155 attachment consistency gap remediation
    // Validates that attachment state is immutable through refresh path
    const attached = presentation_runtime.classifyRefreshOutcome(.refreshed, true);
    const detached = presentation_runtime.classifyRefreshOutcome(.refreshed, false);

    try std.testing.expect(attached.shared_surface_attachment_ready == true);
    try std.testing.expect(attached.host_surface_target_available == true);

    try std.testing.expect(detached.shared_surface_attachment_ready == false);
    try std.testing.expect(detached.host_surface_target_available == true);

    // Attachment state immutability through fold
    const timing = renderer_presentable_host.TerminalPresentTiming{ .background_ms = 1.0, .glyph_ms = 1.0, .kitty_ms = 0.0 };
    const folded_attached = presentation_runtime.foldRefreshOutcomeToPresent(attached, timing);
    const folded_detached = presentation_runtime.foldRefreshOutcomeToPresent(detached, timing);

    try std.testing.expect(folded_attached.shared_surface_attachment_ready == true);
    try std.testing.expect(folded_detached.shared_surface_attachment_ready == false);
}
