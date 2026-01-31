const app_logger = @import("../../app_logger.zig");
const std = @import("std");

pub fn logTextInput(bytes: usize) void {
    const input_log = app_logger.logger("input.sdl");
    if (input_log.enabled_file or input_log.enabled_console) {
        input_log.logf("textinput bytes={d}", .{bytes});
    }
}

pub fn logTextEditing(bytes: usize, cursor: i32, selection: i32) void {
    const ime_log = app_logger.logger("sdl.ime");
    if (ime_log.enabled_file or ime_log.enabled_console) {
        ime_log.logf(
            "textediting bytes={d} cursor={d} selection={d}",
            .{ bytes, cursor, selection },
        );
    }
}

pub fn logTextInputRaw(bytes: []const u8) void {
    const log = app_logger.logger("input.sdl");
    if (!log.enabled_file and !log.enabled_console) return;
    const preview = if (bytes.len > 32) bytes[0..32] else bytes;
    var buf: [256]u8 = undefined;
    var len: usize = 0;
    for (preview) |b| {
        if (len + 2 > buf.len) break;
        _ = std.fmt.bufPrint(buf[len..], "{x:0>2}", .{b}) catch break;
        len += 2;
    }
    log.logf("textinput raw_len={d} hex={s}", .{ bytes.len, buf[0..len] });
}

pub fn logTextInputLayout(
    size: usize,
    event_size: usize,
    offset_type: ?usize,
    offset_reserved: ?usize,
    offset_timestamp: ?usize,
    offset_window_id: ?usize,
    offset_text: ?usize,
) void {
    const log = app_logger.logger("input.sdl");
    if (!log.enabled_file and !log.enabled_console) return;
    log.logf("textinput layout size={d} event_size={d}", .{ size, event_size });
    logOffset(log, "textinput layout", "type", offset_type);
    logOffset(log, "textinput layout", "reserved", offset_reserved);
    logOffset(log, "textinput layout", "timestamp", offset_timestamp);
    logOffset(log, "textinput layout", "windowID", offset_window_id);
    logOffset(log, "textinput layout", "text", offset_text);
}

pub fn logTextInputPointer(bytes: usize, ptr: ?usize) void {
    const log = app_logger.logger("input.sdl");
    if (!log.enabled_file and !log.enabled_console) return;
    if (ptr) |addr| {
        log.logf("textinput ptr=0x{x} bytes={d}", .{ addr, bytes });
    } else {
        log.logf("textinput ptr=null bytes={d}", .{bytes});
    }
}

pub fn logTextEditingRaw(bytes: []const u8, cursor: i32, selection: i32) void {
    const log = app_logger.logger("input.sdl");
    if (!log.enabled_file and !log.enabled_console) return;
    const preview = if (bytes.len > 32) bytes[0..32] else bytes;
    var buf: [256]u8 = undefined;
    var len: usize = 0;
    for (preview) |b| {
        if (len + 2 > buf.len) break;
        _ = std.fmt.bufPrint(buf[len..], "{x:0>2}", .{b}) catch break;
        len += 2;
    }
    log.logf("textedit raw_len={d} cursor={d} selection={d} hex={s}", .{ bytes.len, cursor, selection, buf[0..len] });
}

pub fn logTextEditingLayout(
    size: usize,
    event_size: usize,
    offset_type: ?usize,
    offset_reserved: ?usize,
    offset_timestamp: ?usize,
    offset_window_id: ?usize,
    offset_text: ?usize,
    offset_start: ?usize,
    offset_length: ?usize,
    offset_cursor: ?usize,
    offset_selection_len: ?usize,
) void {
    const log = app_logger.logger("input.sdl");
    if (!log.enabled_file and !log.enabled_console) return;
    log.logf("textedit layout size={d} event_size={d}", .{ size, event_size });
    logOffset(log, "textedit layout", "type", offset_type);
    logOffset(log, "textedit layout", "reserved", offset_reserved);
    logOffset(log, "textedit layout", "timestamp", offset_timestamp);
    logOffset(log, "textedit layout", "windowID", offset_window_id);
    logOffset(log, "textedit layout", "text", offset_text);
    logOffset(log, "textedit layout", "start", offset_start);
    logOffset(log, "textedit layout", "length", offset_length);
    logOffset(log, "textedit layout", "cursor", offset_cursor);
    logOffset(log, "textedit layout", "selection_len", offset_selection_len);
}

pub fn logTextEditingPointer(bytes: usize, cursor: i32, selection: i32, ptr: ?usize) void {
    const log = app_logger.logger("input.sdl");
    if (!log.enabled_file and !log.enabled_console) return;
    if (ptr) |addr| {
        log.logf("textedit ptr=0x{x} bytes={d} cursor={d} selection={d}", .{ addr, bytes, cursor, selection });
    } else {
        log.logf("textedit ptr=null bytes={d} cursor={d} selection={d}", .{ bytes, cursor, selection });
    }
}

pub fn logEventBytes(label: []const u8, bytes: []const u8) void {
    const log = app_logger.logger("input.sdl");
    if (!log.enabled_file and !log.enabled_console) return;
    const preview = if (bytes.len > 64) bytes[0..64] else bytes;
    var buf: [256]u8 = undefined;
    var len: usize = 0;
    for (preview) |b| {
        if (len + 2 > buf.len) break;
        _ = std.fmt.bufPrint(buf[len..], "{x:0>2}", .{b}) catch break;
        len += 2;
    }
    log.logf("{s} bytes={d} hex={s}", .{ label, bytes.len, buf[0..len] });
}

fn logOffset(log: app_logger.Logger, prefix: []const u8, field: []const u8, offset: ?usize) void {
    if (offset) |value| {
        log.logf("{s} {s}={d}", .{ prefix, field, value });
    } else {
        log.logf("{s} {s}=na", .{ prefix, field });
    }
}
