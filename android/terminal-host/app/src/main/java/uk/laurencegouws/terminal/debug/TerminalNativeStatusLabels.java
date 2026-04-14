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

    public static String shellStartStatusLabel(int status) {
        switch (status) {
            case 1:
                return "activity.started";
            case 2:
                return "unsupported";
            case 3:
                return "create-failed";
            case 4:
                return "resize-failed";
            case 5:
                return "start-failed";
            case 6:
                return "send-failed";
            case 7:
                return "poll-failed";
            case 8:
                return "snapshot-failed";
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
                return "init-failed";
            case 5:
                return "surface-failed";
            case 6:
                return "make-current-failed";
            case 7:
                return "swap-failed";
            default:
                return "unavailable";
        }
    }
}
