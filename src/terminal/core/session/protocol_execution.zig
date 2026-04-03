const std = @import("std");
const terminal_core_mod = @import("../terminal_core.zig");
const runtime_fields = @import("runtime_fields.zig");
const interaction_fields = @import("interaction_fields.zig");
const publication_fields = @import("publication_fields.zig");
const control_fields = @import("control_fields.zig");
const transport_runtime = @import("transport_runtime.zig");

const TerminalCore = terminal_core_mod.TerminalCore;

pub const SessionFaces = struct {
    runtime: *runtime_fields.Fields,
    interaction: *interaction_fields.Fields,
    publication: *publication_fields.Fields,
    control: *control_fields.Fields,
};

pub const ProtocolExecution = struct {
    allocator: std.mem.Allocator,
    core: *TerminalCore,
    session: SessionFaces,

    pub fn init(owner: anytype, core: *TerminalCore) ProtocolExecution {
        return .{
            .allocator = owner.allocator,
            .core = core,
            .session = .{
                .runtime = &owner.session.runtime,
                .interaction = &owner.session.interaction,
                .publication = &owner.session.publication,
                .control = &owner.session.control,
            },
        };
    }

    pub fn lock(self: *ProtocolExecution) void {
        self.session.control.state_mutex.lock();
    }

    pub fn unlock(self: *ProtocolExecution) void {
        self.session.control.state_mutex.unlock();
    }

    pub fn writePtyBytes(self: *ProtocolExecution, bytes: []const u8) !void {
        try transport_runtime.writePtyBytes(self, bytes);
    }
};
