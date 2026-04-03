const std = @import("std");
const host_reporting = @import("host_reporting.zig");
const input_modes = @import("../input_modes.zig");

pub fn bracketedPasteEnabled(self: anytype) bool {
    return self.session.interaction.derived_snapshot.input.bracketed_paste.load(.acquire);
}

pub fn focusReportingEnabled(self: anytype) bool {
    return self.session.interaction.derived_snapshot.input.focus_reporting.load(.acquire);
}

pub fn autoRepeatEnabled(self: anytype) bool {
    return self.session.interaction.derived_snapshot.input.auto_repeat.load(.acquire);
}

pub fn mouseAlternateScrollEnabled(self: anytype) bool {
    return self.session.interaction.derived_snapshot.input.mouse_alternate_scroll.load(.acquire);
}

pub fn mouseModeX10Enabled(self: anytype) bool {
    return self.session.interaction.derived_snapshot.input.mouse_mode_x10.load(.acquire);
}

pub fn mouseModeButtonEnabled(self: anytype) bool {
    return self.session.interaction.derived_snapshot.input.mouse_mode_button.load(.acquire);
}

pub fn mouseModeAnyEnabled(self: anytype) bool {
    return self.session.interaction.derived_snapshot.input.mouse_mode_any.load(.acquire);
}

pub fn mouseModeSgrEnabled(self: anytype) bool {
    return self.session.interaction.derived_snapshot.input.mouse_mode_sgr.load(.acquire);
}

pub fn mouseModeSgrPixelsEnabled(self: anytype) bool {
    return self.session.interaction.derived_snapshot.input.mouse_mode_sgr_pixels_1016.load(.acquire);
}

pub fn kittyPasteEvents5522Enabled(self: anytype) bool {
    return host_reporting.kittyPasteEvents5522Enabled(self);
}

pub fn sendKittyPasteEvent5522(self: anytype, clip: []const u8) !bool {
    return host_reporting.sendKittyPasteEvent5522(self, clip);
}

pub fn sendKittyPasteEvent5522WithHtml(self: anytype, clip: []const u8, html: ?[]const u8) !bool {
    return host_reporting.sendKittyPasteEvent5522WithHtml(self, clip, html);
}

pub fn sendKittyPasteEvent5522WithMime(self: anytype, clip: []const u8, html: ?[]const u8, uri_list: ?[]const u8) !bool {
    return host_reporting.sendKittyPasteEvent5522WithMime(self, clip, html, uri_list);
}

pub fn sendKittyPasteEvent5522WithMimeRich(
    self: anytype,
    clip: []const u8,
    html: ?[]const u8,
    uri_list: ?[]const u8,
    png: ?[]const u8,
) !bool {
    return host_reporting.sendKittyPasteEvent5522WithMimeRich(self, clip, html, uri_list, png);
}

pub fn mouseReportingEnabled(self: anytype) bool {
    const input_snapshot = self.session.interaction.derived_snapshot.input;
    return input_snapshot.mouse_mode_x10.load(.acquire) or
        input_snapshot.mouse_mode_button.load(.acquire) or
        input_snapshot.mouse_mode_any.load(.acquire);
}

pub fn getDamage(self: anytype) ?struct {
    start_row: usize,
    end_row: usize,
    start_col: usize,
    end_col: usize,
} {
    return self.core.activeScreenConst().getDamage();
}

pub fn keyModeFlagsValue(self: anytype) u32 {
    return self.session.interaction.derived_snapshot.input.key_mode_flags.load(.acquire);
}

pub fn keyModePush(self: anytype, flags: u32) void {
    input_modes.keyModePush(self, flags);
}

pub fn keyModePushLocked(self: anytype, flags: u32) void {
    input_modes.keyModePushLocked(self, flags);
}

pub fn keyModePop(self: anytype, count: usize) void {
    input_modes.keyModePop(self, count);
}

pub fn keyModePopLocked(self: anytype, count: usize) void {
    input_modes.keyModePopLocked(self, count);
}

pub fn keyModeModify(self: anytype, flags: u32, mode: u32) void {
    input_modes.keyModeModify(self, flags, mode);
}

pub fn keyModeModifyLocked(self: anytype, flags: u32, mode: u32) void {
    input_modes.keyModeModifyLocked(self, flags, mode);
}

pub fn keyModeQuery(self: anytype) void {
    input_modes.keyModeQuery(self);
}

pub fn keyModeQueryLocked(self: anytype) void {
    input_modes.keyModeQueryLocked(self);
}

pub fn setAppCursorKeys(self: anytype, enabled: bool) void {
    input_modes.setAppCursorKeys(self, enabled);
}

pub fn setAppCursorKeysLocked(self: anytype, enabled: bool) void {
    input_modes.setAppCursorKeysLocked(self, enabled);
}

pub fn setAutoRepeat(self: anytype, enabled: bool) void {
    input_modes.setAutoRepeat(self, enabled);
}

pub fn setAutoRepeatLocked(self: anytype, enabled: bool) void {
    input_modes.setAutoRepeatLocked(self, enabled);
}

pub fn setBracketedPaste(self: anytype, enabled: bool) void {
    input_modes.setBracketedPaste(self, enabled);
}

pub fn setBracketedPasteLocked(self: anytype, enabled: bool) void {
    input_modes.setBracketedPasteLocked(self, enabled);
}

pub fn setFocusReporting(self: anytype, enabled: bool) void {
    input_modes.setFocusReporting(self, enabled);
}

pub fn setFocusReportingLocked(self: anytype, enabled: bool) void {
    input_modes.setFocusReportingLocked(self, enabled);
}

pub fn setMouseAlternateScroll(self: anytype, enabled: bool) void {
    input_modes.setMouseAlternateScroll(self, enabled);
}

pub fn setMouseAlternateScrollLocked(self: anytype, enabled: bool) void {
    input_modes.setMouseAlternateScrollLocked(self, enabled);
}

pub fn setMouseModeX10(self: anytype, enabled: bool) void {
    input_modes.setMouseModeX10(self, enabled);
}

pub fn setMouseModeX10Locked(self: anytype, enabled: bool) void {
    input_modes.setMouseModeX10Locked(self, enabled);
}

pub fn setMouseModeButton(self: anytype, enabled: bool) void {
    input_modes.setMouseModeButton(self, enabled);
}

pub fn setMouseModeButtonLocked(self: anytype, enabled: bool) void {
    input_modes.setMouseModeButtonLocked(self, enabled);
}

pub fn setMouseModeAny(self: anytype, enabled: bool) void {
    input_modes.setMouseModeAny(self, enabled);
}

pub fn setMouseModeAnyLocked(self: anytype, enabled: bool) void {
    input_modes.setMouseModeAnyLocked(self, enabled);
}

pub fn setMouseModeSgr(self: anytype, enabled: bool) void {
    input_modes.setMouseModeSgr(self, enabled);
}

pub fn setMouseModeSgrLocked(self: anytype, enabled: bool) void {
    input_modes.setMouseModeSgrLocked(self, enabled);
}

pub fn setMouseModeSgrPixels(self: anytype, enabled: bool) void {
    input_modes.setMouseModeSgrPixels(self, enabled);
}

pub fn setMouseModeSgrPixelsLocked(self: anytype, enabled: bool) void {
    input_modes.setMouseModeSgrPixelsLocked(self, enabled);
}

pub fn resetInputModes(self: anytype) void {
    input_modes.resetInputModes(self);
}

pub fn resetInputModesLocked(self: anytype) void {
    input_modes.resetInputModesLocked(self);
}

pub fn setKeypadMode(self: anytype, enabled: bool) void {
    input_modes.setKeypadMode(self, enabled);
}

pub fn setKeypadModeLocked(self: anytype, enabled: bool) void {
    input_modes.setKeypadModeLocked(self, enabled);
}
