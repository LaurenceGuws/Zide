const app_logger = @import("../../app_logger.zig");

pub fn logTextInput(bytes: usize) void {
    const input_log = app_logger.logger("input.sdl");
    input_log.logf(.info, "textinput bytes={d}", .{bytes});
}

pub fn logTextEditing(bytes: usize, cursor: i32, selection: i32) void {
    const ime_log = app_logger.logger("sdl.ime");
    ime_log.logf(
        .info,
        "textediting bytes={d} cursor={d} selection={d}",
        .{ bytes, cursor, selection },
    );
}
