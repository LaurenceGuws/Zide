const std = @import("std");
const builtin = @import("builtin");
const grammar_fetch = @import("grammar_fetch.zig");

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
    git_missing_only: bool = false,
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
        } else if (std.mem.eql(u8, arg, "--git-missing-only")) {
            mode.git_missing_only = true;
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
        \\  --git-missing-only   During fetch, only clone missing grammars (skip updates)
        \\  --targets <list>  Comma list of targets (os/arch) to build
        \\  --skip-targets <list> Comma list of targets (os/arch) to skip
        \\  --jobs <n>        Parallel jobs for git fetch + grammar pack builds
        \\  --dist <path>     Override dist directory (default tools/grammar_packs/dist)
        \\  --cache-root <path> Override cache root (default %LOCALAPPDATA%/Zide/grammars on Windows, ~/.config/zide/grammars otherwise)
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
        const git_jobs = try parseJobs(jobs);
        try grammar_fetch.fetchGrammars(allocator, scripts_root, git_jobs, mode.git_missing_only, mode.continue_on_error);
    }

    var env_map = try std.process.getEnvMap(allocator);
    defer env_map.deinit();
    try env_map.put("ZIDE_GRAMMAR_CONTINUE", if (mode.continue_on_error) "1" else "0");
    if (targets) |value| {
        try env_map.put("ZIDE_GRAMMAR_TARGETS", value);
    } else if (builtin.os.tag == .windows) {
        try env_map.put("ZIDE_GRAMMAR_TARGETS", "windows/x86_64");
    }
    if (skip_targets) |value| {
        try env_map.put("ZIDE_GRAMMAR_SKIP_TARGETS", value);
    }
    if (jobs) |value| {
        try env_map.put("ZIDE_GRAMMAR_JOBS", value);
    }
    try runScript(allocator, scripts_root, "build_all.sh", &env_map);
}

fn parseJobs(jobs: ?[]const u8) !usize {
    if (jobs) |value| {
        const parsed = try std.fmt.parseInt(usize, value, 10);
        return @max(parsed, 1);
    }
    return 1;
}

fn runScript(
    allocator: std.mem.Allocator,
    scripts_root: []const u8,
    name: []const u8,
    env_map: ?*std.process.EnvMap,
) !void {
    const script_name = if (builtin.os.tag == .windows)
        try std.fmt.allocPrint(allocator, "{s}.ps1", .{std.fs.path.stem(name)})
    else
        try allocator.dupe(u8, name);
    defer allocator.free(script_name);

    const script_path = try std.fs.path.join(allocator, &.{ scripts_root, script_name });
    defer allocator.free(script_path);

    var child = if (builtin.os.tag == .windows)
        std.process.Child.init(&.{ "pwsh", "-NoProfile", "-ExecutionPolicy", "Bypass", "-File", script_name }, allocator)
    else
        std.process.Child.init(&.{script_path}, allocator);
    child.cwd = scripts_root;
    child.stdout_behavior = .Inherit;
    child.stderr_behavior = .Inherit;
    if (env_map) |map| {
        child.env_map = map;
    }
    const result = child.spawnAndWait() catch |err| {
        if (builtin.os.tag == .windows and err == error.FileNotFound) {
            var fallback = std.process.Child.init(&.{ "powershell", "-NoProfile", "-ExecutionPolicy", "Bypass", "-File", script_name }, allocator);
            fallback.cwd = scripts_root;
            fallback.stdout_behavior = .Inherit;
            fallback.stderr_behavior = .Inherit;
            if (env_map) |map| {
                fallback.env_map = map;
            }
            const fallback_result = fallback.spawnAndWait() catch |fallback_err| {
                if (fallback_err == error.FileNotFound) {
                    std.debug.print(
                        "grammar-update: pwsh/powershell not found on PATH. On Windows, install PowerShell and Python 3, then re-run.\n",
                        .{},
                    );
                    return error.BashMissing;
                }
                return fallback_err;
            };
            switch (fallback_result) {
                .Exited => |code| if (code != 0) return error.ScriptFailed,
                else => return error.ScriptFailed,
            }
            return;
        }
        return err;
    };
    switch (result) {
        .Exited => |code| if (code != 0) return error.ScriptFailed,
        else => return error.ScriptFailed,
    }
}

fn installFromDist(allocator: std.mem.Allocator, dist_root: []const u8, cache_root: []const u8) !void {
    const manifest_path = try std.fs.path.join(allocator, &.{ dist_root, "manifest.json" });
    defer allocator.free(manifest_path);

    try ensureDistManifest(allocator, dist_root, manifest_path);

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

fn ensureDistManifest(allocator: std.mem.Allocator, dist_root: []const u8, manifest_path: []const u8) !void {
    if (fileExists(manifest_path)) return;

    const version = try distVersionFromConfig(allocator, dist_root);
    defer allocator.free(version);

    var artifacts = std.ArrayList(Artifact).empty;
    defer {
        for (artifacts.items) |artifact| {
            allocator.free(artifact.path);
            allocator.free(artifact.sha256);
        }
        artifacts.deinit(allocator);
    }

    try collectDistArtifacts(allocator, dist_root, &artifacts);
    std.mem.sort(Artifact, artifacts.items, {}, lessThanArtifactPath);
    try writeManifestFile(allocator, manifest_path, version, artifacts.items);
}

fn distVersionFromConfig(allocator: std.mem.Allocator, dist_root: []const u8) ![]u8 {
    const config_path = try std.fs.path.join(allocator, &.{ dist_root, "..", "config", "grammar_packs.json" });
    defer allocator.free(config_path);

    const config_file = if (std.fs.path.isAbsolute(config_path))
        try std.fs.openFileAbsolute(config_path, .{})
    else
        try std.fs.cwd().openFile(config_path, .{});
    defer config_file.close();

    const config_bytes = try config_file.readToEndAlloc(allocator, std.math.maxInt(usize));
    defer allocator.free(config_bytes);

    const Config = struct {
        version: []const u8,
    };

    const parsed = try std.json.parseFromSlice(Config, allocator, config_bytes, .{
        .ignore_unknown_fields = true,
    });
    defer parsed.deinit();
    return allocator.dupe(u8, parsed.value.version);
}

fn collectDistArtifacts(
    allocator: std.mem.Allocator,
    dist_root: []const u8,
    artifacts: *std.ArrayList(Artifact),
) !void {
    var dir = if (std.fs.path.isAbsolute(dist_root))
        try std.fs.openDirAbsolute(dist_root, .{ .iterate = true })
    else
        try std.fs.cwd().openDir(dist_root, .{ .iterate = true });
    defer dir.close();

    var walker = try dir.walk(allocator);
    defer walker.deinit();

    while (try walker.next()) |entry| {
        if (entry.kind != .file) continue;
        if (!isManifestArtifact(entry.basename)) continue;

        const full_path = try std.fs.path.join(allocator, &.{ dist_root, entry.path });
        defer allocator.free(full_path);

        const sha256 = try sha256FileHex(allocator, full_path);
        errdefer allocator.free(sha256);

        const rel_path = try normalizeToPosixOwned(allocator, entry.path);
        errdefer allocator.free(rel_path);

        const file = if (std.fs.path.isAbsolute(full_path))
            try std.fs.openFileAbsolute(full_path, .{})
        else
            try std.fs.cwd().openFile(full_path, .{});
        defer file.close();
        const stat = try file.stat();

        try artifacts.append(allocator, .{
            .path = rel_path,
            .sha256 = sha256,
            .size = stat.size,
        });
    }
}

fn lessThanArtifactPath(_: void, a: Artifact, b: Artifact) bool {
    return std.mem.lessThan(u8, a.path, b.path);
}

fn isManifestArtifact(name: []const u8) bool {
    return std.mem.endsWith(u8, name, ".dll") or
        std.mem.endsWith(u8, name, ".so") or
        std.mem.endsWith(u8, name, ".dylib") or
        std.mem.endsWith(u8, name, ".scm");
}

fn normalizeToPosixOwned(allocator: std.mem.Allocator, path: []const u8) ![]u8 {
    const owned = try allocator.dupe(u8, path);
    if (std.fs.path.sep != '/') {
        std.mem.replaceScalar(u8, owned, '\\', '/');
    }
    return owned;
}

fn sha256FileHex(allocator: std.mem.Allocator, path: []const u8) ![]u8 {
    const file = if (std.fs.path.isAbsolute(path))
        try std.fs.openFileAbsolute(path, .{})
    else
        try std.fs.cwd().openFile(path, .{});
    defer file.close();

    var hasher = std.crypto.hash.sha2.Sha256.init(.{});
    var buf: [64 * 1024]u8 = undefined;
    while (true) {
        const read = try file.read(&buf);
        if (read == 0) break;
        hasher.update(buf[0..read]);
    }

    var digest: [32]u8 = undefined;
    hasher.final(&digest);

    const out = try allocator.alloc(u8, digest.len * 2);
    const alphabet = "0123456789abcdef";
    for (digest, 0..) |byte, idx| {
        out[idx * 2] = alphabet[byte >> 4];
        out[idx * 2 + 1] = alphabet[byte & 0x0f];
    }
    return out;
}

fn writeManifestFile(
    allocator: std.mem.Allocator,
    manifest_path: []const u8,
    version: []const u8,
    artifacts: []const Artifact,
) !void {
    var out = std.ArrayList(u8).empty;
    defer out.deinit(allocator);
    var writer = out.writer(allocator);
    try writer.print("{{\n  \"version\": \"{s}\",\n  \"artifacts\": [\n", .{version});
    for (artifacts, 0..) |artifact, idx| {
        if (idx != 0) try writer.writeAll(",\n");
        try writer.print(
            "    {{\"path\": \"{s}\", \"sha256\": \"{s}\", \"size\": {d}}}",
            .{ artifact.path, artifact.sha256, artifact.size },
        );
    }
    try writer.writeAll("\n  ]\n}\n");

    const parent = std.fs.path.dirname(manifest_path) orelse return error.InvalidPath;
    try std.fs.cwd().makePath(parent);

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

fn fileExists(path: []const u8) bool {
    const file = if (std.fs.path.isAbsolute(path))
        std.fs.openFileAbsolute(path, .{})
    else
        std.fs.cwd().openFile(path, .{});
    const handle = file catch return false;
    handle.close();
    return true;
}

fn defaultCacheRoot(allocator: std.mem.Allocator) ![]u8 {
    if (builtin.os.tag == .windows) {
        if (std.c.getenv("LOCALAPPDATA")) |local_appdata| {
            const base = std.mem.sliceTo(local_appdata, 0);
            return std.fs.path.join(allocator, &.{ base, "Zide", "grammars" });
        }
        if (std.c.getenv("APPDATA")) |appdata| {
            const base = std.mem.sliceTo(appdata, 0);
            return std.fs.path.join(allocator, &.{ base, "Zide", "grammars" });
        }
    }
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
