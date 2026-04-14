package dev.zide.terminal.host.runtime;

import java.util.function.BooleanSupplier;
import java.util.function.IntSupplier;

/** Functional callback adapter for {@link FrameLoopBridge}. */
public final class FrameLoopCallbacks implements FrameLoopBridge.Callbacks {
    private final BooleanSupplier shouldRunProductFrameLoop;
    private final IntSupplier tickProductFrame;

    public FrameLoopCallbacks(
            BooleanSupplier shouldRunProductFrameLoop,
            IntSupplier tickProductFrame) {
        this.shouldRunProductFrameLoop = shouldRunProductFrameLoop;
        this.tickProductFrame = tickProductFrame;
    }

    @Override
    public boolean shouldRunProductFrameLoop() {
        return shouldRunProductFrameLoop.getAsBoolean();
    }

    @Override
    public int tickProductFrame() {
        return tickProductFrame.getAsInt();
    }
}
