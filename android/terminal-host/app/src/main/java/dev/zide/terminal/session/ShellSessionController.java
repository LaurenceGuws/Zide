package dev.zide.terminal.session;

import dev.zide.terminal.userland.UserlandReadinessState;
import dev.zide.terminal.userland.UserlandRelease;

/**
 * Coordinates shell session polling and first auto-start eligibility.
 *
 * <p>This controller reads userland readiness through bootstrap state and calls the native shell
 * bridge. It does not own product presentation, install workflow, or Android view state.
 */
public final class ShellSessionController {
    public interface Bridge {
        int restart();

        int poll();

        boolean isAlive();
    }

    public static final class PollResult {
        public final int status;
        public final boolean alive;
        public final boolean autoStarted;
        public final int autoStartStatus;
        public final boolean autoStartBlocked;

        public PollResult(
                int status,
                boolean alive,
                boolean autoStarted,
                int autoStartStatus,
                boolean autoStartBlocked) {
            this.status = status;
            this.alive = alive;
            this.autoStarted = autoStarted;
            this.autoStartStatus = autoStartStatus;
            this.autoStartBlocked = autoStartBlocked;
        }
    }

    private final Bridge bridge;
    private final String readinessStampPath;
    private final String shellPath;
    private final UserlandRelease release;
    private final boolean nativeLoaded;
    private boolean autoStartAttempted = false;

    public ShellSessionController(
            Bridge bridge,
            String readinessStampPath,
            String shellPath,
            UserlandRelease release,
            boolean nativeLoaded) {
        this.bridge = bridge;
        this.readinessStampPath = readinessStampPath;
        this.shellPath = shellPath;
        this.release = release;
        this.nativeLoaded = nativeLoaded;
    }

    public UserlandReadinessState loadReadinessState() {
        return UserlandReadinessState.load(readinessStampPath, shellPath, release);
    }

    public PollResult poll(UserlandReadinessState readinessState) {
        int status = nativeLoaded ? bridge.poll() : 0;
        boolean alive = nativeLoaded && bridge.isAlive();
        boolean autoStarted = false;
        int autoStartStatus = 0;
        boolean autoStartBlocked = false;

        if (nativeLoaded && !alive && !autoStartAttempted) {
            if (readinessState.launchReady) {
                autoStartAttempted = true;
                autoStartStatus = bridge.restart();
                autoStarted = true;
                status = bridge.poll();
                alive = bridge.isAlive();
            } else {
                autoStartBlocked = true;
            }
        }

        return new PollResult(
                status,
                alive,
                autoStarted,
                autoStartStatus,
                autoStartBlocked);
    }
}
