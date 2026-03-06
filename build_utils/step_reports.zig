const std = @import("std");

pub fn addBuildProfileReportStep(
    b: *std.Build,
    target: std.Build.ResolvedTarget,
    optimize: std.builtin.OptimizeMode,
) *std.Build.Step {
    const exe = b.addExecutable(.{
        .name = "build-profile-report",
        .root_module = b.createModule(.{
            .root_source_file = b.path("tools/build_profile_report.zig"),
            .target = target,
            .optimize = optimize,
        }),
    });
    exe.root_module.addAnonymousImport("target_profile", .{
        .root_source_file = b.path("build_utils/target_profile.zig"),
        .target = target,
        .optimize = optimize,
    });
    const run = b.addRunArtifact(exe);
    const step = b.step(
        "report-build-profiles",
        "Report active build dependency profiles",
    );
    step.dependOn(&run.step);
    return step;
}

pub fn addBuildModeReportStep(
    b: *std.Build,
    target: std.Build.ResolvedTarget,
    optimize: std.builtin.OptimizeMode,
    build_options: *std.Build.Step.Options,
) *std.Build.Step {
    const exe = b.addExecutable(.{
        .name = "build-mode-report",
        .root_module = b.createModule(.{
            .root_source_file = b.path("tools/build_mode_report.zig"),
            .target = target,
            .optimize = optimize,
        }),
    });
    exe.root_module.addOptions("build_options", build_options);
    const run = b.addRunArtifact(exe);
    const step = b.step(
        "report-build-mode",
        "Report selected app build mode and graph path",
    );
    step.dependOn(&run.step);
    return step;
}

pub fn addBuildBootstrapReportStep(
    b: *std.Build,
    target: std.Build.ResolvedTarget,
    optimize: std.builtin.OptimizeMode,
    build_options: *std.Build.Step.Options,
) *std.Build.Step {
    const exe = b.addExecutable(.{
        .name = "build-bootstrap-report",
        .root_module = b.createModule(.{
            .root_source_file = b.path("tools/build_bootstrap_report.zig"),
            .target = target,
            .optimize = optimize,
        }),
    });
    exe.root_module.addOptions("build_options", build_options);
    const run = b.addRunArtifact(exe);
    const step = b.step(
        "report-build-bootstrap",
        "Report resolved build bootstrap context",
    );
    step.dependOn(&run.step);
    return step;
}

pub fn addBuildFocusedModePolicyCheckStep(
    b: *std.Build,
    target: std.Build.ResolvedTarget,
    optimize: std.builtin.OptimizeMode,
    build_options: *std.Build.Step.Options,
) *std.Build.Step {
    const exe = b.addExecutable(.{
        .name = "build-focused-mode-policy-check",
        .root_module = b.createModule(.{
            .root_source_file = b.path("tools/build_focused_mode_policy_check.zig"),
            .target = target,
            .optimize = optimize,
        }),
    });
    exe.root_module.addOptions("build_options", build_options);
    const run = b.addRunArtifact(exe);
    const step = b.step(
        "report-build-focused-policy",
        "Check focused mode dependency policy",
    );
    step.dependOn(&run.step);
    return step;
}

pub fn addBuildTargetReportStep(
    b: *std.Build,
    target: std.Build.ResolvedTarget,
    optimize: std.builtin.OptimizeMode,
    build_options: *std.Build.Step.Options,
) *std.Build.Step {
    const exe = b.addExecutable(.{
        .name = "build-target-report",
        .root_module = b.createModule(.{
            .root_source_file = b.path("tools/build_target_report.zig"),
            .target = target,
            .optimize = optimize,
        }),
    });
    exe.root_module.addOptions("build_options", build_options);
    const run = b.addRunArtifact(exe);
    const step = b.step(
        "report-build-target",
        "Report resolved target and optimize settings",
    );
    step.dependOn(&run.step);
    return step;
}
