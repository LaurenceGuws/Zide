package dev.zide.terminal.host;

/**
 * Adapts activity-owned frame-loop callbacks to {@link TerminalFrameLoopController.Host}.
 */
public final class TerminalFrameLoopHostBridge implements TerminalFrameLoopController.Host {
    /** Activity callbacks used by frame-loop scheduling. */
    public interface Callbacks {
        boolean shouldRunProductFrameLoop();

        int tickProductFrame();
    }

    private final Callbacks callbacks;

    public TerminalFrameLoopHostBridge(Callbacks callbacks) {
        this.callbacks = callbacks;
    }

    @Override
    public boolean shouldRunProductFrameLoop() {
        return callbacks.shouldRunProductFrameLoop();
    }

    @Override
    public int tickProductFrame() {
        return callbacks.tickProductFrame();
    }
}
