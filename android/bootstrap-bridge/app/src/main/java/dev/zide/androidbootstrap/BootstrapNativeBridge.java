package dev.zide.androidbootstrap;

import android.view.Surface;

final class BootstrapNativeBridge {
    static final class SurfaceStateSnapshot {
        final long token;
        final long epoch;
        final int transition;
        final int glesStatus;
        final long glesSwapCount;
        final long glesBoundEpoch;
        final long glesContextCreateCount;
        final long glesSurfaceCreateCount;
        final long glesTextureCreateCount;
        final boolean glesTextureAlive;
        final long glesTextureUploadCount;
        final long glesTextureUpdateCount;
        final long glesTextureResizeCount;
        final int glesTextureWidth;
        final int glesTextureHeight;

        SurfaceStateSnapshot(
                long token,
                long epoch,
                int transition,
                int glesStatus,
                long glesSwapCount,
                long glesBoundEpoch,
                long glesContextCreateCount,
                long glesSurfaceCreateCount,
                long glesTextureCreateCount,
                boolean glesTextureAlive,
                long glesTextureUploadCount,
                long glesTextureUpdateCount,
                long glesTextureResizeCount,
                int glesTextureWidth,
                int glesTextureHeight) {
            this.token = token;
            this.epoch = epoch;
            this.transition = transition;
            this.glesStatus = glesStatus;
            this.glesSwapCount = glesSwapCount;
            this.glesBoundEpoch = glesBoundEpoch;
            this.glesContextCreateCount = glesContextCreateCount;
            this.glesSurfaceCreateCount = glesSurfaceCreateCount;
            this.glesTextureCreateCount = glesTextureCreateCount;
            this.glesTextureAlive = glesTextureAlive;
            this.glesTextureUploadCount = glesTextureUploadCount;
            this.glesTextureUpdateCount = glesTextureUpdateCount;
            this.glesTextureResizeCount = glesTextureResizeCount;
            this.glesTextureWidth = glesTextureWidth;
            this.glesTextureHeight = glesTextureHeight;
        }
    }

    private static boolean nativeLoaded = false;
    private static String nativeLoadError = null;

    static {
        try {
            System.loadLibrary("zide_android_bridge");
            nativeLoaded = true;
        } catch (UnsatisfiedLinkError err) {
            nativeLoadError = err.toString();
        }
    }

    private BootstrapNativeBridge() {}

    static boolean isLoaded() {
        return nativeLoaded;
    }

    static String loadError() {
        return nativeLoadError;
    }

    static long onCreate() {
        return nativeLoaded ? nativeOnCreateBridge() : -1;
    }

    static long onStart() {
        return nativeLoaded ? nativeOnStartBridge() : -1;
    }

    static long onResume() {
        return nativeLoaded ? nativeOnResumeBridge() : -1;
    }

    static long onPause() {
        return nativeLoaded ? nativeOnPauseBridge() : -1;
    }

    static long onStop() {
        return nativeLoaded ? nativeOnStopBridge() : -1;
    }

    static long onWindowFocus(boolean focused) {
        return nativeLoaded ? nativeOnWindowFocusBridge(focused) : -1;
    }

    static long onSurfaceAvailable(Surface surface, int width, int height) {
        return nativeLoaded ? nativeOnSurfaceAvailableBridge(surface, width, height) : -1;
    }

    static long onSurfaceDestroyed() {
        return nativeLoaded ? nativeOnSurfaceDestroyedBridge() : -1;
    }

    static long onSurfaceRedrawNeeded() {
        return nativeLoaded ? nativeOnSurfaceRedrawNeededBridge() : -1;
    }

    static int restartShellSession() {
        return nativeLoaded ? nativeRestartShellSessionBridge() : 0;
    }

    static int pollShellSession() {
        return nativeLoaded ? nativePollShellSessionBridge() : 0;
    }

    static boolean isShellSessionAlive() {
        return nativeLoaded && nativeIsShellSessionAliveBridge();
    }

    static void sendShellCodepoint(int codepoint) {
        if (!nativeLoaded) return;
        nativeSendShellCodepointBridge(codepoint);
    }

    static SurfaceStateSnapshot currentSurfaceState() {
        if (!nativeLoaded) {
            return new SurfaceStateSnapshot(0, 0, 0, 0, 0, 0, 0, 0, 0, false, 0, 0, 0, 0, 0);
        }
        return new SurfaceStateSnapshot(
                nativeCurrentWindowTokenBridge(),
                nativeCurrentSurfaceEpochBridge(),
                nativeCurrentSurfaceTransitionBridge(),
                nativeCurrentGlesProbeStatusBridge(),
                nativeCurrentGlesProbeSwapCountBridge(),
                nativeCurrentGlesProbeBoundEpochBridge(),
                nativeCurrentGlesProbeContextCreateCountBridge(),
                nativeCurrentGlesProbeSurfaceCreateCountBridge(),
                nativeCurrentGlesProbeTextureCreateCountBridge(),
                nativeCurrentGlesProbeTextureAliveBridge(),
                nativeCurrentGlesProbeTextureUploadCountBridge(),
                nativeCurrentGlesProbeTextureUpdateCountBridge(),
                nativeCurrentGlesProbeTextureResizeCountBridge(),
                nativeCurrentGlesProbeTextureWidthBridge(),
                nativeCurrentGlesProbeTextureHeightBridge());
    }

    static String surfaceTransitionLabel(int transition) {
        return switch (transition) {
            case 1 -> "acquired";
            case 2 -> "replaced";
            case 3 -> "retired";
            default -> "unchanged";
        };
    }

    static String shellStartStatusLabel(int status) {
        return switch (status) {
            case 1 -> "started";
            case 2 -> "unsupported";
            case 3 -> "create-failed";
            case 4 -> "resize-failed";
            case 5 -> "start-failed";
            case 6 -> "send-failed";
            case 7 -> "poll-failed";
            case 8 -> "snapshot-failed";
            default -> "none";
        };
    }

    static String glesProbeStatusLabel(int status) {
        return switch (status) {
            case 1 -> "ready";
            case 2 -> "drawn";
            case 3 -> "surface-destroyed";
            case 4 -> "init-failed";
            case 5 -> "surface-failed";
            case 6 -> "make-current-failed";
            case 7 -> "swap-failed";
            default -> "unavailable";
        };
    }

    private static native long nativeOnCreateBridge();

    private static native long nativeOnStartBridge();

    private static native long nativeOnResumeBridge();

    private static native long nativeOnPauseBridge();

    private static native long nativeOnStopBridge();

    private static native long nativeOnWindowFocusBridge(boolean focused);

    private static native long nativeOnSurfaceAvailableBridge(Surface surface, int width, int height);

    private static native long nativeOnSurfaceDestroyedBridge();

    private static native long nativeOnSurfaceRedrawNeededBridge();

    private static native long nativeCurrentWindowTokenBridge();

    private static native long nativeCurrentSurfaceEpochBridge();

    private static native int nativeCurrentSurfaceTransitionBridge();

    private static native int nativeCurrentGlesProbeStatusBridge();

    private static native long nativeCurrentGlesProbeSwapCountBridge();

    private static native long nativeCurrentGlesProbeBoundEpochBridge();

    private static native long nativeCurrentGlesProbeContextCreateCountBridge();

    private static native long nativeCurrentGlesProbeSurfaceCreateCountBridge();

    private static native long nativeCurrentGlesProbeTextureCreateCountBridge();

    private static native boolean nativeCurrentGlesProbeTextureAliveBridge();

    private static native long nativeCurrentGlesProbeTextureUploadCountBridge();

    private static native long nativeCurrentGlesProbeTextureUpdateCountBridge();

    private static native long nativeCurrentGlesProbeTextureResizeCountBridge();

    private static native int nativeCurrentGlesProbeTextureWidthBridge();

    private static native int nativeCurrentGlesProbeTextureHeightBridge();

    private static native int nativeRestartShellSessionBridge();

    private static native int nativePollShellSessionBridge();

    private static native boolean nativeIsShellSessionAliveBridge();

    private static native int nativeSendShellCodepointBridge(int codepoint);
}
