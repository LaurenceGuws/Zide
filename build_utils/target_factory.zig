const std = @import("std");
const app_types = @import("app_types.zig");
const target_config = @import("target_config.zig");
const step_utils = @import("step_utils.zig");
const target_profile = @import("target_profile.zig");

pub fn addAppExecutable(
    b: *std.Build,
    target: std.Build.ResolvedTarget,
    optimize: std.builtin.OptimizeMode,
    build_options: *std.Build.Step.Options,
    zlua_module: *std.Build.Module,
    name: []const u8,
    root_source_file: []const u8,
) *std.Build.Step.Compile {
    const exe = b.addExecutable(.{
        .name = name,
        .root_module = b.createModule(.{
            .root_source_file = b.path(root_source_file),
            .target = target,
            .optimize = optimize,
            .link_libc = true,
        }),
    });
    exe.root_module.addOptions("build_options", build_options);
    exe.root_module.addImport("zlua", zlua_module);
    return exe;
}

pub fn addFocusedModeExecutable(
    b: *std.Build,
    target: std.Build.ResolvedTarget,
    optimize: std.builtin.OptimizeMode,
    build_options: *std.Build.Step.Options,
    zlua_module: *std.Build.Module,
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
        name,
        root_source_file,
    );
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

pub fn addSdlConfiguredTest(
    b: *std.Build,
    target: std.Build.ResolvedTarget,
    optimize: std.builtin.OptimizeMode,
    root_source_file: []const u8,
    build_options: ?*std.Build.Step.Options,
    ctx: app_types.AppLinkContext,
    profile: target_profile.LinkProfile,
) *std.Build.Step.Compile {
    const test_target = b.addTest(.{
        .root_module = b.createModule(.{
            .root_source_file = b.path(root_source_file),
            .target = target,
            .optimize = optimize,
            .link_libc = true,
        }),
    });
    if (build_options) |opts| {
        test_target.root_module.addOptions("build_options", opts);
    }
    target_config.configureSdlTestTarget(
        test_target,
        ctx,
        profile,
    );
    return test_target;
}

pub fn addSdlConfiguredExecutable(
    b: *std.Build,
    target: std.Build.ResolvedTarget,
    optimize: std.builtin.OptimizeMode,
    name: []const u8,
    root_source_file: []const u8,
    ctx: app_types.AppLinkContext,
    profile: target_profile.LinkProfile,
) *std.Build.Step.Compile {
    const exe = b.addExecutable(.{
        .name = name,
        .root_module = b.createModule(.{
            .root_source_file = b.path(root_source_file),
            .target = target,
            .optimize = optimize,
            .link_libc = true,
        }),
    });
    target_config.configureSdlTestTarget(
        exe,
        ctx,
        profile,
    );
    return exe;
}

pub fn addLibcTest(
    b: *std.Build,
    target: std.Build.ResolvedTarget,
    optimize: std.builtin.OptimizeMode,
    root_source_file: []const u8,
) *std.Build.Step.Compile {
    return b.addTest(.{
        .root_module = b.createModule(.{
            .root_source_file = b.path(root_source_file),
            .target = target,
            .optimize = optimize,
            .link_libc = true,
        }),
    });
}

pub fn addLibcExecutable(
    b: *std.Build,
    target: std.Build.ResolvedTarget,
    optimize: std.builtin.OptimizeMode,
    name: []const u8,
    root_source_file: []const u8,
) *std.Build.Step.Compile {
    return b.addExecutable(.{
        .name = name,
        .root_module = b.createModule(.{
            .root_source_file = b.path(root_source_file),
            .target = target,
            .optimize = optimize,
            .link_libc = true,
        }),
    });
}
