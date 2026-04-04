const app_logger = @import("../../../app_logger.zig");

pub fn emitBytes(self: anytype, log_scope: []const u8, bytes: []const u8) bool {
    self.writePtyBytes(bytes) catch |err| {
        app_logger.logger(log_scope).logf(.warning, "protocol reply sink write failed len={d} err={s}", .{ bytes.len, @errorName(err) });
        return false;
    };
    return true;
}
