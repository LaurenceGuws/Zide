package dev.zide.terminal.host;

import java.util.function.BooleanSupplier;
import java.util.function.IntSupplier;

/** Functional callback adapter for {@link TerminalFrameLoopHostBridge}. */
public final class TerminalFrameLoopHostCallbacks implements TerminalFrameLoopHostBridge.Callbacks {
    private final BooleanSupplier shouldRunProductFrameLoop;
    private final IntSupplier tickProductFrame;

    public TerminalFrameLoopHostCallbacks(
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
