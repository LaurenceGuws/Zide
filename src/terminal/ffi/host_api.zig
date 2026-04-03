const std = @import("std");
const host_queries = @import("../core/session/host_queries.zig");
const session_input = @import("../core/session/input.zig");
const session_runtime = @import("../core/session/runtime.zig");
const scrollback_view = @import("../core/scrollback_view.zig");
const types = @import("../model/types.zig");
const shared = @import("shared.zig");

pub fn start(handle: ?*shared.ZideTerminalHandle, shell: ?[*:0]const u8) shared.Status {
    const h = shared.fromOpaqueActive(handle) orelse return .invalid_argument;
    const shell_slice: ?[:0]const u8 = if (shell) |value| std.mem.span(value) else null;
    session_runtime.startNoThreads(h.shell, shell_slice) catch |err| return shared.mapError(err);
    return .ok;
}

pub fn poll(handle: ?*shared.ZideTerminalHandle) shared.Status {
    const h = shared.fromOpaqueActive(handle) orelse return .invalid_argument;
    session_runtime.poll(h.shell) catch |err| return shared.mapError(err);
    return shared.syncDerivedEvents(h);
}

pub fn resize(handle: ?*shared.ZideTerminalHandle, cols: u16, rows: u16, cell_width: u16, cell_height: u16) shared.Status {
    const h = shared.fromOpaqueActive(handle) orelse return .invalid_argument;
    if (rows == 0 or cols == 0) return .invalid_argument;
    session_runtime.resizeWithCellSize(h.shell, rows, cols, cell_width, cell_height) catch |err| return shared.mapError(err);
    return shared.syncDerivedEvents(h);
}

pub fn sendBytes(handle: ?*shared.ZideTerminalHandle, bytes: ?[*]const u8, len: usize) shared.Status {
    const h = shared.fromOpaqueActive(handle) orelse return .invalid_argument;
    const slice = shared.ptrLen(bytes, len) orelse return .invalid_argument;
    session_input.sendBytes(h.shell, slice) catch |err| return shared.mapError(err);
    return .ok;
}

pub fn sendText(handle: ?*shared.ZideTerminalHandle, bytes: ?[*]const u8, len: usize) shared.Status {
    const h = shared.fromOpaqueActive(handle) orelse return .invalid_argument;
    const slice = shared.ptrLen(bytes, len) orelse return .invalid_argument;
    session_input.sendText(h.shell, slice) catch |err| return shared.mapError(err);
    return .ok;
}

pub fn sendKey(handle: ?*shared.ZideTerminalHandle, event: ?*const shared.KeyEvent) shared.Status {
    const h = shared.fromOpaqueActive(handle) orelse return .invalid_argument;
    const key_event = event orelse return .invalid_argument;
    session_input.sendKey(h.shell, key_event.key, key_event.modifiers) catch |err| return shared.mapError(err);
    return .ok;
}

pub fn sendMouse(handle: ?*shared.ZideTerminalHandle, event: ?*const shared.MouseEvent) shared.Status {
    const h = shared.fromOpaqueActive(handle) orelse return .invalid_argument;
    const mouse_event = event orelse return .invalid_argument;
    const mapped = types.MouseEvent{
        .kind = switch (mouse_event.kind) {
            0 => .press,
            1 => .release,
            2 => .move,
            3 => .wheel,
            else => return .invalid_argument,
        },
        .button = switch (mouse_event.button) {
            0 => .none,
            1 => .left,
            2 => .middle,
            3 => .right,
            4 => .wheel_up,
            5 => .wheel_down,
            else => return .invalid_argument,
        },
        .row = mouse_event.row,
        .col = mouse_event.col,
        .pixel_x = if (mouse_event.has_pixel != 0) mouse_event.pixel_x else null,
        .pixel_y = if (mouse_event.has_pixel != 0) mouse_event.pixel_y else null,
        .mod = mouse_event.modifiers,
        .buttons_down = mouse_event.buttons_down,
    };
    _ = session_input.reportMouseEvent(h.shell, mapped) catch |err| return shared.mapError(err);
    return .ok;
}

pub fn reportFocusChanged(handle: ?*shared.ZideTerminalHandle, focused: u8, out_reported: *u8) shared.Status {
    const h = shared.fromOpaqueActive(handle) orelse return .invalid_argument;
    const reported = session_input.reportFocusChanged(h.shell, focused != 0) catch |err| return shared.mapError(err);
    out_reported.* = @intFromBool(reported);
    return .ok;
}

pub fn reportColorSchemeChanged(handle: ?*shared.ZideTerminalHandle, dark: u8, out_reported: *u8) shared.Status {
    const h = shared.fromOpaqueActive(handle) orelse return .invalid_argument;
    const reported = session_input.reportColorSchemeChanged(h.shell, dark != 0) catch |err| return shared.mapError(err);
    out_reported.* = @intFromBool(reported);
    return .ok;
}

pub fn setScrollbackOffset(handle: ?*shared.ZideTerminalHandle, offset_rows: u32) shared.Status {
    const h = shared.fromOpaqueActive(handle) orelse return .invalid_argument;
    if (h.shell.core.isAltActive() and offset_rows != 0) return .invalid_argument;
    scrollback_view.setScrollOffset(h.shell, offset_rows);
    return shared.syncDerivedEvents(h);
}

pub fn followLiveBottom(handle: ?*shared.ZideTerminalHandle) shared.Status {
    const h = shared.fromOpaqueActive(handle) orelse return .invalid_argument;
    scrollback_view.setScrollOffset(h.shell, 0);
    return shared.syncDerivedEvents(h);
}

pub fn isAlive(handle: ?*shared.ZideTerminalHandle) u8 {
    const h = shared.fromOpaqueActive(handle) orelse return 0;
    return @intFromBool(host_queries.isAlive(h.shell));
}

pub fn childExitStatus(handle: ?*shared.ZideTerminalHandle, out_code: *i32, out_has_status: *u8) shared.Status {
    const h = shared.fromOpaqueActive(handle) orelse return .invalid_argument;
    const runtime_metadata = host_queries.currentRuntimeMetadata(h.shell);
    if (runtime_metadata.exit_code) |code| {
        out_code.* = code;
        out_has_status.* = 1;
    } else {
        out_code.* = 0;
        out_has_status.* = 0;
    }
    return .ok;
}

pub fn reportChildExit(handle: ?*shared.ZideTerminalHandle, code: i32, has_status: u8) shared.Status {
    const h = shared.fromOpaqueActive(handle) orelse return .invalid_argument;
    const status = if (has_status != 0) @as(?i32, code) else null;
    if (!session_runtime.reportExternalChildExit(h.shell, status)) return .invalid_argument;
    return shared.syncDerivedEvents(h);
}
