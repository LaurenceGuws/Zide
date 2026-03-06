const std = @import("std");
const app_types = @import("app_types.zig");
const mode_specs = @import("mode_specs.zig");
const target_profile = @import("target_profile.zig");
const target_factory = @import("target_factory.zig");
const target_config = @import("target_config.zig");
const step_utils = @import("step_utils.zig");
const windows_runtime = @import("windows_runtime.zig");

const AppLinkContext = app_types.AppLinkContext;
const addAppExecutable = target_factory.addAppExecutable;
const configureAppExecutable = target_config.configureAppExecutable;
const addMainModeRunSteps = step_utils.addMainModeRunSteps;
const addFocusedModeExecutable = target_factory.addFocusedModeExecutable;
const MainModeRunSteps = step_utils.MainModeRunSteps;
const installVcpkgRuntimeDlls = windows_runtime.installVcpkgRuntimeDlls;

pub fn planIdePrimaryAppGraph(
    b: *std.Build,
    target: std.Build.ResolvedTarget,
    optimize: std.builtin.OptimizeMode,
    build_options: *std.Build.Step.Options,
    zlua_module: *std.Build.Module,
    app_link_ctx: AppLinkContext,
    passthrough_args: ?[]const []const u8,
) MainModeRunSteps {
    const exe = addAppExecutable(
        b,
        target,
        optimize,
        build_options,
        zlua_module,
        "zide",
        "src/main.zig",
    );
    configureAppExecutable(exe, app_link_ctx, "zide", target_profile.app_main);
    b.installArtifact(exe);
    return addMainModeRunSteps(b, b.getInstallStep(), exe, passthrough_args);
}

pub fn planFocusedRuntimeAppGraph(
    b: *std.Build,
    target: std.Build.ResolvedTarget,
    optimize: std.builtin.OptimizeMode,
    build_options: *std.Build.Step.Options,
    zlua_module: *std.Build.Module,
    app_link_ctx: AppLinkContext,
    mode: mode_specs.BuildMode,
    passthrough_args: ?[]const []const u8,
) void {
    const spec = mode_specs.selectedFocusedApp(mode) orelse
        @panic("dependency policy violation: focused runtime mode requires selected app spec");
    _ = addFocusedModeExecutable(
        b,
        target,
        optimize,
        build_options,
        zlua_module,
        app_link_ctx,
        spec.name,
        spec.root_source_file,
        spec.profile,
        spec.run_step_name,
        spec.run_description,
        passthrough_args,
    );
}

pub fn planAppModeGraphAndInstallRuntime(
    b: *std.Build,
    target: std.Build.ResolvedTarget,
    optimize: std.builtin.OptimizeMode,
    build_options: *std.Build.Step.Options,
    zlua_module: *std.Build.Module,
    app_link_ctx: AppLinkContext,
    mode: mode_specs.BuildMode,
    passthrough_args: ?[]const []const u8,
    target_os: std.Target.Os.Tag,
    use_vcpkg: bool,
    vcpkg_bin: ?[]const u8,
) ?MainModeRunSteps {
    switch (mode) {
        .ide => {
            const steps = planIdePrimaryAppGraph(
                b,
                target,
                optimize,
                build_options,
                zlua_module,
                app_link_ctx,
                passthrough_args,
            );
            installVcpkgRuntimeDlls(b, target_os, use_vcpkg, vcpkg_bin);
            return steps;
        },
        .terminal, .editor => {
            planFocusedRuntimeAppGraph(
                b,
                target,
                optimize,
                build_options,
                zlua_module,
                app_link_ctx,
                mode,
                passthrough_args,
            );
            installVcpkgRuntimeDlls(b, target_os, use_vcpkg, vcpkg_bin);
            return null;
        },
    }
}
