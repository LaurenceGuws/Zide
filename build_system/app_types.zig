const std = @import("std");

pub const AppLinkContext = struct {
    target_os: std.Target.Os.Tag,
    treesitter: ?*std.Build.Step.Compile,
    sdl_lib: ?*std.Build.Step.Compile,
    lua_lib: ?*std.Build.Step.Compile,
    freetype_lib: ?*std.Build.Step.Compile,
    harfbuzz_lib: ?*std.Build.Step.Compile,
};
