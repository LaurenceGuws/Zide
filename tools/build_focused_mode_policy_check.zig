const std = @import("std");
const build_options = @import("build_options");

pub fn main() !void {
    const mode = build_options.build_mode;
    const treesitter_enabled = build_options.treesitter_enabled;

    const is_terminal = std.mem.eql(u8, mode, "terminal");
    if (is_terminal and treesitter_enabled) {
        @panic("focused mode policy violation: terminal mode must not enable tree-sitter");
    }
    if (!is_terminal and !treesitter_enabled) {
        @panic("focused mode policy violation: non-terminal mode must enable tree-sitter");
    }
}
