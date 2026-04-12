package dev.zide.terminal;

final class ShellSessionController {
    interface Bridge {
        int restart();

        int poll();

        boolean isAlive();
    }

    static final class PollResult {
        final int status;
        final boolean alive;
        final boolean autoStarted;
        final int autoStartStatus;
        final boolean autoStartBlocked;

        PollResult(
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
    private final String bootstrapStampPath;
    private final String shellPath;
    private final UserlandRelease release;
    private final boolean nativeLoaded;
    private boolean autoStartAttempted = false;

    ShellSessionController(
            Bridge bridge,
            String bootstrapStampPath,
            String shellPath,
            UserlandRelease release,
            boolean nativeLoaded) {
        this.bridge = bridge;
        this.bootstrapStampPath = bootstrapStampPath;
        this.shellPath = shellPath;
        this.release = release;
        this.nativeLoaded = nativeLoaded;
    }

    UserlandBootstrapState loadBootstrapState() {
        return UserlandBootstrapState.load(bootstrapStampPath, shellPath, release);
    }

    PollResult poll(UserlandBootstrapState bootstrapState) {
        int status = nativeLoaded ? bridge.poll() : 0;
        boolean alive = nativeLoaded && bridge.isAlive();
        boolean autoStarted = false;
        int autoStartStatus = 0;
        boolean autoStartBlocked = false;

        if (nativeLoaded && !alive && !autoStartAttempted) {
            if (bootstrapState.launchReady) {
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
