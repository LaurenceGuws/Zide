package dev.zide.terminal.userland;

import android.view.SurfaceView;
import android.view.View;
import android.widget.Button;
import android.widget.TextView;

/** Owns product shell blocker copy and visibility policy. */
public final class ProductShellStatePresenter {
    public interface Host {
        boolean nativeLoaded();

        boolean sharedShellRendererActive();

        boolean installInstalling();

        boolean installFailed();

        UserlandReadinessState readinessState();

        UserlandInstallState installState();

        SurfaceView surfaceView();

        View productBootstrapBlocker();

        TextView productBootstrapTitle();

        TextView productBootstrapDetail();

        Button productBootstrapRetryButton();

        void showScrollOverlay(boolean visible);
    }

    private final Host host;

    public ProductShellStatePresenter(Host host) {
        this.host = host;
    }

    public void refresh() {
        final UserlandReadinessState readinessState = host.readinessState();
        final UserlandInstallState installState = host.installState();
        final boolean launchReady = readinessState.launchReady;
        final boolean sharedShellActive = launchReady && host.nativeLoaded() && host.sharedShellRendererActive();
        final SurfaceView surfaceView = host.surfaceView();
        final boolean surfaceReady = surfaceView != null && surfaceView.getHolder().getSurface().isValid();
        final boolean rendererMissing = launchReady && readinessState.expectedCurrent && surfaceReady && !sharedShellActive;
        final boolean showBlocker = installState.isInstalling()
                || installState.isFailed()
                || !launchReady
                || !readinessState.expectedCurrent
                || rendererMissing;
        host.productBootstrapBlocker().setVisibility(showBlocker ? View.VISIBLE : View.GONE);
        host.showScrollOverlay(!showBlocker);
        if (showBlocker) {
            host.productBootstrapTitle().setText(UserlandReadinessUiPolicy.title(readinessState, installState, rendererMissing));
            host.productBootstrapDetail().setText(UserlandReadinessUiPolicy.detail(
                    (android.content.Context) host.productBootstrapTitle().getContext(),
                    readinessState,
                    installState,
                    rendererMissing));
            host.productBootstrapRetryButton().setEnabled(!installState.isInstalling());
            host.productBootstrapRetryButton().setText(UserlandReadinessUiPolicy.actionLabel(readinessState, installState));
        }
    }
}
