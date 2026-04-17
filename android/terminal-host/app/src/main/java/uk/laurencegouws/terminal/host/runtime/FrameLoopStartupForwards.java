package uk.laurencegouws.terminal.host.runtime;

import java.util.function.Supplier;

/**
 * Startup-order null-guard forwards into {@link FrameLoopController}.
 */
public final class FrameLoopStartupForwards {
    private final Supplier<FrameLoopController> frameLoopController;

    public FrameLoopStartupForwards(Supplier<FrameLoopController> frameLoopController) {
        this.frameLoopController = frameLoopController;
    }

    public void reevaluateFrameLoopIfReady() {
        final FrameLoopController c = frameLoopController.get();
        if (c != null) {
            c.reevaluate();
        }
    }

    public void stopFrameLoopIfReady() {
        final FrameLoopController c = frameLoopController.get();
        if (c != null) {
            c.stop();
        }
    }
}
