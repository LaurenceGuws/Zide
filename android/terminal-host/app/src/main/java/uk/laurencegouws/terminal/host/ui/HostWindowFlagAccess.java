package uk.laurencegouws.terminal.host.ui;

/**
 * Harness seam for applying integer window flags without coupling policy to {@link android.view.Window}.
 *
 * <p>Typical wiring: activity passes {@code getWindow()::addFlags} into {@link ProductHostKeepScreenOnPolicy}.</p>
 */
@FunctionalInterface
public interface HostWindowFlagAccess {
    void addFlags(int flags);
}
