package uk.laurencegouws.terminal.userland;

import android.view.SurfaceView;
import android.view.View;
import android.widget.Button;
import android.widget.TextView;

/** Owns product shell blocker copy and visibility policy. */
public final class ShellStatePresenter {
    public interface Host {
        boolean nativeLoaded();

        boolean sharedShellRendererActive();

        boolean installInstalling();

        boolean installFailed();

        UserlandReadinessState readinessState();

        UserlandInstallState installState();

        SurfaceView surfaceView();

        View productReadinessBlocker();

        TextView productReadinessTitle();

        TextView productReadinessDetail();

        Button productReadinessRetryButton();

        void showScrollOverlay(boolean visible);
    }

    private final Host host;

    public ShellStatePresenter(Host host) {
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
        host.productReadinessBlocker().setVisibility(showBlocker ? View.VISIBLE : View.GONE);
        host.showScrollOverlay(!showBlocker);
        if (showBlocker) {
            host.productReadinessTitle().setText(UserlandReadinessUiPolicy.title(readinessState, installState, rendererMissing));
            host.productReadinessDetail().setText(UserlandReadinessUiPolicy.detail(
                    host.productReadinessTitle().getContext(),
                    readinessState,
                    installState,
                    rendererMissing));
            host.productReadinessRetryButton().setEnabled(!installState.isInstalling());
            host.productReadinessRetryButton().setText(UserlandReadinessUiPolicy.actionLabel(readinessState, installState));
        }
    }
}
