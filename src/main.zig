const app_entry_runtime = @import("app/app_entry_runtime.zig");
const _windows_gui_entry = @import("windows_gui_entry.zig");
comptime {
    _ = _windows_gui_entry;
}

pub const AppMode = app_entry_runtime.AppMode;
pub const zide_app_identity_name: [*:0]const u8 = "Zide";
pub const zide_app_identity_id: [*:0]const u8 = "LaurenceGuws.Zide";

pub fn main() !void {
    try app_entry_runtime.runMain();
}
