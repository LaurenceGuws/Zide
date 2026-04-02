const std = @import("std");
const host_queries = @import("../core/session/host_queries.zig");
const session_content = @import("../core/session/content.zig");
const session_input = @import("../core/session/input.zig");
const session_runtime = @import("../core/session/runtime.zig");
const types = @import("../model/types.zig");
const shared = @import("shared.zig");

pub fn start(handle: ?*shared.ZideTerminalHandle, shell: ?[*:0]const u8) shared.Status {
    const h = shared.fromOpaqueActive(handle) orelse return .invalid_argument;
    const shell_slice: ?[:0]const u8 = if (shell) |value| std.mem.span(value) else null;
    session_runtime.startNoThreads(h.session, shell_slice) catch |err| return shared.mapError(err);
    return .ok;
}

pub fn poll(handle: ?*shared.ZideTerminalHandle) shared.Status {
    const h = shared.fromOpaqueActive(handle) orelse return .invalid_argument;
    session_runtime.poll(h.session) catch |err| return shared.mapError(err);
    return shared.syncDerivedEvents(h);
}

pub fn resize(handle: ?*shared.ZideTerminalHandle, cols: u16, rows: u16, cell_width: u16, cell_height: u16) shared.Status {
    const h = shared.fromOpaqueActive(handle) orelse return .invalid_argument;
    if (rows == 0 or cols == 0) return .invalid_argument;
    session_runtime.resizeWithCellSize(h.session, rows, cols, cell_width, cell_height) catch |err| return shared.mapError(err);
    return shared.syncDerivedEvents(h);
}

pub fn sendBytes(handle: ?*shared.ZideTerminalHandle, bytes: ?[*]const u8, len: usize) shared.Status {
    const h = shared.fromOpaqueActive(handle) orelse return .invalid_argument;
    const slice = shared.ptrLen(bytes, len) orelse return .invalid_argument;
    session_input.sendBytes(h.session, slice) catch |err| return shared.mapError(err);
    return .ok;
}

pub fn sendText(handle: ?*shared.ZideTerminalHandle, bytes: ?[*]const u8, len: usize) shared.Status {
    const h = shared.fromOpaqueActive(handle) orelse return .invalid_argument;
    const slice = shared.ptrLen(bytes, len) orelse return .invalid_argument;
    session_input.sendText(h.session, slice) catch |err| return shared.mapError(err);
    return .ok;
}

pub fn sendKey(handle: ?*shared.ZideTerminalHandle, event: ?*const shared.KeyEvent) shared.Status {
    const h = shared.fromOpaqueActive(handle) orelse return .invalid_argument;
    const key_event = event orelse return .invalid_argument;
    session_input.sendKey(h.session, key_event.key, key_event.modifiers) catch |err| return shared.mapError(err);
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
    _ = session_input.reportMouseEvent(h.session, mapped) catch |err| return shared.mapError(err);
    return .ok;
}

pub fn reportFocusChanged(handle: ?*shared.ZideTerminalHandle, focused: u8, out_reported: *u8) shared.Status {
    const h = shared.fromOpaqueActive(handle) orelse return .invalid_argument;
    const reported = session_input.reportFocusChanged(h.session, focused != 0) catch |err| return shared.mapError(err);
    out_reported.* = @intFromBool(reported);
    return .ok;
}

pub fn reportColorSchemeChanged(handle: ?*shared.ZideTerminalHandle, dark: u8, out_reported: *u8) shared.Status {
    const h = shared.fromOpaqueActive(handle) orelse return .invalid_argument;
    const reported = session_input.reportColorSchemeChanged(h.session, dark != 0) catch |err| return shared.mapError(err);
    out_reported.* = @intFromBool(reported);
    return .ok;
}

pub fn setScrollbackOffset(handle: ?*shared.ZideTerminalHandle, offset_rows: u32) shared.Status {
    const h = shared.fromOpaqueActive(handle) orelse return .invalid_argument;
    if (h.session.core.isAltActive() and offset_rows != 0) return .invalid_argument;
    session_content.setScrollOffset(h.session, offset_rows);
    return shared.syncDerivedEvents(h);
}

pub fn followLiveBottom(handle: ?*shared.ZideTerminalHandle) shared.Status {
    const h = shared.fromOpaqueActive(handle) orelse return .invalid_argument;
    session_content.setScrollOffset(h.session, 0);
    return shared.syncDerivedEvents(h);
}

pub fn isAlive(handle: ?*shared.ZideTerminalHandle) u8 {
    const h = shared.fromOpaqueActive(handle) orelse return 0;
    return @intFromBool(host_queries.isAlive(h.session));
}

pub fn childExitStatus(handle: ?*shared.ZideTerminalHandle, out_code: *i32, out_has_status: *u8) shared.Status {
    const h = shared.fromOpaqueActive(handle) orelse return .invalid_argument;
    const metadata = host_queries.copyMetadata(h.session, h.allocator, &h.scratch_title, &h.scratch_cwd) catch |err| return shared.mapError(err);
    if (metadata.exit_code) |code| {
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
    if (!session_runtime.reportExternalChildExit(h.session, status)) return .invalid_argument;
    return shared.syncDerivedEvents(h);
}
