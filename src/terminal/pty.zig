const builtin = @import("builtin");

pub const PtySize = struct {
    rows: u16,
    cols: u16,
    cell_width: u16,
    cell_height: u16,
};

pub const Pty = switch (builtin.os.tag) {
    .linux, .macos => @import("pty_unix.zig").Pty,
    .windows => @import("pty_windows.zig").Pty,
    else => @import("pty_stub.zig").Pty,
};
