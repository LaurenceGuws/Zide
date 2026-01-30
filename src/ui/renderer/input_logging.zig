const app_logger = @import("../../app_logger.zig");

pub fn logTextInput(bytes: usize) void {
    const input_log = app_logger.logger("input.sdl");
    if (input_log.enabled_file or input_log.enabled_console) {
        input_log.logf("textinput bytes={d}", .{bytes});
    }
}

pub fn logTextEditing(bytes: usize, cursor: i32, selection: i32) void {
    const ime_log = app_logger.logger("sdl.ime");
    if (ime_log.enabled_file or ime_log.enabled_console) {
        ime_log.logf(
            "textediting bytes={d} cursor={d} selection={d}",
            .{ bytes, cursor, selection },
        );
    }
}
