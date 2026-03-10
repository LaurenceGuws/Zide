const std = @import("std");
const app_logger = @import("../../app_logger.zig");
const terminal_transport = @import("terminal_transport.zig");
const osc_kitty_clipboard = @import("../protocol/osc_kitty_clipboard.zig");
const input_modes = @import("input_modes.zig");

pub fn bracketedPasteEnabled(self: anytype) bool {
    return self.input_snapshot.bracketed_paste.load(.acquire);
}

pub fn pasteSystemClipboard(
    self: anytype,
    clip_opt: ?[]const u8,
    html: ?[]const u8,
    uri_list: ?[]const u8,
    png: ?[]const u8,
) !bool {
    const log = app_logger.logger("terminal.widget");
    const clip = clip_opt orelse "";
    const has_supported_clipboard_data = clip_opt != null or html != null or uri_list != null or png != null;
    if (!has_supported_clipboard_data) return false;

    if (self.renderCache().scroll_offset > 0) {
        self.setScrollOffset(0);
    }

    if (try self.sendKittyPasteEvent5522WithMimeRich(clip, html, uri_list, png)) {
        return true;
    }

    if (clip_opt == null) return false;

    if (self.bracketedPasteEnabled()) {
        self.sendText("\x1b[200~") catch |err| {
            log.logf(.warning, "paste failed sending bracketed prefix err={s}", .{@errorName(err)});
            return false;
        };

        var filtered = std.ArrayList(u8).empty;
        defer filtered.deinit(self.allocator);
        for (clip_opt.?) |b| {
            if (b == 0x1b or b == 0x03) continue;
            filtered.append(self.allocator, b) catch {
                log.logf(.warning, "paste failed appending filtered clipboard byte", .{});
                return false;
            };
        }
        if (filtered.items.len > 0) {
            self.sendText(filtered.items) catch |err| {
                log.logf(.warning, "paste failed sending filtered clipboard err={s}", .{@errorName(err)});
                return false;
            };
        }
        self.sendText("\x1b[201~") catch |err| {
            log.logf(.warning, "paste failed sending bracketed suffix err={s}", .{@errorName(err)});
            return false;
        };
        return true;
    }

    self.sendText(clip_opt.?) catch |err| {
        log.logf(.warning, "paste failed sending clipboard err={s}", .{@errorName(err)});
        return false;
    };
    return true;
}

pub fn pasteSelectionClipboard(
    self: anytype,
    clip_opt: ?[]const u8,
    html: ?[]const u8,
    uri_list: ?[]const u8,
    png: ?[]const u8,
) !bool {
    const has_supported_clipboard_data = clip_opt != null or html != null or uri_list != null or png != null;
    if (!has_supported_clipboard_data) return false;

    const clip = clip_opt orelse "";
    if (try self.sendKittyPasteEvent5522WithMimeRich(clip, html, uri_list, png)) {
        return true;
    }
    if (clip_opt) |clip_text| {
        if (self.bracketedPasteEnabled()) {
            try self.sendText("\x1b[200~");
            try self.sendText(clip_text);
            try self.sendText("\x1b[201~");
        } else {
            try self.sendText(clip_text);
        }
        return true;
    }
    return false;
}

pub fn focusReportingEnabled(self: anytype) bool {
    return self.input_snapshot.focus_reporting.load(.acquire);
}

pub fn autoRepeatEnabled(self: anytype) bool {
    return self.input_snapshot.auto_repeat.load(.acquire);
}

pub fn mouseAlternateScrollEnabled(self: anytype) bool {
    return self.input_snapshot.mouse_alternate_scroll.load(.acquire);
}

pub fn mouseModeX10Enabled(self: anytype) bool {
    return self.input_snapshot.mouse_mode_x10.load(.acquire);
}

pub fn mouseModeButtonEnabled(self: anytype) bool {
    return self.input_snapshot.mouse_mode_button.load(.acquire);
}

pub fn mouseModeAnyEnabled(self: anytype) bool {
    return self.input_snapshot.mouse_mode_any.load(.acquire);
}

pub fn mouseModeSgrEnabled(self: anytype) bool {
    return self.input_snapshot.mouse_mode_sgr.load(.acquire);
}

pub fn mouseModeSgrPixelsEnabled(self: anytype) bool {
    return self.input_snapshot.mouse_mode_sgr_pixels_1016.load(.acquire);
}

pub fn kittyPasteEvents5522Enabled(self: anytype) bool {
    return self.kitty_paste_events_5522;
}

pub fn sendKittyPasteEvent5522(self: anytype, clip: []const u8) !bool {
    return sendKittyPasteEvent5522WithMime(self, clip, null, null);
}

pub fn sendKittyPasteEvent5522WithHtml(self: anytype, clip: []const u8, html: ?[]const u8) !bool {
    return sendKittyPasteEvent5522WithMime(self, clip, html, null);
}

pub fn sendKittyPasteEvent5522WithMime(self: anytype, clip: []const u8, html: ?[]const u8, uri_list: ?[]const u8) !bool {
    return sendKittyPasteEvent5522WithMimeRich(self, clip, html, uri_list, null);
}

pub fn sendKittyPasteEvent5522WithMimeRich(
    self: anytype,
    clip: []const u8,
    html: ?[]const u8,
    uri_list: ?[]const u8,
    png: ?[]const u8,
) !bool {
    const log = app_logger.logger("terminal.osc");
    if (!self.kitty_paste_events_5522) {
        log.logf(.debug, "osc5522 paste skipped reason=disabled", .{});
        return false;
    }
    if (!terminal_transport.Writer.exists(self)) {
        log.logf(.warning, "osc5522 paste dropped reason=missing-pty", .{});
        return false;
    }

    self.core.kitty_osc5522_clipboard_text.clearRetainingCapacity();
    try self.core.kitty_osc5522_clipboard_text.ensureTotalCapacity(self.allocator, clip.len);
    try self.core.kitty_osc5522_clipboard_text.appendSlice(self.allocator, clip);
    self.core.kitty_osc5522_clipboard_html.clearRetainingCapacity();
    if (html) |html_bytes| {
        try self.core.kitty_osc5522_clipboard_html.ensureTotalCapacity(self.allocator, html_bytes.len);
        try self.core.kitty_osc5522_clipboard_html.appendSlice(self.allocator, html_bytes);
    }
    self.core.kitty_osc5522_clipboard_uri_list.clearRetainingCapacity();
    if (uri_list) |uri_bytes| {
        try self.core.kitty_osc5522_clipboard_uri_list.ensureTotalCapacity(self.allocator, uri_bytes.len);
        try self.core.kitty_osc5522_clipboard_uri_list.appendSlice(self.allocator, uri_bytes);
    }
    self.core.kitty_osc5522_clipboard_png.clearRetainingCapacity();
    if (png) |png_bytes| {
        try self.core.kitty_osc5522_clipboard_png.ensureTotalCapacity(self.allocator, png_bytes.len);
        try self.core.kitty_osc5522_clipboard_png.appendSlice(self.allocator, png_bytes);
    }

    if (self.lockPtyWriter()) |writer_guard| {
        var writer = writer_guard;
        defer writer.unlock();
        osc_kitty_clipboard.sendPasteEventMimes(osc_kitty_clipboard.SessionFacade.from(self), &writer, .st);
        return true;
    }
    log.logf(.warning, "osc5522 paste dropped after buffer prep reason=missing-pty", .{});
    return false;
}

pub fn mouseReportingEnabled(self: anytype) bool {
    const input_snapshot = self.input_snapshot;
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
    return self.activeScreenConst().getDamage();
}

pub fn keyModeFlagsValue(self: anytype) u32 {
    return self.input_snapshot.key_mode_flags.load(.acquire);
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
