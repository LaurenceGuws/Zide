const std = @import("std");

pub const DependencySource = enum {
    link,
    zig,
};

pub fn parseDependencyPath(raw: []const u8) DependencySource {
    if (std.mem.eql(u8, raw, "link")) return .link;
    if (std.mem.eql(u8, raw, "zig")) return .zig;
    std.debug.panic("invalid -Dpath='{s}' (expected 'link' or 'zig')", .{raw});
}

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

pub const AppLinkContext = struct {
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

pub fn addAppExecutable(
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
    ctx: AppLinkContext,
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
    ctx: AppLinkContext,
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

pub fn addRunStepForArtifact(
    b: *std.Build,
    install_step: *std.Build.Step,
    artifact: *std.Build.Step.Compile,
    step_name: []const u8,
    description: []const u8,
    fixed_args: []const []const u8,
    passthrough_args: ?[]const []const u8,
) *std.Build.Step {
    const run_cmd = b.addRunArtifact(artifact);
    run_cmd.step.dependOn(install_step);
    if (fixed_args.len > 0) run_cmd.addArgs(fixed_args);
    if (passthrough_args) |args| run_cmd.addArgs(args);
    const run_step = b.step(step_name, description);
    run_step.dependOn(&run_cmd.step);
    return run_step;
}

pub fn addFocusedModeExecutable(
    b: *std.Build,
    target: std.Build.ResolvedTarget,
    optimize: std.builtin.OptimizeMode,
    build_options: *std.Build.Step.Options,
    zlua_module: *std.Build.Module,
    ctx: AppLinkContext,
    name: []const u8,
    root_source_file: []const u8,
    include_treesitter: bool,
    run_step_name: []const u8,
    run_description: []const u8,
    passthrough_args: ?[]const []const u8,
) *std.Build.Step.Compile {
    const exe = addAppExecutable(
        b,
        target,
        optimize,
        build_options,
        zlua_module,
        name,
        root_source_file,
    );
    configureAppExecutable(exe, ctx, name, include_treesitter);
    b.installArtifact(exe);
    _ = addRunStepForArtifact(
        b,
        b.getInstallStep(),
        exe,
        run_step_name,
        run_description,
        &.{},
        passthrough_args,
    );
    return exe;
}

pub fn addSdlConfiguredTest(
    b: *std.Build,
    target: std.Build.ResolvedTarget,
    optimize: std.builtin.OptimizeMode,
    root_source_file: []const u8,
    build_options: ?*std.Build.Step.Options,
    ctx: AppLinkContext,
    include_treesitter: bool,
    include_text_stack: bool,
    include_lua: bool,
    include_fontconfig: bool,
) *std.Build.Step.Compile {
    const test_target = b.addTest(.{
        .root_module = b.createModule(.{
            .root_source_file = b.path(root_source_file),
            .target = target,
            .optimize = optimize,
            .link_libc = true,
        }),
    });
    if (build_options) |opts| {
        test_target.root_module.addOptions("build_options", opts);
    }
    configureSdlTestTarget(
        test_target,
        ctx,
        include_treesitter,
        include_text_stack,
        include_lua,
        include_fontconfig,
    );
    return test_target;
}

pub fn addSdlConfiguredExecutable(
    b: *std.Build,
    target: std.Build.ResolvedTarget,
    optimize: std.builtin.OptimizeMode,
    name: []const u8,
    root_source_file: []const u8,
    ctx: AppLinkContext,
    include_treesitter: bool,
    include_text_stack: bool,
    include_lua: bool,
    include_fontconfig: bool,
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
    configureSdlTestTarget(
        exe,
        ctx,
        include_treesitter,
        include_text_stack,
        include_lua,
        include_fontconfig,
    );
    return exe;
}

pub fn addLibcTest(
    b: *std.Build,
    target: std.Build.ResolvedTarget,
    optimize: std.builtin.OptimizeMode,
    root_source_file: []const u8,
) *std.Build.Step.Compile {
    return b.addTest(.{
        .root_module = b.createModule(.{
            .root_source_file = b.path(root_source_file),
            .target = target,
            .optimize = optimize,
            .link_libc = true,
        }),
    });
}

pub fn addLibcExecutable(
    b: *std.Build,
    target: std.Build.ResolvedTarget,
    optimize: std.builtin.OptimizeMode,
    name: []const u8,
    root_source_file: []const u8,
) *std.Build.Step.Compile {
    return b.addExecutable(.{
        .name = name,
        .root_module = b.createModule(.{
            .root_source_file = b.path(root_source_file),
            .target = target,
            .optimize = optimize,
            .link_libc = true,
        }),
    });
}

pub fn addCheckExecutableStep(
    b: *std.Build,
    target: std.Build.ResolvedTarget,
    optimize: std.builtin.OptimizeMode,
    name: []const u8,
    root_source_file: []const u8,
    step_name: []const u8,
    description: []const u8,
) *std.Build.Step {
    const exe = b.addExecutable(.{
        .name = name,
        .root_module = b.createModule(.{
            .root_source_file = b.path(root_source_file),
            .target = target,
            .optimize = optimize,
        }),
    });
    const run = b.addRunArtifact(exe);
    const step = b.step(step_name, description);
    step.dependOn(&run.step);
    return step;
}

pub fn addRunArtifactStep(
    b: *std.Build,
    artifact: *std.Build.Step.Compile,
    step_name: []const u8,
    description: []const u8,
) struct {
    run: *std.Build.Step.Run,
    step: *std.Build.Step,
} {
    const run = b.addRunArtifact(artifact);
    const step = b.step(step_name, description);
    step.dependOn(&run.step);
    return .{
        .run = run,
        .step = step,
    };
}

pub fn addGateStep(
    b: *std.Build,
    step_name: []const u8,
    description: []const u8,
    deps: []const *std.Build.Step,
) *std.Build.Step {
    const step = b.step(step_name, description);
    for (deps) |dep| step.dependOn(dep);
    return step;
}
