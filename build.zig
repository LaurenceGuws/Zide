const std = @import("std");
const builtin = @import("builtin");
const helpers = @import("build_utils/helpers.zig");
const DependencySource = helpers.DependencySource;
const AppLinkContext = helpers.AppLinkContext;
const parseDependencyPath = helpers.parseDependencyPath;
const addTreeSitterIncludes = helpers.addTreeSitterIncludes;
const addVendorAndStb = helpers.addVendorAndStb;
const linkFfiPlatform = helpers.linkFfiPlatform;
const addAppExecutable = helpers.addAppExecutable;
const configureAppExecutable = helpers.configureAppExecutable;
const addRunStepForArtifact = helpers.addRunStepForArtifact;
const addFocusedModeExecutable = helpers.addFocusedModeExecutable;
const addSdlConfiguredTest = helpers.addSdlConfiguredTest;
const addSdlConfiguredExecutable = helpers.addSdlConfiguredExecutable;
const addCheckExecutableStep = helpers.addCheckExecutableStep;
const addRunArtifactStep = helpers.addRunArtifactStep;
const addLibcTest = helpers.addLibcTest;
const addLibcExecutable = helpers.addLibcExecutable;
const addGateStep = helpers.addGateStep;
const resolveVcpkgPaths = helpers.resolveVcpkgPaths;
const addMainModeRunSteps = helpers.addMainModeRunSteps;
const addSystemCommandStep = helpers.addSystemCommandStep;

pub fn build(b: *std.Build) void {
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
    const dep_path = parseDependencyPath(dep_path_raw);

    // ─────────────────────────────────────────────────────────────────────────
    // Tree-sitter (for syntax highlighting)
    // ─────────────────────────────────────────────────────────────────────────
    const tree_sitter_dep = b.dependency("tree_sitter", .{
        .target = target,
        .optimize = optimize,
    });
    const treesitter = tree_sitter_dep.artifact("tree-sitter");

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
    // Default to enabled on Windows so `zig build` produces a runnable build
    // (assuming `vcpkg install` has been run).
    const use_vcpkg_opt = b.option(bool, "use-vcpkg", "Use vcpkg for native dependencies");
    const use_vcpkg = use_vcpkg_opt orelse (target_os == .windows);
    const vcpkg_root_opt = b.option([]const u8, "vcpkg-root", "Path to vcpkg root") orelse std.process.getEnvVarOwned(b.allocator, "VCPKG_ROOT") catch null;
    const vcpkg_triplet_opt = b.option([]const u8, "vcpkg-triplet", "vcpkg triplet (e.g. x64-windows)") orelse std.process.getEnvVarOwned(b.allocator, "VCPKG_DEFAULT_TRIPLET") catch null;

    const vcpkg_paths = resolveVcpkgPaths(
        b,
        target,
        target_os,
        use_vcpkg,
        vcpkg_root_opt,
        vcpkg_triplet_opt,
    );
    const vcpkg_include = vcpkg_paths.include;
    const vcpkg_lib = vcpkg_paths.lib;
    const vcpkg_bin = vcpkg_paths.bin;

    const sdl_dep = b.dependency("sdl", .{
        .target = target,
        .optimize = optimize,
    });
    const sdl_lib = sdl_dep.artifact("SDL3");
    const zlua_dep = b.dependency("zlua", .{
        .target = target,
        .optimize = optimize,
    });
    const zlua_module = zlua_dep.module("zlua");
    const lua_lib = zlua_dep.artifact("lua");
    const freetype_dep = if (dep_path == .zig and !use_vcpkg)
        b.dependency("freetype", .{
            .target = target,
            .optimize = optimize,
            .use_system_zlib = true,
            .enable_brotli = false,
        })
    else
        null;
    const harfbuzz_dep = if (dep_path == .zig and !use_vcpkg)
        b.dependency("harfbuzz", .{
            .target = target,
            .optimize = optimize,
            .enable_freetype = true,
            .freetype_use_system_zlib = true,
            .freetype_enable_brotli = false,
        })
    else
        null;
    const freetype_lib: ?*std.Build.Step.Compile = if (freetype_dep) |dep| dep.artifact("freetype") else null;
    const harfbuzz_lib: ?*std.Build.Step.Compile = if (harfbuzz_dep) |dep| dep.artifact("harfbuzz") else null;
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

    const exe = addAppExecutable(
        b,
        target,
        optimize,
        build_options,
        zlua_module,
        "zide",
        "src/main.zig",
    );
    configureAppExecutable(exe, app_link_ctx, "zide", true);

    b.installArtifact(exe);

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
    // Run step
    // ─────────────────────────────────────────────────────────────────────────
    const main_mode_run_steps = addMainModeRunSteps(b, b.getInstallStep(), exe, b.args);

    // Focused app entrypoints (same app graph for now, fixed mode roots).
    _ = addFocusedModeExecutable(
        b,
        target,
        optimize,
        build_options,
        zlua_module,
        app_link_ctx,
        "zide-terminal",
        "src/entry_terminal.zig",
        false,
        "run-terminal",
        "Run terminal-only app entry",
        b.args,
    );

    _ = addFocusedModeExecutable(
        b,
        target,
        optimize,
        build_options,
        zlua_module,
        app_link_ctx,
        "zide-editor",
        "src/entry_editor.zig",
        true,
        "run-editor",
        "Run editor-only app entry",
        b.args,
    );

    _ = addFocusedModeExecutable(
        b,
        target,
        optimize,
        build_options,
        zlua_module,
        app_link_ctx,
        "zide-ide",
        "src/entry_ide.zig",
        true,
        "run-ide",
        "Run ide-only app entry",
        b.args,
    );

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
        true,
        false,
        false,
        false,
    );

    const test_step = addRunArtifactStep(b, unit_tests, "test", "Run unit tests").step;

    const editor_tests = addSdlConfiguredTest(
        b,
        target,
        optimize,
        "src/tests_main.zig",
        build_options,
        app_link_ctx,
        true,
        true,
        true,
        false,
    );

    _ = addRunArtifactStep(b, editor_tests, "test-editor", "Run editor-specific tests").step;

    const config_tests = addSdlConfiguredTest(
        b,
        target,
        optimize,
        "src/config_tests.zig",
        null,
        app_link_ctx,
        false,
        true,
        true,
        true,
    );

    _ = addRunArtifactStep(b, config_tests, "test-config", "Run Lua config parser/merge tests").step;

    const terminal_replay_exe = addSdlConfiguredExecutable(
        b,
        target,
        optimize,
        "terminal-replay",
        "src/terminal_replay_main.zig",
        app_link_ctx,
        false,
        false,
        false,
        false,
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

    const terminal_kitty_query_tests = addSdlConfiguredTest(
        b,
        target,
        optimize,
        "src/terminal_kitty_query_parse_tests.zig",
        null,
        app_link_ctx,
        false,
        false,
        false,
        false,
    );
    _ = addRunArtifactStep(
        b,
        terminal_kitty_query_tests,
        "test-terminal-kitty-query-parse",
        "Run project-integrated kitty query parse-path tests",
    ).step;

    const terminal_focus_reporting_tests = addSdlConfiguredTest(
        b,
        target,
        optimize,
        "src/terminal_focus_reporting_tests.zig",
        null,
        app_link_ctx,
        false,
        false,
        false,
        false,
    );
    _ = addRunArtifactStep(
        b,
        terminal_focus_reporting_tests,
        "test-terminal-focus-reporting",
        "Run project-integrated terminal focus reporting tests",
    ).step;

    const terminal_workspace_tests = addSdlConfiguredTest(
        b,
        target,
        optimize,
        "src/terminal_workspace_tests.zig",
        null,
        app_link_ctx,
        false,
        false,
        false,
        false,
    );
    _ = addRunArtifactStep(
        b,
        terminal_workspace_tests,
        "test-terminal-workspace",
        "Run terminal workspace lifecycle tests",
    ).step;

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
            b.getInstallStep(),
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
