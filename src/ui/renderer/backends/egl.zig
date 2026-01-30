const std = @import("std");

pub const EglBackend = struct {
    pub fn init() !void {
        return error.BackendNotImplemented;
    }
};
