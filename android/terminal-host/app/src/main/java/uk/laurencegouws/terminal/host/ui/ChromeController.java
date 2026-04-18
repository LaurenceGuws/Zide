package uk.laurencegouws.terminal.host.ui;

import android.view.MotionEvent;
import android.view.inputmethod.InputMethodManager;
import android.view.View;
import android.widget.Button;

import uk.laurencegouws.terminal.input.ShellInputView;

/**
 * Owns product chrome interactions: view-mode toggles, app-shell sidebar (navigation + terminal
 * session selection), assist/input helper bar, and IME policy.
 *
 * <p>Chrome remains slot-agnostic: it does not take {@link TerminalWidgetSlotId}; reopen only
 * when per-slot chrome behavior is a scoped product decision.</p>
 *
 * <p>IME visibility on {@link Host} uses explicit policy methods — no generic boolean
 * {@code setImeVisible(boolean)} on the chrome host seam.</p>
 */
public final class ChromeController {
    public interface Host {
        android.content.Context context();
        View drawerScrim();
        View drawerEdgeHotspot();
        View leftSidebar();
        boolean chromeDrawerSidebarOpen();
        void applyChromeDrawerSidebarOpen();
        void applyChromeDrawerSidebarClosed();
        void runPackageDoctor();

        void installAndroidEdgeTestBinary();

        void appendEvent(String event);
        /** Whether IME is considered visible for chrome policy (backed by activity state). */
        boolean chromeImeVisibilityPresent();
        /** Records IME hidden after chrome close-IME policy. */
        void applyChromeImeVisibilityHidden();
        /**
         * Records IME visibility after a show-soft-input attempt: {@code softInputShown || shellInputHasFocus}.
         */
        void applyChromeImeVisibilityFromOpenAttempt(boolean softInputShown, boolean shellInputHasFocus);
        void applyModifierLatchState(ShellInputView.Host.ModifierLatchState state);
        ShellInputView shellInputView();
        Button assistCtrlButton();
        Button assistAltButton();
        void sendDirectText(String text);
        void bindAssistButton(int id, String text, String eventName);
        void bindModifierAssistButton(Button button, ShellInputView.ModifierLatch modifier, String eventName);
        void updateStatus(String statusLabel);

        /** @return selected product terminal tab index, or {@code 0} if tab strip is absent */
        int selectedProductTerminalTabIndex();

        /** @return {@code true} if selected tab index changed */
        boolean applySelectProductTerminalTab(int tabIndex);

        Button productTerminalTab0Button();

        Button productTerminalTab1Button();

        void onProductTerminalTabSessionActivated(int tabIndex);
    }

    private final Host host;

    public ChromeController(Host host) {
        this.host = host;
    }

    public void bindSidebarControls() {
        final View sidebar = host.leftSidebar();
        ((Button) sidebar.findViewById(uk.laurencegouws.terminal.R.id.sidebar_restart_button)).setOnClickListener(view -> {
            host.appendEvent("manual.session.restart requested");
            closeSidebar();
        });
        ((Button) sidebar.findViewById(uk.laurencegouws.terminal.R.id.sidebar_packages_button)).setOnClickListener(view -> {
            closeSidebar();
            host.runPackageDoctor();
        });
        ((Button) sidebar.findViewById(uk.laurencegouws.terminal.R.id.sidebar_install_test_tools_button))
                .setOnClickListener(view -> {
                    closeSidebar();
                    host.installAndroidEdgeTestBinary();
                });

        bindProductTerminalTabStrip();

        host.drawerScrim().setOnClickListener(view -> closeSidebar());
        host.drawerEdgeHotspot().setOnTouchListener(new EdgeSwipeListener(true));
        host.leftSidebar().setOnTouchListener(new EdgeSwipeListener(false));
    }

    public void bindAssistBar() {
        bindAssistImeToggleIfPresent(host.shellInputView().getRootView());

        host.bindModifierAssistButton(host.assistCtrlButton(), ShellInputView.ModifierLatch.CTRL, "assist.ctrl");
        host.bindModifierAssistButton(host.assistAltButton(), ShellInputView.ModifierLatch.ALT, "assist.alt");

        host.bindAssistButton(uk.laurencegouws.terminal.R.id.assist_esc_button, "\u001b", "assist.esc");
        host.bindAssistButton(uk.laurencegouws.terminal.R.id.assist_tab_button, "\t", "assist.tab");
        host.bindAssistButton(uk.laurencegouws.terminal.R.id.assist_pipe_button, "|", "assist.pipe");
        host.bindAssistButton(uk.laurencegouws.terminal.R.id.assist_slash_button, "/", "assist.slash");
        host.bindAssistButton(uk.laurencegouws.terminal.R.id.assist_up_button, "\u001b[A", "assist.up");
        host.bindAssistButton(uk.laurencegouws.terminal.R.id.assist_down_button, "\u001b[B", "assist.down");
        host.bindAssistButton(uk.laurencegouws.terminal.R.id.assist_left_button, "\u001b[D", "assist.left");
        host.bindAssistButton(uk.laurencegouws.terminal.R.id.assist_right_button, "\u001b[C", "assist.right");

        host.applyModifierLatchState(host.shellInputView().modifierLatchState());
    }

    private void bindProductTerminalTabStrip() {
        final Button t0 = host.productTerminalTab0Button();
        final Button t1 = host.productTerminalTab1Button();
        if (t0 == null || t1 == null) {
            return;
        }
        t0.setOnClickListener(view -> selectProductTerminalTab(0));
        t1.setOnClickListener(view -> selectProductTerminalTab(1));
        syncProductTerminalTabChrome();
    }

    private void selectProductTerminalTab(final int tabIndex) {
        final boolean changed = host.applySelectProductTerminalTab(tabIndex);
        host.appendEvent("app_shell.product_terminal_tab.select index=" + tabIndex);
        if (changed) {
            host.onProductTerminalTabSessionActivated(tabIndex);
        }
        syncProductTerminalTabChrome();
    }

    private void syncProductTerminalTabChrome() {
        final Button t0 = host.productTerminalTab0Button();
        final Button t1 = host.productTerminalTab1Button();
        if (t0 == null || t1 == null) {
            return;
        }
        final int sel = host.selectedProductTerminalTabIndex();
        applyTabButtonSelected(t0, sel == 0);
        applyTabButtonSelected(t1, sel == 1);
    }

    private static void applyTabButtonSelected(Button button, boolean selected) {
        button.setSelected(selected);
        button.setAlpha(selected ? 1.0f : 0.65f);
    }

    /** Binds optional assist-row IME toggle when the view id exists in the assist layout. */
    private void bindAssistImeToggleIfPresent(View root) {
        final int imeButtonId =
                root.getResources().getIdentifier("assist_ime_button", "id", root.getContext().getPackageName());
        if (imeButtonId == 0) {
            return;
        }
        final Button imeButton = root.findViewById(imeButtonId);
        if (imeButton == null) {
            return;
        }
        imeButton.setOnClickListener(view -> {
            toggleIme();
            host.appendEvent("assist.ime.toggle");
        });
    }

    public void applyModifierLatchState(ShellInputView.Host.ModifierLatchState state) {
        host.applyModifierLatchState(state);
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
        host.applyChromeImeVisibilityFromOpenAttempt(shown, shellInputView.hasFocus());
        host.appendEvent("manual.ime.open shown=" + shown + " focus=" + shellInputView.hasFocus());
        host.updateStatus("ime.state.shown");
    }

    public void closeIme() {
        final InputMethodManager imm = inputMethodManagerOrLogUnavailable();
        if (imm == null) {
            return;
        }
        final boolean hidden = imm.hideSoftInputFromWindow(host.shellInputView().getWindowToken(), 0);
        host.applyChromeImeVisibilityHidden();
        host.appendEvent("manual.ime.close hidden=" + hidden);
        host.updateStatus("ime.state.hidden");
    }

    public void toggleIme() {
        if (host.chromeImeVisibilityPresent()) {
            closeIme();
            return;
        }
        openIme();
    }

    public void openSidebar() {
        if (shouldDeferSidebarOpen()) {
            return;
        }
        host.applyChromeDrawerSidebarOpen();
        animateSidebarTranslation(true);
        updateSidebarVisibility(true);
    }

    public void closeSidebar() {
        if (shouldDeferSidebarClose()) {
            return;
        }
        host.applyChromeDrawerSidebarClosed();
        animateSidebarTranslation(false);
        updateSidebarVisibility(false);
    }

    private boolean shouldDeferSidebarOpen() {
        return host.chromeDrawerSidebarOpen();
    }

    private boolean shouldDeferSidebarClose() {
        return !host.chromeDrawerSidebarOpen();
    }

    private void animateSidebarTranslation(boolean open) {
        final float targetX = open ? 0f : -host.leftSidebar().getWidth();
        host.leftSidebar().animate().translationX(targetX).setDuration(180).start();
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
                        if (delta > EDGE_SWIPE_OPEN_PX) {
                            openSidebar();
                            return true;
                        }
                    } else if (delta < -EDGE_SWIPE_OPEN_PX) {
                        closeSidebar();
                        return true;
                    }
                    return openListener;
                default:
                    return openListener;
            }
        }
    }
}
