const std = @import("std");
const app_logger = @import("app_logger.zig");
const text_store = @import("editor/text_store.zig");

const TextStore = text_store.TextStore;

const Config = struct {
    scenario: Scenario = .all,
    file_path: ?[]const u8 = null,
    size_mb: usize = 64,
    line_len: usize = 120,
    queries: usize = 200_000,
    frames: usize = 600,
    visible_lines: usize = 80,
    stride_lines: usize = 3,
    seed: u64 = 0x5EED_1234_9ABC_DEF0,
};

const Scenario = enum {
    all,
    open,
    line_start,
    viewport,
};

const OpenResult = struct {
    open_ns: i128,
    rss_before_kb: ?usize,
    rss_after_open_kb: ?usize,
    rss_after_close_kb: ?usize,
    total_len: usize,
    line_count: usize,
};

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    app_logger.setConsoleFilterString("none") catch {};
    app_logger.setFileFilterString("none") catch {};

    const config = try parseArgs(allocator);
    defer if (config.file_path) |path| allocator.free(path);

    var owned_input_path: ?[]u8 = null;
    defer if (owned_input_path) |path| allocator.free(path);

    const input_path = if (config.file_path) |path|
        path
    else blk: {
        const generated = try ensureSyntheticFixture(
            allocator,
            config.size_mb,
            config.line_len,
        );
        owned_input_path = generated;
        break :blk generated;
    };

    const stat = try std.fs.cwd().statFile(input_path);

    std.debug.print(
        "PERF meta path=\"{s}\" size_bytes={d} scenario={s} queries={d} frames={d} visible_lines={d} stride_lines={d}\n",
        .{
            input_path,
            stat.size,
            @tagName(config.scenario),
            config.queries,
            config.frames,
            config.visible_lines,
            config.stride_lines,
        },
    );

    var open_result: ?OpenResult = null;
    if (config.scenario == .all or config.scenario == .open) {
        open_result = try runOpenScenario(allocator, input_path);
        const result = open_result.?;
        std.debug.print(
            "PERF open open_ms={d:.3} total_len={d} line_count={d} rss_before_kb={any} rss_after_open_kb={any} rss_after_close_kb={any}\n",
            .{
                nsToMs(result.open_ns),
                result.total_len,
                result.line_count,
                result.rss_before_kb,
                result.rss_after_open_kb,
                result.rss_after_close_kb,
            },
        );
    }

    if (config.scenario == .all or config.scenario == .line_start or config.scenario == .viewport) {
        var store = try TextStore.initFromFile(allocator, input_path);
        defer store.deinit();

        if (config.scenario == .all or config.scenario == .line_start) {
            const line_random = runLineStartRandomScenario(store, config.queries, config.seed);
            std.debug.print(
                "PERF line_start_random queries={d} total_ms={d:.3} ns_per_op={d:.1} checksum={d}\n",
                .{
                    config.queries,
                    nsToMs(line_random.total_ns),
                    @as(f64, @floatFromInt(line_random.total_ns)) / @as(f64, @floatFromInt(config.queries)),
                    line_random.checksum,
                },
            );
            const line_seq = runLineStartSequentialScenario(store, config.queries);
            std.debug.print(
                "PERF line_start_sequential queries={d} total_ms={d:.3} ns_per_op={d:.1} checksum={d}\n",
                .{
                    config.queries,
                    nsToMs(line_seq.total_ns),
                    @as(f64, @floatFromInt(line_seq.total_ns)) / @as(f64, @floatFromInt(config.queries)),
                    line_seq.checksum,
                },
            );
        }

        if (config.scenario == .all or config.scenario == .viewport) {
            const viewport_result = try runViewportScenario(
                allocator,
                store,
                config.frames,
                config.visible_lines,
                config.stride_lines,
            );
            std.debug.print(
                "PERF viewport frames={d} visible_lines={d} total_ms={d:.3} ms_per_frame={d:.4} bytes_read={d} checksum={d}\n",
                .{
                    config.frames,
                    config.visible_lines,
                    nsToMs(viewport_result.total_ns),
                    @as(f64, @floatFromInt(viewport_result.total_ns)) /
                        @as(f64, @floatFromInt(config.frames)) / 1_000_000.0,
                    viewport_result.bytes_read,
                    viewport_result.checksum,
                },
            );
        }
    }
}

fn parseArgs(allocator: std.mem.Allocator) !Config {
    var config: Config = .{};
    var args = std.process.args();
    _ = args.next();
    while (args.next()) |arg| {
        if (std.mem.eql(u8, arg, "--scenario")) {
            const raw = args.next() orelse return error.MissingScenario;
            config.scenario = parseScenario(raw) orelse return error.InvalidScenario;
            continue;
        }
        if (std.mem.eql(u8, arg, "--file")) {
            const path = args.next() orelse return error.MissingFilePath;
            config.file_path = try allocator.dupe(u8, path);
            continue;
        }
        if (std.mem.eql(u8, arg, "--size-mb")) {
            const raw = args.next() orelse return error.MissingSizeMb;
            config.size_mb = try std.fmt.parseInt(usize, raw, 10);
            continue;
        }
        if (std.mem.eql(u8, arg, "--line-len")) {
            const raw = args.next() orelse return error.MissingLineLen;
            config.line_len = try std.fmt.parseInt(usize, raw, 10);
            continue;
        }
        if (std.mem.eql(u8, arg, "--queries")) {
            const raw = args.next() orelse return error.MissingQueries;
            config.queries = try std.fmt.parseInt(usize, raw, 10);
            continue;
        }
        if (std.mem.eql(u8, arg, "--frames")) {
            const raw = args.next() orelse return error.MissingFrames;
            config.frames = try std.fmt.parseInt(usize, raw, 10);
            continue;
        }
        if (std.mem.eql(u8, arg, "--visible-lines")) {
            const raw = args.next() orelse return error.MissingVisibleLines;
            config.visible_lines = try std.fmt.parseInt(usize, raw, 10);
            continue;
        }
        if (std.mem.eql(u8, arg, "--stride-lines")) {
            const raw = args.next() orelse return error.MissingStrideLines;
            config.stride_lines = try std.fmt.parseInt(usize, raw, 10);
            continue;
        }
        if (std.mem.eql(u8, arg, "--seed")) {
            const raw = args.next() orelse return error.MissingSeed;
            config.seed = try std.fmt.parseInt(u64, raw, 10);
            continue;
        }
        if (std.mem.eql(u8, arg, "--help") or std.mem.eql(u8, arg, "-h")) {
            printHelp();
            std.process.exit(0);
        }
        return error.UnknownArgument;
    }

    if (config.line_len < 2) config.line_len = 2;
    if (config.queries == 0) config.queries = 1;
    if (config.frames == 0) config.frames = 1;
    if (config.visible_lines == 0) config.visible_lines = 1;
    if (config.stride_lines == 0) config.stride_lines = 1;
    return config;
}

fn parseScenario(raw: []const u8) ?Scenario {
    if (std.mem.eql(u8, raw, "all")) return .all;
    if (std.mem.eql(u8, raw, "open")) return .open;
    if (std.mem.eql(u8, raw, "line-start")) return .line_start;
    if (std.mem.eql(u8, raw, "viewport")) return .viewport;
    return null;
}

fn printHelp() void {
    std.debug.print(
        "editor perf harness (headless)\n" ++
            "  --scenario all|open|line-start|viewport\n" ++
            "  --file <path>              (default: generated synthetic fixture)\n" ++
            "  --size-mb <int>            (default: 64, synthetic only)\n" ++
            "  --line-len <int>           (default: 120, synthetic only)\n" ++
            "  --queries <int>            (default: 200000)\n" ++
            "  --frames <int>             (default: 600)\n" ++
            "  --visible-lines <int>      (default: 80)\n" ++
            "  --stride-lines <int>       (default: 3)\n" ++
            "  --seed <int>               (default: fixed)\n",
        .{},
    );
}

fn ensureSyntheticFixture(
    allocator: std.mem.Allocator,
    size_mb: usize,
    line_len: usize,
) ![]u8 {
    const dir_path = "zig-cache/editor-perf";
    try std.fs.cwd().makePath(dir_path);
    const file_name = try std.fmt.allocPrint(
        allocator,
        "synth_{d}mb_l{d}.txt",
        .{ size_mb, line_len },
    );
    defer allocator.free(file_name);
    const path = try std.fs.path.join(allocator, &.{ dir_path, file_name });
    errdefer allocator.free(path);

    const target_bytes = size_mb * 1024 * 1024;
    if (std.fs.cwd().statFile(path)) |st| {
        if (st.size == target_bytes) return path;
    } else |_| {}

    var file = try std.fs.cwd().createFile(path, .{ .truncate = true });
    defer file.close();
    const payload_len = line_len - 1;
    var line = try allocator.alloc(u8, line_len);
    defer allocator.free(line);
    @memset(line[0..payload_len], 'x');
    line[payload_len] = '\n';

    var remaining = target_bytes;
    while (remaining > 0) {
        const write_len = @min(remaining, line_len);
        try file.writeAll(line[0..write_len]);
        remaining -= write_len;
    }
    return path;
}

fn runOpenScenario(allocator: std.mem.Allocator, path: []const u8) !OpenResult {
    const rss_before = try readRssKb();
    const t0 = std.time.nanoTimestamp();
    var store = try TextStore.initFromFile(allocator, path);
    const t1 = std.time.nanoTimestamp();
    const total_len = store.totalLen();
    const line_count = store.lineCount();
    const rss_after_open = try readRssKb();
    store.deinit();
    const rss_after_close = try readRssKb();

    return .{
        .open_ns = t1 - t0,
        .rss_before_kb = rss_before,
        .rss_after_open_kb = rss_after_open,
        .rss_after_close_kb = rss_after_close,
        .total_len = total_len,
        .line_count = line_count,
    };
}

const LineStartResult = struct {
    total_ns: i128,
    checksum: u64,
};

fn runLineStartRandomScenario(store: *TextStore, queries: usize, seed: u64) LineStartResult {
    const line_count = @max(@as(usize, 1), store.lineCount());
    var prng = std.Random.DefaultPrng.init(seed);
    const rand = prng.random();

    var checksum: u64 = 0;
    const t0 = std.time.nanoTimestamp();
    for (0..queries) |_| {
        const line = rand.uintLessThan(usize, line_count);
        checksum +%= @as(u64, @intCast(store.lineStart(line)));
    }
    const t1 = std.time.nanoTimestamp();
    return .{
        .total_ns = t1 - t0,
        .checksum = checksum,
    };
}

fn runLineStartSequentialScenario(store: *TextStore, queries: usize) LineStartResult {
    const line_count = @max(@as(usize, 1), store.lineCount());
    var checksum: u64 = 0;
    var line: usize = 0;
    const t0 = std.time.nanoTimestamp();
    for (0..queries) |_| {
        checksum +%= @as(u64, @intCast(store.lineStart(line)));
        line += 1;
        if (line >= line_count) line = 0;
    }
    const t1 = std.time.nanoTimestamp();
    return .{
        .total_ns = t1 - t0,
        .checksum = checksum,
    };
}

const ViewportResult = struct {
    total_ns: i128,
    bytes_read: usize,
    checksum: u64,
};

fn runViewportScenario(
    allocator: std.mem.Allocator,
    store: *TextStore,
    frames: usize,
    visible_lines: usize,
    stride_lines: usize,
) !ViewportResult {
    const total_lines = @max(@as(usize, 1), store.lineCount());
    const line_cap: usize = 4096;
    var stack_buf: [line_cap]u8 = undefined;
    var checksum: u64 = 0;
    var bytes_read: usize = 0;

    const t0 = std.time.nanoTimestamp();
    for (0..frames) |frame| {
        const max_start = total_lines -| 1;
        const start_line = if (max_start == 0) 0 else @min(frame * stride_lines, max_start) % total_lines;

        for (0..visible_lines) |row| {
            const line_idx = start_line + row;
            if (line_idx >= total_lines) break;
            const line_start = store.lineStart(line_idx);
            const len = store.lineLen(line_idx);
            if (len <= line_cap) {
                const read = store.readLine(line_idx, stack_buf[0..len]);
                bytes_read += read;
                checksum +%= @as(u64, @intCast(line_start + read));
            } else {
                const owned = try allocator.alloc(u8, len);
                defer allocator.free(owned);
                const read = store.readLine(line_idx, owned);
                bytes_read += read;
                checksum +%= @as(u64, @intCast(line_start + read));
            }
        }
    }
    const t1 = std.time.nanoTimestamp();
    return .{
        .total_ns = t1 - t0,
        .bytes_read = bytes_read,
        .checksum = checksum,
    };
}

fn readRssKb() !?usize {
    if (@import("builtin").os.tag != .linux) return null;
    var file = try std.fs.openFileAbsolute("/proc/self/status", .{ .mode = .read_only });
    defer file.close();
    const data = try file.readToEndAlloc(std.heap.page_allocator, 256 * 1024);
    defer std.heap.page_allocator.free(data);

    const key = "VmRSS:";
    if (std.mem.indexOf(u8, data, key)) |idx| {
        const tail = data[idx + key.len ..];
        var i: usize = 0;
        while (i < tail.len and (tail[i] == ' ' or tail[i] == '\t')) : (i += 1) {}
        const start = i;
        while (i < tail.len and tail[i] >= '0' and tail[i] <= '9') : (i += 1) {}
        if (i > start) {
            const value = try std.fmt.parseInt(usize, tail[start..i], 10);
            return value;
        }
    }
    return null;
}

fn nsToMs(ns: i128) f64 {
    return @as(f64, @floatFromInt(ns)) / 1_000_000.0;
}
