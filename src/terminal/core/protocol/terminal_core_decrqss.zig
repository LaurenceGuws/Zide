const std = @import("std");
const app_logger = @import("../../../app_logger.zig");

pub fn replyInto(self: anytype, text: []const u8, buf: []u8) ?[]const u8 {
    const log = app_logger.logger("terminal.apc");
    if (std.mem.eql(u8, text, " q")) {
        return self.core.decrqssCursorStyleReplyText();
    }
    if (std.mem.eql(u8, text, "m")) {
        return self.core.sgrReplyInto(buf);
    }
    if (std.mem.eql(u8, text, "r")) {
        const screen = self.core.activeScreen();
        return std.fmt.bufPrint(buf, "{d};{d}r", .{
            screen.scroll_top + 1,
            screen.scroll_bottom + 1,
        }) catch |err| {
            log.logf(.warning, "decrqss r reply format failed err={s}", .{@errorName(err)});
            return null;
        };
    }
    if (std.mem.eql(u8, text, "s")) {
        const screen = self.core.activeScreen();
        return std.fmt.bufPrint(buf, "{d};{d}s", .{
            screen.left_margin + 1,
            screen.right_margin + 1,
        }) catch |err| {
            log.logf(.warning, "decrqss s reply format failed err={s}", .{@errorName(err)});
            return null;
        };
    }
    return null;
}
