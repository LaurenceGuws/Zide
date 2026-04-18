package uk.laurencegouws.terminal.host.ui;

import android.content.res.Resources;

import java.util.List;
import java.util.Objects;

import uk.laurencegouws.terminal.R;

/**
 * Builds the default product-harness tab descriptor table for {@link AppShellTerminalViewPolicy}.
 *
 * <p>Labels come from {@code strings.xml} so localization stays resource-owned; stable ids stay
 * in code as the long-lived contract surface.</p>
 */
public final class ProductTerminalTabDescriptors {
    /** Stable id for tab index {@code 0} (single-PTY product harness). */
    public static final String STABLE_ID_SESSION_PRIMARY = "product_terminal.session_primary";
    /** Stable id for tab index {@code 1}. */
    public static final String STABLE_ID_SESSION_SECONDARY = "product_terminal.session_secondary";

    private ProductTerminalTabDescriptors() {
    }

    /**
     * Default two-tab descriptor list aligned with {@link AppShellNavigation#PRODUCT_TERMINAL_TAB_COUNT}.
     */
    public static List<ProductTerminalTabDescriptor> defaultsForProductHarness(final Resources res) {
        Objects.requireNonNull(res, "res");
        if (AppShellNavigation.PRODUCT_TERMINAL_TAB_COUNT != 2) {
            throw new IllegalStateException(
                    "defaultsForProductHarness must be updated when PRODUCT_TERMINAL_TAB_COUNT changes");
        }
        return List.of(
                new ProductTerminalTabDescriptor(
                        STABLE_ID_SESSION_PRIMARY, res.getString(R.string.product_terminal_tab_0), 0),
                new ProductTerminalTabDescriptor(
                        STABLE_ID_SESSION_SECONDARY, res.getString(R.string.product_terminal_tab_1), 1));
    }
}
