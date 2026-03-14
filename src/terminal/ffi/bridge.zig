const shared = @import("shared.zig");
const host_api = @import("host_api.zig");
const core_api = @import("core_api.zig");

pub const Status = shared.Status;
pub const snapshot_abi_version = shared.snapshot_abi_version;
pub const event_abi_version = shared.event_abi_version;
pub const scrollback_abi_version = shared.scrollback_abi_version;
pub const renderer_metadata_abi_version = shared.renderer_metadata_abi_version;
pub const metadata_abi_version = shared.metadata_abi_version;
pub const redraw_state_abi_version = shared.redraw_state_abi_version;
pub const EventKind = shared.EventKind;
pub const GlyphClassFlags = shared.GlyphClassFlags;
pub const DamagePolicyFlags = shared.DamagePolicyFlags;
pub const ZideTerminalHandle = shared.ZideTerminalHandle;
pub const CreateConfig = shared.CreateConfig;
pub const Color = shared.Color;
pub const Cell = shared.Cell;
pub const Snapshot = shared.Snapshot;
pub const ScrollbackBuffer = shared.ScrollbackBuffer;
pub const Metadata = shared.Metadata;
pub const RedrawState = shared.RedrawState;
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

pub fn needsRedraw(handle: ?*ZideTerminalHandle) u8 {
    return core_api.needsRedraw(handle);
}

pub fn sendKey(handle: ?*ZideTerminalHandle, event: ?*const KeyEvent) Status {
    return host_api.sendKey(handle, event);
}

pub fn sendMouse(handle: ?*ZideTerminalHandle, event: ?*const MouseEvent) Status {
    return host_api.sendMouse(handle, event);
}

pub fn snapshotAcquire(handle: ?*ZideTerminalHandle, out_snapshot: *Snapshot) Status {
    return core_api.snapshotAcquire(handle, out_snapshot);
}

pub fn snapshotRelease(snapshot: *Snapshot) void {
    core_api.snapshotRelease(snapshot);
}

pub fn scrollbackAcquire(handle: ?*ZideTerminalHandle, start_row: u32, max_rows: u32, out_buffer: *ScrollbackBuffer) Status {
    return core_api.scrollbackAcquire(handle, start_row, max_rows, out_buffer);
}

pub fn scrollbackRelease(scrollback: *ScrollbackBuffer) void {
    core_api.scrollbackRelease(scrollback);
}

pub fn metadataAcquire(handle: ?*ZideTerminalHandle, out_metadata: *Metadata) Status {
    return core_api.metadataAcquire(handle, out_metadata);
}

pub fn metadataRelease(metadata: *Metadata) void {
    core_api.metadataRelease(metadata);
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

pub fn snapshotAbiVersion() u32 {
    return core_api.snapshotAbiVersion();
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

pub fn rendererMetadata(codepoint: u32, out_metadata: *RendererMetadata) Status {
    return core_api.rendererMetadata(codepoint, out_metadata);
}
