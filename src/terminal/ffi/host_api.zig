const std = @import("std");
const types = @import("../model/types.zig");
const shared = @import("shared.zig");

pub fn start(handle: ?*shared.ZideTerminalHandle, shell: ?[*:0]const u8) shared.Status {
    const h = shared.fromOpaque(handle) orelse return .invalid_argument;
    const shell_slice: ?[:0]const u8 = if (shell) |value| std.mem.span(value) else null;
    h.session.startNoThreads(shell_slice) catch |err| return shared.mapError(err);
    return .ok;
}

pub fn poll(handle: ?*shared.ZideTerminalHandle) shared.Status {
    const h = shared.fromOpaque(handle) orelse return .invalid_argument;
    h.session.poll() catch |err| return shared.mapError(err);
    return shared.syncDerivedEvents(h);
}

pub fn resize(handle: ?*shared.ZideTerminalHandle, cols: u16, rows: u16, cell_width: u16, cell_height: u16) shared.Status {
    const h = shared.fromOpaque(handle) orelse return .invalid_argument;
    if (rows == 0 or cols == 0) return .invalid_argument;
    h.session.resize(rows, cols) catch |err| return shared.mapError(err);
    h.session.setCellSize(cell_width, cell_height);
    return shared.syncDerivedEvents(h);
}

pub fn sendBytes(handle: ?*shared.ZideTerminalHandle, bytes: ?[*]const u8, len: usize) shared.Status {
    const h = shared.fromOpaque(handle) orelse return .invalid_argument;
    const slice = shared.ptrLen(bytes, len) orelse return .invalid_argument;
    h.session.sendBytes(slice) catch |err| return shared.mapError(err);
    return .ok;
}

pub fn sendText(handle: ?*shared.ZideTerminalHandle, bytes: ?[*]const u8, len: usize) shared.Status {
    const h = shared.fromOpaque(handle) orelse return .invalid_argument;
    const slice = shared.ptrLen(bytes, len) orelse return .invalid_argument;
    h.session.sendText(slice) catch |err| return shared.mapError(err);
    return .ok;
}

pub fn sendKey(handle: ?*shared.ZideTerminalHandle, event: ?*const shared.KeyEvent) shared.Status {
    const h = shared.fromOpaque(handle) orelse return .invalid_argument;
    const key_event = event orelse return .invalid_argument;
    h.session.sendKey(key_event.key, key_event.modifiers) catch |err| return shared.mapError(err);
    return .ok;
}

pub fn sendMouse(handle: ?*shared.ZideTerminalHandle, event: ?*const shared.MouseEvent) shared.Status {
    const h = shared.fromOpaque(handle) orelse return .invalid_argument;
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
    _ = h.session.reportMouseEvent(mapped) catch |err| return shared.mapError(err);
    return .ok;
}

pub fn setScrollbackOffset(handle: ?*shared.ZideTerminalHandle, offset_rows: u32) shared.Status {
    const h = shared.fromOpaque(handle) orelse return .invalid_argument;
    if (h.session.isAltActive() and offset_rows != 0) return .invalid_argument;
    h.session.setScrollOffset(offset_rows);
    return shared.syncDerivedEvents(h);
}

pub fn followLiveBottom(handle: ?*shared.ZideTerminalHandle) shared.Status {
    const h = shared.fromOpaque(handle) orelse return .invalid_argument;
    h.session.setScrollOffset(0);
    return shared.syncDerivedEvents(h);
}

pub fn isAlive(handle: ?*shared.ZideTerminalHandle) u8 {
    const h = shared.fromOpaque(handle) orelse return 0;
    return @intFromBool(h.session.isAlive());
}

pub fn childExitStatus(handle: ?*shared.ZideTerminalHandle, out_code: *i32, out_has_status: *u8) shared.Status {
    const h = shared.fromOpaque(handle) orelse return .invalid_argument;
    const metadata = h.session.copyMetadata(h.allocator, &h.scratch_title, &h.scratch_cwd) catch |err| return shared.mapError(err);
    if (metadata.exit_code) |code| {
        out_code.* = code;
        out_has_status.* = 1;
    } else {
        out_code.* = 0;
        out_has_status.* = 0;
    }
    return .ok;
}
