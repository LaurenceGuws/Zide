pub const ProfileSpec = struct {
    name: []const u8,
    description: []const u8,
    profile: LinkProfile,
};

pub const LinkProfile = struct {
    include_treesitter: bool,
    include_text_stack: bool,
    include_lua: bool,
    include_fontconfig: bool,
};

pub const profiles = [_]ProfileSpec{
    .{ .name = "app_main", .description = "main IDE runtime target", .profile = .{ .include_treesitter = true, .include_text_stack = true, .include_lua = true, .include_fontconfig = true } },
    .{ .name = "app_terminal", .description = "focused terminal runtime target", .profile = .{ .include_treesitter = false, .include_text_stack = true, .include_lua = true, .include_fontconfig = true } },
    .{ .name = "app_editor", .description = "focused editor runtime target", .profile = .{ .include_treesitter = true, .include_text_stack = true, .include_lua = true, .include_fontconfig = true } },
    .{ .name = "app_ide", .description = "focused IDE runtime target", .profile = .{ .include_treesitter = true, .include_text_stack = true, .include_lua = true, .include_fontconfig = true } },
    .{ .name = "test_unit", .description = "core unit-test target", .profile = .{ .include_treesitter = true, .include_text_stack = false, .include_lua = false, .include_fontconfig = false } },
    .{ .name = "test_editor", .description = "editor-heavy test target", .profile = .{ .include_treesitter = true, .include_text_stack = true, .include_lua = true, .include_fontconfig = false } },
    .{ .name = "test_config", .description = "Lua config parser/merge tests", .profile = .{ .include_treesitter = false, .include_text_stack = true, .include_lua = true, .include_fontconfig = true } },
    .{ .name = "test_terminal_replay", .description = "terminal replay harness target", .profile = .{ .include_treesitter = false, .include_text_stack = false, .include_lua = false, .include_fontconfig = false } },
    .{ .name = "test_terminal_kitty_query", .description = "kitty query parse-path tests", .profile = .{ .include_treesitter = false, .include_text_stack = false, .include_lua = false, .include_fontconfig = false } },
    .{ .name = "test_terminal_focus_reporting", .description = "terminal focus reporting tests", .profile = .{ .include_treesitter = false, .include_text_stack = false, .include_lua = false, .include_fontconfig = false } },
    .{ .name = "test_terminal_workspace", .description = "terminal workspace lifecycle tests", .profile = .{ .include_treesitter = false, .include_text_stack = false, .include_lua = false, .include_fontconfig = false } },
};
