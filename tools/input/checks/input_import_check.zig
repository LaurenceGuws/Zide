const app_import_check = @import("app_import_check.zig");

pub fn main() !void {
    try app_import_check.main();
}
