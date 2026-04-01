const app_logger = @import("../../app_logger.zig");
const terminal_transport = @import("terminal_transport.zig");

pub fn reportExternalChildExit(self: anytype, code: ?i32) bool {
    if (self.runtime.external_transport == null) return false;
    if (code) |value| {
        self.runtime.child_exit_code.store(value, .release);
        self.runtime.child_exited.store(true, .release);
    } else {
        self.runtime.child_exit_code.store(-1, .release);
        self.runtime.child_exited.store(false, .release);
    }
    return true;
}

pub fn refreshChildExit(self: anytype) void {
    maybeUpdateChildExit(self);
}

pub fn childExitCode(self: anytype) ?i32 {
    return if (self.runtime.child_exited.load(.acquire))
        self.runtime.child_exit_code.load(.acquire)
    else
        null;
}

pub fn maybeUpdateChildExit(self: anytype) void {
    if (self.runtime.child_exited.load(.acquire)) return;
    if (terminal_transport.Transport.fromSession(self)) |transport| {
        if (transport.pollExit() catch |err| blk: {
            const log = app_logger.logger("terminal.runtime.pty");
            log.logf(.warning, "pty pollExit failed err={s}", .{@errorName(err)});
            break :blk null;
        }) |code| {
            self.runtime.child_exit_code.store(code, .release);
            self.runtime.child_exited.store(true, .release);
        }
    }
}
