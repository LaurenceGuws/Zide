//! Terminal FFI Zig facade: re-exports ABI types and forwards calls to
//! `core_api.zig` (VT core) and `host_api.zig` (optional BYO-PTY host seam).
const shared = @import("shared.zig");
const host_api = @import("host_api.zig");
const core_api = @import("core_api.zig");

pub const Status = shared.Status;
pub const snapshot_abi_version = shared.snapshot_abi_version;
pub const snapshot_diff_abi_version = shared.snapshot_diff_abi_version;
pub const event_abi_version = shared.event_abi_version;
pub const scrollback_abi_version = shared.scrollback_abi_version;
pub const renderer_metadata_abi_version = shared.renderer_metadata_abi_version;
pub const metadata_abi_version = shared.metadata_abi_version;
pub const activity_abi_version = shared.activity_abi_version;
pub const redraw_state_abi_version = shared.redraw_state_abi_version;
pub const string_abi_version = shared.string_abi_version;
pub const byte_buffer_abi_version = shared.byte_buffer_abi_version;
pub const close_confirm_abi_version = shared.close_confirm_abi_version;
pub const clipboard_abi_version = shared.clipboard_abi_version;
pub const EventKind = shared.EventKind;
pub const GlyphClassFlags = shared.GlyphClassFlags;
pub const DamagePolicyFlags = shared.DamagePolicyFlags;
pub const MetadataIncludeFlags = shared.MetadataIncludeFlags;
pub const ActivityIncludeFlags = shared.ActivityIncludeFlags;
pub const ZideTerminalHandle = shared.ZideTerminalHandle;
pub const CreateConfig = shared.CreateConfig;
pub const Color = shared.Color;
pub const Cell = shared.Cell;
pub const Snapshot = shared.Snapshot;
pub const SnapshotDiff = shared.SnapshotDiff;
pub const SnapshotDiffRequest = shared.SnapshotDiffRequest;
pub const SnapshotDiffRow = shared.SnapshotDiffRow;
pub const SnapshotDiffSpan = shared.SnapshotDiffSpan;
pub const SnapshotRequest = shared.SnapshotRequest;
pub const ScrollbackBuffer = shared.ScrollbackBuffer;
pub const MetadataRequest = shared.MetadataRequest;
pub const Metadata = shared.Metadata;
pub const ActivityRequest = shared.ActivityRequest;
pub const Activity = shared.Activity;
pub const RedrawState = shared.RedrawState;
pub const CloseConfirmSignals = shared.CloseConfirmSignals;
pub const ByteBuffer = shared.ByteBuffer;
pub const KeyEvent = shared.KeyEvent;
pub const MouseEvent = shared.MouseEvent;
pub const Event = shared.Event;
pub const RendererMetadata = shared.RendererMetadata;
pub const EventBuffer = shared.EventBuffer;
pub const StringBuffer = shared.StringBuffer;

pub fn create(config: ?*const CreateConfig, out_handle: *?*ZideTerminalHandle) Status {
    return core_api.create(config, out_handle);
}

pub fn destroy(handle: ?*ZideTerminalHandle) void {
    core_api.destroy(handle);
}

pub fn start(handle: ?*ZideTerminalHandle, shell: ?[*:0]const u8) Status {
    return host_api.start(handle, shell);
}

pub fn poll(handle: ?*ZideTerminalHandle) Status {
    return host_api.poll(handle);
}

pub fn resize(handle: ?*ZideTerminalHandle, cols: u16, rows: u16, cell_width: u16, cell_height: u16) Status {
    return host_api.resize(handle, cols, rows, cell_width, cell_height);
}

pub fn updateCellSize(handle: ?*ZideTerminalHandle, cell_width: u16, cell_height: u16) Status {
    return host_api.updateCellSize(handle, cell_width, cell_height);
}

pub fn sendBytes(handle: ?*ZideTerminalHandle, bytes: ?[*]const u8, len: usize) Status {
    return host_api.sendBytes(handle, bytes, len);
}

pub fn sendText(handle: ?*ZideTerminalHandle, bytes: ?[*]const u8, len: usize) Status {
    return host_api.sendText(handle, bytes, len);
}

pub fn feedOutput(handle: ?*ZideTerminalHandle, bytes: ?[*]const u8, len: usize) Status {
    return core_api.feedOutput(handle, bytes, len);
}

pub fn closeInput(handle: ?*ZideTerminalHandle) Status {
    return core_api.closeInput(handle);
}

pub fn pendingInputAcquire(handle: ?*ZideTerminalHandle, out_buffer: *ByteBuffer) Status {
    return core_api.pendingInputAcquire(handle, out_buffer);
}

pub fn pendingInputRelease(out_buffer: *ByteBuffer) void {
    core_api.pendingInputRelease(out_buffer);
}

pub fn presentAck(handle: ?*ZideTerminalHandle, generation: u64) Status {
    return core_api.presentAck(handle, generation);
}

pub fn acknowledgedGeneration(handle: ?*ZideTerminalHandle, out_generation: *u64) Status {
    return core_api.acknowledgedGeneration(handle, out_generation);
}

pub fn publishedGeneration(handle: ?*ZideTerminalHandle, out_generation: *u64) Status {
    return core_api.publishedGeneration(handle, out_generation);
}

pub fn redrawState(handle: ?*ZideTerminalHandle, out_state: *RedrawState) Status {
    return core_api.redrawState(handle, out_state);
}

pub fn closeConfirmSignals(handle: ?*ZideTerminalHandle, out_signals: *CloseConfirmSignals) Status {
    return core_api.closeConfirmSignals(handle, out_signals);
}

pub fn needsRedraw(handle: ?*ZideTerminalHandle) u8 {
    return core_api.needsRedraw(handle);
}

pub fn sendKey(handle: ?*ZideTerminalHandle, event: ?*const KeyEvent) Status {
    return host_api.sendKey(handle, event);
}

pub fn sendMouse(handle: ?*ZideTerminalHandle, event: ?*const MouseEvent) Status {
    return host_api.sendMouse(handle, event);
}

pub fn reportFocusChanged(handle: ?*ZideTerminalHandle, focused: u8, out_reported: *u8) Status {
    return host_api.reportFocusChanged(handle, focused, out_reported);
}

pub fn reportColorSchemeChanged(handle: ?*ZideTerminalHandle, dark: u8, out_reported: *u8) Status {
    return host_api.reportColorSchemeChanged(handle, dark, out_reported);
}

pub fn setScrollbackOffset(handle: ?*ZideTerminalHandle, offset_rows: u32) Status {
    return host_api.setScrollbackOffset(handle, offset_rows);
}

pub fn followLiveBottom(handle: ?*ZideTerminalHandle) Status {
    return host_api.followLiveBottom(handle);
}

pub fn snapshotAcquire(handle: ?*ZideTerminalHandle, request: ?*const SnapshotRequest, out_snapshot: *Snapshot) Status {
    return core_api.snapshotAcquire(handle, request, out_snapshot);
}

pub fn snapshotRelease(snapshot: *Snapshot) void {
    core_api.snapshotRelease(snapshot);
}

pub fn snapshotDiffAcquire(handle: ?*ZideTerminalHandle, request: ?*const SnapshotDiffRequest, out_diff: *SnapshotDiff) Status {
    return core_api.snapshotDiffAcquire(handle, request, out_diff);
}

pub fn snapshotDiffRelease(diff: *SnapshotDiff) void {
    core_api.snapshotDiffRelease(diff);
}

pub fn scrollbackAcquire(handle: ?*ZideTerminalHandle, start_row: u32, max_rows: u32, out_buffer: *ScrollbackBuffer) Status {
    return core_api.scrollbackAcquire(handle, start_row, max_rows, out_buffer);
}

pub fn scrollbackRelease(scrollback: *ScrollbackBuffer) void {
    core_api.scrollbackRelease(scrollback);
}

pub fn metadataAcquire(handle: ?*ZideTerminalHandle, request: ?*const MetadataRequest, out_metadata: *Metadata) Status {
    return core_api.metadataAcquire(handle, request, out_metadata);
}

pub fn metadataRelease(metadata: *Metadata) void {
    core_api.metadataRelease(metadata);
}

pub fn activityAcquire(handle: ?*ZideTerminalHandle, request: ?*const ActivityRequest, out_activity: *Activity) Status {
    return core_api.activityAcquire(handle, request, out_activity);
}

pub fn activityRelease(activity: *Activity) void {
    core_api.activityRelease(activity);
}

pub fn eventDrain(handle: ?*ZideTerminalHandle, out_events: *EventBuffer) Status {
    return core_api.eventDrain(handle, out_events);
}

pub fn eventsFree(events: *EventBuffer) void {
    core_api.eventsFree(events);
}

pub fn isAlive(handle: ?*ZideTerminalHandle) u8 {
    return host_api.isAlive(handle);
}

pub fn selectionText(handle: ?*ZideTerminalHandle, out_string: *StringBuffer) Status {
    return core_api.selectionText(handle, out_string);
}

pub fn clipboardWrite(handle: ?*ZideTerminalHandle, out_string: *StringBuffer) Status {
    return core_api.clipboardWrite(handle, out_string);
}

pub fn scrollbackPlainText(handle: ?*ZideTerminalHandle, out_string: *StringBuffer) Status {
    return core_api.scrollbackPlainText(handle, out_string);
}

pub fn scrollbackAnsiText(handle: ?*ZideTerminalHandle, out_string: *StringBuffer) Status {
    return core_api.scrollbackAnsiText(handle, out_string);
}

pub fn stringFree(string: *StringBuffer) void {
    core_api.stringFree(string);
}

pub fn childExitStatus(handle: ?*ZideTerminalHandle, out_code: *i32, out_has_status: *u8) Status {
    return host_api.childExitStatus(handle, out_code, out_has_status);
}

pub fn reportChildExit(handle: ?*ZideTerminalHandle, code: i32, has_status: u8) Status {
    return host_api.reportChildExit(handle, code, has_status);
}

pub fn snapshotAbiVersion() u32 {
    return core_api.snapshotAbiVersion();
}

pub fn snapshotDiffAbiVersion() u32 {
    return core_api.snapshotDiffAbiVersion();
}

pub fn eventAbiVersion() u32 {
    return core_api.eventAbiVersion();
}

pub fn scrollbackAbiVersion() u32 {
    return core_api.scrollbackAbiVersion();
}

pub fn rendererMetadataAbiVersion() u32 {
    return core_api.rendererMetadataAbiVersion();
}

pub fn redrawStateAbiVersion() u32 {
    return core_api.redrawStateAbiVersion();
}

pub fn activityAbiVersion() u32 {
    return core_api.activityAbiVersion();
}

pub fn closeConfirmAbiVersion() u32 {
    return core_api.closeConfirmAbiVersion();
}

pub fn clipboardAbiVersion() u32 {
    return core_api.clipboardAbiVersion();
}

pub fn pendingInputAbiVersion() u32 {
    return core_api.pendingInputAbiVersion();
}

pub fn stringAbiVersion() u32 {
    return core_api.stringAbiVersion();
}

pub fn rendererMetadata(codepoint: u32, out_metadata: *RendererMetadata) Status {
    return core_api.rendererMetadata(codepoint, out_metadata);
}
