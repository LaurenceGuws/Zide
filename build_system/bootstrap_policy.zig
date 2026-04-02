const std = @import("std");
const builtin = @import("builtin");
const mode_specs = @import("mode_specs.zig");
const platform_capabilities = @import("platform_capabilities.zig");

pub const RendererOption = struct {
    value: []const u8,
    description: []const u8,
};

pub const supported_renderer_options = [_]RendererOption{
    .{
        .value = "sdl_gl",
        .description = "OpenGL renderer via SDL3",
    },
};

pub fn defaultTargetQuery() std.Target.Query {
    return if (builtin.os.tag == .windows) .{
        .cpu_arch = .x86_64,
        .os_tag = .windows,
        .abi = .msvc,
    } else .{};
}

pub fn parseBuildModeOption(b: *std.Build) mode_specs.BuildMode {
    return parseBuildModeRaw(readBuildModeOptionRaw(b));
}

pub fn readBuildModeOptionRaw(b: *std.Build) []const u8 {
    return b.option(
        []const u8,
        "mode",
        "Build app mode: ide (default), terminal, editor",
    ) orelse "ide";
}

pub fn parseBuildModeRaw(build_mode_raw: []const u8) mode_specs.BuildMode {
    return mode_specs.parseBuildMode(build_mode_raw);
}

pub fn readRendererBackendOption(b: *std.Build) []const u8 {
    const default_renderer_backend = platform_capabilities.rendererBackendName(.sdl_gl);
    const renderer_backend = b.option(
        []const u8,
        "renderer-backend",
        "Renderer backend (only sdl_gl is implemented)",
    ) orelse default_renderer_backend;
    if (!platform_capabilities.isSupportedRendererBackend(renderer_backend)) {
        std.debug.panic(
            "renderer backend '{s}' is not implemented (use -Drenderer-backend=sdl_gl)",
            .{renderer_backend},
        );
    }
    return renderer_backend;
}
