const android_runtime_bridge = @import("../platform/android_runtime_bridge.zig");

fn onCreate() i64 {
    return @intCast(android_runtime_bridge.onCreate());
}

fn onStart() i64 {
    return @intCast(android_runtime_bridge.onStart());
}

fn onResume() i64 {
    return @intCast(android_runtime_bridge.onResume());
}

fn onPause() i64 {
    return @intCast(android_runtime_bridge.onPause());
}

fn onStop() i64 {
    return @intCast(android_runtime_bridge.onStop());
}

fn onWindowFocusChanged(focused: bool) i64 {
    return @intCast(android_runtime_bridge.onWindowFocusChanged(focused));
}

fn onSurfaceAvailable(env: ?*anyopaque, surface: ?*anyopaque, width: i32, height: i32) i64 {
    return @intCast(android_runtime_bridge.onSurfaceAvailableFromJava(env, surface, width, height));
}

fn onSurfaceDestroyed() i64 {
    return @intCast(android_runtime_bridge.onSurfaceDestroyed());
}

fn onSurfaceRedrawNeeded() i64 {
    return @intCast(android_runtime_bridge.onSurfaceRedrawNeeded());
}

fn onVisibleViewport(width: i32, height: i32, imeVisible: bool) i64 {
    return @intCast(android_runtime_bridge.onVisibleViewport(width, height, imeVisible));
}

fn applyTerminalPinchZoom(scaleFactor: f32) i32 {
    return android_runtime_bridge.applyTerminalPinchZoom(scaleFactor);
}

fn setTerminalPinchActive(active: bool) i32 {
    return android_runtime_bridge.setTerminalPinchActive(active);
}

fn currentWindowToken() i64 {
    return @intCast(android_runtime_bridge.currentNativeWindowToken());
}

fn currentSurfaceEpoch() i64 {
    return @intCast(android_runtime_bridge.currentSurfaceEpoch());
}

fn currentSurfaceTransition() i32 {
    return @intFromEnum(android_runtime_bridge.currentSurfaceTransition());
}

export fn Java_uk_laurencegouws_terminal_TerminalNativeBridge_nativeOnCreateBridge(
    _: ?*anyopaque,
    _: ?*anyopaque,
) callconv(.c) i64 {
    return onCreate();
}

export fn Java_uk_laurencegouws_terminal_TerminalNativeBridge_nativeOnStartBridge(
    _: ?*anyopaque,
    _: ?*anyopaque,
) callconv(.c) i64 {
    return onStart();
}

export fn Java_uk_laurencegouws_terminal_TerminalNativeBridge_nativeOnResumeBridge(
    _: ?*anyopaque,
    _: ?*anyopaque,
) callconv(.c) i64 {
    return onResume();
}

export fn Java_uk_laurencegouws_terminal_TerminalNativeBridge_nativeOnPauseBridge(
    _: ?*anyopaque,
    _: ?*anyopaque,
) callconv(.c) i64 {
    return onPause();
}

export fn Java_uk_laurencegouws_terminal_TerminalNativeBridge_nativeOnStopBridge(
    _: ?*anyopaque,
    _: ?*anyopaque,
) callconv(.c) i64 {
    return onStop();
}

export fn Java_uk_laurencegouws_terminal_TerminalNativeBridge_nativeOnWindowFocusBridge(
    _: ?*anyopaque,
    _: ?*anyopaque,
    focused: bool,
) callconv(.c) i64 {
    return onWindowFocusChanged(focused);
}

export fn Java_uk_laurencegouws_terminal_TerminalNativeBridge_nativeOnSurfaceAvailableBridge(
    env: ?*anyopaque,
    _: ?*anyopaque,
    surface: ?*anyopaque,
    width: i32,
    height: i32,
) callconv(.c) i64 {
    return onSurfaceAvailable(env, surface, width, height);
}

export fn Java_uk_laurencegouws_terminal_TerminalNativeBridge_nativeOnSurfaceDestroyedBridge(
    _: ?*anyopaque,
    _: ?*anyopaque,
) callconv(.c) i64 {
    return onSurfaceDestroyed();
}

export fn Java_uk_laurencegouws_terminal_TerminalNativeBridge_nativeOnSurfaceRedrawNeededBridge(
    _: ?*anyopaque,
    _: ?*anyopaque,
) callconv(.c) i64 {
    return onSurfaceRedrawNeeded();
}

export fn Java_uk_laurencegouws_terminal_TerminalNativeBridge_nativeOnVisibleViewportBridge(
    _: ?*anyopaque,
    _: ?*anyopaque,
    width: i32,
    height: i32,
    imeVisible: bool,
) callconv(.c) i64 {
    return onVisibleViewport(width, height, imeVisible);
}

export fn Java_uk_laurencegouws_terminal_TerminalNativeBridge_nativeApplyTerminalPinchZoomBridge(
    _: ?*anyopaque,
    _: ?*anyopaque,
    scaleFactor: f32,
) callconv(.c) i32 {
    return applyTerminalPinchZoom(scaleFactor);
}

export fn Java_uk_laurencegouws_terminal_TerminalNativeBridge_nativeSetTerminalPinchActiveBridge(
    _: ?*anyopaque,
    _: ?*anyopaque,
    active: bool,
) callconv(.c) i32 {
    return setTerminalPinchActive(active);
}

export fn Java_uk_laurencegouws_terminal_TerminalNativeBridge_nativeCurrentWindowTokenBridge(
    _: ?*anyopaque,
    _: ?*anyopaque,
) callconv(.c) i64 {
    return currentWindowToken();
}

export fn Java_uk_laurencegouws_terminal_TerminalNativeBridge_nativeCurrentSurfaceEpochBridge(
    _: ?*anyopaque,
    _: ?*anyopaque,
) callconv(.c) i64 {
    return currentSurfaceEpoch();
}

export fn Java_uk_laurencegouws_terminal_TerminalNativeBridge_nativeCurrentSurfaceTransitionBridge(
    _: ?*anyopaque,
    _: ?*anyopaque,
) callconv(.c) i32 {
    return currentSurfaceTransition();
}
