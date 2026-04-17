package uk.laurencegouws.terminal.selection;

/** Creates selection controllers for a terminal surface widget instance. */
public final class SelectionControllerFactory {
    /** Widget host callbacks required by selection controller wiring. */
    public interface Host extends SelectionController.Host, SelectionController.Bridge {
    }

    private SelectionControllerFactory() {
    }

    public static SelectionController create(Host host) {
        return new SelectionController(host, host);
    }
}
