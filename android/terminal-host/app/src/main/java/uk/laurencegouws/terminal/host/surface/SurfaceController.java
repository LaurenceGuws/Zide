package uk.laurencegouws.terminal.host.surface;

import android.graphics.PixelFormat;
import android.view.Gravity;
import android.view.SurfaceHolder;
import android.view.SurfaceView;
import android.view.View;
import android.view.ViewGroup;
import android.widget.FrameLayout;
import android.os.Handler;

import uk.laurencegouws.terminal.debug.AndroidDebugFormatter;

/** Owns SurfaceView host lifecycle, viewport notifications, and debug surface scheduling. */
public final class SurfaceController {
    /** Host callbacks for surface and viewport orchestration. */
    public interface Host {
        Handler handler();

        boolean nativeLoaded();

        boolean debugViewEnabled();

        FrameLayout productSurfaceContainer();

        SurfaceView surfaceView();

        void setSurfaceView(SurfaceView surfaceView);

        int surfaceHostGeneration();

        void setSurfaceHostGeneration(int generation);

        boolean surfaceRecreationScheduled();

        void setSurfaceRecreationScheduled(boolean scheduled);

        boolean surfaceResizeScheduled();

        void setSurfaceResizeScheduled(boolean scheduled);

        boolean shellStartScheduled();

        void setShellStartScheduled(boolean scheduled);

        int visibleViewportWidth();

        int visibleViewportHeight();

        void setVisibleViewportSize(int width, int height);

        int notifiedViewportWidth();

        int notifiedViewportHeight();

        boolean notifiedViewportImeVisible();

        void setNotifiedViewportSize(int width, int height, boolean imeVisible);

        boolean currentImeVisible();

        boolean shouldRunProductFrameLoop();

        void refreshProductScrollOverlay();

        void appendEvent(String event);

        void updateStatus(String statusLabel);

        void callNative(String event, long seq);

        void callNativeWithSurfaceState(String event, long seq, AndroidDebugFormatter.SurfaceEventSnapshot state);

        long nativeOnSurfaceAvailableBridge(SurfaceHolder holder, int width, int height);

        long nativeOnSurfaceDestroyedBridge();

        long nativeOnSurfaceRedrawNeededBridge();

        long nativeOnVisibleViewportBridge(int width, int height, boolean imeVisible);

        AndroidDebugFormatter.SurfaceEventSnapshot currentSurfaceStateSnapshot();

        void handleProductShellStateEvent(String statusLabel);

        void installSurfaceGestureHost(SurfaceView surfaceView);

        void reinstallSurfaceCallback(SurfaceView surfaceView, SurfaceHolder.Callback2 callback);

        SurfaceHolder.Callback2 surfaceCallback();
    }

    private final Host host;
    private boolean surfaceRedrawNeededDispatching;

    public SurfaceController(Host host) {
        this.host = host;
    }

    public void onResume(boolean recreateSurfaceOnce, boolean resizeSurfaceOnce, boolean startShellOnce) {
        maybeScheduleSurfaceRecreation(recreateSurfaceOnce);
        maybeScheduleSurfaceResize(resizeSurfaceOnce);
        maybeScheduleShellStart(startShellOnce);
        notifyProductShellResumed();
    }

    public void onPause() {
        dispatchNativePause();
    }

    public void onSurfaceCreated(SurfaceHolder holder) {
        appendSurfaceCreatedEvent(holder);
        updateSurfaceCreatedStatus();
    }

    public void onSurfaceChanged(SurfaceHolder holder, int format, int width, int height) {
        host.appendEvent(surfaceChangedEvent(format, width, height));
        final long seq = nativeSurfaceAvailableSeq(holder, width, height);
        dispatchNativeSurfaceAvailable(seq);
        postSurfaceChangedViewportNotification();
        host.handleProductShellStateEvent("surface-changed");
    }

    public void onSurfaceDestroyed(SurfaceHolder holder) {
        appendSurfaceDestroyedEvent();
        final long seq = nativeSurfaceDestroyedSeq();
        dispatchNativeSurfaceDestroyed(seq);
        updateSurfaceDestroyedStatus();
    }

    public void onSurfaceRedrawNeeded(SurfaceHolder holder) {
        if (surfaceRedrawNeededDispatching) {
            appendSurfaceRedrawReentrantSkippedEvent(holder);
            return;
        }
        surfaceRedrawNeededDispatching = true;
        appendSurfaceRedrawNeededEvent(holder);
        try {
            final long seq = nativeSurfaceRedrawNeededSeq();
            final AndroidDebugFormatter.SurfaceEventSnapshot state = host.currentSurfaceStateSnapshot();
            appendNativeSurfaceRedrawNeededEvent(seq, state);
            updateSurfaceRedrawNeededStatus();
        } finally {
            clearSurfaceRedrawNeededDispatching();
        }
    }

    public void installSurfaceView(String reason, SurfaceHolder.Callback2 callback) {
        removeExistingSurfaceViewIfPresent(reason, callback);

        incrementSurfaceHostGeneration();
        final SurfaceView nextSurfaceView = createAndAttachSurfaceView();
        final SurfaceHolder.Callback2 nextCallback = resolveSurfaceCallback(callback);
        host.reinstallSurfaceCallback(nextSurfaceView, nextCallback);
        installCurrentSurfaceView(nextSurfaceView);
        appendSurfaceHostInstalledEvent(reason);
        postSurfaceInstallViewportNotification();
    }

    public void notifyVisibleViewport(String reason) {
        if (viewportNotificationSuppressed()) {
            return;
        }
        final boolean viewportImeVisible = host.currentImeVisible();
        final int width = Math.max(host.productSurfaceContainer().getWidth(), 1);
        final int height = Math.max(host.productSurfaceContainer().getHeight(), 1);
        updateVisibleViewportSize(width, height);
        if (viewportNotificationUnchanged(width, height, viewportImeVisible)) {
            return;
        }
        recordNotifiedViewport(width, height, viewportImeVisible);
        appendViewportChangedEvent(reason, width, height, viewportImeVisible);
        final long seq = nativeViewportChangedSeq(width, height, viewportImeVisible);
        dispatchNativeViewportChanged(seq);
        refreshViewportScrollOverlay();
        updateViewportUpdatedStatus();
    }

    private void maybeScheduleSurfaceRecreation(boolean recreateSurfaceOnce) {
        host.appendEvent("debug.surface.recreate requested=" + recreateSurfaceOnce + " scheduled=" + host.surfaceRecreationScheduled());
        if (skipSurfaceRecreationSchedule(recreateSurfaceOnce)) {
            return;
        }
        host.setSurfaceRecreationScheduled(true);
        host.productSurfaceContainer().postDelayed(() -> {
            host.appendEvent("debug.surface.recreate_view");
            installSurfaceView("debug-recreate", null);
            host.updateStatus("debug.surface.recreated");
        }, 700);
    }

    private void maybeScheduleSurfaceResize(boolean resizeSurfaceOnce) {
        host.appendEvent("debug.surface.resize requested=" + resizeSurfaceOnce + " scheduled=" + host.surfaceResizeScheduled());
        if (skipSurfaceResizeSchedule(resizeSurfaceOnce)) {
            return;
        }
        final SurfaceView surfaceView = host.surfaceView();
        if (missingSurfaceViewForResize(surfaceView)) {
            return;
        }
        host.setSurfaceResizeScheduled(true);
        scheduleSurfaceResizeProbe(surfaceView);
    }

    private void maybeScheduleShellStart(boolean startShellOnce) {
        host.appendEvent("debug.session.start requested=" + startShellOnce + " scheduled=" + host.shellStartScheduled());
        if (skipShellStartSchedule(startShellOnce)) {
            return;
        }
        host.setShellStartScheduled(true);
        host.handler().postDelayed(() -> {
            host.handleProductShellStateEvent("debug-session-started");
        }, 900);
    }

    private void applySurfaceResize(
            SurfaceHolder holder,
            int originalWidth,
            int originalHeight,
            int shrunkHeight) {
        holder.setFixedSize(originalWidth, shrunkHeight);
        host.appendEvent(
                "debug.surface.resize fixedSize=" + originalWidth + "x" + shrunkHeight
                        + " original=" + originalWidth + "x" + originalHeight
                        + " target=surfaceHolder");
        host.updateStatus("debug.surface.resized_shrink");

        host.handler().postDelayed(() -> restoreSurfaceSize(holder, originalWidth, originalHeight), 900);
    }

    private void restoreSurfaceSize(SurfaceHolder holder, int originalWidth, int originalHeight) {
        holder.setFixedSize(originalWidth, originalHeight);
        host.appendEvent(
                "debug.surface.resize restoreSize=" + originalWidth + "x" + originalHeight
                        + " target=surfaceHolder");
        host.updateStatus("debug.surface.resized_restore");
    }

    private void removeExistingSurfaceViewIfPresent(String reason, SurfaceHolder.Callback2 callback) {
        final SurfaceView existing = host.surfaceView();
        if (existing == null) {
            return;
        }
        final SurfaceHolder.Callback2 previousCallback = callback != null ? callback : host.surfaceCallback();
        if (previousCallback != null) {
            existing.getHolder().removeCallback(previousCallback);
        }
        host.productSurfaceContainer().removeView(existing);
        host.appendEvent("surface.host.removed reason=" + reason + " generation=" + host.surfaceHostGeneration());
    }

    private SurfaceView createAndAttachSurfaceView() {
        final SurfaceView nextSurfaceView = new SurfaceView(host.productSurfaceContainer().getContext());
        final SurfaceHolder holder = nextSurfaceView.getHolder();
        holder.setFormat(PixelFormat.RGBA_8888);
        host.installSurfaceGestureHost(nextSurfaceView);
        final FrameLayout.LayoutParams params = new FrameLayout.LayoutParams(
                ViewGroup.LayoutParams.MATCH_PARENT,
                ViewGroup.LayoutParams.MATCH_PARENT,
                Gravity.CENTER);
        host.productSurfaceContainer().addView(nextSurfaceView, params);
        return nextSurfaceView;
    }

    private SurfaceHolder.Callback2 resolveSurfaceCallback(SurfaceHolder.Callback2 callback) {
        return callback != null ? callback : host.surfaceCallback();
    }

    private String surfaceChangedEvent(int format, int width, int height) {
        return "surface.changed generation=" + host.surfaceHostGeneration()
                + " format=" + format
                + " size=" + width + "x" + height;
    }

    private long nativeSurfaceAvailableSeq(SurfaceHolder holder, int width, int height) {
        return host.nativeLoaded() ? host.nativeOnSurfaceAvailableBridge(holder, width, height) : -1;
    }

    private long nativeSurfaceDestroyedSeq() {
        return host.nativeLoaded() ? host.nativeOnSurfaceDestroyedBridge() : -1;
    }

    private long nativeSurfaceRedrawNeededSeq() {
        return host.nativeLoaded() ? host.nativeOnSurfaceRedrawNeededBridge() : -1;
    }

    private long nativeViewportChangedSeq(int width, int height, boolean imeVisible) {
        return host.nativeLoaded() ? host.nativeOnVisibleViewportBridge(width, height, imeVisible) : -1;
    }

    private boolean viewportNotificationSuppressed() {
        return host.debugViewEnabled() || host.productSurfaceContainer().getVisibility() != View.VISIBLE;
    }

    private boolean viewportNotificationUnchanged(int width, int height, boolean viewportImeVisible) {
        return width == host.notifiedViewportWidth()
                && height == host.notifiedViewportHeight()
                && viewportImeVisible == host.notifiedViewportImeVisible();
    }

    private void appendViewportChangedEvent(String reason, int width, int height, boolean viewportImeVisible) {
        host.appendEvent("viewport.size.changed reason=" + reason + " size=" + width + "x" + height + " imeVisible=" + viewportImeVisible);
    }

    private void appendSurfaceCreatedEvent(SurfaceHolder holder) {
        host.appendEvent("surface.lifecycle.created generation=" + host.surfaceHostGeneration() + " valid=" + holder.getSurface().isValid());
    }

    private void updateSurfaceCreatedStatus() {
        host.updateStatus("surface.state.created");
    }

    private void appendSurfaceDestroyedEvent() {
        host.appendEvent("surface.lifecycle.destroyed generation=" + host.surfaceHostGeneration());
    }

    private void appendSurfaceRedrawReentrantSkippedEvent(SurfaceHolder holder) {
        host.appendEvent(
                "surface.redrawNeeded reentrant-skipped generation=" + host.surfaceHostGeneration() +
                        " valid=" + holder.getSurface().isValid());
    }

    private void appendSurfaceRedrawNeededEvent(SurfaceHolder holder) {
        host.appendEvent(
                "surface.redrawNeeded generation=" + host.surfaceHostGeneration() + " valid=" + holder.getSurface().isValid());
    }

    private void appendNativeSurfaceRedrawNeededEvent(long seq, AndroidDebugFormatter.SurfaceEventSnapshot state) {
        host.appendEvent(
                "native.surfaceRedrawNeeded seq=" + seq +
                        " gles=" + state.glesStatus +
                        " glesSwaps=" + state.glesSwapCount +
                        " glesBoundEpoch=" + state.glesBoundEpoch +
                        " glesContextCreates=" + state.glesContextCreateCount +
                        " glesSurfaceCreates=" + state.glesSurfaceCreateCount +
                        " glesTextureCreates=" + state.glesTextureCreateCount +
                        " glesTextureAlive=" + state.glesTextureAlive +
                        " glesTextureUploads=" + state.glesTextureUploadCount +
                        " glesTextureUpdates=" + state.glesTextureUpdateCount +
                        " glesTextureResizes=" + state.glesTextureResizeCount +
                        " glesTextureSize=" + state.glesTextureWidth + "x" + state.glesTextureHeight);
    }

    private void updateSurfaceRedrawNeededStatus() {
        host.updateStatus("surface.state.redraw_needed");
    }

    private void clearSurfaceRedrawNeededDispatching() {
        surfaceRedrawNeededDispatching = false;
    }

    private void dispatchNativeSurfaceAvailable(long seq) {
        host.callNativeWithSurfaceState(
                "native.surfaceAvailable",
                seq,
                host.currentSurfaceStateSnapshot());
    }

    private void postSurfaceChangedViewportNotification() {
        host.productSurfaceContainer().post(() -> notifyVisibleViewport("surface-changed"));
    }

    private void installCurrentSurfaceView(SurfaceView nextSurfaceView) {
        host.setSurfaceView(nextSurfaceView);
    }

    private void postSurfaceInstallViewportNotification() {
        host.productSurfaceContainer().post(() -> notifyVisibleViewport("surface-install"));
    }

    private void incrementSurfaceHostGeneration() {
        host.setSurfaceHostGeneration(host.surfaceHostGeneration() + 1);
    }

    private void appendSurfaceHostInstalledEvent(String reason) {
        host.appendEvent("surface.host.installed reason=" + reason + " generation=" + host.surfaceHostGeneration());
    }

    private boolean skipSurfaceRecreationSchedule(boolean recreateSurfaceOnce) {
        return !recreateSurfaceOnce || host.surfaceRecreationScheduled();
    }

    private boolean skipShellStartSchedule(boolean startShellOnce) {
        return !startShellOnce || host.shellStartScheduled();
    }

    private boolean skipSurfaceResizeSchedule(boolean resizeSurfaceOnce) {
        return !resizeSurfaceOnce || host.surfaceResizeScheduled();
    }

    private boolean missingSurfaceViewForResize(SurfaceView surfaceView) {
        return surfaceView == null;
    }

    private void scheduleSurfaceResizeProbe(SurfaceView surfaceView) {
        host.handler().postDelayed(() -> {
            final SurfaceHolder holder = surfaceView.getHolder();
            final int originalWidth = Math.max(2, surfaceView.getWidth());
            final int originalHeight = Math.max(2, surfaceView.getHeight());
            final int shrunkHeight = Math.max(200, originalHeight / 2);
            applySurfaceResize(holder, originalWidth, originalHeight, shrunkHeight);
        }, 900);
    }

    private void notifyProductShellResumed() {
        host.handleProductShellStateEvent("resumed");
    }

    private void dispatchNativePause() {
        host.callNative("native.onPause", -1);
    }

    private void dispatchNativeSurfaceDestroyed(long seq) {
        host.callNativeWithSurfaceState(
                "native.surfaceDestroyed",
                seq,
                host.currentSurfaceStateSnapshot());
    }

    private void updateSurfaceDestroyedStatus() {
        host.updateStatus("surface.state.destroyed");
    }

    private void dispatchNativeViewportChanged(long seq) {
        host.callNativeWithSurfaceState("native.viewportChanged", seq, host.currentSurfaceStateSnapshot());
    }

    private void updateVisibleViewportSize(int width, int height) {
        host.setVisibleViewportSize(width, height);
    }

    private void recordNotifiedViewport(int width, int height, boolean viewportImeVisible) {
        host.setNotifiedViewportSize(width, height, viewportImeVisible);
    }

    private void refreshViewportScrollOverlay() {
        host.refreshProductScrollOverlay();
    }

    private void updateViewportUpdatedStatus() {
        host.updateStatus("viewport.state.updated");
    }
}
