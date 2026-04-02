const app_logger = @import("../../../app_logger.zig");
const terminal_transport = @import("../runtime/terminal_transport.zig");

pub fn reportExternalChildExit(self: anytype, code: ?i32) bool {
    if (self.session.runtime.external_transport == null) return false;
    if (code) |value| {
        self.session.runtime.child_exit_code.store(value, .release);
        self.session.runtime.child_exited.store(true, .release);
    } else {
        self.session.runtime.child_exit_code.store(-1, .release);
        self.session.runtime.child_exited.store(false, .release);
    }
    return true;
}

pub fn refreshChildExit(self: anytype) void {
    maybeUpdateChildExit(self);
}

pub fn childExitCode(self: anytype) ?i32 {
    return if (self.session.runtime.child_exited.load(.acquire))
        self.session.runtime.child_exit_code.load(.acquire)
    else
        null;
}

pub fn maybeUpdateChildExit(self: anytype) void {
    if (self.session.runtime.child_exited.load(.acquire)) return;
    if (terminal_transport.Transport.fromSession(self)) |transport| {
        if (transport.pollExit() catch |err| blk: {
            const log = app_logger.logger("terminal.session.runtime.pty");
            log.logf(.warning, "pty pollExit failed err={s}", .{@errorName(err)});
            break :blk null;
        }) |code| {
            self.session.runtime.child_exit_code.store(code, .release);
            self.session.runtime.child_exited.store(true, .release);
        }
    }
}
