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

fn onVisibleViewportBridge(width: i32, height: i32, ime_visible: bool) i64 {
    return @intCast(android_runtime_bridge.noteVisibleViewport(width, height, ime_visible));
}

fn applyTerminalPinchZoomBridge(scale_factor: f32) i32 {
    return android_runtime_bridge.applyTerminalPinchZoom(scale_factor);
}

fn setTerminalPinchActiveBridge(active: bool) i32 {
    return android_runtime_bridge.setTerminalPinchActive(active);
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

fn currentRendererStatusBridge() i32 {
    return @intFromEnum(android_runtime_bridge.currentRendererStatus());
}

fn currentRendererSwapCountBridge() i64 {
    return @intCast(android_runtime_bridge.currentRendererSwapCount());
}

fn currentRendererBoundEpochBridge() i64 {
    return @intCast(android_runtime_bridge.currentRendererBoundEpoch());
}

fn currentRendererContextCreateCountBridge() i64 {
    return @intCast(android_runtime_bridge.currentRendererContextCreateCount());
}

fn currentRendererSurfaceCreateCountBridge() i64 {
    return @intCast(android_runtime_bridge.currentRendererSurfaceCreateCount());
}

fn currentRendererTextureCreateCountBridge() i64 {
    return @intCast(android_runtime_bridge.currentRendererTextureCreateCount());
}

fn currentRendererTextureAliveBridge() u8 {
    return @intFromBool(android_runtime_bridge.currentRendererTextureAlive());
}

fn currentRendererTextureUploadCountBridge() i64 {
    return @intCast(android_runtime_bridge.currentRendererTextureUploadCount());
}

fn currentRendererTextureUpdateCountBridge() i64 {
    return @intCast(android_runtime_bridge.currentRendererTextureUpdateCount());
}

fn currentRendererTextureResizeCountBridge() i64 {
    return @intCast(android_runtime_bridge.currentRendererTextureResizeCount());
}

fn currentRendererTextureWidthBridge() i32 {
    return android_runtime_bridge.currentRendererTextureWidth();
}

fn currentRendererTextureHeightBridge() i32 {
    return android_runtime_bridge.currentRendererTextureHeight();
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

fn sharedShellRendererActiveBridge() bool {
    return android_runtime_bridge.sharedShellRendererActive();
}

export fn Java_dev_zide_terminal_ZideTerminalActivity_nativeOnCreateBridge(
    _: ?*anyopaque,
    _: ?*anyopaque,
) callconv(.c) i64 {
    return onCreateBridge();
}

export fn Java_dev_zide_terminal_ZideTerminalActivity_nativeOnStartBridge(
    _: ?*anyopaque,
    _: ?*anyopaque,
) callconv(.c) i64 {
    return onStartBridge();
}

export fn Java_dev_zide_terminal_ZideTerminalActivity_nativeOnResumeBridge(
    _: ?*anyopaque,
    _: ?*anyopaque,
) callconv(.c) i64 {
    return onResumeBridge();
}

export fn Java_dev_zide_terminal_ZideTerminalActivity_nativeOnPauseBridge(
    _: ?*anyopaque,
    _: ?*anyopaque,
) callconv(.c) i64 {
    return onPauseBridge();
}

export fn Java_dev_zide_terminal_ZideTerminalActivity_nativeOnStopBridge(
    _: ?*anyopaque,
    _: ?*anyopaque,
) callconv(.c) i64 {
    return onStopBridge();
}

export fn Java_dev_zide_terminal_ZideTerminalActivity_nativeOnWindowFocusBridge(
    _: ?*anyopaque,
    _: ?*anyopaque,
    focused: bool,
) callconv(.c) i64 {
    return onWindowFocusBridge(focused);
}

export fn Java_dev_zide_terminal_ZideTerminalActivity_nativeOnSurfaceAvailableBridge(
    env: ?*anyopaque,
    _: ?*anyopaque,
    surface: ?*anyopaque,
    width: i32,
    height: i32,
) callconv(.c) i64 {
    return onSurfaceAvailableBridge(env, surface, width, height);
}

export fn Java_dev_zide_terminal_ZideTerminalActivity_nativeOnSurfaceDestroyedBridge(
    _: ?*anyopaque,
    _: ?*anyopaque,
) callconv(.c) i64 {
    return onSurfaceDestroyedBridge();
}

export fn Java_dev_zide_terminal_ZideTerminalActivity_nativeOnSurfaceRedrawNeededBridge(
    _: ?*anyopaque,
    _: ?*anyopaque,
) callconv(.c) i64 {
    return onSurfaceRedrawNeededBridge();
}

export fn Java_dev_zide_terminal_ZideTerminalActivity_nativeOnVisibleViewportBridge(
    _: ?*anyopaque,
    _: ?*anyopaque,
    width: i32,
    height: i32,
    ime_visible: bool,
) callconv(.c) i64 {
    return onVisibleViewportBridge(width, height, ime_visible);
}

export fn Java_dev_zide_terminal_ZideTerminalActivity_nativeApplyTerminalPinchZoomBridge(
    _: ?*anyopaque,
    _: ?*anyopaque,
    scale_factor: f32,
) callconv(.c) i32 {
    return applyTerminalPinchZoomBridge(scale_factor);
}

export fn Java_dev_zide_terminal_ZideTerminalActivity_nativeSetTerminalPinchActiveBridge(
    _: ?*anyopaque,
    _: ?*anyopaque,
    active: bool,
) callconv(.c) i32 {
    return setTerminalPinchActiveBridge(active);
}

export fn Java_dev_zide_terminal_ZideTerminalActivity_nativeCurrentWindowTokenBridge(
    _: ?*anyopaque,
    _: ?*anyopaque,
) callconv(.c) i64 {
    return currentWindowTokenBridge();
}

export fn Java_dev_zide_terminal_ZideTerminalActivity_nativeCurrentSurfaceEpochBridge(
    _: ?*anyopaque,
    _: ?*anyopaque,
) callconv(.c) i64 {
    return currentSurfaceEpochBridge();
}

export fn Java_dev_zide_terminal_ZideTerminalActivity_nativeCurrentSurfaceTransitionBridge(
    _: ?*anyopaque,
    _: ?*anyopaque,
) callconv(.c) i32 {
    return currentSurfaceTransitionBridge();
}

export fn Java_dev_zide_terminal_ZideTerminalActivity_nativeCurrentRendererStatusBridge(
    _: ?*anyopaque,
    _: ?*anyopaque,
) callconv(.c) i32 {
    return currentRendererStatusBridge();
}

export fn Java_dev_zide_terminal_ZideTerminalActivity_nativeCurrentRendererSwapCountBridge(
    _: ?*anyopaque,
    _: ?*anyopaque,
) callconv(.c) i64 {
    return currentRendererSwapCountBridge();
}

export fn Java_dev_zide_terminal_ZideTerminalActivity_nativeCurrentRendererBoundEpochBridge(
    _: ?*anyopaque,
    _: ?*anyopaque,
) callconv(.c) i64 {
    return currentRendererBoundEpochBridge();
}

export fn Java_dev_zide_terminal_ZideTerminalActivity_nativeCurrentRendererContextCreateCountBridge(
    _: ?*anyopaque,
    _: ?*anyopaque,
) callconv(.c) i64 {
    return currentRendererContextCreateCountBridge();
}

export fn Java_dev_zide_terminal_ZideTerminalActivity_nativeCurrentRendererSurfaceCreateCountBridge(
    _: ?*anyopaque,
    _: ?*anyopaque,
) callconv(.c) i64 {
    return currentRendererSurfaceCreateCountBridge();
}

export fn Java_dev_zide_terminal_ZideTerminalActivity_nativeCurrentRendererTextureCreateCountBridge(
    _: ?*anyopaque,
    _: ?*anyopaque,
) callconv(.c) i64 {
    return currentRendererTextureCreateCountBridge();
}

export fn Java_dev_zide_terminal_ZideTerminalActivity_nativeCurrentRendererTextureAliveBridge(
    _: ?*anyopaque,
    _: ?*anyopaque,
) callconv(.c) u8 {
    return currentRendererTextureAliveBridge();
}

export fn Java_dev_zide_terminal_ZideTerminalActivity_nativeCurrentRendererTextureUploadCountBridge(
    _: ?*anyopaque,
    _: ?*anyopaque,
) callconv(.c) i64 {
    return currentRendererTextureUploadCountBridge();
}

export fn Java_dev_zide_terminal_ZideTerminalActivity_nativeCurrentRendererTextureUpdateCountBridge(
    _: ?*anyopaque,
    _: ?*anyopaque,
) callconv(.c) i64 {
    return currentRendererTextureUpdateCountBridge();
}

export fn Java_dev_zide_terminal_ZideTerminalActivity_nativeCurrentRendererTextureResizeCountBridge(
    _: ?*anyopaque,
    _: ?*anyopaque,
) callconv(.c) i64 {
    return currentRendererTextureResizeCountBridge();
}

export fn Java_dev_zide_terminal_ZideTerminalActivity_nativeCurrentRendererTextureWidthBridge(
    _: ?*anyopaque,
    _: ?*anyopaque,
) callconv(.c) i32 {
    return currentRendererTextureWidthBridge();
}

export fn Java_dev_zide_terminal_ZideTerminalActivity_nativeCurrentRendererTextureHeightBridge(
    _: ?*anyopaque,
    _: ?*anyopaque,
) callconv(.c) i32 {
    return currentRendererTextureHeightBridge();
}

export fn Java_dev_zide_terminal_ZideTerminalActivity_nativeRestartShellSessionBridge(
    _: ?*anyopaque,
    _: ?*anyopaque,
) callconv(.c) i32 {
    return restartShellSessionBridge();
}

export fn Java_dev_zide_terminal_ZideTerminalActivity_nativePollShellSessionBridge(
    _: ?*anyopaque,
    _: ?*anyopaque,
) callconv(.c) i32 {
    return pollShellSessionBridge();
}

export fn Java_dev_zide_terminal_ZideTerminalActivity_nativeIsShellSessionAliveBridge(
    _: ?*anyopaque,
    _: ?*anyopaque,
) callconv(.c) bool {
    return isShellSessionAliveBridge();
}

export fn Java_dev_zide_terminal_ZideTerminalActivity_nativeSendShellCodepointBridge(
    _: ?*anyopaque,
    _: ?*anyopaque,
    codepoint: i32,
) callconv(.c) i32 {
    return sendShellCodepointBridge(codepoint);
}

export fn Java_dev_zide_terminal_ZideTerminalActivity_nativeSharedShellRendererActiveBridge(
    _: ?*anyopaque,
    _: ?*anyopaque,
) callconv(.c) bool {
    return sharedShellRendererActiveBridge();
}
