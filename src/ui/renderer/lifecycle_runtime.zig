const app_delegate_runtime = @import("app_delegate_runtime.zig");
const app_event_watch_runtime = @import("app_event_watch_runtime.zig");

pub const Installation = app_delegate_runtime.Installation;

pub fn installAppHooks(app_host: anytype) struct {
    appkit_delegate_installation: ?Installation,
    app_event_watch_installed: bool,
} {
    return .{
        .appkit_delegate_installation = app_delegate_runtime.install(app_host),
        .app_event_watch_installed = app_event_watch_runtime.install(app_host),
    };
}

pub fn uninstallAppHooks(app_host: anytype, appkit_delegate_installation: ?Installation, app_event_watch_installed: bool) void {
    if (appkit_delegate_installation) |installation| {
        var mutable_installation = installation;
        app_delegate_runtime.uninstall(&mutable_installation);
    }
    if (app_event_watch_installed) app_event_watch_runtime.remove(app_host);
}
