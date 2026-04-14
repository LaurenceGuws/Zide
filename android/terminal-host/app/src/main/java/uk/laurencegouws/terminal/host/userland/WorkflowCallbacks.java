package uk.laurencegouws.terminal.host.userland;

import android.widget.TextView;

import java.util.function.BiConsumer;
import java.util.function.Consumer;
import java.util.function.Supplier;

import uk.laurencegouws.terminal.userland.UserlandReadinessState;
import uk.laurencegouws.terminal.userland.UserlandInstallState;
import uk.laurencegouws.terminal.userland.UserlandRelease;

/** Functional callback adapter for {@link WorkflowBridge}. */
public final class WorkflowCallbacks implements WorkflowBridge.Callbacks {
    private final Supplier<UserlandRelease> release;
    private final Consumer<String> appendEvent;
    private final BiConsumer<UserlandInstallState, String> applyInstallState;
    private final Consumer<UserlandInstallState> setInstallState;
    private final Consumer<UserlandReadinessState> setReadinessState;
    private final RestartShellSessionCallback restartShellSession;
    private final BiConsumer<String, String> showDebugView;
    private final TextView packageStatusText;
    private final Consumer<String> updateStatus;

    /** Functional callback for shell restart requests. */
    public interface RestartShellSessionCallback {
        void restart(String eventName, String statusLabel, boolean logRefresh);
    }

    public WorkflowCallbacks(
            Supplier<UserlandRelease> release,
            Consumer<String> appendEvent,
            BiConsumer<UserlandInstallState, String> applyInstallState,
            Consumer<UserlandInstallState> setInstallState,
            Consumer<UserlandReadinessState> setReadinessState,
            RestartShellSessionCallback restartShellSession,
            BiConsumer<String, String> showDebugView,
            TextView packageStatusText,
            Consumer<String> updateStatus) {
        this.release = release;
        this.appendEvent = appendEvent;
        this.applyInstallState = applyInstallState;
        this.setInstallState = setInstallState;
        this.setReadinessState = setReadinessState;
        this.restartShellSession = restartShellSession;
        this.showDebugView = showDebugView;
        this.packageStatusText = packageStatusText;
        this.updateStatus = updateStatus;
    }

    @Override
    public UserlandRelease release() {
        return release.get();
    }

    @Override
    public void appendEvent(String event) {
        appendEvent.accept(event);
    }

    @Override
    public void applyInstallState(UserlandInstallState installState, String statusLabel) {
        applyInstallState.accept(installState, statusLabel);
    }

    @Override
    public void setInstallState(UserlandInstallState installState) {
        setInstallState.accept(installState);
    }

    @Override
    public void setReadinessState(UserlandReadinessState readinessState) {
        setReadinessState.accept(readinessState);
    }

    @Override
    public void restartShellSession(String eventName, String statusLabel, boolean logRefresh) {
        restartShellSession.restart(eventName, statusLabel, logRefresh);
    }

    @Override
    public void showDebugView(String eventName, String statusLabel) {
        showDebugView.accept(eventName, statusLabel);
    }

    @Override
    public void setPackageStatusText(String text) {
        packageStatusText.setText(text);
    }

    @Override
    public void updateStatus(String statusLabel) {
        updateStatus.accept(statusLabel);
    }
}
