const std = @import("std");

pub fn main() !void {
    std.debug.print(
        \\Zide build surface
        \\==================
        \\
        \\Primary operator steps
        \\- `zig build`: build/install the selected runtime target
        \\- `zig build run`: run the main IDE entry
        \\- `zig build run-mode-terminal`: run main entry in terminal mode
        \\- `zig build run-mode-editor`: run main entry in editor mode
        \\- `zig build run-mode-ide`: run main entry in IDE mode
        \\- `zig build run-terminal`: run focused terminal app build
        \\- `zig build run-editor`: run focused editor app build
        \\
        \\Core validation
        \\- `zig build test`: run unit tests
        \\- `zig build test-editor`: run editor-specific tests
        \\- `zig build test-config`: run Lua config parser/merge tests
        \\- `zig build test-terminal-replay`: run terminal replay harness
        \\- `zig build test-terminal-replay-all`: replay all terminal fixtures
        \\- `zig build check-terminal-imports`: check terminal layering
        \\- `zig build check-editor-imports`: check editor layering
        \\- `zig build check-app-imports`: check app and mode layering
        \\- `zig build check-input-imports`: check input layering
        \\- `zig build check-build-deps`: check build dependency policy
        \\
        \\FFI and focused smokes
        \\- `zig build build-terminal-ffi`: build terminal FFI library
        \\- `zig build build-editor-ffi`: build editor FFI library
        \\- `zig build test-terminal-ffi`: run terminal FFI tests
        \\- `zig build test-editor-ffi`: run editor FFI tests
        \\- `zig build test-terminal-ffi-pty`: run PTY-backed FFI smoke
        \\- `zig build test-ffi-host-combo`: run host combo smoke
        \\- `zig build run-gui-smokes-manual-launcher`: launch GUI smoke set
        \\
        \\Tooling and reports
        \\- `zig build meta`: generate Lua metadata
        \\- `zig build grammar-update`: build/install tree-sitter grammar packs
        \\- `zig build report-build-mode`: report selected build mode
        \\- `zig build report-build-bootstrap`: report bootstrap context
        \\- `zig build report-build-target`: report target/optimize settings
        \\- `zig build report-build-profiles`: report dependency profiles
        \\- `zig build report-build-focused-policy`: report focused-mode policy
        \\- `zig build report-build-policy`: report supported options and hard constraints
        \\- `zig build report-build-surface`: report this operator-facing step taxonomy
        \\- `zig build report-build-all`: run all core build reports/checks
        \\
        \\Build policy notes
        \\- Default runtime mode is `ide`; use `-Dmode=terminal` or `-Dmode=editor` for focused builds.
        \\- Renderer backend is currently `-Drenderer-backend=sdl_gl` only.
        \\- `main` runtime graph and extended IDE/test graph are planned separately on purpose.
        \\
    , .{});
}
