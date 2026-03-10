comptime {
    _ = @import("../src/main.zig");
    _ = @import("../src/main_tests.zig");
    _ = @import("../src/editor_tests.zig");
    _ = @import("../src/editor_snapshot_tests.zig");
    _ = @import("../src/highlight_replay_tests.zig");
    _ = @import("../src/input_tests.zig");
    _ = @import("../src/layout_tests.zig");
    _ = @import("../src/terminal_reflow_tests.zig");
    _ = @import("../src/terminal/core/terminal_session.zig");
    _ = @import("../src/terminal/core/terminal_session_tests.zig");
    _ = @import("../src/ui/widgets/terminal_widget_draw.zig");
    _ = @import("../src/terminal_key_encoder_tests.zig");
    _ = @import("../src/terminal_input_encoding_tests.zig");
    _ = @import("../src/editor_clipboard_tests.zig");
    _ = @import("../src/terminal_snapshot_tests.zig");
    _ = @import("../src/widget_action_tests.zig");
}
