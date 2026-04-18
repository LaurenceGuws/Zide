//! Resolve a mutable `*TerminalCore` from scroll/kitty `anytype` faces (`*TerminalCore`,
//! `*TerminalRuntimeShell`, or protocol wrappers with a `.core` field).
const terminal_core_mod = @import("terminal_core.zig");

pub const TerminalCore = terminal_core_mod.TerminalCore;

pub fn mutableTerminalCore(self: anytype) *TerminalCore {
    if (@hasField(@TypeOf(self.*), "active") and @hasField(@TypeOf(self.*), "history")) {
        return @constCast(@as(*const TerminalCore, self));
    }
    // Protocol faces store `core: *TerminalCore`; the runtime shell embeds `core` by value.
    // Never bind `self.core` into a local `TerminalCore` value — that would point at a stack copy.
    const core_addr = switch (@typeInfo(@TypeOf(self.core))) {
        .pointer => self.core,
        else => &self.core,
    };
    return @constCast(@as(*const TerminalCore, core_addr));
}
