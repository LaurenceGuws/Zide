const app_bootstrap = @import("bootstrap.zig");
const app_modes = @import("modes/mod.zig");

const AppMode = app_bootstrap.AppMode;

pub fn canHandleIntent(
    app_mode: AppMode,
    intent: app_modes.ide.TerminalShortcutIntent,
) bool {
    return switch (intent) {
        .focus => app_modes.ide.canHandleTerminalTabFocusShortcuts(app_mode),
        else => app_modes.ide.canHandleTerminalTabShortcuts(app_mode),
    };
}
