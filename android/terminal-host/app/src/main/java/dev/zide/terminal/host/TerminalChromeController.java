package dev.zide.terminal.host;

import android.view.MotionEvent;
import android.view.inputmethod.InputMethodManager;
import android.view.View;
import android.widget.Button;

import dev.zide.terminal.input.ShellInputView;

/** Owns product chrome interactions: view-mode toggles, sidebar, assist bar, and IME policy. */
public final class TerminalChromeController {
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

    public TerminalChromeController(Host host) {
        this.host = host;
    }

    public void bindViewModeToggle() {
        host.debugViewModeButton().setOnClickListener(view -> host.showProductView("view.mode debug=false", "product-view"));
    }

    public void bindSidebarControls() {
        final Button restartButton = (Button) host.leftSidebar().findViewById(dev.zide.terminal.R.id.sidebar_restart_button);
        final Button debugButton = (Button) host.leftSidebar().findViewById(dev.zide.terminal.R.id.sidebar_debug_button);
        final Button packagesButton = (Button) host.leftSidebar().findViewById(dev.zide.terminal.R.id.sidebar_packages_button);

        restartButton.setOnClickListener(view -> {
            host.appendEvent("manual.shellRestart requested");
            closeSidebar();
        });

        debugButton.setOnClickListener(view -> {
            host.showDebugView("view.mode debug=true", "debug-view");
            closeSidebar();
        });

        packagesButton.setOnClickListener(view -> {
            closeSidebar();
            host.runPackageDoctor();
        });

        host.drawerScrim().setOnClickListener(view -> closeSidebar());
        host.drawerEdgeHotspot().setOnTouchListener(new EdgeSwipeListener(true));
        host.leftSidebar().setOnTouchListener(new EdgeSwipeListener(false));
    }

    public void bindAssistBar() {
        final View root = host.shellInputView().getRootView();
        final int imeButtonId =
                root.getResources().getIdentifier("assist_ime_button", "id", root.getContext().getPackageName());
        final Button imeButton = imeButtonId != 0 ? root.findViewById(imeButtonId) : null;
        if (imeButton != null) {
            imeButton.setOnClickListener(view -> {
                toggleIme();
                host.appendEvent("assist.ime");
            });
        }
        host.bindAssistButton(dev.zide.terminal.R.id.assist_esc_button, "\u001b", "assist.esc");
        host.bindAssistButton(dev.zide.terminal.R.id.assist_tab_button, "\t", "assist.tab");
        host.bindModifierAssistButton(host.assistCtrlButton(), ShellInputView.ModifierLatch.CTRL, "assist.ctrl");
        host.bindModifierAssistButton(host.assistAltButton(), ShellInputView.ModifierLatch.ALT, "assist.alt");
        host.bindAssistButton(dev.zide.terminal.R.id.assist_pipe_button, "|", "assist.pipe");
        host.bindAssistButton(dev.zide.terminal.R.id.assist_slash_button, "/", "assist.slash");
        host.bindAssistButton(dev.zide.terminal.R.id.assist_up_button, "\u001b[A", "assist.up");
        host.bindAssistButton(dev.zide.terminal.R.id.assist_down_button, "\u001b[B", "assist.down");
        host.bindAssistButton(dev.zide.terminal.R.id.assist_left_button, "\u001b[D", "assist.left");
        host.bindAssistButton(dev.zide.terminal.R.id.assist_right_button, "\u001b[C", "assist.right");
        host.applyModifierLatchState(host.shellInputView().modifierLatchState());
    }

    public void applyModifierLatchState(ShellInputView.Host.ModifierLatchState state) {
        host.applyModifierLatchState(state);
    }

    public boolean currentImeVisible() {
        return host.currentImeVisible();
    }

    public void openIme() {
        final InputMethodManager imm = host.context().getSystemService(InputMethodManager.class);
        if (imm == null) {
            host.appendEvent("manual.ime unavailable=true");
            return;
        }

        final ShellInputView shellInputView = host.shellInputView();
        host.appendEvent("manual.imeOpen begin focus=" + shellInputView.hasFocus());
        shellInputView.requestFocusFromTouch();
        if (!shellInputView.hasFocus()) {
            shellInputView.requestFocus();
        }
        host.appendEvent("manual.imeOpen focusAfterRequest=" + shellInputView.hasFocus());
        imm.restartInput(shellInputView);
        final boolean shown = imm.showSoftInput(shellInputView, InputMethodManager.SHOW_IMPLICIT);
        host.setImeVisible(shown || shellInputView.hasFocus());
        host.appendEvent("manual.imeOpen shown=" + shown + " focus=" + shellInputView.hasFocus());
        host.updateStatus("ime-shown");
    }

    public void closeIme() {
        final InputMethodManager imm = host.context().getSystemService(InputMethodManager.class);
        if (imm == null) {
            host.appendEvent("manual.ime unavailable=true");
            return;
        }
        final boolean hidden = imm.hideSoftInputFromWindow(host.shellInputView().getWindowToken(), 0);
        host.setImeVisible(false);
        host.appendEvent("manual.imeClose hidden=" + hidden);
        host.updateStatus("ime-hidden");
    }

    public void toggleIme() {
        if (currentImeVisible()) {
            closeIme();
            return;
        }
        openIme();
    }

    public void openSidebar() {
        if (host.sidebarOpen() || host.debugViewEnabled()) {
            return;
        }
        host.setSidebarOpen(true);
        host.leftSidebar().animate().translationX(0).setDuration(180).start();
        updateSidebarVisibility(true);
    }

    public void closeSidebar() {
        if (!host.sidebarOpen()) {
            return;
        }
        host.setSidebarOpen(false);
        host.leftSidebar().animate().translationX(-host.leftSidebar().getWidth()).setDuration(180).start();
        updateSidebarVisibility(false);
    }

    public void updateSidebarVisibility(boolean visible) {
        host.drawerScrim().setVisibility(visible ? View.VISIBLE : View.GONE);
        host.drawerEdgeHotspot().setVisibility(visible ? View.GONE : View.VISIBLE);
    }

    private final class EdgeSwipeListener implements View.OnTouchListener {
        private static final float OPEN_THRESHOLD_PX = 48f;
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
                        if (delta > OPEN_THRESHOLD_PX) {
                            host.setSidebarOpen(true);
                            updateSidebarVisibility(true);
                            return true;
                        }
                    } else if (delta < -OPEN_THRESHOLD_PX) {
                        host.setSidebarOpen(false);
                        updateSidebarVisibility(false);
                        return true;
                    }
                    return openListener;
                default:
                    return openListener;
            }
        }
    }
}
