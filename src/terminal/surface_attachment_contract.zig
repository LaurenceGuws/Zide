//! Host **shared-surface attachment** seam: pairing terminal presentable pipeline
//! readiness with host drawable-target availability for the shared GPU attachment
//! (`TERMINAL_SURFACE_CONTRACT.md`, `TERMINAL_SUBSYSTEM_LAYERS.md`).
//! Generation/clear pairing remains in `surface_contract.zig`; this module names
//! attachment-only predicates (`CZH-S15`).
//!
//! **Naming (`CZH-S16`):** `TerminalWidgetSurfaceState.presentationUpdateDelta` exposes
//! `presentable_ready` as the **terminal presentable pipeline** leg
//! (`terminal_presentable_ready` / `presentableReady()`), not the full
//! `hostSharedSurfaceAttachmentReady` conjunction. Present-plan reuse eligibility still
//! uses that pipeline leg alone by design; full attachment readiness uses
//! `notePresentableAvailability` / `readSharedSurfaceAttachmentReady`.

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
