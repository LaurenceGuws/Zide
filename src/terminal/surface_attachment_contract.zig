//! Host **shared-surface attachment** seam: pairing terminal presentable pipeline
//! readiness with host drawable-target availability for the shared GPU attachment
//! (`TERMINAL_SURFACE_CONTRACT.md`, `TERMINAL_SUBSYSTEM_LAYERS.md`).
//! Generation/clear pairing remains in `surface_contract.zig`; this module names
//! attachment-only predicates (`CZH-S15`).
//!
//! **State vocabulary lock (`CZH-S18`):** this module owns **only** the **conjunction**
//! of (terminal presentable **pipeline** ready) ∧ (host **drawable target** available).
//! **Generation** publication/clear state is exclusively `surface_contract`. The
//! pipeline leg alone is **not** “attachment-ready” without the host-target leg.
//!
//! **`CZH-S16` / `CZH-S17`:** `presentationUpdateDelta.terminal_presentable_pipeline_ready`
//! is the pipeline leg (`terminalPresentablePipelineReady()` after `CZH-725`), not the
//! full `hostSharedSurfaceAttachmentReady` conjunction. Present-plan reuse uses the
//! pipeline leg alone by design; full readiness uses `notePresentableAvailability` /
//! `readSharedSurfaceAttachmentReady`.

const std = @import("std");

/// True when the terminal can draw into the presentable **and** the host exposes
/// a surface target for that attachment (logical AND — no extra policy).
pub fn hostSharedSurfaceAttachmentReady(
    terminal_presentable_pipeline_ready: bool,
    host_surface_target_available: bool,
) bool {
    return terminal_presentable_pipeline_ready and host_surface_target_available;
}

/// Snapshot of the two attachment legs for explicit ownership at widget seams.
pub const SharedSurfaceAttachmentPipelinePair = struct {
    terminal_presentable_pipeline_ready: bool,
    host_surface_target_available: bool,
};

pub fn hostSharedSurfaceAttachmentReadyFromPair(pair: SharedSurfaceAttachmentPipelinePair) bool {
    return hostSharedSurfaceAttachmentReady(
        pair.terminal_presentable_pipeline_ready,
        pair.host_surface_target_available,
    );
}

test "hostSharedSurfaceAttachmentReady is conjunction of legs" {
    try std.testing.expect(hostSharedSurfaceAttachmentReady(true, true));
    try std.testing.expect(!hostSharedSurfaceAttachmentReady(false, true));
    try std.testing.expect(!hostSharedSurfaceAttachmentReady(true, false));
    try std.testing.expect(!hostSharedSurfaceAttachmentReady(false, false));
}

test "FromPair matches hostSharedSurfaceAttachmentReady" {
    try std.testing.expect(hostSharedSurfaceAttachmentReadyFromPair(.{
        .terminal_presentable_pipeline_ready = true,
        .host_surface_target_available = true,
    }));
    try std.testing.expect(!hostSharedSurfaceAttachmentReadyFromPair(.{
        .terminal_presentable_pipeline_ready = true,
        .host_surface_target_available = false,
    }));
}

test "CZH-S16: pipeline leg alone does not imply full attachment readiness" {
    try std.testing.expect(!hostSharedSurfaceAttachmentReady(true, false));
    try std.testing.expect(hostSharedSurfaceAttachmentReady(true, true));
}

test "CZH-S18: full attachment readiness is strict AND of vocabulary legs" {
    try std.testing.expect(hostSharedSurfaceAttachmentReady(true, true) == (true and true));
    try std.testing.expect(hostSharedSurfaceAttachmentReady(false, true) == (false and true));
    try std.testing.expect(hostSharedSurfaceAttachmentReady(true, false) == (true and false));
}
