const android_runtime_bridge = @import("../platform/android_runtime_bridge.zig");

fn currentRendererStatus() i32 {
    return @intFromEnum(android_runtime_bridge.currentRendererStatus());
}

fn currentRendererSwapCount() i64 {
    return @intCast(android_runtime_bridge.currentRendererSwapCount());
}

fn currentRendererBoundEpoch() i64 {
    return @intCast(android_runtime_bridge.currentRendererBoundEpoch());
}

fn currentRendererContextCreateCount() i64 {
    return @intCast(android_runtime_bridge.currentRendererContextCreateCount());
}

fn currentRendererSurfaceCreateCount() i64 {
    return @intCast(android_runtime_bridge.currentRendererSurfaceCreateCount());
}

fn currentRendererTextureCreateCount() i64 {
    return @intCast(android_runtime_bridge.currentRendererTextureCreateCount());
}

fn currentRendererTextureAlive() u8 {
    return @intFromBool(android_runtime_bridge.currentRendererTextureAlive());
}

fn currentRendererTextureUploadCount() i64 {
    return @intCast(android_runtime_bridge.currentRendererTextureUploadCount());
}

fn currentRendererTextureUpdateCount() i64 {
    return @intCast(android_runtime_bridge.currentRendererTextureUpdateCount());
}

fn currentRendererTextureResizeCount() i64 {
    return @intCast(android_runtime_bridge.currentRendererTextureResizeCount());
}

fn currentRendererTextureWidth() i32 {
    return android_runtime_bridge.currentRendererTextureWidth();
}

fn currentRendererTextureHeight() i32 {
    return android_runtime_bridge.currentRendererTextureHeight();
}

fn rendererActive() bool {
    return android_runtime_bridge.rendererActive();
}

export fn Java_uk_laurencegouws_terminal_NativeBridge_nativeCurrentRendererStatusBridge(
    _: ?*anyopaque,
    _: ?*anyopaque,
) callconv(.c) i32 {
    return currentRendererStatus();
}

export fn Java_uk_laurencegouws_terminal_NativeBridge_nativeCurrentRendererSwapCountBridge(
    _: ?*anyopaque,
    _: ?*anyopaque,
) callconv(.c) i64 {
    return currentRendererSwapCount();
}

export fn Java_uk_laurencegouws_terminal_NativeBridge_nativeCurrentRendererBoundEpochBridge(
    _: ?*anyopaque,
    _: ?*anyopaque,
) callconv(.c) i64 {
    return currentRendererBoundEpoch();
}

export fn Java_uk_laurencegouws_terminal_NativeBridge_nativeCurrentRendererContextCreateCountBridge(
    _: ?*anyopaque,
    _: ?*anyopaque,
) callconv(.c) i64 {
    return currentRendererContextCreateCount();
}

export fn Java_uk_laurencegouws_terminal_NativeBridge_nativeCurrentRendererSurfaceCreateCountBridge(
    _: ?*anyopaque,
    _: ?*anyopaque,
) callconv(.c) i64 {
    return currentRendererSurfaceCreateCount();
}

export fn Java_uk_laurencegouws_terminal_NativeBridge_nativeCurrentRendererTextureCreateCountBridge(
    _: ?*anyopaque,
    _: ?*anyopaque,
) callconv(.c) i64 {
    return currentRendererTextureCreateCount();
}

export fn Java_uk_laurencegouws_terminal_NativeBridge_nativeCurrentRendererTextureAliveBridge(
    _: ?*anyopaque,
    _: ?*anyopaque,
) callconv(.c) u8 {
    return currentRendererTextureAlive();
}

export fn Java_uk_laurencegouws_terminal_NativeBridge_nativeCurrentRendererTextureUploadCountBridge(
    _: ?*anyopaque,
    _: ?*anyopaque,
) callconv(.c) i64 {
    return currentRendererTextureUploadCount();
}

export fn Java_uk_laurencegouws_terminal_NativeBridge_nativeCurrentRendererTextureUpdateCountBridge(
    _: ?*anyopaque,
    _: ?*anyopaque,
) callconv(.c) i64 {
    return currentRendererTextureUpdateCount();
}

export fn Java_uk_laurencegouws_terminal_NativeBridge_nativeCurrentRendererTextureResizeCountBridge(
    _: ?*anyopaque,
    _: ?*anyopaque,
) callconv(.c) i64 {
    return currentRendererTextureResizeCount();
}

export fn Java_uk_laurencegouws_terminal_NativeBridge_nativeCurrentRendererTextureWidthBridge(
    _: ?*anyopaque,
    _: ?*anyopaque,
) callconv(.c) i32 {
    return currentRendererTextureWidth();
}

export fn Java_uk_laurencegouws_terminal_NativeBridge_nativeCurrentRendererTextureHeightBridge(
    _: ?*anyopaque,
    _: ?*anyopaque,
) callconv(.c) i32 {
    return currentRendererTextureHeight();
}

export fn Java_uk_laurencegouws_terminal_NativeBridge_nativeSharedRendererActiveBridge(
    _: ?*anyopaque,
    _: ?*anyopaque,
) callconv(.c) bool {
    return rendererActive();
}
