package uk.laurencegouws.terminal.debug;

/** Maps native bridge status enums to stable debug/operator labels. */
public final class TerminalNativeStatusLabels {
    private TerminalNativeStatusLabels() {
    }

    public static String surfaceTransitionLabel(int transition) {
        switch (transition) {
            case 1:
                return "surface.transition.acquired";
            case 2:
                return "surface.transition.replaced";
            case 3:
                return "surface.transition.retired";
            default:
                return "surface.transition.unchanged";
        }
    }

    public static String sessionStartStatusLabel(int status) {
        switch (status) {
            case 1:
                return "session.start.started";
            case 2:
                return "session.start.unsupported";
            case 3:
                return "session.start.failed.create";
            case 4:
                return "session.start.failed.resize";
            case 5:
                return "session.start.failed.launch";
            case 6:
                return "session.start.failed.send";
            case 7:
                return "session.start.failed.poll";
            case 8:
                return "session.start.failed.snapshot";
            default:
                return "session.start.none";
        }
    }

    public static String glesRendererStatusLabel(int status) {
        switch (status) {
            case 1:
                return "surface.state.ready";
            case 2:
                return "surface.state.drawn";
            case 3:
                return "surface.state.destroyed";
            case 4:
                return "surface.init.failed";
            case 5:
                return "surface.bind.failed";
            case 6:
                return "surface.make_current.failed";
            case 7:
                return "surface.swap.failed";
            default:
                return "surface.state.unavailable";
        }
    }
}
