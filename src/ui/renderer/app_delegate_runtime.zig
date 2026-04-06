const builtin = @import("builtin");
const native_host = @import("../../platform/native_host.zig");

pub const Installation = if (builtin.target.os.tag == .macos)
    @import("../../platform/macos_app_delegate.zig").Installation
else
    struct {};

pub fn install(app_host: *native_host.PlatformAppHost) ?Installation {
    if (builtin.target.os.tag == .macos) {
        const macos_app_delegate = @import("../../platform/macos_app_delegate.zig");
        return macos_app_delegate.install(app_host);
    }
    return null;
}

pub fn uninstall(installation: *Installation) void {
    if (builtin.target.os.tag == .macos) {
        const macos_app_delegate = @import("../../platform/macos_app_delegate.zig");
        macos_app_delegate.uninstall(installation);
    }
}
