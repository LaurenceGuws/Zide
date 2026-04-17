package uk.laurencegouws.terminal.userland;

import android.widget.Button;

/** Owns readiness-blocker retry/install button policy. */
public final class UserlandReadinessBlockerController {
    /** Host callbacks for state and side effects. */
    public interface Host {
        UserlandInstallState installState();

        UserlandReadinessState readinessState();

        UserlandWorkflowController workflowController();

        UserlandSessionCoordinator sessionCoordinator();

        void appendEvent(String event);

        void updateStatus(String statusLabel);
    }

    private final Button retryButton;
    private final Host host;

    public UserlandReadinessBlockerController(Button retryButton, Host host) {
        this.retryButton = retryButton;
        this.host = host;
    }

    public void bind() {
        retryButton.setOnClickListener(view -> {
            if (host.installState().isInstalling()) {
                host.appendEvent("product.install.ignored reason=already-installing");
                return;
            }
            if (UserlandReadinessUiPolicy.shouldStartInstall(host.readinessState())) {
                host.workflowController().startInstall();
                return;
            }
            host.appendEvent("product.readiness.retry");
            host.sessionCoordinator().refreshAndApply(true);
            host.updateStatus("product.readiness.retry");
        });
    }
}
