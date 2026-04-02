const std = @import("std");

pub fn configureWindowsLinker(step: *std.Build.Step.Compile) void {
    _ = step;
}

pub fn addExecutable(
    b: *std.Build,
    name: []const u8,
    root_module: *std.Build.Module,
) *std.Build.Step.Compile {
    const exe = b.addExecutable(.{
        .name = name,
        .root_module = root_module,
    });
    configureWindowsLinker(exe);
    return exe;
}

pub fn addCompileRunStep(
    b: *std.Build,
    artifact: *std.Build.Step.Compile,
    step_name: []const u8,
    description: []const u8,
) *std.Build.Step {
    const run = b.addRunArtifact(artifact);
    const step = b.step(step_name, description);
    step.dependOn(&run.step);
    return step;
}
