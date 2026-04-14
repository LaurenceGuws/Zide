package uk.laurencegouws.terminal.debug;

/**
 * Formats debug-only Android host snapshots for logcat and the in-app debug surface.
 *
 * <p>This class must stay a pure formatter. It should not read Android state, call native code, or
 * own product behavior.
 */
public final class AndroidDebugFormatter {
    public static final class SurfaceEventSnapshot {
        public final long seq;
        public final long token;
        public final long epoch;
        public final String transition;
        public final String glesStatus;
        public final long glesSwapCount;
        public final long glesBoundEpoch;
        public final long glesContextCreateCount;
        public final long glesSurfaceCreateCount;
        public final long glesTextureCreateCount;
        public final boolean glesTextureAlive;
        public final long glesTextureUploadCount;
        public final long glesTextureUpdateCount;
        public final long glesTextureResizeCount;
        public final int glesTextureWidth;
        public final int glesTextureHeight;

        public SurfaceEventSnapshot(
                long seq,
                long token,
                long epoch,
                String transition,
                String glesStatus,
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
            this.seq = seq;
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

    public static final class StatusSnapshot {
        public final String state;
        public final boolean nativeLoaded;
        public final boolean windowFocused;
        public final boolean imeVisible;
        public final boolean surfaceValid;
        public final int surfaceWidth;
        public final int surfaceHeight;
        public final int viewportWidth;
        public final int viewportHeight;
        public final String installState;
        public final String installDetail;
        public final String userlandState;
        public final String userlandFormat;
        public final String userlandArtifact;
        public final String userlandVersion;
        public final String userlandProvider;
        public final boolean userlandLaunchReady;
        public final boolean userlandExpectedCurrent;
        public final String glesStatus;
        public final long glesSwapCount;
        public final long glesBoundEpoch;
        public final long glesContextCreateCount;
        public final long glesSurfaceCreateCount;
        public final long glesTextureCreateCount;
        public final boolean glesTextureAlive;
        public final long glesTextureUploadCount;
        public final long glesTextureUpdateCount;
        public final long glesTextureResizeCount;
        public final int glesTextureWidth;
        public final int glesTextureHeight;

        public StatusSnapshot(
                String state,
                boolean nativeLoaded,
                boolean windowFocused,
                boolean imeVisible,
                boolean surfaceValid,
                int surfaceWidth,
                int surfaceHeight,
                int viewportWidth,
                int viewportHeight,
                String installState,
                String installDetail,
                String userlandState,
                String userlandFormat,
                String userlandArtifact,
                String userlandVersion,
                String userlandProvider,
                boolean userlandLaunchReady,
                boolean userlandExpectedCurrent,
                String glesStatus,
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
            this.state = state;
            this.nativeLoaded = nativeLoaded;
            this.windowFocused = windowFocused;
            this.imeVisible = imeVisible;
            this.surfaceValid = surfaceValid;
            this.surfaceWidth = surfaceWidth;
            this.surfaceHeight = surfaceHeight;
            this.viewportWidth = viewportWidth;
            this.viewportHeight = viewportHeight;
            this.installState = installState;
            this.installDetail = installDetail;
            this.userlandState = userlandState;
            this.userlandFormat = userlandFormat;
            this.userlandArtifact = userlandArtifact;
            this.userlandVersion = userlandVersion;
            this.userlandProvider = userlandProvider;
            this.userlandLaunchReady = userlandLaunchReady;
            this.userlandExpectedCurrent = userlandExpectedCurrent;
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

    private AndroidDebugFormatter() {
    }

    public static String formatSurfaceEvent(String event, SurfaceEventSnapshot s) {
        return event + " seq=" + s.seq +
                " token=0x" + Long.toHexString(s.token) +
                " epoch=" + s.epoch +
                " transition=" + s.transition +
                " gles=" + s.glesStatus +
                " glesSwaps=" + s.glesSwapCount +
                " glesBoundEpoch=" + s.glesBoundEpoch +
                " glesContextCreates=" + s.glesContextCreateCount +
                " glesSurfaceCreates=" + s.glesSurfaceCreateCount +
                " glesTextureCreates=" + s.glesTextureCreateCount +
                " glesTextureAlive=" + s.glesTextureAlive +
                " glesTextureUploads=" + s.glesTextureUploadCount +
                " glesTextureUpdates=" + s.glesTextureUpdateCount +
                " glesTextureResizes=" + s.glesTextureResizeCount +
                " glesTextureSize=" + s.glesTextureWidth + "x" + s.glesTextureHeight;
    }

    public static String formatStatus(StatusSnapshot s) {
        return "state=" + s.state +
                " nativeLoaded=" + s.nativeLoaded +
                " windowFocus=" + s.windowFocused +
                " imeVisible=" + s.imeVisible +
                "\n" +
                "surfaceValid=" + s.surfaceValid +
                " surfaceSize=" + s.surfaceWidth + "x" + s.surfaceHeight +
                " viewportSize=" + s.viewportWidth + "x" + s.viewportHeight +
                "\n" +
                "install=" + s.installState +
                " detail=" + s.installDetail +
                "\n" +
                "userland=" + s.userlandState +
                " launchReady=" + s.userlandLaunchReady +
                " expectedCurrent=" + s.userlandExpectedCurrent +
                " format=" + s.userlandFormat +
                "\n" +
                "artifact=" + s.userlandArtifact +
                " version=" + s.userlandVersion +
                " provider=" + s.userlandProvider +
                "\n" +
                "gles=" + s.glesStatus +
                " swaps=" + s.glesSwapCount +
                " boundEpoch=" + s.glesBoundEpoch +
                "\n" +
                "contextCreates=" + s.glesContextCreateCount +
                " surfaceCreates=" + s.glesSurfaceCreateCount +
                "\n" +
                "textureCreates=" + s.glesTextureCreateCount +
                " textureAlive=" + s.glesTextureAlive +
                "\n" +
                "textureUploads=" + s.glesTextureUploadCount +
                " textureUpdates=" + s.glesTextureUpdateCount +
                " textureResizes=" + s.glesTextureResizeCount +
                "\n" +
                "textureSize=" + s.glesTextureWidth + "x" + s.glesTextureHeight;
    }
}
