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

export fn Java_uk_laurencegouws_terminal_TerminalNativeBridge_nativeRestartSessionBridge(
    _: ?*anyopaque,
    _: ?*anyopaque,
) callconv(.c) i32 {
    return restartSession();
}

export fn Java_uk_laurencegouws_terminal_TerminalNativeBridge_nativePollSessionBridge(
    _: ?*anyopaque,
    _: ?*anyopaque,
) callconv(.c) i32 {
    return pollSession();
}

export fn Java_uk_laurencegouws_terminal_TerminalNativeBridge_nativeIsSessionAliveBridge(
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

export fn Java_uk_laurencegouws_terminal_TerminalNativeBridge_nativeSendSessionCodepointBridge(
    _: ?*anyopaque,
    _: ?*anyopaque,
    codepoint: i32,
) callconv(.c) i32 {
    return sendCodepoint(codepoint);
}

export fn Java_uk_laurencegouws_terminal_TerminalNativeBridge_nativeCurrentSessionVisibleRowsBridge(
    _: ?*anyopaque,
    _: ?*anyopaque,
) callconv(.c) i32 {
    return visibleRows();
}

export fn Java_uk_laurencegouws_terminal_TerminalNativeBridge_nativeCurrentSessionVisibleColsBridge(
    _: ?*anyopaque,
    _: ?*anyopaque,
) callconv(.c) i32 {
    return visibleCols();
}

export fn Java_uk_laurencegouws_terminal_TerminalNativeBridge_nativeCurrentSessionScrollbackCountBridge(
    _: ?*anyopaque,
    _: ?*anyopaque,
) callconv(.c) i32 {
    return scrollbackCount();
}

export fn Java_uk_laurencegouws_terminal_TerminalNativeBridge_nativeCurrentSessionScrollbackOffsetBridge(
    _: ?*anyopaque,
    _: ?*anyopaque,
) callconv(.c) i32 {
    return scrollbackOffset();
}

export fn Java_uk_laurencegouws_terminal_TerminalNativeBridge_nativeSetSessionScrollbackOffsetBridge(
    _: ?*anyopaque,
    _: ?*anyopaque,
    offsetRows: i32,
) callconv(.c) i32 {
    return setScrollbackOffset(offsetRows);
}

export fn Java_uk_laurencegouws_terminal_TerminalNativeBridge_nativeFollowSessionLiveBottomBridge(
    _: ?*anyopaque,
    _: ?*anyopaque,
) callconv(.c) i32 {
    return followLiveBottom();
}
