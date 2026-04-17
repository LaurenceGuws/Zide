package uk.laurencegouws.terminal.host.session;

import android.content.Context;
import android.os.Handler;

import uk.laurencegouws.terminal.NativeBridge;
import uk.laurencegouws.terminal.debug.NativeStatusLabels;
import uk.laurencegouws.terminal.host.runtime.FrameLoopController;
import uk.laurencegouws.terminal.host.runtime.RuntimeFactory;
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
        public final UserlandSessionCoordinator.Host userlandSessionHost;
        public final UserlandSessionCoordinator userlandSessionCoordinator;
        public final FrameLoopController frameLoopController;

        private Result(
                uk.laurencegouws.terminal.session.ShellSessionController shellSessionController,
                UserlandSessionCoordinator.Host userlandSessionHost,
                UserlandSessionCoordinator userlandSessionCoordinator,
                FrameLoopController frameLoopController) {
            this.shellSessionController = shellSessionController;
            this.userlandSessionHost = userlandSessionHost;
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
        final UserlandSessionCoordinator.Host userlandSessionHost =
                SessionFactory.createUserlandSessionHost(
                        host::appendEvent,
                        NativeStatusLabels::sessionStartStatusLabel,
                        host::applyReadinessState,
                        host::refreshShellState,
                        host::refreshDebugStatusSurface,
                        host::updateStatus);
        final UserlandSessionCoordinator userlandSessionCoordinator =
                new UserlandSessionCoordinator(shellSessionController, userlandSessionHost);
        final FrameLoopController frameLoopController =
                RuntimeFactory.createFrameLoopController(
                        host.handler(),
                        host::shouldRunFrameLoop,
                        host::tickFrame);
        return new Result(
                shellSessionController,
                userlandSessionHost,
                userlandSessionCoordinator,
                frameLoopController);
    }
}
