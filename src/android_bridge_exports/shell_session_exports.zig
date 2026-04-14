const android_runtime_bridge = @import("../platform/android_runtime_bridge.zig");

fn restartShellSession() i32 {
    return android_runtime_bridge.restartShellSession();
}

fn pollShellSession() i32 {
    return android_runtime_bridge.pollShellSession();
}

fn isShellSessionAlive() bool {
    return android_runtime_bridge.isShellSessionAlive();
}

fn tickProductShellFrame() i32 {
    return android_runtime_bridge.tickProductShellFrame();
}

fn sendShellCodepoint(codepoint: i32) i32 {
    return android_runtime_bridge.sendShellCodepoint(codepoint);
}

fn currentShellVisibleRows() i32 {
    return android_runtime_bridge.currentShellVisibleRows();
}

fn currentShellVisibleCols() i32 {
    return android_runtime_bridge.currentShellVisibleCols();
}

fn currentShellScrollbackCount() i32 {
    return android_runtime_bridge.currentShellScrollbackCount();
}

fn currentShellScrollbackOffset() i32 {
    return android_runtime_bridge.currentShellScrollbackOffset();
}

fn setShellScrollbackOffset(offsetRows: i32) i32 {
    return android_runtime_bridge.setShellScrollbackOffset(offsetRows);
}

fn followShellLiveBottom() i32 {
    return android_runtime_bridge.followShellLiveBottom();
}

export fn Java_uk_laurencegouws_terminal_TerminalNativeBridge_nativeRestartShellSessionBridge(
    _: ?*anyopaque,
    _: ?*anyopaque,
) callconv(.c) i32 {
    return restartShellSession();
}

export fn Java_uk_laurencegouws_terminal_TerminalNativeBridge_nativePollShellSessionBridge(
    _: ?*anyopaque,
    _: ?*anyopaque,
) callconv(.c) i32 {
    return pollShellSession();
}

export fn Java_uk_laurencegouws_terminal_TerminalNativeBridge_nativeIsShellSessionAliveBridge(
    _: ?*anyopaque,
    _: ?*anyopaque,
) callconv(.c) bool {
    return isShellSessionAlive();
}

export fn Java_uk_laurencegouws_terminal_TerminalNativeBridge_nativeTickProductShellFrameBridge(
    _: ?*anyopaque,
    _: ?*anyopaque,
) callconv(.c) i32 {
    return tickProductShellFrame();
}

export fn Java_uk_laurencegouws_terminal_TerminalNativeBridge_nativeSendShellCodepointBridge(
    _: ?*anyopaque,
    _: ?*anyopaque,
    codepoint: i32,
) callconv(.c) i32 {
    return sendShellCodepoint(codepoint);
}

export fn Java_uk_laurencegouws_terminal_TerminalNativeBridge_nativeCurrentShellVisibleRowsBridge(
    _: ?*anyopaque,
    _: ?*anyopaque,
) callconv(.c) i32 {
    return currentShellVisibleRows();
}

export fn Java_uk_laurencegouws_terminal_TerminalNativeBridge_nativeCurrentShellVisibleColsBridge(
    _: ?*anyopaque,
    _: ?*anyopaque,
) callconv(.c) i32 {
    return currentShellVisibleCols();
}

export fn Java_uk_laurencegouws_terminal_TerminalNativeBridge_nativeCurrentShellScrollbackCountBridge(
    _: ?*anyopaque,
    _: ?*anyopaque,
) callconv(.c) i32 {
    return currentShellScrollbackCount();
}

export fn Java_uk_laurencegouws_terminal_TerminalNativeBridge_nativeCurrentShellScrollbackOffsetBridge(
    _: ?*anyopaque,
    _: ?*anyopaque,
) callconv(.c) i32 {
    return currentShellScrollbackOffset();
}

export fn Java_uk_laurencegouws_terminal_TerminalNativeBridge_nativeSetShellScrollbackOffsetBridge(
    _: ?*anyopaque,
    _: ?*anyopaque,
    offsetRows: i32,
) callconv(.c) i32 {
    return setShellScrollbackOffset(offsetRows);
}

export fn Java_uk_laurencegouws_terminal_TerminalNativeBridge_nativeFollowShellLiveBottomBridge(
    _: ?*anyopaque,
    _: ?*anyopaque,
) callconv(.c) i32 {
    return followShellLiveBottom();
}
