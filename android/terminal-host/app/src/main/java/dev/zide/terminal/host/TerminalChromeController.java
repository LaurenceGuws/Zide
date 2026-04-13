package dev.zide.terminal.host;

import android.view.MotionEvent;
import android.view.View;
import android.widget.Button;

import dev.zide.terminal.input.ShellInputView;

/** Owns product chrome interactions: view-mode toggles, sidebar, assist bar, and IME policy. */
public final class TerminalChromeController {
    public interface Host {
        View debugViewModeButton();
        View drawerScrim();
        View drawerEdgeHotspot();
        View leftSidebar();
        boolean sidebarOpen();
        void setSidebarOpen(boolean open);
        boolean debugViewEnabled();
        void showProductView(String eventName, String statusLabel);
        void showDebugView(String eventName, String statusLabel);
        void closeSidebar();
        void updateSidebarVisibility(boolean visible);
        void runPackageDoctor();
        void appendEvent(String event);
        void toggleIme();
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
            host.closeSidebar();
        });

        debugButton.setOnClickListener(view -> {
            host.showDebugView("view.mode debug=true", "debug-view");
            host.closeSidebar();
        });

        packagesButton.setOnClickListener(view -> {
            host.closeSidebar();
            host.runPackageDoctor();
        });

        host.drawerScrim().setOnClickListener(view -> host.closeSidebar());
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
                host.toggleIme();
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

    public void applyViewMode(boolean debugViewEnabled, View productView, View debugView, View terminalScrollOverlay, View productSurfaceContainer) {
        productView.setVisibility(debugViewEnabled ? View.GONE : View.VISIBLE);
        debugView.setVisibility(debugViewEnabled ? View.VISIBLE : View.GONE);
        if (debugViewEnabled) {
            host.closeSidebar();
            terminalScrollOverlay.setVisibility(View.GONE);
        } else {
            productSurfaceContainer.post(() -> host.updateStatus("product-view"));
        }
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
                            host.updateSidebarVisibility(true);
                            return true;
                        }
                    } else if (delta < -OPEN_THRESHOLD_PX) {
                        host.setSidebarOpen(false);
                        host.updateSidebarVisibility(false);
                        return true;
                    }
                    return openListener;
                default:
                    return openListener;
            }
        }
    }
}
