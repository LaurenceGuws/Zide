const input_modes = @import("../core/input_modes.zig");
const sync_updates = @import("../core/protocol/sync_updates.zig");
const terminal_core_reset = @import("../core/protocol/terminal_core_reset.zig");
const protocol_runtime = @import("../core/session/protocol_runtime.zig");

pub fn applyDecstrReset(self: anytype) void {
    terminal_core_reset.applyDecstrTerminalReset(self);
    protocol_runtime.resetCsiReportingModes(self);
    input_modes.resetInputModesLocked(self);
    sync_updates.setLocked(self, false);
    input_modes.publishSnapshot(self);
}
