//! Neutral terminal presentable draw payloads. OpenGL retained
//! `PresentableTarget` / `PresentableTargetState` live in `gl_presentable_target.zig`.
//!
//! **Conjunction propagation (`CZH-S22`):** `TerminalPresentResult` **stores** per-outcome fields
//! supplied by callers; it does not **compute** `shared_surface_attachment_ready` — runtime/widget
//! paths compute conjunction and **report** through the same field names downstream.

pub const PresentableDraw = struct {
    x: f32,
    y: f32,
    width: ?f32 = null,
    height: ?f32 = null,
    source_width: ?f32 = null,
    source_height: ?f32 = null,
    generation: ?u64 = null,
};

pub const ResolvedPresentableDraw = struct {
    x: f32,
    y: f32,
    width: f32,
    height: f32,
    source_width: f32,
    source_height: f32,
    generation: ?u64 = null,
};

pub fn resolveDraw(
    draw: PresentableDraw,
    fallback_width: ?f32,
    fallback_height: ?f32,
) ?ResolvedPresentableDraw {
    const width = draw.width orelse fallback_width orelse return null;
    const height = draw.height orelse fallback_height orelse return null;
    return .{
        .x = draw.x,
        .y = draw.y,
        .width = width,
        .height = height,
        .source_width = draw.source_width orelse width,
        .source_height = draw.source_height orelse height,
        .generation = draw.generation,
    };
}

pub const PresentableInfo = struct {
    width_px: i32,
    height_px: i32,
    logical_width: i32,
    logical_height: i32,
};

pub const TerminalPresentUpdateIntent = enum {
    none,
    partial,
    full,
};

pub const TerminalPresentIntent = enum {
    reuse,
    update_and_present,
    direct_present,
};

pub const TerminalPresentDamageMode = enum {
    none,
    full,
    partial,
};

pub const TerminalPresentGeometry = struct {
    logical_width: i32 = 0,
    logical_height: i32 = 0,
    visible_width: i32 = 0,
    visible_height: i32 = 0,
    dest_x: f32 = 0,
    dest_y: f32 = 0,
    dest_width: f32 = 0,
    dest_height: f32 = 0,
};

pub const TerminalPresentReusePolicy = struct {
    reuse_allowed: bool = false,
    shift_reuse_requested: bool = false,
    invalidation_blocks_reuse: bool = false,
};

pub const TerminalPresentDamage = struct {
    mode: TerminalPresentDamageMode = .none,
    has_partial_payload: bool = false,
};

pub const TerminalPresentInvalidationReasons = struct {
    generation_changed: bool = false,
    clear_generation_changed: bool = false,
    cell_metrics_changed: bool = false,
    scale_changed: bool = false,
    cursor_changed: bool = false,
    overlay_changed: bool = false,
    viewport_shifted: bool = false,
};

pub const TerminalPresentPlan = struct {
    update_intent: TerminalPresentUpdateIntent = .none,
    present_intent: TerminalPresentIntent = .update_and_present,
    surface_geometry: TerminalPresentGeometry = .{},
    reuse_policy: TerminalPresentReusePolicy = .{},
    damage: TerminalPresentDamage = .{},
    invalidation_reasons: TerminalPresentInvalidationReasons = .{},
};

pub const TerminalPresentOutcome = enum {
    presented,
    reused,
    updated_and_presented,
    unavailable,
    skipped,
};

pub const TerminalPresentFollowupReason = enum {
    none,
    target_unavailable,
    reuse_rejected,
    update_invalidated,
    geometry_changed,
};

pub const TerminalPresentTiming = struct {
    update_ms: f64 = 0.0,
    background_ms: f64 = 0.0,
    glyph_ms: f64 = 0.0,
    kitty_ms: f64 = 0.0,
};

pub const TerminalPresentFollowup = struct {
    required: bool = false,
    reason: TerminalPresentFollowupReason = .none,
};

/// Aggregated present result (`CZH-B26` ownership): **`host_surface_target_available`**
/// records only whether the **host drawable-target** leg was available for this execution
/// (renderer-reported presentable target). **`shared_surface_attachment_ready`** records the
/// **full attachment** predicate (terminal presentable pipeline ∧ host target) when the caller
/// computes it; default `false` when this execution path does not surface that conjunction.
pub const TerminalPresentResult = struct {
    outcome: TerminalPresentOutcome = .skipped,
    cache_state_advanced: bool = false,
    host_surface_target_available: bool = false,
    shared_surface_attachment_ready: bool = false,
    timing: TerminalPresentTiming = .{},
    followup: TerminalPresentFollowup = .{},
};
