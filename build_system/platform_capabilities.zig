const std = @import("std");

pub const RendererBackend = enum {
    sdl_gl,
};

pub const PlatformCapability = struct {
    os_tag: std.Target.Os.Tag,
    graphics_backend: []const u8,
    ffi_surface: []const u8,
    supports_fontconfig: bool,
    fontconfig_include_dir: ?[]const u8,
    needs_system_zlib: bool,
};

pub const supported_renderer_backends = [_]RendererBackend{
    .sdl_gl,
};

pub const supported_platforms = [_]PlatformCapability{
    .{
        .os_tag = .linux,
        .graphics_backend = "OpenGL via SDL3/system GL",
        .ffi_surface = "libc + pthread/dl/rt",
        .supports_fontconfig = true,
        .fontconfig_include_dir = "/usr/include/fontconfig",
        .needs_system_zlib = true,
    },
    .{
        .os_tag = .macos,
        .graphics_backend = "OpenGL framework via SDL3",
        .ffi_surface = "Cocoa framework",
        .supports_fontconfig = false,
        .fontconfig_include_dir = null,
        .needs_system_zlib = true,
    },
    .{
        .os_tag = .windows,
        .graphics_backend = "OpenGL32 via SDL3",
        .ffi_surface = "user32/shell32",
        .supports_fontconfig = false,
        .fontconfig_include_dir = null,
        .needs_system_zlib = false,
    },
};

pub fn rendererBackendName(backend: RendererBackend) []const u8 {
    return switch (backend) {
        .sdl_gl => "sdl_gl",
    };
}

pub fn isSupportedRendererBackend(raw: []const u8) bool {
    inline for (supported_renderer_backends) |backend| {
        if (std.mem.eql(u8, raw, rendererBackendName(backend))) return true;
    }
    return false;
}

pub fn platformCapability(os_tag: std.Target.Os.Tag) ?PlatformCapability {
    inline for (supported_platforms) |capability| {
        if (capability.os_tag == os_tag) return capability;
    }
    return null;
}
