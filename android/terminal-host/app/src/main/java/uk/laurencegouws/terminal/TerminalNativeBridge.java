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

    public static native int nativePollSessionBridge();

    public static native boolean nativeIsSessionAliveBridge();

    public static native int nativeTickProductShellFrameBridge();

    public static native int nativeSendSessionCodepointBridge(int codepoint);

    public static native int nativeCurrentSessionVisibleRowsBridge();

    public static native int nativeCurrentSessionVisibleColsBridge();

    public static native int nativeCurrentSessionScrollbackCountBridge();

    public static native int nativeCurrentSessionScrollbackOffsetBridge();

    public static native int nativeSetSessionScrollbackOffsetBridge(int offsetRows);

    public static native int nativeFollowSessionLiveBottomBridge();

    public static native int nativeBeginSelectionWordAtVisibleCellBridge(int row, int col);

    public static native int nativeExtendSelectionGestureToVisibleCellBridge(int row, int col);

    public static native int nativeFinishSelectionGestureBridge();

    public static native int nativeClearSelectionBridge();

    public static native int nativeUpdateSelectionStartAtVisibleCellBridge(int row, int col);

    public static native int nativeUpdateSelectionEndAtVisibleCellBridge(int row, int col);

    public static native boolean nativeCurrentSelectionActiveBridge();

    public static native int nativeCurrentSelectionRectLeftBridge();

    public static native int nativeCurrentSelectionRectTopBridge();

    public static native int nativeCurrentSelectionRectRightBridge();

    public static native int nativeCurrentSelectionRectBottomBridge();

    public static native int nativeCurrentSelectionStartRectLeftBridge();

    public static native int nativeCurrentSelectionStartRectTopBridge();

    public static native int nativeCurrentSelectionStartRectRightBridge();

    public static native int nativeCurrentSelectionStartRectBottomBridge();

    public static native int nativeCurrentSelectionEndRectLeftBridge();

    public static native int nativeCurrentSelectionEndRectTopBridge();

    public static native int nativeCurrentSelectionEndRectRightBridge();

    public static native int nativeCurrentSelectionEndRectBottomBridge();

    public static native byte[] nativeCurrentSelectionTextBytesBridge();

    public static native boolean nativeSharedShellRendererActiveBridge();
}
