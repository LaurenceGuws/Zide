package dev.zide.terminal.host.ui;

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
public final class ChromeFactory {
    private ChromeFactory() {
    }

    public static ChromeBridge createChromeHostBridge(
            Context context,
            View rootView,
            View debugViewModeButton,
            View drawerScrim,
            View drawerEdgeHotspot,
            View leftSidebar,
            ChromeBridge.Callbacks callbacks) {
        return new ChromeBridge(
                context,
                rootView,
                debugViewModeButton,
                drawerScrim,
                drawerEdgeHotspot,
                leftSidebar,
                callbacks);
    }

    public static ChromeBridge.Callbacks createChromeHostCallbacks(
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
        return new ChromeCallbacks(
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
