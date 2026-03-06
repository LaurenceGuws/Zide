const std = @import("std");

pub fn addRunStepForArtifact(
    b: *std.Build,
    install_step: *std.Build.Step,
    artifact: *std.Build.Step.Compile,
    step_name: []const u8,
    description: []const u8,
    fixed_args: []const []const u8,
    passthrough_args: ?[]const []const u8,
) *std.Build.Step {
    const run_cmd = b.addRunArtifact(artifact);
    run_cmd.step.dependOn(install_step);
    if (fixed_args.len > 0) run_cmd.addArgs(fixed_args);
    if (passthrough_args) |args| run_cmd.addArgs(args);
    const run_step = b.step(step_name, description);
    run_step.dependOn(&run_cmd.step);
    return run_step;
}

pub const MainModeRunSteps = struct {
    run: *std.Build.Step,
    terminal: *std.Build.Step,
    editor: *std.Build.Step,
    ide: *std.Build.Step,
};

pub fn addMainModeRunSteps(
    b: *std.Build,
    install_step: *std.Build.Step,
    exe: *std.Build.Step.Compile,
    passthrough_args: ?[]const []const u8,
) MainModeRunSteps {
    return .{
        .run = addRunStepForArtifact(b, install_step, exe, "run", "Run the IDE", &.{}, passthrough_args),
        .terminal = addRunStepForArtifact(
            b,
            install_step,
            exe,
            "run-mode-terminal",
            "Run main entry in --mode terminal",
            &.{ "--mode", "terminal" },
            null,
        ),
        .editor = addRunStepForArtifact(
            b,
            install_step,
            exe,
            "run-mode-editor",
            "Run main entry in --mode editor",
            &.{ "--mode", "editor" },
            null,
        ),
        .ide = addRunStepForArtifact(
            b,
            install_step,
            exe,
            "run-mode-ide",
            "Run main entry in --mode ide",
            &.{ "--mode", "ide" },
            null,
        ),
    };
}

pub fn addCheckExecutableStep(
    b: *std.Build,
    target: std.Build.ResolvedTarget,
    optimize: std.builtin.OptimizeMode,
    name: []const u8,
    root_source_file: []const u8,
    step_name: []const u8,
    description: []const u8,
) *std.Build.Step {
    const exe = b.addExecutable(.{
        .name = name,
        .root_module = b.createModule(.{
            .root_source_file = b.path(root_source_file),
            .target = target,
            .optimize = optimize,
        }),
    });
    const run = b.addRunArtifact(exe);
    const step = b.step(step_name, description);
    step.dependOn(&run.step);
    return step;
}

pub fn addRunArtifactStep(
    b: *std.Build,
    artifact: *std.Build.Step.Compile,
    step_name: []const u8,
    description: []const u8,
) struct {
    run: *std.Build.Step.Run,
    step: *std.Build.Step,
} {
    const run = b.addRunArtifact(artifact);
    const step = b.step(step_name, description);
    step.dependOn(&run.step);
    return .{
        .run = run,
        .step = step,
    };
}

pub fn addGateStep(
    b: *std.Build,
    step_name: []const u8,
    description: []const u8,
    deps: []const *std.Build.Step,
) *std.Build.Step {
    const step = b.step(step_name, description);
    for (deps) |dep| step.dependOn(dep);
    return step;
}

pub fn addSystemCommandStep(
    b: *std.Build,
    step_name: []const u8,
    description: []const u8,
    cmd_args: []const []const u8,
    deps: []const *std.Build.Step,
) *std.Build.Step {
    const cmd = b.addSystemCommand(cmd_args);
    const step = b.step(step_name, description);
    for (deps) |dep| step.dependOn(dep);
    step.dependOn(&cmd.step);
    return step;
}

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
