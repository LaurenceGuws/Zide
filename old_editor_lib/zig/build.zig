const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const module = b.createModule(.{
        .root_source_file = b.path("src/ffi.zig"),
        .target = target,
        .optimize = optimize,
        .link_libc = true,
    });

    const lib = b.addLibrary(.{
        .name = "zig_ffi",
        .root_module = module,
        .linkage = .dynamic,
    });

    lib.addIncludePath(b.path("third_party/tree-sitter/lib/include"));
    lib.addIncludePath(b.path("third_party/tree-sitter-bash/src"));
    lib.addCSourceFiles(.{
        .files = &[_][]const u8{
            "third_party/tree-sitter/lib/src/lib.c",
            "third_party/tree-sitter-bash/src/parser.c",
            "third_party/tree-sitter-bash/src/scanner.c",
        },
        .flags = &[_][]const u8{
            "-std=c99",
            "-D_POSIX_C_SOURCE=200809L",
            "-D_DEFAULT_SOURCE",
            "-D_GNU_SOURCE",
        },
    });

    b.installArtifact(lib);
}
