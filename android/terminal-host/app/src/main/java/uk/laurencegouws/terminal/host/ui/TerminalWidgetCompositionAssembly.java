package uk.laurencegouws.terminal.host.ui;

import uk.laurencegouws.terminal.host.interaction.InteractionAssembly;

/**
 * Harness-owned composition seam for one terminal widget product instance.
 *
 * <p>Combines {@link InteractionAssembly} (selection + gesture) with {@link WidgetSurfaceHostJoin}
 * into a {@link TerminalWidgetInstance}. Harness chrome/shell/view-mode controllers stay on
 * {@link WidgetAssembly.Result#harnessHost}; this type only joins the surface slice — it does not
 * make {@code WidgetAssembly.Result} act as a terminal-instance factory by itself.</p>
 *
 * <p>The activity reads harness controllers from {@link WidgetAssembly.Result} alongside
 * {@link #compose} output. Future multi-slot hosting would pass one {@link WidgetSurfaceHostJoin} per
 * slot; this class does not implement tab product behavior.</p>
 */
public final class TerminalWidgetCompositionAssembly {
    private TerminalWidgetCompositionAssembly() {
    }

    /**
     * Joins interaction and surface host join into the portable {@link TerminalWidgetInstance}.
     * Harness chrome/shell/view-mode refs are not part of this call.
     *
     * @param slot compile-visible slot identity for this join — must satisfy
     *             {@link TerminalWidgetSlotId#checkActiveProductTerminalSlot} for current product wiring
     */
    public static TerminalWidgetInstance compose(
            TerminalWidgetSlotId slot,
            InteractionAssembly.Result interaction,
            WidgetSurfaceHostJoin surfaceJoin) {
        TerminalWidgetSlotId.checkActiveProductTerminalSlot(slot);
        return new TerminalWidgetInstance(
                interaction.selectionController,
                interaction.GestureStateController,
                surfaceJoin.surfaceHostBridge,
                surfaceJoin.surfaceHostController,
                surfaceJoin.surfaceWidgetController);
    }
}
