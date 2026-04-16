package uk.laurencegouws.terminal.host.ui;

import android.widget.Button;

import java.util.function.BiConsumer;
import java.util.function.BooleanSupplier;
import java.util.function.Consumer;
import java.util.function.Supplier;

import uk.laurencegouws.terminal.input.ShellInputView;

/** Functional callback adapter for {@link ChromeBridge}. */
public final class ChromeCallbacks implements ChromeBridge.Callbacks {
    private final BooleanSupplier debugViewEnabled;
    private final BiConsumer<String, String> showView;
    private final BiConsumer<String, String> showDebugView;
    private final Runnable runPackageDoctor;
    private final Consumer<String> appendEvent;
    private final BooleanSupplier currentImeVisible;
    private final Consumer<Boolean> setImeVisible;
    private final Supplier<ShellInputView> shellInputView;
    private final Supplier<Button> assistCtrlButton;
    private final Supplier<Button> assistAltButton;
    private final Consumer<String> sendDirectText;
    private final Consumer<String> updateStatus;

    public ChromeCallbacks(
            BooleanSupplier debugViewEnabled,
            BiConsumer<String, String> showView,
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
        this.debugViewEnabled = debugViewEnabled;
        this.showView = showView;
        this.showDebugView = showDebugView;
        this.runPackageDoctor = runPackageDoctor;
        this.appendEvent = appendEvent;
        this.currentImeVisible = currentImeVisible;
        this.setImeVisible = setImeVisible;
        this.shellInputView = shellInputView;
        this.assistCtrlButton = assistCtrlButton;
        this.assistAltButton = assistAltButton;
        this.sendDirectText = sendDirectText;
        this.updateStatus = updateStatus;
    }

    @Override
    public boolean debugViewEnabled() {
        return debugViewEnabled.getAsBoolean();
    }

    @Override
    public void showView(String eventName, String statusLabel) {
        showView.accept(eventName, statusLabel);
    }

    @Override
    public void showDebugView(String eventName, String statusLabel) {
        showDebugView.accept(eventName, statusLabel);
    }

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
}
