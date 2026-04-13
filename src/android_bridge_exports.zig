const android_runtime_bridge = @import("platform/android_runtime_bridge.zig");
const std = @import("std");
const jni = @cImport({
    @cInclude("jni.h");
});

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

fn tickProductShellFrameBridge() i32 {
    return android_runtime_bridge.tickProductShellFrame();
}

fn sendShellCodepointBridge(codepoint: i32) i32 {
    return android_runtime_bridge.sendShellCodepoint(codepoint);
}

fn currentShellVisibleRowsBridge() i32 {
    return android_runtime_bridge.currentShellVisibleRows();
}

fn currentShellVisibleColsBridge() i32 {
    return android_runtime_bridge.currentShellVisibleCols();
}

fn currentShellScrollbackCountBridge() i32 {
    return android_runtime_bridge.currentShellScrollbackCount();
}

fn currentShellScrollbackOffsetBridge() i32 {
    return android_runtime_bridge.currentShellScrollbackOffset();
}

fn setShellScrollbackOffsetBridge(offset_rows: i32) i32 {
    return android_runtime_bridge.setShellScrollbackOffset(offset_rows);
}

fn followShellLiveBottomBridge() i32 {
    return android_runtime_bridge.followShellLiveBottom();
}

fn beginShellWordSelectionAtVisibleCellBridge(row: i32, col: i32) i32 {
    return android_runtime_bridge.beginShellWordSelectionAtVisibleCell(row, col);
}

fn extendShellSelectionGestureToVisibleCellBridge(row: i32, col: i32) i32 {
    return android_runtime_bridge.extendShellSelectionGestureToVisibleCell(row, col);
}

fn finishShellSelectionGestureBridge() i32 {
    return android_runtime_bridge.finishShellSelectionGesture();
}

fn clearShellSelectionBridge() i32 {
    return android_runtime_bridge.clearShellSelection();
}

fn updateShellSelectionStartAtVisibleCellBridge(row: i32, col: i32) i32 {
    return android_runtime_bridge.updateShellSelectionStartAtVisibleCell(row, col);
}

fn updateShellSelectionEndAtVisibleCellBridge(row: i32, col: i32) i32 {
    return android_runtime_bridge.updateShellSelectionEndAtVisibleCell(row, col);
}

fn currentShellSelectionActiveBridge() bool {
    return android_runtime_bridge.currentShellSelectionActive();
}

fn currentShellSelectionRectLeftBridge() i32 {
    return android_runtime_bridge.currentShellSelectionRectLeft();
}

fn currentShellSelectionRectTopBridge() i32 {
    return android_runtime_bridge.currentShellSelectionRectTop();
}

fn currentShellSelectionRectRightBridge() i32 {
    return android_runtime_bridge.currentShellSelectionRectRight();
}

fn currentShellSelectionRectBottomBridge() i32 {
    return android_runtime_bridge.currentShellSelectionRectBottom();
}

fn currentShellSelectionStartRectLeftBridge() i32 {
    return android_runtime_bridge.currentShellSelectionStartRectLeft();
}

fn currentShellSelectionStartRectTopBridge() i32 {
    return android_runtime_bridge.currentShellSelectionStartRectTop();
}

fn currentShellSelectionStartRectRightBridge() i32 {
    return android_runtime_bridge.currentShellSelectionStartRectRight();
}

fn currentShellSelectionStartRectBottomBridge() i32 {
    return android_runtime_bridge.currentShellSelectionStartRectBottom();
}

fn currentShellSelectionEndRectLeftBridge() i32 {
    return android_runtime_bridge.currentShellSelectionEndRectLeft();
}

fn currentShellSelectionEndRectTopBridge() i32 {
    return android_runtime_bridge.currentShellSelectionEndRectTop();
}

fn currentShellSelectionEndRectRightBridge() i32 {
    return android_runtime_bridge.currentShellSelectionEndRectRight();
}

fn currentShellSelectionEndRectBottomBridge() i32 {
    return android_runtime_bridge.currentShellSelectionEndRectBottom();
}

fn sharedShellRendererActiveBridge() bool {
    return android_runtime_bridge.sharedShellRendererActive();
}

fn currentShellSelectionTextBytesBridge(env: ?*anyopaque) ?*anyopaque {
    const jenv_ptr: ?*jni.JNIEnv = @ptrCast(@alignCast(env));
    const jenv = jenv_ptr orelse return null;
    const fns = jenv.*.*;
    const selection = android_runtime_bridge.copyShellSelectionTextAlloc(std.heap.c_allocator) catch return null;
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

export fn Java_dev_zide_terminal_TerminalNativeBridge_nativeOnCreateBridge(
    _: ?*anyopaque,
    _: ?*anyopaque,
) callconv(.c) i64 {
    return onCreateBridge();
}

export fn Java_dev_zide_terminal_TerminalNativeBridge_nativeOnStartBridge(
    _: ?*anyopaque,
    _: ?*anyopaque,
) callconv(.c) i64 {
    return onStartBridge();
}

export fn Java_dev_zide_terminal_TerminalNativeBridge_nativeOnResumeBridge(
    _: ?*anyopaque,
    _: ?*anyopaque,
) callconv(.c) i64 {
    return onResumeBridge();
}

export fn Java_dev_zide_terminal_TerminalNativeBridge_nativeOnPauseBridge(
    _: ?*anyopaque,
    _: ?*anyopaque,
) callconv(.c) i64 {
    return onPauseBridge();
}

export fn Java_dev_zide_terminal_TerminalNativeBridge_nativeOnStopBridge(
    _: ?*anyopaque,
    _: ?*anyopaque,
) callconv(.c) i64 {
    return onStopBridge();
}

export fn Java_dev_zide_terminal_TerminalNativeBridge_nativeOnWindowFocusBridge(
    _: ?*anyopaque,
    _: ?*anyopaque,
    focused: bool,
) callconv(.c) i64 {
    return onWindowFocusBridge(focused);
}

export fn Java_dev_zide_terminal_TerminalNativeBridge_nativeOnSurfaceAvailableBridge(
    env: ?*anyopaque,
    _: ?*anyopaque,
    surface: ?*anyopaque,
    width: i32,
    height: i32,
) callconv(.c) i64 {
    return onSurfaceAvailableBridge(env, surface, width, height);
}

export fn Java_dev_zide_terminal_TerminalNativeBridge_nativeOnSurfaceDestroyedBridge(
    _: ?*anyopaque,
    _: ?*anyopaque,
) callconv(.c) i64 {
    return onSurfaceDestroyedBridge();
}

export fn Java_dev_zide_terminal_TerminalNativeBridge_nativeOnSurfaceRedrawNeededBridge(
    _: ?*anyopaque,
    _: ?*anyopaque,
) callconv(.c) i64 {
    return onSurfaceRedrawNeededBridge();
}

export fn Java_dev_zide_terminal_TerminalNativeBridge_nativeOnVisibleViewportBridge(
    _: ?*anyopaque,
    _: ?*anyopaque,
    width: i32,
    height: i32,
    ime_visible: bool,
) callconv(.c) i64 {
    return onVisibleViewportBridge(width, height, ime_visible);
}

export fn Java_dev_zide_terminal_TerminalNativeBridge_nativeApplyTerminalPinchZoomBridge(
    _: ?*anyopaque,
    _: ?*anyopaque,
    scale_factor: f32,
) callconv(.c) i32 {
    return applyTerminalPinchZoomBridge(scale_factor);
}

export fn Java_dev_zide_terminal_TerminalNativeBridge_nativeSetTerminalPinchActiveBridge(
    _: ?*anyopaque,
    _: ?*anyopaque,
    active: bool,
) callconv(.c) i32 {
    return setTerminalPinchActiveBridge(active);
}

export fn Java_dev_zide_terminal_TerminalNativeBridge_nativeCurrentWindowTokenBridge(
    _: ?*anyopaque,
    _: ?*anyopaque,
) callconv(.c) i64 {
    return currentWindowTokenBridge();
}

export fn Java_dev_zide_terminal_TerminalNativeBridge_nativeCurrentSurfaceEpochBridge(
    _: ?*anyopaque,
    _: ?*anyopaque,
) callconv(.c) i64 {
    return currentSurfaceEpochBridge();
}

export fn Java_dev_zide_terminal_TerminalNativeBridge_nativeCurrentSurfaceTransitionBridge(
    _: ?*anyopaque,
    _: ?*anyopaque,
) callconv(.c) i32 {
    return currentSurfaceTransitionBridge();
}

export fn Java_dev_zide_terminal_TerminalNativeBridge_nativeCurrentRendererStatusBridge(
    _: ?*anyopaque,
    _: ?*anyopaque,
) callconv(.c) i32 {
    return currentRendererStatusBridge();
}

export fn Java_dev_zide_terminal_TerminalNativeBridge_nativeCurrentRendererSwapCountBridge(
    _: ?*anyopaque,
    _: ?*anyopaque,
) callconv(.c) i64 {
    return currentRendererSwapCountBridge();
}

export fn Java_dev_zide_terminal_TerminalNativeBridge_nativeCurrentRendererBoundEpochBridge(
    _: ?*anyopaque,
    _: ?*anyopaque,
) callconv(.c) i64 {
    return currentRendererBoundEpochBridge();
}

export fn Java_dev_zide_terminal_TerminalNativeBridge_nativeCurrentRendererContextCreateCountBridge(
    _: ?*anyopaque,
    _: ?*anyopaque,
) callconv(.c) i64 {
    return currentRendererContextCreateCountBridge();
}

export fn Java_dev_zide_terminal_TerminalNativeBridge_nativeCurrentRendererSurfaceCreateCountBridge(
    _: ?*anyopaque,
    _: ?*anyopaque,
) callconv(.c) i64 {
    return currentRendererSurfaceCreateCountBridge();
}

export fn Java_dev_zide_terminal_TerminalNativeBridge_nativeCurrentRendererTextureCreateCountBridge(
    _: ?*anyopaque,
    _: ?*anyopaque,
) callconv(.c) i64 {
    return currentRendererTextureCreateCountBridge();
}

export fn Java_dev_zide_terminal_TerminalNativeBridge_nativeCurrentRendererTextureAliveBridge(
    _: ?*anyopaque,
    _: ?*anyopaque,
) callconv(.c) u8 {
    return currentRendererTextureAliveBridge();
}

export fn Java_dev_zide_terminal_TerminalNativeBridge_nativeCurrentRendererTextureUploadCountBridge(
    _: ?*anyopaque,
    _: ?*anyopaque,
) callconv(.c) i64 {
    return currentRendererTextureUploadCountBridge();
}

export fn Java_dev_zide_terminal_TerminalNativeBridge_nativeCurrentRendererTextureUpdateCountBridge(
    _: ?*anyopaque,
    _: ?*anyopaque,
) callconv(.c) i64 {
    return currentRendererTextureUpdateCountBridge();
}

export fn Java_dev_zide_terminal_TerminalNativeBridge_nativeCurrentRendererTextureResizeCountBridge(
    _: ?*anyopaque,
    _: ?*anyopaque,
) callconv(.c) i64 {
    return currentRendererTextureResizeCountBridge();
}

export fn Java_dev_zide_terminal_TerminalNativeBridge_nativeCurrentRendererTextureWidthBridge(
    _: ?*anyopaque,
    _: ?*anyopaque,
) callconv(.c) i32 {
    return currentRendererTextureWidthBridge();
}

export fn Java_dev_zide_terminal_TerminalNativeBridge_nativeCurrentRendererTextureHeightBridge(
    _: ?*anyopaque,
    _: ?*anyopaque,
) callconv(.c) i32 {
    return currentRendererTextureHeightBridge();
}

export fn Java_dev_zide_terminal_TerminalNativeBridge_nativeRestartShellSessionBridge(
    _: ?*anyopaque,
    _: ?*anyopaque,
) callconv(.c) i32 {
    return restartShellSessionBridge();
}

export fn Java_dev_zide_terminal_TerminalNativeBridge_nativePollShellSessionBridge(
    _: ?*anyopaque,
    _: ?*anyopaque,
) callconv(.c) i32 {
    return pollShellSessionBridge();
}

export fn Java_dev_zide_terminal_TerminalNativeBridge_nativeIsShellSessionAliveBridge(
    _: ?*anyopaque,
    _: ?*anyopaque,
) callconv(.c) bool {
    return isShellSessionAliveBridge();
}

export fn Java_dev_zide_terminal_TerminalNativeBridge_nativeTickProductShellFrameBridge(
    _: ?*anyopaque,
    _: ?*anyopaque,
) callconv(.c) i32 {
    return tickProductShellFrameBridge();
}

export fn Java_dev_zide_terminal_TerminalNativeBridge_nativeSendShellCodepointBridge(
    _: ?*anyopaque,
    _: ?*anyopaque,
    codepoint: i32,
) callconv(.c) i32 {
    return sendShellCodepointBridge(codepoint);
}

export fn Java_dev_zide_terminal_TerminalNativeBridge_nativeCurrentShellVisibleRowsBridge(
    _: ?*anyopaque,
    _: ?*anyopaque,
) callconv(.c) i32 {
    return currentShellVisibleRowsBridge();
}

export fn Java_dev_zide_terminal_TerminalNativeBridge_nativeCurrentShellVisibleColsBridge(
    _: ?*anyopaque,
    _: ?*anyopaque,
) callconv(.c) i32 {
    return currentShellVisibleColsBridge();
}

export fn Java_dev_zide_terminal_TerminalNativeBridge_nativeCurrentShellScrollbackCountBridge(
    _: ?*anyopaque,
    _: ?*anyopaque,
) callconv(.c) i32 {
    return currentShellScrollbackCountBridge();
}

export fn Java_dev_zide_terminal_TerminalNativeBridge_nativeCurrentShellScrollbackOffsetBridge(
    _: ?*anyopaque,
    _: ?*anyopaque,
) callconv(.c) i32 {
    return currentShellScrollbackOffsetBridge();
}

export fn Java_dev_zide_terminal_TerminalNativeBridge_nativeSetShellScrollbackOffsetBridge(
    _: ?*anyopaque,
    _: ?*anyopaque,
    offset_rows: i32,
) callconv(.c) i32 {
    return setShellScrollbackOffsetBridge(offset_rows);
}

export fn Java_dev_zide_terminal_TerminalNativeBridge_nativeFollowShellLiveBottomBridge(
    _: ?*anyopaque,
    _: ?*anyopaque,
) callconv(.c) i32 {
    return followShellLiveBottomBridge();
}

export fn Java_dev_zide_terminal_TerminalNativeBridge_nativeBeginShellWordSelectionAtVisibleCellBridge(
    _: ?*anyopaque,
    _: ?*anyopaque,
    row: i32,
    col: i32,
) callconv(.c) i32 {
    return beginShellWordSelectionAtVisibleCellBridge(row, col);
}

export fn Java_dev_zide_terminal_TerminalNativeBridge_nativeExtendShellSelectionGestureToVisibleCellBridge(
    _: ?*anyopaque,
    _: ?*anyopaque,
    row: i32,
    col: i32,
) callconv(.c) i32 {
    return extendShellSelectionGestureToVisibleCellBridge(row, col);
}

export fn Java_dev_zide_terminal_TerminalNativeBridge_nativeFinishShellSelectionGestureBridge(
    _: ?*anyopaque,
    _: ?*anyopaque,
) callconv(.c) i32 {
    return finishShellSelectionGestureBridge();
}

export fn Java_dev_zide_terminal_TerminalNativeBridge_nativeClearShellSelectionBridge(
    _: ?*anyopaque,
    _: ?*anyopaque,
) callconv(.c) i32 {
    return clearShellSelectionBridge();
}

export fn Java_dev_zide_terminal_TerminalNativeBridge_nativeUpdateShellSelectionStartAtVisibleCellBridge(
    _: ?*anyopaque,
    _: ?*anyopaque,
    row: i32,
    col: i32,
) callconv(.c) i32 {
    return updateShellSelectionStartAtVisibleCellBridge(row, col);
}

export fn Java_dev_zide_terminal_TerminalNativeBridge_nativeUpdateShellSelectionEndAtVisibleCellBridge(
    _: ?*anyopaque,
    _: ?*anyopaque,
    row: i32,
    col: i32,
) callconv(.c) i32 {
    return updateShellSelectionEndAtVisibleCellBridge(row, col);
}

export fn Java_dev_zide_terminal_TerminalNativeBridge_nativeCurrentShellSelectionActiveBridge(
    _: ?*anyopaque,
    _: ?*anyopaque,
) callconv(.c) bool {
    return currentShellSelectionActiveBridge();
}

export fn Java_dev_zide_terminal_TerminalNativeBridge_nativeCurrentShellSelectionRectLeftBridge(
    _: ?*anyopaque,
    _: ?*anyopaque,
) callconv(.c) i32 {
    return currentShellSelectionRectLeftBridge();
}

export fn Java_dev_zide_terminal_TerminalNativeBridge_nativeCurrentShellSelectionRectTopBridge(
    _: ?*anyopaque,
    _: ?*anyopaque,
) callconv(.c) i32 {
    return currentShellSelectionRectTopBridge();
}

export fn Java_dev_zide_terminal_TerminalNativeBridge_nativeCurrentShellSelectionRectRightBridge(
    _: ?*anyopaque,
    _: ?*anyopaque,
) callconv(.c) i32 {
    return currentShellSelectionRectRightBridge();
}

export fn Java_dev_zide_terminal_TerminalNativeBridge_nativeCurrentShellSelectionRectBottomBridge(
    _: ?*anyopaque,
    _: ?*anyopaque,
) callconv(.c) i32 {
    return currentShellSelectionRectBottomBridge();
}

export fn Java_dev_zide_terminal_TerminalNativeBridge_nativeCurrentShellSelectionStartRectLeftBridge(
    _: ?*anyopaque,
    _: ?*anyopaque,
) callconv(.c) i32 {
    return currentShellSelectionStartRectLeftBridge();
}

export fn Java_dev_zide_terminal_TerminalNativeBridge_nativeCurrentShellSelectionStartRectTopBridge(
    _: ?*anyopaque,
    _: ?*anyopaque,
) callconv(.c) i32 {
    return currentShellSelectionStartRectTopBridge();
}

export fn Java_dev_zide_terminal_TerminalNativeBridge_nativeCurrentShellSelectionStartRectRightBridge(
    _: ?*anyopaque,
    _: ?*anyopaque,
) callconv(.c) i32 {
    return currentShellSelectionStartRectRightBridge();
}

export fn Java_dev_zide_terminal_TerminalNativeBridge_nativeCurrentShellSelectionStartRectBottomBridge(
    _: ?*anyopaque,
    _: ?*anyopaque,
) callconv(.c) i32 {
    return currentShellSelectionStartRectBottomBridge();
}

export fn Java_dev_zide_terminal_TerminalNativeBridge_nativeCurrentShellSelectionEndRectLeftBridge(
    _: ?*anyopaque,
    _: ?*anyopaque,
) callconv(.c) i32 {
    return currentShellSelectionEndRectLeftBridge();
}

export fn Java_dev_zide_terminal_TerminalNativeBridge_nativeCurrentShellSelectionEndRectTopBridge(
    _: ?*anyopaque,
    _: ?*anyopaque,
) callconv(.c) i32 {
    return currentShellSelectionEndRectTopBridge();
}

export fn Java_dev_zide_terminal_TerminalNativeBridge_nativeCurrentShellSelectionEndRectRightBridge(
    _: ?*anyopaque,
    _: ?*anyopaque,
) callconv(.c) i32 {
    return currentShellSelectionEndRectRightBridge();
}

export fn Java_dev_zide_terminal_TerminalNativeBridge_nativeCurrentShellSelectionEndRectBottomBridge(
    _: ?*anyopaque,
    _: ?*anyopaque,
) callconv(.c) i32 {
    return currentShellSelectionEndRectBottomBridge();
}

export fn Java_dev_zide_terminal_TerminalNativeBridge_nativeCurrentShellSelectionTextBytesBridge(
    env: ?*anyopaque,
    _: ?*anyopaque,
) callconv(.c) ?*anyopaque {
    return currentShellSelectionTextBytesBridge(env);
}

export fn Java_dev_zide_terminal_TerminalNativeBridge_nativeSharedShellRendererActiveBridge(
    _: ?*anyopaque,
    _: ?*anyopaque,
) callconv(.c) bool {
    return sharedShellRendererActiveBridge();
}
