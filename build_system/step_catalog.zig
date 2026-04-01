pub const StepSpec = struct {
    name: []const u8,
    description: []const u8,
};

pub const StepGroup = struct {
    title: []const u8,
    steps: []const StepSpec,
};

pub const primary_operator_steps = [_]StepSpec{
    .{ .name = "zig build", .description = "build/install the selected runtime target" },
    .{ .name = "zig build run", .description = "run the main IDE entry" },
    .{ .name = "zig build run-mode-terminal", .description = "run main entry in terminal mode" },
    .{ .name = "zig build run-mode-editor", .description = "run main entry in editor mode" },
    .{ .name = "zig build run-mode-ide", .description = "run main entry in IDE mode" },
    .{ .name = "zig build run-terminal", .description = "run focused terminal app build" },
    .{ .name = "zig build run-editor", .description = "run focused editor app build" },
};

pub const core_validation_steps = [_]StepSpec{
    .{ .name = "zig build test", .description = "run unit tests" },
    .{ .name = "zig build test-editor", .description = "run editor-specific tests" },
    .{ .name = "zig build test-config", .description = "run Lua config parser/merge tests" },
    .{ .name = "zig build test-terminal-replay", .description = "run terminal replay harness" },
    .{ .name = "zig build test-terminal-replay-all", .description = "replay all terminal fixtures" },
    .{ .name = "zig build check-terminal-imports", .description = "check terminal layering" },
    .{ .name = "zig build check-editor-imports", .description = "check editor layering" },
    .{ .name = "zig build check-app-imports", .description = "check app and mode layering" },
    .{ .name = "zig build check-input-imports", .description = "check input layering" },
    .{ .name = "zig build check-build-deps", .description = "check build dependency policy" },
};

pub const ffi_and_smoke_steps = [_]StepSpec{
    .{ .name = "zig build build-terminal-ffi", .description = "build terminal FFI library" },
    .{ .name = "zig build build-editor-ffi", .description = "build editor FFI library" },
    .{ .name = "zig build test-terminal-ffi", .description = "run terminal FFI tests" },
    .{ .name = "zig build test-editor-ffi", .description = "run editor FFI tests" },
    .{ .name = "zig build test-terminal-ffi-pty", .description = "run PTY-backed FFI smoke" },
    .{ .name = "zig build test-ffi-host-combo", .description = "run host combo smoke" },
    .{ .name = "zig build run-gui-smokes-manual-launcher", .description = "launch GUI smoke set" },
};

pub const tooling_and_report_steps = [_]StepSpec{
    .{ .name = "zig build meta", .description = "generate Lua metadata" },
    .{ .name = "zig build grammar-update", .description = "build/install tree-sitter grammar packs" },
    .{ .name = "zig build report-build-mode", .description = "report selected build mode" },
    .{ .name = "zig build report-build-bootstrap", .description = "report bootstrap context" },
    .{ .name = "zig build report-build-target", .description = "report target/optimize settings" },
    .{ .name = "zig build report-build-profiles", .description = "report dependency profiles" },
    .{ .name = "zig build report-build-platform", .description = "report target platform capability assumptions" },
    .{ .name = "zig build report-build-dependencies", .description = "report dependency intent per profile" },
    .{ .name = "zig build report-build-focused-policy", .description = "report focused-mode policy" },
    .{ .name = "zig build report-build-policy", .description = "report supported options and hard constraints" },
    .{ .name = "zig build report-build-surface", .description = "report operator-facing step taxonomy" },
    .{ .name = "zig build report-build-all", .description = "run all core build reports/checks" },
};

pub const operator_step_groups = [_]StepGroup{
    .{ .title = "Primary operator steps", .steps = &primary_operator_steps },
    .{ .title = "Core validation", .steps = &core_validation_steps },
    .{ .title = "FFI and focused smokes", .steps = &ffi_and_smoke_steps },
    .{ .title = "Tooling and reports", .steps = &tooling_and_report_steps },
};
