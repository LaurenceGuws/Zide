const std = @import("std");
const builtin = @import("builtin");
const app_logger = @import("../app_logger.zig");

const ts_api = @import("treesitter_api.zig");
const c = ts_api.c_api;

pub const TSLanguage = ts_api.TSLanguage;

extern "c" fn tree_sitter_zig() *const c.TSLanguage;

const LanguageFn = *const fn () callconv(.c) *const c.TSLanguage;

pub const LoadedGrammar = struct {
    language_name: []u8,
    version: ?[]u8,
    lib_path: ?[]u8,
    query_path: ?[]u8,
    handle: ?std.DynLib,
    ts_language: *const c.TSLanguage,
};

pub const GrammarManager = struct {
    allocator: std.mem.Allocator,
    cache_root: []u8,
    loaded: std.StringHashMap(*LoadedGrammar),

    pub fn init(allocator: std.mem.Allocator) !GrammarManager {
        const cache_root = try defaultCacheRoot(allocator);
        return .{
            .allocator = allocator,
            .cache_root = cache_root,
            .loaded = std.StringHashMap(*LoadedGrammar).init(allocator),
        };
    }

    pub fn deinit(self: *GrammarManager) void {
        var it = self.loaded.iterator();
        while (it.next()) |entry| {
            const grammar = entry.value_ptr.*;
            if (grammar.handle) |*handle| {
                handle.close();
            }
            if (grammar.language_name.len > 0) {
                self.allocator.free(grammar.language_name);
            }
            if (grammar.version) |version| self.allocator.free(version);
            if (grammar.lib_path) |path| self.allocator.free(path);
            if (grammar.query_path) |path| self.allocator.free(path);
            self.allocator.destroy(grammar);
        }
        self.loaded.deinit();
        self.allocator.free(self.cache_root);
    }

    pub fn getOrLoad(self: *GrammarManager, language_name: []const u8) !?*LoadedGrammar {
        if (self.loaded.get(language_name)) |entry| {
            return entry;
        }

        if (try self.loadFromCache(language_name)) |grammar| {
            return grammar;
        }

        if (std.mem.eql(u8, language_name, "zig")) {
            const grammar = try self.loadBuiltinZig();
            return grammar;
        }

        return null;
    }

    pub fn cacheRoot(self: *GrammarManager) []const u8 {
        return self.cache_root;
    }

    fn loadBuiltinZig(self: *GrammarManager) !*LoadedGrammar {
        const name = try self.allocator.dupe(u8, "zig");
        errdefer self.allocator.free(name);

        const grammar = try self.allocator.create(LoadedGrammar);
        errdefer self.allocator.destroy(grammar);

        grammar.* = .{
            .language_name = name,
            .version = null,
            .lib_path = null,
            .query_path = null,
            .handle = null,
            .ts_language = tree_sitter_zig(),
        };

        try self.loaded.put(name, grammar);
        return grammar;
    }

    fn loadFromCache(self: *GrammarManager, language_name: []const u8) !?*LoadedGrammar {
        const log = app_logger.logger("editor.grammar");

        const latest = try findLatestVersion(self.allocator, self.cache_root, language_name) orelse {
            log.logf("grammar missing lang={s} root={s}", .{ language_name, self.cache_root });
            return null;
        };
        defer self.allocator.free(latest);

        const os_tag = builtin.os.tag;
        const arch = builtin.cpu.arch;
        const os_name = osName(os_tag) orelse {
            log.logf("grammar unsupported os={s} lang={s}", .{ @tagName(os_tag), language_name });
            return null;
        };
        const arch_name = archName(arch) orelse {
            log.logf("grammar unsupported arch={s} lang={s}", .{ @tagName(arch), language_name });
            return null;
        };
        const ext = libExt(os_tag);

        const lib_name = try std.fmt.allocPrint(self.allocator, "{s}_{s}_{s}_{s}.{s}", .{
            language_name,
            latest,
            os_name,
            arch_name,
            ext,
        });
        defer self.allocator.free(lib_name);

        const query_name = try std.fmt.allocPrint(self.allocator, "{s}_{s}_highlights.scm", .{
            language_name,
            latest,
        });
        defer self.allocator.free(query_name);

        const lib_path = try std.fs.path.join(self.allocator, &.{ self.cache_root, language_name, latest, lib_name });
        errdefer self.allocator.free(lib_path);
        const query_path = try std.fs.path.join(self.allocator, &.{ self.cache_root, language_name, latest, query_name });
        errdefer self.allocator.free(query_path);

        if (!fileExistsAbsolute(lib_path)) {
            log.logf("grammar lib missing lang={s} path={s}", .{ language_name, lib_path });
            self.allocator.free(lib_path);
            self.allocator.free(query_path);
            return null;
        }

        var handle = std.DynLib.open(lib_path) catch |err| {
            log.logf("grammar dlopen failed lang={s} path={s} err={any}", .{ language_name, lib_path, err });
            self.allocator.free(lib_path);
            self.allocator.free(query_path);
            return err;
        };
        errdefer handle.close();

        const symbol = try allocZ(self.allocator, "tree_sitter_{s}", .{ language_name });
        defer self.allocator.free(symbol);

        const loader = handle.lookup(LanguageFn, symbol) orelse {
            log.logf("grammar symbol missing lang={s} symbol={s}", .{ language_name, symbol });
            self.allocator.free(lib_path);
            self.allocator.free(query_path);
            return null;
        };

        const grammar = try self.allocator.create(LoadedGrammar);
        errdefer self.allocator.destroy(grammar);

        const name = try self.allocator.dupe(u8, language_name);
        errdefer self.allocator.free(name);

        const version = try self.allocator.dupe(u8, latest);
        errdefer self.allocator.free(version);

        const stored_query_path = if (fileExistsAbsolute(query_path))
            query_path
        else
            blk: {
                self.allocator.free(query_path);
                break :blk null;
            };

        grammar.* = .{
            .language_name = name,
            .version = version,
            .lib_path = lib_path,
            .query_path = stored_query_path,
            .handle = handle,
            .ts_language = loader(),
        };

        try self.loaded.put(name, grammar);
        log.logf("grammar loaded lang={s} version={s} lib={s}", .{ name, version, lib_path });
        return grammar;
    }
};

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

fn osName(os_tag: std.Target.Os.Tag) ?[]const u8 {
    return switch (os_tag) {
        .linux => "linux",
        .windows => "windows",
        .macos => "macos",
        .ios => "macos",
        .tvos => "macos",
        .watchos => "macos",
        else => null,
    };
}

fn archName(arch: std.Target.Cpu.Arch) ?[]const u8 {
    return switch (arch) {
        .x86_64 => "x86_64",
        .aarch64 => "aarch64",
        .arm => "armv7",
        else => null,
    };
}

fn libExt(os_tag: std.Target.Os.Tag) []const u8 {
    return switch (os_tag) {
        .windows => "dll",
        .macos, .ios, .tvos, .watchos => "dylib",
        else => "so",
    };
}

fn fileExistsAbsolute(path: []const u8) bool {
    const file = if (std.fs.path.isAbsolute(path))
        std.fs.openFileAbsolute(path, .{})
    else
        std.fs.cwd().openFile(path, .{});
    const handle = file catch |err| switch (err) {
        error.FileNotFound => return false,
        else => return false,
    };
    handle.close();
    return true;
}

fn findLatestVersion(
    allocator: std.mem.Allocator,
    cache_root: []const u8,
    language_name: []const u8,
) !?[]u8 {
    const base_path = try std.fs.path.join(allocator, &.{ cache_root, language_name });
    defer allocator.free(base_path);

    var dir = if (std.fs.path.isAbsolute(base_path))
        std.fs.openDirAbsolute(base_path, .{ .iterate = true }) catch |err| switch (err) {
            error.FileNotFound => return null,
            else => return err,
        }
    else
        std.fs.cwd().openDir(base_path, .{ .iterate = true }) catch |err| switch (err) {
            error.FileNotFound => return null,
            else => return err,
        };
    defer dir.close();

    var best: ?[]u8 = null;
    var it = dir.iterate();
    while (try it.next()) |entry| {
        if (entry.kind != .directory) continue;
        const name = entry.name;
        if (best == null or compareVersions(name, best.?) > 0) {
            if (best) |old| allocator.free(old);
            best = try allocator.dupe(u8, name);
        }
    }
    return best;
}

fn compareVersions(a: []const u8, b: []const u8) i8 {
    var ia: usize = 0;
    var ib: usize = 0;
    while (ia < a.len or ib < b.len) {
        const seg_a = nextVersionSegment(a, &ia);
        const seg_b = nextVersionSegment(b, &ib);
        if (seg_a < seg_b) return -1;
        if (seg_a > seg_b) return 1;
    }
    return 0;
}

fn nextVersionSegment(input: []const u8, index: *usize) u64 {
    var i = index.*;
    while (i < input.len and !std.ascii.isDigit(input[i])) : (i += 1) {}
    var value: u64 = 0;
    var found = false;
    while (i < input.len and std.ascii.isDigit(input[i])) : (i += 1) {
        found = true;
        value = value * 10 + @as(u64, input[i] - '0');
    }
    index.* = if (i < input.len) i + 1 else i;
    return if (found) value else 0;
}

fn allocZ(allocator: std.mem.Allocator, comptime fmt: []const u8, args: anytype) ![:0]u8 {
    const formatted = try std.fmt.allocPrint(allocator, fmt, args);
    defer allocator.free(formatted);

    const buf = try allocator.alloc(u8, formatted.len + 1);
    std.mem.copyForwards(u8, buf[0..formatted.len], formatted);
    buf[formatted.len] = 0;
    return buf[0..formatted.len :0];
}

test "compareVersions handles numeric ordering" {
    try std.testing.expect(compareVersions("0.1.9", "0.1.10") < 0);
    try std.testing.expect(compareVersions("1.0.0", "0.9.9") > 0);
    try std.testing.expect(compareVersions("0.1.1", "0.1.1") == 0);
}
