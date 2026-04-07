const app_delegate_runtime = @import("app_delegate_runtime.zig");
const app_event_watch_runtime = @import("app_event_watch_runtime.zig");
const renderer_global_runtime = @import("renderer_global_runtime.zig");

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

pub fn finalizeRendererInit(comptime RendererType: type, renderer: *RendererType) !void {
    const app_hooks = installAppHooks(&renderer.app_host);
    renderer.appkit_delegate_installation = app_hooks.appkit_delegate_installation;
    renderer.app_event_watch_installed = app_hooks.app_event_watch_installed;

    renderer.backend.ops.runtime.configureRuntimePolicy(renderer);
    try renderer.backend.ops.runtime.initRuntime(renderer);

    renderer_global_runtime.registerRenderer(RendererType, renderer);
}

pub fn beginRendererShutdown(comptime RendererType: type, renderer: *RendererType) void {
    renderer_global_runtime.unregisterRenderer(RendererType, renderer);
    uninstallAppHooks(&renderer.app_host, renderer.appkit_delegate_installation, renderer.app_event_watch_installed);
}
