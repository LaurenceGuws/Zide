const builtin = @import("builtin");

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

pub const RenderSurfaceAvailability = enum {
    unavailable,
    available,
};

pub const SurfaceIdentityTransition = enum {
    unchanged,
    acquired,
    replaced,
    retired,
};

pub const RenderSurfaceMetrics = struct {
    logical_width: i32 = 0,
    logical_height: i32 = 0,
    drawable_width: i32 = 0,
    drawable_height: i32 = 0,
    display_scale: f32 = 0.0,
    pixel_density: f32 = 0.0,
};

pub const NativeViewHandles = struct {
    cocoa_window: ?*anyopaque = null,
    cocoa_view: ?*anyopaque = null,
    win32_hwnd: ?*anyopaque = null,
    android_native_window: ?*anyopaque = null,
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
    active: bool = false,
    surface_focused: bool = false,
    text_input_active: bool = false,
    pending_intent: ?ExternalIntent = null,

    pub fn noteStarted(self: *PlatformAppHost) void {
        self.lifecycle_state = .started;
    }

    pub fn noteResumed(self: *PlatformAppHost) void {
        self.lifecycle_state = .resumed;
        self.active = true;
        self.pending_intent = .activation_requested;
    }

    pub fn notePaused(self: *PlatformAppHost) void {
        self.lifecycle_state = .paused;
        self.active = false;
        self.surface_focused = false;
        self.text_input_active = false;
    }

    pub fn noteStopped(self: *PlatformAppHost) void {
        self.lifecycle_state = .stopped;
        self.active = false;
        self.surface_focused = false;
        self.text_input_active = false;
    }

    pub fn noteTerminationRequested(self: *PlatformAppHost) void {
        self.lifecycle_state = .terminating;
        self.active = false;
        self.pending_intent = .quit_requested;
    }

    pub fn noteSurfaceFocused(self: *PlatformAppHost, focused: bool) void {
        self.surface_focused = focused;
        if (!focused) self.text_input_active = false;
    }

    pub fn noteTextInputActive(self: *PlatformAppHost, active: bool) void {
        self.text_input_active = active;
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
    binding: RenderSurfaceBinding,
    surface_availability: RenderSurfaceAvailability,
    surface_metrics: RenderSurfaceMetrics,
    surface_identity_epoch: u64 = 0,
    redraw_requested: bool = false,
    native_handles: NativeViewHandles,

    fn advanceSurfaceIdentityEpoch(self: *PlatformRenderHost) void {
        self.surface_identity_epoch +%= 1;
        if (self.surface_identity_epoch == 0) self.surface_identity_epoch = 1;
    }

    pub fn hasSurface(self: PlatformRenderHost) bool {
        return self.surface_availability == .available;
    }

    pub fn noteSurfaceAvailable(self: *PlatformRenderHost, metrics: RenderSurfaceMetrics) void {
        self.surface_availability = .available;
        self.surface_metrics = metrics;
    }

    pub fn noteSurfaceUnavailable(self: *PlatformRenderHost) void {
        self.surface_availability = .unavailable;
        self.surface_metrics = .{};
        self.redraw_requested = false;
        self.native_handles.android_native_window = null;
    }

    pub fn noteRedrawRequested(self: *PlatformRenderHost) void {
        self.redraw_requested = true;
    }

    pub fn clearRedrawRequested(self: *PlatformRenderHost) void {
        self.redraw_requested = false;
    }

    pub fn cocoaWindow(self: PlatformRenderHost) ?*anyopaque {
        return self.native_handles.cocoa_window;
    }

    pub fn cocoaView(self: PlatformRenderHost) ?*anyopaque {
        return self.native_handles.cocoa_view;
    }

    pub fn win32Hwnd(self: PlatformRenderHost) ?*anyopaque {
        return self.native_handles.win32_hwnd;
    }

    pub fn androidNativeWindow(self: PlatformRenderHost) ?*anyopaque {
        return self.native_handles.android_native_window;
    }

    pub fn surfaceIdentityEpoch(self: PlatformRenderHost) u64 {
        return self.surface_identity_epoch;
    }

    pub fn noteAndroidNativeWindow(
        self: *PlatformRenderHost,
        native_window: ?*anyopaque,
    ) SurfaceIdentityTransition {
        const prior_window = self.native_handles.android_native_window;
        const transition: SurfaceIdentityTransition = if (prior_window == native_window)
            .unchanged
        else if (prior_window == null and native_window != null)
            .acquired
        else if (prior_window != null and native_window == null)
            .retired
        else
            .replaced;

        if (transition != .unchanged) {
            self.advanceSurfaceIdentityEpoch();
        }
        self.native_handles.android_native_window = native_window;
        if (native_window == null) {
            self.surface_availability = .unavailable;
        }
        return transition;
    }
};

pub fn currentAppHost() PlatformAppHost {
    const kind: AppHostKind = if (builtin.target.os.tag == .linux and builtin.target.abi == .android)
        .android_activity
    else switch (builtin.target.os.tag) {
        .macos => .appkit,
        .windows => .windows_desktop,
        else => .sdl_desktop,
    };
    return .{
        .kind = kind,
        .lifecycle_state = .started,
    };
}

test "render host surface transitions clear redraw and native window on loss" {
    const std = @import("std");
    var host = PlatformRenderHost{
        .binding = .none,
        .surface_availability = .available,
        .surface_metrics = .{
            .logical_width = 100,
            .logical_height = 60,
            .drawable_width = 200,
            .drawable_height = 120,
            .display_scale = 2.0,
            .pixel_density = 2.0,
        },
        .redraw_requested = true,
        .native_handles = .{
            .android_native_window = @ptrFromInt(2),
        },
    };

    host.noteSurfaceUnavailable();

    try std.testing.expectEqual(RenderSurfaceAvailability.unavailable, host.surface_availability);
    try std.testing.expectEqual(@as(i32, 0), host.surface_metrics.logical_width);
    try std.testing.expectEqual(@as(i32, 0), host.surface_metrics.drawable_width);
    try std.testing.expect(!host.redraw_requested);
    try std.testing.expectEqual(@as(?*anyopaque, null), host.androidNativeWindow());
}

test "render host redraw and android window state can be re-armed after surface return" {
    const std = @import("std");
    var host = PlatformRenderHost{
        .binding = .opengl,
        .surface_availability = .unavailable,
        .surface_metrics = .{},
        .native_handles = .{},
    };

    try std.testing.expectEqual(SurfaceIdentityTransition.acquired, host.noteAndroidNativeWindow(@ptrFromInt(3)));
    host.noteSurfaceAvailable(.{
        .logical_width = 360,
        .logical_height = 760,
        .drawable_width = 1080,
        .drawable_height = 2280,
        .display_scale = 3.0,
        .pixel_density = 3.0,
    });
    host.noteRedrawRequested();

    try std.testing.expect(host.hasSurface());
    try std.testing.expectEqual(@as(?*anyopaque, @ptrFromInt(3)), host.androidNativeWindow());
    try std.testing.expectEqual(@as(u64, 1), host.surfaceIdentityEpoch());
    try std.testing.expectEqual(@as(i32, 1080), host.surface_metrics.drawable_width);
    try std.testing.expect(host.redraw_requested);

    host.clearRedrawRequested();
    try std.testing.expect(!host.redraw_requested);
}

test "android surface identity epoch advances only when the native window changes" {
    const std = @import("std");
    var host = PlatformRenderHost{
        .binding = .none,
        .surface_availability = .unavailable,
        .surface_metrics = .{},
        .native_handles = .{},
    };

    try std.testing.expectEqual(@as(u64, 0), host.surfaceIdentityEpoch());

    try std.testing.expectEqual(SurfaceIdentityTransition.acquired, host.noteAndroidNativeWindow(@ptrFromInt(3)));
    try std.testing.expectEqual(@as(u64, 1), host.surfaceIdentityEpoch());

    try std.testing.expectEqual(SurfaceIdentityTransition.unchanged, host.noteAndroidNativeWindow(@ptrFromInt(3)));
    try std.testing.expectEqual(@as(u64, 1), host.surfaceIdentityEpoch());

    try std.testing.expectEqual(SurfaceIdentityTransition.replaced, host.noteAndroidNativeWindow(@ptrFromInt(4)));
    try std.testing.expectEqual(@as(u64, 2), host.surfaceIdentityEpoch());

    try std.testing.expectEqual(SurfaceIdentityTransition.retired, host.noteAndroidNativeWindow(null));
    try std.testing.expectEqual(@as(u64, 3), host.surfaceIdentityEpoch());
}

test "app host keeps lifecycle separate from focus and text input" {
    const std = @import("std");
    var app_host = PlatformAppHost{
        .kind = .android_activity,
        .lifecycle_state = .started,
    };

    app_host.noteResumed();
    app_host.noteSurfaceFocused(true);
    app_host.noteTextInputActive(true);
    try std.testing.expect(app_host.active);
    try std.testing.expect(app_host.surface_focused);
    try std.testing.expect(app_host.text_input_active);

    app_host.notePaused();
    try std.testing.expectEqual(AppLifecycleState.paused, app_host.lifecycle_state);
    try std.testing.expect(!app_host.active);
    try std.testing.expect(!app_host.surface_focused);
    try std.testing.expect(!app_host.text_input_active);

    app_host.noteStarted();
    try std.testing.expectEqual(AppLifecycleState.started, app_host.lifecycle_state);
    try std.testing.expect(!app_host.active);

    app_host.noteStopped();
    try std.testing.expectEqual(AppLifecycleState.stopped, app_host.lifecycle_state);
}
