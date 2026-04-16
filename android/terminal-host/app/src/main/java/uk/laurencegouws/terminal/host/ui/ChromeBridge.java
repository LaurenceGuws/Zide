package uk.laurencegouws.terminal.host.ui;

import android.content.Context;
import android.view.View;
import android.widget.Button;

import uk.laurencegouws.terminal.R;
import uk.laurencegouws.terminal.input.ShellInputView;

/**
 * Adapts activity-owned chrome callbacks and view references to {@link ChromeController}.
 */
public final class ChromeBridge implements ChromeController.Host {
    /** Activity callbacks used by chrome actions. */
    public interface Callbacks {
        boolean debugViewEnabled();

        void showView(String eventName, String statusLabel);

        void showDebugView(String eventName, String statusLabel);

        void runPackageDoctor();

        void appendEvent(String event);

        boolean currentImeVisible();

        void setImeVisible(boolean visible);

        ShellInputView shellInputView();

        Button assistCtrlButton();

        Button assistAltButton();

        void sendDirectText(String text);

        void updateStatus(String statusLabel);
    }

    private final Context context;
    private final View rootView;
    private final View debugViewModeButton;
    private final View drawerScrim;
    private final View drawerEdgeHotspot;
    private final View leftSidebar;
    private final Callbacks callbacks;
    private boolean sidebarOpen = false;

    public ChromeBridge(
            Context context,
            View rootView,
            View debugViewModeButton,
            View drawerScrim,
            View drawerEdgeHotspot,
            View leftSidebar,
            Callbacks callbacks) {
        this.context = context;
        this.rootView = rootView;
        this.debugViewModeButton = debugViewModeButton;
        this.drawerScrim = drawerScrim;
        this.drawerEdgeHotspot = drawerEdgeHotspot;
        this.leftSidebar = leftSidebar;
        this.callbacks = callbacks;
    }

    @Override
    public Context context() {
        return context;
    }

    @Override
    public View debugViewModeButton() {
        return debugViewModeButton;
    }

    @Override
    public View drawerScrim() {
        return drawerScrim;
    }

    @Override
    public View drawerEdgeHotspot() {
        return drawerEdgeHotspot;
    }

    @Override
    public View leftSidebar() {
        return leftSidebar;
    }

    @Override
    public boolean sidebarOpen() {
        return sidebarOpen;
    }

    @Override
    public void setSidebarOpen(boolean open) {
        sidebarOpen = open;
    }

    @Override
    public boolean debugViewEnabled() {
        return callbacks.debugViewEnabled();
    }

    @Override
    public void showView(String eventName, String statusLabel) {
        callbacks.showView(eventName, statusLabel);
    }

    @Override
    public void showDebugView(String eventName, String statusLabel) {
        callbacks.showDebugView(eventName, statusLabel);
    }

    @Override
    public void runPackageDoctor() {
        callbacks.runPackageDoctor();
    }

    @Override
    public void appendEvent(String event) {
        callbacks.appendEvent(event);
    }

    @Override
    public boolean currentImeVisible() {
        return callbacks.currentImeVisible();
    }

    @Override
    public void setImeVisible(boolean visible) {
        callbacks.setImeVisible(visible);
    }

    @Override
    public void applyModifierLatchState(ShellInputView.Host.ModifierLatchState state) {
        applyModifierButtonState(
                assistCtrlButton(),
                state.ctrlLatched,
                R.string.assist_ctrl,
                R.string.assist_ctrl_latched);
        applyModifierButtonState(
                assistAltButton(),
                state.altLatched,
                R.string.assist_alt,
                R.string.assist_alt_latched);
    }

    @Override
    public ShellInputView shellInputView() {
        return callbacks.shellInputView();
    }

    @Override
    public Button assistCtrlButton() {
        return callbacks.assistCtrlButton();
    }

    @Override
    public Button assistAltButton() {
        return callbacks.assistAltButton();
    }

    @Override
    public void sendDirectText(String text) {
        callbacks.sendDirectText(text);
    }

    @Override
    public void bindAssistButton(int id, String text, String eventName) {
        final Button button = rootView.findViewById(id);
        button.setOnClickListener(view -> {
            callbacks.sendDirectText(text);
            callbacks.appendEvent(eventName);
        });
    }

    @Override
    public void bindModifierAssistButton(Button button, ShellInputView.ModifierLatch modifier, String eventName) {
        button.setOnClickListener(view -> {
            callbacks.shellInputView().toggleModifierLatch(modifier);
            callbacks.appendEvent(eventName + " toggled");
        });
    }

    @Override
    public void updateStatus(String statusLabel) {
        callbacks.updateStatus(statusLabel);
    }

    private void applyModifierButtonState(Button button, boolean latched, int idleLabelResId, int activeLabelResId) {
        if (button == null) {
            return;
        }
        button.setText(latched ? activeLabelResId : idleLabelResId);
        button.setAlpha(latched ? 1.0f : 0.72f);
        button.setActivated(latched);
        button.setSelected(latched);
    }
}
