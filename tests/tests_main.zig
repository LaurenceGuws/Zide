comptime {
    _ = @import("../src/main.zig");
    _ = @import("main_tests.zig");
    _ = @import("editor_tests.zig");
    _ = @import("editor_snapshot_tests.zig");
    _ = @import("highlight_replay_tests.zig");
    _ = @import("input_tests.zig");
    _ = @import("layout_tests.zig");
    _ = @import("../src/terminal_reflow_tests.zig");
    _ = @import("../src/terminal/core/terminal_session.zig");
    _ = @import("../src/terminal/core/terminal_session_tests.zig");
    _ = @import("../src/ui/widgets/terminal_widget_draw.zig");
    _ = @import("../src/terminal_key_encoder_tests.zig");
    _ = @import("../src/terminal_input_encoding_tests.zig");
    _ = @import("editor_clipboard_tests.zig");
    _ = @import("../src/terminal_snapshot_tests.zig");
    _ = @import("widget_action_tests.zig");
}
