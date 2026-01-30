const std = @import("std");

pub const MetalBackend = struct {
    pub fn init() !void {
        return error.BackendNotImplemented;
    }
};
