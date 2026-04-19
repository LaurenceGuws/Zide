//! Terminal **presentation bridge:** canonical compute and read routes for host attachment
//! readiness (terminal presentable pipeline ∧ host drawable target). Owned by terminal layer.
//!
//! This seam consolidates conjunction compute and read logic so widget layer does not re-derive
//! attachment readiness. Widget surface state delegates to this bridge and stores legs only.
//!
//! **Canonical compute route:** `notePresentableAvailability(available: bool) -> bool`
//! - Updates host-target leg from caller input
//! - Returns conjunction via canonical helper
//! - Invalidates presentation cache on unavailability
//! - Must be called before read-only access or logging
//!
//! **Canonical read route:** `readSharedSurfaceAttachmentReady(pipeline: bool, target: bool) -> bool`
//! - Read-only access to conjunction
//! - Derives from stored legs (no local computation)
//! - Paired with compute route for storage/read consistency
//!
//! **Ownership invariant:** This bridge owns all conjunction computation for the presentation
//! surface. Widget layer stores legs but never computes conjunction independently.

const surface_attachment_contract = @import("surface_attachment_contract.zig");

/// **Canonical compute + store route for conjunction:** computes host-target leg availability
/// and returns conjunction. Called on each refresh/reuse evaluation.
///
/// **Invalidation:** If availability becomes false, presentation cache should be invalidated.
/// **Pairing:** Pairs with `readSharedSurfaceAttachmentReady` for storage/read consistency.
pub fn notePresentableAvailability(
    pipeline_ready: bool,
    available: bool,
    invalidate_callback: ?*const fn (bool) void,
) bool {
    if (!available) {
        if (invalidate_callback) |cb| {
            cb(true);
        }
    }
    return surface_attachment_contract.hostSharedSurfaceAttachmentReady(pipeline_ready, available);
}

/// **Canonical read-only route for conjunction:** derives conjunction from caller-provided legs.
/// Returns same predicate as `notePresentableAvailability` would for matching inputs.
///
/// **Read-only:** Does not modify any state. Safe for diagnostic/logging paths.
/// **Pairing:** Pairs with `notePresentableAvailability` for storage/read consistency.
pub fn readSharedSurfaceAttachmentReady(
    pipeline_ready: bool,
    target_available: bool,
) bool {
    return surface_attachment_contract.hostSharedSurfaceAttachmentReadyFromPair(.{
        .terminal_presentable_pipeline_ready = pipeline_ready,
        .host_surface_target_available = target_available,
    });
}
