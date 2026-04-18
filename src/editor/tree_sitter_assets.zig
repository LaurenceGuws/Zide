const std = @import("std");
const builtin = @import("builtin");

const c = @cImport({
    @cInclude("stdlib.h");
});

pub fn resolveSharedAssetPath(allocator: std.mem.Allocator, rel_path: []const u8) !?[]u8 {
    if (std.c.getenv("ZIDE_TREE_SITTER_ASSET_ROOT")) |root_c| {
        const root = std.mem.sliceTo(root_c, 0);
        if (try joinIfExists(allocator, root, rel_path)) |path| return path;
    }

    if (try userAssetRoot(allocator)) |root| {
        defer allocator.free(root);
        if (try joinIfExists(allocator, root, rel_path)) |path| return path;
    }

    if (try joinIfExists(allocator, "assets", rel_path)) |path| return path;
    return null;
}

pub fn userAssetRoot(allocator: std.mem.Allocator) !?[]u8 {
    if (builtin.os.tag == .windows) {
        if (std.c.getenv("LOCALAPPDATA")) |local_appdata| {
            const base = std.mem.sliceTo(local_appdata, 0);
            return try std.fs.path.join(allocator, &.{ base, "Zide", "tree-sitter-assets" });
        }
        if (std.c.getenv("APPDATA")) |appdata| {
            const base = std.mem.sliceTo(appdata, 0);
            return try std.fs.path.join(allocator, &.{ base, "Zide", "tree-sitter-assets" });
        }
    }
    if (std.c.getenv("XDG_CONFIG_HOME")) |xdg| {
        const base = std.mem.sliceTo(xdg, 0);
        return try std.fs.path.join(allocator, &.{ base, "zide", "tree-sitter-assets" });
    }
    if (std.c.getenv("HOME")) |home| {
        const base = std.mem.sliceTo(home, 0);
        return try std.fs.path.join(allocator, &.{ base, ".config", "zide", "tree-sitter-assets" });
    }
    return null;
}

fn joinIfExists(allocator: std.mem.Allocator, base: []const u8, rel_path: []const u8) !?[]u8 {
    const path = try std.fs.path.join(allocator, &.{ base, rel_path });
    errdefer allocator.free(path);
    if (!fileExists(path)) {
        allocator.free(path);
        return null;
    }
    return path;
}

fn fileExists(path: []const u8) bool {
    const file = if (std.fs.path.isAbsolute(path))
        std.fs.openFileAbsolute(path, .{})
    else
        std.fs.cwd().openFile(path, .{});
    const handle = file catch return false;
    handle.close();
    return true;
}

test "resolveSharedAssetPath prefers user asset root over bundled assets" {
    var tmp = std.testing.tmpDir(.{});
    defer tmp.cleanup();

    try tmp.dir.makePath("user/zide/tree-sitter-assets/syntax");
    try tmp.dir.makePath("workspace/zide");
    try tmp.dir.makePath("workspace/zide/assets/syntax");

    try tmp.dir.writeFile(.{
        .sub_path = "user/zide/tree-sitter-assets/syntax/generated.lua",
        .data = "user",
    });
    try tmp.dir.writeFile(.{
        .sub_path = "workspace/zide/assets/syntax/generated.lua",
        .data = "bundled",
    });

    const root_path = try tmp.dir.realpathAlloc(std.testing.allocator, ".");
    defer std.testing.allocator.free(root_path);

    const workspace_root = try std.fs.path.join(std.testing.allocator, &.{ root_path, "workspace", "zide" });
    defer std.testing.allocator.free(workspace_root);
    const user_root = try std.fs.path.join(std.testing.allocator, &.{ root_path, "user" });
    defer std.testing.allocator.free(user_root);

    const previous_cwd = try std.process.getCwdAlloc(std.testing.allocator);
    defer std.testing.allocator.free(previous_cwd);
    try std.posix.chdir(workspace_root);
    defer std.posix.chdir(previous_cwd) catch {};

    const old_xdg = std.c.getenv("XDG_CONFIG_HOME");
    const old_home = std.c.getenv("HOME");

    const user_root_z = try std.testing.allocator.dupeZ(u8, user_root);
    defer std.testing.allocator.free(user_root_z);

    _ = c.setenv("XDG_CONFIG_HOME", user_root_z.ptr, 1);
    _ = c.setenv("HOME", user_root_z.ptr, 1);
    defer {
        if (old_xdg) |value| {
            const slice = std.mem.sliceTo(value, 0);
            const buf = std.testing.allocator.dupeZ(u8, slice) catch unreachable;
            defer std.testing.allocator.free(buf);
            _ = c.setenv("XDG_CONFIG_HOME", buf.ptr, 1);
        } else {
            _ = c.unsetenv("XDG_CONFIG_HOME");
        }
        if (old_home) |value| {
            const slice = std.mem.sliceTo(value, 0);
            const buf = std.testing.allocator.dupeZ(u8, slice) catch unreachable;
            defer std.testing.allocator.free(buf);
            _ = c.setenv("HOME", buf.ptr, 1);
        } else {
            _ = c.unsetenv("HOME");
        }
    }

    const resolved = try resolveSharedAssetPath(std.testing.allocator, "syntax/generated.lua");
    try std.testing.expect(resolved != null);
    defer std.testing.allocator.free(resolved.?);

    const expected = try std.fs.path.join(std.testing.allocator, &.{ user_root, "zide", "tree-sitter-assets", "syntax", "generated.lua" });
    defer std.testing.allocator.free(expected);
    try std.testing.expectEqualStrings(expected, resolved.?);
}
