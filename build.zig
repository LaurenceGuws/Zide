const std = @import("std");
const builtin = @import("builtin");
const dependency_path = @import("build_utils/dependency_path.zig");
const app_types = @import("build_utils/app_types.zig");
const target_config = @import("build_utils/target_config.zig");
const target_factory = @import("build_utils/target_factory.zig");
const step_utils = @import("build_utils/step_utils.zig");
const vcpkg_paths = @import("build_utils/vcpkg_paths.zig");
const dependency_resolver = @import("build_utils/dependency_resolver.zig");
const target_profile = @import("build_utils/target_profile.zig");
const mode_specs = @import("build_utils/mode_specs.zig");
const DependencySource = dependency_path.DependencySource;
const AppLinkContext = app_types.AppLinkContext;
const parseDependencyPath = dependency_path.parseDependencyPath;
const addTreeSitterIncludes = target_config.addTreeSitterIncludes;
const addVendorAndStb = target_config.addVendorAndStb;
const linkFfiPlatform = target_config.linkFfiPlatform;
const addAppExecutable = target_factory.addAppExecutable;
const configureAppExecutable = target_config.configureAppExecutable;
const addRunStepForArtifact = step_utils.addRunStepForArtifact;
const addFocusedModeExecutable = target_factory.addFocusedModeExecutable;
const addSdlConfiguredTest = target_factory.addSdlConfiguredTest;
const addSdlConfiguredExecutable = target_factory.addSdlConfiguredExecutable;
const addCheckExecutableStep = step_utils.addCheckExecutableStep;
const addRunArtifactStep = step_utils.addRunArtifactStep;
const addLibcTest = target_factory.addLibcTest;
const addLibcExecutable = target_factory.addLibcExecutable;
const addGateStep = step_utils.addGateStep;
const resolveVcpkgPaths = vcpkg_paths.resolveVcpkgPaths;
const addMainModeRunSteps = step_utils.addMainModeRunSteps;
const addSystemCommandStep = step_utils.addSystemCommandStep;
const MainModeRunSteps = step_utils.MainModeRunSteps;

const BuildMode = enum {
    ide,
    terminal,
    editor,
};

fn parseBuildMode(raw: []const u8) BuildMode {
    if (std.mem.eql(u8, raw, "ide")) return .ide;
    if (std.mem.eql(u8, raw, "terminal")) return .terminal;
    if (std.mem.eql(u8, raw, "editor")) return .editor;
    std.debug.panic("invalid -Dmode '{s}' (expected: ide, terminal, editor)", .{raw});
}

pub fn build(b: *std.Build) void {
    target_profile.assertPolicy();

    const target = b.standardTargetOptions(.{
        .default_target = if (builtin.os.tag == .windows) .{
            .cpu_arch = .x86_64,
            .os_tag = .windows,
            .abi = .msvc,
        } else .{},
    });
    const optimize = b.standardOptimizeOption(.{});
    const dep_path_raw = b.option(
        []const u8,
        "path",
        "Dependency path: link (default) or zig package manager",
    ) orelse "link";
    const build_mode_raw = b.option(
        []const u8,
        "mode",
        "Build app mode: ide (default), terminal, editor",
    ) orelse "ide";
    const dep_path = parseDependencyPath(dep_path_raw);
    const build_mode = parseBuildMode(build_mode_raw);

    // ─────────────────────────────────────────────────────────────────────────
    // Tree-sitter (for syntax highlighting)
    // ─────────────────────────────────────────────────────────────────────────
    // resolved in dependency_resolver below

    // Platform detection
    const target_os = target.result.os.tag;

    // Renderer backends (wgl/egl) are tracked as TODOs; SDL-managed GL is the
    // only implemented backend today across platforms.
    const default_renderer_backend = "sdl_gl";
    const renderer_backend = b.option(
        []const u8,
        "renderer-backend",
        "Renderer backend (only sdl_gl is implemented; wgl/egl are TODO)",
    ) orelse default_renderer_backend;

    if (!std.mem.eql(u8, renderer_backend, "sdl_gl")) {
        std.debug.panic("renderer backend '{s}' is not implemented (use -Drenderer-backend=sdl_gl)", .{renderer_backend});
    }
    const build_options = b.addOptions();
    build_options.addOption([]const u8, "renderer_backend", renderer_backend);
    build_options.addOption([]const u8, "dependency_path", dep_path_raw);

    // vcpkg support
    //
    // Windows builds currently rely on vcpkg for SDL3 + text stack.
    // This path is target-driven: enabled on Windows, disabled elsewhere.
    const use_vcpkg = (target_os == .windows);
    const vcpkg_root_opt = b.option([]const u8, "vcpkg-root", "Path to vcpkg root") orelse std.process.getEnvVarOwned(b.allocator, "VCPKG_ROOT") catch null;
    const vcpkg_triplet_opt = b.option([]const u8, "vcpkg-triplet", "vcpkg triplet (e.g. x64-windows)") orelse std.process.getEnvVarOwned(b.allocator, "VCPKG_DEFAULT_TRIPLET") catch null;

    const resolved_vcpkg_paths = resolveVcpkgPaths(
        b,
        target,
        target_os,
        vcpkg_root_opt,
        vcpkg_triplet_opt,
    );
    const vcpkg_include = resolved_vcpkg_paths.include;
    const vcpkg_lib = resolved_vcpkg_paths.lib;
    const vcpkg_bin = resolved_vcpkg_paths.bin;

    const deps = dependency_resolver.resolveDependencies(
        b,
        target,
        optimize,
        dep_path,
        use_vcpkg,
    );
    const treesitter = deps.treesitter;
    const sdl_lib = deps.sdl_lib;
    const zlua_module = deps.zlua_module;
    const lua_lib = deps.lua_lib;
    const freetype_lib = deps.freetype_lib;
    const harfbuzz_lib = deps.harfbuzz_lib;
    // ─────────────────────────────────────────────────────────────────────────
    // Main executable
    // ─────────────────────────────────────────────────────────────────────────
    const app_link_ctx = AppLinkContext{
        .dep_path = dep_path,
        .target_os = target_os,
        .use_vcpkg = use_vcpkg,
        .vcpkg_lib = vcpkg_lib,
        .vcpkg_include = vcpkg_include,
        .treesitter = treesitter,
        .sdl_lib = sdl_lib,
        .lua_lib = lua_lib,
        .freetype_lib = freetype_lib,
        .harfbuzz_lib = harfbuzz_lib,
    };

    var main_mode_run_steps: ?MainModeRunSteps = null;
    if (build_mode == .ide) {
        const exe = addAppExecutable(
            b,
            target,
            optimize,
            build_options,
            zlua_module,
            "zide",
            "src/main.zig",
        );
        configureAppExecutable(exe, app_link_ctx, "zide", target_profile.app_main);
        b.installArtifact(exe);
        main_mode_run_steps = addMainModeRunSteps(b, b.getInstallStep(), exe, b.args);
    } else {
        for (mode_specs.focused_apps) |spec| {
            const is_selected = switch (build_mode) {
                .terminal => std.mem.eql(u8, spec.name, "zide-terminal"),
                .editor => std.mem.eql(u8, spec.name, "zide-editor"),
                .ide => false,
            };
            if (!is_selected) continue;
            _ = addFocusedModeExecutable(
                b,
                target,
                optimize,
                build_options,
                zlua_module,
                app_link_ctx,
                spec.name,
                spec.root_source_file,
                spec.profile,
                spec.run_step_name,
                spec.run_description,
                b.args,
            );
        }
    }

    // On Windows, vcpkg typically provides runtime deps as DLLs in
    // <triplet>/bin. Copy them next to the installed exe so that launching
    // `zig-out/bin/zide.exe` works without requiring manual PATH setup.
    if (use_vcpkg and target_os == .windows and vcpkg_bin != null) {
        const dlls = [_][]const u8{
            "SDL3.dll",
            "freetype.dll",
            "harfbuzz.dll",
            "harfbuzz-subset.dll",
            "lua.dll",
            "zlib1.dll",
            "libpng16.dll",
            "bz2.dll",
            "brotlicommon.dll",
            "brotlidec.dll",
            "brotlienc.dll",
        };
        for (dlls) |dll| {
            const src = b.pathJoin(&.{ vcpkg_bin.?, dll });
            if (std.fs.cwd().access(src, .{})) |_| {
                const install_dll = b.addInstallFile(.{ .cwd_relative = src }, b.fmt("bin/{s}", .{dll}));
                b.getInstallStep().dependOn(&install_dll.step);
            } else |_| {
                // Some triplets/configurations may not ship all of these.
            }
        }
    }

    // ─────────────────────────────────────────────────────────────────────────
    // Terminal FFI bridge
    // ─────────────────────────────────────────────────────────────────────────
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
    editor_ffi.linkLibrary(treesitter);
    addVendorAndStb(editor_ffi);
    addTreeSitterIncludes(editor_ffi, treesitter);
    linkFfiPlatform(editor_ffi, target_os);
    const install_editor_ffi = b.addInstallArtifact(editor_ffi, .{});
    const install_editor_ffi_header = b.addInstallFile(b.path("include/zide_editor_ffi.h"), "include/zide_editor_ffi.h");
    const editor_ffi_step = b.step("build-editor-ffi", "Build the editor FFI shared library");
    editor_ffi_step.dependOn(&install_editor_ffi.step);
    editor_ffi_step.dependOn(&install_editor_ffi_header.step);

    // ─────────────────────────────────────────────────────────────────────────
    // Tests
    // ─────────────────────────────────────────────────────────────────────────
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
        "src/tests_main.zig",
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
    if (b.args) |args| {
        terminal_replay.run.addArgs(args);
    }
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
    editor_perf_headless.linkLibrary(treesitter);
    editor_perf_headless.addIncludePath(b.path("vendor"));
    addTreeSitterIncludes(editor_perf_headless, treesitter);
    const editor_perf_headless_run = addRunArtifactStep(
        b,
        editor_perf_headless,
        "perf-editor-headless",
        "Run headless editor large-file performance harness",
    );
    if (b.args) |args| {
        editor_perf_headless_run.run.addArgs(args);
    }
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
    editor_ffi_tests.linkLibrary(treesitter);
    addVendorAndStb(editor_ffi_tests);
    addTreeSitterIncludes(editor_ffi_tests, treesitter);
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

    const build_profile_report_exe = b.addExecutable(.{
        .name = "build-profile-report",
        .root_module = b.createModule(.{
            .root_source_file = b.path("tools/build_profile_report.zig"),
            .target = target,
            .optimize = optimize,
        }),
    });
    build_profile_report_exe.root_module.addAnonymousImport("target_profile", .{
        .root_source_file = b.path("build_utils/target_profile.zig"),
        .target = target,
        .optimize = optimize,
    });
    const build_profile_report_run = b.addRunArtifact(build_profile_report_exe);
    const build_profile_report_step = b.step(
        "report-build-profiles",
        "Report active build dependency profiles",
    );
    build_profile_report_step.dependOn(&build_profile_report_run.step);

    if (build_mode == .ide) {
        _ = addSystemCommandStep(
            b,
            "mode-size-report",
            "Report focused mode binary sizes",
            &.{ "bash", "tools/report_mode_binary_sizes.sh" },
            &.{b.getInstallStep()},
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
                &.{b.getInstallStep()},
            );
        }

        const mode_size_check_step = addSystemCommandStep(
            b,
            "mode-size-check",
            "Check focused binaries are not larger than main binary",
            &.{ "bash", "tools/check_mode_binary_sizes.sh" },
            &.{b.getInstallStep()},
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
                b.getInstallStep(),
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
                b.getInstallStep(),
                mode_size_check_step,
            },
        );

        if (main_mode_run_steps) |steps| {
            _ = addGateStep(
                b,
                "mode-smokes-manual",
                "Run interactive MODE smokes (manual)",
                &.{
                    steps.run,
                    steps.terminal,
                    steps.editor,
                    steps.ide,
                },
            );
        }
    }

    const grammar_update = addLibcExecutable(
        b,
        target,
        optimize,
        "grammar-update",
        "src/tools/grammar_update.zig",
    );
    const grammar_update_run = addRunArtifactStep(
        b,
        grammar_update,
        "grammar-update",
        "Build and install tree-sitter grammar packs",
    );
    if (b.args) |args| {
        grammar_update_run.run.addArgs(args);
    }
    _ = grammar_update_run.step;
}
