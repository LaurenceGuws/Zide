pub fn set(self: anytype, shell_path: ?[]const u8) !void {
    if (self.runtime.launch_shell_path) |old| {
        self.allocator.free(old);
        self.runtime.launch_shell_path = null;
    }
    if (shell_path) |path| {
        self.runtime.launch_shell_path = try self.allocator.dupe(u8, path);
    }
}

pub fn get(self: anytype) []const u8 {
    return self.runtime.launch_shell_path orelse "";
}
