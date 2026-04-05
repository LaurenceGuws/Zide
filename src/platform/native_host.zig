const builtin = @import("builtin");
const sdl_api = @import("sdl_api.zig");

pub const AppLifecycleState = enum {
    started,
    resumed,
    paused,
    stopped,
    terminating,
};

pub const AppHostKind = enum {
    sdl_desktop,
    appkit,
    android_activity,
    windows_desktop,
};

pub const RenderSurfaceBinding = enum {
    none,
    opengl,
    metal,
};

pub const NativeViewHandles = struct {
    cocoa_window: ?*anyopaque = null,
    cocoa_view: ?*anyopaque = null,
    win32_hwnd: ?*anyopaque = null,
};

pub const OpenFileIntent = struct {
    const max_path_bytes: usize = 1024;

    path_len: usize = 0,
    path_bytes: [max_path_bytes]u8 = [_]u8{0} ** max_path_bytes,

    pub fn path(self: *const OpenFileIntent) []const u8 {
        return self.path_bytes[0..self.path_len];
    }
};

pub const ExternalIntent = union(enum) {
    quit_requested,
    activation_requested,
    open_file_requested: OpenFileIntent,
};

pub const PlatformAppHost = struct {
    kind: AppHostKind,
    lifecycle_state: AppLifecycleState,
    pending_intent: ?ExternalIntent = null,

    pub fn noteResumed(self: *PlatformAppHost) void {
        self.lifecycle_state = .resumed;
        self.pending_intent = .activation_requested;
    }

    pub fn notePaused(self: *PlatformAppHost) void {
        self.lifecycle_state = .paused;
    }

    pub fn noteTerminationRequested(self: *PlatformAppHost) void {
        self.lifecycle_state = .terminating;
        self.pending_intent = .quit_requested;
    }

    pub fn noteOpenFileRequested(self: *PlatformAppHost, path: []const u8) bool {
        if (path.len > OpenFileIntent.max_path_bytes) return false;
        var intent: OpenFileIntent = .{};
        @memcpy(intent.path_bytes[0..path.len], path);
        intent.path_len = path.len;
        self.pending_intent = .{ .open_file_requested = intent };
        return true;
    }

    pub fn takePendingIntent(self: *PlatformAppHost) ?ExternalIntent {
        const intent = self.pending_intent orelse return null;
        self.pending_intent = null;
        return intent;
    }
};

pub const PlatformRenderHost = struct {
    sdl_window: *sdl_api.c.SDL_Window,
    binding: RenderSurfaceBinding,
    native_handles: NativeViewHandles,

    pub fn cocoaWindow(self: PlatformRenderHost) ?*anyopaque {
        return self.native_handles.cocoa_window;
    }

    pub fn cocoaView(self: PlatformRenderHost) ?*anyopaque {
        return self.native_handles.cocoa_view;
    }

    pub fn win32Hwnd(self: PlatformRenderHost) ?*anyopaque {
        return self.native_handles.win32_hwnd;
    }
};

pub fn currentAppHost() PlatformAppHost {
    return .{
        .kind = switch (builtin.target.os.tag) {
            .macos => .appkit,
            .windows => .windows_desktop,
            else => .sdl_desktop,
        },
        .lifecycle_state = .started,
    };
}

pub fn captureRenderHost(
    window: *sdl_api.c.SDL_Window,
    binding: RenderSurfaceBinding,
) PlatformRenderHost {
    return .{
        .sdl_window = window,
        .binding = binding,
        .native_handles = .{
            .cocoa_window = sdl_api.getWindowCocoaWindow(window),
            .cocoa_view = sdl_api.getWindowCocoaView(window),
            .win32_hwnd = sdl_api.getWindowWin32Hwnd(window),
        },
    };
}
