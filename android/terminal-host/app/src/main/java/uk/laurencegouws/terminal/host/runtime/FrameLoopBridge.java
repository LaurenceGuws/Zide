package uk.laurencegouws.terminal.host.runtime;

/**
 * Adapts activity-owned frame-loop callbacks to {@link FrameLoopController.Host}.
 */
public final class FrameLoopBridge implements FrameLoopController.Host {
    /** Activity callbacks used by frame-loop scheduling. */
    public interface Callbacks {
        boolean shouldRunProductFrameLoop();

        int tickProductFrame();
    }

    private final Callbacks callbacks;

    public FrameLoopBridge(Callbacks callbacks) {
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
