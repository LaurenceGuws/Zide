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
    common_graphics_system_libs: []const []const u8,
    common_graphics_frameworks: []const []const u8,
    ffi_system_libs: []const []const u8,
    ffi_frameworks: []const []const u8,
    sdl_test_system_libs: []const []const u8,
    sdl_test_frameworks: []const []const u8,
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
        .common_graphics_system_libs = &.{ "GL", "m", "pthread", "dl", "rt" },
        .common_graphics_frameworks = &.{},
        .ffi_system_libs = &.{ "m", "pthread", "dl", "rt" },
        .ffi_frameworks = &.{},
        .sdl_test_system_libs = &.{"GL"},
        .sdl_test_frameworks = &.{},
    },
    .{
        .os_tag = .macos,
        .graphics_backend = "OpenGL framework via SDL3",
        .ffi_surface = "Cocoa framework",
        .supports_fontconfig = false,
        .fontconfig_include_dir = null,
        .needs_system_zlib = true,
        .common_graphics_system_libs = &.{},
        .common_graphics_frameworks = &.{ "OpenGL", "Cocoa", "IOKit", "CoreVideo" },
        .ffi_system_libs = &.{},
        .ffi_frameworks = &.{"Cocoa"},
        .sdl_test_system_libs = &.{},
        .sdl_test_frameworks = &.{"OpenGL"},
    },
    .{
        .os_tag = .windows,
        .graphics_backend = "OpenGL32 via SDL3",
        .ffi_surface = "user32/shell32",
        .supports_fontconfig = false,
        .fontconfig_include_dir = null,
        .needs_system_zlib = false,
        .common_graphics_system_libs = &.{ "opengl32", "gdi32", "comdlg32", "dwrite", "ole32", "winmm", "user32", "shell32" },
        .common_graphics_frameworks = &.{},
        .ffi_system_libs = &.{ "user32", "shell32" },
        .ffi_frameworks = &.{},
        .sdl_test_system_libs = &.{"opengl32"},
        .sdl_test_frameworks = &.{},
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
