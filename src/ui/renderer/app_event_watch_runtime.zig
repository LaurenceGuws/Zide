const builtin = @import("builtin");
const native_host = @import("../../platform/native_host.zig");
const sdl_api = @import("../../platform/sdl_api.zig");

fn appEventWatchCallback(userdata: ?*anyopaque, event: [*c]sdl_api.c.SDL_Event) callconv(.c) bool {
    const raw = userdata orelse return true;
    const app_host: *native_host.PlatformAppHost = @ptrCast(@alignCast(raw));
    if (event == null) return true;
    const evt = event[0];
    switch (evt.type) {
        sdl_api.EVENT_APP_TERMINATING => app_host.noteTerminationRequested(),
        sdl_api.EVENT_APP_DID_ENTER_BACKGROUND => app_host.notePaused(),
        sdl_api.EVENT_APP_DID_ENTER_FOREGROUND => app_host.noteResumed(),
        else => {},
    }
    return true;
}

pub fn install(app_host: *native_host.PlatformAppHost) bool {
    if (builtin.target.os.tag != .macos) return false;
    return sdl_api.addEventWatch(appEventWatchCallback, app_host);
}

pub fn remove(app_host: *native_host.PlatformAppHost) void {
    if (builtin.target.os.tag != .macos) return;
    sdl_api.removeEventWatch(appEventWatchCallback, app_host);
}
