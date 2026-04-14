const android_runtime_bridge = @import("../platform/android_runtime_bridge.zig");
const std = @import("std");
const jni = @cImport({
    @cInclude("jni.h");
});

fn beginWordSelectionAtVisibleCell(row: i32, col: i32) i32 {
    return android_runtime_bridge.beginWordSelectionAtCell(row, col);
}

fn extendSelectionGestureToVisibleCell(row: i32, col: i32) i32 {
    return android_runtime_bridge.extendSelectionGestureToCell(row, col);
}

fn finishSelectionGesture() i32 {
    return android_runtime_bridge.finishSelectionGesture();
}

fn clearSelection() i32 {
    return android_runtime_bridge.clearSelection();
}

fn updateSelectionStartAtVisibleCell(row: i32, col: i32) i32 {
    return android_runtime_bridge.updateSelectionStartAtCell(row, col);
}

fn updateSelectionEndAtVisibleCell(row: i32, col: i32) i32 {
    return android_runtime_bridge.updateSelectionEndAtCell(row, col);
}

fn selectionActive() bool {
    return android_runtime_bridge.selectionActive();
}

fn selectionRectLeft() i32 {
    return android_runtime_bridge.selectionRectLeft();
}

fn selectionRectTop() i32 {
    return android_runtime_bridge.selectionRectTop();
}

fn selectionRectRight() i32 {
    return android_runtime_bridge.selectionRectRight();
}

fn selectionRectBottom() i32 {
    return android_runtime_bridge.selectionRectBottom();
}

fn selectionStartRectLeft() i32 {
    return android_runtime_bridge.selectionStartRectLeft();
}

fn selectionStartRectTop() i32 {
    return android_runtime_bridge.selectionStartRectTop();
}

fn selectionStartRectRight() i32 {
    return android_runtime_bridge.selectionStartRectRight();
}

fn selectionStartRectBottom() i32 {
    return android_runtime_bridge.selectionStartRectBottom();
}

fn selectionEndRectLeft() i32 {
    return android_runtime_bridge.selectionEndRectLeft();
}

fn selectionEndRectTop() i32 {
    return android_runtime_bridge.selectionEndRectTop();
}

fn selectionEndRectRight() i32 {
    return android_runtime_bridge.selectionEndRectRight();
}

fn selectionEndRectBottom() i32 {
    return android_runtime_bridge.selectionEndRectBottom();
}

fn selectionTextBytes(env: ?*anyopaque) ?*anyopaque {
    const jenvPtr: ?*jni.JNIEnv = @ptrCast(@alignCast(env));
    const jenv = jenvPtr orelse return null;
    const fns = jenv.*.*;
    const selection = android_runtime_bridge.selectionTextAlloc(std.heap.c_allocator) catch return null;
    const bytes = selection orelse return null;
    defer std.heap.c_allocator.free(bytes);

    const array = fns.NewByteArray.?(jenv, @intCast(bytes.len)) orelse return null;
    if (bytes.len > 0) {
        fns.SetByteArrayRegion.?(
            jenv,
            array,
            0,
            @intCast(bytes.len),
            @ptrCast(bytes.ptr),
        );
    }
    return array;
}

export fn Java_uk_laurencegouws_terminal_TerminalNativeBridge_nativeBeginSelectionWordAtVisibleCellBridge(
    _: ?*anyopaque,
    _: ?*anyopaque,
    row: i32,
    col: i32,
) callconv(.c) i32 {
    return beginWordSelectionAtVisibleCell(row, col);
}

export fn Java_uk_laurencegouws_terminal_TerminalNativeBridge_nativeExtendSelectionGestureToVisibleCellBridge(
    _: ?*anyopaque,
    _: ?*anyopaque,
    row: i32,
    col: i32,
) callconv(.c) i32 {
    return extendSelectionGestureToVisibleCell(row, col);
}

export fn Java_uk_laurencegouws_terminal_TerminalNativeBridge_nativeFinishSelectionGestureBridge(
    _: ?*anyopaque,
    _: ?*anyopaque,
) callconv(.c) i32 {
    return finishSelectionGesture();
}

export fn Java_uk_laurencegouws_terminal_TerminalNativeBridge_nativeClearSelectionBridge(
    _: ?*anyopaque,
    _: ?*anyopaque,
) callconv(.c) i32 {
    return clearSelection();
}

export fn Java_uk_laurencegouws_terminal_TerminalNativeBridge_nativeUpdateSelectionStartAtVisibleCellBridge(
    _: ?*anyopaque,
    _: ?*anyopaque,
    row: i32,
    col: i32,
) callconv(.c) i32 {
    return updateSelectionStartAtVisibleCell(row, col);
}

export fn Java_uk_laurencegouws_terminal_TerminalNativeBridge_nativeUpdateSelectionEndAtVisibleCellBridge(
    _: ?*anyopaque,
    _: ?*anyopaque,
    row: i32,
    col: i32,
) callconv(.c) i32 {
    return updateSelectionEndAtVisibleCell(row, col);
}

export fn Java_uk_laurencegouws_terminal_TerminalNativeBridge_nativeCurrentSelectionActiveBridge(
    _: ?*anyopaque,
    _: ?*anyopaque,
) callconv(.c) bool {
    return selectionActive();
}

export fn Java_uk_laurencegouws_terminal_TerminalNativeBridge_nativeCurrentSelectionRectLeftBridge(
    _: ?*anyopaque,
    _: ?*anyopaque,
) callconv(.c) i32 {
    return selectionRectLeft();
}

export fn Java_uk_laurencegouws_terminal_TerminalNativeBridge_nativeCurrentSelectionRectTopBridge(
    _: ?*anyopaque,
    _: ?*anyopaque,
) callconv(.c) i32 {
    return selectionRectTop();
}

export fn Java_uk_laurencegouws_terminal_TerminalNativeBridge_nativeCurrentSelectionRectRightBridge(
    _: ?*anyopaque,
    _: ?*anyopaque,
) callconv(.c) i32 {
    return selectionRectRight();
}

export fn Java_uk_laurencegouws_terminal_TerminalNativeBridge_nativeCurrentSelectionRectBottomBridge(
    _: ?*anyopaque,
    _: ?*anyopaque,
) callconv(.c) i32 {
    return selectionRectBottom();
}

export fn Java_uk_laurencegouws_terminal_TerminalNativeBridge_nativeCurrentSelectionStartRectLeftBridge(
    _: ?*anyopaque,
    _: ?*anyopaque,
) callconv(.c) i32 {
    return selectionStartRectLeft();
}

export fn Java_uk_laurencegouws_terminal_TerminalNativeBridge_nativeCurrentSelectionStartRectTopBridge(
    _: ?*anyopaque,
    _: ?*anyopaque,
) callconv(.c) i32 {
    return selectionStartRectTop();
}

export fn Java_uk_laurencegouws_terminal_TerminalNativeBridge_nativeCurrentSelectionStartRectRightBridge(
    _: ?*anyopaque,
    _: ?*anyopaque,
) callconv(.c) i32 {
    return selectionStartRectRight();
}

export fn Java_uk_laurencegouws_terminal_TerminalNativeBridge_nativeCurrentSelectionStartRectBottomBridge(
    _: ?*anyopaque,
    _: ?*anyopaque,
) callconv(.c) i32 {
    return selectionStartRectBottom();
}

export fn Java_uk_laurencegouws_terminal_TerminalNativeBridge_nativeCurrentSelectionEndRectLeftBridge(
    _: ?*anyopaque,
    _: ?*anyopaque,
) callconv(.c) i32 {
    return selectionEndRectLeft();
}

export fn Java_uk_laurencegouws_terminal_TerminalNativeBridge_nativeCurrentSelectionEndRectTopBridge(
    _: ?*anyopaque,
    _: ?*anyopaque,
) callconv(.c) i32 {
    return selectionEndRectTop();
}

export fn Java_uk_laurencegouws_terminal_TerminalNativeBridge_nativeCurrentSelectionEndRectRightBridge(
    _: ?*anyopaque,
    _: ?*anyopaque,
) callconv(.c) i32 {
    return selectionEndRectRight();
}

export fn Java_uk_laurencegouws_terminal_TerminalNativeBridge_nativeCurrentSelectionEndRectBottomBridge(
    _: ?*anyopaque,
    _: ?*anyopaque,
) callconv(.c) i32 {
    return selectionEndRectBottom();
}

export fn Java_uk_laurencegouws_terminal_TerminalNativeBridge_nativeCurrentSelectionTextBytesBridge(
    env: ?*anyopaque,
    _: ?*anyopaque,
) callconv(.c) ?*anyopaque {
    return selectionTextBytes(env);
}
