package uk.laurencegouws.terminal.gesture;

import android.content.Context;
import android.os.Handler;
import android.widget.OverScroller;

import uk.laurencegouws.terminal.host.interaction.GestureStateBridge;

/** Creates gesture-state controllers for a terminal surface widget instance. */
public final class TerminalGestureStateControllerFactory {
    /** Widget host callbacks required by gesture-state controller wiring. */
    public interface Host {
        boolean nativeLoaded();

        int visibleRows();

        int viewportHeightPx();

        int scrollbackCount();

        int scrollbackOffset();

        int setScrollbackOffset(int offsetRows);

        int followLiveBottom();

        int applyTerminalPinchZoom(float scaleFactor);

        int setTerminalPinchActive(boolean active);

        void refreshProductScrollOverlay();

        void reevaluateProductFrameLoop();
    }

    private TerminalGestureStateControllerFactory() {
    }

    public static TerminalGestureStateController create(Context context, Handler handler, Host host) {
        final TerminalGestureStateController controller = new TerminalGestureStateController(
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
                    public int applyTerminalPinchZoom(float scaleFactor) {
                        return host.applyTerminalPinchZoom(scaleFactor);
                    }

                    @Override
                    public int setTerminalPinchActive(boolean active) {
                        return host.setTerminalPinchActive(active);
                    }

                    @Override
                    public void refreshProductScrollOverlay() {
                        host.refreshProductScrollOverlay();
                    }

                    @Override
                    public void reevaluateProductFrameLoop() {
                        host.reevaluateProductFrameLoop();
                    }
                }));
        controller.setScrollbackFlingScroller(new OverScroller(context));
        return controller;
    }
}
