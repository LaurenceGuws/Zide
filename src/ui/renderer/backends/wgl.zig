const std = @import("std");

pub const WglBackend = struct {
    pub fn init() !void {
        return error.BackendNotImplemented;
    }
};
