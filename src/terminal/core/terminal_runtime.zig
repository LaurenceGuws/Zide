const std = @import("std");
const shell_mod = @import("session/terminal_runtime_shell.zig");

pub const TerminalCore = @import("terminal_core.zig").TerminalCore;
pub const TerminalRuntimeShell = shell_mod.TerminalRuntimeShell;
pub const InitOptions = shell_mod.TerminalRuntimeShell.InitOptions;

pub fn init(allocator: std.mem.Allocator, rows: u16, cols: u16) !*TerminalRuntimeShell {
    return initWithOptions(allocator, rows, cols, .{});
}

pub fn initWithOptions(
    allocator: std.mem.Allocator,
    rows: u16,
    cols: u16,
    options: InitOptions,
) !*TerminalRuntimeShell {
    return try @import("session/runtime.zig").init(TerminalRuntimeShell, allocator, rows, cols, options);
}
