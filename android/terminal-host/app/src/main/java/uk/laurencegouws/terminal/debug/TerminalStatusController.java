package uk.laurencegouws.terminal.debug;

import android.util.Log;
import android.view.SurfaceView;
import android.widget.TextView;

import uk.laurencegouws.terminal.userland.UserlandReadinessState;
import uk.laurencegouws.terminal.userland.UserlandInstallState;

/** Owns the debug status surface and event log presentation. */
public final class TerminalStatusController {
    public interface Host {
        boolean debugViewEnabled();

        boolean nativeLoaded();

        boolean hasWindowFocus();

        boolean imeVisible();

        SurfaceView surfaceView();

        int visibleViewportWidth();

        int visibleViewportHeight();

        UserlandInstallState installState();

        UserlandReadinessState readinessState();

        AndroidDebugFormatter.SurfaceEventSnapshot currentSurfaceStateSnapshot();
    }

    private static final String TAG = "ZideAndroidTerminal";
    private static final int MAX_LOG_CHARS = 12000;

    private final TextView statusText;
    private final TextView eventLogText;
    private final Host host;
    private final StringBuilder eventLog = new StringBuilder();

    public TerminalStatusController(TextView statusText, TextView eventLogText, Host host) {
        this.statusText = statusText;
        this.eventLogText = eventLogText;
        this.host = host;
    }

    public void appendEvent(String message) {
        final String line = String.format("[%08d] %s", android.os.SystemClock.uptimeMillis(), message);
        Log.i(TAG, line);
        if (eventLog.length() > 0) {
            eventLog.append('\n');
        }
        eventLog.append(line);
        if (eventLog.length() > MAX_LOG_CHARS) {
            eventLog.delete(0, eventLog.length() - MAX_LOG_CHARS);
        }
        eventLogText.setText(eventLog.toString());
    }

    public void callNative(String event, long seq) {
        appendEvent(event + " seq=" + seq);
    }

    public void callNativeWithSurfaceState(
            String event,
            long seq,
            AndroidDebugFormatter.SurfaceEventSnapshot state) {
        appendEvent(AndroidDebugFormatter.formatSurfaceEvent(
                event,
                new AndroidDebugFormatter.SurfaceEventSnapshot(
                        seq,
                        state.token,
                        state.epoch,
                        state.transition,
                        state.glesStatus,
                        state.glesSwapCount,
                        state.glesBoundEpoch,
                        state.glesContextCreateCount,
                        state.glesSurfaceCreateCount,
                        state.glesTextureCreateCount,
                        state.glesTextureAlive,
                        state.glesTextureUploadCount,
                        state.glesTextureUpdateCount,
                        state.glesTextureResizeCount,
                        state.glesTextureWidth,
                        state.glesTextureHeight)));
    }

    public void refreshDebugStatusSurface() {
        if (!host.debugViewEnabled()) {
            return;
        }
        updateStatus("shell-state", host.readinessState());
    }

    public void updateStatus(String state) {
        updateStatus(state, host.readinessState());
    }

    public void updateStatus(String state, UserlandReadinessState readinessState) {
        if (!host.debugViewEnabled()) {
            return;
        }
        final SurfaceView surfaceView = host.surfaceView();
        if (surfaceView == null) {
            return;
        }
        final AndroidDebugFormatter.SurfaceEventSnapshot surfaceState = host.currentSurfaceStateSnapshot();
        statusText.setText(AndroidDebugFormatter.formatStatus(
                new AndroidDebugFormatter.StatusSnapshot(
                        state,
                        host.nativeLoaded(),
                        host.hasWindowFocus(),
                        host.imeVisible(),
                        surfaceView.getHolder().getSurface().isValid(),
                        surfaceView.getWidth(),
                        surfaceView.getHeight(),
                        host.visibleViewportWidth(),
                        host.visibleViewportHeight(),
                        host.installState().status,
                        host.installState().detail,
                        readinessState.state,
                        readinessState.format,
                        readinessState.artifact,
                        readinessState.version,
                        readinessState.provider,
                        readinessState.launchReady,
                        readinessState.expectedCurrent,
                        surfaceState.glesStatus,
                        surfaceState.glesSwapCount,
                        surfaceState.glesBoundEpoch,
                        surfaceState.glesContextCreateCount,
                        surfaceState.glesSurfaceCreateCount,
                        surfaceState.glesTextureCreateCount,
                        surfaceState.glesTextureAlive,
                        surfaceState.glesTextureUploadCount,
                        surfaceState.glesTextureUpdateCount,
                        surfaceState.glesTextureResizeCount,
                        surfaceState.glesTextureWidth,
                        surfaceState.glesTextureHeight)));
    }
}
