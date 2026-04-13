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

        UserlandBootstrapState bootstrapState();

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
        final UserlandBootstrapState bootstrapState = host.bootstrapState();
        final UserlandInstallState installState = host.installState();
        final boolean launchReady = bootstrapState.launchReady;
        final boolean sharedShellActive = launchReady && host.nativeLoaded() && host.sharedShellRendererActive();
        final SurfaceView surfaceView = host.surfaceView();
        final boolean surfaceReady = surfaceView != null && surfaceView.getHolder().getSurface().isValid();
        final boolean rendererMissing = launchReady && bootstrapState.expectedCurrent && surfaceReady && !sharedShellActive;
        final boolean showBlocker = installState.isInstalling()
                || installState.isFailed()
                || !launchReady
                || !bootstrapState.expectedCurrent
                || rendererMissing;
        host.productBootstrapBlocker().setVisibility(showBlocker ? View.VISIBLE : View.GONE);
        host.showScrollOverlay(!showBlocker);
        if (showBlocker) {
            host.productBootstrapTitle().setText(UserlandBootstrapUiPolicy.title(bootstrapState, installState, rendererMissing));
            host.productBootstrapDetail().setText(UserlandBootstrapUiPolicy.detail(
                    (android.content.Context) host.productBootstrapTitle().getContext(),
                    bootstrapState,
                    installState,
                    rendererMissing));
            host.productBootstrapRetryButton().setEnabled(!installState.isInstalling());
            host.productBootstrapRetryButton().setText(UserlandBootstrapUiPolicy.actionLabel(bootstrapState, installState));
        }
    }
}
