const app_bootstrap = @import("bootstrap.zig");
const app_logger = @import("../app_logger.zig");
const app_modes = @import("modes/mod.zig");
const app_shell = @import("../app_shell.zig");

const Shell = app_shell.Shell;

pub fn handle(state: anytype, shell: *Shell) bool {
    if (!app_modes.ide.isFontSample(state.app_mode)) return false;

    if (state.font_sample_view) |*view| {
        view.draw(shell);
    }
    if (state.font_sample_close_pending) {
        if (state.font_sample_screenshot_path) |path| {
            const log = app_logger.logger("app.font-sample");
            const screenshot_w = app_bootstrap.parseEnvI32("ZIDE_FONT_SAMPLE_SCREENSHOT_WIDTH", 0);
            const screenshot_h = app_bootstrap.parseEnvI32("ZIDE_FONT_SAMPLE_SCREENSHOT_HEIGHT", 0);
            if (screenshot_w > 0 and screenshot_h > 0) {
                shell.rendererPtr().dumpWindowScreenshotPpmSized(path, screenshot_w, screenshot_h) catch |err| {
                    log.logf(.warning, 
                        "screenshot failed path={s} mode=sized size={d}x{d} err={s}",
                        .{ path, screenshot_w, screenshot_h, @errorName(err) },
                    );
                };
            } else {
                shell.rendererPtr().dumpWindowScreenshotPpm(path) catch |err| {
                    log.logf(.warning, "screenshot failed path={s} mode=window err={s}", .{ path, @errorName(err) });
                };
            }
        }
        shell.requestClose();
        state.font_sample_close_pending = false;
    }
    return true;
}
