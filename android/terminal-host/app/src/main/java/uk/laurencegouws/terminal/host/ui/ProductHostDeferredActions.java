package uk.laurencegouws.terminal.host.ui;

import android.view.KeyEvent;

import java.util.function.Consumer;
import java.util.function.Supplier;

import uk.laurencegouws.terminal.NativeBridge;
import uk.laurencegouws.terminal.debug.StatusController;
import uk.laurencegouws.terminal.host.runtime.FrameLoopController;
import uk.laurencegouws.terminal.host.runtime.RuntimeController;
import uk.laurencegouws.terminal.host.surface.SurfaceController;
import uk.laurencegouws.terminal.input.HardwareKeyboardController;
import uk.laurencegouws.terminal.input.ImeFocusRecoveryController;
import uk.laurencegouws.terminal.input.ShellInputView;
import uk.laurencegouws.terminal.userland.UserlandInstallState;
import uk.laurencegouws.terminal.userland.UserlandReadinessState;
import uk.laurencegouws.terminal.userland.UserlandSessionCoordinator;

/**
 * Null-safe forwards from early wiring callbacks into controllers that are
 * constructed progressively during activity startup.
 *
 * <p>Keeps {@code ZideActivity} as entrypoint wiring only; orchestration stays
 * in dedicated runtime/surface/session owners.
 */
public final class ProductHostDeferredActions {
    private final Supplier<RuntimeController> runtimeController;
    private final Supplier<FrameLoopController> frameLoopController;
    private final Supplier<SurfaceController> surfaceHostController;
    private final Supplier<UserlandSessionCoordinator> userlandSessionCoordinator;
    private final Supplier<HardwareKeyboardController> hardwareKeyboardController;
    private final Supplier<ImeFocusRecoveryController> imeFocusRecoveryController;
    private final Supplier<ChromeController> chromeController;
    private final Supplier<StatusController> statusController;
    private final Consumer<UserlandInstallState> setInstallState;
    private final Consumer<UserlandReadinessState> setReadinessState;

    public ProductHostDeferredActions(
            Supplier<RuntimeController> runtimeController,
            Supplier<FrameLoopController> frameLoopController,
            Supplier<SurfaceController> surfaceHostController,
            Supplier<UserlandSessionCoordinator> userlandSessionCoordinator,
            Supplier<HardwareKeyboardController> hardwareKeyboardController,
            Supplier<ImeFocusRecoveryController> imeFocusRecoveryController,
            Supplier<ChromeController> chromeController,
            Supplier<StatusController> statusController,
            Consumer<UserlandInstallState> setInstallState,
            Consumer<UserlandReadinessState> setReadinessState) {
        this.runtimeController = runtimeController;
        this.frameLoopController = frameLoopController;
        this.surfaceHostController = surfaceHostController;
        this.userlandSessionCoordinator = userlandSessionCoordinator;
        this.hardwareKeyboardController = hardwareKeyboardController;
        this.imeFocusRecoveryController = imeFocusRecoveryController;
        this.chromeController = chromeController;
        this.statusController = statusController;
        this.setInstallState = setInstallState;
        this.setReadinessState = setReadinessState;
    }

    public void stopScrollbackFlingIfReady() {
        final RuntimeController c = runtimeController.get();
        if (c != null) {
            c.stopScrollbackFling();
        }
    }

    public void refreshScrollOverlayIfReady() {
        final RuntimeController c = runtimeController.get();
        if (c != null) {
            c.refreshScrollOverlay();
        }
    }

    public void reevaluateFrameLoopIfReady() {
        final FrameLoopController c = frameLoopController.get();
        if (c != null) {
            c.reevaluate();
        }
    }

    public void refreshShellStateIfReady() {
        final RuntimeController c = runtimeController.get();
        if (c != null) {
            c.refreshShellState();
        }
    }

    public void refreshStatusTelemetryIfReady() {
        final RuntimeController c = runtimeController.get();
        if (c != null) {
            c.refreshStatusTelemetry();
        }
    }

    public void handleShellStateEventIfReady() {
        final RuntimeController c = runtimeController.get();
        if (c != null) {
            c.handleShellStateEvent();
        }
    }

    public void applyInstallStateIfReady(UserlandInstallState installState) {
        final RuntimeController c = runtimeController.get();
        if (c != null) {
            c.applyInstallState(installState);
        }
    }

    public void completeInstallIfReady(UserlandReadinessState readinessState) {
        setInstallState.accept(UserlandInstallState.idle());
        setReadinessState.accept(readinessState);
        restartSessionAfterInstallIfReady(true);
    }

    public void failInstallIfReady(UserlandInstallState installState) {
        applyInstallStateIfReady(installState);
    }

    public void restartSessionAfterInstallIfReady(boolean logRefresh) {
        final RuntimeController c = runtimeController.get();
        if (c != null) {
            c.restartSessionAfterInstall(logRefresh);
        }
    }

    public void markPackageDoctorCompleteIfReady(boolean success) {
        final StatusController s = statusController.get();
        if (s != null) {
            s.recordPackageDoctorOutcome(success);
        }
    }

    public void notifyVisibleViewportIfReady(String reason) {
        final SurfaceController c = surfaceHostController.get();
        if (c != null) {
            c.notifyVisibleViewport(reason);
        }
    }

    public void stopFrameLoopIfReady() {
        final FrameLoopController c = frameLoopController.get();
        if (c != null) {
            c.stop();
        }
    }

    public void refreshUserlandSessionIfReady() {
        final UserlandSessionCoordinator c = userlandSessionCoordinator.get();
        if (c != null) {
            c.refreshAndApply(false);
        }
    }

    public void pauseSurfaceIfReady() {
        final SurfaceController c = surfaceHostController.get();
        if (c != null) {
            c.onPause();
        }
    }

    public void resumeSurfaceIfReady(
            boolean debugRecreateSurfaceOnce,
            boolean debugResizeSurfaceOnce,
            boolean debugStartShellOnce) {
        final SurfaceController c = surfaceHostController.get();
        if (c != null) {
            c.onResume(
                    debugRecreateSurfaceOnce,
                    debugResizeSurfaceOnce,
                    debugStartShellOnce);
        }
    }

    public boolean shouldRunFrameLoop() {
        final RuntimeController c = runtimeController.get();
        return c != null && c.shouldRunFrameLoop();
    }

    public int tickFrameAndRefreshScrollOverlay(boolean nativeLoaded) {
        final int tick = nativeLoaded ? NativeBridge.nativeTickFrameBridge() : 0;
        refreshScrollOverlayIfReady();
        return tick;
    }

    public boolean handleHardwareDispatchKeyEventIfReady(KeyEvent event) {
        final HardwareKeyboardController c = hardwareKeyboardController.get();
        return c != null && c.handleDispatchKeyEvent(event);
    }

    public void notifyInputFocusRecoveryIfReady(boolean hasFocus) {
        final ImeFocusRecoveryController c = imeFocusRecoveryController.get();
        if (c != null) {
            c.onInputFocusChanged(hasFocus);
        }
    }

    public void applyModifierLatchIfReady(ShellInputView.Host.ModifierLatchState state) {
        final ChromeController c = chromeController.get();
        if (c != null) {
            c.applyModifierLatchState(state);
        }
    }
}
