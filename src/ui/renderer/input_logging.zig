const app_logger = @import("../../app_logger.zig");
const std = @import("std");

pub fn logTextInput(bytes: usize) void {
    const input_log = app_logger.logger("input.sdl");
            input_log.logf(.info, "textinput bytes={d}", .{bytes});
}

pub fn logTextEditing(bytes: usize, cursor: i32, selection: i32) void {
    const ime_log = app_logger.logger("sdl.ime");
            ime_log.logf(.info, 
            "textediting bytes={d} cursor={d} selection={d}",
            .{ bytes, cursor, selection },
        );
}

pub fn logTextInputRaw(bytes: []const u8) void {
    const log = app_logger.logger("input.sdl");
    const preview = if (bytes.len > 32) bytes[0..32] else bytes;
    var buf: [256]u8 = undefined;
    var len: usize = 0;
    for (preview) |b| {
        if (len + 2 > buf.len) break;
        _ = std.fmt.bufPrint(buf[len..], "{x:0>2}", .{b}) catch break;
        len += 2;
    }
    log.logf(.info, "textinput raw_len={d} hex={s}", .{ bytes.len, buf[0..len] });
}

pub fn logTextInputLayout(
    size: usize,
    event_size: usize,
    offset_type: usize,
    offset_reserved: usize,
    offset_timestamp: usize,
    offset_window_id: usize,
    offset_text: usize,
) void {
    const log = app_logger.logger("input.sdl");
    log.logf(.info, 
        "textinput layout size={d} event_size={d} type={d} reserved={d} timestamp={d} windowID={d} text={d}",
        .{ size, event_size, offset_type, offset_reserved, offset_timestamp, offset_window_id, offset_text },
    );
}

pub fn logTextInputPointer(bytes: usize, ptr: ?usize) void {
    const log = app_logger.logger("input.sdl");
    if (ptr) |addr| {
        log.logf(.info, "textinput ptr=0x{x} bytes={d}", .{ addr, bytes });
    } else {
        log.logf(.info, "textinput ptr=null bytes={d}", .{bytes});
    }
}

pub fn logTextEditingRaw(bytes: []const u8, cursor: i32, selection: i32) void {
    const log = app_logger.logger("input.sdl");
    const preview = if (bytes.len > 32) bytes[0..32] else bytes;
    var buf: [256]u8 = undefined;
    var len: usize = 0;
    for (preview) |b| {
        if (len + 2 > buf.len) break;
        _ = std.fmt.bufPrint(buf[len..], "{x:0>2}", .{b}) catch break;
        len += 2;
    }
    log.logf(.info, "textedit raw_len={d} cursor={d} selection={d} hex={s}", .{ bytes.len, cursor, selection, buf[0..len] });
}

pub fn logTextEditingLayout(
    size: usize,
    event_size: usize,
    offset_type: usize,
    offset_reserved: usize,
    offset_timestamp: usize,
    offset_window_id: usize,
    offset_text: usize,
    offset_start: usize,
    offset_length: usize,
    offset_cursor: usize,
    offset_selection_len: usize,
) void {
    const log = app_logger.logger("input.sdl");
    log.logf(.info, 
        "textedit layout size={d} event_size={d} type={d} reserved={d} timestamp={d} windowID={d} text={d} start={d} length={d} cursor={d} selection_len={d}",
        .{ size, event_size, offset_type, offset_reserved, offset_timestamp, offset_window_id, offset_text, offset_start, offset_length, offset_cursor, offset_selection_len },
    );
}

pub fn logTextEditingPointer(bytes: usize, cursor: i32, selection: i32, ptr: ?usize) void {
    const log = app_logger.logger("input.sdl");
    if (ptr) |addr| {
        log.logf(.info, "textedit ptr=0x{x} bytes={d} cursor={d} selection={d}", .{ addr, bytes, cursor, selection });
    } else {
        log.logf(.info, "textedit ptr=null bytes={d} cursor={d} selection={d}", .{ bytes, cursor, selection });
    }
}

pub fn logEventBytes(label: []const u8, bytes: []const u8) void {
    const log = app_logger.logger("input.sdl");
    const preview = if (bytes.len > 64) bytes[0..64] else bytes;
    var buf: [256]u8 = undefined;
    var len: usize = 0;
    for (preview) |b| {
        if (len + 2 > buf.len) break;
        _ = std.fmt.bufPrint(buf[len..], "{x:0>2}", .{b}) catch break;
        len += 2;
    }
    log.logf(.info, "{s} bytes={d} hex={s}", .{ label, bytes.len, buf[0..len] });
}
