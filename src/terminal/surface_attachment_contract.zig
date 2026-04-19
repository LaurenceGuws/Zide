//! Host **shared-surface attachment** seam: pairing terminal presentable pipeline
//! readiness with host drawable-target availability for the shared GPU attachment
//! (`TERMINAL_SURFACE_CONTRACT.md`, `TERMINAL_SUBSYSTEM_LAYERS.md`).
//! Generation/clear pairing remains in `surface_contract.zig`; this module names
//! attachment-only predicates (`CZH-S15`).

const std = @import("std");

/// True when the terminal can draw into the presentable **and** the host exposes
/// a surface target for that attachment (logical AND — no extra policy).
pub fn hostSharedSurfaceAttachmentReady(
    terminal_presentable_pipeline_ready: bool,
    host_surface_target_available: bool,
) bool {
    return terminal_presentable_pipeline_ready and host_surface_target_available;
}
