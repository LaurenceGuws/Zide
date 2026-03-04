const std = @import("std");
const shared = @import("../shared/mod.zig");

pub const IdeHost = struct {
    allocator: std.mem.Allocator,
    editor: shared.contracts.ModeContract,
    terminal: shared.contracts.ModeContract,

    pub fn init(
        allocator: std.mem.Allocator,
        editor: shared.contracts.ModeContract,
        terminal: shared.contracts.ModeContract,
    ) IdeHost {
        return .{
            .allocator = allocator,
            .editor = editor,
            .terminal = terminal,
        };
    }

    pub fn deinit(self: *IdeHost) void {
        self.editor.deinit(self.allocator);
        self.terminal.deinit(self.allocator);
    }
};

