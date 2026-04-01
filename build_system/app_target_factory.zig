const std = @import("std");
const app_types = @import("app_types.zig");
const target_config = @import("target_config.zig");
const step_utils = @import("step_utils.zig");
const target_profile = @import("target_profile.zig");
const windows_identity = @import("windows_identity.zig");
const compile_utils = @import("compile_utils.zig");

pub fn configureWindowsGuiSubsystem(step: *std.Build.Step.Compile, target: std.Build.ResolvedTarget) void {
    if (target.result.os.tag == .windows) {
        step.subsystem = .Windows;
    }
}

pub fn addAppExecutable(
    b: *std.Build,
    target: std.Build.ResolvedTarget,
    optimize: std.builtin.OptimizeMode,
    build_options: *std.Build.Step.Options,
    zlua_module: *std.Build.Module,
    zlua_portable_module: ?*std.Build.Module,
    name: []const u8,
    root_source_file: []const u8,
) *std.Build.Step.Compile {
    const exe = compile_utils.addExecutable(b, name, b.createModule(.{
        .root_source_file = b.path(root_source_file),
        .target = target,
        .optimize = optimize,
        .link_libc = true,
    }));
    windows_identity.configureExecutableResources(b, exe, target, name);
    exe.root_module.addOptions("build_options", build_options);
    exe.root_module.addImport("zlua", zlua_module);
    if (zlua_portable_module) |module| {
        exe.root_module.addImport("zlua_portable", module);
    }
    return exe;
}

pub fn addFocusedModeExecutable(
    b: *std.Build,
    target: std.Build.ResolvedTarget,
    optimize: std.builtin.OptimizeMode,
    build_options: *std.Build.Step.Options,
    zlua_module: *std.Build.Module,
    zlua_portable_module: ?*std.Build.Module,
    ctx: app_types.AppLinkContext,
    name: []const u8,
    root_source_file: []const u8,
    profile: target_profile.LinkProfile,
    run_step_name: []const u8,
    run_description: []const u8,
    passthrough_args: ?[]const []const u8,
) *std.Build.Step.Compile {
    const exe = addAppExecutable(
        b,
        target,
        optimize,
        build_options,
        zlua_module,
        zlua_portable_module,
        name,
        root_source_file,
    );
    configureWindowsGuiSubsystem(exe, target);
    target_config.configureAppExecutable(exe, ctx, name, profile);
    b.installArtifact(exe);
    _ = step_utils.addRunStepForArtifact(
        b,
        b.getInstallStep(),
        exe,
        run_step_name,
        run_description,
        &.{},
        passthrough_args,
    );
    return exe;
}
