const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
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
        .file = b.path("old_editor_lib/zig/third_party/tree-sitter/lib/src/lib.c"),
        .flags = &.{
            "-std=c99",
            "-D_POSIX_C_SOURCE=200809L",
            "-D_DEFAULT_SOURCE",
        },
    });
    treesitter.addIncludePath(b.path("old_editor_lib/zig/third_party/tree-sitter/lib/include"));
    treesitter.addIncludePath(b.path("old_editor_lib/zig/third_party/tree-sitter/lib/src"));

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
        .file = b.path("old_editor_lib/zig/third_party/tree-sitter-zig/src/parser.c"),
        .flags = &.{"-std=c99"},
    });
    ts_zig.addIncludePath(b.path("old_editor_lib/zig/third_party/tree-sitter/lib/include"));

    // ─────────────────────────────────────────────────────────────────────────
    // Raylib (built from source)
    // ─────────────────────────────────────────────────────────────────────────
    const raylib = b.addLibrary(.{
        .name = "raylib",
        .linkage = .static,
        .root_module = b.createModule(.{
            .target = target,
            .optimize = optimize,
            .link_libc = true,
        }),
    });

    // Platform detection (needed for Wayland vs X11 decision)
    const target_os = target.result.os.tag;

    const raylib_src_path = "vendor/raylib/src/";
    const raylib_sources: []const []const u8 = &.{
        raylib_src_path ++ "rcore.c",
        raylib_src_path ++ "rshapes.c",
        raylib_src_path ++ "rtextures.c",
        raylib_src_path ++ "rtext.c",
        raylib_src_path ++ "rmodels.c",
        raylib_src_path ++ "raudio.c",
    };

    // Wayland-native on Linux (for proper Hyprland/Sway integration)
    const use_wayland = target_os == .linux;

    const raylib_flags: []const []const u8 = if (use_wayland) &.{
        "-std=c99",
        "-DPLATFORM_DESKTOP_GLFW",
        "-DGRAPHICS_API_OPENGL_33",
        "-D_GLFW_WAYLAND",
    } else &.{
        "-std=c99",
        "-DPLATFORM_DESKTOP_GLFW",
        "-DGRAPHICS_API_OPENGL_33",
        "-D_GLFW_X11",
    };

    raylib.addCSourceFiles(.{
        .files = raylib_sources,
        .flags = raylib_flags,
    });

    // Platform-specific raylib source
    if (target_os == .windows) {
        raylib.addCSourceFile(.{
            .file = b.path(raylib_src_path ++ "rglfw.c"),
            .flags = raylib_flags,
        });
        raylib.linkSystemLibrary("opengl32");
        raylib.linkSystemLibrary("gdi32");
        raylib.linkSystemLibrary("winmm");
        raylib.linkSystemLibrary("user32");
        raylib.linkSystemLibrary("shell32");
    } else if (target_os == .macos) {
        raylib.addCSourceFile(.{
            .file = b.path(raylib_src_path ++ "rglfw.c"),
            .flags = raylib_flags,
        });
        raylib.linkFramework("OpenGL");
        raylib.linkFramework("Cocoa");
        raylib.linkFramework("IOKit");
        raylib.linkFramework("CoreVideo");
    } else {
        // Linux
        raylib.addCSourceFile(.{
            .file = b.path(raylib_src_path ++ "rglfw.c"),
            .flags = raylib_flags,
        });

        if (use_wayland) {
            // Native Wayland support - generated protocol headers are in vendor/wayland-protocols
            raylib.addIncludePath(b.path("vendor/wayland-protocols"));
            raylib.linkSystemLibrary("wayland-client");
            raylib.linkSystemLibrary("wayland-cursor");
            raylib.linkSystemLibrary("wayland-egl");
            raylib.linkSystemLibrary("xkbcommon");
            raylib.linkSystemLibrary("EGL");
            raylib.linkSystemLibrary("GL");
        } else {
            // X11 fallback
            raylib.linkSystemLibrary("GL");
            raylib.linkSystemLibrary("X11");
        }
        raylib.linkSystemLibrary("m");
        raylib.linkSystemLibrary("pthread");
        raylib.linkSystemLibrary("dl");
        raylib.linkSystemLibrary("rt");
    }

    raylib.addIncludePath(b.path("vendor/raylib/src"));
    raylib.addIncludePath(b.path("vendor/raylib/src/external/glfw/include"));

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

    // Link C libraries
    exe.linkLibrary(raylib);
    exe.linkLibrary(treesitter);
    exe.linkLibrary(ts_zig);
    exe.linkSystemLibrary("freetype");
    exe.linkSystemLibrary("harfbuzz");
    exe.linkSystemLibrary("lua");

    // Include paths for @cImport
    exe.addIncludePath(b.path("vendor/raylib/src"));
    exe.addIncludePath(b.path("old_editor_lib/zig/third_party/tree-sitter/lib/include"));
    exe.addIncludePath(.{ .cwd_relative = "/usr/include/freetype2" });
    exe.addIncludePath(.{ .cwd_relative = "/usr/include/harfbuzz" });
    exe.addIncludePath(.{ .cwd_relative = "/usr/include/lua5.4" });

    // Platform-specific linking for the exe
    if (target_os == .windows) {
        exe.linkSystemLibrary("opengl32");
        exe.linkSystemLibrary("gdi32");
        exe.linkSystemLibrary("winmm");
        exe.linkSystemLibrary("user32");
        exe.linkSystemLibrary("shell32");
    } else if (target_os == .macos) {
        exe.linkFramework("OpenGL");
        exe.linkFramework("Cocoa");
        exe.linkFramework("IOKit");
        exe.linkFramework("CoreVideo");
    } else {
        if (use_wayland) {
            // Native Wayland support
            exe.linkSystemLibrary("wayland-client");
            exe.linkSystemLibrary("wayland-cursor");
            exe.linkSystemLibrary("wayland-egl");
            exe.linkSystemLibrary("xkbcommon");
            exe.linkSystemLibrary("EGL");
            exe.linkSystemLibrary("GL");
        } else {
            exe.linkSystemLibrary("GL");
            exe.linkSystemLibrary("X11");
        }
        exe.linkSystemLibrary("m");
        exe.linkSystemLibrary("pthread");
        exe.linkSystemLibrary("dl");
        exe.linkSystemLibrary("rt");
    }

    b.installArtifact(exe);

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
    unit_tests.linkLibrary(treesitter);
    unit_tests.addIncludePath(b.path("old_editor_lib/zig/third_party/tree-sitter/lib/include"));

    const run_tests = b.addRunArtifact(unit_tests);
    const test_step = b.step("test", "Run unit tests");
    test_step.dependOn(&run_tests.step);
}
