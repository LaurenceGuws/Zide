//! Terminal **presentation runtime:** canonical outcome classification and fold routes
//! for terminal presentation (refresh cycle, reuse path, direct draw). Owned by terminal layer.
//!
//! This seam consolidates outcome semantics and fold logic so widget layer does not re-derive
//! presentation results. Widget runtime delegates to this module and interprets outcomes only.
//!
//! **Canonical outcome paths:**
//! - `classifyRefreshOutcome(refresh) -> RefreshOutcomeState`: semantic classification of refresh result
//! - `classifyDirectPresentOutcome(updated) -> DirectPresentOutcomeState`: outcome from direct draw
//! - `reuseSuccessOutcome() -> ReusePresentOutcomeState`: outcome when reuse path succeeds
//!
//! **Canonical fold routes:**
//! - `presentResultFromRefreshOutcomeState(outcome, timing) -> TerminalPresentResult`: fold refresh outcomes
//! - `presentResultFromReuseOutcomeState(outcome, timing) -> TerminalPresentResult`: fold reuse outcomes
//! - `presentResultFromOutcomeState()`: generic fold used by both paths

const std = @import("std");
const renderer_presentable_host = @import("../ui/renderer/renderer_presentable_host.zig");
const presentable_contract = @import("../ui/renderer/presentable_contract.zig");
const layout_types = @import("../types/layout.zig");

const TerminalPresentOutcome = presentable_contract.TerminalPresentOutcome;
const TerminalViewGeometry = layout_types.TerminalViewGeometry;
const TerminalPresentFollowupReason = presentable_contract.TerminalPresentFollowupReason;
const TerminalPresentResult = renderer_presentable_host.TerminalPresentResult;
const TerminalPresentableRefresh = renderer_presentable_host.TerminalPresentableRefresh;

/// **Outcome snapshot from refresh cycle:** carries result and followup state.
pub const RefreshOutcomeState = struct {
    outcome: TerminalPresentOutcome = .presented,
    cache_state_advanced: bool = false,
    host_surface_target_available: bool = false,
    followup_required: bool = false,
    followup_reason: TerminalPresentFollowupReason = .none,
};

/// **Direct present outcome snapshot:** result when drawing directly bypasses reuse path.
/// Host-target leg hardcoded to `true` (drawing implies renderer is available).
/// Conjunction hardcoded to `false` (direct path does not verify full attachment before returning).
/// *Invariants:* `cache_state_advanced` always true (drawing implies advancement); both legs fixed.
/// Hardening assertions validate invariants in `classifyDirectPresentOutcome()`.
pub const DirectPresentOutcomeState = struct {
    outcome: TerminalPresentOutcome = .presented,
    cache_state_advanced: bool = true,
    host_surface_target_available: bool = true,
    shared_surface_attachment_ready: bool = false,
};

/// **Outcome snapshot from reuse path:** carries result of the reuse attempt.
pub const ReusePresentOutcomeState = struct {
    reused: bool = false,
    outcome: TerminalPresentOutcome = .skipped,
    cache_state_advanced: bool = false,
    /// **Leg only** — host drawable-target (renderer `terminalPresentableInfo`); not conjunction.
    host_surface_target_available: bool = false,
    /// **Full conjunction** — terminal presentable pipeline ∧ host target (from `notePresentableAvailability`).
    /// *Canonical route:* must be populated by canonical helper, never hardcoded or re-derived.
    shared_surface_attachment_ready: bool = false,
};

/// **Classify refresh cycle outcome:** derives outcome from refresh result.
/// Maps `TerminalPresentableRefresh` enum to `RefreshOutcomeState` fields: outcome, cache advancement,
/// host availability, and followup requirements.
/// *Hardening:* validates outcome consistency before returning.
pub fn classifyRefreshOutcome(refresh: TerminalPresentableRefresh) RefreshOutcomeState {
    const outcome_state: RefreshOutcomeState = .{
        .outcome = if (refresh == .refreshed) .updated_and_presented else .presented,
        .cache_state_advanced = refresh == .refreshed,
        .host_surface_target_available = refresh != .unsupported and refresh != .target_unavailable,
        .followup_required = refresh == .target_unavailable,
        .followup_reason = if (refresh == .target_unavailable) .target_unavailable else .none,
    };
    assertRefreshOutcomeConsistency(outcome_state);
    return outcome_state;
}

/// **Classify direct present outcome:** derive outcome from direct draw completion.
/// Invariant: both legs and conjunction are fixed to correct values (drawing succeeded).
/// *Hardening:* validates invariant fields to catch invalid state early.
pub fn classifyDirectPresentOutcome(updated: bool) DirectPresentOutcomeState {
    const outcome_state: DirectPresentOutcomeState = .{
        .outcome = if (updated) .updated_and_presented else .presented,
    };
    assertDirectPresentOutcomeConsistency(outcome_state);
    return outcome_state;
}

/// **Outcome for successful reuse:** when reuse path completes successfully,
/// construct outcome state with all fields true (reuse succeeded, cache advanced, attachment ready).
/// Invariant: outcome == .reused requires cache_state_advanced && host_surface_target_available && shared_surface_attachment_ready.
pub fn reuseSuccessOutcome() ReusePresentOutcomeState {
    const outcome: ReusePresentOutcomeState = .{
        .reused = true,
        .outcome = .reused,
        .cache_state_advanced = true,
        .host_surface_target_available = true,
        .shared_surface_attachment_ready = true,
    };
    assertReuseOutcomeConsistency(outcome);
    return outcome;
}

/// **Generic result fold:** construct host-facing `TerminalPresentResult` from outcome
/// state fields. `host_surface_target_available` is **leg only**; `shared_surface_attachment_ready` is the
/// **conjunction** when supplied (not report snapshot). **Canonical fold helper for all outcome paths**
/// — all outcome-specific folds route through this function.
/// *Consolidation:* central hub of fold path composition — `presentResultFromRefreshOutcomeState`
/// and `presentResultFromReuseOutcomeState` call this with outcome-specific parameters, then apply
/// outcome-type-specific fields via `applyOutcomeSpecificFields`.
/// *Hardening:* validates output result consistency across all outcome types.
pub fn presentResultFromOutcomeState(
    outcome: TerminalPresentOutcome,
    cache_state_advanced: bool,
    host_surface_target_available: bool,
    timing: renderer_presentable_host.TerminalPresentTiming,
    shared_surface_attachment_ready: bool,
) TerminalPresentResult {
    const result: TerminalPresentResult = .{
        .outcome = outcome,
        .cache_state_advanced = cache_state_advanced,
        .host_surface_target_available = host_surface_target_available,
        .shared_surface_attachment_ready = shared_surface_attachment_ready,
        .timing = timing,
    };
    // Harden: validate output result consistency across outcome types
    if (outcome == .reused) {
        std.debug.assert(result.cache_state_advanced == true);
        std.debug.assert(result.shared_surface_attachment_ready == true);
    }
    // Direct outcome: cache always advanced, host target always available
    if (outcome == .updated_and_presented or outcome == .presented) {
        if (cache_state_advanced and host_surface_target_available) {
            // For direct path, these invariants must hold together
            std.debug.assert(result.outcome == .updated_and_presented or result.outcome == .presented);
        }
    }
    return result;
}

/// **Canonical outcome fold for refresh path:** uses conjunction computed in refresh cycle.
/// *Hardening:* validates outcome -> result threading and followup propagation.
/// *Consolidation:* routes refresh outcomes through generic fold with followup assignment.
pub fn presentResultFromRefreshOutcomeState(
    outcome_state: RefreshOutcomeState,
    timing: renderer_presentable_host.TerminalPresentTiming,
    shared_surface_attachment_ready: bool,
) TerminalPresentResult {
    assertRefreshOutcomeConsistency(outcome_state);
    var result = presentResultFromOutcomeState(
        outcome_state.outcome,
        outcome_state.cache_state_advanced,
        outcome_state.host_surface_target_available,
        timing,
        shared_surface_attachment_ready,
    );
    applyOutcomeSpecificFields(&result, outcome_state.followup_required, outcome_state.followup_reason);
    // Harden: verify followup propagates correctly through fold
    if (outcome_state.followup_required) {
        std.debug.assert(result.followup.required == true);
        std.debug.assert(result.followup.reason != .none);
    }
    return result;
}

/// **Canonical outcome fold for reuse path:** validates input consistency before folding.
/// *Consolidation:* routes reuse outcomes through generic fold with input validation.
pub fn presentResultFromReuseOutcomeState(
    outcome_state: ReusePresentOutcomeState,
    timing: renderer_presentable_host.TerminalPresentTiming,
) TerminalPresentResult {
    // Harden: validate input state before folding
    if (outcome_state.reused) {
        std.debug.assert(outcome_state.outcome == .reused);
        std.debug.assert(outcome_state.cache_state_advanced == true);
        std.debug.assert(outcome_state.host_surface_target_available == true);
        std.debug.assert(outcome_state.shared_surface_attachment_ready == true);
    }
    return presentResultFromOutcomeState(
        outcome_state.outcome,
        outcome_state.cache_state_advanced,
        outcome_state.host_surface_target_available,
        timing,
        outcome_state.shared_surface_attachment_ready,
    );
}

/// **Validate reuse outcome consistency:** hardening check that reuse outcome state has correct field values.
pub fn assertReuseOutcomeConsistency(state: ReusePresentOutcomeState) void {
    if (state.reused) {
        std.debug.assert(state.cache_state_advanced == true);
        std.debug.assert(state.host_surface_target_available == true);
        std.debug.assert(state.shared_surface_attachment_ready == true);
    }
}

/// **Validate direct present outcome consistency:** hardening check that direct present outcome
/// state has invariant field values. Direct draws always advance cache and have renderer available;
/// conjunction is false (not pre-verified).
pub fn assertDirectPresentOutcomeConsistency(state: DirectPresentOutcomeState) void {
    std.debug.assert(state.cache_state_advanced == true);
    std.debug.assert(state.host_surface_target_available == true);
    std.debug.assert(state.shared_surface_attachment_ready == false);
}

/// **Validate refresh outcome consistency:** consolidation of refresh-path assertion patterns.
/// Verifies that followup coupling invariants hold (if followup_required, then followup_reason != .none).
pub fn assertRefreshOutcomeConsistency(state: RefreshOutcomeState) void {
    if (state.followup_required) {
        std.debug.assert(state.followup_reason != .none);
    } else {
        std.debug.assert(state.followup_reason == .none);
    }
}

/// **Consolidated fold composition pattern:** Two-step fold for outcome types with followup fields.
/// Step 1: Call `presentResultFromOutcomeState` to construct base result from core outcome fields.
/// Step 2: Call `applyOutcomeSpecificFields` to add outcome-type-specific fields (e.g., followup).
pub fn applyOutcomeSpecificFields(
    result: *TerminalPresentResult,
    followup_required: bool,
    followup_reason: TerminalPresentFollowupReason,
) void {
    result.followup.required = followup_required;
    result.followup.reason = followup_reason;
}

/// **Consolidated attachment state computation:** derives host-target leg from renderer,
/// calls canonical helper for conjunction, returns both for outcome state threading.
pub fn computeHostSurfaceAttachmentState(
    renderer: anytype,
    surface_state: anytype,
) struct {
    host_surface_target_available: bool,
    shared_surface_attachment_ready: bool,
} {
    const host_surface_target_available = renderer_presentable_host.terminalPresentableInfo(renderer) != null;
    const shared_surface_attachment_ready = surface_state.notePresentableAvailability(host_surface_target_available);
    return .{
        .host_surface_target_available = host_surface_target_available,
        .shared_surface_attachment_ready = shared_surface_attachment_ready,
    };
}

/// **Presentation surface geometry:** computed viewport and cell dimensions for rendering.
pub const PresentationGeometry = struct {
    render_scale: f32 = 1.0,
    cell_w_i: i32 = 0,
    cell_h_i: i32 = 0,
    padding_x_i: i32 = 0,
    surface_w: i32 = 0,
    surface_h: i32 = 0,
    visible_w: i32 = 0,
    visible_h: i32 = 0,
    viewport_w: f32 = 0.0,
    viewport_h: f32 = 0.0,
};

/// **Compute presentation surface geometry:** derives viewport and cell dimensions from renderer and view model.
pub fn computePresentationSurfaceGeometry(
    renderer: anytype,
    terminal_view: anytype,
    view_geometry: anytype,
) PresentationGeometry {
    var geometry: PresentationGeometry = .{};
    const rows = terminal_view.rows;
    const cols = terminal_view.cols;
    if (rows == 0 or cols == 0) return geometry;

    const geom = renderer.terminalCellGeometry();
    geometry.cell_w_i = geom.cell_width_device_px;
    geometry.cell_h_i = geom.cell_height_device_px;
    geometry.padding_x_i = @max(2, @divTrunc(geometry.cell_w_i, 2));
    geometry.render_scale = 1.0 / renderer.devicePixelStep();

    const scale = geometry.render_scale;
    geometry.surface_w = @as(i32, @intFromFloat(std.math.round(@as(f32, @floatFromInt(geometry.cell_w_i * @as(i32, @intCast(cols)) + geometry.padding_x_i)) / scale)));
    geometry.surface_h = @as(i32, @intFromFloat(std.math.round(@as(f32, @floatFromInt(geometry.cell_h_i * @as(i32, @intCast(rows)))) / scale)));
    geometry.visible_w = @intFromFloat(std.math.round(view_geometry.viewport_width));
    geometry.visible_h = @intFromFloat(std.math.round(view_geometry.viewport_height));
    geometry.viewport_w = view_geometry.viewport_width;
    geometry.viewport_h = view_geometry.viewport_height;
    return geometry;
}

/// **Viewport shift state:** tracks scrolling region for partial updates.
pub const ViewportShiftState = struct {
    rows: i32 = 0,
    exposed_only: bool = false,
};

/// **Compute presentation plan decision:** Pure orchestration logic for deciding update/present intents.
/// Terminal-owned orchestration function; widget layer gathers state and calls this helper.
/// Returns decision struct with update/present intents and reuse flags for widget facade to use.
pub const TerminalPresentPlanDecision = struct {
    update_intent: @import("../ui/renderer/presentable_contract.zig").TerminalPresentUpdateIntent = .none,
    present_intent: @import("../ui/renderer/presentable_contract.zig").TerminalPresentIntent = .update_and_present,
    reuse_allowed: bool = false,
    invalidation_blocks_reuse: bool = false,
    viewport_shifted: bool = false,
};

pub fn computeTerminalPresentPlanDecision(
    terminal_presentable_pipeline_ready: bool,
    terminal_view_rows: usize,
    terminal_view_cols: usize,
    terminal_view_cells_len: usize,
    terminal_view_sync_updates_active: bool,
    partial_capture_viewport_shift_rows: i32,
    generation_matches_last_render: bool,
    invalidation_blocks_reuse_explicit: bool,
    delta_clear_generation_changed: bool,
    delta_cell_metrics_changed: bool,
    delta_render_scale_changed: bool,
    delta_cursor_changed: bool,
    overlay_changed: bool,
    blink_requires_partial: bool,
) TerminalPresentPlanDecision {
    const viewport_shifted = partial_capture_viewport_shift_rows != 0;
    const explicit_invalidation_blocks_reuse = invalidation_blocks_reuse_explicit or
        delta_clear_generation_changed or
        delta_cell_metrics_changed or
        delta_render_scale_changed or
        delta_cursor_changed or
        overlay_changed or
        blink_requires_partial;

    const reuse_allowed = terminal_presentable_pipeline_ready and terminal_view_cells_len > 0;
    const reuse_requested = reuse_allowed and
        !viewport_shifted and
        (terminal_view_sync_updates_active or
            (!explicit_invalidation_blocks_reuse and generation_matches_last_render));

    const PresentableContract = @import("../ui/renderer/presentable_contract.zig");
    const update_intent = if (terminal_view_rows == 0 or terminal_view_cols == 0 or reuse_requested)
        PresentableContract.TerminalPresentUpdateIntent.none
    else if (viewport_shifted or explicit_invalidation_blocks_reuse)
        PresentableContract.TerminalPresentUpdateIntent.full
    else
        PresentableContract.TerminalPresentUpdateIntent.partial;

    const present_intent = if (reuse_requested)
        PresentableContract.TerminalPresentIntent.reuse
    else
        PresentableContract.TerminalPresentIntent.update_and_present;

    return .{
        .update_intent = update_intent,
        .present_intent = present_intent,
        .reuse_allowed = reuse_allowed,
        .invalidation_blocks_reuse = explicit_invalidation_blocks_reuse,
        .viewport_shifted = viewport_shifted,
    };
}

/// **Outcome from refresh + presentation:** timing and attachment state after refresh cycle handling.
/// Produced by `runRefreshedPresentablePresentation` (widget layer orchestration).
/// Canonically owns outcome aggregation responsibility.
pub const RefreshedPresentablePresentationResult = struct {
    bg_ms: f64 = 0.0,
    glyph_ms: f64 = 0.0,
    kitty_ms: f64 = 0.0,
    shared_surface_attachment_ready: bool = false,
};

/// **Presentation present state snapshot:** captures conjunction during refresh for operator reporting.
/// Stores on transient snapshot; not report from result structs. Canonical carrier for conjunction field.
pub const PresentationPresentState = struct {
    updated: bool = false,
    presentable_refresh: TerminalPresentableRefresh = .unsupported,
    host_surface_target_available: bool = false,
    shared_surface_attachment_ready: bool = false,
    visible: bool = false,
    present: bool = false,
    log_unavailable: bool = false,
};

/// **Presentation state refresh:** computes conjunction via `notePresentableAvailability`; stores
/// on transient `PresentationPresentState` for tick. **Canonical conjunction derivation.**
pub fn refreshPresentState(
    surface_state: anytype,
    renderer: anytype,
    terminal_view: anytype,
    surface_geometry: PresentationGeometry,
    presentable_refresh: TerminalPresentableRefresh,
    draw_cursor: bool,
    cursor: anytype,
    cursor_style: anytype,
    hover_link_id: u32,
    composing_active: bool,
    composing_hash: u64,
    visible_w: i32,
    visible_h: i32,
    view_cells_len: usize,
) PresentationPresentState {
    var state = PresentationPresentState{
        .updated = presentable_refresh == .refreshed,
        .presentable_refresh = presentable_refresh,
        .visible = visible_w > 0 and visible_h > 0,
    };

    if (presentable_refresh == .refreshed) {
        surface_state.notePresentationUpdated(
            terminal_view,
            surface_geometry,
            draw_cursor,
            cursor,
            cursor_style,
            hover_link_id,
            composing_active,
            composing_hash,
        );
    }

    const attachment_state = computeHostSurfaceAttachmentState(renderer, surface_state);
    state.host_surface_target_available = attachment_state.host_surface_target_available;
    state.shared_surface_attachment_ready = attachment_state.shared_surface_attachment_ready;
    state.present = state.shared_surface_attachment_ready and state.visible;
    state.log_unavailable = !state.shared_surface_attachment_ready and terminal_view.rows > 0 and terminal_view.cols > 0 and view_cells_len > 0 and state.visible;

    return state;
}

/// **Present draw callback:** invokes renderer present handling with hooks for present notifications.
/// Terminal-owned orchestration of present acknowledgement.
pub fn presentDraw(
    renderer: anytype,
    sample_generation: u64,
    surface_generation: u64,
    view_geometry: TerminalViewGeometry,
    viewport_w: f32,
    viewport_h: f32,
    note_present_ctx: anytype,
    note_present: anytype,
) void {
    const Hooks = struct {
        pub fn noteDirectReuse(
            ctx: @TypeOf(note_present_ctx),
            renderer_local: @TypeOf(renderer),
            generation: u64,
            geometry: TerminalViewGeometry,
            width_local: f32,
            height_local: f32,
        ) void {
            note_present(
                ctx,
                renderer_local,
                .cached_presentable_reuse,
                generation,
                geometry.origin_x,
                geometry.origin_y,
                width_local,
                height_local,
                width_local,
                height_local,
            );
        }

        pub fn noteRetainedReuse(
            ctx: @TypeOf(note_present_ctx),
            renderer_local: @TypeOf(renderer),
            generation: u64,
            geometry: TerminalViewGeometry,
            width_local: f32,
            height_local: f32,
        ) void {
            note_present(
                ctx,
                renderer_local,
                .refreshed_presentable,
                generation,
                geometry.origin_x,
                geometry.origin_y,
                width_local,
                height_local,
                width_local,
                height_local,
            );
        }
    };
    renderer_presentable_host.presentExistingTerminalPresentable(
        renderer,
        sample_generation,
        surface_generation,
        view_geometry,
        viewport_w,
        viewport_h,
        note_present_ctx,
        Hooks,
    );
}

/// **Reuse eligibility decision:** terminal-owned check for whether to attempt reuse path.
/// Takes pre-computed attachment state (from widget-layer `computeHostSurfaceAttachmentState`).
pub fn checkReuseEligibility(
    plan: anytype,
    view_cells_len: usize,
    shared_surface_attachment_ready: bool,
    sync_updates_active: bool,
    supports_reuse_without_sync: bool,
) bool {
    if (plan.present_intent != .reuse) return false;
    return view_cells_len > 0 and shared_surface_attachment_ready and
        (sync_updates_active or supports_reuse_without_sync);
}

/// **Refresh orchestration flow:** terminal-owned sequence for refresh path.
/// Orchestrates: run refresh cycle → classify outcome → run presentation → fold result.
/// Widget provides `runCycle` and `runPresentation` hooks for integration-only operations.
pub fn executeRefreshPresentFlow(
    rows: usize,
    cols: usize,
    ctx: anytype,
    comptime Hooks: type,
) TerminalPresentResult {
    // Hooks must implement:
    //   runCycle(ctx: anytype) -> TerminalPresentableRefreshExecutionResult
    //   runPresentation(ctx: anytype, cycle: anytype) -> RefreshedPresentablePresentationResult
    if (rows == 0 or cols == 0) return .{};
    const cycle = Hooks.runCycle(ctx);
    const outcome_state = classifyRefreshOutcome(cycle.refresh);
    const refreshed = Hooks.runPresentation(ctx, cycle);
    return presentResultFromRefreshOutcomeState(outcome_state, .{
        .background_ms = refreshed.bg_ms,
        .glyph_ms = refreshed.glyph_ms,
        .kitty_ms = refreshed.kitty_ms,
    }, refreshed.shared_surface_attachment_ready);
}
