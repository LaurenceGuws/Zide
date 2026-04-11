const std = @import("std");
const bootstrap_graph = @import("bootstrap_graph.zig");
const android_terminal_host_graph = @import("android_terminal_host_graph.zig");
const app_graph = @import("app_graph.zig");
const ide_graph = @import("ide_graph.zig");
const tooling_graph = @import("tooling_graph.zig");

pub fn build(b: *std.Build) void {
    const boot = bootstrap_graph.initBuildBootstrap(b);
    android_terminal_host_graph.addAndroidTerminalHostBridgeStep(b, boot);
    _ = tooling_graph.addLuaMetaStep(b, boot.target, boot.optimize);

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
