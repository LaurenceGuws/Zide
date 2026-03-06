const std = @import("std");
const dependency_path = @import("dependency_path.zig");
const app_types = @import("app_types.zig");

fn linkSdl3(step: *std.Build.Step.Compile, sdl_lib: ?*std.Build.Step.Compile) void {
    step.linkLibrary(sdl_lib.?);
}

fn linkLua(step: *std.Build.Step.Compile, lua_lib: ?*std.Build.Step.Compile) void {
    step.linkLibrary(lua_lib.?);
}

fn addLuaIncludes(step: *std.Build.Step.Compile, lua_lib: ?*std.Build.Step.Compile) void {
    step.addIncludePath(lua_lib.?.getEmittedIncludeTree());
}

pub fn addTreeSitterIncludes(step: *std.Build.Step.Compile, treesitter_lib: *std.Build.Step.Compile) void {
    step.addIncludePath(treesitter_lib.getEmittedIncludeTree());
}

fn linkTextStack(
    step: *std.Build.Step.Compile,
    dep_path: dependency_path.DependencySource,
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
    dep_path: dependency_path.DependencySource,
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

pub fn addVendorAndStb(step: *std.Build.Step.Compile) void {
    step.addIncludePath(.{ .cwd_relative = "vendor" });
    step.addCSourceFile(.{
        .file = .{ .cwd_relative = "src/c/stb_image.c" },
        .flags = &.{"-std=c99"},
    });
}

pub fn linkFfiPlatform(step: *std.Build.Step.Compile, target_os: std.Target.Os.Tag) void {
    if (target_os == .windows) {
        step.linkSystemLibrary("user32");
        step.linkSystemLibrary("shell32");
    } else if (target_os == .macos) {
        step.linkFramework("Cocoa");
    } else {
        step.linkSystemLibrary("m");
        step.linkSystemLibrary("pthread");
        step.linkSystemLibrary("dl");
        step.linkSystemLibrary("rt");
    }
}

fn linkSdlTestGraphics(step: *std.Build.Step.Compile, target_os: std.Target.Os.Tag) void {
    if (target_os == .linux) {
        step.linkSystemLibrary("GL");
    } else if (target_os == .windows) {
        step.linkSystemLibrary("opengl32");
    } else if (target_os == .macos) {
        step.linkFramework("OpenGL");
    }
}

pub fn configureSdlTestTarget(
    step: *std.Build.Step.Compile,
    ctx: app_types.AppLinkContext,
    include_treesitter: bool,
    include_text_stack: bool,
    include_lua: bool,
    include_fontconfig: bool,
) void {
    if (ctx.use_vcpkg) {
        step.addLibraryPath(.{ .cwd_relative = ctx.vcpkg_lib.? });
        step.addIncludePath(.{ .cwd_relative = ctx.vcpkg_include.? });
    }
    linkSdl3(step, ctx.sdl_lib);
    if (include_text_stack) linkTextStack(step, ctx.dep_path, ctx.freetype_lib, ctx.harfbuzz_lib);
    if (include_lua) linkLua(step, ctx.lua_lib);
    if (include_fontconfig and ctx.target_os == .linux) {
        step.linkSystemLibrary("fontconfig");
    }
    linkSdlTestGraphics(step, ctx.target_os);

    if (include_treesitter) {
        step.linkLibrary(ctx.treesitter);
    }
    addVendorAndStb(step);
    if (include_treesitter) {
        addTreeSitterIncludes(step, ctx.treesitter);
    }
    if (!ctx.use_vcpkg) {
        if (include_text_stack) {
            addTextStackIncludes(step, ctx.use_vcpkg, ctx.target_os, ctx.dep_path, ctx.freetype_lib, ctx.harfbuzz_lib);
        }
        if (include_lua) {
            addLuaIncludes(step, ctx.lua_lib);
        }
    }
}

pub fn configureAppExecutable(
    exe: *std.Build.Step.Compile,
    ctx: app_types.AppLinkContext,
    target_name: []const u8,
    include_treesitter: bool,
) void {
    if (std.mem.eql(u8, target_name, "zide-terminal") and include_treesitter) {
        @panic("dependency policy violation: zide-terminal must not link tree-sitter");
    }
    if (include_treesitter) {
        exe.linkLibrary(ctx.treesitter);
    }
    if (ctx.use_vcpkg) {
        exe.addLibraryPath(.{ .cwd_relative = ctx.vcpkg_lib.? });
        exe.addIncludePath(.{ .cwd_relative = ctx.vcpkg_include.? });
    }
    linkTextStack(exe, ctx.dep_path, ctx.freetype_lib, ctx.harfbuzz_lib);
    linkLua(exe, ctx.lua_lib);
    linkSdl3(exe, ctx.sdl_lib);
    if (ctx.target_os == .linux) {
        exe.linkSystemLibrary("fontconfig");
    }
    addVendorAndStb(exe);
    if (include_treesitter) {
        addTreeSitterIncludes(exe, ctx.treesitter);
    }
    if (!ctx.use_vcpkg) {
        addTextStackIncludes(exe, ctx.use_vcpkg, ctx.target_os, ctx.dep_path, ctx.freetype_lib, ctx.harfbuzz_lib);
        addLuaIncludes(exe, ctx.lua_lib);
    }
    linkCommonPlatformGraphics(exe, ctx.target_os);
}
