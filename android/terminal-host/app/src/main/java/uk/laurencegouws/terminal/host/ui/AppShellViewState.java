package uk.laurencegouws.terminal.host.ui;

/**
 * Per-shell-view snapshot for harness navigation (tab-ready shape).
 *
 * <p>{@link #contentReady} is reserved for wiring surface/readiness into shell chrome
 * when multiple views exist; single-view mode keeps defaults.
 */
public final class AppShellViewState {
    public final ShellViewId id;
    /** Analog to tab selection: this view owns the app-shell chrome focus. */
    public final boolean selected;
    /** Reserved: true when this view's primary content surface is ready to interact. */
    public final boolean contentReady;

    public AppShellViewState(ShellViewId id, boolean selected, boolean contentReady) {
        this.id = id;
        this.selected = selected;
        this.contentReady = contentReady;
    }
}
