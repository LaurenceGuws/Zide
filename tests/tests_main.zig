//! Aggregates tests for `zig build test-editor` (repo-root module).
//!
//! Scope is intentionally narrow: any import of `grammar_manager` / `Editor` init paths
//! pulls `lua_config` and its ZigLua parse tests; the config test binary currently hits
//! a post-run abort (signal 6) after tests report success — same as `zig build test-config`.
//! Editor integration tests remain in `tests/editor_tests.zig` for a future harness that
//! either fixes the Lua teardown or uses `src/main.zig`-style test roots.
//!
//! Omitted until migrated: `PtyTerminalRuntime` suites, full `editor_tests.zig`, snapshots,
//! clipboard, highlight replay (see `docs/todo/core` backlog).

comptime {
    _ = @import("layout_tests.zig");
    _ = @import("widget_action_tests.zig");
    _ = @import("../src/ui/widgets/terminal_widget_draw.zig");
    _ = @import("../src/terminal/surface_contract.zig");
    _ = @import("terminal_key_encoder_tests.zig");
    _ = @import("terminal_input_encoding_tests.zig");
}
