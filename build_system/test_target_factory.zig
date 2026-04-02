const std = @import("std");
const app_types = @import("app_types.zig");
const target_config = @import("target_config.zig");
const target_profile = @import("target_profile.zig");
const compile_utils = @import("compile_utils.zig");

pub fn addSdlConfiguredTest(
    b: *std.Build,
    target: std.Build.ResolvedTarget,
    optimize: std.builtin.OptimizeMode,
    root_source_file: []const u8,
    build_options: ?*std.Build.Step.Options,
    zlua_module: ?*std.Build.Module,
    zlua_portable_module: ?*std.Build.Module,
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
    compile_utils.configureWindowsLinker(test_target);
    if (build_options) |opts| {
        test_target.root_module.addOptions("build_options", opts);
    }
    if (zlua_module) |module| {
        test_target.root_module.addImport("zlua", module);
    }
    if (zlua_portable_module) |module| {
        test_target.root_module.addImport("zlua_portable", module);
    }
    target_config.configureSdlTestTarget(test_target, ctx, profile);
    return test_target;
}

pub fn addSdlConfiguredExecutable(
    b: *std.Build,
    target: std.Build.ResolvedTarget,
    optimize: std.builtin.OptimizeMode,
    name: []const u8,
    root_source_file: []const u8,
    zlua_portable_module: ?*std.Build.Module,
    ctx: app_types.AppLinkContext,
    profile: target_profile.LinkProfile,
) *std.Build.Step.Compile {
    const exe = compile_utils.addExecutable(b, name, b.createModule(.{
        .root_source_file = b.path(root_source_file),
        .target = target,
        .optimize = optimize,
        .link_libc = true,
    }));
    if (zlua_portable_module) |module| {
        exe.root_module.addImport("zlua_portable", module);
    }
    target_config.configureSdlTestTarget(exe, ctx, profile);
    return exe;
}

pub fn addLibcTest(
    b: *std.Build,
    target: std.Build.ResolvedTarget,
    optimize: std.builtin.OptimizeMode,
    root_source_file: []const u8,
) *std.Build.Step.Compile {
    const test_target = b.addTest(.{
        .root_module = b.createModule(.{
            .root_source_file = b.path(root_source_file),
            .target = target,
            .optimize = optimize,
            .link_libc = true,
        }),
    });
    compile_utils.configureWindowsLinker(test_target);
    return test_target;
}

pub fn addLibcExecutable(
    b: *std.Build,
    target: std.Build.ResolvedTarget,
    optimize: std.builtin.OptimizeMode,
    name: []const u8,
    root_source_file: []const u8,
) *std.Build.Step.Compile {
    return compile_utils.addExecutable(b, name, b.createModule(.{
        .root_source_file = b.path(root_source_file),
        .target = target,
        .optimize = optimize,
        .link_libc = true,
    }));
}
