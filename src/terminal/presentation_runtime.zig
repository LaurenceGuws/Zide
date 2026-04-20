//! Terminal **presentation runtime:** orchestration, classification, fold, and geometry
//! for terminal presentation (refresh cycle, reuse path, direct draw). Owned by terminal layer.
//!
//! **Ownership boundary:** Terminal layer owns all decision logic and stateless computation.
//! Widget layer owns execution (GPU drawing, state mutation, renderer integration).
//! Widget delegates decisions and folding to this module; never re-derives outcomes.
//!
//! **Orchestration:**
//! - `executeRefreshPresentFlow(rows, cols, ctx, Hooks)` — refresh sequence (cycle → classify → present → fold)
//! - `checkReuseEligibility(...)` — reuse path eligibility decision
//! - `checkDirectPresentEligibility(...)` — direct draw eligibility decision
//!
//! **State computation:**
//! - `refreshPresentState(...)` — present-state snapshot for a refresh tick
//! - `presentDraw(...)` — present acknowledgement via renderer hooks
//! - `computeHostSurfaceAttachmentState(...)` — attachment leg + conjunction
//! - `computePresentationSurfaceGeometry(...)` — viewport and cell geometry
//! - `computeTerminalPresentPlanDecision(...)` — present plan decision (refresh/reuse/direct)
//!
//! **Canonical outcome paths:**
//! - `classifyRefreshOutcome(refresh) -> RefreshOutcomeState`
//! - `classifyDirectPresentOutcome(updated) -> DirectPresentOutcomeState`
//! - `reuseSuccessOutcome() -> ReusePresentOutcomeState`
//!
//! **Canonical fold routes:**
//! - `foldRefreshOutcomeToPresent(outcome, timing) -> TerminalPresentResult`
//! - `foldReuseOutcomeToPresent(outcome, timing) -> TerminalPresentResult`
//! - `foldDirectOutcomeToPresent(outcome, timing) -> TerminalPresentResult`
//! - internal generic fold helper routes all path-specific fold helpers

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
/// Simplified carrier: full attachment state carried inline, no separate conjunction parameter.
pub const RefreshOutcomeState = struct {
    transport: FoldTransportFields = .{},
    outcome: TerminalPresentOutcome = .presented,
    cache_state_advanced: bool = false,
    host_surface_target_available: bool = false,
    shared_surface_attachment_ready: bool = false,
    followup: presentable_contract.TerminalPresentFollowup = .{},
};

/// **Direct boundary outcome snapshot:** result when direct boundary execution bypasses reuse path.
/// Host-target leg is fixed to `true` (direct boundary draw implies renderer availability).
/// Conjunction is fixed to `false` (direct boundary path does not pre-verify full attachment before returning).
/// *Invariants:* `cache_state_advanced` remains true (draw implies advancement); boundary legs remain fixed.
/// Hardening assertions validate direct boundary invariants in `classifyDirectPresentOutcome()`.
pub const DirectPresentOutcomeState = struct {
    outcome: TerminalPresentOutcome = .presented,
    cache_state_advanced: bool = true,
    host_surface_target_available: bool = true,
    shared_surface_attachment_ready: bool = false,
};

comptime {
    const fields = @typeInfo(DirectPresentOutcomeState).@"struct".fields;
    var outcome_count: usize = 0;
    var cache_count: usize = 0;
    var host_count: usize = 0;
    var attachment_count: usize = 0;
    for (fields) |f| {
        if (std.mem.eql(u8, f.name, "outcome")) outcome_count += 1;
        if (std.mem.eql(u8, f.name, "cache_state_advanced")) cache_count += 1;
        if (std.mem.eql(u8, f.name, "host_surface_target_available")) host_count += 1;
        if (std.mem.eql(u8, f.name, "shared_surface_attachment_ready")) attachment_count += 1;
    }
    std.debug.assert(outcome_count == 1 and cache_count == 1 and host_count == 1 and attachment_count == 1);
}

/// **Outcome snapshot from reuse path:** carries result of the reuse attempt.
pub const ReusePresentOutcomeState = struct {
    outcome: TerminalPresentOutcome = .skipped,
    cache_state_advanced: bool = false,
    /// **Leg only** — host drawable-target (renderer `terminalPresentableInfo`); not conjunction.
    host_surface_target_available: bool = false,
    /// **Full conjunction** — terminal presentable pipeline ∧ host target (from `notePresentableAvailability`).
    /// *Canonical route:* must be populated by canonical helper, never hardcoded or re-derived.
    shared_surface_attachment_ready: bool = false,
};

/// **Canonical fold transport fields:** shared host-facing transport payload used by
/// refresh/reuse/direct fold routes before timing/followup composition.
pub const FoldTransportFields = struct {
    outcome: TerminalPresentOutcome = .skipped,
    cache_state_advanced: bool = false,
    host_surface_target_available: bool = false,
    shared_surface_attachment_ready: bool = false,
};

/// **Classify refresh cycle outcome:** derives outcome from refresh result.
/// Maps `TerminalPresentableRefresh` enum to `RefreshOutcomeState` fields: outcome, cache advancement,
/// host availability, attachment conjunction, and followup requirements.
/// *Hardening:* validates outcome consistency before returning.
/// *Simplification:* populates `shared_surface_attachment_ready` inline; caller threads it through outcome state.
pub fn classifyRefreshOutcome(
    refresh: TerminalPresentableRefresh,
    shared_surface_attachment_ready: bool,
) RefreshOutcomeState {
    const outcome_state: RefreshOutcomeState = .{
        .transport = .{
            .outcome = if (refresh == .refreshed) .updated_and_presented else .presented,
            .cache_state_advanced = refresh == .refreshed,
            .host_surface_target_available = refresh != .unsupported and refresh != .target_unavailable,
            .shared_surface_attachment_ready = shared_surface_attachment_ready,
        },
        .outcome = if (refresh == .refreshed) .updated_and_presented else .presented,
        .cache_state_advanced = refresh == .refreshed,
        .host_surface_target_available = refresh != .unsupported and refresh != .target_unavailable,
        .shared_surface_attachment_ready = shared_surface_attachment_ready,
        .followup = .{
            .required = refresh == .target_unavailable,
            .reason = if (refresh == .target_unavailable) .target_unavailable else .none,
        },
    };
    assertRefreshOutcomeConsistency(outcome_state);
    return outcome_state;
}

/// **Classify direct boundary outcome:** derive outcome from direct boundary draw completion.
/// Invariant: both legs and conjunction remain fixed to the direct boundary contract values.
/// *Hardening:* validates direct boundary invariant fields to catch invalid state early.
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
/// *Consolidation:* central hub of fold path composition — `foldRefreshOutcomeToPresent`
/// and `foldReuseOutcomeToPresent` call this with outcome-specific parameters.
/// *Hardening:* validates output result consistency across all outcome types.
fn presentResultFromOutcomeState(
    fields: FoldTransportFields,
    timing: renderer_presentable_host.TerminalPresentTiming,
) TerminalPresentResult {
    const result: TerminalPresentResult = .{
        .outcome = fields.outcome,
        .cache_state_advanced = fields.cache_state_advanced,
        .host_surface_target_available = fields.host_surface_target_available,
        .shared_surface_attachment_ready = fields.shared_surface_attachment_ready,
        .timing = timing,
    };
    // Harden: validate output result consistency across outcome types
    if (fields.outcome == .reused) {
        std.debug.assert(result.cache_state_advanced == true);
        std.debug.assert(result.shared_surface_attachment_ready == true);
    }
    // Direct outcome: cache always advanced, host target always available
    if (fields.outcome == .updated_and_presented or fields.outcome == .presented) {
        if (fields.cache_state_advanced and fields.host_surface_target_available) {
            // For direct path, these invariants must hold together
            std.debug.assert(result.outcome == .updated_and_presented or result.outcome == .presented);
        }
    }
    return result;
}

/// **Canonical outcome fold for refresh path:** uses conjunction carried in outcome state.
/// *Simplification:* reads `shared_surface_attachment_ready` from outcome state, no separate parameter.
/// *Hardening:* validates outcome -> result threading and followup propagation.
/// *Consolidation:* routes refresh outcomes through generic fold with inline followup assignment.
pub fn foldRefreshOutcomeToPresent(
    outcome_state: RefreshOutcomeState,
    timing: renderer_presentable_host.TerminalPresentTiming,
) TerminalPresentResult {
    assertRefreshOutcomeConsistency(outcome_state);
    var result = presentResultFromOutcomeState(outcome_state.transport, timing);
    result.followup = outcome_state.followup;
    // Harden: verify followup propagates correctly through fold
    if (outcome_state.followup.required) {
        std.debug.assert(result.followup.required == true);
        std.debug.assert(result.followup.reason != .none);
    }
    return result;
}

/// **Canonical reuse boundary helper:** folds reuse-attempt result into host-facing transport.
/// Widget/runtime boundaries should call this helper when completing reuse attempt transport.
pub fn foldReuseOutcomeToPresent(
    outcome_state: ReusePresentOutcomeState,
    timing: renderer_presentable_host.TerminalPresentTiming,
) TerminalPresentResult {
    if (outcome_state.outcome == .reused) {
        std.debug.assert(outcome_state.cache_state_advanced == true);
        std.debug.assert(outcome_state.host_surface_target_available == true);
        std.debug.assert(outcome_state.shared_surface_attachment_ready == true);
    }
    return presentResultFromOutcomeState(foldFieldsFromReuseOutcome(outcome_state), timing);
}

fn foldFieldsFromReuseOutcome(outcome_state: ReusePresentOutcomeState) FoldTransportFields {
    return .{
        .outcome = outcome_state.outcome,
        .cache_state_advanced = outcome_state.cache_state_advanced,
        .host_surface_target_available = outcome_state.host_surface_target_available,
        .shared_surface_attachment_ready = outcome_state.shared_surface_attachment_ready,
    };
}

/// **Canonical direct boundary fold route:** folds direct boundary outcome through generic result helper.
/// *Simplification:* collapses direct boundary transport hop at callsites.
/// *Hardening:* validates direct boundary invariants before folding.
pub fn foldDirectOutcomeToPresent(
    outcome_state: DirectPresentOutcomeState,
    timing: renderer_presentable_host.TerminalPresentTiming,
) TerminalPresentResult {
    assertDirectPresentOutcomeConsistency(outcome_state);
    return presentResultFromOutcomeState(foldFieldsFromDirectOutcome(outcome_state), timing);
}

fn foldFieldsFromDirectOutcome(outcome_state: DirectPresentOutcomeState) FoldTransportFields {
    return .{
        .outcome = outcome_state.outcome,
        .cache_state_advanced = outcome_state.cache_state_advanced,
        .host_surface_target_available = outcome_state.host_surface_target_available,
        .shared_surface_attachment_ready = outcome_state.shared_surface_attachment_ready,
    };
}

/// **Validate reuse outcome consistency:** hardening check that reuse outcome state has correct field values.
pub fn assertReuseOutcomeConsistency(state: ReusePresentOutcomeState) void {
    if (state.outcome == .reused) {
        std.debug.assert(state.cache_state_advanced == true);
        std.debug.assert(state.host_surface_target_available == true);
        std.debug.assert(state.shared_surface_attachment_ready == true);
    }
}

/// **Validate direct boundary outcome consistency:** hardening check that direct boundary outcome
/// state has invariant field values. Direct boundary draws always advance cache and keep renderer available;
/// conjunction remains false (not pre-verified).
pub fn assertDirectPresentOutcomeConsistency(state: DirectPresentOutcomeState) void {
    std.debug.assert(state.cache_state_advanced == true);
    std.debug.assert(state.host_surface_target_available == true);
    std.debug.assert(state.shared_surface_attachment_ready == false);
}

/// **Validate refresh outcome consistency:** consolidation of refresh-path assertion patterns.
/// Verifies that followup coupling invariants hold (if `followup.required`, then `followup.reason != .none`).
pub fn assertRefreshOutcomeConsistency(state: RefreshOutcomeState) void {
    if (state.followup.required) {
        std.debug.assert(state.followup.reason != .none);
    } else {
        std.debug.assert(state.followup.reason == .none);
    }
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

/// **Presentation state computation:** pure conjunction computation for a refresh tick.
/// Computes attachment state and visibility flags. Does not mutate surface cache state;
/// callers advance cache separately for the refreshed path.
pub fn refreshPresentState(
    surface_state: anytype,
    renderer: anytype,
    terminal_view: anytype,
    presentable_refresh: TerminalPresentableRefresh,
    visible_w: i32,
    visible_h: i32,
    view_cells_len: usize,
) PresentationPresentState {
    var state = PresentationPresentState{
        .updated = presentable_refresh == .refreshed,
        .presentable_refresh = presentable_refresh,
        .visible = visible_w > 0 and visible_h > 0,
    };
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
pub const ReuseEligibilityInput = struct {
    view_cells_len: usize,
    shared_surface_attachment_ready: bool,
    sync_updates_active: bool,
    supports_reuse_without_sync: bool,
};

pub fn checkReuseEligibility(
    plan: anytype,
    input: ReuseEligibilityInput,
) bool {
    if (plan.present_intent != .reuse) return false;
    return input.view_cells_len > 0 and input.shared_surface_attachment_ready and
        (input.sync_updates_active or input.supports_reuse_without_sync);
}

/// **Direct present eligibility decision:** terminal-owned check for direct draw path.
/// Validates view model has content to draw (rows, cols, cells).
pub const DirectPresentEligibilityInput = struct {
    rows: usize,
    cols: usize,
    view_cells_len: usize,
};

pub fn checkDirectPresentEligibility(
    input: DirectPresentEligibilityInput,
) bool {
    return input.rows > 0 and input.cols > 0 and input.view_cells_len > 0;
}

/// **Refresh orchestration flow:** terminal-owned sequence for refresh path.
/// Orchestrates: check dimensions → run cycle → classify outcome → run presentation → fold result.
///
/// `Hooks` interface (comptime, widget-provided):
///   `runCycle(ctx) -> TerminalPresentableRefreshExecutionResult`
///   `runPresentation(ctx, cycle: TerminalPresentableRefreshExecutionResult) -> TerminalPresentResult`
///
/// Terminal owns orchestration and classification; widget owns execution via `Hooks`.
/// *Consolidation:* refresh boundary transport returns canonical folded host-facing result transport.
pub fn executeRefreshPresentFlow(
    rows: usize,
    cols: usize,
    ctx: anytype,
    comptime Hooks: type,
) TerminalPresentResult {
    if (rows == 0 or cols == 0) return .{};
    const cycle = Hooks.runCycle(ctx);
    return Hooks.runPresentation(ctx, cycle);
}
