const app_entry_runtime = @import("app/app_entry_runtime.zig");

pub const AppMode = app_entry_runtime.AppMode;

pub fn main() !void {
    try app_entry_runtime.runMain();
}

test {
    _ = @import("main_tests.zig");
}
