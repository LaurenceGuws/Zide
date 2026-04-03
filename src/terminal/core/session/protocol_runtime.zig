const host_reporting = @import("host_reporting.zig");
const protocol_reply_sink = @import("protocol_reply_sink.zig");

pub const CsiReplyRuntimeSnapshot = struct {
    cell_height: u16,
    cell_width: u16,
    color_scheme_dark: bool,
};

pub fn emitReplyBytes(self: anytype, log_scope: []const u8, bytes: []const u8) bool {
    return protocol_reply_sink.emitBytes(self, log_scope, bytes);
}

pub fn csiReplyRuntimeSnapshot(self: anytype) CsiReplyRuntimeSnapshot {
    return .{
        .cell_height = self.session.interaction.host_contract.cell_height,
        .cell_width = self.session.interaction.host_contract.cell_width,
        .color_scheme_dark = self.session.interaction.host_contract.color_scheme_dark,
    };
}

pub fn reportingSnapshot(self: anytype) host_reporting.ReportingSnapshot {
    return host_reporting.reportingSnapshot(self);
}

pub fn applyCsiReportingMode(self: anytype, mode: i32, enabled: bool) bool {
    return host_reporting.applyCsiReportingMode(self, mode, enabled);
}

pub fn resetCsiReportingModes(self: anytype) void {
    self.session.interaction.host_contract.report_color_scheme_2031 = false;
    self.session.interaction.host_contract.inband_resize_notifications_2048 = false;
    self.session.interaction.host_contract.kitty_paste_events_5522 = false;
}
