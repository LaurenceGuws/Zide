const std = @import("std");
const build_options = @import("build_options");
const platform_capabilities = @import("platform_capabilities");

pub fn main() !void {
    const os_tag = std.meta.stringToEnum(std.Target.Os.Tag, build_options.target_os) orelse {
        @panic("unsupported build target os in build options");
    };
    const capability = platform_capabilities.platformCapability(os_tag) orelse {
        @panic("no platform capability defined for target os");
    };

    std.debug.print("build platform capability\n", .{});
    std.debug.print("os: {s}\n", .{build_options.target_os});
    std.debug.print("graphics_backend: {s}\n", .{capability.graphics_backend});
    std.debug.print("ffi_surface: {s}\n", .{capability.ffi_surface});
    std.debug.print("supports_fontconfig: {any}\n", .{capability.supports_fontconfig});
    std.debug.print("supports_terminal_bundle: {any}\n", .{capability.supports_terminal_bundle});
    std.debug.print("supports_windows_shell_extension: {any}\n", .{capability.supports_windows_shell_extension});
    std.debug.print("uses_windows_gui_subsystem: {any}\n", .{capability.uses_windows_gui_subsystem});
    std.debug.print("supports_windows_resources: {any}\n", .{capability.supports_windows_resources});
    std.debug.print("renderer_backend: {s}\n", .{build_options.renderer_backend});
}
