const std = @import("std");
const app_types = @import("app_types.zig");
const target_profile = @import("target_profile.zig");
const links_windows = @import("platform_links_windows.zig");
const links_linux = @import("platform_links_linux.zig");
const links_macos = @import("platform_links_macos.zig");

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

fn requireTreeSitter(ctx: app_types.AppLinkContext) *std.Build.Step.Compile {
    return ctx.treesitter orelse @panic("dependency policy violation: tree-sitter required but not resolved");
}

fn linkTextStack(
    step: *std.Build.Step.Compile,
    freetype_lib: ?*std.Build.Step.Compile,
    harfbuzz_lib: ?*std.Build.Step.Compile,
) void {
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
}

fn addTextStackIncludes(
    step: *std.Build.Step.Compile,
    use_vcpkg: bool,
    target_os: std.Target.Os.Tag,
    freetype_lib: ?*std.Build.Step.Compile,
    harfbuzz_lib: ?*std.Build.Step.Compile,
) void {
    if (use_vcpkg) return;
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
    if (target_os == .linux) {
        step.addIncludePath(.{ .cwd_relative = "/usr/include/fontconfig" });
    }
}

fn linkCommonPlatformGraphics(exe: *std.Build.Step.Compile, target_os: std.Target.Os.Tag) void {
    switch (target_os) {
        .windows => links_windows.linkCommonPlatformGraphics(exe),
        .macos => links_macos.linkCommonPlatformGraphics(exe),
        else => links_linux.linkCommonPlatformGraphics(exe),
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
    switch (target_os) {
        .windows => links_windows.linkFfiPlatform(step),
        .macos => links_macos.linkFfiPlatform(step),
        else => links_linux.linkFfiPlatform(step),
    }
}

fn linkSdlTestGraphics(step: *std.Build.Step.Compile, target_os: std.Target.Os.Tag) void {
    switch (target_os) {
        .windows => links_windows.linkSdlTestGraphics(step),
        .macos => links_macos.linkSdlTestGraphics(step),
        else => links_linux.linkSdlTestGraphics(step),
    }
}

pub fn configureSdlTestTarget(
    step: *std.Build.Step.Compile,
    ctx: app_types.AppLinkContext,
    profile: target_profile.LinkProfile,
) void {
    if (ctx.use_vcpkg) {
        step.addLibraryPath(.{ .cwd_relative = ctx.vcpkg_lib.? });
        step.addIncludePath(.{ .cwd_relative = ctx.vcpkg_include.? });
    }
    linkSdl3(step, ctx.sdl_lib);
    if (profile.include_text_stack) linkTextStack(step, ctx.freetype_lib, ctx.harfbuzz_lib);
    if (profile.include_lua) linkLua(step, ctx.lua_lib);
    if (profile.include_fontconfig and ctx.target_os == .linux) {
        step.linkSystemLibrary("fontconfig");
    }
    linkSdlTestGraphics(step, ctx.target_os);

    if (profile.include_treesitter) step.linkLibrary(requireTreeSitter(ctx));
    addVendorAndStb(step);
    if (profile.include_treesitter) addTreeSitterIncludes(step, requireTreeSitter(ctx));
    if (!ctx.use_vcpkg) {
        if (profile.include_text_stack) {
            addTextStackIncludes(step, ctx.use_vcpkg, ctx.target_os, ctx.freetype_lib, ctx.harfbuzz_lib);
        }
        if (profile.include_lua) {
            addLuaIncludes(step, ctx.lua_lib);
        }
    }
}

pub fn configureAppExecutable(
    exe: *std.Build.Step.Compile,
    ctx: app_types.AppLinkContext,
    target_name: []const u8,
    profile: target_profile.LinkProfile,
) void {
    if (std.mem.eql(u8, target_name, "zide-terminal") and profile.include_treesitter) {
        @panic("dependency policy violation: zide-terminal must not link tree-sitter");
    }
    if (profile.include_treesitter) exe.linkLibrary(requireTreeSitter(ctx));
    if (ctx.use_vcpkg) {
        exe.addLibraryPath(.{ .cwd_relative = ctx.vcpkg_lib.? });
        exe.addIncludePath(.{ .cwd_relative = ctx.vcpkg_include.? });
    }
    if (profile.include_text_stack) {
        linkTextStack(exe, ctx.freetype_lib, ctx.harfbuzz_lib);
    }
    if (profile.include_lua) {
        linkLua(exe, ctx.lua_lib);
    }
    linkSdl3(exe, ctx.sdl_lib);
    if (profile.include_fontconfig and ctx.target_os == .linux) {
        exe.linkSystemLibrary("fontconfig");
    }
    addVendorAndStb(exe);
    if (profile.include_treesitter) addTreeSitterIncludes(exe, requireTreeSitter(ctx));
    if (!ctx.use_vcpkg) {
        if (profile.include_text_stack) {
            addTextStackIncludes(exe, ctx.use_vcpkg, ctx.target_os, ctx.freetype_lib, ctx.harfbuzz_lib);
        }
        if (profile.include_lua) {
            addLuaIncludes(exe, ctx.lua_lib);
        }
    }
    linkCommonPlatformGraphics(exe, ctx.target_os);
}
