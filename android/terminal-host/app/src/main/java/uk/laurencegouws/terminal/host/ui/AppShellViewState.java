package uk.laurencegouws.terminal.host.ui;

import java.util.Objects;

/**
 * Per-shell-view snapshot for harness navigation (tab-ready shape).
 *
 * <p>{@link #contentReady} is reserved for wiring surface/readiness into shell chrome
 * when multiple views exist; single-view mode keeps defaults.</p>
 *
 * <p><strong>Invariants:</strong> {@link #id} is never {@code null}. Callers must not
 * construct with contradictory tab-selection semantics unless harness policy defines
 * them; {@link AppShellNavigation#activeViewState()} supplies the product default row.</p>
 */
public final class AppShellViewState {
    public final ShellViewId id;
    /** Analog to tab selection: this view owns the app-shell chrome focus. */
    public final boolean selected;
    /** Reserved: true when this view's primary content surface is ready to interact. */
    public final boolean contentReady;

    public AppShellViewState(ShellViewId id, boolean selected, boolean contentReady) {
        this.id = Objects.requireNonNull(id, "id");
        this.selected = selected;
        this.contentReady = contentReady;
    }
}
