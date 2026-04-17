package uk.laurencegouws.terminal.gesture;

import android.content.Context;
import android.os.Handler;
import android.widget.OverScroller;

import uk.laurencegouws.terminal.host.interaction.GestureStateBridge;

/** Creates gesture-state controllers for a terminal surface widget instance. */
public final class GestureStateControllerFactory {
    /** Widget host callbacks required by gesture-state controller wiring. */
    public interface Host extends GestureStateBridge.Callbacks {
    }

    private GestureStateControllerFactory() {
    }

    public static GestureStateController create(Context context, Handler handler, Host host) {
        final GestureStateController controller = new GestureStateController(
                handler,
                new GestureStateBridge(host));
        controller.setScrollbackFlingScroller(new OverScroller(context));
        return controller;
    }
}
