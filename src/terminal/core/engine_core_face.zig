//! Resolve a mutable `*TerminalCore` from scroll/kitty `anytype` faces.
//! Only these owner shapes are supported; add an explicit branch when a new
//! wrapper must participate (no structural duck-typing on `.core`).
const terminal_core_mod = @import("terminal_core.zig");
const protocol_execution_mod = @import("session/protocol_execution.zig");
const terminal_runtime_shell_mod = @import("session/terminal_runtime_shell.zig");

pub const TerminalCore = terminal_core_mod.TerminalCore;

const ProtocolExecution = protocol_execution_mod.ProtocolExecution;
const TerminalRuntimeShell = terminal_runtime_shell_mod.TerminalRuntimeShell;

pub fn mutableTerminalCore(self: anytype) *TerminalCore {
    const T = @TypeOf(self);
    return switch (T) {
        *TerminalCore => self,
        *const TerminalCore => @constCast(self),
        *TerminalRuntimeShell => &self.core,
        *ProtocolExecution => self.core,
        else => @compileError("mutableTerminalCore: unsupported owner type " ++ @typeName(T)),
    };
}
