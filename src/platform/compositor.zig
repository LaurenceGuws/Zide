const std = @import("std");

pub const Compositor = enum {
    hyprland,
    kde,
    unknown,
};

pub const Detection = struct {
    wayland: bool,
    compositor: Compositor,
};

pub fn detect() Detection {
    const wayland = isWayland();
    return .{
        .wayland = wayland,
        .compositor = if (wayland) detectCompositor() else .unknown,
    };
}

pub fn isWayland() bool {
    if (std.c.getenv("WAYLAND_DISPLAY") != null) return true;
    if (std.c.getenv("XDG_SESSION_TYPE")) |raw| {
        const val = std.mem.sliceTo(raw, 0);
        return std.mem.eql(u8, val, "wayland");
    }
    return false;
}

fn detectCompositor() Compositor {
    if (std.c.getenv("HYPRLAND_INSTANCE_SIGNATURE") != null) return .hyprland;

    if (std.c.getenv("KDE_FULL_SESSION") != null or std.c.getenv("KDE_SESSION_VERSION") != null) return .kde;

    if (std.c.getenv("XDG_CURRENT_DESKTOP")) |raw| {
        const val = std.mem.sliceTo(raw, 0);
        if (containsInsensitive(val, "kde")) return .kde;
    }

    if (std.c.getenv("XDG_SESSION_DESKTOP")) |raw| {
        const val = std.mem.sliceTo(raw, 0);
        if (containsInsensitive(val, "kde")) return .kde;
    }

    return .unknown;
}

pub fn getWaylandScale(allocator: std.mem.Allocator) ?f32 {
    const info = detect();
    if (!info.wayland) return null;

    return switch (info.compositor) {
        .hyprland => getHyprlandScale(allocator),
        .kde => getKdeScale(allocator),
        .unknown => null,
    };
}

fn getHyprlandScale(allocator: std.mem.Allocator) ?f32 {
    const stdout = runCommand(allocator, &.{ "hyprctl", "-j", "monitors" }) orelse return null;
    defer allocator.free(stdout);

    var parsed = std.json.parseFromSlice(std.json.Value, allocator, stdout, .{}) catch return null;
    defer parsed.deinit();

    if (parsed.value != .array) return null;

    var fallback_scale: ?f32 = null;
    for (parsed.value.array.items) |item| {
        if (item != .object) continue;
        const obj = item.object;

        if (fallback_scale == null) {
            if (obj.get("scale")) |val| {
                fallback_scale = parseScaleValue(val);
            }
        }

        if (obj.get("focused")) |val| {
            if (val == .bool and val.bool) {
                if (obj.get("scale")) |scale_val| {
                    if (parseScaleValue(scale_val)) |scale| return scale;
                }
            }
        }
    }

    return fallback_scale;
}

fn getKdeScale(_: std.mem.Allocator) ?f32 {
    // TODO: implement using kscreen-doctor output once we have a KDE test setup.
    return null;
}

fn parseScaleValue(val: std.json.Value) ?f32 {
    return switch (val) {
        .float => |v| @floatCast(v),
        .integer => |v| @floatFromInt(v),
        else => null,
    };
}

fn runCommand(allocator: std.mem.Allocator, argv: []const []const u8) ?[]u8 {
    const result = std.process.Child.run(.{
        .allocator = allocator,
        .argv = argv,
        .max_output_bytes = 64 * 1024,
    }) catch return null;

    defer allocator.free(result.stderr);

    switch (result.term) {
        .Exited => |code| if (code != 0) {
            allocator.free(result.stdout);
            return null;
        },
        else => {
            allocator.free(result.stdout);
            return null;
        },
    }

    return result.stdout;
}

fn containsInsensitive(haystack: []const u8, needle: []const u8) bool {
    if (needle.len == 0) return true;
    if (haystack.len < needle.len) return false;

    const lower = std.ascii.toLower;
    var i: usize = 0;
    while (i + needle.len <= haystack.len) : (i += 1) {
        var matched = true;
        var j: usize = 0;
        while (j < needle.len) : (j += 1) {
            if (lower(haystack[i + j]) != lower(needle[j])) {
                matched = false;
                break;
            }
        }
        if (matched) return true;
    }

    return false;
}
