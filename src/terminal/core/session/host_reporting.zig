const std = @import("std");
const app_logger = @import("../../../app_logger.zig");
const osc_kitty_clipboard = @import("../../protocol/osc_kitty_clipboard.zig");
const terminal_transport = @import("../runtime/terminal_transport.zig");
const csi_mod = @import("../../protocol/csi.zig");

pub const ReportingSnapshot = struct {
    report_color_scheme_2031: bool,
    inband_resize_notifications_2048: bool,
    kitty_paste_events_5522: bool,
};

pub fn reportingSnapshot(self: anytype) ReportingSnapshot {
    return .{
        .report_color_scheme_2031 = self.session.interaction.host_contract.report_color_scheme_2031,
        .inband_resize_notifications_2048 = self.session.interaction.host_contract.inband_resize_notifications_2048,
        .kitty_paste_events_5522 = self.session.interaction.host_contract.kitty_paste_events_5522,
    };
}

pub fn applyCsiReportingMode(self: anytype, mode: i32, enabled: bool) bool {
    switch (mode) {
        2031 => self.session.interaction.host_contract.report_color_scheme_2031 = enabled,
        2048 => self.session.interaction.host_contract.inband_resize_notifications_2048 = enabled,
        5522 => self.session.interaction.host_contract.kitty_paste_events_5522 = enabled,
        else => return false,
    }
    return true;
}

pub fn decrqmReportingModeState(snapshot: ReportingSnapshot, mode: i32) ?csi_mod.DecrpmState {
    return switch (mode) {
        2031 => boolModeState(snapshot.report_color_scheme_2031),
        2048 => boolModeState(snapshot.inband_resize_notifications_2048),
        5522 => boolModeState(snapshot.kitty_paste_events_5522),
        else => null,
    };
}

pub fn reportInBandResize2048(self: anytype, rows: u16, cols: u16) !void {
    if (!self.session.interaction.host_contract.inband_resize_notifications_2048) return;
    if (self.lockPtyWriter()) |writer_guard| {
        var writer = writer_guard;
        const rows_px: u32 = @as(u32, rows) * @as(u32, self.session.interaction.host_contract.cell_height);
        const cols_px: u32 = @as(u32, cols) * @as(u32, self.session.interaction.host_contract.cell_width);
        var buf: [64]u8 = undefined;
        const seq = try std.fmt.bufPrint(
            &buf,
            "\x1b[48;{d};{d};{d};{d}t",
            .{ rows, cols, rows_px, cols_px },
        );
        defer writer.unlock();
        _ = try writer.write(seq);
    }
}

pub fn reportColorSchemeChanged(self: anytype, dark: bool) !bool {
    self.session.interaction.host_contract.color_scheme_dark = dark;
    if (!self.session.interaction.host_contract.report_color_scheme_2031) {
        return false;
    }
    if (self.lockPtyWriter()) |writer_guard| {
        var writer = writer_guard;
        var buf: [16]u8 = undefined;
        const seq = try std.fmt.bufPrint(&buf, "\x1b[?997;{d}n", .{if (dark) @as(u8, 1) else @as(u8, 2)});
        defer writer.unlock();
        _ = try writer.write(seq);
        return true;
    }
    std.log.warn("color-scheme report dropped dark={} reason=missing-pty", .{@intFromBool(dark)});
    return false;
}

pub fn kittyPasteEvents5522Enabled(self: anytype) bool {
    return self.session.interaction.host_contract.kitty_paste_events_5522;
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
    if (!self.session.interaction.host_contract.kitty_paste_events_5522) {
        return false;
    }
    if (!terminal_transport.Writer.exists(self)) {
        app_logger.logger("terminal.osc").logf(.warning, "osc5522 paste dropped reason=missing-pty", .{});
        return false;
    }

    try self.core.setKittyOsc5522Clipboard(self.allocator, clip, html, uri_list, png);

    if (self.lockPtyWriter()) |writer_guard| {
        var writer = writer_guard;
        defer writer.unlock();
        osc_kitty_clipboard.sendPasteEventMimes(self, &writer, .st);
        return true;
    }
    app_logger.logger("terminal.osc").logf(.warning, "osc5522 paste dropped after buffer prep reason=missing-pty", .{});
    return false;
}

fn boolModeState(enabled: bool) csi_mod.DecrpmState {
    return if (enabled) .set else .reset;
}
