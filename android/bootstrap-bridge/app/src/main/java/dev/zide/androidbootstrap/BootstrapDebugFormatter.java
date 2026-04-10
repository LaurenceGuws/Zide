package dev.zide.androidbootstrap;

final class BootstrapDebugFormatter {
    static final class SurfaceEventSnapshot {
        final long seq;
        final long token;
        final long epoch;
        final String transition;
        final String glesStatus;
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

        SurfaceEventSnapshot(
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

    static final class StatusSnapshot {
        final String state;
        final boolean nativeLoaded;
        final boolean windowFocused;
        final boolean imeVisible;
        final boolean surfaceValid;
        final int surfaceWidth;
        final int surfaceHeight;
        final String glesStatus;
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

        StatusSnapshot(
                String state,
                boolean nativeLoaded,
                boolean windowFocused,
                boolean imeVisible,
                boolean surfaceValid,
                int surfaceWidth,
                int surfaceHeight,
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

    private BootstrapDebugFormatter() {
    }

    static String formatSurfaceEvent(String event, SurfaceEventSnapshot s) {
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

    static String formatStatus(StatusSnapshot s) {
        return "state=" + s.state +
                " nativeLoaded=" + s.nativeLoaded +
                " windowFocus=" + s.windowFocused +
                " imeVisible=" + s.imeVisible +
                "\n" +
                "surfaceValid=" + s.surfaceValid +
                " surfaceSize=" + s.surfaceWidth + "x" + s.surfaceHeight +
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
