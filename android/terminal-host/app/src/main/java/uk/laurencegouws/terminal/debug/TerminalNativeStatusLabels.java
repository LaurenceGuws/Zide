package uk.laurencegouws.terminal.debug;

/** Maps native bridge status enums to stable debug/operator labels. */
public final class TerminalNativeStatusLabels {
    private TerminalNativeStatusLabels() {
    }

    public static String surfaceTransitionLabel(int transition) {
        switch (transition) {
            case 1:
                return "acquired";
            case 2:
                return "replaced";
            case 3:
                return "retired";
            default:
                return "unchanged";
        }
    }

    public static String sessionStartStatusLabel(int status) {
        switch (status) {
            case 1:
                return "activity.started";
            case 2:
                return "unsupported";
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
                return "none";
        }
    }

    public static String glesRendererStatusLabel(int status) {
        switch (status) {
            case 1:
                return "ready";
            case 2:
                return "drawn";
            case 3:
                return "surface.destroyed";
            case 4:
                return "surface.init.failed";
            case 5:
                return "surface.bind.failed";
            case 6:
                return "surface.make_current.failed";
            case 7:
                return "surface.swap.failed";
            default:
                return "unavailable";
        }
    }
}
