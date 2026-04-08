const android_runtime_bridge = @import("platform/android_runtime_bridge.zig");

export fn Java_dev_zide_androidbootstrap_ZideBootstrapActivity_nativeOnCreateBridge(
    _: ?*anyopaque,
    _: ?*anyopaque,
) callconv(.c) i64 {
    return @intCast(android_runtime_bridge.noteCreate());
}

export fn Java_dev_zide_androidbootstrap_ZideBootstrapActivity_nativeOnStartBridge(
    _: ?*anyopaque,
    _: ?*anyopaque,
) callconv(.c) i64 {
    return @intCast(android_runtime_bridge.noteStart());
}

export fn Java_dev_zide_androidbootstrap_ZideBootstrapActivity_nativeOnResumeBridge(
    _: ?*anyopaque,
    _: ?*anyopaque,
) callconv(.c) i64 {
    return @intCast(android_runtime_bridge.noteResume());
}

export fn Java_dev_zide_androidbootstrap_ZideBootstrapActivity_nativeOnPauseBridge(
    _: ?*anyopaque,
    _: ?*anyopaque,
) callconv(.c) i64 {
    return @intCast(android_runtime_bridge.notePause());
}

export fn Java_dev_zide_androidbootstrap_ZideBootstrapActivity_nativeOnStopBridge(
    _: ?*anyopaque,
    _: ?*anyopaque,
) callconv(.c) i64 {
    return @intCast(android_runtime_bridge.noteStop());
}

export fn Java_dev_zide_androidbootstrap_ZideBootstrapActivity_nativeOnWindowFocusBridge(
    _: ?*anyopaque,
    _: ?*anyopaque,
    focused: bool,
) callconv(.c) i64 {
    return @intCast(android_runtime_bridge.noteWindowFocusChanged(focused));
}

export fn Java_dev_zide_androidbootstrap_ZideBootstrapActivity_nativeOnSurfaceAvailableBridge(
    env: ?*anyopaque,
    _: ?*anyopaque,
    surface: ?*anyopaque,
    width: i32,
    height: i32,
) callconv(.c) i64 {
    return @intCast(android_runtime_bridge.noteSurfaceAvailableFromJava(env, surface, width, height));
}

export fn Java_dev_zide_androidbootstrap_ZideBootstrapActivity_nativeOnSurfaceDestroyedBridge(
    _: ?*anyopaque,
    _: ?*anyopaque,
) callconv(.c) i64 {
    return @intCast(android_runtime_bridge.noteSurfaceDestroyed());
}

export fn Java_dev_zide_androidbootstrap_ZideBootstrapActivity_nativeCurrentWindowTokenBridge(
    _: ?*anyopaque,
    _: ?*anyopaque,
) callconv(.c) i64 {
    return @intCast(android_runtime_bridge.currentNativeWindowToken());
}

export fn Java_dev_zide_androidbootstrap_ZideBootstrapActivity_nativeCurrentSurfaceEpochBridge(
    _: ?*anyopaque,
    _: ?*anyopaque,
) callconv(.c) i64 {
    return @intCast(android_runtime_bridge.currentSurfaceIdentityEpoch());
}
