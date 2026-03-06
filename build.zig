const std = @import("std");
const builtin = @import("builtin");

const DependencySource = enum {
    link,
    zig,
};

fn parseDependencyPath(raw: []const u8) DependencySource {
    if (std.mem.eql(u8, raw, "link")) return .link;
    if (std.mem.eql(u8, raw, "zig")) return .zig;
    std.debug.panic("invalid -Dpath='{s}' (expected 'link' or 'zig')", .{raw});
}

fn linkSdl3(step: *std.Build.Step.Compile, dep_path: DependencySource, sdl_lib: ?*std.Build.Step.Compile) void {
    _ = dep_path;
    step.linkLibrary(sdl_lib.?);
}

fn linkLua(step: *std.Build.Step.Compile, dep_path: DependencySource, lua_lib: ?*std.Build.Step.Compile) void {
    _ = dep_path;
    step.linkLibrary(lua_lib.?);
}

fn addLinuxSystemSdlInclude(step: *std.Build.Step.Compile, target_os: std.Target.Os.Tag, dep_path: DependencySource) void {
    _ = step;
    _ = target_os;
    _ = dep_path;
}

fn addLuaIncludes(step: *std.Build.Step.Compile, dep_path: DependencySource, lua_lib: ?*std.Build.Step.Compile) void {
    _ = dep_path;
    step.addIncludePath(lua_lib.?.getEmittedIncludeTree());
}

fn addTreeSitterIncludes(step: *std.Build.Step.Compile, treesitter_lib: *std.Build.Step.Compile) void {
    step.addIncludePath(treesitter_lib.getEmittedIncludeTree());
}

fn linkTextStack(
    step: *std.Build.Step.Compile,
    dep_path: DependencySource,
    freetype_lib: ?*std.Build.Step.Compile,
    harfbuzz_lib: ?*std.Build.Step.Compile,
) void {
    switch (dep_path) {
        .link => {
            step.linkSystemLibrary("freetype");
            step.linkSystemLibrary("harfbuzz");
        },
        .zig => {
            if (freetype_lib) |lib| {
                step.linkLibrary(lib);
            } else {
                step.linkSystemLibrary("freetype");
            }
            if (harfbuzz_lib) |lib| {
                step.linkLibrary(lib);
            } else {
                step.linkSystemLibrary("harfbuzz");
            }
            step.linkSystemLibrary("z");
        },
    }
}

fn addTextStackIncludes(
    step: *std.Build.Step.Compile,
    use_vcpkg: bool,
    target_os: std.Target.Os.Tag,
    dep_path: DependencySource,
    freetype_lib: ?*std.Build.Step.Compile,
    harfbuzz_lib: ?*std.Build.Step.Compile,
) void {
    if (use_vcpkg) return;
    switch (dep_path) {
        .link => {
            step.addIncludePath(.{ .cwd_relative = "/usr/include/freetype2" });
            step.addIncludePath(.{ .cwd_relative = "/usr/include/harfbuzz" });
        },
        .zig => {
            if (freetype_lib) |lib| {
                step.addIncludePath(lib.getEmittedIncludeTree());
            } else {
                step.addIncludePath(.{ .cwd_relative = "/usr/include/freetype2" });
            }
            if (harfbuzz_lib) |lib| {
                step.addIncludePath(lib.getEmittedIncludeTree());
            } else {
                step.addIncludePath(.{ .cwd_relative = "/usr/include/harfbuzz" });
            }
        },
    }
    if (target_os == .linux) {
        step.addIncludePath(.{ .cwd_relative = "/usr/include/fontconfig" });
    }
}

const AppLinkContext = struct {
    dep_path: DependencySource,
    target_os: std.Target.Os.Tag,
    use_vcpkg: bool,
    vcpkg_lib: ?[]const u8,
    vcpkg_include: ?[]const u8,
    treesitter: *std.Build.Step.Compile,
    sdl_lib: ?*std.Build.Step.Compile,
    lua_lib: ?*std.Build.Step.Compile,
    freetype_lib: ?*std.Build.Step.Compile,
    harfbuzz_lib: ?*std.Build.Step.Compile,
};

fn addAppExecutable(
    b: *std.Build,
    target: std.Build.ResolvedTarget,
    optimize: std.builtin.OptimizeMode,
    build_options: *std.Build.Step.Options,
    zlua_module: *std.Build.Module,
    name: []const u8,
    root_source_file: []const u8,
) *std.Build.Step.Compile {
    const exe = b.addExecutable(.{
        .name = name,
        .root_module = b.createModule(.{
            .root_source_file = b.path(root_source_file),
            .target = target,
            .optimize = optimize,
            .link_libc = true,
        }),
    });
    exe.root_module.addOptions("build_options", build_options);
    exe.root_module.addImport("zlua", zlua_module);
    return exe;
}

fn linkCommonPlatformGraphics(exe: *std.Build.Step.Compile, target_os: std.Target.Os.Tag) void {
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
}

fn configureAppExecutable(exe: *std.Build.Step.Compile, ctx: AppLinkContext, include_treesitter: bool) void {
    if (include_treesitter) {
        exe.linkLibrary(ctx.treesitter);
    }
    if (ctx.use_vcpkg) {
        exe.addLibraryPath(.{ .cwd_relative = ctx.vcpkg_lib.? });
        exe.addIncludePath(.{ .cwd_relative = ctx.vcpkg_include.? });
        linkTextStack(exe, ctx.dep_path, ctx.freetype_lib, ctx.harfbuzz_lib);
        linkLua(exe, ctx.dep_path, ctx.lua_lib);
        linkSdl3(exe, ctx.dep_path, ctx.sdl_lib);
    } else {
        linkTextStack(exe, ctx.dep_path, ctx.freetype_lib, ctx.harfbuzz_lib);
        linkLua(exe, ctx.dep_path, ctx.lua_lib);
        linkSdl3(exe, ctx.dep_path, ctx.sdl_lib);
    }
    if (ctx.target_os == .linux) {
        exe.linkSystemLibrary("fontconfig");
    }
    exe.addIncludePath(.{ .cwd_relative = "vendor" });
    if (include_treesitter) {
        addTreeSitterIncludes(exe, ctx.treesitter);
    }
    if (!ctx.use_vcpkg) {
        addTextStackIncludes(exe, ctx.use_vcpkg, ctx.target_os, ctx.dep_path, ctx.freetype_lib, ctx.harfbuzz_lib);
        addLuaIncludes(exe, ctx.dep_path, ctx.lua_lib);
        if (ctx.target_os == .linux) {
            addLinuxSystemSdlInclude(exe, ctx.target_os, ctx.dep_path);
        }
    }
    linkCommonPlatformGraphics(exe, ctx.target_os);
    exe.addCSourceFile(.{
        .file = .{ .cwd_relative = "src/c/stb_image.c" },
        .flags = &.{"-std=c99"},
    });
}

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
    configureAppExecutable(exe, app_link_ctx, true);

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

    const run_mode_terminal_cmd = b.addRunArtifact(exe);
    run_mode_terminal_cmd.step.dependOn(b.getInstallStep());
    run_mode_terminal_cmd.addArgs(&.{ "--mode", "terminal" });
    const run_mode_terminal_step = b.step("run-mode-terminal", "Run main entry in --mode terminal");
    run_mode_terminal_step.dependOn(&run_mode_terminal_cmd.step);

    const run_mode_editor_cmd = b.addRunArtifact(exe);
    run_mode_editor_cmd.step.dependOn(b.getInstallStep());
    run_mode_editor_cmd.addArgs(&.{ "--mode", "editor" });
    const run_mode_editor_step = b.step("run-mode-editor", "Run main entry in --mode editor");
    run_mode_editor_step.dependOn(&run_mode_editor_cmd.step);

    const run_mode_ide_cmd = b.addRunArtifact(exe);
    run_mode_ide_cmd.step.dependOn(b.getInstallStep());
    run_mode_ide_cmd.addArgs(&.{ "--mode", "ide" });
    const run_mode_ide_step = b.step("run-mode-ide", "Run main entry in --mode ide");
    run_mode_ide_step.dependOn(&run_mode_ide_cmd.step);

    // Focused app entrypoints (same app graph for now, fixed mode roots).
    const exe_terminal = addAppExecutable(
        b,
        target,
        optimize,
        build_options,
        zlua_module,
        "zide-terminal",
        "src/entry_terminal.zig",
    );
    configureAppExecutable(exe_terminal, app_link_ctx, false);
    b.installArtifact(exe_terminal);
    const run_terminal_cmd = b.addRunArtifact(exe_terminal);
    run_terminal_cmd.step.dependOn(b.getInstallStep());
    if (b.args) |args| {
        run_terminal_cmd.addArgs(args);
    }
    const run_terminal_step = b.step("run-terminal", "Run terminal-only app entry");
    run_terminal_step.dependOn(&run_terminal_cmd.step);

    const exe_editor = addAppExecutable(
        b,
        target,
        optimize,
        build_options,
        zlua_module,
        "zide-editor",
        "src/entry_editor.zig",
    );
    configureAppExecutable(exe_editor, app_link_ctx, true);
    b.installArtifact(exe_editor);
    const run_editor_cmd = b.addRunArtifact(exe_editor);
    run_editor_cmd.step.dependOn(b.getInstallStep());
    if (b.args) |args| {
        run_editor_cmd.addArgs(args);
    }
    const run_editor_step = b.step("run-editor", "Run editor-only app entry");
    run_editor_step.dependOn(&run_editor_cmd.step);

    const exe_ide = addAppExecutable(
        b,
        target,
        optimize,
        build_options,
        zlua_module,
        "zide-ide",
        "src/entry_ide.zig",
    );
    configureAppExecutable(exe_ide, app_link_ctx, true);
    b.installArtifact(exe_ide);
    const run_ide_cmd = b.addRunArtifact(exe_ide);
    run_ide_cmd.step.dependOn(b.getInstallStep());
    if (b.args) |args| {
        run_ide_cmd.addArgs(args);
    }
    const run_ide_step = b.step("run-ide", "Run ide-only app entry");
    run_ide_step.dependOn(&run_ide_cmd.step);

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
    terminal_ffi.addIncludePath(b.path("vendor"));
    terminal_ffi.addCSourceFile(.{
        .file = b.path("src/c/stb_image.c"),
        .flags = &.{"-std=c99"},
    });
    if (target_os == .windows) {
        terminal_ffi.linkSystemLibrary("user32");
        terminal_ffi.linkSystemLibrary("shell32");
    } else if (target_os == .macos) {
        terminal_ffi.linkFramework("Cocoa");
    } else {
        terminal_ffi.linkSystemLibrary("m");
        terminal_ffi.linkSystemLibrary("pthread");
        terminal_ffi.linkSystemLibrary("dl");
        terminal_ffi.linkSystemLibrary("rt");
    }
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
    editor_ffi.addIncludePath(b.path("vendor"));
    addTreeSitterIncludes(editor_ffi, treesitter);
    if (target_os == .windows) {
        editor_ffi.linkSystemLibrary("user32");
        editor_ffi.linkSystemLibrary("shell32");
    } else if (target_os == .macos) {
        editor_ffi.linkFramework("Cocoa");
    } else {
        editor_ffi.linkSystemLibrary("m");
        editor_ffi.linkSystemLibrary("pthread");
        editor_ffi.linkSystemLibrary("dl");
        editor_ffi.linkSystemLibrary("rt");
    }
    const install_editor_ffi = b.addInstallArtifact(editor_ffi, .{});
    const install_editor_ffi_header = b.addInstallFile(b.path("include/zide_editor_ffi.h"), "include/zide_editor_ffi.h");
    const editor_ffi_step = b.step("build-editor-ffi", "Build the editor FFI shared library");
    editor_ffi_step.dependOn(&install_editor_ffi.step);
    editor_ffi_step.dependOn(&install_editor_ffi_header.step);

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
    linkSdl3(unit_tests, dep_path, sdl_lib);
    if (target_os == .linux) {
        unit_tests.linkSystemLibrary("GL");
    } else if (target_os == .windows) {
        unit_tests.linkSystemLibrary("opengl32");
    } else if (target_os == .macos) {
        unit_tests.linkFramework("OpenGL");
    }
    unit_tests.linkLibrary(treesitter);
    unit_tests.addIncludePath(b.path("vendor"));
    addTreeSitterIncludes(unit_tests, treesitter);
    if (!use_vcpkg) {
        addLinuxSystemSdlInclude(unit_tests, target_os, dep_path);
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
    linkSdl3(editor_tests, dep_path, sdl_lib);
    if (target_os == .linux) {
        editor_tests.linkSystemLibrary("GL");
    } else if (target_os == .windows) {
        editor_tests.linkSystemLibrary("opengl32");
    } else if (target_os == .macos) {
        editor_tests.linkFramework("OpenGL");
    }
    editor_tests.linkLibrary(treesitter);
    editor_tests.addIncludePath(b.path("vendor"));
    addTreeSitterIncludes(editor_tests, treesitter);
    if (!use_vcpkg) {
        addTextStackIncludes(editor_tests, use_vcpkg, target_os, dep_path, freetype_lib, harfbuzz_lib);
        addLuaIncludes(editor_tests, dep_path, lua_lib);
        addLinuxSystemSdlInclude(editor_tests, target_os, dep_path);
    }
    editor_tests.addCSourceFile(.{
        .file = b.path("src/c/stb_image.c"),
        .flags = &.{"-std=c99"},
    });

    const run_editor_tests = b.addRunArtifact(editor_tests);
    const editor_test_step = b.step("test-editor", "Run editor-specific tests");
    editor_test_step.dependOn(&run_editor_tests.step);

    const config_tests = b.addTest(.{
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/config_tests.zig"),
            .target = target,
            .optimize = optimize,
            .link_libc = true,
        }),
    });
    if (use_vcpkg) {
        config_tests.addLibraryPath(.{ .cwd_relative = vcpkg_lib.? });
        config_tests.addIncludePath(.{ .cwd_relative = vcpkg_include.? });
    }
    linkSdl3(config_tests, dep_path, sdl_lib);
    linkTextStack(config_tests, dep_path, freetype_lib, harfbuzz_lib);
    linkLua(config_tests, dep_path, lua_lib);
    if (target_os == .linux) {
        config_tests.linkSystemLibrary("GL");
        config_tests.linkSystemLibrary("fontconfig");
    } else if (target_os == .windows) {
        config_tests.linkSystemLibrary("opengl32");
    } else if (target_os == .macos) {
        config_tests.linkFramework("OpenGL");
    }
    config_tests.addIncludePath(b.path("vendor"));
    if (!use_vcpkg) {
        addTextStackIncludes(config_tests, use_vcpkg, target_os, dep_path, freetype_lib, harfbuzz_lib);
        addLuaIncludes(config_tests, dep_path, lua_lib);
        if (target_os == .linux) {
            addLinuxSystemSdlInclude(config_tests, target_os, dep_path);
        }
    }
    config_tests.addCSourceFile(.{
        .file = b.path("src/c/stb_image.c"),
        .flags = &.{"-std=c99"},
    });

    const run_config_tests = b.addRunArtifact(config_tests);
    const config_test_step = b.step("test-config", "Run Lua config parser/merge tests");
    config_test_step.dependOn(&run_config_tests.step);

    const terminal_replay_exe = b.addExecutable(.{
        .name = "terminal-replay",
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/terminal_replay_main.zig"),
            .target = target,
            .optimize = optimize,
            .link_libc = true,
        }),
    });
    linkSdl3(terminal_replay_exe, dep_path, sdl_lib);
    if (target_os == .linux) {
        terminal_replay_exe.linkSystemLibrary("GL");
    } else if (target_os == .windows) {
        terminal_replay_exe.linkSystemLibrary("opengl32");
    } else if (target_os == .macos) {
        terminal_replay_exe.linkFramework("OpenGL");
    }
    terminal_replay_exe.addIncludePath(b.path("vendor"));
    addLinuxSystemSdlInclude(terminal_replay_exe, target_os, dep_path);
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

    const run_terminal_replay_all = b.addRunArtifact(terminal_replay_exe);
    run_terminal_replay_all.addArg("--all");
    const terminal_replay_all_step = b.step("test-terminal-replay-all", "Run terminal replay harness across all fixtures");
    terminal_replay_all_step.dependOn(&run_terminal_replay_all.step);

    const editor_perf_headless = b.addExecutable(.{
        .name = "editor-perf-headless",
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/editor_perf_main.zig"),
            .target = target,
            .optimize = optimize,
            .link_libc = true,
        }),
    });
    editor_perf_headless.linkLibrary(treesitter);
    editor_perf_headless.addIncludePath(b.path("vendor"));
    addTreeSitterIncludes(editor_perf_headless, treesitter);
    const run_editor_perf_headless = b.addRunArtifact(editor_perf_headless);
    if (b.args) |args| {
        run_editor_perf_headless.addArgs(args);
    }
    const editor_perf_headless_step = b.step(
        "perf-editor-headless",
        "Run headless editor large-file performance harness",
    );
    editor_perf_headless_step.dependOn(&run_editor_perf_headless.step);

    const editor_perf_gate_cmd = b.addSystemCommand(&.{ "bash", "tools/perf_editor_gate.sh" });
    const editor_perf_gate_step = b.step(
        "perf-editor-gate",
        "Run repeatable editor performance gate against stress fixtures",
    );
    editor_perf_gate_step.dependOn(&editor_perf_gate_cmd.step);

    const terminal_kitty_query_tests = b.addTest(.{
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/terminal_kitty_query_parse_tests.zig"),
            .target = target,
            .optimize = optimize,
            .link_libc = true,
        }),
    });
    linkSdl3(terminal_kitty_query_tests, dep_path, sdl_lib);
    if (target_os == .linux) {
        terminal_kitty_query_tests.linkSystemLibrary("GL");
    } else if (target_os == .windows) {
        terminal_kitty_query_tests.linkSystemLibrary("opengl32");
    } else if (target_os == .macos) {
        terminal_kitty_query_tests.linkFramework("OpenGL");
    }
    terminal_kitty_query_tests.addIncludePath(b.path("vendor"));
    addLinuxSystemSdlInclude(terminal_kitty_query_tests, target_os, dep_path);
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

    const terminal_focus_reporting_tests = b.addTest(.{
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/terminal_focus_reporting_tests.zig"),
            .target = target,
            .optimize = optimize,
            .link_libc = true,
        }),
    });
    linkSdl3(terminal_focus_reporting_tests, dep_path, sdl_lib);
    if (target_os == .linux) {
        terminal_focus_reporting_tests.linkSystemLibrary("GL");
    } else if (target_os == .windows) {
        terminal_focus_reporting_tests.linkSystemLibrary("opengl32");
    } else if (target_os == .macos) {
        terminal_focus_reporting_tests.linkFramework("OpenGL");
    }
    terminal_focus_reporting_tests.addIncludePath(b.path("vendor"));
    addLinuxSystemSdlInclude(terminal_focus_reporting_tests, target_os, dep_path);
    terminal_focus_reporting_tests.addCSourceFile(.{
        .file = b.path("src/c/stb_image.c"),
        .flags = &.{"-std=c99"},
    });
    const run_terminal_focus_reporting_tests = b.addRunArtifact(terminal_focus_reporting_tests);
    const terminal_focus_reporting_tests_step = b.step(
        "test-terminal-focus-reporting",
        "Run project-integrated terminal focus reporting tests",
    );
    terminal_focus_reporting_tests_step.dependOn(&run_terminal_focus_reporting_tests.step);

    const terminal_workspace_tests = b.addTest(.{
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/terminal_workspace_tests.zig"),
            .target = target,
            .optimize = optimize,
            .link_libc = true,
        }),
    });
    linkSdl3(terminal_workspace_tests, dep_path, sdl_lib);
    if (target_os == .linux) {
        terminal_workspace_tests.linkSystemLibrary("GL");
    } else if (target_os == .windows) {
        terminal_workspace_tests.linkSystemLibrary("opengl32");
    } else if (target_os == .macos) {
        terminal_workspace_tests.linkFramework("OpenGL");
    }
    terminal_workspace_tests.addIncludePath(b.path("vendor"));
    addLinuxSystemSdlInclude(terminal_workspace_tests, target_os, dep_path);
    terminal_workspace_tests.addCSourceFile(.{
        .file = b.path("src/c/stb_image.c"),
        .flags = &.{"-std=c99"},
    });
    const run_terminal_workspace_tests = b.addRunArtifact(terminal_workspace_tests);
    const terminal_workspace_tests_step = b.step(
        "test-terminal-workspace",
        "Run terminal workspace lifecycle tests",
    );
    terminal_workspace_tests_step.dependOn(&run_terminal_workspace_tests.step);

    const terminal_ffi_tests = b.addTest(.{
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/terminal_ffi_smoke_tests.zig"),
            .target = target,
            .optimize = optimize,
            .link_libc = true,
        }),
    });
    terminal_ffi_tests.addIncludePath(b.path("vendor"));
    terminal_ffi_tests.addCSourceFile(.{
        .file = b.path("src/c/stb_image.c"),
        .flags = &.{"-std=c99"},
    });
    const run_terminal_ffi_tests = b.addRunArtifact(terminal_ffi_tests);
    const terminal_ffi_tests_step = b.step(
        "test-terminal-ffi",
        "Run terminal FFI bridge tests",
    );
    terminal_ffi_tests_step.dependOn(&run_terminal_ffi_tests.step);

    const editor_ffi_tests = b.addTest(.{
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/editor_ffi_smoke_tests.zig"),
            .target = target,
            .optimize = optimize,
            .link_libc = true,
        }),
    });
    editor_ffi_tests.linkLibrary(treesitter);
    editor_ffi_tests.addIncludePath(b.path("vendor"));
    addTreeSitterIncludes(editor_ffi_tests, treesitter);
    const run_editor_ffi_tests = b.addRunArtifact(editor_ffi_tests);
    const editor_ffi_tests_step = b.step(
        "test-editor-ffi",
        "Run editor FFI bridge tests",
    );
    editor_ffi_tests_step.dependOn(&run_editor_ffi_tests.step);

    const terminal_ffi_pty_smoke = b.addExecutable(.{
        .name = "terminal-ffi-pty-smoke",
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/terminal_ffi_pty_smoke.zig"),
            .target = target,
            .optimize = optimize,
            .link_libc = true,
        }),
    });
    terminal_ffi_pty_smoke.addIncludePath(b.path("vendor"));
    terminal_ffi_pty_smoke.addCSourceFile(.{
        .file = b.path("src/c/stb_image.c"),
        .flags = &.{"-std=c99"},
    });
    const run_terminal_ffi_pty_smoke = b.addRunArtifact(terminal_ffi_pty_smoke);
    const terminal_ffi_pty_smoke_step = b.step(
        "test-terminal-ffi-pty",
        "Run PTY-backed terminal FFI smoke",
    );
    terminal_ffi_pty_smoke_step.dependOn(&run_terminal_ffi_pty_smoke.step);

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
    const app_import_check_step = b.step("check-app-imports", "Check app-level and mode-layer import boundaries");
    app_import_check_step.dependOn(&run_app_import_check.step);

    const run_input_import_check = b.addRunArtifact(app_import_check);
    const input_import_check_step = b.step("check-input-imports", "Check input module import layering");
    input_import_check_step.dependOn(&run_input_import_check.step);

    const mode_size_report_step = b.step("mode-size-report", "Report focused mode binary sizes");
    mode_size_report_step.dependOn(b.getInstallStep());
    const mode_size_report_cmd = b.addSystemCommand(&.{ "bash", "tools/report_mode_binary_sizes.sh" });
    mode_size_report_step.dependOn(&mode_size_report_cmd.step);

    const mode_size_check_step = b.step("mode-size-check", "Check focused binaries are not larger than main binary");
    mode_size_check_step.dependOn(b.getInstallStep());
    const mode_size_check_cmd = b.addSystemCommand(&.{ "bash", "tools/check_mode_binary_sizes.sh" });
    mode_size_check_step.dependOn(&mode_size_check_cmd.step);

    const mode_gates_step = b.step("mode-gates", "Run MODE extraction regression gate bundle");
    mode_gates_step.dependOn(test_step);
    mode_gates_step.dependOn(terminal_import_check_step);
    mode_gates_step.dependOn(app_import_check_step);
    mode_gates_step.dependOn(input_import_check_step);
    mode_gates_step.dependOn(editor_import_check_step);
    mode_gates_step.dependOn(b.getInstallStep());
    mode_gates_step.dependOn(mode_size_check_step);
    mode_gates_step.dependOn(terminal_replay_all_step);

    const mode_gates_fast_step = b.step("mode-gates-fast", "Run fast non-replay MODE extraction gates");
    mode_gates_fast_step.dependOn(test_step);
    mode_gates_fast_step.dependOn(terminal_import_check_step);
    mode_gates_fast_step.dependOn(app_import_check_step);
    mode_gates_fast_step.dependOn(input_import_check_step);
    mode_gates_fast_step.dependOn(editor_import_check_step);
    mode_gates_fast_step.dependOn(b.getInstallStep());
    mode_gates_fast_step.dependOn(mode_size_check_step);

    const mode_smokes_manual_step = b.step("mode-smokes-manual", "Run interactive MODE smokes (manual)");
    mode_smokes_manual_step.dependOn(run_step);
    mode_smokes_manual_step.dependOn(run_mode_terminal_step);
    mode_smokes_manual_step.dependOn(run_mode_editor_step);
    mode_smokes_manual_step.dependOn(run_mode_ide_step);

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
