const std = @import("std");
const builtin = @import("builtin");

pub fn resolveSharedAssetPath(allocator: std.mem.Allocator, rel_path: []const u8) !?[]u8 {
    if (std.c.getenv("ZIDE_TREE_SITTER_ASSET_ROOT")) |root_c| {
        const root = std.mem.sliceTo(root_c, 0);
        if (try joinIfExists(allocator, root, rel_path)) |path| return path;
    }

    if (try userAssetRoot(allocator)) |root| {
        defer allocator.free(root);
        if (try joinIfExists(allocator, root, rel_path)) |path| return path;
    }

    if (try cwdDevAssetRoot(allocator)) |root| {
        defer allocator.free(root);
        if (try joinIfExists(allocator, root, rel_path)) |path| return path;
    }

    if (try exeDevAssetRoot(allocator)) |root| {
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
            return std.fs.path.join(allocator, &.{ base, "Zide", "tree-sitter-assets" });
        }
        if (std.c.getenv("APPDATA")) |appdata| {
            const base = std.mem.sliceTo(appdata, 0);
            return std.fs.path.join(allocator, &.{ base, "Zide", "tree-sitter-assets" });
        }
    }
    if (std.c.getenv("XDG_CONFIG_HOME")) |xdg| {
        const base = std.mem.sliceTo(xdg, 0);
        return std.fs.path.join(allocator, &.{ base, "zide", "tree-sitter-assets" });
    }
    if (std.c.getenv("HOME")) |home| {
        const base = std.mem.sliceTo(home, 0);
        return std.fs.path.join(allocator, &.{ base, ".config", "zide", "tree-sitter-assets" });
    }
    return null;
}

fn cwdDevAssetRoot(allocator: std.mem.Allocator) !?[]u8 {
    const candidates = [_][]const u8{
        "../zide-tree-sitter/assets",
        "../../zide-tree-sitter/assets",
    };
    for (candidates) |candidate| {
        if (fileExists(candidate)) return allocator.dupe(u8, candidate);
    }
    return null;
}

fn exeDevAssetRoot(allocator: std.mem.Allocator) !?[]u8 {
    const exe_dir = std.fs.selfExeDirPathAlloc(allocator) catch return null;
    defer allocator.free(exe_dir);
    const candidates = [_][]const u8{
        "../zide-tree-sitter/assets",
        "../../zide-tree-sitter/assets",
        "../../../zide-tree-sitter/assets",
    };
    for (candidates) |candidate| {
        const joined = try std.fs.path.join(allocator, &.{ exe_dir, candidate });
        defer allocator.free(joined);
        if (fileExists(joined)) return try allocator.dupe(u8, joined);
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
