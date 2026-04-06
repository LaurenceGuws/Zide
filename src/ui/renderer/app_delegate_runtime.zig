const native_host = @import("../../platform/native_host.zig");
const macos_app_delegate = @import("../../platform/macos_app_delegate.zig");

pub const Installation = macos_app_delegate.Installation;

pub fn install(app_host: *native_host.PlatformAppHost) ?Installation {
    return macos_app_delegate.install(app_host);
}

pub fn uninstall(installation: *Installation) void {
    macos_app_delegate.uninstall(installation);
}
