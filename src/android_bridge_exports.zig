const android_runtime_bridge = @import("platform/android_runtime_bridge.zig");

fn onCreateBridge() i64 {
    return @intCast(android_runtime_bridge.noteCreate());
}

fn onStartBridge() i64 {
    return @intCast(android_runtime_bridge.noteStart());
}

fn onResumeBridge() i64 {
    return @intCast(android_runtime_bridge.noteResume());
}

fn onPauseBridge() i64 {
    return @intCast(android_runtime_bridge.notePause());
}

fn onStopBridge() i64 {
    return @intCast(android_runtime_bridge.noteStop());
}

fn onWindowFocusBridge(focused: bool) i64 {
    return @intCast(android_runtime_bridge.noteWindowFocusChanged(focused));
}

fn onSurfaceAvailableBridge(env: ?*anyopaque, surface: ?*anyopaque, width: i32, height: i32) i64 {
    return @intCast(android_runtime_bridge.noteSurfaceAvailableFromJava(env, surface, width, height));
}

fn onSurfaceDestroyedBridge() i64 {
    return @intCast(android_runtime_bridge.noteSurfaceDestroyed());
}

fn onSurfaceRedrawNeededBridge() i64 {
    return @intCast(android_runtime_bridge.noteSurfaceRedrawNeeded());
}

fn currentWindowTokenBridge() i64 {
    return @intCast(android_runtime_bridge.currentNativeWindowToken());
}

fn currentSurfaceEpochBridge() i64 {
    return @intCast(android_runtime_bridge.currentSurfaceIdentityEpoch());
}

fn currentSurfaceTransitionBridge() i32 {
    return @intFromEnum(android_runtime_bridge.currentSurfaceIdentityTransition());
}

fn currentGlesProbeStatusBridge() i32 {
    return @intFromEnum(android_runtime_bridge.currentGlesProbeStatus());
}

fn currentGlesProbeSwapCountBridge() i64 {
    return @intCast(android_runtime_bridge.currentGlesProbeSwapCount());
}

fn currentGlesProbeBoundEpochBridge() i64 {
    return @intCast(android_runtime_bridge.currentGlesProbeBoundEpoch());
}

fn currentGlesProbeContextCreateCountBridge() i64 {
    return @intCast(android_runtime_bridge.currentGlesProbeContextCreateCount());
}

fn currentGlesProbeSurfaceCreateCountBridge() i64 {
    return @intCast(android_runtime_bridge.currentGlesProbeSurfaceCreateCount());
}

fn currentGlesProbeTextureCreateCountBridge() i64 {
    return @intCast(android_runtime_bridge.currentGlesProbeTextureCreateCount());
}

fn currentGlesProbeTextureAliveBridge() u8 {
    return @intFromBool(android_runtime_bridge.currentGlesProbeTextureAlive());
}

fn currentGlesProbeTextureUploadCountBridge() i64 {
    return @intCast(android_runtime_bridge.currentGlesProbeTextureUploadCount());
}

fn currentGlesProbeTextureUpdateCountBridge() i64 {
    return @intCast(android_runtime_bridge.currentGlesProbeTextureUpdateCount());
}

fn currentGlesProbeTextureResizeCountBridge() i64 {
    return @intCast(android_runtime_bridge.currentGlesProbeTextureResizeCount());
}

fn currentGlesProbeTextureWidthBridge() i32 {
    return android_runtime_bridge.currentGlesProbeTextureWidth();
}

fn currentGlesProbeTextureHeightBridge() i32 {
    return android_runtime_bridge.currentGlesProbeTextureHeight();
}

fn restartShellSessionBridge() i32 {
    return android_runtime_bridge.restartShellSession();
}

fn pollShellSessionBridge() i32 {
    return android_runtime_bridge.pollShellSession();
}

fn isShellSessionAliveBridge() bool {
    return android_runtime_bridge.isShellSessionAlive();
}

fn sendShellCodepointBridge(codepoint: i32) i32 {
    return android_runtime_bridge.sendShellCodepoint(codepoint);
}

export fn Java_dev_zide_androidbootstrap_ZideBootstrapActivity_nativeOnCreateBridge(
    _: ?*anyopaque,
    _: ?*anyopaque,
) callconv(.c) i64 {
    return onCreateBridge();
}

export fn Java_dev_zide_androidbootstrap_ZideBootstrapActivity_nativeOnStartBridge(
    _: ?*anyopaque,
    _: ?*anyopaque,
) callconv(.c) i64 {
    return onStartBridge();
}

export fn Java_dev_zide_androidbootstrap_ZideBootstrapActivity_nativeOnResumeBridge(
    _: ?*anyopaque,
    _: ?*anyopaque,
) callconv(.c) i64 {
    return onResumeBridge();
}

export fn Java_dev_zide_androidbootstrap_ZideBootstrapActivity_nativeOnPauseBridge(
    _: ?*anyopaque,
    _: ?*anyopaque,
) callconv(.c) i64 {
    return onPauseBridge();
}

export fn Java_dev_zide_androidbootstrap_ZideBootstrapActivity_nativeOnStopBridge(
    _: ?*anyopaque,
    _: ?*anyopaque,
) callconv(.c) i64 {
    return onStopBridge();
}

export fn Java_dev_zide_androidbootstrap_ZideBootstrapActivity_nativeOnWindowFocusBridge(
    _: ?*anyopaque,
    _: ?*anyopaque,
    focused: bool,
) callconv(.c) i64 {
    return onWindowFocusBridge(focused);
}

export fn Java_dev_zide_androidbootstrap_ZideBootstrapActivity_nativeOnSurfaceAvailableBridge(
    env: ?*anyopaque,
    _: ?*anyopaque,
    surface: ?*anyopaque,
    width: i32,
    height: i32,
) callconv(.c) i64 {
    return onSurfaceAvailableBridge(env, surface, width, height);
}

export fn Java_dev_zide_androidbootstrap_ZideBootstrapActivity_nativeOnSurfaceDestroyedBridge(
    _: ?*anyopaque,
    _: ?*anyopaque,
) callconv(.c) i64 {
    return onSurfaceDestroyedBridge();
}

export fn Java_dev_zide_androidbootstrap_ZideBootstrapActivity_nativeOnSurfaceRedrawNeededBridge(
    _: ?*anyopaque,
    _: ?*anyopaque,
) callconv(.c) i64 {
    return onSurfaceRedrawNeededBridge();
}

export fn Java_dev_zide_androidbootstrap_ZideBootstrapActivity_nativeCurrentWindowTokenBridge(
    _: ?*anyopaque,
    _: ?*anyopaque,
) callconv(.c) i64 {
    return currentWindowTokenBridge();
}

export fn Java_dev_zide_androidbootstrap_ZideBootstrapActivity_nativeCurrentSurfaceEpochBridge(
    _: ?*anyopaque,
    _: ?*anyopaque,
) callconv(.c) i64 {
    return currentSurfaceEpochBridge();
}

export fn Java_dev_zide_androidbootstrap_ZideBootstrapActivity_nativeCurrentSurfaceTransitionBridge(
    _: ?*anyopaque,
    _: ?*anyopaque,
) callconv(.c) i32 {
    return currentSurfaceTransitionBridge();
}

export fn Java_dev_zide_androidbootstrap_ZideBootstrapActivity_nativeCurrentGlesProbeStatusBridge(
    _: ?*anyopaque,
    _: ?*anyopaque,
) callconv(.c) i32 {
    return currentGlesProbeStatusBridge();
}

export fn Java_dev_zide_androidbootstrap_ZideBootstrapActivity_nativeCurrentGlesProbeSwapCountBridge(
    _: ?*anyopaque,
    _: ?*anyopaque,
) callconv(.c) i64 {
    return currentGlesProbeSwapCountBridge();
}

export fn Java_dev_zide_androidbootstrap_ZideBootstrapActivity_nativeCurrentGlesProbeBoundEpochBridge(
    _: ?*anyopaque,
    _: ?*anyopaque,
) callconv(.c) i64 {
    return currentGlesProbeBoundEpochBridge();
}

export fn Java_dev_zide_androidbootstrap_ZideBootstrapActivity_nativeCurrentGlesProbeContextCreateCountBridge(
    _: ?*anyopaque,
    _: ?*anyopaque,
) callconv(.c) i64 {
    return currentGlesProbeContextCreateCountBridge();
}

export fn Java_dev_zide_androidbootstrap_ZideBootstrapActivity_nativeCurrentGlesProbeSurfaceCreateCountBridge(
    _: ?*anyopaque,
    _: ?*anyopaque,
) callconv(.c) i64 {
    return currentGlesProbeSurfaceCreateCountBridge();
}

export fn Java_dev_zide_androidbootstrap_ZideBootstrapActivity_nativeCurrentGlesProbeTextureCreateCountBridge(
    _: ?*anyopaque,
    _: ?*anyopaque,
) callconv(.c) i64 {
    return currentGlesProbeTextureCreateCountBridge();
}

export fn Java_dev_zide_androidbootstrap_ZideBootstrapActivity_nativeCurrentGlesProbeTextureAliveBridge(
    _: ?*anyopaque,
    _: ?*anyopaque,
) callconv(.c) u8 {
    return currentGlesProbeTextureAliveBridge();
}

export fn Java_dev_zide_androidbootstrap_ZideBootstrapActivity_nativeCurrentGlesProbeTextureUploadCountBridge(
    _: ?*anyopaque,
    _: ?*anyopaque,
) callconv(.c) i64 {
    return currentGlesProbeTextureUploadCountBridge();
}

export fn Java_dev_zide_androidbootstrap_ZideBootstrapActivity_nativeCurrentGlesProbeTextureUpdateCountBridge(
    _: ?*anyopaque,
    _: ?*anyopaque,
) callconv(.c) i64 {
    return currentGlesProbeTextureUpdateCountBridge();
}

export fn Java_dev_zide_androidbootstrap_ZideBootstrapActivity_nativeCurrentGlesProbeTextureResizeCountBridge(
    _: ?*anyopaque,
    _: ?*anyopaque,
) callconv(.c) i64 {
    return currentGlesProbeTextureResizeCountBridge();
}

export fn Java_dev_zide_androidbootstrap_ZideBootstrapActivity_nativeCurrentGlesProbeTextureWidthBridge(
    _: ?*anyopaque,
    _: ?*anyopaque,
) callconv(.c) i32 {
    return currentGlesProbeTextureWidthBridge();
}

export fn Java_dev_zide_androidbootstrap_ZideBootstrapActivity_nativeCurrentGlesProbeTextureHeightBridge(
    _: ?*anyopaque,
    _: ?*anyopaque,
) callconv(.c) i32 {
    return currentGlesProbeTextureHeightBridge();
}

export fn Java_dev_zide_androidbootstrap_ZideBootstrapActivity_nativeRestartShellSessionBridge(
    _: ?*anyopaque,
    _: ?*anyopaque,
) callconv(.c) i32 {
    return restartShellSessionBridge();
}

export fn Java_dev_zide_androidbootstrap_ZideBootstrapActivity_nativePollShellSessionBridge(
    _: ?*anyopaque,
    _: ?*anyopaque,
) callconv(.c) i32 {
    return pollShellSessionBridge();
}

export fn Java_dev_zide_androidbootstrap_ZideBootstrapActivity_nativeIsShellSessionAliveBridge(
    _: ?*anyopaque,
    _: ?*anyopaque,
) callconv(.c) bool {
    return isShellSessionAliveBridge();
}

export fn Java_dev_zide_androidbootstrap_ZideBootstrapActivity_nativeSendShellCodepointBridge(
    _: ?*anyopaque,
    _: ?*anyopaque,
    codepoint: i32,
) callconv(.c) i32 {
    return sendShellCodepointBridge(codepoint);
}

