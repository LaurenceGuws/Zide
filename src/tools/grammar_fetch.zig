const std = @import("std");

const Task = struct {
    lang: []const u8,
    url: []const u8,
    revision: ?[]const u8,
};

const WorkerCtx = struct {
    allocator: std.mem.Allocator,
    tasks: []const Task,
    out_dir: []const u8,
    missing_only: bool,
    next_index: std.atomic.Value(usize),
    first_error: ?anyerror,
    err_mutex: std.Thread.Mutex,
};

pub fn fetchGrammars(allocator: std.mem.Allocator, scripts_root: []const u8, jobs: usize, missing_only: bool) !void {
    const grammar_root = try std.fs.path.join(allocator, &.{ scripts_root, ".." });
    defer allocator.free(grammar_root);
    const work_dir = try std.fs.path.join(allocator, &.{ grammar_root, "work" });
    defer allocator.free(work_dir);
    const out_dir = try std.fs.path.join(allocator, &.{ work_dir, "grammars" });
    defer allocator.free(out_dir);
    const runtime_dir = try std.fs.path.join(allocator, &.{ work_dir, "tree-sitter" });
    defer allocator.free(runtime_dir);
    const parsers_path = try std.fs.path.join(allocator, &.{ work_dir, "parsers.lua" });
    defer allocator.free(parsers_path);

    try std.fs.cwd().makePath(out_dir);
    try ensureRuntime(allocator, runtime_dir);

    const parser_bytes = std.fs.cwd().readFileAlloc(allocator, parsers_path, std.math.maxInt(usize)) catch |err| switch (err) {
        error.FileNotFound => {
            std.debug.print("Missing work/parsers.lua. Run scripts/sync_from_nvim.sh first.\n", .{});
            return err;
        },
        else => return err,
    };
    defer allocator.free(parser_bytes);

    var tasks = std.ArrayList(Task).empty;
    defer tasks.deinit(allocator);
    try parseParsersLua(allocator, parser_bytes, &tasks);

    if (tasks.items.len == 0) return;

    const worker_count = @min(@max(jobs, 1), tasks.items.len);
    if (worker_count > 1) {
        std.debug.print("Fetching grammars with {d} parallel jobs\n", .{worker_count});
    }

    var ctx = WorkerCtx{
        .allocator = allocator,
        .tasks = tasks.items,
        .out_dir = out_dir,
        .missing_only = missing_only,
        .next_index = std.atomic.Value(usize).init(0),
        .first_error = null,
        .err_mutex = .{},
    };

    var threads = try allocator.alloc(std.Thread, worker_count);
    defer allocator.free(threads);
    for (threads, 0..) |*thread, i| {
        if (i == 0) {
            workerMain(&ctx);
            thread.* = undefined;
        } else {
            thread.* = try std.Thread.spawn(.{}, workerMain, .{&ctx});
        }
    }
    for (threads[1..]) |thread| thread.join();

    if (ctx.first_error) |err| return err;
}

fn workerMain(ctx: *WorkerCtx) void {
    while (true) {
        const idx = ctx.next_index.fetchAdd(1, .acq_rel);
        if (idx >= ctx.tasks.len) return;
        const task = ctx.tasks[idx];
        fetchOne(ctx.allocator, ctx.out_dir, task, ctx.missing_only) catch |err| {
            ctx.err_mutex.lock();
            defer ctx.err_mutex.unlock();
            if (ctx.first_error == null) {
                ctx.first_error = err;
            }
            return;
        };
    }
}

fn fetchOne(allocator: std.mem.Allocator, out_dir: []const u8, task: Task, missing_only: bool) !void {
    const name = std.fs.path.basename(task.url);
    const dest = try std.fs.path.join(allocator, &.{ out_dir, name });
    defer allocator.free(dest);
    const git_dir = try std.fs.path.join(allocator, &.{ dest, ".git" });
    defer allocator.free(git_dir);

    if (pathExists(git_dir)) {
        if (missing_only) {
            std.debug.print("[{s}] Skipping existing {s}\n", .{ task.lang, dest });
            return;
        }
        std.debug.print("[{s}] Updating {s}\n", .{ task.lang, dest });
        try runGit(allocator, &.{ "git", "-C", dest, "fetch", "--depth", "1", "origin" });
    } else {
        std.debug.print("[{s}] Cloning {s}\n", .{ task.lang, task.url });
        try runGit(allocator, &.{ "git", "clone", "--depth", "1", task.url, dest });
    }

    if (task.revision) |rev| {
        try runGit(allocator, &.{ "git", "-C", dest, "fetch", "--depth", "1", "origin", rev });
        try runGit(allocator, &.{ "git", "-C", dest, "checkout", "-f", "FETCH_HEAD" });
    }
}

fn ensureRuntime(allocator: std.mem.Allocator, runtime_dir: []const u8) !void {
    const git_dir = try std.fs.path.join(allocator, &.{ runtime_dir, ".git" });
    defer allocator.free(git_dir);

    if (pathExists(git_dir)) {
        std.debug.print("Updating Tree-sitter runtime\n", .{});
        try runGit(allocator, &.{ "git", "-C", runtime_dir, "fetch", "--depth", "1", "origin" });
        try runGit(allocator, &.{ "git", "-C", runtime_dir, "reset", "--hard", "origin/HEAD" });
    } else {
        std.debug.print("Cloning Tree-sitter runtime\n", .{});
        const parent = std.fs.path.dirname(runtime_dir) orelse return error.InvalidPath;
        try std.fs.cwd().makePath(parent);
        try runGit(allocator, &.{ "git", "clone", "--depth", "1", "https://github.com/tree-sitter/tree-sitter.git", runtime_dir });
    }
}

fn runGit(allocator: std.mem.Allocator, argv: []const []const u8) !void {
    var child = std.process.Child.init(argv, allocator);
    child.stdout_behavior = .Inherit;
    child.stderr_behavior = .Inherit;
    const res = try child.spawnAndWait();
    switch (res) {
        .Exited => |code| if (code != 0) return error.GitFailed,
        else => return error.GitFailed,
    }
}

fn pathExists(path: []const u8) bool {
    std.fs.cwd().access(path, .{}) catch return false;
    return true;
}

fn parseParsersLua(allocator: std.mem.Allocator, bytes: []const u8, out: *std.ArrayList(Task)) !void {
    var in_lang = false;
    var in_install = false;
    var current_lang: ?[]const u8 = null;
    var install_url: ?[]const u8 = null;
    var install_rev: ?[]const u8 = null;

    var line_it = std.mem.splitScalar(u8, bytes, '\n');
    while (line_it.next()) |line| {
        const indent = leadingSpaces(line);
        const trimmed = std.mem.trim(u8, line, " \t\r");
        if (trimmed.len == 0) continue;

        if (!in_lang and indent == 2 and std.mem.endsWith(u8, trimmed, "= {")) {
            const lhs = std.mem.trimRight(u8, trimmed[0 .. trimmed.len - 3], " ");
            if (isLuaIdent(lhs)) {
                current_lang = lhs;
                in_lang = true;
                in_install = false;
                install_url = null;
                install_rev = null;
            }
            continue;
        }

        if (!in_lang) continue;

        if (!in_install and std.mem.eql(u8, trimmed, "install_info = {")) {
            in_install = true;
            continue;
        }

        if (in_install) {
            if (std.mem.startsWith(u8, trimmed, "}")) {
                in_install = false;
                continue;
            }
            if (parseLuaStringKV(trimmed)) |kv| {
                if (std.mem.eql(u8, kv.key, "url")) install_url = kv.value;
                if (std.mem.eql(u8, kv.key, "revision")) install_rev = kv.value;
            }
            continue;
        }

        if (indent == 2 and std.mem.startsWith(u8, trimmed, "}")) {
            if (current_lang != null and install_url != null) {
                try out.append(allocator, .{
                    .lang = current_lang.?,
                    .url = install_url.?,
                    .revision = install_rev,
                });
            }
            in_lang = false;
            current_lang = null;
            install_url = null;
            install_rev = null;
            continue;
        }
    }
}

const LuaKV = struct {
    key: []const u8,
    value: []const u8,
};

fn parseLuaStringKV(line: []const u8) ?LuaKV {
    const eq_idx = std.mem.indexOfScalar(u8, line, '=') orelse return null;
    const key = std.mem.trim(u8, line[0..eq_idx], " ");
    var rhs = std.mem.trim(u8, line[eq_idx + 1 ..], " ");
    if (rhs.len > 0 and rhs[rhs.len - 1] == ',') rhs = rhs[0 .. rhs.len - 1];
    rhs = std.mem.trim(u8, rhs, " ");
    if (rhs.len < 2 or rhs[0] != '\'' or rhs[rhs.len - 1] != '\'') return null;
    return .{ .key = key, .value = rhs[1 .. rhs.len - 1] };
}

fn leadingSpaces(line: []const u8) usize {
    var i: usize = 0;
    while (i < line.len and line[i] == ' ') : (i += 1) {}
    return i;
}

fn isLuaIdent(s: []const u8) bool {
    if (s.len == 0) return false;
    if (!isAlpha(s[0]) and s[0] != '_') return false;
    for (s[1..]) |ch| {
        if (!isAlpha(ch) and !isDigit(ch) and ch != '_') return false;
    }
    return true;
}

fn isAlpha(ch: u8) bool {
    return (ch >= 'a' and ch <= 'z') or (ch >= 'A' and ch <= 'Z');
}

fn isDigit(ch: u8) bool {
    return ch >= '0' and ch <= '9';
}
