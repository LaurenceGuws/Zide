const std = @import("std");

pub fn installVcpkgRuntimeDlls(
    b: *std.Build,
    target_os: std.Target.Os.Tag,
    use_vcpkg: bool,
    vcpkg_bin: ?[]const u8,
) void {
    if (!(use_vcpkg and target_os == .windows and vcpkg_bin != null)) return;

    const dlls = [_][]const u8{
        "SDL3.dll",
        "freetype.dll",
        "harfbuzz.dll",
        "harfbuzz-subset.dll",
        "lua.dll",
        "zlib1.dll",
        "libpng16.dll",
        "bz2.dll",
        "brotlicommon.dll",
        "brotlidec.dll",
        "brotlienc.dll",
    };

    for (dlls) |dll| {
        const src = b.pathJoin(&.{ vcpkg_bin.?, dll });
        if (std.fs.cwd().access(src, .{})) |_| {
            const install_dll = b.addInstallFile(.{ .cwd_relative = src }, b.fmt("bin/{s}", .{dll}));
            b.getInstallStep().dependOn(&install_dll.step);
        } else |_| {
            // Some triplets/configurations may not ship all of these.
        }
    }
}
