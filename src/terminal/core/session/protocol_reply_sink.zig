const app_logger = @import("../../../app_logger.zig");
const transport_runtime = @import("transport_runtime.zig");

pub fn emitBytes(self: anytype, log_scope: []const u8, bytes: []const u8) bool {
    transport_runtime.writePtyBytes(self, bytes) catch |err| {
        app_logger.logger(log_scope).logf(.warning, "protocol reply sink write failed len={d} err={s}", .{ bytes.len, @errorName(err) });
        return false;
    };
    return true;
}
