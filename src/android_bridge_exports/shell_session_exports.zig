const android_runtime_bridge = @import("../platform/android_runtime_bridge.zig");

fn restartSession() i32 {
    return android_runtime_bridge.restartSession();
}

fn pollSession() i32 {
    return android_runtime_bridge.pollSession();
}

fn sessionAlive() bool {
    return android_runtime_bridge.sessionAlive();
}

fn tickFrame() i32 {
    return android_runtime_bridge.tickFrame();
}

fn sendCodepoint(codepoint: i32) i32 {
    return android_runtime_bridge.sendCodepoint(codepoint);
}

fn visibleRows() i32 {
    return android_runtime_bridge.visibleRows();
}

fn visibleCols() i32 {
    return android_runtime_bridge.visibleCols();
}

fn scrollbackCount() i32 {
    return android_runtime_bridge.scrollbackCount();
}

fn scrollbackOffset() i32 {
    return android_runtime_bridge.scrollbackOffset();
}

fn setScrollbackOffset(offsetRows: i32) i32 {
    return android_runtime_bridge.setScrollbackOffset(offsetRows);
}

fn followLiveBottom() i32 {
    return android_runtime_bridge.followLiveBottom();
}

export fn Java_uk_laurencegouws_terminal_TerminalNativeBridge_nativeRestartShellSessionBridge(
    _: ?*anyopaque,
    _: ?*anyopaque,
) callconv(.c) i32 {
    return restartSession();
}

export fn Java_uk_laurencegouws_terminal_TerminalNativeBridge_nativePollShellSessionBridge(
    _: ?*anyopaque,
    _: ?*anyopaque,
) callconv(.c) i32 {
    return pollSession();
}

export fn Java_uk_laurencegouws_terminal_TerminalNativeBridge_nativeIsShellSessionAliveBridge(
    _: ?*anyopaque,
    _: ?*anyopaque,
) callconv(.c) bool {
    return sessionAlive();
}

export fn Java_uk_laurencegouws_terminal_TerminalNativeBridge_nativeTickProductShellFrameBridge(
    _: ?*anyopaque,
    _: ?*anyopaque,
) callconv(.c) i32 {
    return tickFrame();
}

export fn Java_uk_laurencegouws_terminal_TerminalNativeBridge_nativeSendShellCodepointBridge(
    _: ?*anyopaque,
    _: ?*anyopaque,
    codepoint: i32,
) callconv(.c) i32 {
    return sendCodepoint(codepoint);
}

export fn Java_uk_laurencegouws_terminal_TerminalNativeBridge_nativeCurrentShellVisibleRowsBridge(
    _: ?*anyopaque,
    _: ?*anyopaque,
) callconv(.c) i32 {
    return visibleRows();
}

export fn Java_uk_laurencegouws_terminal_TerminalNativeBridge_nativeCurrentShellVisibleColsBridge(
    _: ?*anyopaque,
    _: ?*anyopaque,
) callconv(.c) i32 {
    return visibleCols();
}

export fn Java_uk_laurencegouws_terminal_TerminalNativeBridge_nativeCurrentShellScrollbackCountBridge(
    _: ?*anyopaque,
    _: ?*anyopaque,
) callconv(.c) i32 {
    return scrollbackCount();
}

export fn Java_uk_laurencegouws_terminal_TerminalNativeBridge_nativeCurrentShellScrollbackOffsetBridge(
    _: ?*anyopaque,
    _: ?*anyopaque,
) callconv(.c) i32 {
    return scrollbackOffset();
}

export fn Java_uk_laurencegouws_terminal_TerminalNativeBridge_nativeSetShellScrollbackOffsetBridge(
    _: ?*anyopaque,
    _: ?*anyopaque,
    offsetRows: i32,
) callconv(.c) i32 {
    return setScrollbackOffset(offsetRows);
}

export fn Java_uk_laurencegouws_terminal_TerminalNativeBridge_nativeFollowShellLiveBottomBridge(
    _: ?*anyopaque,
    _: ?*anyopaque,
) callconv(.c) i32 {
    return followLiveBottom();
}
