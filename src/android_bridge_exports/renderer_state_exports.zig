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

fn sharedShellRendererActive() bool {
    return android_runtime_bridge.sharedShellRendererActive();
}

export fn Java_uk_laurencegouws_terminal_TerminalNativeBridge_nativeCurrentRendererStatusBridge(
    _: ?*anyopaque,
    _: ?*anyopaque,
) callconv(.c) i32 {
    return currentRendererStatus();
}

export fn Java_uk_laurencegouws_terminal_TerminalNativeBridge_nativeCurrentRendererSwapCountBridge(
    _: ?*anyopaque,
    _: ?*anyopaque,
) callconv(.c) i64 {
    return currentRendererSwapCount();
}

export fn Java_uk_laurencegouws_terminal_TerminalNativeBridge_nativeCurrentRendererBoundEpochBridge(
    _: ?*anyopaque,
    _: ?*anyopaque,
) callconv(.c) i64 {
    return currentRendererBoundEpoch();
}

export fn Java_uk_laurencegouws_terminal_TerminalNativeBridge_nativeCurrentRendererContextCreateCountBridge(
    _: ?*anyopaque,
    _: ?*anyopaque,
) callconv(.c) i64 {
    return currentRendererContextCreateCount();
}

export fn Java_uk_laurencegouws_terminal_TerminalNativeBridge_nativeCurrentRendererSurfaceCreateCountBridge(
    _: ?*anyopaque,
    _: ?*anyopaque,
) callconv(.c) i64 {
    return currentRendererSurfaceCreateCount();
}

export fn Java_uk_laurencegouws_terminal_TerminalNativeBridge_nativeCurrentRendererTextureCreateCountBridge(
    _: ?*anyopaque,
    _: ?*anyopaque,
) callconv(.c) i64 {
    return currentRendererTextureCreateCount();
}

export fn Java_uk_laurencegouws_terminal_TerminalNativeBridge_nativeCurrentRendererTextureAliveBridge(
    _: ?*anyopaque,
    _: ?*anyopaque,
) callconv(.c) u8 {
    return currentRendererTextureAlive();
}

export fn Java_uk_laurencegouws_terminal_TerminalNativeBridge_nativeCurrentRendererTextureUploadCountBridge(
    _: ?*anyopaque,
    _: ?*anyopaque,
) callconv(.c) i64 {
    return currentRendererTextureUploadCount();
}

export fn Java_uk_laurencegouws_terminal_TerminalNativeBridge_nativeCurrentRendererTextureUpdateCountBridge(
    _: ?*anyopaque,
    _: ?*anyopaque,
) callconv(.c) i64 {
    return currentRendererTextureUpdateCount();
}

export fn Java_uk_laurencegouws_terminal_TerminalNativeBridge_nativeCurrentRendererTextureResizeCountBridge(
    _: ?*anyopaque,
    _: ?*anyopaque,
) callconv(.c) i64 {
    return currentRendererTextureResizeCount();
}

export fn Java_uk_laurencegouws_terminal_TerminalNativeBridge_nativeCurrentRendererTextureWidthBridge(
    _: ?*anyopaque,
    _: ?*anyopaque,
) callconv(.c) i32 {
    return currentRendererTextureWidth();
}

export fn Java_uk_laurencegouws_terminal_TerminalNativeBridge_nativeCurrentRendererTextureHeightBridge(
    _: ?*anyopaque,
    _: ?*anyopaque,
) callconv(.c) i32 {
    return currentRendererTextureHeight();
}

export fn Java_uk_laurencegouws_terminal_TerminalNativeBridge_nativeSharedShellRendererActiveBridge(
    _: ?*anyopaque,
    _: ?*anyopaque,
) callconv(.c) bool {
    return sharedShellRendererActive();
}
