const std = @import("std");
const app_types = @import("app_types.zig");
const target_profile = @import("target_profile.zig");
const platform_capabilities = @import("platform_capabilities.zig");

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

const TextStackDeps = struct {
    freetype: *std.Build.Step.Compile,
    harfbuzz: *std.Build.Step.Compile,
};

fn requireTextStack(ctx: app_types.AppLinkContext) TextStackDeps {
    return .{
        .freetype = ctx.freetype_lib orelse @panic("dependency policy violation: text stack requires freetype"),
        .harfbuzz = ctx.harfbuzz_lib orelse @panic("dependency policy violation: text stack requires harfbuzz"),
    };
}

fn linkTextStack(
    step: *std.Build.Step.Compile,
    target_os: std.Target.Os.Tag,
    text_stack: TextStackDeps,
) void {
    const capability = platform_capabilities.platformCapability(target_os) orelse
        @panic("dependency policy violation: unsupported target os for text stack");
    step.linkLibrary(text_stack.freetype);
    step.linkLibrary(text_stack.harfbuzz);
    if (capability.needs_system_zlib) {
        step.linkSystemLibrary("z");
    }
}

fn addTextStackIncludes(
    step: *std.Build.Step.Compile,
    target_os: std.Target.Os.Tag,
    text_stack: TextStackDeps,
) void {
    const capability = platform_capabilities.platformCapability(target_os) orelse
        @panic("dependency policy violation: unsupported target os for text stack includes");
    step.addIncludePath(text_stack.freetype.getEmittedIncludeTree());
    step.addIncludePath(text_stack.harfbuzz.getEmittedIncludeTree());
    if (capability.fontconfig_include_dir) |include_dir| {
        step.addIncludePath(.{ .cwd_relative = include_dir });
    }
}

fn supportsFontconfig(target_os: std.Target.Os.Tag) bool {
    return (platform_capabilities.platformCapability(target_os) orelse
        @panic("dependency policy violation: unsupported target os for fontconfig")).supports_fontconfig;
}

fn linkSystemLibs(step: *std.Build.Step.Compile, libs: []const []const u8) void {
    for (libs) |lib_name| {
        step.linkSystemLibrary(lib_name);
    }
}

fn linkFrameworks(step: *std.Build.Step.Compile, frameworks: []const []const u8) void {
    for (frameworks) |framework_name| {
        step.linkFramework(framework_name);
    }
}

fn linkCommonPlatformGraphics(exe: *std.Build.Step.Compile, target_os: std.Target.Os.Tag) void {
    const capability = platform_capabilities.platformCapability(target_os) orelse
        @panic("dependency policy violation: unsupported target os for common graphics linking");
    linkSystemLibs(exe, capability.common_graphics_system_libs);
    linkFrameworks(exe, capability.common_graphics_frameworks);
}

pub fn addVendorAndStb(step: *std.Build.Step.Compile) void {
    step.addIncludePath(.{ .cwd_relative = "vendor" });
    step.addCSourceFile(.{
        .file = .{ .cwd_relative = "src/c/stb_image.c" },
        .flags = &.{"-std=c99"},
    });
}

pub fn linkFfiPlatform(step: *std.Build.Step.Compile, target_os: std.Target.Os.Tag) void {
    const capability = platform_capabilities.platformCapability(target_os) orelse
        @panic("dependency policy violation: unsupported target os for ffi linking");
    linkSystemLibs(step, capability.ffi_system_libs);
    linkFrameworks(step, capability.ffi_frameworks);
}

fn linkSdlTestGraphics(step: *std.Build.Step.Compile, target_os: std.Target.Os.Tag) void {
    const capability = platform_capabilities.platformCapability(target_os) orelse
        @panic("dependency policy violation: unsupported target os for SDL test graphics linking");
    linkSystemLibs(step, capability.sdl_test_system_libs);
    linkFrameworks(step, capability.sdl_test_frameworks);
}

pub fn configureSdlTestTarget(
    step: *std.Build.Step.Compile,
    ctx: app_types.AppLinkContext,
    profile: target_profile.LinkProfile,
) void {
    const text_stack = if (profile.include_text_stack) requireTextStack(ctx) else null;
    linkSdl3(step, ctx.sdl_lib);
    if (text_stack) |deps| linkTextStack(step, ctx.target_os, deps);
    if (profile.include_lua and ctx.lua_lib != null) linkLua(step, ctx.lua_lib);
    if (profile.include_fontconfig and supportsFontconfig(ctx.target_os)) {
        step.linkSystemLibrary("fontconfig");
    }
    linkSdlTestGraphics(step, ctx.target_os);

    if (profile.include_treesitter) step.linkLibrary(requireTreeSitter(ctx));
    addVendorAndStb(step);
    if (profile.include_treesitter) addTreeSitterIncludes(step, requireTreeSitter(ctx));
    if (text_stack) |deps| addTextStackIncludes(step, ctx.target_os, deps);
    if (profile.include_lua and ctx.lua_lib != null) {
        addLuaIncludes(step, ctx.lua_lib);
    }
}

pub fn configureAppExecutable(
    exe: *std.Build.Step.Compile,
    ctx: app_types.AppLinkContext,
    target_name: []const u8,
    profile: target_profile.LinkProfile,
) void {
    const text_stack = if (profile.include_text_stack) requireTextStack(ctx) else null;
    if (std.mem.eql(u8, target_name, "zide-terminal") and profile.include_treesitter) {
        @panic("dependency policy violation: zide-terminal must not link tree-sitter");
    }
    if (profile.include_treesitter) exe.linkLibrary(requireTreeSitter(ctx));
    if (text_stack) |deps| linkTextStack(exe, ctx.target_os, deps);
    if (profile.include_lua and ctx.lua_lib != null) {
        linkLua(exe, ctx.lua_lib);
    }
    linkSdl3(exe, ctx.sdl_lib);
    if (profile.include_fontconfig and supportsFontconfig(ctx.target_os)) {
        exe.linkSystemLibrary("fontconfig");
    }
    addVendorAndStb(exe);
    if (profile.include_treesitter) addTreeSitterIncludes(exe, requireTreeSitter(ctx));
    if (text_stack) |deps| addTextStackIncludes(exe, ctx.target_os, deps);
    if (profile.include_lua and ctx.lua_lib != null) {
        addLuaIncludes(exe, ctx.lua_lib);
    }
    linkCommonPlatformGraphics(exe, ctx.target_os);
}
