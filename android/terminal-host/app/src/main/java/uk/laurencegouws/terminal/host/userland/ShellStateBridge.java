package uk.laurencegouws.terminal.host.userland;

import android.view.SurfaceView;
import android.view.View;
import android.widget.Button;
import android.widget.TextView;

import uk.laurencegouws.terminal.userland.ShellStatePresenter;
import uk.laurencegouws.terminal.userland.UserlandReadinessState;
import uk.laurencegouws.terminal.userland.UserlandInstallState;

/**
 * Adapts activity-owned callbacks and views to {@link ShellStatePresenter.Host}.
 */
public final class ShellStateBridge implements ShellStatePresenter.Host {
    /** Harness callbacks used by product shell blocker presentation. */
    public interface Callbacks {
        boolean nativeLoaded();

        boolean sharedShellRendererActive();

        boolean installInstalling();

        boolean installFailed();

        UserlandReadinessState readinessState();

        UserlandInstallState installState();

        SurfaceView surfaceView();
    }

    private final View productReadinessBlocker;
    private final View terminalScrollOverlay;
    private final TextView productReadinessTitle;
    private final TextView productReadinessDetail;
    private final Button productReadinessRetryButton;
    private final Callbacks callbacks;

    public ShellStateBridge(
            View productReadinessBlocker,
            View terminalScrollOverlay,
            TextView productReadinessTitle,
            TextView productReadinessDetail,
            Button productReadinessRetryButton,
            Callbacks callbacks) {
        this.productReadinessBlocker = productReadinessBlocker;
        this.terminalScrollOverlay = terminalScrollOverlay;
        this.productReadinessTitle = productReadinessTitle;
        this.productReadinessDetail = productReadinessDetail;
        this.productReadinessRetryButton = productReadinessRetryButton;
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
    public View productReadinessBlocker() {
        return productReadinessBlocker;
    }

    @Override
    public TextView productReadinessTitle() {
        return productReadinessTitle;
    }

    @Override
    public TextView productReadinessDetail() {
        return productReadinessDetail;
    }

    @Override
    public Button productReadinessRetryButton() {
        return productReadinessRetryButton;
    }

    @Override
    public void showScrollOverlay(boolean visible) {
        terminalScrollOverlay.setVisibility(visible ? View.VISIBLE : View.GONE);
    }
}
