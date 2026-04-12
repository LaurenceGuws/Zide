package dev.zide.terminal;

import java.io.BufferedReader;
import java.io.File;
import java.io.FileReader;
import java.io.IOException;

final class ShellSessionController {
    interface Bridge {
        int restart();

        int poll();

        boolean isAlive();
    }

    static final class PollResult {
        final int status;
        final boolean alive;
        final String transcript;
        final boolean autoStarted;
        final int autoStartStatus;
        final boolean autoStartBlocked;
        final UserlandBootstrapState bootstrapState;

        PollResult(
                int status,
                boolean alive,
                String transcript,
                boolean autoStarted,
                int autoStartStatus,
                boolean autoStartBlocked,
                UserlandBootstrapState bootstrapState) {
            this.status = status;
            this.alive = alive;
            this.transcript = transcript;
            this.autoStarted = autoStarted;
            this.autoStartStatus = autoStartStatus;
            this.autoStartBlocked = autoStartBlocked;
            this.bootstrapState = bootstrapState;
        }
    }

    private final Bridge bridge;
    private final String transcriptPath;
    private final String bootstrapStampPath;
    private final String shellPath;
    private final UserlandRelease release;
    private final boolean nativeLoaded;
    private boolean autoStartAttempted = false;

    ShellSessionController(
            Bridge bridge,
            String transcriptPath,
            String bootstrapStampPath,
            String shellPath,
            UserlandRelease release,
            boolean nativeLoaded) {
        this.bridge = bridge;
        this.transcriptPath = transcriptPath;
        this.bootstrapStampPath = bootstrapStampPath;
        this.shellPath = shellPath;
        this.release = release;
        this.nativeLoaded = nativeLoaded;
    }

    PollResult poll() {
        int status = nativeLoaded ? bridge.poll() : 0;
        boolean alive = nativeLoaded && bridge.isAlive();
        boolean autoStarted = false;
        int autoStartStatus = 0;
        final UserlandBootstrapState bootstrapState = UserlandBootstrapState.load(bootstrapStampPath, shellPath, release);
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
                readTextFile(transcriptPath),
                autoStarted,
                autoStartStatus,
                autoStartBlocked,
                bootstrapState);
    }

    private static String readTextFile(String path) {
        final File file = new File(path);
        if (!file.exists()) {
            return "";
        }

        final StringBuilder out = new StringBuilder();
        try (BufferedReader reader = new BufferedReader(new FileReader(file))) {
            String line;
            boolean first = true;
            while ((line = reader.readLine()) != null) {
                if (!first) {
                    out.append('\n');
                }
                out.append(line);
                first = false;
            }
        } catch (IOException err) {
            return "read-error:" + err.getClass().getSimpleName();
        }
        return out.toString();
    }
}
