pub const LinkProfile = struct {
    include_treesitter: bool,
    include_text_stack: bool,
    include_lua: bool,
    include_fontconfig: bool,
};

pub fn assertPolicy() void {
    if (app_terminal.include_treesitter) {
        @panic("dependency policy violation: app_terminal must not include tree-sitter");
    }
    if (!app_main.include_text_stack or !app_main.include_lua) {
        @panic("dependency policy violation: app_main must include text stack + lua");
    }
    if (!app_editor.include_treesitter) {
        @panic("dependency policy violation: app_editor must include tree-sitter");
    }
    if (!app_ide.include_treesitter) {
        @panic("dependency policy violation: app_ide must include tree-sitter");
    }
}

pub const app_main = LinkProfile{
    .include_treesitter = true,
    .include_text_stack = true,
    .include_lua = true,
    .include_fontconfig = true,
};

pub const app_terminal = LinkProfile{
    .include_treesitter = false,
    .include_text_stack = true,
    .include_lua = true,
    .include_fontconfig = true,
};

pub const app_editor = LinkProfile{
    .include_treesitter = true,
    .include_text_stack = true,
    .include_lua = true,
    .include_fontconfig = true,
};

pub const app_ide = LinkProfile{
    .include_treesitter = true,
    .include_text_stack = true,
    .include_lua = true,
    .include_fontconfig = true,
};

pub const test_unit = LinkProfile{
    .include_treesitter = true,
    .include_text_stack = false,
    .include_lua = false,
    .include_fontconfig = false,
};

pub const test_editor = LinkProfile{
    .include_treesitter = true,
    .include_text_stack = true,
    .include_lua = true,
    .include_fontconfig = false,
};

pub const test_config = LinkProfile{
    .include_treesitter = false,
    .include_text_stack = true,
    .include_lua = true,
    .include_fontconfig = true,
};

pub const test_terminal_replay = LinkProfile{
    .include_treesitter = false,
    .include_text_stack = false,
    .include_lua = false,
    .include_fontconfig = false,
};

pub const test_terminal_kitty_query = LinkProfile{
    .include_treesitter = false,
    .include_text_stack = false,
    .include_lua = false,
    .include_fontconfig = false,
};

pub const test_terminal_focus_reporting = LinkProfile{
    .include_treesitter = false,
    .include_text_stack = false,
    .include_lua = false,
    .include_fontconfig = false,
};

pub const test_terminal_workspace = LinkProfile{
    .include_treesitter = false,
    .include_text_stack = false,
    .include_lua = false,
    .include_fontconfig = false,
};
