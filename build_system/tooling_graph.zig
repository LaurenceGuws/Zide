const std = @import("std");
const compile_utils = @import("compile_utils.zig");

pub fn addLuaMetaStep(
    b: *std.Build,
    target: std.Build.ResolvedTarget,
    optimize: std.builtin.OptimizeMode,
) *std.Build.Step {
    const meta_tool = compile_utils.addExecutable(b, "generate_lua_meta", b.createModule(.{
        .root_source_file = b.path("tools/generate_lua_meta.zig"),
        .target = target,
        .optimize = optimize,
        .imports = &.{
            .{
                .name = "zide_meta_root",
                .module = b.createModule(.{
                    .root_source_file = b.path("src/meta_root.zig"),
                    .target = target,
                    .optimize = optimize,
                }),
            },
        },
    }));
    const meta_run = b.addRunArtifact(meta_tool);
    meta_run.addArg(b.path("lua/zide-meta.lua").getPath(b));
    meta_run.addArg(b.path("snippets/lua.json").getPath(b));
    meta_run.addArg(b.path(".luarc.json").getPath(b));
    const meta_step = b.step("meta", "Generate Lua metadata");
    meta_step.dependOn(&meta_run.step);
    return meta_step;
}
