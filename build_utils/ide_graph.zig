const std = @import("std");
const app_types = @import("app_types.zig");
const mode_specs = @import("mode_specs.zig");
const target_profile = @import("target_profile.zig");
const target_config = @import("target_config.zig");
const target_factory = @import("target_factory.zig");
const step_utils = @import("step_utils.zig");
const step_reports = @import("step_reports.zig");

const AppLinkContext = app_types.AppLinkContext;
const addTreeSitterIncludes = target_config.addTreeSitterIncludes;
const addVendorAndStb = target_config.addVendorAndStb;
const linkFfiPlatform = target_config.linkFfiPlatform;
const addSdlConfiguredTest = target_factory.addSdlConfiguredTest;
const addSdlConfiguredExecutable = target_factory.addSdlConfiguredExecutable;
const addRunArtifactStep = step_utils.addRunArtifactStep;
const addLibcTest = target_factory.addLibcTest;
const addLibcExecutable = target_factory.addLibcExecutable;
const addCheckExecutableStep = step_utils.addCheckExecutableStep;
const addSystemCommandStep = step_utils.addSystemCommandStep;
const addReportBuildProfilesStep = step_reports.addReportBuildProfilesStep;
const addGateStep = step_utils.addGateStep;
const MainModeRunSteps = step_utils.MainModeRunSteps;

fn addModeGateAndBundleSteps(
    b: *std.Build,
    target_os: std.Target.Os.Tag,
    install_step: *std.Build.Step,
    test_step: *std.Build.Step,
    terminal_import_check_step: *std.Build.Step,
    app_import_check_step: *std.Build.Step,
    input_import_check_step: *std.Build.Step,
    editor_import_check_step: *std.Build.Step,
    build_dep_policy_step: *std.Build.Step,
    build_profile_report_step: *std.Build.Step,
    terminal_replay_all_step: *std.Build.Step,
    main_mode_run_steps: MainModeRunSteps,
) void {
    // Mode utility + packaging steps
    _ = addSystemCommandStep(
        b,
        "mode-size-report",
        "Report focused mode binary sizes",
        &.{ "bash", "tools/report_mode_binary_sizes.sh" },
        &.{install_step},
    );

    if (target_os == .linux) {
        _ = addSystemCommandStep(
            b,
            "bundle-terminal",
            "Bundle zide-terminal with resolved shared libs for portable use",
            &.{
                "bash",
                "tools/bundle_terminal_linux.sh",
                "zig-out/bin/zide-terminal",
                "zig-out/terminal-bundle",
                "assets",
            },
            &.{install_step},
        );
    }

    const mode_size_check_step = addSystemCommandStep(
        b,
        "mode-size-check",
        "Check focused binaries are not larger than main binary",
        &.{ "bash", "tools/check_mode_binary_sizes.sh" },
        &.{install_step},
    );

    _ = addGateStep(
        b,
        "mode-gates",
        "Run MODE extraction regression gate bundle",
        &.{
            test_step,
            terminal_import_check_step,
            app_import_check_step,
            input_import_check_step,
            editor_import_check_step,
            build_dep_policy_step,
            build_profile_report_step,
            install_step,
            mode_size_check_step,
            terminal_replay_all_step,
        },
    );

    _ = addGateStep(
        b,
        "mode-gates-fast",
        "Run fast non-replay MODE extraction gates",
        &.{
            test_step,
            terminal_import_check_step,
            app_import_check_step,
            input_import_check_step,
            editor_import_check_step,
            build_dep_policy_step,
            build_profile_report_step,
            install_step,
            mode_size_check_step,
        },
    );

    _ = addGateStep(
        b,
        "mode-smokes-manual",
        "Run interactive MODE smokes (manual)",
        &.{
            main_mode_run_steps.run,
            main_mode_run_steps.terminal,
            main_mode_run_steps.editor,
            main_mode_run_steps.ide,
        },
    );
}

pub fn planIdeExtendedBuildGraph(
    b: *std.Build,
    target: std.Build.ResolvedTarget,
    optimize: std.builtin.OptimizeMode,
    target_os: std.Target.Os.Tag,
    treesitter: ?*std.Build.Step.Compile,
    app_link_ctx: AppLinkContext,
    build_options: *std.Build.Step.Options,
    main_mode_run_steps: MainModeRunSteps,
) void {
    // FFI artifacts
    const terminal_ffi = b.addLibrary(.{
        .name = "zide-terminal-ffi",
        .linkage = .dynamic,
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/terminal_ffi_exports.zig"),
            .target = target,
            .optimize = optimize,
            .link_libc = true,
        }),
    });
    addVendorAndStb(terminal_ffi);
    linkFfiPlatform(terminal_ffi, target_os);
    const install_terminal_ffi = b.addInstallArtifact(terminal_ffi, .{});
    const install_terminal_ffi_header = b.addInstallFile(b.path("include/zide_terminal_ffi.h"), "include/zide_terminal_ffi.h");
    const terminal_ffi_step = b.step("build-terminal-ffi", "Build the terminal FFI shared library");
    terminal_ffi_step.dependOn(&install_terminal_ffi.step);
    terminal_ffi_step.dependOn(&install_terminal_ffi_header.step);

    const editor_ffi = b.addLibrary(.{
        .name = "zide-editor-ffi",
        .linkage = .dynamic,
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/editor_ffi_exports.zig"),
            .target = target,
            .optimize = optimize,
            .link_libc = true,
        }),
    });
    editor_ffi.linkLibrary(treesitter.?);
    addVendorAndStb(editor_ffi);
    addTreeSitterIncludes(editor_ffi, treesitter.?);
    linkFfiPlatform(editor_ffi, target_os);
    const install_editor_ffi = b.addInstallArtifact(editor_ffi, .{});
    const install_editor_ffi_header = b.addInstallFile(b.path("include/zide_editor_ffi.h"), "include/zide_editor_ffi.h");
    const editor_ffi_step = b.step("build-editor-ffi", "Build the editor FFI shared library");
    editor_ffi_step.dependOn(&install_editor_ffi.step);
    editor_ffi_step.dependOn(&install_editor_ffi_header.step);

    // Core test suites
    const unit_tests = addSdlConfiguredTest(
        b,
        target,
        optimize,
        "src/main.zig",
        build_options,
        app_link_ctx,
        target_profile.test_unit,
    );
    const test_step = addRunArtifactStep(b, unit_tests, "test", "Run unit tests").step;

    const editor_tests = addSdlConfiguredTest(
        b,
        target,
        optimize,
        "tests/tests_main.zig",
        build_options,
        app_link_ctx,
        target_profile.test_editor,
    );
    _ = addRunArtifactStep(b, editor_tests, "test-editor", "Run editor-specific tests").step;

    const config_tests = addSdlConfiguredTest(
        b,
        target,
        optimize,
        "src/config_tests.zig",
        null,
        app_link_ctx,
        target_profile.test_config,
    );
    _ = addRunArtifactStep(b, config_tests, "test-config", "Run Lua config parser/merge tests").step;

    // Replay + perf harnesses
    const terminal_replay_exe = addSdlConfiguredExecutable(
        b,
        target,
        optimize,
        "terminal-replay",
        "src/terminal_replay_main.zig",
        app_link_ctx,
        target_profile.test_terminal_replay,
    );
    const terminal_replay = addRunArtifactStep(
        b,
        terminal_replay_exe,
        "test-terminal-replay",
        "Run terminal replay harness",
    );
    if (b.args) |args| terminal_replay.run.addArgs(args);
    _ = terminal_replay.step;

    const terminal_replay_all = addRunArtifactStep(
        b,
        terminal_replay_exe,
        "test-terminal-replay-all",
        "Run terminal replay harness across all fixtures",
    );
    terminal_replay_all.run.addArg("--all");
    const terminal_replay_all_step = terminal_replay_all.step;

    const editor_perf_headless = addLibcExecutable(
        b,
        target,
        optimize,
        "editor-perf-headless",
        "src/editor_perf_main.zig",
    );
    editor_perf_headless.linkLibrary(treesitter.?);
    editor_perf_headless.addIncludePath(b.path("vendor"));
    addTreeSitterIncludes(editor_perf_headless, treesitter.?);
    const editor_perf_headless_run = addRunArtifactStep(
        b,
        editor_perf_headless,
        "perf-editor-headless",
        "Run headless editor large-file performance harness",
    );
    if (b.args) |args| editor_perf_headless_run.run.addArgs(args);
    _ = editor_perf_headless_run.step;

    _ = addSystemCommandStep(
        b,
        "perf-editor-gate",
        "Run repeatable editor performance gate against stress fixtures",
        &.{ "bash", "tools/perf_editor_gate.sh" },
        &.{},
    );

    for (mode_specs.terminal_tests) |spec| {
        const spec_test = addSdlConfiguredTest(
            b,
            target,
            optimize,
            spec.root_source_file,
            null,
            app_link_ctx,
            spec.profile,
        );
        _ = addRunArtifactStep(
            b,
            spec_test,
            spec.step_name,
            spec.step_desc,
        ).step;
    }

    const terminal_ffi_tests = addLibcTest(
        b,
        target,
        optimize,
        "src/terminal_ffi_smoke_tests.zig",
    );
    addVendorAndStb(terminal_ffi_tests);
    _ = addRunArtifactStep(
        b,
        terminal_ffi_tests,
        "test-terminal-ffi",
        "Run terminal FFI bridge tests",
    ).step;

    const editor_ffi_tests = addLibcTest(
        b,
        target,
        optimize,
        "src/editor_ffi_smoke_tests.zig",
    );
    editor_ffi_tests.linkLibrary(treesitter.?);
    addVendorAndStb(editor_ffi_tests);
    addTreeSitterIncludes(editor_ffi_tests, treesitter.?);
    _ = addRunArtifactStep(
        b,
        editor_ffi_tests,
        "test-editor-ffi",
        "Run editor FFI bridge tests",
    ).step;

    const terminal_ffi_pty_smoke = addLibcExecutable(
        b,
        target,
        optimize,
        "terminal-ffi-pty-smoke",
        "src/terminal_ffi_pty_smoke.zig",
    );
    addVendorAndStb(terminal_ffi_pty_smoke);
    _ = addRunArtifactStep(
        b,
        terminal_ffi_pty_smoke,
        "test-terminal-ffi-pty",
        "Run PTY-backed terminal FFI smoke",
    ).step;

    // Import/build policy checks
    const terminal_import_check_step = addCheckExecutableStep(
        b,
        target,
        optimize,
        "terminal-import-check",
        "tools/terminal_import_check.zig",
        "check-terminal-imports",
        "Check terminal module import layering",
    );
    const editor_import_check_step = addCheckExecutableStep(
        b,
        target,
        optimize,
        "editor-import-check",
        "tools/editor_import_check.zig",
        "check-editor-imports",
        "Check editor module import layering",
    );
    const app_import_check_step = addCheckExecutableStep(
        b,
        target,
        optimize,
        "app-import-check",
        "tools/app_import_check.zig",
        "check-app-imports",
        "Check app-level and mode-layer import boundaries",
    );
    const input_import_check_step = addCheckExecutableStep(
        b,
        target,
        optimize,
        "input-import-check",
        "tools/input_import_check.zig",
        "check-input-imports",
        "Check input module import layering",
    );
    const build_dep_policy_step = addCheckExecutableStep(
        b,
        target,
        optimize,
        "build-dep-policy-check",
        "tools/build_dep_policy_check.zig",
        "check-build-deps",
        "Check app target dependency policy wiring",
    );
    _ = addSystemCommandStep(
        b,
        "report-build-deps",
        "Report app target dependency policy wiring",
        &.{ "bash", "-lc", "rg -n \"configureAppExecutable\\(exe(_terminal|_editor|_ide)?|dependency policy violation\" build.zig" },
        &.{},
    );
    const build_profile_report_step = addReportBuildProfilesStep(
        b,
        target,
        optimize,
    );

    // Aggregate mode gates
    addModeGateAndBundleSteps(
        b,
        target_os,
        b.getInstallStep(),
        test_step,
        terminal_import_check_step,
        app_import_check_step,
        input_import_check_step,
        editor_import_check_step,
        build_dep_policy_step,
        build_profile_report_step,
        terminal_replay_all_step,
        main_mode_run_steps,
    );

    // Developer tooling
    const grammar_update = addLibcExecutable(
        b,
        target,
        optimize,
        "grammar-update",
        "tools/grammar_update.zig",
    );
    const grammar_update_run = addRunArtifactStep(
        b,
        grammar_update,
        "grammar-update",
        "Build and install tree-sitter grammar packs",
    );
    if (b.args) |args| grammar_update_run.run.addArgs(args);
    _ = grammar_update_run.step;
}
