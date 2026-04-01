const std = @import("std");
const platform_capabilities = @import("platform_capabilities.zig");
const step_utils = @import("step_utils.zig");

const addSystemCommandStep = step_utils.addSystemCommandStep;
const addGateStep = step_utils.addGateStep;

pub fn addWindowsShellExtension(
    b: *std.Build,
    target: std.Build.ResolvedTarget,
    optimize: std.builtin.OptimizeMode,
) ?*std.Build.Step {
    const capability = platform_capabilities.platformCapability(target.result.os.tag) orelse
        @panic("dependency policy violation: unsupported target os for workflow setup");
    if (!capability.supports_windows_shell_extension) return null;

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

pub fn addModeGateAndBundleSteps(
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
    _ = addSystemCommandStep(
        b,
        "mode-size-report",
        "Report focused mode binary sizes",
        &.{ "bash", "tools/build_tools/reports/report_mode_binary_sizes.sh" },
        &.{install_step},
    );

    const capability = platform_capabilities.platformCapability(target_os) orelse
        @panic("dependency policy violation: unsupported target os for workflow steps");
    if (capability.supports_terminal_bundle) {
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
        &.{install_step},
    );

    _ = addGateStep(
        b,
        "gui-smokes-manual",
        "Run interactive GUI smokes (manual)",
        &.{gui_smokes_manual_step},
    );
}

pub fn addGrammarUpdateStep(
    b: *std.Build,
    passthrough_args: ?[]const []const u8,
) void {
    const grammar_update_cmd = b.addSystemCommand(&.{
        "bash",
        "tools/editor/tree_sitter/grammar_update_proxy.sh",
    });
    if (passthrough_args) |args| grammar_update_cmd.addArgs(args);
    const grammar_update_step = b.step(
        "grammar-update",
        "Build and install tree-sitter grammar packs via zide-tree-sitter",
    );
    grammar_update_step.dependOn(&grammar_update_cmd.step);
}
