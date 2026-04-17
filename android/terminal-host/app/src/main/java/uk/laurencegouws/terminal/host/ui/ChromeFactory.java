package uk.laurencegouws.terminal.host.ui;

import android.content.Context;
import android.view.View;
import android.widget.Button;

import java.util.function.BooleanSupplier;
import java.util.function.Consumer;
import java.util.function.Supplier;

import uk.laurencegouws.terminal.input.ShellInputView;

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
            View drawerScrim,
            View drawerEdgeHotspot,
            View leftSidebar,
            ChromeBridge.Callbacks callbacks) {
        return new ChromeBridge(
                context,
                rootView,
                drawerScrim,
                drawerEdgeHotspot,
                leftSidebar,
                callbacks);
    }

    public static ChromeBridge.Callbacks createChromeHostCallbacks(
            Runnable runPackageDoctor,
            Consumer<String> appendEvent,
            BooleanSupplier currentImeVisible,
            Consumer<Boolean> setImeVisible,
            Supplier<ShellInputView> shellInputView,
            Supplier<Button> assistCtrlButton,
            Supplier<Button> assistAltButton,
            Consumer<String> sendDirectText,
            Consumer<String> updateStatus) {
        return new ChromeBridge.Callbacks() {
            @Override
            public void runPackageDoctor() {
                runPackageDoctor.run();
            }

            @Override
            public void appendEvent(String event) {
                appendEvent.accept(event);
            }

            @Override
            public boolean currentImeVisible() {
                return currentImeVisible.getAsBoolean();
            }

            @Override
            public void setImeVisible(boolean visible) {
                setImeVisible.accept(visible);
            }

            @Override
            public ShellInputView shellInputView() {
                return shellInputView.get();
            }

            @Override
            public Button assistCtrlButton() {
                return assistCtrlButton.get();
            }

            @Override
            public Button assistAltButton() {
                return assistAltButton.get();
            }

            @Override
            public void sendDirectText(String text) {
                sendDirectText.accept(text);
            }

            @Override
            public void updateStatus(String statusLabel) {
                updateStatus.accept(statusLabel);
            }
        };
    }
}
