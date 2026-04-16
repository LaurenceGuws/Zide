package uk.laurencegouws.terminal.host.session;

import android.content.Context;
import android.os.Handler;

import uk.laurencegouws.terminal.NativeBridge;
import uk.laurencegouws.terminal.debug.NativeStatusLabels;
import uk.laurencegouws.terminal.host.runtime.FrameLoopController;
import uk.laurencegouws.terminal.host.runtime.RuntimeFactory;
import uk.laurencegouws.terminal.host.userland.SessionBridge;
import uk.laurencegouws.terminal.userland.UserlandReadinessState;
import uk.laurencegouws.terminal.userland.UserlandPolicy;
import uk.laurencegouws.terminal.userland.UserlandRelease;
import uk.laurencegouws.terminal.userland.UserlandSessionCoordinator;

/** Owns session-related controller assembly for the activity wiring layer. */
public final class SessionAssembly {
    /** Activity callbacks required to assemble session-related controllers. */
    public interface Host {
        Context context();

        UserlandRelease userlandRelease();

        Handler handler();

        void appendEvent(String event);

        void updateStatus(String statusLabel);

        void applyReadinessState(UserlandReadinessState readinessState);

        void refreshShellState();

        void refreshDebugStatusSurface();

        boolean shouldRunFrameLoop();

        int tickFrame();

        int nativeRestartSession();

        int nativePollSession();

        boolean nativeIsSessionAlive();
    }

    /** Immutable assembled session/runtime construction result. */
    public static final class Result {
        public final uk.laurencegouws.terminal.session.ShellSessionController shellSessionController;
        public final SessionBridge userlandSessionHostBridge;
        public final UserlandSessionCoordinator userlandSessionCoordinator;
        public final FrameLoopController frameLoopController;

        private Result(
                uk.laurencegouws.terminal.session.ShellSessionController shellSessionController,
                SessionBridge userlandSessionHostBridge,
                UserlandSessionCoordinator userlandSessionCoordinator,
                FrameLoopController frameLoopController) {
            this.shellSessionController = shellSessionController;
            this.userlandSessionHostBridge = userlandSessionHostBridge;
            this.userlandSessionCoordinator = userlandSessionCoordinator;
            this.frameLoopController = frameLoopController;
        }
    }

    private SessionAssembly() {
    }

    public static Result assemble(Host host) {
        final uk.laurencegouws.terminal.session.ShellSessionController shellSessionController =
                SessionFactory.createShellSessionController(
                        UserlandPolicy.readinessStampPath(host.context()),
                        UserlandPolicy.shellPath(host.context()),
                        host.userlandRelease(),
                        NativeBridge.nativeLoaded(),
                        host::nativeRestartSession,
                        host::nativePollSession,
                        host::nativeIsSessionAlive);
        final SessionBridge userlandSessionHostBridge =
                SessionFactory.createUserlandSessionHostBridge(
                        host::appendEvent,
                        NativeStatusLabels::sessionStartStatusLabel,
                        host::applyReadinessState,
                        host::refreshShellState,
                        host::refreshDebugStatusSurface,
                        host::updateStatus);
        final UserlandSessionCoordinator userlandSessionCoordinator =
                new UserlandSessionCoordinator(shellSessionController, userlandSessionHostBridge);
        final FrameLoopController frameLoopController =
                RuntimeFactory.createFrameLoopController(
                        host.handler(),
                        host::shouldRunFrameLoop,
                        host::tickFrame);
        return new Result(
                shellSessionController,
                userlandSessionHostBridge,
                userlandSessionCoordinator,
                frameLoopController);
    }
}
