const std = @import("std");
const terminal_transport = @import("../runtime/terminal_transport.zig");
const pty_mod = @import("../../io/pty.zig");

pub const Fields = struct {
    pty: ?pty_mod.Pty,
    external_transport: ?terminal_transport.ExternalTransport,
    pty_write_mutex: std.Thread.Mutex,
    read_thread: ?std.Thread,
    read_thread_running: std.atomic.Value(bool),
    parse_thread: ?std.Thread,
    parse_thread_running: std.atomic.Value(bool),
    io_mutex: std.Thread.Mutex,
    io_wait_cond: std.Thread.Condition,
    io_buffer: std.ArrayList(u8),
    io_read_offset: usize,
    child_exited: std.atomic.Value(bool),
    child_exit_code: std.atomic.Value(i32),
    launch_shell_path: ?[]u8,
    tearing_down: bool,
};
