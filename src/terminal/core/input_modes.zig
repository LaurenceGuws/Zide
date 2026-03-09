const std = @import("std");
const key_encoding = @import("../input/key_encoding.zig");
const app_logger = @import("../../app_logger.zig");

const supported_key_mode_flags: u32 =
    key_encoding.key_mode_disambiguate |
    key_encoding.key_mode_report_all_event_types |
    key_encoding.key_mode_report_alternate_key |
    key_encoding.key_mode_report_text |
    key_encoding.key_mode_embed_text;

pub fn sanitizeKeyModeFlags(flags: u32) u32 {
    return flags & supported_key_mode_flags;
}

pub fn keyModeFlags(self: anytype) u32 {
    return sanitizeKeyModeFlags(self.activeScreen().keyModeFlags());
}

pub fn publishSnapshot(self: anytype) void {
    const session = switch (@typeInfo(@TypeOf(self))) {
        .pointer => |ptr| switch (@typeInfo(ptr.child)) {
            .pointer => self.*,
            else => self,
        },
        else => @compileError("publishSnapshot expects a pointer receiver"),
    };
    const screen = if (session.active == .alt) &session.alt else &session.primary;
    session.input_snapshot.app_cursor_keys.store(session.app_cursor_keys, .release);
    session.input_snapshot.app_keypad.store(session.app_keypad, .release);
    session.input_snapshot.key_mode_flags.store(keyModeFlags(session), .release);
    session.input_snapshot.mouse_mode_x10.store(session.input.mouse_mode_x10, .release);
    session.input_snapshot.mouse_mode_button.store(session.input.mouse_mode_button, .release);
    session.input_snapshot.mouse_mode_any.store(session.input.mouse_mode_any, .release);
    session.input_snapshot.mouse_mode_sgr.store(session.input.mouse_mode_sgr, .release);
    session.input_snapshot.mouse_mode_sgr_pixels_1016.store(session.input.mouse_mode_sgr_pixels_1016, .release);
    session.input_snapshot.focus_reporting.store(session.focus_reporting, .release);
    session.input_snapshot.bracketed_paste.store(session.bracketed_paste, .release);
    session.input_snapshot.auto_repeat.store(session.auto_repeat, .release);
    session.input_snapshot.mouse_alternate_scroll.store(session.mouse_alternate_scroll, .release);
    session.input_snapshot.alt_active.store(session.active == .alt, .release);
    session.input_snapshot.screen_rows.store(screen.grid.rows, .release);
    session.input_snapshot.screen_cols.store(screen.grid.cols, .release);
}

pub fn keyModePush(self: anytype, flags: u32) void {
    self.state_mutex.lock();
    defer self.state_mutex.unlock();
    keyModePushLocked(self, flags);
}

pub fn keyModePushLocked(self: anytype, flags: u32) void {
    self.activeScreen().keyModePush(sanitizeKeyModeFlags(flags));
    publishSnapshot(self);
}

pub fn keyModePop(self: anytype, count: usize) void {
    self.state_mutex.lock();
    defer self.state_mutex.unlock();
    keyModePopLocked(self, count);
}

pub fn keyModePopLocked(self: anytype, count: usize) void {
    self.activeScreen().keyModePop(count);
    publishSnapshot(self);
}

pub fn keyModeModify(self: anytype, flags: u32, mode: u32) void {
    self.state_mutex.lock();
    defer self.state_mutex.unlock();
    keyModeModifyLocked(self, flags, mode);
}

pub fn keyModeModifyLocked(self: anytype, flags: u32, mode: u32) void {
    self.activeScreen().keyModeModify(sanitizeKeyModeFlags(flags), mode);
    publishSnapshot(self);
}

pub fn keyModeQuery(self: anytype) void {
    self.state_mutex.lock();
    defer self.state_mutex.unlock();
    keyModeQueryLocked(self);
}

pub fn keyModeQueryLocked(self: anytype) void {
    const log = app_logger.logger("terminal.input.keys");
    const flags = keyModeFlags(self);
    var buf: [32]u8 = undefined;
    const seq = std.fmt.bufPrint(&buf, "\x1b[?{d}u", .{flags}) catch |err| {
        log.logf(.warning, "key mode query format failed flags={d} err={s}", .{ flags, @errorName(err) });
        return;
    };
    self.writePtyBytes(seq) catch |err| {
        log.logf(.warning, "key mode query write failed flags={d} err={s}", .{ flags, @errorName(err) });
    };
}

pub fn setKeypadMode(self: anytype, enabled: bool) void {
    self.state_mutex.lock();
    defer self.state_mutex.unlock();
    setKeypadModeLocked(self, enabled);
}

pub fn setKeypadModeLocked(self: anytype, enabled: bool) void {
    self.app_keypad = enabled;
    publishSnapshot(self);
}

pub fn setAppCursorKeys(self: anytype, enabled: bool) void {
    self.state_mutex.lock();
    defer self.state_mutex.unlock();
    setAppCursorKeysLocked(self, enabled);
}

pub fn setAppCursorKeysLocked(self: anytype, enabled: bool) void {
    self.app_cursor_keys = enabled;
    publishSnapshot(self);
}

pub fn setAutoRepeat(self: anytype, enabled: bool) void {
    self.state_mutex.lock();
    defer self.state_mutex.unlock();
    setAutoRepeatLocked(self, enabled);
}

pub fn setAutoRepeatLocked(self: anytype, enabled: bool) void {
    self.auto_repeat = enabled;
    publishSnapshot(self);
}

pub fn setBracketedPaste(self: anytype, enabled: bool) void {
    self.state_mutex.lock();
    defer self.state_mutex.unlock();
    setBracketedPasteLocked(self, enabled);
}

pub fn setBracketedPasteLocked(self: anytype, enabled: bool) void {
    self.bracketed_paste = enabled;
    publishSnapshot(self);
}

pub fn setFocusReporting(self: anytype, enabled: bool) void {
    self.state_mutex.lock();
    defer self.state_mutex.unlock();
    setFocusReportingLocked(self, enabled);
}

pub fn setFocusReportingLocked(self: anytype, enabled: bool) void {
    self.focus_reporting = enabled;
    publishSnapshot(self);
}

pub fn setMouseAlternateScroll(self: anytype, enabled: bool) void {
    self.state_mutex.lock();
    defer self.state_mutex.unlock();
    setMouseAlternateScrollLocked(self, enabled);
}

pub fn setMouseAlternateScrollLocked(self: anytype, enabled: bool) void {
    self.mouse_alternate_scroll = enabled;
    publishSnapshot(self);
}

pub fn setMouseModeX10(self: anytype, enabled: bool) void {
    self.state_mutex.lock();
    defer self.state_mutex.unlock();
    setMouseModeX10Locked(self, enabled);
}

pub fn setMouseModeX10Locked(self: anytype, enabled: bool) void {
    self.input.mouse_mode_x10 = enabled;
    publishSnapshot(self);
}

pub fn setMouseModeButton(self: anytype, enabled: bool) void {
    self.state_mutex.lock();
    defer self.state_mutex.unlock();
    setMouseModeButtonLocked(self, enabled);
}

pub fn setMouseModeButtonLocked(self: anytype, enabled: bool) void {
    self.input.mouse_mode_button = enabled;
    publishSnapshot(self);
}

pub fn setMouseModeAny(self: anytype, enabled: bool) void {
    self.state_mutex.lock();
    defer self.state_mutex.unlock();
    setMouseModeAnyLocked(self, enabled);
}

pub fn setMouseModeAnyLocked(self: anytype, enabled: bool) void {
    self.input.mouse_mode_any = enabled;
    publishSnapshot(self);
}

pub fn setMouseModeSgr(self: anytype, enabled: bool) void {
    self.state_mutex.lock();
    defer self.state_mutex.unlock();
    setMouseModeSgrLocked(self, enabled);
}

pub fn setMouseModeSgrLocked(self: anytype, enabled: bool) void {
    self.input.mouse_mode_sgr = enabled;
    publishSnapshot(self);
}

pub fn setMouseModeSgrPixels(self: anytype, enabled: bool) void {
    self.state_mutex.lock();
    defer self.state_mutex.unlock();
    setMouseModeSgrPixelsLocked(self, enabled);
}

pub fn setMouseModeSgrPixelsLocked(self: anytype, enabled: bool) void {
    self.input.mouse_mode_sgr_pixels_1016 = enabled;
    publishSnapshot(self);
}

pub fn resetInputModes(self: anytype) void {
    self.state_mutex.lock();
    defer self.state_mutex.unlock();
    resetInputModesLocked(self);
}

pub fn resetInputModesLocked(self: anytype) void {
    self.app_cursor_keys = false;
    self.app_keypad = false;
    self.auto_repeat = true;
    self.mouse_alternate_scroll = true;
    self.input.resetMouse();
    self.bracketed_paste = false;
    self.focus_reporting = false;
    publishSnapshot(self);
}

pub fn appKeypadEnabled(self: anytype) bool {
    return self.input_snapshot.app_keypad.load(.acquire);
}

test "sanitize key mode flags preserves alternate-key bit" {
    const flags = key_encoding.key_mode_report_alternate_key |
        key_encoding.key_mode_report_text |
        key_encoding.key_mode_report_all_event_types;
    const sanitized = sanitizeKeyModeFlags(flags);
    try std.testing.expect((sanitized & key_encoding.key_mode_report_alternate_key) != 0);
    try std.testing.expect((sanitized & key_encoding.key_mode_report_text) != 0);
    try std.testing.expect((sanitized & key_encoding.key_mode_report_all_event_types) != 0);
}
