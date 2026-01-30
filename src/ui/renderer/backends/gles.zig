const std = @import("std");

pub const GlesBackend = struct {
    pub fn init() !void {
        return error.BackendNotImplemented;
    }
};
