package uk.laurencegouws.terminal.selection;

import android.content.Context;
import android.widget.FrameLayout;

import uk.laurencegouws.terminal.host.interaction.SelectionBridge;
import uk.laurencegouws.terminal.host.interaction.SelectionInteractionBridge;

/** Creates selection controllers for a terminal surface widget instance. */
public final class SelectionControllerFactory {
    /** Widget host callbacks required by selection controller wiring. */
    public interface Host extends SelectionInteractionBridge.Callbacks, SelectionBridge.Callbacks {
    }

    private SelectionControllerFactory() {
    }

    public static SelectionController create(Context context, FrameLayout productSurfaceContainer, Host host) {
        return new SelectionController(
                new SelectionInteractionBridge(context, productSurfaceContainer, host),
                new SelectionBridge(host));
    }
}
