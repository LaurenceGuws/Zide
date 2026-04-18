//! Repository-root entry for `zig build test-editor` so the test module root is the
//! project root. `tests/*.zig` may use `@import("../src/...")` without escaping the
//! package (see CZH-B4).

comptime {
    _ = @import("tests/tests_main.zig");
}
