package uk.laurencegouws.terminal.host.ui;

import android.content.Context;
import android.view.View;
import android.widget.Button;

import uk.laurencegouws.terminal.R;
import uk.laurencegouws.terminal.input.ShellInputView;

/**
 * Adapts activity-owned chrome callbacks and view references to {@link ChromeController}.
 * Drawer sidebar policy reads/writes go through {@link AppShellTerminalViewPolicy}, not raw
 * {@link AppShellNavigation}.
 */
public final class ChromeBridge implements ChromeController.Host {
    /** Harness callbacks used by chrome actions. */
    public interface Callbacks {
        void runPackageDoctor();

        void appendEvent(String event);

        boolean chromeImeVisibilityPresent();

        void applyChromeImeVisibilityHidden();

        void applyChromeImeVisibilityFromOpenAttempt(boolean softInputShown, boolean shellInputHasFocus);

        ShellInputView shellInputView();

        Button assistCtrlButton();

        Button assistAltButton();

        void sendDirectText(String text);

        void updateStatus(String statusLabel);
    }

    private final Context context;
    private final View rootView;
    private final View drawerScrim;
    private final View drawerEdgeHotspot;
    private final View leftSidebar;
    private final Callbacks callbacks;
    private final AppShellTerminalViewPolicy appShellTerminalViewPolicy;

    public ChromeBridge(
            Context context,
            View rootView,
            View drawerScrim,
            View drawerEdgeHotspot,
            View leftSidebar,
            AppShellTerminalViewPolicy appShellTerminalViewPolicy,
            Callbacks callbacks) {
        this.context = context;
        this.rootView = rootView;
        this.drawerScrim = drawerScrim;
        this.drawerEdgeHotspot = drawerEdgeHotspot;
        this.leftSidebar = leftSidebar;
        this.appShellTerminalViewPolicy = appShellTerminalViewPolicy;
        this.callbacks = callbacks;
    }

    @Override
    public Context context() {
        return context;
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
    public boolean chromeDrawerSidebarOpen() {
        return appShellTerminalViewPolicy.chromeDrawerSidebarOpen();
    }

    @Override
    public void applyChromeDrawerSidebarOpen() {
        appShellTerminalViewPolicy.applyChromeDrawerSidebarOpen();
    }

    @Override
    public void applyChromeDrawerSidebarClosed() {
        appShellTerminalViewPolicy.applyChromeDrawerSidebarClosed();
    }

    public void runPackageDoctor() {
        callbacks.runPackageDoctor();
    }

    @Override
    public void appendEvent(String event) {
        callbacks.appendEvent(event);
    }

    @Override
    public boolean chromeImeVisibilityPresent() {
        return callbacks.chromeImeVisibilityPresent();
    }

    @Override
    public void applyChromeImeVisibilityHidden() {
        callbacks.applyChromeImeVisibilityHidden();
    }

    @Override
    public void applyChromeImeVisibilityFromOpenAttempt(
            boolean softInputShown, boolean shellInputHasFocus) {
        callbacks.applyChromeImeVisibilityFromOpenAttempt(softInputShown, shellInputHasFocus);
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

    @Override
    public int selectedProductTerminalTabIndex() {
        return appShellTerminalViewPolicy.selectedProductTerminalTabIndex();
    }

    @Override
    public void applySelectProductTerminalTab(int tabIndex) {
        appShellTerminalViewPolicy.applySelectProductTerminalTab(tabIndex);
    }

    @Override
    public Button productTerminalTab0Button() {
        return rootView.findViewById(R.id.product_terminal_tab_0);
    }

    @Override
    public Button productTerminalTab1Button() {
        return rootView.findViewById(R.id.product_terminal_tab_1);
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
