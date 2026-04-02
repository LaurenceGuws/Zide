const std = @import("std");
const terminal_core_mod = @import("../terminal_core.zig");
const init_options = @import("init_options.zig");
const session_fields = @import("session_fields.zig");
const runtime = @import("runtime.zig");
const control = @import("control.zig");

const TerminalCoreType = terminal_core_mod.TerminalCore;

pub const TerminalSession = struct {
    pub const InitOptions = init_options.InitOptions;

    allocator: std.mem.Allocator,
    core: TerminalCoreType,
    session: session_fields.Fields,

    pub fn init(allocator: std.mem.Allocator, rows: u16, cols: u16) !*TerminalSession {
        return initWithOptions(allocator, rows, cols, .{});
    }

    pub fn initWithOptions(allocator: std.mem.Allocator, rows: u16, cols: u16, options: InitOptions) !*TerminalSession {
        return try runtime.init(TerminalSession, allocator, rows, cols, options);
    }

    pub const deinit = runtime.deinit;

    pub const lock = control.lock;
    pub const tryLock = control.tryLock;
    pub const unlock = control.unlock;

    pub const lockPtyWriter = runtime.lockPtyWriter;
    pub const writePtyBytes = runtime.writePtyBytes;
};
