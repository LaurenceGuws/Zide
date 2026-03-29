const std = @import("std");
const app_types = @import("app_types.zig");
const mode_specs = @import("mode_specs.zig");
const target_profile = @import("target_profile.zig");
const target_config = @import("target_config.zig");
const target_factory = @import("target_factory.zig");
const step_utils = @import("step_utils.zig");
const step_reports = @import("step_reports.zig");

const AppLinkContext = app_types.AppLinkContext;
const addAppExecutable = target_factory.addAppExecutable;
const addTreeSitterIncludes = target_config.addTreeSitterIncludes;
const addVendorAndStb = target_config.addVendorAndStb;
const linkFfiPlatform = target_config.linkFfiPlatform;
const addSdlConfiguredTest = target_factory.addSdlConfiguredTest;
const addSdlConfiguredExecutable = target_factory.addSdlConfiguredExecutable;
const configureWindowsGuiSubsystem = target_factory.configureWindowsGuiSubsystem;
const configureAppExecutable = target_config.configureAppExecutable;
const addRunArtifactStep = step_utils.addRunArtifactStep;
const addLibcTest = target_factory.addLibcTest;
const addLibcExecutable = target_factory.addLibcExecutable;
const addCheckExecutableStep = step_utils.addCheckExecutableStep;
const addCheckExecutableStepWithImports = step_utils.addCheckExecutableStepWithImports;
const addSystemCommandStep = step_utils.addSystemCommandStep;
const addReportBuildProfilesStep = step_reports.addReportBuildProfilesStep;
const addGateStep = step_utils.addGateStep;

fn addWindowsShellExtension(
    b: *std.Build,
    target: std.Build.ResolvedTarget,
    optimize: std.builtin.OptimizeMode,
) ?*std.Build.Step {
    if (target.result.os.tag != .windows) return null;

    const dll = b.addLibrary(.{
        .name = "zide-shell-ext",
        .linkage = .dynamic,
        .root_module = b.createModule(.{
            .target = target,
            .optimize = optimize,
            .link_libc = true,
        }),
    });
    dll.addCSourceFile(.{
        .file = .{ .cwd_relative = "src/platform/windows_shell_extension/open_zide_terminal_here.cpp" },
        .flags = &.{ "-std=c++17", "-Wno-unused-command-line-argument" },
    });
    dll.linkSystemLibrary("ole32");
    dll.linkSystemLibrary("shell32");
    dll.linkSystemLibrary("shlwapi");
    dll.linkSystemLibrary("user32");
    const install = b.addInstallArtifact(dll, .{});
    return &install.step;
}

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
    gui_smokes_manual_step: *std.Build.Step,
) void {
    // Mode utility + packaging steps
    _ = addSystemCommandStep(
        b,
        "mode-size-report",
        "Report focused mode binary sizes",
        &.{ "bash", "tools/build_tools/reports/report_mode_binary_sizes.sh" },
        &.{install_step},
    );

    if (target_os == .linux) {
        _ = addSystemCommandStep(
            b,
            "bundle-terminal",
            "Bundle zide-terminal with resolved shared libs for portable use",
            &.{
                "bash",
                "tools/packaging/linux/bundle_terminal_linux.sh",
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
        &.{ "bash", "tools/build_tools/checks/check_mode_binary_sizes.sh" },
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
        "gui-smokes-manual-gates",
        "Run GUI smoke prerequisites",
        &.{
            install_step,
        },
    );

    _ = addGateStep(
        b,
        "gui-smokes-manual",
        "Run interactive GUI smokes (manual)",
        &.{
            gui_smokes_manual_step,
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
    zlua_module: *std.Build.Module,
) void {
    const windows_shell_extension_install = addWindowsShellExtension(b, target, optimize);

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
    editor_ffi.root_module.addImport("zlua", zlua_module);
    editor_ffi.linkLibrary(treesitter.?);
    addVendorAndStb(editor_ffi);
    addTreeSitterIncludes(editor_ffi, treesitter.?);
    linkFfiPlatform(editor_ffi, target_os);
    const install_editor_ffi = b.addInstallArtifact(editor_ffi, .{});
    const install_editor_ffi_header = b.addInstallFile(b.path("include/zide_editor_ffi.h"), "include/zide_editor_ffi.h");
    const editor_ffi_step = b.step("build-editor-ffi", "Build the editor FFI shared library");
    editor_ffi_step.dependOn(&install_editor_ffi.step);
    editor_ffi_step.dependOn(&install_editor_ffi_header.step);

    _ = addSystemCommandStep(
        b,
        "test-ffi-host-combo",
        "Run non-interactive terminal+editor FFI combo smoke",
        &.{
            "python3",
            "tests/ffi_smokes/host_combo/main.py",
            "--terminal-lib",
            "zig-out/lib/libzide-terminal-ffi.so",
            "--editor-lib",
            "zig-out/lib/libzide-editor-ffi.so",
        },
        &.{ terminal_ffi_step, editor_ffi_step },
    );

    // Core test suites
    const unit_tests = addSdlConfiguredTest(
        b,
        target,
        optimize,
        "src/main.zig",
        build_options,
        zlua_module,
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
        zlua_module,
        app_link_ctx,
        target_profile.test_editor,
    );
    _ = addRunArtifactStep(b, editor_tests, "test-editor", "Run editor-specific tests").step;

    const editor_highlight_smoke = addSdlConfiguredTest(
        b,
        target,
        optimize,
        "test_editor_highlight_smoke.zig",
        build_options,
        zlua_module,
        app_link_ctx,
        target_profile.test_editor,
    );
    _ = addRunArtifactStep(b, editor_highlight_smoke, "test-editor-highlight-smoke", "Run focused editor highlight smoke").step;

    const editor_scripted_input_smoke = addAppExecutable(
        b,
        target,
        optimize,
        build_options,
        zlua_module,
        "editor-scripted-input-smoke",
        "src/editor_scripted_input_smoke.zig",
    );
    configureAppExecutable(
        editor_scripted_input_smoke,
        app_link_ctx,
        "editor-scripted-input-smoke",
        target_profile.app_editor,
    );
    const editor_scripted_input_smoke_run = addRunArtifactStep(
        b,
        editor_scripted_input_smoke,
        "test-editor-scripted-input-smoke",
        "Run scripted editor input smoke harness",
    );
    if (b.args) |args| editor_scripted_input_smoke_run.run.addArgs(args);
    _ = editor_scripted_input_smoke_run.step;

    const config_tests = addSdlConfiguredTest(
        b,
        target,
        optimize,
        "src/config_tests.zig",
        build_options,
        zlua_module,
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

    const editor_perf_headless = addAppExecutable(
        b,
        target,
        optimize,
        build_options,
        zlua_module,
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
        &.{ "bash", "tools/observability/perf/perf_editor_gate.sh" },
        &.{},
    );

    for (mode_specs.terminal_tests) |spec| {
        const spec_test = addSdlConfiguredTest(
            b,
            target,
            optimize,
            spec.root_source_file,
            null,
            zlua_module,
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
        "tests/terminal_ffi_smoke_tests.zig",
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
    editor_ffi_tests.root_module.addImport("zlua", zlua_module);
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
        "tests/checks/terminal_import_check.zig",
        "check-terminal-imports",
        "Check terminal module import layering",
    );
    const editor_import_check_step = addCheckExecutableStep(
        b,
        target,
        optimize,
        "editor-import-check",
        "tests/checks/editor_import_check.zig",
        "check-editor-imports",
        "Check editor module import layering",
    );
    const app_import_check_step = addCheckExecutableStep(
        b,
        target,
        optimize,
        "app-import-check",
        "tests/checks/app_import_check.zig",
        "check-app-imports",
        "Check app-level and mode-layer import boundaries",
    );
    const input_import_check_step = addCheckExecutableStepWithImports(
        b,
        target,
        optimize,
        "input-import-check",
        "tests/checks/input_import_check.zig",
        &.{
            .{
                .name = "app_import_check",
                .root_source_file = "tests/checks/app_import_check.zig",
            },
        },
        "check-input-imports",
        "Check input module import layering",
    );
    const build_dep_policy_step = addCheckExecutableStep(
        b,
        target,
        optimize,
        "build-dep-policy-check",
        "tools/build_tools/checks/build_dep_policy_check.zig",
        "check-build-deps",
        "Check app target dependency policy wiring",
    );
    _ = addSystemCommandStep(
        b,
        "report-build-deps",
        "Report app target dependency policy wiring",
        &.{ "bash", "-lc", "rg -n \"configureAppExecutable\\(|dependency policy violation\" build_system" },
        &.{},
    );
    const build_profile_report_step = addReportBuildProfilesStep(
        b,
        target,
        optimize,
    );

    // Aggregate mode gates
    const focused_terminal = addAppExecutable(
        b,
        target,
        optimize,
        build_options,
        zlua_module,
        "zide-terminal",
        "src/entry_terminal.zig",
    );
    configureWindowsGuiSubsystem(focused_terminal, target);
    configureAppExecutable(focused_terminal, app_link_ctx, "zide-terminal", target_profile.app_terminal);
    const install_focused_terminal = b.addInstallArtifact(focused_terminal, .{});

    const focused_editor = addAppExecutable(
        b,
        target,
        optimize,
        build_options,
        zlua_module,
        "zide-editor",
        "src/entry_editor.zig",
    );
    configureWindowsGuiSubsystem(focused_editor, target);
    configureAppExecutable(focused_editor, app_link_ctx, "zide-editor", target_profile.app_editor);
    const install_focused_editor = b.addInstallArtifact(focused_editor, .{});

    const gui_smokes_manual = addLibcExecutable(
        b,
        target,
        optimize,
        "gui-smokes-manual",
        "tools/build_tools/smokes/gui_smokes_manual.zig",
    );
    const gui_smokes_manual_run = addRunArtifactStep(
        b,
        gui_smokes_manual,
        "run-gui-smokes-manual-launcher",
        "Launch editor, IDE, and terminal GUI smokes",
    );
    gui_smokes_manual_run.run.step.dependOn(&install_focused_editor.step);
    gui_smokes_manual_run.run.step.dependOn(&install_focused_terminal.step);
    gui_smokes_manual_run.run.step.dependOn(b.getInstallStep());
    gui_smokes_manual_run.run.addArg(b.getInstallPath(.bin, "zide-editor"));
    gui_smokes_manual_run.run.addArg(b.getInstallPath(.bin, "zide"));
    gui_smokes_manual_run.run.addArg(b.getInstallPath(.bin, "zide-terminal"));

    if (windows_shell_extension_install) |step| {
        b.getInstallStep().dependOn(step);
    }

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
        gui_smokes_manual_run.step,
    );

    // Developer tooling
    const grammar_update = addLibcExecutable(
        b,
        target,
        optimize,
        "grammar-update",
        "tools/editor/grammar/grammar_update.zig",
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
