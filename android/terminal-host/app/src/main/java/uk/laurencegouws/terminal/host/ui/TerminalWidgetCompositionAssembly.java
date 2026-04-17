package uk.laurencegouws.terminal.host.ui;

import java.util.Objects;

import uk.laurencegouws.terminal.host.interaction.InteractionAssembly;

/**
 * Harness-owned composition seam for one terminal widget product instance.
 *
 * <p>Combines {@link InteractionAssembly} (selection + gesture) with {@link WidgetAssembly}
 * surface/chrome results into a {@link TerminalWidgetInstance}. {@link WidgetAssembly.Result}
 * remains the widget/chrome assembly output; this type performs the harness-owned join into the
 * portable instance holder without making {@code WidgetAssembly.Result} act as a terminal-instance
 * factory by itself.</p>
 *
 * <p>Harness shell/chrome/view-mode controllers remain on {@link WidgetAssembly.Result}; the
 * activity reads them from that result alongside {@link #compose} output. Future multi-view
 * hosting would call {@code compose} once per terminal slot; this class does not implement tab
 * product behavior.</p>
 */
public final class TerminalWidgetCompositionAssembly {
    private TerminalWidgetCompositionAssembly() {
    }

    /**
     * Joins interaction and widget assembly results into the portable {@link TerminalWidgetInstance}.
     * Co-hosted chrome/shell/view-mode refs stay on {@code widget}; do not duplicate them here.
     *
     * @param slot compile-visible slot identity for this join (single {@link TerminalWidgetSlotId#PRIMARY}
     *             today; reserved for future per-slot policy at this seam)
     */
    public static TerminalWidgetInstance compose(
            TerminalWidgetSlotId slot,
            InteractionAssembly.Result interaction,
            WidgetAssembly.Result widget) {
        Objects.requireNonNull(slot, "slot");
        return new TerminalWidgetInstance(
                interaction.selectionController,
                interaction.GestureStateController,
                widget.surfaceHostBridge,
                widget.surfaceHostController,
                widget.terminalSurfaceWidgetController);
    }
}
