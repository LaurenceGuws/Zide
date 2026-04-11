const std = @import("std");
const bootstrap_graph = @import("bootstrap_graph.zig");
const target_config = @import("target_config.zig");

fn addAndroidSysrootIncludes(b: *std.Build, step: *std.Build.Step.Compile) void {
    const sysroot = b.sysroot orelse @panic("android terminal host bridge requires --sysroot");
    step.root_module.addSystemIncludePath(.{ .cwd_relative = b.fmt("{s}/usr/include", .{sysroot}) });
    step.root_module.addSystemIncludePath(.{ .cwd_relative = b.fmt("{s}/usr/include/aarch64-linux-android", .{sysroot}) });
}

fn addAndroidSystemLibrary(
    b: *std.Build,
    target: std.Build.ResolvedTarget,
    step: *std.Build.Step.Compile,
    lib_name: []const u8,
) void {
    const sysroot = b.sysroot orelse @panic("android terminal host bridge requires --sysroot");
    const api_level = target.result.os.version_range.linux.android;
    step.root_module.addObjectFile(.{
        .cwd_relative = b.fmt(
            "{s}/usr/lib/aarch64-linux-android/{d}/lib{s}.so",
            .{ sysroot, api_level, lib_name },
        ),
    });
}

fn addAndroidLibcFile(
    b: *std.Build,
    target: std.Build.ResolvedTarget,
    step: *std.Build.Step.Compile,
) void {
    const sysroot = b.sysroot orelse @panic("android terminal host bridge requires --sysroot");
    const api_level = target.result.os.version_range.linux.android;
    const write_files = b.addWriteFiles();
    const libc_file = write_files.add("android-libc.txt", b.fmt(
        \\include_dir={s}/usr/include
        \\sys_include_dir={s}/usr/include/aarch64-linux-android
        \\crt_dir={s}/usr/lib/aarch64-linux-android/{d}
        \\msvc_lib_dir=
        \\kernel32_lib_dir=
        \\gcc_dir=
        \\
    , .{ sysroot, sysroot, sysroot, api_level }));
    step.setLibCFile(libc_file);
}

fn addSdlHeaderIncludes(
    b: *std.Build,
    target: std.Build.ResolvedTarget,
    optimize: std.builtin.OptimizeMode,
    step: *std.Build.Step.Compile,
) void {
    const sdl_dep = b.dependency("sdl", .{
        .target = target,
        .optimize = optimize,
    });
    step.addIncludePath(sdl_dep.path("include"));
    step.addIncludePath(sdl_dep.path("include/build_config"));
}

pub fn addAndroidTerminalHostBridgeStep(
    b: *std.Build,
    boot: bootstrap_graph.BuildBootstrap,
) void {
    if (boot.target.result.abi != .android) return;

    const freetype_lib = boot.app_link_ctx.freetype_lib orelse @panic("android terminal host requires freetype");
    const harfbuzz_lib = boot.app_link_ctx.harfbuzz_lib orelse @panic("android terminal host requires harfbuzz");

    addAndroidSysrootIncludes(b, freetype_lib);
    addAndroidSysrootIncludes(b, harfbuzz_lib);

    const bridge = b.addLibrary(.{
        .name = "zide_android_bridge",
        .linkage = .dynamic,
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/android_bridge_exports.zig"),
            .target = boot.target,
            .optimize = boot.optimize,
            .link_libc = true,
        }),
    });
    addAndroidSysrootIncludes(b, bridge);
    addAndroidLibcFile(b, boot.target, bridge);
    bridge.root_module.addOptions("build_options", boot.build_options);

    bridge.linkLibrary(freetype_lib);
    bridge.linkLibrary(harfbuzz_lib);
    addAndroidSystemLibrary(b, boot.target, bridge, "android");
    addAndroidSystemLibrary(b, boot.target, bridge, "EGL");
    addAndroidSystemLibrary(b, boot.target, bridge, "GLESv2");
    addAndroidSystemLibrary(b, boot.target, bridge, "m");
    addAndroidSystemLibrary(b, boot.target, bridge, "z");

    target_config.addVendorAndStb(bridge);
    addSdlHeaderIncludes(b, boot.target, boot.optimize, bridge);
    bridge.addIncludePath(freetype_lib.getEmittedIncludeTree());
    bridge.addIncludePath(harfbuzz_lib.getEmittedIncludeTree());

    const install_bridge = b.addInstallArtifact(bridge, .{});
    const step = b.step(
        "android-terminal-host-bridge",
        "Build the Android terminal-host native bridge shared library",
    );
    step.dependOn(&install_bridge.step);
}
