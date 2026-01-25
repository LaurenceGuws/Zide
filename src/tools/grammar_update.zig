const std = @import("std");

const Manifest = struct {
    version: []const u8,
    artifacts: []Artifact,
};

const Artifact = struct {
    path: []const u8,
    sha256: []const u8,
    size: u64,
};

const Mode = struct {
    build: bool = true,
    install: bool = true,
    skip_sync: bool = false,
    skip_fetch: bool = false,
    continue_on_error: bool = false,
};

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    const args = try std.process.argsAlloc(allocator);
    defer std.process.argsFree(allocator, args);

    var mode = Mode{};
    var dist_path: ?[]const u8 = null;
    var cache_root: ?[]const u8 = null;
    var targets: ?[]const u8 = null;
    var skip_targets: ?[]const u8 = null;
    var jobs: ?[]const u8 = null;

    var i: usize = 1;
    while (i < args.len) : (i += 1) {
        const arg = args[i];
        if (std.mem.eql(u8, arg, "--install-only")) {
            mode.build = false;
            mode.install = true;
        } else if (std.mem.eql(u8, arg, "--build-only")) {
            mode.build = true;
            mode.install = false;
        } else if (std.mem.eql(u8, arg, "--no-build")) {
            mode.build = false;
        } else if (std.mem.eql(u8, arg, "--skip-sync")) {
            mode.skip_sync = true;
        } else if (std.mem.eql(u8, arg, "--skip-fetch")) {
            mode.skip_fetch = true;
        } else if (std.mem.eql(u8, arg, "--skip-git")) {
            mode.skip_sync = true;
            mode.skip_fetch = true;
        } else if (std.mem.eql(u8, arg, "--continue-on-error")) {
            mode.continue_on_error = true;
        } else if (std.mem.eql(u8, arg, "--targets") and i + 1 < args.len) {
            i += 1;
            targets = args[i];
        } else if (std.mem.eql(u8, arg, "--skip-targets") and i + 1 < args.len) {
            i += 1;
            skip_targets = args[i];
        } else if (std.mem.eql(u8, arg, "--jobs") and i + 1 < args.len) {
            i += 1;
            jobs = args[i];
        } else if (std.mem.eql(u8, arg, "--dist") and i + 1 < args.len) {
            i += 1;
            dist_path = args[i];
        } else if (std.mem.eql(u8, arg, "--cache-root") and i + 1 < args.len) {
            i += 1;
            cache_root = args[i];
        } else if (std.mem.eql(u8, arg, "--help")) {
            printUsage();
            return;
        } else {
            std.debug.print("Unknown argument: {s}\n", .{arg});
            printUsage();
            return error.InvalidArguments;
        }
    }

    const repo_root = try std.fs.cwd().realpathAlloc(allocator, ".");
    defer allocator.free(repo_root);

    if (mode.build) {
        try runBuildScripts(allocator, repo_root, mode, targets, skip_targets, jobs);
    }

    if (mode.install) {
        const dist_root = dist_path orelse try std.fs.path.join(allocator, &.{ repo_root, "tools/grammar_packs/dist" });
        defer if (dist_path == null) allocator.free(dist_root);
        const cache = cache_root orelse try defaultCacheRoot(allocator);
        defer if (cache_root == null) allocator.free(cache);

        try installFromDist(allocator, dist_root, cache);
    }
}

fn printUsage() void {
    std.debug.print(
        \\Usage: grammar-update [options]
        \\  --install-only    Skip build, install from dist
        \\  --build-only      Build packs but do not install
        \\  --no-build        Skip build step (install only if enabled)
        \\  --skip-sync       Skip syncing parsers/queries from nvim-treesitter
        \\  --skip-fetch      Skip git clone/fetch of grammar repos
        \\  --skip-git        Skip sync + fetch steps
        \\  --continue-on-error  Continue building if a grammar fails
        \\  --targets <list>  Comma list of targets (os/arch) to build
        \\  --skip-targets <list> Comma list of targets (os/arch) to skip
        \\  --jobs <n>        Parallel build jobs for grammar packs
        \\  --dist <path>     Override dist directory (default tools/grammar_packs/dist)
        \\  --cache-root <path> Override cache root (default ~/.config/zide/grammars)
        \\  --help            Show this help
        \\
    , .{});
}

fn runBuildScripts(
    allocator: std.mem.Allocator,
    repo_root: []const u8,
    mode: Mode,
    targets: ?[]const u8,
    skip_targets: ?[]const u8,
    jobs: ?[]const u8,
) !void {
    const scripts_root = try std.fs.path.join(allocator, &.{ repo_root, "tools/grammar_packs/scripts" });
    defer allocator.free(scripts_root);

    if (!mode.skip_sync) {
        try runScript(allocator, scripts_root, "sync_from_nvim.sh", null);
    }
    if (!mode.skip_fetch) {
        try runScript(allocator, scripts_root, "fetch_grammars.sh", null);
    }

    var env_map = try std.process.getEnvMap(allocator);
    defer env_map.deinit();
    try env_map.put("ZIDE_GRAMMAR_CONTINUE", if (mode.continue_on_error) "1" else "0");
    if (targets) |value| {
        try env_map.put("ZIDE_GRAMMAR_TARGETS", value);
    }
    if (skip_targets) |value| {
        try env_map.put("ZIDE_GRAMMAR_SKIP_TARGETS", value);
    }
    if (jobs) |value| {
        try env_map.put("ZIDE_GRAMMAR_JOBS", value);
    }
    try runScript(allocator, scripts_root, "build_all.sh", &env_map);
}

fn runScript(
    allocator: std.mem.Allocator,
    scripts_root: []const u8,
    name: []const u8,
    env_map: ?*std.process.EnvMap,
) !void {
    const script_path = try std.fs.path.join(allocator, &.{ scripts_root, name });
    defer allocator.free(script_path);

    var child = std.process.Child.init(&.{ script_path }, allocator);
    child.cwd = scripts_root;
    child.stdout_behavior = .Inherit;
    child.stderr_behavior = .Inherit;
    if (env_map) |map| {
        child.env_map = map;
    }
    const result = try child.spawnAndWait();
    switch (result) {
        .Exited => |code| if (code != 0) return error.ScriptFailed,
        else => return error.ScriptFailed,
    }
}

fn installFromDist(allocator: std.mem.Allocator, dist_root: []const u8, cache_root: []const u8) !void {
    const manifest_path = try std.fs.path.join(allocator, &.{ dist_root, "manifest.json" });
    defer allocator.free(manifest_path);

    const manifest_file = if (std.fs.path.isAbsolute(manifest_path))
        try std.fs.openFileAbsolute(manifest_path, .{})
    else
        try std.fs.cwd().openFile(manifest_path, .{});
    defer manifest_file.close();
    const manifest_bytes = try manifest_file.readToEndAlloc(allocator, std.math.maxInt(usize));
    defer allocator.free(manifest_bytes);

    const parsed = try std.json.parseFromSlice(Manifest, allocator, manifest_bytes, .{});
    defer parsed.deinit();

    var grouped = std.StringHashMap(std.ArrayList(Artifact)).init(allocator);
    defer {
        var it = grouped.iterator();
        while (it.next()) |entry| {
            allocator.free(entry.key_ptr.*);
            entry.value_ptr.deinit(allocator);
        }
        grouped.deinit();
    }

    for (parsed.value.artifacts) |artifact| {
        const rel = artifact.path;
        const parts = splitPathTwo(rel);
        if (parts == null) continue;
        const key = try std.fmt.allocPrint(allocator, "{s}/{s}", .{ parts.?.lang, parts.?.version });

        var list = if (grouped.getPtr(key)) |existing| blk: {
            allocator.free(key);
            break :blk existing;
        } else blk: {
            const new_list = std.ArrayList(Artifact).empty;
            try grouped.put(key, new_list);
            break :blk grouped.getPtr(key).?;
        };
        try list.append(allocator, artifact);

        const src_path = try std.fs.path.join(allocator, &.{ dist_root, rel });
        defer allocator.free(src_path);
        const dest_path = try std.fs.path.join(allocator, &.{ cache_root, rel });
        defer allocator.free(dest_path);

        try std.fs.cwd().makePath(std.fs.path.dirname(dest_path).?);
        try copyFile(src_path, dest_path);
    }

    try writeRootManifest(allocator, dist_root, cache_root);
    try writePackManifests(allocator, cache_root, parsed.value.version, &grouped);
}

fn writeRootManifest(allocator: std.mem.Allocator, dist_root: []const u8, cache_root: []const u8) !void {
    const src = try std.fs.path.join(allocator, &.{ dist_root, "manifest.json" });
    defer allocator.free(src);
    const dest = try std.fs.path.join(allocator, &.{ cache_root, "manifest.json" });
    defer allocator.free(dest);
    try std.fs.cwd().makePath(cache_root);
    try copyFile(src, dest);
}

fn writePackManifests(
    allocator: std.mem.Allocator,
    cache_root: []const u8,
    version: []const u8,
    grouped: *std.StringHashMap(std.ArrayList(Artifact)),
) !void {
    var it = grouped.iterator();
    while (it.next()) |entry| {
        const key = entry.key_ptr.*;
        const artifacts = entry.value_ptr.items;
        const pack_dir = try std.fs.path.join(allocator, &.{ cache_root, key });
        defer allocator.free(pack_dir);

        try std.fs.cwd().makePath(pack_dir);
        const manifest_path = try std.fs.path.join(allocator, &.{ pack_dir, "manifest.json" });
        defer allocator.free(manifest_path);

        var out = std.ArrayList(u8).empty;
        defer out.deinit(allocator);
        var writer = out.writer(allocator);
        try writer.print("{{\n  \"version\": \"{s}\",\n  \"artifacts\": [\n", .{version});

        for (artifacts, 0..) |artifact, idx| {
            const basename = std.fs.path.basename(artifact.path);
            if (idx != 0) try writer.writeAll(",\n");
            try writer.print(
                "    {{\"path\": \"{s}\", \"sha256\": \"{s}\", \"size\": {d}}}",
                .{ basename, artifact.sha256, artifact.size },
            );
        }
        try writer.writeAll("\n  ]\n}\n");

        if (std.fs.path.isAbsolute(manifest_path)) {
            const file = try std.fs.createFileAbsolute(manifest_path, .{ .truncate = true });
            defer file.close();
            try file.writeAll(out.items);
        } else {
            const file = try std.fs.cwd().createFile(manifest_path, .{ .truncate = true });
            defer file.close();
            try file.writeAll(out.items);
        }
    }
}

fn copyFile(src_path: []const u8, dest_path: []const u8) !void {
    if (std.fs.path.isAbsolute(src_path) and std.fs.path.isAbsolute(dest_path)) {
        return std.fs.copyFileAbsolute(src_path, dest_path, .{});
    }
    return std.fs.cwd().copyFile(src_path, std.fs.cwd(), dest_path, .{});
}

fn defaultCacheRoot(allocator: std.mem.Allocator) ![]u8 {
    if (std.c.getenv("XDG_CONFIG_HOME")) |xdg| {
        const base = std.mem.sliceTo(xdg, 0);
        return std.fs.path.join(allocator, &.{ base, "zide", "grammars" });
    }
    if (std.c.getenv("HOME")) |home| {
        const base = std.mem.sliceTo(home, 0);
        return std.fs.path.join(allocator, &.{ base, ".config", "zide", "grammars" });
    }
    return allocator.dupe(u8, ".zide/grammars");
}

const PackParts = struct {
    lang: []const u8,
    version: []const u8,
};

fn splitPathTwo(path: []const u8) ?PackParts {
    var it = std.mem.splitScalar(u8, path, '/');
    const lang = it.next() orelse return null;
    const version = it.next() orelse return null;
    return .{ .lang = lang, .version = version };
}
