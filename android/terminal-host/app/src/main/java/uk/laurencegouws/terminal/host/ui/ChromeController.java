package uk.laurencegouws.terminal.host.ui;

import android.os.IBinder;
import android.view.MotionEvent;
import android.view.inputmethod.InputMethodManager;
import android.view.View;
import android.widget.Button;

import uk.laurencegouws.terminal.input.ShellInputView;

/** Owns product chrome interactions: view-mode toggles, sidebar, assist bar, and IME policy. */
public final class ChromeController {
    public interface Host {
        android.content.Context context();
        View debugViewModeButton();
        View drawerScrim();
        View drawerEdgeHotspot();
        View leftSidebar();
        boolean sidebarOpen();
        void setSidebarOpen(boolean open);
        boolean debugViewEnabled();
        void showProductView(String eventName, String statusLabel);
        void showDebugView(String eventName, String statusLabel);
        void runPackageDoctor();
        void appendEvent(String event);
        boolean currentImeVisible();
        void setImeVisible(boolean visible);
        void applyModifierLatchState(ShellInputView.Host.ModifierLatchState state);
        ShellInputView shellInputView();
        Button assistCtrlButton();
        Button assistAltButton();
        void sendDirectText(String text);
        void bindAssistButton(int id, String text, String eventName);
        void bindModifierAssistButton(Button button, ShellInputView.ModifierLatch modifier, String eventName);
        void updateStatus(String statusLabel);
    }

    private final Host host;

    public ChromeController(Host host) {
        this.host = host;
    }

    public void bindViewModeToggle() {
        bindProductViewModeToggle();
    }

    private void bindProductViewModeToggle() {
        debugViewModeToggleChrome().setOnClickListener(
                view -> host.showProductView("view.mode debug=false", "product-view"));
    }

    private View debugViewModeToggleChrome() {
        return host.debugViewModeButton();
    }

    public void bindSidebarControls() {
        bindSidebarChromeInteractions();
    }

    /** Sidebar nav actions, scrim dismiss, and edge swipe open/close chrome. */
    private void bindSidebarChromeInteractions() {
        bindSidebarNavActions();
        bindSidebarDrawerGestures();
    }

    private void bindSidebarNavActions() {
        final Button restartButton =
                (Button) leftSidebarChrome().findViewById(uk.laurencegouws.terminal.R.id.sidebar_restart_button);
        final Button debugButton =
                (Button) leftSidebarChrome().findViewById(uk.laurencegouws.terminal.R.id.sidebar_debug_button);
        final Button packagesButton =
                (Button) leftSidebarChrome().findViewById(uk.laurencegouws.terminal.R.id.sidebar_packages_button);

        bindSidebarRestartNavButton(restartButton);
        bindSidebarDebugNavButton(debugButton);
        bindSidebarPackagesNavButton(packagesButton);
    }

    private void bindSidebarRestartNavButton(Button restartButton) {
        restartButton.setOnClickListener(view -> {
            host.appendEvent("manual.session.restart requested");
            closeSidebar();
        });
    }

    private void bindSidebarDebugNavButton(Button debugButton) {
        debugButton.setOnClickListener(view -> {
            host.showDebugView("view.mode debug=true", "debug-view");
            closeSidebar();
        });
    }

    private void bindSidebarPackagesNavButton(Button packagesButton) {
        packagesButton.setOnClickListener(view -> {
            closeSidebar();
            host.runPackageDoctor();
        });
    }

    private void bindSidebarDrawerGestures() {
        bindDrawerScrimDismissChrome();
        bindDrawerEdgeSwipeListenersChrome();
    }

    private View leftSidebarChrome() {
        return host.leftSidebar();
    }

    private View drawerScrimChrome() {
        return host.drawerScrim();
    }

    private View drawerEdgeHotspotChrome() {
        return host.drawerEdgeHotspot();
    }

    private void bindDrawerScrimDismissChrome() {
        drawerScrimChrome().setOnClickListener(view -> closeSidebar());
    }

    private void bindDrawerEdgeSwipeListenersChrome() {
        drawerEdgeHotspotChrome().setOnTouchListener(new EdgeSwipeListener(true));
        leftSidebarChrome().setOnTouchListener(new EdgeSwipeListener(false));
    }

    public void bindAssistBar() {
        bindAssistImeToggleIfPresent(assistBarRootView());
        bindAssistRowInputChrome();
    }

    private ShellInputView activeShellInputView() {
        return host.shellInputView();
    }

    private View assistBarRootView() {
        return activeShellInputView().getRootView();
    }

    private void bindAssistRowInputChrome() {
        bindAssistModifierLatchButtons();
        bindAssistCharacterButtons();
        applyAssistModifierLatchChromeAfterBindings();
    }

    private void applyAssistModifierLatchChromeAfterBindings() {
        host.applyModifierLatchState(activeShellInputView().modifierLatchState());
    }

    private void bindAssistModifierLatchButtons() {
        host.bindModifierAssistButton(host.assistCtrlButton(), ShellInputView.ModifierLatch.CTRL, "assist.ctrl");
        host.bindModifierAssistButton(host.assistAltButton(), ShellInputView.ModifierLatch.ALT, "assist.alt");
    }

    /** Wires assist-row text keys and arrow keys to host direct-send binding. */
    private void bindAssistCharacterButtons() {
        bindAssistCharacterLiteralButtons();
        bindAssistCharacterNavigationButtons();
    }

    private void bindAssistCharacterLiteralButtons() {
        host.bindAssistButton(uk.laurencegouws.terminal.R.id.assist_esc_button, "\u001b", "assist.esc");
        host.bindAssistButton(uk.laurencegouws.terminal.R.id.assist_tab_button, "\t", "assist.tab");
        host.bindAssistButton(uk.laurencegouws.terminal.R.id.assist_pipe_button, "|", "assist.pipe");
        host.bindAssistButton(uk.laurencegouws.terminal.R.id.assist_slash_button, "/", "assist.slash");
    }

    private void bindAssistCharacterNavigationButtons() {
        host.bindAssistButton(uk.laurencegouws.terminal.R.id.assist_up_button, "\u001b[A", "assist.up");
        host.bindAssistButton(uk.laurencegouws.terminal.R.id.assist_down_button, "\u001b[B", "assist.down");
        host.bindAssistButton(uk.laurencegouws.terminal.R.id.assist_left_button, "\u001b[D", "assist.left");
        host.bindAssistButton(uk.laurencegouws.terminal.R.id.assist_right_button, "\u001b[C", "assist.right");
    }

    /** Binds optional assist-row IME toggle when the view id exists in the assist layout. */
    private void bindAssistImeToggleIfPresent(View root) {
        final Button imeButton = resolveAssistImeButton(root);
        if (imeButton == null) {
            return;
        }
        bindAssistImeToggleClick(imeButton);
    }

    private Button resolveAssistImeButton(View root) {
        final int imeButtonId =
                root.getResources().getIdentifier("assist_ime_button", "id", root.getContext().getPackageName());
        return imeButtonId != 0 ? root.findViewById(imeButtonId) : null;
    }

    private void bindAssistImeToggleClick(Button imeButton) {
        imeButton.setOnClickListener(view -> {
            toggleIme();
            host.appendEvent("assist.ime.toggle");
        });
    }

    public void applyModifierLatchState(ShellInputView.Host.ModifierLatchState state) {
        host.applyModifierLatchState(state);
    }

    public boolean currentImeVisible() {
        return host.currentImeVisible();
    }

    public void openIme() {
        final InputMethodManager imm = inputMethodManagerOrLogUnavailable();
        if (imm == null) {
            return;
        }
        runManualImeOpenSequence(imm, activeShellInputView());
    }

    /** Focus, soft-input show, and IME visibility bookkeeping for a manual open. */
    private void runManualImeOpenSequence(InputMethodManager imm, ShellInputView shellInputView) {
        appendManualImeOpenBeginTrace(shellInputView);
        requestInputFocusForManualImeOpen(shellInputView);
        showSoftInputAfterRestartInput(imm, shellInputView);
    }

    private void appendManualImeOpenBeginTrace(ShellInputView shellInputView) {
        host.appendEvent("manual.ime.open begin focus=" + shellInputView.hasFocus());
    }

    private void requestInputFocusForManualImeOpen(ShellInputView shellInputView) {
        requestInputFocus(shellInputView);
        host.appendEvent("manual.ime.open focusAfterRequest=" + shellInputView.hasFocus());
    }

    private void showSoftInputAfterRestartInput(InputMethodManager imm, ShellInputView shellInputView) {
        restartInputForManualImeOpen(imm, shellInputView);
        final boolean shown = showSoftInputImplicitForShell(imm, shellInputView);
        recordManualImeOpenSoftInputResult(shellInputView, shown);
    }

    private void restartInputForManualImeOpen(InputMethodManager imm, ShellInputView shellInputView) {
        imm.restartInput(shellInputView);
    }

    private boolean showSoftInputImplicitForShell(InputMethodManager imm, ShellInputView shellInputView) {
        return imm.showSoftInput(shellInputView, InputMethodManager.SHOW_IMPLICIT);
    }

    private void recordManualImeOpenSoftInputResult(ShellInputView shellInputView, boolean shown) {
        host.setImeVisible(shown || shellInputView.hasFocus());
        host.appendEvent("manual.ime.open shown=" + shown + " focus=" + shellInputView.hasFocus());
        host.updateStatus("ime.state.shown");
    }

    public void closeIme() {
        final InputMethodManager imm = inputMethodManagerOrLogUnavailable();
        if (imm == null) {
            return;
        }
        runManualImeCloseSequence(imm);
    }

    /** Hides soft input and records IME chrome state for a manual close. */
    private void runManualImeCloseSequence(InputMethodManager imm) {
        final boolean hidden = hideSoftInputFromShellWindowToken(imm);
        recordManualImeCloseSoftInputResult(hidden);
    }

    private boolean hideSoftInputFromShellWindowToken(InputMethodManager imm) {
        return imm.hideSoftInputFromWindow(activeShellInputWindowToken(), 0);
    }

    private IBinder activeShellInputWindowToken() {
        return activeShellInputView().getWindowToken();
    }

    private void recordManualImeCloseSoftInputResult(boolean hidden) {
        host.setImeVisible(false);
        host.appendEvent("manual.ime.close hidden=" + hidden);
        host.updateStatus("ime.state.hidden");
    }

    public void toggleIme() {
        if (currentImeVisible()) {
            closeIme();
            return;
        }
        openIme();
    }

    public void openSidebar() {
        if (shouldDeferSidebarOpen()) {
            return;
        }
        applySidebarOpenedChrome();
    }

    public void closeSidebar() {
        if (shouldDeferSidebarClose()) {
            return;
        }
        applySidebarClosedChrome();
    }

    private void applySidebarOpenedChrome() {
        host.setSidebarOpen(true);
        animateSidebarTranslation(true);
        updateSidebarVisibility(true);
    }

    private void applySidebarClosedChrome() {
        host.setSidebarOpen(false);
        animateSidebarTranslation(false);
        updateSidebarVisibility(false);
    }

    private boolean shouldDeferSidebarOpen() {
        return host.sidebarOpen() || host.debugViewEnabled();
    }

    private boolean shouldDeferSidebarClose() {
        return !host.sidebarOpen();
    }

    private void animateSidebarTranslation(boolean open) {
        final float targetX = leftSidebarTranslationXForOpenState(open);
        leftSidebarChrome().animate().translationX(targetX).setDuration(180).start();
    }

    private float leftSidebarTranslationXForOpenState(boolean open) {
        return open ? 0f : -leftSidebarChrome().getWidth();
    }

    public void updateSidebarVisibility(boolean visible) {
        applyDrawerScrimAndHotspotVisibility(visible);
    }

    private void applyDrawerScrimAndHotspotVisibility(boolean visible) {
        drawerScrimChrome().setVisibility(visible ? View.VISIBLE : View.GONE);
        drawerEdgeHotspotChrome().setVisibility(visible ? View.GONE : View.VISIBLE);
    }

    private InputMethodManager inputMethodManagerOrLogUnavailable() {
        final InputMethodManager imm = host.context().getSystemService(InputMethodManager.class);
        if (imm == null) {
            appendManualImeInputManagerUnavailableEvent();
        }
        return imm;
    }

    private void appendManualImeInputManagerUnavailableEvent() {
        host.appendEvent("manual.ime.unavailable state=true");
    }

    private void requestInputFocus(ShellInputView shellInputView) {
        shellInputView.requestFocusFromTouch();
        if (!shellInputView.hasFocus()) {
            shellInputView.requestFocus();
        }
    }

    private static final float EDGE_SWIPE_OPEN_PX = 48f;

    private boolean tryConsumeSidebarOpenEdgeSwipe(float delta) {
        if (delta > EDGE_SWIPE_OPEN_PX) {
            openSidebar();
            return true;
        }
        return false;
    }

    private boolean tryConsumeSidebarCloseEdgeSwipe(float delta) {
        if (delta < -EDGE_SWIPE_OPEN_PX) {
            closeSidebar();
            return true;
        }
        return false;
    }

    private final class EdgeSwipeListener implements View.OnTouchListener {
        private final boolean openListener;
        private float downX;

        EdgeSwipeListener(boolean openListener) { this.openListener = openListener; }

        @Override
        public boolean onTouch(View view, MotionEvent event) {
            switch (event.getActionMasked()) {
                case MotionEvent.ACTION_DOWN:
                    downX = event.getRawX();
                    return true;
                case MotionEvent.ACTION_UP:
                case MotionEvent.ACTION_CANCEL:
                    final float delta = event.getRawX() - downX;
                    if (openListener) {
                        if (tryConsumeSidebarOpenEdgeSwipe(delta)) {
                            return true;
                        }
                    } else if (tryConsumeSidebarCloseEdgeSwipe(delta)) {
                        return true;
                    }
                    return openListener;
                default:
                    return openListener;
            }
        }
    }
}
