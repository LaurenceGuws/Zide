package dev.zide.terminal.host;

import android.os.Handler;

/**
 * Owns product frame-loop activation and callback scheduling for the Android terminal host.
 *
 * <p>This is host infrastructure, not userland policy: it decides whether the product frame
 * runnable should be active and removes pending callbacks when the product surface is not ready.
 */
public final class TerminalFrameLoopController {
    /** Host callback for the frame-loop readiness gate. */
    public interface Host {
        boolean shouldRunProductFrameLoop();

        int tickProductFrame();
    }

    private final Handler handler;
    private final Host host;
    private boolean active = false;
    private final Runnable frameRunnable = new Runnable() {
        @Override
        public void run() {
            if (!active) {
                return;
            }
            final int tick = host.tickProductFrame();
            if (!host.shouldRunProductFrameLoop() || tick == 0) {
                stop();
                return;
            }
            handler.postDelayed(this, tick == 2 ? 16L : 33L);
        }
    };

    public TerminalFrameLoopController(Handler handler, Host host) {
        this.handler = handler;
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
