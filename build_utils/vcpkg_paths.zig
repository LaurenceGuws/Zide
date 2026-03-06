const std = @import("std");
const app_types = @import("app_types.zig");

pub fn resolveVcpkgPaths(
    b: *std.Build,
    target: std.Build.ResolvedTarget,
    target_os: std.Target.Os.Tag,
    use_vcpkg: bool,
    vcpkg_root_opt: ?[]const u8,
    vcpkg_triplet_opt: ?[]const u8,
) app_types.VcpkgPaths {
    var vcpkg_include: ?[]const u8 = null;
    var vcpkg_lib: ?[]const u8 = null;
    var vcpkg_bin: ?[]const u8 = null;

    if (use_vcpkg) {
        if (target_os == .windows and target.result.cpu.arch != .x86_64) {
            @panic("Windows builds are x86_64-only.");
        }
        const vcpkg_triplet = vcpkg_triplet_opt orelse switch (target_os) {
            .windows => "x64-windows",
            else => "x64-linux",
        };

        const manifest_lib = b.pathJoin(&.{ "vcpkg_installed", vcpkg_triplet, "lib" });
        const manifest_include = b.pathJoin(&.{ "vcpkg_installed", vcpkg_triplet, "include" });
        const manifest_bin = b.pathJoin(&.{ "vcpkg_installed", vcpkg_triplet, "bin" });

        if (vcpkg_root_opt) |vcpkg_root| {
            const classic_lib = b.pathJoin(&.{ vcpkg_root, "installed", vcpkg_triplet, "lib" });
            const classic_include = b.pathJoin(&.{ vcpkg_root, "installed", vcpkg_triplet, "include" });
            const classic_bin = b.pathJoin(&.{ vcpkg_root, "installed", vcpkg_triplet, "bin" });

            if (std.fs.cwd().access(classic_lib, .{})) |_| {
                vcpkg_lib = classic_lib;
                vcpkg_include = classic_include;
                vcpkg_bin = classic_bin;
            } else |_| {
                if (std.fs.cwd().access(manifest_lib, .{})) |_| {
                    vcpkg_lib = manifest_lib;
                    vcpkg_include = manifest_include;
                    vcpkg_bin = manifest_bin;
                } else |_| {
                    @panic("use-vcpkg enabled, but could not find vcpkg libraries. Expected either <VCPKG_ROOT>/installed/<triplet>/lib or ./vcpkg_installed/<triplet>/lib");
                }
            }
        } else {
            if (std.fs.cwd().access(manifest_lib, .{})) |_| {
                vcpkg_lib = manifest_lib;
                vcpkg_include = manifest_include;
                vcpkg_bin = manifest_bin;
            } else |_| {
                @panic("use-vcpkg enabled, but vcpkg deps were not found. On Windows, run `vcpkg install --triplet x64-windows` in the repo root (manifest mode), or set VCPKG_ROOT / pass --vcpkg-root for classic mode.");
            }
        }
    } else if (target_os == .windows) {
        @panic("Windows builds require vcpkg. Install deps via manifest mode (./vcpkg_installed) or set VCPKG_ROOT + VCPKG_DEFAULT_TRIPLET, then re-run.");
    }

    return .{
        .include = vcpkg_include,
        .lib = vcpkg_lib,
        .bin = vcpkg_bin,
    };
}
