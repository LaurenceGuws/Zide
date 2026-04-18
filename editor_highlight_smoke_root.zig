//! Repository-root entry for `zig build test-editor-highlight-smoke` (same module
//! root rationale as `editor_tests_root.zig`).

comptime {
    _ = @import("tests/editor_highlight_smoke_tests.zig");
}
