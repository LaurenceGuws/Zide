package dev.zide.terminal.host;

import android.view.SurfaceView;
import android.view.View;
import android.widget.Button;
import android.widget.TextView;

import dev.zide.terminal.userland.ProductShellStatePresenter;
import dev.zide.terminal.userland.UserlandReadinessState;
import dev.zide.terminal.userland.UserlandInstallState;

/**
 * Adapts activity-owned callbacks and views to {@link ProductShellStatePresenter.Host}.
 */
public final class TerminalProductShellStateHostBridge implements ProductShellStatePresenter.Host {
    /** Activity callbacks used by product shell blocker presentation. */
    public interface Callbacks {
        boolean nativeLoaded();

        boolean sharedShellRendererActive();

        boolean installInstalling();

        boolean installFailed();

        UserlandReadinessState readinessState();

        UserlandInstallState installState();

        SurfaceView surfaceView();
    }

    private final View productBootstrapBlocker;
    private final View terminalScrollOverlay;
    private final TextView productBootstrapTitle;
    private final TextView productBootstrapDetail;
    private final Button productBootstrapRetryButton;
    private final Callbacks callbacks;

    public TerminalProductShellStateHostBridge(
            View productBootstrapBlocker,
            View terminalScrollOverlay,
            TextView productBootstrapTitle,
            TextView productBootstrapDetail,
            Button productBootstrapRetryButton,
            Callbacks callbacks) {
        this.productBootstrapBlocker = productBootstrapBlocker;
        this.terminalScrollOverlay = terminalScrollOverlay;
        this.productBootstrapTitle = productBootstrapTitle;
        this.productBootstrapDetail = productBootstrapDetail;
        this.productBootstrapRetryButton = productBootstrapRetryButton;
        this.callbacks = callbacks;
    }

    @Override
    public boolean nativeLoaded() {
        return callbacks.nativeLoaded();
    }

    @Override
    public boolean sharedShellRendererActive() {
        return callbacks.sharedShellRendererActive();
    }

    @Override
    public boolean installInstalling() {
        return callbacks.installInstalling();
    }

    @Override
    public boolean installFailed() {
        return callbacks.installFailed();
    }

    @Override
    public UserlandReadinessState readinessState() {
        return callbacks.readinessState();
    }

    @Override
    public UserlandInstallState installState() {
        return callbacks.installState();
    }

    @Override
    public SurfaceView surfaceView() {
        return callbacks.surfaceView();
    }

    @Override
    public View productBootstrapBlocker() {
        return productBootstrapBlocker;
    }

    @Override
    public TextView productBootstrapTitle() {
        return productBootstrapTitle;
    }

    @Override
    public TextView productBootstrapDetail() {
        return productBootstrapDetail;
    }

    @Override
    public Button productBootstrapRetryButton() {
        return productBootstrapRetryButton;
    }

    @Override
    public void showScrollOverlay(boolean visible) {
        terminalScrollOverlay.setVisibility(visible ? View.VISIBLE : View.GONE);
    }
}
