package uk.laurencegouws.terminal.host.userland;

import java.util.function.Supplier;

import uk.laurencegouws.terminal.userland.UserlandInstallState;
import uk.laurencegouws.terminal.userland.UserlandReadinessState;

/**
 * Harness-owned seam for shell-blocker presentation: supplies readiness and
 * install snapshots without exposing userland types on {@code WidgetAssembly.Host}.
 *
 * <p>Userland value types remain the product truth for readiness/install; this type
 * only bundles the suppliers used to wire {@link ShellStateCallbacks} from the
 * harness assembly layer.
 */
public final class ShellPresentationHostInputs {
    private final Supplier<UserlandReadinessState> readinessState;
    private final Supplier<UserlandInstallState> installState;

    public ShellPresentationHostInputs(
            Supplier<UserlandReadinessState> readinessState,
            Supplier<UserlandInstallState> installState) {
        this.readinessState = readinessState;
        this.installState = installState;
    }

    public Supplier<UserlandReadinessState> readinessState() {
        return readinessState;
    }

    public Supplier<UserlandInstallState> installState() {
        return installState;
    }
}
