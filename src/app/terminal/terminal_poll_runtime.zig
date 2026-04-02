const std = @import("std");
const app_logger = @import("../../app_logger.zig");
const publication_state = @import("../../terminal/core/publication/publication_state.zig");
const session_runtime = @import("../../terminal/core/session/runtime.zig");

pub fn pollSingleSession(term: anytype, has_input: bool) !bool {
    const wake_log = app_logger.logger("terminal.wake");
    const pubgen_pre = publication_state.publishedGeneration(term);
    const had_data = session_runtime.hasData(term);
    var polled = false;
    if (had_data) {
        session_runtime.setInputPressure(term, has_input);
        try session_runtime.poll(term);
        polled = true;
    }
    const published_changed = publication_state.publishedGenerationChangedSince(term, pubgen_pre);
    if (wake_log.enabled_file or wake_log.enabled_console) {
        const pubgen_post = publication_state.publishedGeneration(term);
        wake_log.logFields(.info, "single_poll", &.{
            .{ .key = "has_input", .value = .{ .boolean = has_input } },
            .{ .key = "had_data", .value = .{ .boolean = had_data } },
            .{ .key = "polled", .value = .{ .boolean = polled } },
            .{ .key = "published_changed", .value = .{ .boolean = published_changed } },
            .{ .key = "published_generation_pre", .value = .{ .unsigned = pubgen_pre } },
            .{ .key = "published_generation_post", .value = .{ .unsigned = pubgen_post } },
        });
    }
    return published_changed;
}
