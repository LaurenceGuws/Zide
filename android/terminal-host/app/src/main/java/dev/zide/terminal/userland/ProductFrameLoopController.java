package dev.zide.terminal.userland;

import android.os.Handler;

/** Owns the product frame-loop activation policy and callback scheduling. */
public final class ProductFrameLoopController {
    /** Host callback for the frame-loop readiness gate. */
    public interface Host {
        boolean shouldRunProductFrameLoop();

        void refreshProductScrollOverlay();
    }

    private final Handler handler;
    private final Runnable frameRunnable;
    private final Host host;
    private boolean active = false;

    public ProductFrameLoopController(Handler handler, Runnable frameRunnable, Host host) {
        this.handler = handler;
        this.frameRunnable = frameRunnable;
        this.host = host;
    }

    public void start() {
        if (active || !host.shouldRunProductFrameLoop()) {
            return;
        }
        active = true;
        handler.post(frameRunnable);
    }

    public void stop() {
        if (!active) {
            return;
        }
        active = false;
        handler.removeCallbacks(frameRunnable);
    }

    public void reevaluate() {
        if (host.shouldRunProductFrameLoop()) {
            start();
        } else {
            stop();
        }
    }

    public boolean isActive() {
        return active;
    }
}
