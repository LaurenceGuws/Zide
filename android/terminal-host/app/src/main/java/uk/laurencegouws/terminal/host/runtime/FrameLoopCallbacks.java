package uk.laurencegouws.terminal.host.runtime;

import java.util.function.BooleanSupplier;
import java.util.function.IntSupplier;

/** Functional callback adapter for {@link FrameLoopBridge}. */
public final class FrameLoopCallbacks implements FrameLoopBridge.Callbacks {
    private final BooleanSupplier shouldRunFrameLoop;
    private final IntSupplier tickFrame;

    public FrameLoopCallbacks(
            BooleanSupplier shouldRunFrameLoop,
            IntSupplier tickFrame) {
        this.shouldRunFrameLoop = shouldRunFrameLoop;
        this.tickFrame = tickFrame;
    }

    @Override
    public boolean shouldRunFrameLoop() {
        return shouldRunFrameLoop.getAsBoolean();
    }

    @Override
    public int tickFrame() {
        return tickFrame.getAsInt();
    }
}
