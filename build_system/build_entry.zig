const std = @import("std");
const step_utils = @import("step_utils.zig");
const bootstrap_graph = @import("bootstrap_graph.zig");
const app_graph = @import("app_graph.zig");
const ide_graph = @import("ide_graph.zig");

pub fn build(b: *std.Build) void {
    const boot = bootstrap_graph.initBuildBootstrap(b);

    const meta_tool = b.addExecutable(.{
        .name = "generate_lua_meta",
        .root_module = b.createModule(.{
            .root_source_file = b.path("tools/generate_lua_meta.zig"),
            .target = boot.target,
            .optimize = boot.optimize,
            .imports = &.{
                .{
                    .name = "zide_meta_root",
                    .module = b.createModule(.{
                        .root_source_file = b.path("src/meta_root.zig"),
                        .target = boot.target,
                        .optimize = boot.optimize,
                    }),
                },
            },
        }),
    });
    const meta_run = b.addRunArtifact(meta_tool);
    meta_run.addArg(b.path("lua/zide-meta.lua").getPath(b));
    meta_run.addArg(b.path("snippets/lua.json").getPath(b));
    meta_run.addArg(b.path(".luarc.json").getPath(b));
    const meta_step = b.step("meta", "Generate Lua metadata");
    meta_step.dependOn(&meta_run.step);

    _ = app_graph.planAppModeGraphAndInstallRuntime(
        b,
        boot.target,
        boot.optimize,
        boot.build_options,
        boot.zlua_module,
        boot.zlua_portable_module,
        boot.app_link_ctx,
        boot.build_mode,
        b.args,
    ) orelse return;

    ide_graph.planIdeExtendedBuildGraph(
        b,
        boot.target,
        boot.optimize,
        boot.target_os,
        boot.treesitter,
        boot.app_link_ctx,
        boot.build_options,
        boot.zlua_module,
        boot.zlua_portable_module,
    );
}
