package dev.zide.terminal.host;

import android.content.Context;
import android.os.Handler;

import java.util.function.Function;

import dev.zide.terminal.debug.TerminalNativeStatusLabels;
import dev.zide.terminal.userland.UserlandBootstrapState;
import dev.zide.terminal.userland.UserlandPolicy;
import dev.zide.terminal.userland.UserlandRelease;
import dev.zide.terminal.userland.UserlandSessionCoordinator;

/** Owns session-related controller assembly for the activity wiring layer. */
public final class TerminalSessionAssembly {
    /** Activity callbacks required to assemble session-related controllers. */
    public interface Host {
        Context context();

        UserlandRelease userlandRelease();

        boolean nativeLoaded();

        Handler handler();

        void appendEvent(String event);

        void updateStatus(String statusLabel);

        void applyBootstrapState(UserlandBootstrapState bootstrapState);

        void refreshProductShellState();

        void refreshDebugStatusSurface();

        boolean shouldRunProductFrameLoop();

        int tickProductFrame();

        int nativeRestartShellSession();

        int nativePollShellSession();

        boolean nativeIsShellSessionAlive();
    }

    /** Immutable assembled session/runtime construction result. */
    public static final class Result {
        public final dev.zide.terminal.session.ShellSessionController shellSessionController;
        public final TerminalUserlandSessionHostBridge userlandSessionHostBridge;
        public final UserlandSessionCoordinator userlandSessionCoordinator;
        public final TerminalFrameLoopController frameLoopController;

        private Result(
                dev.zide.terminal.session.ShellSessionController shellSessionController,
                TerminalUserlandSessionHostBridge userlandSessionHostBridge,
                UserlandSessionCoordinator userlandSessionCoordinator,
                TerminalFrameLoopController frameLoopController) {
            this.shellSessionController = shellSessionController;
            this.userlandSessionHostBridge = userlandSessionHostBridge;
            this.userlandSessionCoordinator = userlandSessionCoordinator;
            this.frameLoopController = frameLoopController;
        }
    }

    private TerminalSessionAssembly() {
    }

    public static Result assemble(Host host) {
        final dev.zide.terminal.session.ShellSessionController shellSessionController =
                TerminalSessionHostFactory.createShellSessionController(
                        UserlandPolicy.bootstrapStampPath(host.context()),
                        UserlandPolicy.shellPath(host.context()),
                        host.userlandRelease(),
                        host.nativeLoaded(),
                        host::nativeRestartShellSession,
                        host::nativePollShellSession,
                        host::nativeIsShellSessionAlive);
        final TerminalUserlandSessionHostBridge userlandSessionHostBridge =
                TerminalSessionHostFactory.createUserlandSessionHostBridge(
                        host::appendEvent,
                        (Function<Integer, String>) TerminalNativeStatusLabels::shellStartStatusLabel,
                        host::applyBootstrapState,
                        host::refreshProductShellState,
                        host::refreshDebugStatusSurface,
                        host::updateStatus);
        final UserlandSessionCoordinator userlandSessionCoordinator =
                new UserlandSessionCoordinator(shellSessionController, userlandSessionHostBridge);
        final TerminalFrameLoopController frameLoopController =
                TerminalRuntimeHostFactory.createFrameLoopController(
                        host.handler(),
                        host::shouldRunProductFrameLoop,
                        host::tickProductFrame);
        return new Result(
                shellSessionController,
                userlandSessionHostBridge,
                userlandSessionCoordinator,
                frameLoopController);
    }
}
