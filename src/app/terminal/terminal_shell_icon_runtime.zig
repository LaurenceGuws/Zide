const std = @import("std");
const builtin = @import("builtin");
const app_logger = @import("../../app_logger.zig");
const app_shell = @import("../../app_shell.zig");
const config_mod = @import("../../config/lua_config.zig");
const image_decode = @import("../../ui/image_decode.zig");
const renderer_draw_host = @import("../../ui/renderer/renderer_draw_host.zig");
const renderer_mod = @import("../../ui/renderer.zig");
const renderer_types = @import("../../ui/renderer/types.zig");
const surface_draw = @import("../../ui/renderer/surface_draw.zig");
const tab_bar_mod = @import("../../ui/widgets/tab_bar.zig");

const Renderer = renderer_mod.Renderer;
const GpuImageRef = surface_draw.GpuImageRef;
const Rect = renderer_types.Rect;
pub const TerminalShellIconMapping = config_mod.TerminalShellIconMapping;

const CachedIcon = struct {
    path: []u8,
    texture: GpuImageRef = .{ .handle = 0, .width = 0, .height = 0 },
    failed: bool = false,
};

pub const ShellIconCache = struct {
    allocator: std.mem.Allocator,
    entries: std.ArrayList(CachedIcon),

    pub fn init(allocator: std.mem.Allocator) ShellIconCache {
        return .{
            .allocator = allocator,
            .entries = .empty,
        };
    }

    pub fn deinit(self: *ShellIconCache, renderer: *Renderer) void {
        self.clear(renderer);
        self.entries.deinit(self.allocator);
    }

    pub fn clear(self: *ShellIconCache, renderer: *Renderer) void {
        for (self.entries.items) |*entry| {
            if (entry.texture.handle != 0) {
                renderer_draw_host.destroyPersistentImage(renderer, &entry.texture);
            }
            self.allocator.free(entry.path);
            entry.* = undefined;
        }
        self.entries.clearRetainingCapacity();
    }

    pub fn iconProvider(self: *ShellIconCache) tab_bar_mod.TabBar.IconProvider {
        return .{
            .ctx = self,
            .draw = drawThunk,
        };
    }

    fn drawThunk(ctx: *anyopaque, shell: *app_shell.Shell, icon_path: []const u8, x: f32, y: f32, size: f32) bool {
        const self: *ShellIconCache = @ptrCast(@alignCast(ctx));
        return self.drawIcon(shell, icon_path, x, y, size);
    }

    fn drawIcon(self: *ShellIconCache, shell: *app_shell.Shell, icon_path: []const u8, x: f32, y: f32, size: f32) bool {
        const texture = self.ensureTexture(shell.rendererPtr(), icon_path) orelse return false;
        if (texture.width <= 0 or texture.height <= 0) return false;

        const box = @max(size, 1.0);
        var draw_w = box;
        var draw_h = box;
        const aspect = @as(f32, @floatFromInt(texture.width)) / @as(f32, @floatFromInt(texture.height));
        if (aspect > 1.0) {
            draw_h = box / aspect;
        } else if (aspect > 0) {
            draw_w = box * aspect;
        }

        const src = Rect{
            .x = 0,
            .y = 0,
            .width = @floatFromInt(texture.width),
            .height = @floatFromInt(texture.height),
        };
        const dest = Rect{
            .x = x + (box - draw_w) * 0.5,
            .y = y + (box - draw_h) * 0.5,
            .width = draw_w,
            .height = draw_h,
        };
        return renderer_draw_host.drawPersistentImage(shell.rendererPtr(), texture, src, dest, app_shell.Color.white.toRgba());
    }

    fn ensureTexture(self: *ShellIconCache, renderer: *Renderer, icon_path: []const u8) ?GpuImageRef {
        if (self.findEntry(icon_path)) |entry| {
            if (entry.failed) return null;
            return entry.texture;
        }

        var new_entry = CachedIcon{
            .path = self.allocator.dupe(u8, icon_path) catch return null,
            .failed = true,
        };
        errdefer self.allocator.free(new_entry.path);

        if (loadTexture(renderer, self.allocator, icon_path)) |texture| {
            new_entry.texture = texture;
            new_entry.failed = false;
        }

        self.entries.append(self.allocator, new_entry) catch {
            if (new_entry.texture.handle != 0) renderer_draw_host.destroyPersistentImage(renderer, &new_entry.texture);
            return null;
        };

        if (new_entry.failed) return null;
        return new_entry.texture;
    }

    fn findEntry(self: *ShellIconCache, icon_path: []const u8) ?*CachedIcon {
        for (self.entries.items) |*entry| {
            if (stringEq(entry.path, icon_path)) return entry;
        }
        return null;
    }
};

pub fn dupMappings(allocator: std.mem.Allocator, mappings: ?[]const TerminalShellIconMapping) !?[]TerminalShellIconMapping {
    const src = mappings orelse return null;
    var out = try allocator.alloc(TerminalShellIconMapping, src.len);
    errdefer allocator.free(out);
    var loaded: usize = 0;
    errdefer {
        for (out[0..loaded]) |*mapping| {
            allocator.free(mapping.shell);
            allocator.free(mapping.icon_path);
        }
    }
    for (src, 0..) |mapping, i| {
        out[i] = .{
            .shell = try allocator.dupe(u8, mapping.shell),
            .icon_path = try allocator.dupe(u8, mapping.icon_path),
        };
        loaded += 1;
    }
    return out;
}

pub fn freeMappings(allocator: std.mem.Allocator, mappings: ?[]TerminalShellIconMapping) void {
    const slice = mappings orelse return;
    for (slice) |*mapping| {
        allocator.free(mapping.shell);
        allocator.free(mapping.icon_path);
        mapping.* = undefined;
    }
    allocator.free(slice);
}

pub fn resolveIconPath(
    show_shell_icon: bool,
    mappings: ?[]const TerminalShellIconMapping,
    shell_path: []const u8,
) ?[]const u8 {
    const mapping_slice = mappings orelse return null;
    if (!show_shell_icon or shell_path.len == 0) return null;

    const base = shellBasename(shell_path);
    const stem = shellBasenameStem(base);

    for (mapping_slice) |mapping| {
        if (stringEq(mapping.shell, shell_path)) return mapping.icon_path;
    }
    for (mapping_slice) |mapping| {
        if (stringEq(mapping.shell, base)) return mapping.icon_path;
    }
    for (mapping_slice) |mapping| {
        if (stringEq(mapping.shell, stem)) return mapping.icon_path;
    }
    return null;
}

fn loadTexture(renderer: *Renderer, allocator: std.mem.Allocator, icon_path: []const u8) ?GpuImageRef {
    const log = app_logger.logger("terminal.shell_icon");
    const file = std.fs.cwd().readFileAlloc(allocator, icon_path, 8 * 1024 * 1024) catch |err| {
        log.logf(.warning, "tab shell icon read failed path={s} err={s}", .{ icon_path, @errorName(err) });
        return null;
    };
    defer allocator.free(file);

    const decoded = image_decode.decodePngRgba(allocator, file) catch |err| {
        log.logf(.warning, "tab shell icon decode failed path={s} err={s}", .{ icon_path, @errorName(err) });
        return null;
    };
    defer allocator.free(decoded.data);

    return renderer_draw_host.createPersistentImageFromRgba(
        renderer,
        @intCast(decoded.width),
        @intCast(decoded.height),
        decoded.data,
    ) orelse blk: {
        log.logf(.warning, "tab shell icon upload failed path={s}", .{icon_path});
        break :blk null;
    };
}

fn shellBasename(path: []const u8) []const u8 {
    var start: usize = 0;
    for (path, 0..) |ch, i| {
        if (ch == '/' or ch == '\\') start = i + 1;
    }
    return path[start..];
}

fn shellBasenameStem(base: []const u8) []const u8 {
    if (std.mem.lastIndexOfScalar(u8, base, '.')) |dot| {
        if (dot > 0) return base[0..dot];
    }
    return base;
}

fn stringEq(a: []const u8, b: []const u8) bool {
    if (builtin.os.tag == .windows) return std.ascii.eqlIgnoreCase(a, b);
    return std.mem.eql(u8, a, b);
}

test "resolveIconPath matches exact path basename and stem" {
    const mappings = [_]TerminalShellIconMapping{
        .{ .shell = "C:/Program Files/PowerShell/7/pwsh.exe", .icon_path = "pwsh-exact.png" },
        .{ .shell = "bash.exe", .icon_path = "bash-base.png" },
        .{ .shell = "zsh", .icon_path = "zsh-stem.png" },
    };

    try std.testing.expectEqualStrings("pwsh-exact.png", resolveIconPath(true, &mappings, "C:/Program Files/PowerShell/7/pwsh.exe").?);
    try std.testing.expectEqualStrings("bash-base.png", resolveIconPath(true, &mappings, "C:/msys64/usr/bin/bash.exe").?);
    try std.testing.expectEqualStrings("zsh-stem.png", resolveIconPath(true, &mappings, "/bin/zsh").?);
    try std.testing.expect(resolveIconPath(false, &mappings, "/bin/zsh") == null);
}
