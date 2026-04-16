package uk.laurencegouws.terminal.gesture;

import android.content.Context;
import android.os.Handler;
import android.widget.OverScroller;

import uk.laurencegouws.terminal.host.interaction.GestureStateBridge;

/** Creates gesture-state controllers for a terminal surface widget instance. */
public final class GestureStateControllerFactory {
    /** Widget host callbacks required by gesture-state controller wiring. */
    public interface Host {
        boolean nativeLoaded();

        int visibleRows();

        int viewportHeightPx();

        int scrollbackCount();

        int scrollbackOffset();

        int setScrollbackOffset(int offsetRows);

        int followLiveBottom();

        int applyPinchZoom(float scaleFactor);

        int setPinchActive(boolean active);

        void refreshScrollOverlay();

        void reevaluateFrameLoop();
    }

    private GestureStateControllerFactory() {
    }

    public static GestureStateController create(Context context, Handler handler, Host host) {
        final GestureStateController controller = new GestureStateController(
                handler,
                new GestureStateBridge(new GestureStateBridge.Callbacks() {
                    @Override
                    public boolean nativeLoaded() {
                        return host.nativeLoaded();
                    }

                    @Override
                    public int visibleRows() {
                        return host.visibleRows();
                    }

                    @Override
                    public int viewportHeightPx() {
                        return host.viewportHeightPx();
                    }

                    @Override
                    public int scrollbackCount() {
                        return host.scrollbackCount();
                    }

                    @Override
                    public int scrollbackOffset() {
                        return host.scrollbackOffset();
                    }

                    @Override
                    public int setScrollbackOffset(int offsetRows) {
                        return host.setScrollbackOffset(offsetRows);
                    }

                    @Override
                    public int followLiveBottom() {
                        return host.followLiveBottom();
                    }

                    @Override
                    public int applyPinchZoom(float scaleFactor) {
                        return host.applyPinchZoom(scaleFactor);
                    }

                    @Override
                    public int setPinchActive(boolean active) {
                        return host.setPinchActive(active);
                    }

                    @Override
                    public void refreshScrollOverlay() {
                        host.refreshScrollOverlay();
                    }

                    @Override
                    public void reevaluateFrameLoop() {
                        host.reevaluateFrameLoop();
                    }
                }));
        controller.setScrollbackFlingScroller(new OverScroller(context));
        return controller;
    }
}
