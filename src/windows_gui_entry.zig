const builtin = @import("builtin");
const root = @import("root");
const std = @import("std");

comptime {
    if (builtin.os.tag == .windows and !builtin.is_test) {
        @export(&WinMainShim, .{ .name = "WinMain" });
    }
}

fn runRootMain() callconv(.c) c_int {
    root.main() catch {
        return 1;
    };
    return 0;
}

fn WinMainShim(
    h_instance: ?*anyopaque,
    prev_instance: ?*anyopaque,
    cmd_line: ?[*:0]u8,
    show_cmd: i32,
) callconv(.winapi) c_int {
    _ = h_instance;
    _ = prev_instance;
    _ = cmd_line;
    _ = show_cmd;
    return runRootMain();
}
