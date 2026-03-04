const std = @import("std");
const builtin = @import("builtin");

var sigint_requested = std.atomic.Value(bool).init(false);

fn handleSigint(_: c_int) callconv(.c) void {
    sigint_requested.store(true, .release);
}

pub fn install() void {
    if (builtin.os.tag == .windows) {
        const win32 = struct {
            const BOOL = i32;
            const DWORD = u32;
            const TRUE: BOOL = 1;
            const FALSE: BOOL = 0;

            const CTRL_C_EVENT: DWORD = 0;
            const CTRL_BREAK_EVENT: DWORD = 1;
            const CTRL_CLOSE_EVENT: DWORD = 2;
            const CTRL_LOGOFF_EVENT: DWORD = 5;
            const CTRL_SHUTDOWN_EVENT: DWORD = 6;

            const HandlerRoutine = *const fn (dwCtrlType: DWORD) callconv(.winapi) BOOL;

            extern "kernel32" fn SetConsoleCtrlHandler(HandlerRoutine: ?HandlerRoutine, Add: BOOL) callconv(.winapi) BOOL;
        };

        const handler = struct {
            fn call(ctrl_type: win32.DWORD) callconv(.winapi) win32.BOOL {
                switch (ctrl_type) {
                    win32.CTRL_C_EVENT,
                    win32.CTRL_BREAK_EVENT,
                    win32.CTRL_CLOSE_EVENT,
                    win32.CTRL_LOGOFF_EVENT,
                    win32.CTRL_SHUTDOWN_EVENT,
                    => {
                        sigint_requested.store(true, .release);
                        return win32.TRUE;
                    },
                    else => return win32.FALSE,
                }
            }
        }.call;

        _ = win32.SetConsoleCtrlHandler(handler, win32.TRUE);
        return;
    }
    const act = std.posix.Sigaction{
        .handler = .{ .handler = handleSigint },
        .mask = std.posix.sigemptyset(),
        .flags = 0,
    };
    std.posix.sigaction(std.posix.SIG.INT, &act, null);
}

pub fn requested() bool {
    return sigint_requested.load(.acquire);
}

