package uk.laurencegouws.terminal.gesture;

import android.content.Context;
import android.os.Handler;
import android.widget.OverScroller;

/** Creates gesture-state controllers for a terminal surface widget instance. */
public final class GestureStateControllerFactory {
    /** Widget host callbacks required by gesture-state controller wiring. */
    public interface Host extends GestureStateController.Host {
    }

    private GestureStateControllerFactory() {
    }

    public static GestureStateController create(Context context, Handler handler, Host host) {
        final GestureStateController controller = new GestureStateController(
                handler,
                host);
        controller.setScrollbackFlingScroller(new OverScroller(context));
        return controller;
    }
}
