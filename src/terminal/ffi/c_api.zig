const bridge = @import("bridge.zig");

pub const ZideTerminalHandle = bridge.ZideTerminalHandle;
pub const ZIDE_TERMINAL_SNAPSHOT_ABI_VERSION = bridge.snapshot_abi_version;
pub const ZIDE_TERMINAL_EVENT_ABI_VERSION = bridge.event_abi_version;
pub const ZideTerminalCreateConfig = bridge.CreateConfig;
pub const ZideTerminalColor = bridge.Color;
pub const ZideTerminalCell = bridge.Cell;
pub const ZideTerminalSnapshot = bridge.Snapshot;
pub const ZideTerminalKeyEvent = bridge.KeyEvent;
pub const ZideTerminalMouseEvent = bridge.MouseEvent;
pub const ZideTerminalEvent = bridge.Event;
pub const ZideTerminalEventBuffer = bridge.EventBuffer;
pub const ZideTerminalStringBuffer = bridge.StringBuffer;
pub const ZideTerminalStatus = bridge.Status;
pub const ZideTerminalEventKind = bridge.EventKind;

pub fn zide_terminal_create(config: ?*const ZideTerminalCreateConfig, out_handle: *?*ZideTerminalHandle) c_int {
    return @intFromEnum(bridge.create(config, out_handle));
}

pub fn zide_terminal_destroy(handle: ?*ZideTerminalHandle) void {
    bridge.destroy(handle);
}

pub fn zide_terminal_start(handle: ?*ZideTerminalHandle, shell: ?[*:0]const u8) c_int {
    return @intFromEnum(bridge.start(handle, shell));
}

pub fn zide_terminal_poll(handle: ?*ZideTerminalHandle) c_int {
    return @intFromEnum(bridge.poll(handle));
}

pub fn zide_terminal_resize(handle: ?*ZideTerminalHandle, cols: u16, rows: u16, cell_width: u16, cell_height: u16) c_int {
    return @intFromEnum(bridge.resize(handle, cols, rows, cell_width, cell_height));
}

pub fn zide_terminal_send_bytes(handle: ?*ZideTerminalHandle, bytes: ?[*]const u8, len: usize) c_int {
    return @intFromEnum(bridge.sendBytes(handle, bytes, len));
}

pub fn zide_terminal_send_text(handle: ?*ZideTerminalHandle, text: ?[*]const u8, len: usize) c_int {
    return @intFromEnum(bridge.sendText(handle, text, len));
}

pub fn zide_terminal_feed_output(handle: ?*ZideTerminalHandle, bytes: ?[*]const u8, len: usize) c_int {
    return @intFromEnum(bridge.feedOutput(handle, bytes, len));
}

pub fn zide_terminal_send_key(handle: ?*ZideTerminalHandle, event: ?*const ZideTerminalKeyEvent) c_int {
    return @intFromEnum(bridge.sendKey(handle, event));
}

pub fn zide_terminal_send_mouse(handle: ?*ZideTerminalHandle, event: ?*const ZideTerminalMouseEvent) c_int {
    return @intFromEnum(bridge.sendMouse(handle, event));
}

pub fn zide_terminal_snapshot_acquire(handle: ?*ZideTerminalHandle, out_snapshot: *ZideTerminalSnapshot) c_int {
    return @intFromEnum(bridge.snapshotAcquire(handle, out_snapshot));
}

pub fn zide_terminal_snapshot_release(snapshot: *ZideTerminalSnapshot) void {
    bridge.snapshotRelease(snapshot);
}

pub fn zide_terminal_event_drain(handle: ?*ZideTerminalHandle, out_events: *ZideTerminalEventBuffer) c_int {
    return @intFromEnum(bridge.eventDrain(handle, out_events));
}

pub fn zide_terminal_events_free(events: *ZideTerminalEventBuffer) void {
    bridge.eventsFree(events);
}

pub fn zide_terminal_is_alive(handle: ?*ZideTerminalHandle) u8 {
    return bridge.isAlive(handle);
}

pub fn zide_terminal_current_title(handle: ?*ZideTerminalHandle, out_string: *ZideTerminalStringBuffer) c_int {
    return @intFromEnum(bridge.currentTitle(handle, out_string));
}

pub fn zide_terminal_current_cwd(handle: ?*ZideTerminalHandle, out_string: *ZideTerminalStringBuffer) c_int {
    return @intFromEnum(bridge.currentCwd(handle, out_string));
}

pub fn zide_terminal_string_free(string: *ZideTerminalStringBuffer) void {
    bridge.stringFree(string);
}

pub fn zide_terminal_child_exit_status(handle: ?*ZideTerminalHandle, out_code: *i32, out_has_status: *u8) c_int {
    return @intFromEnum(bridge.childExitStatus(handle, out_code, out_has_status));
}

pub fn zide_terminal_snapshot_abi_version() u32 {
    return bridge.snapshotAbiVersion();
}

pub fn zide_terminal_event_abi_version() u32 {
    return bridge.eventAbiVersion();
}

pub fn zide_terminal_status_string(status: c_int) [*:0]const u8 {
    return switch (status) {
        0 => "ok",
        1 => "invalid_argument",
        2 => "out_of_memory",
        3 => "backend_error",
        else => "unknown_status",
    };
}
