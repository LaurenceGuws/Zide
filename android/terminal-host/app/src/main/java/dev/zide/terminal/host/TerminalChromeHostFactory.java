package dev.zide.terminal.host;

import android.content.Context;
import android.view.View;
import android.widget.Button;

import java.util.function.BiConsumer;
import java.util.function.BooleanSupplier;
import java.util.function.Consumer;
import java.util.function.Supplier;

import dev.zide.terminal.input.ShellInputView;

/**
 * Chrome host assembly helpers.
 *
 * <p>Owns creation of chrome bridge/callback adapter instances so generic
 * host wiring does not accumulate domain-specific construction logic.
 */
public final class TerminalChromeHostFactory {
    private TerminalChromeHostFactory() {
    }

    public static TerminalChromeHostBridge createChromeHostBridge(
            Context context,
            View rootView,
            View debugViewModeButton,
            View drawerScrim,
            View drawerEdgeHotspot,
            View leftSidebar,
            TerminalChromeHostBridge.Callbacks callbacks) {
        return new TerminalChromeHostBridge(
                context,
                rootView,
                debugViewModeButton,
                drawerScrim,
                drawerEdgeHotspot,
                leftSidebar,
                callbacks);
    }

    public static TerminalChromeHostBridge.Callbacks createChromeHostCallbacks(
            BooleanSupplier debugViewEnabled,
            BiConsumer<String, String> showProductView,
            BiConsumer<String, String> showDebugView,
            Runnable runPackageDoctor,
            Consumer<String> appendEvent,
            BooleanSupplier currentImeVisible,
            Consumer<Boolean> setImeVisible,
            Supplier<ShellInputView> shellInputView,
            Supplier<Button> assistCtrlButton,
            Supplier<Button> assistAltButton,
            Consumer<String> sendDirectText,
            Consumer<String> updateStatus) {
        return new TerminalChromeHostCallbacks(
                debugViewEnabled,
                showProductView,
                showDebugView,
                runPackageDoctor,
                appendEvent,
                currentImeVisible,
                setImeVisible,
                shellInputView,
                assistCtrlButton,
                assistAltButton,
                sendDirectText,
                updateStatus);
    }
}
