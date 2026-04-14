package uk.laurencegouws.terminal.host.lifecycle;

import android.content.Intent;

/** Immutable debug lifecycle args parsed from activity intent extras. */
public final class LifecycleDebugIntentArgs {
    private static final String EXTRA_DEBUG_RECREATE_SURFACE_ONCE = "debug_recreate_surface_once";
    private static final String EXTRA_DEBUG_RESIZE_SURFACE_ONCE = "debug_resize_surface_once";
    private static final String EXTRA_DEBUG_START_SHELL_ONCE = "debug_start_shell_once";

    public final boolean recreateSurfaceOnce;
    public final boolean resizeSurfaceOnce;
    public final boolean startShellOnce;

    private LifecycleDebugIntentArgs(
            boolean recreateSurfaceOnce,
            boolean resizeSurfaceOnce,
            boolean startShellOnce) {
        this.recreateSurfaceOnce = recreateSurfaceOnce;
        this.resizeSurfaceOnce = resizeSurfaceOnce;
        this.startShellOnce = startShellOnce;
    }

    public static LifecycleDebugIntentArgs fromIntent(Intent intent) {
        return new LifecycleDebugIntentArgs(
                intent.getBooleanExtra(EXTRA_DEBUG_RECREATE_SURFACE_ONCE, false),
                intent.getBooleanExtra(EXTRA_DEBUG_RESIZE_SURFACE_ONCE, false),
                intent.getBooleanExtra(EXTRA_DEBUG_START_SHELL_ONCE, false));
    }
}
