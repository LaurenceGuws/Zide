package uk.laurencegouws.terminal.host.ui;

import uk.laurencegouws.terminal.NativeBridge;
import uk.laurencegouws.terminal.debug.StatusController;
import uk.laurencegouws.terminal.host.lifecycle.LifecycleController;

/**
 * {@link LifecycleController.Host} for the product terminal activity — native bridge and harness
 * forwards only; activity stays free of this anonymous implementation block.
 */
public final class ProductTerminalLifecycleHost implements LifecycleController.Host {
    private final ProductHostStartupBundle hostStartup;
    private final StatusController statusController;

    public ProductTerminalLifecycleHost(
            ProductHostStartupBundle hostStartup,
            StatusController statusController) {
        this.hostStartup = hostStartup;
        this.statusController = statusController;
    }

    @Override
    public boolean nativeLoaded() {
        return NativeBridge.nativeLoaded();
    }

    @Override
    public String nativeLoadError() {
        return NativeBridge.nativeLoadError();
    }

    @Override
    public long nativeOnCreate() {
        return NativeBridge.nativeOnCreateBridge();
    }

    @Override
    public long nativeOnStart() {
        return NativeBridge.nativeOnStartBridge();
    }

    @Override
    public long nativeOnResume() {
        return NativeBridge.nativeOnResumeBridge();
    }

    @Override
    public long nativeOnPause() {
        return NativeBridge.nativeOnPauseBridge();
    }

    @Override
    public long nativeOnStop() {
        return NativeBridge.nativeOnStopBridge();
    }

    @Override
    public long nativeOnWindowFocus(boolean hasFocus) {
        return NativeBridge.nativeOnWindowFocusBridge(hasFocus);
    }

    @Override
    public void appendEvent(String event) {
        statusController.appendEvent(event);
    }

    @Override
    public void callNative(String event, long seq) {
        statusController.callNative(event, seq);
    }

    @Override
    public void updateStatus(String statusLabel) {
        statusController.updateStatus(statusLabel);
    }

    @Override
    public void stopFrameLoop() {
        hostStartup.frameLoop.stopFrameLoopIfReady();
    }

    @Override
    public void refreshUserlandSessionOnPause() {
        hostStartup.userlandSession.refreshUserlandSessionIfReady();
    }

    @Override
    public void notifySurfacePause() {
        hostStartup.surface.pauseSurfaceIfReady();
    }

    @Override
    public void notifySurfaceResume(
            boolean debugRecreateSurfaceOnce,
            boolean debugResizeSurfaceOnce,
            boolean debugStartShellOnce) {
        hostStartup.surface.resumeSurfaceIfReady(
                debugRecreateSurfaceOnce,
                debugResizeSurfaceOnce,
                debugStartShellOnce);
    }
}
