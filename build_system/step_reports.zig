const std = @import("std");
const compile_utils = @import("compile_utils.zig");
const report_catalog = @import("report_catalog.zig");

const ReportToolSpec = report_catalog.ReportToolSpec;

pub fn addReportBuildAllStep(
    b: *std.Build,
    deps: []const *std.Build.Step,
) *std.Build.Step {
    const step = b.step(
        "report-build-all",
        "Run all core build report/check steps",
    );
    for (deps) |dep| step.dependOn(dep);
    return step;
}

pub fn addReportBuildProfilesStep(
    b: *std.Build,
    target: std.Build.ResolvedTarget,
    optimize: std.builtin.OptimizeMode,
) *std.Build.Step {
    return addReportToolRunStep(b, target, optimize, null, report_catalog.build_profile_report);
}

pub fn addReportBuildDependenciesStep(
    b: *std.Build,
    target: std.Build.ResolvedTarget,
    optimize: std.builtin.OptimizeMode,
) *std.Build.Step {
    return addReportToolRunStep(b, target, optimize, null, report_catalog.build_dependency_report);
}

pub fn addReportBuildModeStep(
    b: *std.Build,
    target: std.Build.ResolvedTarget,
    optimize: std.builtin.OptimizeMode,
    build_options: *std.Build.Step.Options,
) *std.Build.Step {
    return addReportToolRunStep(b, target, optimize, build_options, report_catalog.build_mode_report);
}

pub fn addReportBuildBootstrapStep(
    b: *std.Build,
    target: std.Build.ResolvedTarget,
    optimize: std.builtin.OptimizeMode,
    build_options: *std.Build.Step.Options,
) *std.Build.Step {
    return addReportToolRunStep(b, target, optimize, build_options, report_catalog.build_bootstrap_report);
}

pub fn addReportBuildFocusedPolicyStep(
    b: *std.Build,
    target: std.Build.ResolvedTarget,
    optimize: std.builtin.OptimizeMode,
    build_options: *std.Build.Step.Options,
) *std.Build.Step {
    return addReportToolRunStep(b, target, optimize, build_options, report_catalog.build_focused_policy_report);
}

pub fn addReportBuildTargetStep(
    b: *std.Build,
    target: std.Build.ResolvedTarget,
    optimize: std.builtin.OptimizeMode,
    build_options: *std.Build.Step.Options,
) *std.Build.Step {
    return addReportToolRunStep(b, target, optimize, build_options, report_catalog.build_target_report);
}

pub fn addReportBuildPolicyStep(
    b: *std.Build,
    target: std.Build.ResolvedTarget,
    optimize: std.builtin.OptimizeMode,
    build_options: *std.Build.Step.Options,
) *std.Build.Step {
    return addReportToolRunStep(b, target, optimize, build_options, report_catalog.build_policy_report);
}

pub fn addReportBuildPlatformStep(
    b: *std.Build,
    target: std.Build.ResolvedTarget,
    optimize: std.builtin.OptimizeMode,
    build_options: *std.Build.Step.Options,
) *std.Build.Step {
    return addReportToolRunStep(b, target, optimize, build_options, report_catalog.build_platform_report);
}

pub fn addReportBuildSurfaceStep(
    b: *std.Build,
    target: std.Build.ResolvedTarget,
    optimize: std.builtin.OptimizeMode,
) *std.Build.Step {
    return addReportToolRunStep(b, target, optimize, null, report_catalog.build_surface_report);
}

pub fn addCoreBuildReportSuite(
    b: *std.Build,
    target: std.Build.ResolvedTarget,
    optimize: std.builtin.OptimizeMode,
    build_options: *std.Build.Step.Options,
) *std.Build.Step {
    var deps: [report_catalog.core_bootstrap_report_specs.len + 1]*std.Build.Step = undefined;
    inline for (report_catalog.core_bootstrap_report_specs, 0..) |spec, index| {
        const maybe_build_options = if (spec.adds_build_options) build_options else null;
        deps[index] = addReportToolRunStep(b, target, optimize, maybe_build_options, spec);
    }
    deps[report_catalog.core_bootstrap_report_specs.len] = addCheckBuildReportToolsStep(
        b,
        target,
        optimize,
        build_options,
    );
    return addReportBuildAllStep(b, &deps);
}

pub fn addCheckBuildReportToolsStep(
    b: *std.Build,
    target: std.Build.ResolvedTarget,
    optimize: std.builtin.OptimizeMode,
    build_options: *std.Build.Step.Options,
) *std.Build.Step {
    const step = b.step(
        "check-build-report-tools",
        "Compile-check all core build report tools",
    );
    for (report_catalog.core_report_tool_specs) |spec| {
        step.dependOn(&addReportToolCheckExecutable(b, target, optimize, build_options, spec).step);
    }

    return step;
}

fn addReportToolRunStep(
    b: *std.Build,
    target: std.Build.ResolvedTarget,
    optimize: std.builtin.OptimizeMode,
    build_options: ?*std.Build.Step.Options,
    spec: ReportToolSpec,
) *std.Build.Step {
    const exe = addReportToolExecutable(b, target, optimize, build_options, spec);
    const run = b.addRunArtifact(exe);
    const step = b.step(spec.step_name, spec.description);
    step.dependOn(&run.step);
    return step;
}

fn addReportToolCheckExecutable(
    b: *std.Build,
    target: std.Build.ResolvedTarget,
    optimize: std.builtin.OptimizeMode,
    build_options: ?*std.Build.Step.Options,
    spec: ReportToolSpec,
) *std.Build.Step.Compile {
    return addReportToolExecutable(b, target, optimize, build_options, .{
        .exe_name = spec.check_exe_name,
        .check_exe_name = spec.check_exe_name,
        .root_source_file = spec.root_source_file,
        .step_name = spec.step_name,
        .description = spec.description,
        .adds_build_options = spec.adds_build_options,
        .adds_target_profile_import = spec.adds_target_profile_import,
        .adds_step_catalog_import = spec.adds_step_catalog_import,
        .adds_policy_catalog_import = spec.adds_policy_catalog_import,
        .adds_profile_catalog_import = spec.adds_profile_catalog_import,
        .adds_platform_capabilities_import = spec.adds_platform_capabilities_import,
    });
}

fn addReportToolExecutable(
    b: *std.Build,
    target: std.Build.ResolvedTarget,
    optimize: std.builtin.OptimizeMode,
    build_options: ?*std.Build.Step.Options,
    spec: ReportToolSpec,
) *std.Build.Step.Compile {
    const exe = compile_utils.addExecutable(b, spec.exe_name, b.createModule(.{
        .root_source_file = b.path(spec.root_source_file),
        .target = target,
        .optimize = optimize,
    }));
    if (spec.adds_build_options) {
        exe.root_module.addOptions("build_options", build_options.?);
    }
    if (spec.adds_target_profile_import) {
        exe.root_module.addAnonymousImport("target_profile", .{
            .root_source_file = b.path("build_system/target_profile.zig"),
            .target = target,
            .optimize = optimize,
        });
    }
    if (spec.adds_step_catalog_import) {
        exe.root_module.addAnonymousImport("step_catalog", .{
            .root_source_file = b.path("build_system/step_catalog.zig"),
            .target = target,
            .optimize = optimize,
        });
    }
    if (spec.adds_policy_catalog_import) {
        exe.root_module.addAnonymousImport("policy_catalog", .{
            .root_source_file = b.path("build_system/policy_catalog.zig"),
            .target = target,
            .optimize = optimize,
        });
    }
    if (spec.adds_profile_catalog_import) {
        exe.root_module.addAnonymousImport("profile_catalog", .{
            .root_source_file = b.path("build_system/profile_catalog.zig"),
            .target = target,
            .optimize = optimize,
        });
    }
    if (spec.adds_platform_capabilities_import) {
        exe.root_module.addAnonymousImport("platform_capabilities", .{
            .root_source_file = b.path("build_system/platform_capabilities.zig"),
            .target = target,
            .optimize = optimize,
        });
    }
    return exe;
}
