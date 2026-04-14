package uk.laurencegouws.terminal;

import android.util.Log;
import android.view.Surface;

/** JNI bridge surface for terminal-host native integration. */
public final class TerminalNativeBridge {
    private static final String TAG = "ZideAndroidTerminal";
    private static final boolean NATIVE_LOADED;
    private static final String NATIVE_LOAD_ERROR;

    static {
        boolean loaded = false;
        String loadError = null;
        try {
            System.loadLibrary("zide_android_bridge");
            loaded = true;
        } catch (UnsatisfiedLinkError err) {
            loadError = err.toString();
            Log.e(TAG, "failed to load native bridge", err);
        }
        NATIVE_LOADED = loaded;
        NATIVE_LOAD_ERROR = loadError;
    }

    private TerminalNativeBridge() {
    }

    public static boolean nativeLoaded() {
        return NATIVE_LOADED;
    }

    public static String nativeLoadError() {
        return NATIVE_LOAD_ERROR;
    }

    public static native long nativeOnCreateBridge();

    public static native long nativeOnStartBridge();

    public static native long nativeOnResumeBridge();

    public static native long nativeOnPauseBridge();

    public static native long nativeOnStopBridge();

    public static native long nativeOnWindowFocusBridge(boolean focused);

    public static native long nativeOnSurfaceAvailableBridge(Surface surface, int width, int height);

    public static native long nativeOnSurfaceDestroyedBridge();

    public static native long nativeOnSurfaceRedrawNeededBridge();

    public static native long nativeOnVisibleViewportBridge(int width, int height, boolean imeVisible);

    public static native int nativeApplyTerminalPinchZoomBridge(float scaleFactor);

    public static native int nativeSetTerminalPinchActiveBridge(boolean active);

    public static native long nativeCurrentWindowTokenBridge();

    public static native long nativeCurrentSurfaceEpochBridge();

    public static native int nativeCurrentSurfaceTransitionBridge();

    public static native int nativeCurrentRendererStatusBridge();

    public static native long nativeCurrentRendererSwapCountBridge();

    public static native long nativeCurrentRendererBoundEpochBridge();

    public static native long nativeCurrentRendererContextCreateCountBridge();

    public static native long nativeCurrentRendererSurfaceCreateCountBridge();

    public static native long nativeCurrentRendererTextureCreateCountBridge();

    public static native boolean nativeCurrentRendererTextureAliveBridge();

    public static native long nativeCurrentRendererTextureUploadCountBridge();

    public static native long nativeCurrentRendererTextureUpdateCountBridge();

    public static native long nativeCurrentRendererTextureResizeCountBridge();

    public static native int nativeCurrentRendererTextureWidthBridge();

    public static native int nativeCurrentRendererTextureHeightBridge();

    public static native int nativeRestartSessionBridge();

    public static native int nativePollShellSessionBridge();

    public static native boolean nativeIsShellSessionAliveBridge();

    public static native int nativeTickProductShellFrameBridge();

    public static native int nativeSendShellCodepointBridge(int codepoint);

    public static native int nativeCurrentShellVisibleRowsBridge();

    public static native int nativeCurrentShellVisibleColsBridge();

    public static native int nativeCurrentShellScrollbackCountBridge();

    public static native int nativeCurrentShellScrollbackOffsetBridge();

    public static native int nativeSetShellScrollbackOffsetBridge(int offsetRows);

    public static native int nativeFollowShellLiveBottomBridge();

    public static native int nativeBeginShellWordSelectionAtVisibleCellBridge(int row, int col);

    public static native int nativeExtendShellSelectionGestureToVisibleCellBridge(int row, int col);

    public static native int nativeFinishShellSelectionGestureBridge();

    public static native int nativeClearShellSelectionBridge();

    public static native int nativeUpdateShellSelectionStartAtVisibleCellBridge(int row, int col);

    public static native int nativeUpdateShellSelectionEndAtVisibleCellBridge(int row, int col);

    public static native boolean nativeCurrentShellSelectionActiveBridge();

    public static native int nativeCurrentShellSelectionRectLeftBridge();

    public static native int nativeCurrentShellSelectionRectTopBridge();

    public static native int nativeCurrentShellSelectionRectRightBridge();

    public static native int nativeCurrentShellSelectionRectBottomBridge();

    public static native int nativeCurrentShellSelectionStartRectLeftBridge();

    public static native int nativeCurrentShellSelectionStartRectTopBridge();

    public static native int nativeCurrentShellSelectionStartRectRightBridge();

    public static native int nativeCurrentShellSelectionStartRectBottomBridge();

    public static native int nativeCurrentShellSelectionEndRectLeftBridge();

    public static native int nativeCurrentShellSelectionEndRectTopBridge();

    public static native int nativeCurrentShellSelectionEndRectRightBridge();

    public static native int nativeCurrentShellSelectionEndRectBottomBridge();

    public static native byte[] nativeCurrentShellSelectionTextBytesBridge();

    public static native boolean nativeSharedShellRendererActiveBridge();
}
