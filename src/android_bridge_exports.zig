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

export fn Java_dev_zide_androidbootstrap_ZideBootstrapActivity_nativeOnSurfaceRedrawNeededBridge(
    _: ?*anyopaque,
    _: ?*anyopaque,
) callconv(.c) i64 {
    return @intCast(android_runtime_bridge.noteSurfaceRedrawNeeded());
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

export fn Java_dev_zide_androidbootstrap_ZideBootstrapActivity_nativeCurrentSurfaceTransitionBridge(
    _: ?*anyopaque,
    _: ?*anyopaque,
) callconv(.c) i32 {
    return @intFromEnum(android_runtime_bridge.currentSurfaceIdentityTransition());
}

export fn Java_dev_zide_androidbootstrap_ZideBootstrapActivity_nativeCurrentGlesProbeStatusBridge(
    _: ?*anyopaque,
    _: ?*anyopaque,
) callconv(.c) i32 {
    return @intFromEnum(android_runtime_bridge.currentGlesProbeStatus());
}

export fn Java_dev_zide_androidbootstrap_ZideBootstrapActivity_nativeCurrentGlesProbeSwapCountBridge(
    _: ?*anyopaque,
    _: ?*anyopaque,
) callconv(.c) i64 {
    return @intCast(android_runtime_bridge.currentGlesProbeSwapCount());
}

export fn Java_dev_zide_androidbootstrap_ZideBootstrapActivity_nativeCurrentGlesProbeBoundEpochBridge(
    _: ?*anyopaque,
    _: ?*anyopaque,
) callconv(.c) i64 {
    return @intCast(android_runtime_bridge.currentGlesProbeBoundEpoch());
}

export fn Java_dev_zide_androidbootstrap_ZideBootstrapActivity_nativeCurrentGlesProbeSurfaceCreateCountBridge(
    _: ?*anyopaque,
    _: ?*anyopaque,
) callconv(.c) i64 {
    return @intCast(android_runtime_bridge.currentGlesProbeSurfaceCreateCount());
}

export fn Java_dev_zide_androidbootstrap_ZideBootstrapActivity_nativeStartPtyProbeBridge(
    _: ?*anyopaque,
    _: ?*anyopaque,
) callconv(.c) i64 {
    return @intCast(android_runtime_bridge.startPtyLifetimeProbe());
}

export fn Java_dev_zide_androidbootstrap_ZideBootstrapActivity_nativeStopPtyProbeBridge(
    _: ?*anyopaque,
    _: ?*anyopaque,
) callconv(.c) void {
    android_runtime_bridge.stopPtyLifetimeProbe();
}

export fn Java_dev_zide_androidbootstrap_ZideBootstrapActivity_nativeIsPtyProbeAliveBridge(
    _: ?*anyopaque,
    _: ?*anyopaque,
) callconv(.c) bool {
    return android_runtime_bridge.isPtyLifetimeProbeAlive();
}

export fn Java_dev_zide_androidbootstrap_ZideBootstrapActivity_nativePtyProbeChildPidBridge(
    _: ?*anyopaque,
    _: ?*anyopaque,
) callconv(.c) i64 {
    return @intCast(android_runtime_bridge.ptyLifetimeProbeChildPid());
}

export fn Java_dev_zide_androidbootstrap_ZideBootstrapActivity_nativePtyProbeStartStatusBridge(
    _: ?*anyopaque,
    _: ?*anyopaque,
) callconv(.c) i32 {
    return android_runtime_bridge.ptyLifetimeProbeStartStatus();
}

export fn Java_dev_zide_androidbootstrap_ZidePtyProbeService_nativeStartPtyProbeBridge(
    _: ?*anyopaque,
    _: ?*anyopaque,
) callconv(.c) i64 {
    return @intCast(android_runtime_bridge.startPtyLifetimeProbe());
}

export fn Java_dev_zide_androidbootstrap_ZidePtyProbeService_nativeStopPtyProbeBridge(
    _: ?*anyopaque,
    _: ?*anyopaque,
) callconv(.c) void {
    android_runtime_bridge.stopPtyLifetimeProbe();
}

export fn Java_dev_zide_androidbootstrap_ZidePtyProbeService_nativeIsPtyProbeAliveBridge(
    _: ?*anyopaque,
    _: ?*anyopaque,
) callconv(.c) bool {
    return android_runtime_bridge.isPtyLifetimeProbeAlive();
}

export fn Java_dev_zide_androidbootstrap_ZidePtyProbeService_nativePtyProbeChildPidBridge(
    _: ?*anyopaque,
    _: ?*anyopaque,
) callconv(.c) i64 {
    return @intCast(android_runtime_bridge.ptyLifetimeProbeChildPid());
}

export fn Java_dev_zide_androidbootstrap_ZidePtyProbeService_nativePtyProbeStartStatusBridge(
    _: ?*anyopaque,
    _: ?*anyopaque,
) callconv(.c) i32 {
    return android_runtime_bridge.ptyLifetimeProbeStartStatus();
}
