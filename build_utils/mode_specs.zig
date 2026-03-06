const std = @import("std");
const target_profile = @import("target_profile.zig");

pub const BuildMode = enum {
    ide,
    terminal,
    editor,
};

pub fn parseBuildMode(raw: []const u8) BuildMode {
    if (std.mem.eql(u8, raw, "ide")) return .ide;
    if (std.mem.eql(u8, raw, "terminal")) return .terminal;
    if (std.mem.eql(u8, raw, "editor")) return .editor;
    @panic("invalid -Dmode (expected: ide, terminal, editor)");
}

// Focused app build/run metadata
pub const FocusedAppSpec = struct {
    name: []const u8,
    root_source_file: []const u8,
    profile: target_profile.LinkProfile,
    run_step_name: []const u8,
    run_description: []const u8,
};

pub const focused_apps = [_]FocusedAppSpec{
    .{
        .name = "zide-terminal",
        .root_source_file = "src/entry_terminal.zig",
        .profile = target_profile.app_terminal,
        .run_step_name = "run-terminal",
        .run_description = "Run terminal-only app entry",
    },
    .{
        .name = "zide-editor",
        .root_source_file = "src/entry_editor.zig",
        .profile = target_profile.app_editor,
        .run_step_name = "run-editor",
        .run_description = "Run editor-only app entry",
    },
    .{
        .name = "zide-ide",
        .root_source_file = "src/entry_ide.zig",
        .profile = target_profile.app_ide,
        .run_step_name = "run-ide",
        .run_description = "Run ide-only app entry",
    },
};

pub fn selectedFocusedApp(mode: BuildMode) ?FocusedAppSpec {
    return switch (mode) {
        .terminal => focused_apps[0], // zide-terminal
        .editor => focused_apps[1], // zide-editor
        .ide => null,
    };
}

// Terminal-focused standalone test metadata
pub const TerminalTestSpec = struct {
    root_source_file: []const u8,
    step_name: []const u8,
    step_desc: []const u8,
    profile: target_profile.LinkProfile,
};

pub const terminal_tests = [_]TerminalTestSpec{
    .{
        .root_source_file = "src/terminal_kitty_query_parse_tests.zig",
        .step_name = "test-terminal-kitty-query-parse",
        .step_desc = "Run project-integrated kitty query parse-path tests",
        .profile = target_profile.test_terminal_kitty_query,
    },
    .{
        .root_source_file = "src/terminal_focus_reporting_tests.zig",
        .step_name = "test-terminal-focus-reporting",
        .step_desc = "Run project-integrated terminal focus reporting tests",
        .profile = target_profile.test_terminal_focus_reporting,
    },
    .{
        .root_source_file = "src/terminal_workspace_tests.zig",
        .step_name = "test-terminal-workspace",
        .step_desc = "Run terminal workspace lifecycle tests",
        .profile = target_profile.test_terminal_workspace,
    },
};
