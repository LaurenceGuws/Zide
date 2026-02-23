const std = @import("std");
const builtin = @import("builtin");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{
        .default_target = if (builtin.os.tag == .windows) .{
            .cpu_arch = .x86_64,
            .os_tag = .windows,
            .abi = .msvc,
        } else .{},
    });
    const optimize = b.standardOptimizeOption(.{});

    // ─────────────────────────────────────────────────────────────────────────
    // Tree-sitter (for syntax highlighting)
    // ─────────────────────────────────────────────────────────────────────────
    const treesitter = b.addLibrary(.{
        .name = "tree-sitter",
        .linkage = .static,
        .root_module = b.createModule(.{
            .target = target,
            .optimize = optimize,
            .link_libc = true,
        }),
    });
    treesitter.addCSourceFile(.{
        .file = b.path("vendor/tree-sitter/lib/src/lib.c"),
        .flags = &.{
            "-std=c99",
            "-D_POSIX_C_SOURCE=200809L",
            "-D_DEFAULT_SOURCE",
        },
    });
    treesitter.addIncludePath(b.path("vendor/tree-sitter/lib/include"));
    treesitter.addIncludePath(b.path("vendor/tree-sitter/lib/src"));

    // Tree-sitter Zig parser
    const ts_zig = b.addLibrary(.{
        .name = "tree-sitter-zig",
        .linkage = .static,
        .root_module = b.createModule(.{
            .target = target,
            .optimize = optimize,
            .link_libc = true,
        }),
    });
    ts_zig.addCSourceFile(.{
        .file = b.path("vendor/tree-sitter-zig/src/parser.c"),
        .flags = &.{"-std=c99"},
    });
    ts_zig.addIncludePath(b.path("vendor/tree-sitter/lib/include"));
    ts_zig.addIncludePath(b.path("vendor/tree-sitter-zig/src"));

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

    // vcpkg support
    //
    // Windows builds currently rely on vcpkg for SDL3 + text stack.
    // Default to enabled on Windows so `zig build` produces a runnable build
    // (assuming `vcpkg install` has been run).
    const use_vcpkg_opt = b.option(bool, "use-vcpkg", "Use vcpkg for native dependencies");
    const use_vcpkg = use_vcpkg_opt orelse (target_os == .windows);
    const vcpkg_root_opt = b.option([]const u8, "vcpkg-root", "Path to vcpkg root") orelse std.process.getEnvVarOwned(b.allocator, "VCPKG_ROOT") catch null;
    const vcpkg_triplet_opt = b.option([]const u8, "vcpkg-triplet", "vcpkg triplet (e.g. x64-windows)") orelse std.process.getEnvVarOwned(b.allocator, "VCPKG_DEFAULT_TRIPLET") catch null;

    // vcpkg can install dependencies in two common layouts:
    // - Classic: <VCPKG_ROOT>/installed/<triplet>/{include,lib,bin,...}
    // - Manifest (recommended): <project>/vcpkg_installed/<triplet>/{include,lib,bin,...}
    //
    // Prefer classic if it exists (and a root was provided), otherwise fall back
    // to manifest layout.
    var vcpkg_include: ?[]const u8 = null;
    var vcpkg_lib: ?[]const u8 = null;
    var vcpkg_bin: ?[]const u8 = null;
    if (use_vcpkg) {
        if (target_os == .windows and target.result.cpu.arch != .x86_64) {
            @panic("Windows builds are x86_64-only.");
        }
        const vcpkg_triplet = vcpkg_triplet_opt orelse switch (target_os) {
            .windows => "x64-windows",
            else => "x64-linux",
        };

        const manifest_lib = b.pathJoin(&.{ "vcpkg_installed", vcpkg_triplet, "lib" });
        const manifest_include = b.pathJoin(&.{ "vcpkg_installed", vcpkg_triplet, "include" });
        const manifest_bin = b.pathJoin(&.{ "vcpkg_installed", vcpkg_triplet, "bin" });

        if (vcpkg_root_opt) |vcpkg_root| {
            const classic_lib = b.pathJoin(&.{ vcpkg_root, "installed", vcpkg_triplet, "lib" });
            const classic_include = b.pathJoin(&.{ vcpkg_root, "installed", vcpkg_triplet, "include" });
            const classic_bin = b.pathJoin(&.{ vcpkg_root, "installed", vcpkg_triplet, "bin" });

            if (std.fs.cwd().access(classic_lib, .{})) |_| {
                vcpkg_lib = classic_lib;
                vcpkg_include = classic_include;
                vcpkg_bin = classic_bin;
            } else |_| {
                // Fall back to manifest layout if present.
                if (std.fs.cwd().access(manifest_lib, .{})) |_| {
                    vcpkg_lib = manifest_lib;
                    vcpkg_include = manifest_include;
                    vcpkg_bin = manifest_bin;
                } else |_| {
                    @panic("use-vcpkg enabled, but could not find vcpkg libraries. Expected either <VCPKG_ROOT>/installed/<triplet>/lib or ./vcpkg_installed/<triplet>/lib");
                }
            }
        } else {
            if (std.fs.cwd().access(manifest_lib, .{})) |_| {
                vcpkg_lib = manifest_lib;
                vcpkg_include = manifest_include;
                vcpkg_bin = manifest_bin;
            } else |_| {
                @panic("use-vcpkg enabled, but vcpkg deps were not found. On Windows, run `vcpkg install --triplet x64-windows` in the repo root (manifest mode), or set VCPKG_ROOT / pass --vcpkg-root for classic mode.");
            }
        }
    } else if (target_os == .windows) {
        @panic("Windows builds require vcpkg. Install deps via manifest mode (./vcpkg_installed) or set VCPKG_ROOT + VCPKG_DEFAULT_TRIPLET, then re-run.");
    }

    // ─────────────────────────────────────────────────────────────────────────
    // Main executable
    // ─────────────────────────────────────────────────────────────────────────
    const exe = b.addExecutable(.{
        .name = "zide",
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/main.zig"),
            .target = target,
            .optimize = optimize,
            .link_libc = true,
        }),
    });
    exe.root_module.addOptions("build_options", build_options);

    // Link C libraries
    exe.linkLibrary(treesitter);
    exe.linkLibrary(ts_zig);
    if (use_vcpkg) {
        exe.addLibraryPath(.{ .cwd_relative = vcpkg_lib.? });
        exe.addIncludePath(.{ .cwd_relative = vcpkg_include.? });
        exe.linkSystemLibrary("freetype");
        exe.linkSystemLibrary("harfbuzz");
        exe.linkSystemLibrary("lua");
        exe.linkSystemLibrary("SDL3");
    } else {
        exe.linkSystemLibrary("freetype");
        exe.linkSystemLibrary("harfbuzz");
        exe.linkSystemLibrary("lua");
        exe.linkSystemLibrary("SDL3");
    }
    if (target_os == .linux) {
        exe.linkSystemLibrary("fontconfig");
    }

    // Include paths for @cImport
    exe.addIncludePath(b.path("vendor"));
    exe.addIncludePath(b.path("vendor/tree-sitter/lib/include"));
    if (!use_vcpkg) {
        exe.addIncludePath(.{ .cwd_relative = "/usr/include/freetype2" });
        exe.addIncludePath(.{ .cwd_relative = "/usr/include/harfbuzz" });
        exe.addIncludePath(.{ .cwd_relative = "/usr/include/lua5.4" });
        if (target_os == .linux) {
            exe.addIncludePath(.{ .cwd_relative = "/usr/include/SDL3" });
        }
        if (target_os == .linux) {
            exe.addIncludePath(.{ .cwd_relative = "/usr/include/fontconfig" });
        }
    }

    // Platform-specific linking for the exe
    if (target_os == .windows) {
        exe.linkSystemLibrary("opengl32");
        exe.linkSystemLibrary("gdi32");
        exe.linkSystemLibrary("comdlg32");
        exe.linkSystemLibrary("dwrite");
        exe.linkSystemLibrary("ole32");
        exe.linkSystemLibrary("winmm");
        exe.linkSystemLibrary("user32");
        exe.linkSystemLibrary("shell32");
    } else if (target_os == .macos) {
        exe.linkFramework("OpenGL");
        exe.linkFramework("Cocoa");
        exe.linkFramework("IOKit");
        exe.linkFramework("CoreVideo");
    } else {
        exe.linkSystemLibrary("GL");
        exe.linkSystemLibrary("m");
        exe.linkSystemLibrary("pthread");
        exe.linkSystemLibrary("dl");
        exe.linkSystemLibrary("rt");
    }

    exe.addCSourceFile(.{
        .file = b.path("src/c/stb_image.c"),
        .flags = &.{"-std=c99"},
    });

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
    const run_cmd = b.addRunArtifact(exe);
    run_cmd.step.dependOn(b.getInstallStep());
    if (b.args) |args| {
        run_cmd.addArgs(args);
    }

    const run_step = b.step("run", "Run the IDE");
    run_step.dependOn(&run_cmd.step);

    // ─────────────────────────────────────────────────────────────────────────
    // Tests
    // ─────────────────────────────────────────────────────────────────────────
    const unit_tests = b.addTest(.{
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/main.zig"),
            .target = target,
            .optimize = optimize,
            .link_libc = true,
        }),
    });
    unit_tests.root_module.addOptions("build_options", build_options);
    if (use_vcpkg) {
        unit_tests.addLibraryPath(.{ .cwd_relative = vcpkg_lib.? });
        unit_tests.addIncludePath(.{ .cwd_relative = vcpkg_include.? });
    }
    unit_tests.linkSystemLibrary("SDL3");
    if (target_os == .linux) {
        unit_tests.linkSystemLibrary("GL");
    } else if (target_os == .windows) {
        unit_tests.linkSystemLibrary("opengl32");
    } else if (target_os == .macos) {
        unit_tests.linkFramework("OpenGL");
    }
    unit_tests.linkLibrary(treesitter);
    unit_tests.linkLibrary(ts_zig);
    unit_tests.addIncludePath(b.path("vendor"));
    unit_tests.addIncludePath(b.path("vendor/tree-sitter/lib/include"));
    unit_tests.addIncludePath(b.path("vendor/tree-sitter-zig/src"));
    if (!use_vcpkg and target_os == .linux) {
        unit_tests.addIncludePath(.{ .cwd_relative = "/usr/include/SDL3" });
    }
    unit_tests.addCSourceFile(.{
        .file = b.path("src/c/stb_image.c"),
        .flags = &.{"-std=c99"},
    });

    const run_tests = b.addRunArtifact(unit_tests);
    const test_step = b.step("test", "Run unit tests");
    test_step.dependOn(&run_tests.step);

    const editor_tests_root = b.createModule(.{
        .root_source_file = b.path("src/tests_main.zig"),
        .target = target,
        .optimize = optimize,
        .link_libc = true,
    });
    const editor_tests = b.addTest(.{
        .root_module = editor_tests_root,
    });
    editor_tests_root.addOptions("build_options", build_options);
    if (use_vcpkg) {
        editor_tests.addLibraryPath(.{ .cwd_relative = vcpkg_lib.? });
        editor_tests.addIncludePath(.{ .cwd_relative = vcpkg_include.? });
    }
    editor_tests.linkSystemLibrary("SDL3");
    if (target_os == .linux) {
        editor_tests.linkSystemLibrary("GL");
    } else if (target_os == .windows) {
        editor_tests.linkSystemLibrary("opengl32");
    } else if (target_os == .macos) {
        editor_tests.linkFramework("OpenGL");
    }
    editor_tests.linkLibrary(treesitter);
    editor_tests.linkLibrary(ts_zig);
    editor_tests.addIncludePath(b.path("vendor"));
    editor_tests.addIncludePath(b.path("vendor/tree-sitter/lib/include"));
    editor_tests.addIncludePath(b.path("vendor/tree-sitter-zig/src"));
    if (!use_vcpkg) {
        editor_tests.addIncludePath(.{ .cwd_relative = "/usr/include/freetype2" });
        editor_tests.addIncludePath(.{ .cwd_relative = "/usr/include/harfbuzz" });
        editor_tests.addIncludePath(.{ .cwd_relative = "/usr/include/lua5.4" });
        if (target_os == .linux) {
            editor_tests.addIncludePath(.{ .cwd_relative = "/usr/include/SDL3" });
        }
        if (target_os == .linux) {
            editor_tests.addIncludePath(.{ .cwd_relative = "/usr/include/fontconfig" });
        }
    }
    editor_tests.addCSourceFile(.{
        .file = b.path("src/c/stb_image.c"),
        .flags = &.{"-std=c99"},
    });

    const run_editor_tests = b.addRunArtifact(editor_tests);
    const editor_test_step = b.step("test-editor", "Run editor-specific tests");
    editor_test_step.dependOn(&run_editor_tests.step);

    const terminal_replay_exe = b.addExecutable(.{
        .name = "terminal-replay",
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/terminal_replay_main.zig"),
            .target = target,
            .optimize = optimize,
            .link_libc = true,
        }),
    });
    terminal_replay_exe.linkSystemLibrary("SDL3");
    if (target_os == .linux) {
        terminal_replay_exe.linkSystemLibrary("GL");
    } else if (target_os == .windows) {
        terminal_replay_exe.linkSystemLibrary("opengl32");
    } else if (target_os == .macos) {
        terminal_replay_exe.linkFramework("OpenGL");
    }
    terminal_replay_exe.addIncludePath(b.path("vendor"));
    if (target_os == .linux) {
        terminal_replay_exe.addIncludePath(.{ .cwd_relative = "/usr/include/SDL3" });
    }
    terminal_replay_exe.addCSourceFile(.{
        .file = b.path("src/c/stb_image.c"),
        .flags = &.{"-std=c99"},
    });

    const run_terminal_replay = b.addRunArtifact(terminal_replay_exe);
    if (b.args) |args| {
        run_terminal_replay.addArgs(args);
    }
    const terminal_replay_step = b.step("test-terminal-replay", "Run terminal replay harness");
    terminal_replay_step.dependOn(&run_terminal_replay.step);

    const terminal_kitty_query_tests = b.addTest(.{
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/terminal_kitty_query_parse_tests.zig"),
            .target = target,
            .optimize = optimize,
            .link_libc = true,
        }),
    });
    terminal_kitty_query_tests.linkSystemLibrary("SDL3");
    if (target_os == .linux) {
        terminal_kitty_query_tests.linkSystemLibrary("GL");
    } else if (target_os == .windows) {
        terminal_kitty_query_tests.linkSystemLibrary("opengl32");
    } else if (target_os == .macos) {
        terminal_kitty_query_tests.linkFramework("OpenGL");
    }
    terminal_kitty_query_tests.addIncludePath(b.path("vendor"));
    if (target_os == .linux) {
        terminal_kitty_query_tests.addIncludePath(.{ .cwd_relative = "/usr/include/SDL3" });
    }
    terminal_kitty_query_tests.addCSourceFile(.{
        .file = b.path("src/c/stb_image.c"),
        .flags = &.{"-std=c99"},
    });
    const run_terminal_kitty_query_tests = b.addRunArtifact(terminal_kitty_query_tests);
    const terminal_kitty_query_tests_step = b.step(
        "test-terminal-kitty-query-parse",
        "Run project-integrated kitty query parse-path tests",
    );
    terminal_kitty_query_tests_step.dependOn(&run_terminal_kitty_query_tests.step);

    const terminal_import_check = b.addExecutable(.{
        .name = "terminal-import-check",
        .root_module = b.createModule(.{
            .root_source_file = b.path("tools/terminal_import_check.zig"),
            .target = target,
            .optimize = optimize,
        }),
    });
    const run_terminal_import_check = b.addRunArtifact(terminal_import_check);
    const terminal_import_check_step = b.step("check-terminal-imports", "Check terminal module import layering");
    terminal_import_check_step.dependOn(&run_terminal_import_check.step);

    const editor_import_check = b.addExecutable(.{
        .name = "editor-import-check",
        .root_module = b.createModule(.{
            .root_source_file = b.path("tools/editor_import_check.zig"),
            .target = target,
            .optimize = optimize,
        }),
    });
    const run_editor_import_check = b.addRunArtifact(editor_import_check);
    const editor_import_check_step = b.step("check-editor-imports", "Check editor module import layering");
    editor_import_check_step.dependOn(&run_editor_import_check.step);

    const app_import_check = b.addExecutable(.{
        .name = "app-import-check",
        .root_module = b.createModule(.{
            .root_source_file = b.path("tools/app_import_check.zig"),
            .target = target,
            .optimize = optimize,
        }),
    });
    const run_app_import_check = b.addRunArtifact(app_import_check);
    const app_import_check_step = b.step("check-app-imports", "Check app-level import layering");
    app_import_check_step.dependOn(&run_app_import_check.step);

    const run_input_import_check = b.addRunArtifact(app_import_check);
    const input_import_check_step = b.step("check-input-imports", "Check input module import layering");
    input_import_check_step.dependOn(&run_input_import_check.step);

    const grammar_update = b.addExecutable(.{
        .name = "grammar-update",
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/tools/grammar_update.zig"),
            .target = target,
            .optimize = optimize,
            .link_libc = true,
        }),
    });
    const run_grammar_update = b.addRunArtifact(grammar_update);
    if (b.args) |args| {
        run_grammar_update.addArgs(args);
    }
    const grammar_update_step = b.step("grammar-update", "Build and install tree-sitter grammar packs");
    grammar_update_step.dependOn(&run_grammar_update.step);
}
