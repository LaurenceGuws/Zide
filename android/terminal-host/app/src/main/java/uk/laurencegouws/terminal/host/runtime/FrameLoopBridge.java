package uk.laurencegouws.terminal.host.runtime;

/**
 * Adapts activity-owned frame-loop callbacks to {@link FrameLoopController.Host}.
 */
public final class FrameLoopBridge implements FrameLoopController.Host {
    /** Harness callbacks used by frame-loop scheduling. */
    public interface Callbacks {
        boolean shouldRunFrameLoop();

        int tickFrame();
    }

    private final Callbacks callbacks;

    public FrameLoopBridge(Callbacks callbacks) {
        this.callbacks = callbacks;
    }

    @Override
    public boolean shouldRunFrameLoop() {
        return callbacks.shouldRunFrameLoop();
    }

    @Override
    public int tickFrame() {
        return callbacks.tickFrame();
    }
}
