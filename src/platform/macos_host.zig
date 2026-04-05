const builtin = @import("builtin");
const native_host = @import("native_host.zig");

pub const TerminateDisposition = enum {
    now,
    forward_to_previous_delegate,
};

pub const MetalAttachmentTarget = struct {
    cocoa_window: *anyopaque,
    cocoa_view: ?*anyopaque,
};

pub fn available() bool {
    return builtin.target.os.tag == .macos;
}

pub fn usesAppKitHost(app_host: native_host.PlatformAppHost) bool {
    return app_host.kind == .appkit;
}

pub fn requestActivation(app_host: *native_host.PlatformAppHost) void {
    app_host.noteResumed();
}

pub fn noteDidBecomeActive(app_host: *native_host.PlatformAppHost) bool {
    if (!available()) return false;
    app_host.noteResumed();
    return true;
}

pub fn noteDidResignActive(app_host: *native_host.PlatformAppHost) bool {
    if (!available()) return false;
    app_host.notePaused();
    return true;
}

pub fn requestQuit(app_host: *native_host.PlatformAppHost) void {
    app_host.noteTerminationRequested();
}

pub fn noteShouldTerminate(app_host: *native_host.PlatformAppHost) TerminateDisposition {
    if (!available()) return .forward_to_previous_delegate;
    app_host.noteTerminationRequested();
    return .now;
}

pub fn noteWillTerminate(app_host: *native_host.PlatformAppHost) bool {
    if (!available()) return false;
    app_host.noteTerminationRequested();
    return true;
}

pub fn requestOpenFile(app_host: *native_host.PlatformAppHost, path: []const u8) bool {
    return app_host.noteOpenFileRequested(path);
}

pub fn noteOpenFile(app_host: *native_host.PlatformAppHost, path: []const u8) bool {
    if (!available()) return false;
    return app_host.noteOpenFileRequested(path);
}

pub fn takePendingIntent(app_host: *native_host.PlatformAppHost) ?native_host.ExternalIntent {
    return app_host.takePendingIntent();
}

pub fn canAttachMetal(render_host: native_host.PlatformRenderHost) bool {
    if (!available()) return false;
    return render_host.cocoaWindow() != null;
}

pub fn metalAttachmentTarget(
    render_host: native_host.PlatformRenderHost,
) ?MetalAttachmentTarget {
    if (!canAttachMetal(render_host)) return null;
    return .{
        .cocoa_window = render_host.cocoaWindow().?,
        .cocoa_view = render_host.cocoaView(),
    };
}
