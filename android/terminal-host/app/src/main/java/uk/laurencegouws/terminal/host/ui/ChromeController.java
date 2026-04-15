package uk.laurencegouws.terminal.host.ui;

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
        host.debugViewModeButton().setOnClickListener(
                view -> host.showProductView("view.mode debug=false", "product-view"));
    }

    public void bindSidebarControls() {
        bindSidebarNavActions();
        bindSidebarDrawerGestures();
    }

    private void bindSidebarNavActions() {
        final View sidebar = host.leftSidebar();
        ((Button) sidebar.findViewById(uk.laurencegouws.terminal.R.id.sidebar_restart_button)).setOnClickListener(view -> {
            host.appendEvent("manual.session.restart requested");
            closeSidebar();
        });
        ((Button) sidebar.findViewById(uk.laurencegouws.terminal.R.id.sidebar_debug_button)).setOnClickListener(view -> {
            host.showDebugView("view.mode debug=true", "debug-view");
            closeSidebar();
        });
        ((Button) sidebar.findViewById(uk.laurencegouws.terminal.R.id.sidebar_packages_button)).setOnClickListener(view -> {
            closeSidebar();
            host.runPackageDoctor();
        });
    }

    private void bindSidebarDrawerGestures() {
        host.drawerScrim().setOnClickListener(view -> closeSidebar());
        host.drawerEdgeHotspot().setOnTouchListener(new EdgeSwipeListener(true));
        host.leftSidebar().setOnTouchListener(new EdgeSwipeListener(false));
    }

    public void bindAssistBar() {
        bindAssistImeToggleIfPresent(host.shellInputView().getRootView());
        bindAssistRowInputChrome();
    }

    private void bindAssistRowInputChrome() {
        bindAssistModifierLatchButtons();
        bindAssistCharacterButtons();
        host.applyModifierLatchState(host.shellInputView().modifierLatchState());
    }

    private void bindAssistModifierLatchButtons() {
        host.bindModifierAssistButton(host.assistCtrlButton(), ShellInputView.ModifierLatch.CTRL, "assist.ctrl");
        host.bindModifierAssistButton(host.assistAltButton(), ShellInputView.ModifierLatch.ALT, "assist.alt");
    }

    /** Wires assist-row text keys and arrow keys to host direct-send binding. */
    private void bindAssistCharacterButtons() {
        host.bindAssistButton(uk.laurencegouws.terminal.R.id.assist_esc_button, "\u001b", "assist.esc");
        host.bindAssistButton(uk.laurencegouws.terminal.R.id.assist_tab_button, "\t", "assist.tab");
        host.bindAssistButton(uk.laurencegouws.terminal.R.id.assist_pipe_button, "|", "assist.pipe");
        host.bindAssistButton(uk.laurencegouws.terminal.R.id.assist_slash_button, "/", "assist.slash");
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
        final int imeButtonId = assistImeButtonResourceIdFromRoot(root);
        return imeButtonId != 0 ? root.findViewById(imeButtonId) : null;
    }

    private int assistImeButtonResourceIdFromRoot(View root) {
        return root.getResources().getIdentifier("assist_ime_button", "id", root.getContext().getPackageName());
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
        final ShellInputView shellInputView = host.shellInputView();
        host.appendEvent("manual.ime.open begin focus=" + shellInputView.hasFocus());
        shellInputView.requestFocusFromTouch();
        if (!shellInputView.hasFocus()) {
            shellInputView.requestFocus();
        }
        host.appendEvent("manual.ime.open focusAfterRequest=" + shellInputView.hasFocus());
        imm.restartInput(shellInputView);
        final boolean shown = imm.showSoftInput(shellInputView, InputMethodManager.SHOW_IMPLICIT);
        host.setImeVisible(shown || shellInputView.hasFocus());
        host.appendEvent("manual.ime.open shown=" + shown + " focus=" + shellInputView.hasFocus());
        host.updateStatus("ime.state.shown");
    }

    public void closeIme() {
        final InputMethodManager imm = inputMethodManagerOrLogUnavailable();
        if (imm == null) {
            return;
        }
        final boolean hidden = imm.hideSoftInputFromWindow(host.shellInputView().getWindowToken(), 0);
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
        host.leftSidebar().animate().translationX(targetX).setDuration(180).start();
    }

    private float leftSidebarTranslationXForOpenState(boolean open) {
        return open ? 0f : -host.leftSidebar().getWidth();
    }

    public void updateSidebarVisibility(boolean visible) {
        host.drawerScrim().setVisibility(visible ? View.VISIBLE : View.GONE);
        host.drawerEdgeHotspot().setVisibility(visible ? View.GONE : View.VISIBLE);
    }

    private InputMethodManager inputMethodManagerOrLogUnavailable() {
        final InputMethodManager imm = host.context().getSystemService(InputMethodManager.class);
        if (imm == null) {
            host.appendEvent("manual.ime.unavailable state=true");
        }
        return imm;
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
