const std = @import("std");

pub const BuildMode = enum {
    debug,
    release_safe,
    release_fast,
    release_small,
};

pub const WidgetConfig = struct {
    name: []const u8,
    enabled: bool,
    build_mode: BuildMode,
    threshold: usize,
};

pub const CursorFixture = struct {
    allocator: std.mem.Allocator,
    configs: []const WidgetConfig,

    pub fn init(allocator: std.mem.Allocator, configs: []const WidgetConfig) CursorFixture {
        return .{
            .allocator = allocator,
            .configs = configs,
        };
    }

    pub fn enabledCount(self: CursorFixture) usize {
        var count: usize = 0;
        for (self.configs) |config| {
            if (config.enabled) count += 1;
        }
        return count;
    }

    pub fn totalThreshold(self: CursorFixture) usize {
        var total: usize = 0;
        for (self.configs) |config| {
            total += config.threshold;
        }
        return total;
    }

    pub fn summarize(self: CursorFixture, writer: anytype) !void {
        try writer.print("enabled={d} total_threshold={d}\n", .{
            self.enabledCount(),
            self.totalThreshold(),
        });

        for (self.configs, 0..) |config, idx| {
            try writer.print("{d}: {s} enabled={any} mode={s} threshold={d}\n", .{
                idx,
                config.name,
                config.enabled,
                @tagName(config.build_mode),
                config.threshold,
            });
        }
    }
};

fn modePenalty(mode: BuildMode) usize {
    return switch (mode) {
        .debug => 8,
        .release_safe => 4,
        .release_fast => 2,
        .release_small => 3,
    };
}

fn weightedScore(config: WidgetConfig) usize {
    const enabled_bonus: usize = if (config.enabled) 5 else 1;
    return (config.threshold + modePenalty(config.build_mode)) * enabled_bonus;
}

fn buildSampleConfigs() [24]WidgetConfig {
    return .{
        .{ .name = "alpha.renderer", .enabled = true, .build_mode = .debug, .threshold = 11 },
        .{ .name = "beta.renderer", .enabled = true, .build_mode = .release_safe, .threshold = 12 },
        .{ .name = "gamma.renderer", .enabled = false, .build_mode = .release_fast, .threshold = 13 },
        .{ .name = "delta.renderer", .enabled = true, .build_mode = .release_small, .threshold = 14 },
        .{ .name = "epsilon.renderer", .enabled = true, .build_mode = .debug, .threshold = 15 },
        .{ .name = "zeta.renderer", .enabled = false, .build_mode = .release_safe, .threshold = 16 },
        .{ .name = "eta.renderer", .enabled = true, .build_mode = .release_fast, .threshold = 17 },
        .{ .name = "theta.renderer", .enabled = true, .build_mode = .release_small, .threshold = 18 },
        .{ .name = "iota.renderer", .enabled = false, .build_mode = .debug, .threshold = 19 },
        .{ .name = "kappa.renderer", .enabled = true, .build_mode = .release_safe, .threshold = 20 },
        .{ .name = "lambda.renderer", .enabled = true, .build_mode = .release_fast, .threshold = 21 },
        .{ .name = "mu.renderer", .enabled = false, .build_mode = .release_small, .threshold = 22 },
        .{ .name = "nu.renderer", .enabled = true, .build_mode = .debug, .threshold = 23 },
        .{ .name = "xi.renderer", .enabled = true, .build_mode = .release_safe, .threshold = 24 },
        .{ .name = "omicron.renderer", .enabled = false, .build_mode = .release_fast, .threshold = 25 },
        .{ .name = "pi.renderer", .enabled = true, .build_mode = .release_small, .threshold = 26 },
        .{ .name = "rho.renderer", .enabled = true, .build_mode = .debug, .threshold = 27 },
        .{ .name = "sigma.renderer", .enabled = false, .build_mode = .release_safe, .threshold = 28 },
        .{ .name = "tau.renderer", .enabled = true, .build_mode = .release_fast, .threshold = 29 },
        .{ .name = "upsilon.renderer", .enabled = true, .build_mode = .release_small, .threshold = 30 },
        .{ .name = "phi.renderer", .enabled = false, .build_mode = .debug, .threshold = 31 },
        .{ .name = "chi.renderer", .enabled = true, .build_mode = .release_safe, .threshold = 32 },
        .{ .name = "psi.renderer", .enabled = true, .build_mode = .release_fast, .threshold = 33 },
        .{ .name = "omega.renderer", .enabled = true, .build_mode = .release_small, .threshold = 34 },
    };
}

fn emitScores(writer: anytype, configs: []const WidgetConfig) !void {
    for (configs) |config| {
        try writer.print("{s}: {d}\n", .{
            config.name,
            weightedScore(config),
        });
    }
}

pub fn main() !void {
    var stdout = std.io.getStdOut().writer();
    const configs = buildSampleConfigs();
    const fixture = CursorFixture.init(std.heap.page_allocator, &configs);

    try fixture.summarize(stdout);
    try emitScores(stdout, &configs);
}
