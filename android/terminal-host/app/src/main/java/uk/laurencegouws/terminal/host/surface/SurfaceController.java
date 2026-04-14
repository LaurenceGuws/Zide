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
        scheduleDebugSurfaceRecreationIfRequested(recreateSurfaceOnce);
        scheduleDebugSurfaceResizeIfRequested(resizeSurfaceOnce);
        scheduleDebugShellStartIfRequested(startShellOnce);

        host.handleProductShellStateEvent("resumed");
    }

    /** Debug-only: optional one-shot surface view reinstall from lifecycle resume flags. */
    private void scheduleDebugSurfaceRecreationIfRequested(boolean recreateSurfaceOnce) {
        host.appendEvent("debug.surface.recreate requested=" + recreateSurfaceOnce + " scheduled=" + host.surfaceRecreationScheduled());
        if (recreateSurfaceOnce && !host.surfaceRecreationScheduled()) {
            host.setSurfaceRecreationScheduled(true);
            host.productSurfaceContainer().postDelayed(() -> {
                host.appendEvent("debug.surface.recreate_view");
                installSurfaceView("debug-recreate", null);
                host.updateStatus("debug.surface.recreated");
            }, 700);
        }
    }

    /** Debug-only: optional one-shot surface holder resize probe from lifecycle resume flags. */
    private void scheduleDebugSurfaceResizeIfRequested(boolean resizeSurfaceOnce) {
        host.appendEvent("debug.surface.resize requested=" + resizeSurfaceOnce + " scheduled=" + host.surfaceResizeScheduled());
        if (resizeSurfaceOnce && !host.surfaceResizeScheduled()) {
            final SurfaceView surfaceView = host.surfaceView();
            if (surfaceView != null) {
                host.setSurfaceResizeScheduled(true);
                host.handler().postDelayed(() -> {
                    final SurfaceHolder holder = surfaceView.getHolder();
                    final int originalWidth = Math.max(2, surfaceView.getWidth());
                    final int originalHeight = Math.max(2, surfaceView.getHeight());
                    final int shrunkHeight = Math.max(200, originalHeight / 2);
                    holder.setFixedSize(originalWidth, shrunkHeight);
                    host.appendEvent(
                            "debug.surface.resize fixedSize=" + originalWidth + "x" + shrunkHeight
                                    + " original=" + originalWidth + "x" + originalHeight
                                    + " target=surfaceHolder");
                    host.updateStatus("debug.surface.resized_shrink");

                    host.handler().postDelayed(() -> {
                        holder.setFixedSize(originalWidth, originalHeight);
                        host.appendEvent(
                                "debug.surface.resize restoreSize=" + originalWidth + "x" + originalHeight
                                        + " target=surfaceHolder");
                        host.updateStatus("debug.surface.resized_restore");
                    }, 900);
                }, 900);
            }
        }
    }

    /** Debug-only: optional one-shot shell start signal from lifecycle resume flags. */
    private void scheduleDebugShellStartIfRequested(boolean startShellOnce) {
        host.appendEvent("debug.session.start requested=" + startShellOnce + " scheduled=" + host.shellStartScheduled());
        if (startShellOnce && !host.shellStartScheduled()) {
            host.setShellStartScheduled(true);
            host.handler().postDelayed(() -> {
                host.handleProductShellStateEvent("debug-session-started");
            }, 900);
        }
    }

    public void onPause() {
        host.callNative("native.onPause", -1);
    }

    public void onSurfaceCreated(SurfaceHolder holder) {
        host.appendEvent("surface.lifecycle.created generation=" + host.surfaceHostGeneration() + " valid=" + holder.getSurface().isValid());
        host.updateStatus("surface.state.created");
    }

    public void onSurfaceChanged(SurfaceHolder holder, int format, int width, int height) {
        host.appendEvent("surface.changed generation=" + host.surfaceHostGeneration()
                + " format=" + format
                + " size=" + width + "x" + height);
        final long seq = host.nativeLoaded() ? host.nativeOnSurfaceAvailableBridge(holder, width, height) : -1;
        host.callNativeWithSurfaceState(
                "native.surfaceAvailable",
                seq,
                host.currentSurfaceStateSnapshot());
        host.productSurfaceContainer().post(() -> notifyVisibleViewport("surface-changed"));
        host.handleProductShellStateEvent("surface-changed");
    }

    public void onSurfaceDestroyed(SurfaceHolder holder) {
        host.appendEvent("surface.lifecycle.destroyed generation=" + host.surfaceHostGeneration());
        final long seq = host.nativeLoaded() ? host.nativeOnSurfaceDestroyedBridge() : -1;
        host.callNativeWithSurfaceState(
                "native.surfaceDestroyed",
                seq,
                host.currentSurfaceStateSnapshot());
        host.updateStatus("surface.state.destroyed");
    }

    public void onSurfaceRedrawNeeded(SurfaceHolder holder) {
        if (surfaceRedrawNeededDispatching) {
            host.appendEvent(
                    "surface.redrawNeeded reentrant-skipped generation=" + host.surfaceHostGeneration() +
                            " valid=" + holder.getSurface().isValid());
            return;
        }
        surfaceRedrawNeededDispatching = true;
        host.appendEvent(
                "surface.redrawNeeded generation=" + host.surfaceHostGeneration() + " valid=" + holder.getSurface().isValid());
        try {
            final long seq = host.nativeLoaded() ? host.nativeOnSurfaceRedrawNeededBridge() : -1;
            final AndroidDebugFormatter.SurfaceEventSnapshot state = host.currentSurfaceStateSnapshot();
            appendNativeSurfaceRedrawNeededTelemetry(seq, state);
            host.updateStatus("surface.state.redraw_needed");
        } finally {
            surfaceRedrawNeededDispatching = false;
        }
    }

    public void installSurfaceView(String reason, SurfaceHolder.Callback2 callback) {
        removeExistingSurfaceHostViewIfPresent(reason, callback);

        host.setSurfaceHostGeneration(host.surfaceHostGeneration() + 1);
        final SurfaceView nextSurfaceView = new SurfaceView(host.productSurfaceContainer().getContext());
        nextSurfaceView.getHolder().setFormat(PixelFormat.RGBA_8888);
        host.installSurfaceGestureHost(nextSurfaceView);
        final FrameLayout.LayoutParams params = matchParentCenteredSurfaceHostLayoutParams();
        host.productSurfaceContainer().addView(nextSurfaceView, params);
        final SurfaceHolder.Callback2 nextCallback = resolveSurfaceInstallCallback(callback);
        host.reinstallSurfaceCallback(nextSurfaceView, nextCallback);
        host.setSurfaceView(nextSurfaceView);
        host.appendEvent("surface.host.installed reason=" + reason + " generation=" + host.surfaceHostGeneration());
        host.productSurfaceContainer().post(() -> notifyVisibleViewport("surface-install"));
    }

    public void notifyVisibleViewport(String reason) {
        if (host.debugViewEnabled() || host.productSurfaceContainer().getVisibility() != View.VISIBLE) {
            return;
        }
        final boolean viewportImeVisible = host.currentImeVisible();
        final int width = Math.max(host.productSurfaceContainer().getWidth(), 1);
        final int height = Math.max(host.productSurfaceContainer().getHeight(), 1);
        host.setVisibleViewportSize(width, height);
        if (visibleViewportDimensionsMatchNotified(width, height, viewportImeVisible)) {
            return;
        }
        publishVisibleViewportChange(reason, width, height, viewportImeVisible);
    }

    private boolean visibleViewportDimensionsMatchNotified(
            int width,
            int height,
            boolean viewportImeVisible) {
        return width == host.notifiedViewportWidth()
                && height == host.notifiedViewportHeight()
                && viewportImeVisible == host.notifiedViewportImeVisible();
    }

    private void publishVisibleViewportChange(
            String reason,
            int width,
            int height,
            boolean viewportImeVisible) {
        host.setNotifiedViewportSize(width, height, viewportImeVisible);
        host.appendEvent("viewport.size.changed reason=" + reason + " size=" + width + "x" + height + " imeVisible=" + viewportImeVisible);
        final long seq = host.nativeLoaded() ? host.nativeOnVisibleViewportBridge(width, height, viewportImeVisible) : -1;
        host.callNativeWithSurfaceState("native.viewportChanged", seq, host.currentSurfaceStateSnapshot());
        host.refreshProductScrollOverlay();
        host.updateStatus("viewport.state.updated");
    }

    private void appendNativeSurfaceRedrawNeededTelemetry(
            long seq,
            AndroidDebugFormatter.SurfaceEventSnapshot state) {
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

    private SurfaceHolder.Callback2 resolveSurfaceInstallCallback(SurfaceHolder.Callback2 callback) {
        return callback != null ? callback : host.surfaceCallback();
    }

    private void removeExistingSurfaceHostViewIfPresent(String reason, SurfaceHolder.Callback2 callback) {
        final SurfaceView existing = host.surfaceView();
        if (existing == null) {
            return;
        }
        final SurfaceHolder.Callback2 previousCallback = resolveSurfaceInstallCallback(callback);
        if (previousCallback != null) {
            existing.getHolder().removeCallback(previousCallback);
        }
        host.productSurfaceContainer().removeView(existing);
        host.appendEvent("surface.host.removed reason=" + reason + " generation=" + host.surfaceHostGeneration());
    }

    private FrameLayout.LayoutParams matchParentCenteredSurfaceHostLayoutParams() {
        return new FrameLayout.LayoutParams(
                ViewGroup.LayoutParams.MATCH_PARENT,
                ViewGroup.LayoutParams.MATCH_PARENT,
                Gravity.CENTER);
    }

}
