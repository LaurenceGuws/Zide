const std = @import("std");
const app_shell = @import("../../app_shell.zig");
const app_logger = @import("../../app_logger.zig");
const terminal_mod = @import("../../terminal/core/terminal.zig");

const gl = @import("../renderer/gl.zig");
const types = @import("../renderer/types.zig");

const Shell = app_shell.Shell;
const Color = app_shell.Color;
const KittyImage = terminal_mod.KittyImage;
const KittyPlacement = terminal_mod.KittyPlacement;

const KittyTexture = struct {
    texture: types.Texture,
    width: i32,
    height: i32,
    version: u64,
};

pub const KittyState = struct {
    images_view: std.ArrayList(KittyImage),
    placements_view: std.ArrayList(KittyPlacement),
    textures: std.AutoHashMap(u32, KittyTexture),
    pending_uploads: std.ArrayList(u32),
    pending_uploads_set: std.AutoHashMap(u32, void),
    last_generation: u64 = 0,

    pub const UploadStats = struct {
        images: usize = 0,
        bytes: usize = 0,
    };

    pub fn init(allocator: std.mem.Allocator) KittyState {
        return .{
            .images_view = .empty,
            .placements_view = .empty,
            .textures = std.AutoHashMap(u32, KittyTexture).init(allocator),
            .pending_uploads = .empty,
            .pending_uploads_set = std.AutoHashMap(u32, void).init(allocator),
            .last_generation = 0,
        };
    }

    pub fn deinit(self: *KittyState, allocator: std.mem.Allocator) void {
        var it = self.textures.iterator();
        while (it.next()) |entry| {
            if (entry.value_ptr.texture.id != 0) {
                gl.DeleteTextures(1, &entry.value_ptr.texture.id);
            }
        }
        self.textures.deinit();
        self.pending_uploads.deinit(allocator);
        self.pending_uploads_set.deinit();
        self.images_view.deinit(allocator);
        self.placements_view.deinit(allocator);
    }

    pub fn hasKitty(self: *const KittyState) bool {
        return self.images_view.items.len > 0 and self.placements_view.items.len > 0;
    }

    pub fn updateViews(
        self: *KittyState,
        allocator: std.mem.Allocator,
        rows: usize,
        cols: usize,
        session_images: []const KittyImage,
        session_placements: []const KittyPlacement,
    ) void {
        const log = app_logger.logger("terminal.kitty");
        if (rows > 0 and cols > 0) {
            self.images_view.resize(allocator, session_images.len) catch |err| {
                                    log.logf(.warning, "kitty view resize failed field=images len={d} err={s}", .{ session_images.len, @errorName(err) });
                return;
            };
            self.placements_view.resize(allocator, session_placements.len) catch |err| {
                                    log.logf(.warning, "kitty view resize failed field=placements len={d} err={s}", .{ session_placements.len, @errorName(err) });
                return;
            };
            std.mem.copyForwards(KittyImage, self.images_view.items, session_images);
            std.mem.copyForwards(KittyPlacement, self.placements_view.items, session_placements);
        } else {
            self.images_view.clearRetainingCapacity();
            self.placements_view.clearRetainingCapacity();
        }
    }

    pub fn cleanupTextures(self: *KittyState, allocator: std.mem.Allocator, images: []const KittyImage) void {
        const log = app_logger.logger("terminal.kitty");
        var stale = std.ArrayList(u32).empty;
        defer stale.deinit(allocator);
        var it = self.textures.iterator();
        while (it.next()) |entry| {
            var found = false;
            for (images) |img| {
                if (img.id == entry.key_ptr.*) {
                    found = true;
                    break;
                }
            }
            if (!found) {
                stale.append(allocator, entry.key_ptr.*) catch |err| {
                                            log.logf(.warning, "kitty stale list append failed err={s}", .{@errorName(err)});
                    break;
                };
            }
        }
        for (stale.items) |id| {
            if (self.textures.fetchRemove(id)) |entry| {
                if (entry.value.texture.id != 0) {
                    gl.DeleteTextures(1, &entry.value.texture.id);
                }
            }
            _ = self.pending_uploads_set.remove(id);
        }
    }

    fn shouldDrawPlacement(placement: KittyPlacement, above_text: bool) bool {
        if (placement.is_virtual) return above_text;
        if (above_text) return placement.z >= 0;
        return placement.z < 0;
    }

    pub fn drawImages(
        self: *KittyState,
        allocator: std.mem.Allocator,
        shell: *Shell,
        base_x: f32,
        base_y: f32,
        above_text: bool,
        start_line: usize,
        rows: usize,
        cols: usize,
    ) void {
        const r = shell.rendererPtr();
        const cell_w: f32 = r.terminal_cell_width;
        const cell_h: f32 = r.terminal_cell_height;
        const start_line_i: i32 = @intCast(start_line);
        const rows_i: i32 = @intCast(rows);
        const cols_i: i32 = @intCast(cols);

        for (self.placements_view.items) |placement| {
            if (!shouldDrawPlacement(placement, above_text)) continue;
            const image = findKittyImage(self.images_view.items, placement.image_id) orelse continue;
            const tex = self.ensureTexture(allocator, image) orelse continue;

            const col_i: i32 = @as(i32, @intCast(placement.col));
            if (col_i < 0 or col_i >= cols_i) continue;
            const row_i: i32 = @as(i32, @intCast(placement.row)) - start_line_i;

            const draw_w = if (placement.cols > 0) cell_w * @as(f32, @floatFromInt(placement.cols)) else @as(f32, @floatFromInt(tex.width));
            const draw_h = if (placement.rows > 0) cell_h * @as(f32, @floatFromInt(placement.rows)) else @as(f32, @floatFromInt(tex.height));

            const row_span: i32 = if (placement.rows > 0)
                @as(i32, @intCast(placement.rows))
            else
                @as(i32, @intCast(@max(@as(i32, 1), @as(i32, @intFromFloat(@ceil(draw_h / cell_h))))));
            if (row_i >= rows_i or row_i + row_span <= 0) continue;

            const x = base_x + @as(f32, @floatFromInt(col_i)) * cell_w;
            const y = base_y + @as(f32, @floatFromInt(row_i)) * cell_h;

            const dest = types.Rect{ .x = x, .y = y, .width = draw_w, .height = draw_h };
            const src = types.Rect{
                .x = 0,
                .y = 0,
                .width = @as(f32, @floatFromInt(tex.texture.width)),
                .height = @as(f32, @floatFromInt(tex.texture.height)),
            };
            r.drawTexture(tex.texture, src, dest, Color.white);
        }
    }

    pub fn primeUploads(self: *KittyState, allocator: std.mem.Allocator) void {
        if (self.placements_view.items.len == 0) return;
        for (self.placements_view.items) |placement| {
            const image_id = placement.image_id;
            if (self.textures.contains(image_id)) continue;
            self.enqueueUpload(allocator, image_id);
        }
    }

    pub fn processPendingUploads(self: *KittyState, shell: *Shell) UploadStats {
        if (self.pending_uploads.items.len == 0) return .{};
        const renderer = shell.rendererPtr();
        const max_bytes: usize = 2 * 1024 * 1024;
        var used_bytes: usize = 0;
        var uploaded_images: usize = 0;

        while (self.pending_uploads.items.len > 0) {
            const image_id = self.pending_uploads.items[0];
            if (self.textures.contains(image_id)) {
                _ = self.pending_uploads_set.remove(image_id);
                _ = self.pending_uploads.swapRemove(0);
                continue;
            }
            const image = findKittyImage(self.images_view.items, image_id) orelse {
                _ = self.pending_uploads_set.remove(image_id);
                _ = self.pending_uploads.swapRemove(0);
                continue;
            };
            const bytes_per_px: usize = switch (image.format) {
                .rgb => 3,
                .rgba => 4,
                .png => 4,
            };
            const image_bytes: usize = @as(usize, image.width) * @as(usize, image.height) * bytes_per_px;
            if (used_bytes > 0 and used_bytes + image_bytes > max_bytes) break;

            if (self.uploadTexture(renderer, image)) {
                used_bytes += image_bytes;
                uploaded_images += 1;
            }
            _ = self.pending_uploads_set.remove(image_id);
            _ = self.pending_uploads.swapRemove(0);
        }

        return .{ .images = uploaded_images, .bytes = used_bytes };
    }

    pub fn ensureTexture(self: *KittyState, allocator: std.mem.Allocator, image: KittyImage) ?KittyTexture {
        if (self.textures.getEntry(image.id)) |entry| {
            if (entry.value_ptr.version == image.version) return entry.value_ptr.*;
            if (entry.value_ptr.texture.id != 0) {
                gl.DeleteTextures(1, &entry.value_ptr.texture.id);
            }
            _ = self.textures.remove(image.id);
        }
        self.enqueueUpload(allocator, image.id);
        return null;
    }

    fn enqueueUpload(self: *KittyState, allocator: std.mem.Allocator, image_id: u32) void {
        const log = app_logger.logger("terminal.kitty");
        if (self.pending_uploads_set.contains(image_id)) return;
        _ = self.pending_uploads.append(allocator, image_id) catch |err| {
                            log.logf(.warning, "kitty upload queue append failed id={d} err={s}", .{ image_id, @errorName(err) });
            return;
        };
        self.pending_uploads_set.put(image_id, {}) catch |err| {
                            log.logf(.warning, "kitty upload set insert failed id={d} err={s}", .{ image_id, @errorName(err) });
        };
    }

    fn uploadTexture(self: *KittyState, renderer: anytype, image: KittyImage) bool {
        const texture = loadTexture(renderer, image) orelse {
            const log = app_logger.logger("terminal.kitty");
                            log.logf(.info, "kitty texture load failed id={d} format={s} bytes={d}", .{ image.id, @tagName(image.format), image.data.len });
            return false;
        };
        const stored = KittyTexture{
            .texture = texture,
            .width = texture.width,
            .height = texture.height,
            .version = image.version,
        };
        const log = app_logger.logger("terminal.kitty");
        self.textures.put(image.id, stored) catch |err| {
            if (stored.texture.id != 0) {
                gl.DeleteTextures(1, &stored.texture.id);
            }
                            log.logf(.warning, "kitty texture map insert failed id={d} err={s}", .{ image.id, @errorName(err) });
            return false;
        };
                    log.logf(.info, "kitty texture ok id={d} w={d} h={d}", .{ image.id, texture.width, texture.height });
        return true;
    }

    fn loadTexture(renderer: anytype, image: KittyImage) ?types.Texture {
        switch (image.format) {
            .png => {
                const log = app_logger.logger("terminal.kitty");
                                    log.logf(.info, "kitty upload skipped: png needs decode id={d}", .{image.id});
                return null;
            },
            .rgb => {
                if (image.width == 0 or image.height == 0) return null;
                return renderer.createTextureFromRgb(@intCast(image.width), @intCast(image.height), image.data, gl.c.GL_LINEAR);
            },
            .rgba => {
                if (image.width == 0 or image.height == 0) return null;
                return renderer.createTextureFromRgba(@intCast(image.width), @intCast(image.height), image.data, gl.c.GL_LINEAR);
            },
        }
    }

    fn findKittyImage(images: []const KittyImage, image_id: u32) ?KittyImage {
        for (images) |img| {
            if (img.id == image_id) return img;
        }
        return null;
    }
};

test "kitty virtual placements render only on above-text pass" {
    const virtual = KittyPlacement{
        .image_id = 1,
        .placement_id = 0,
        .row = 0,
        .col = 0,
        .cols = 0,
        .rows = 0,
        .z = -1,
        .anchor_row = 0,
        .is_virtual = true,
        .parent_image_id = 0,
        .parent_placement_id = 0,
        .offset_x = 0,
        .offset_y = 0,
    };
    try std.testing.expect(!KittyState.shouldDrawPlacement(virtual, false));
    try std.testing.expect(KittyState.shouldDrawPlacement(virtual, true));
}

test "kitty non-virtual placement z-layer policy unchanged" {
    const below = KittyPlacement{
        .image_id = 1,
        .placement_id = 0,
        .row = 0,
        .col = 0,
        .cols = 0,
        .rows = 0,
        .z = -1,
        .anchor_row = 0,
        .is_virtual = false,
        .parent_image_id = 0,
        .parent_placement_id = 0,
        .offset_x = 0,
        .offset_y = 0,
    };
    const above = KittyPlacement{
        .image_id = 1,
        .placement_id = 0,
        .row = 0,
        .col = 0,
        .cols = 0,
        .rows = 0,
        .z = 1,
        .anchor_row = 0,
        .is_virtual = false,
        .parent_image_id = 0,
        .parent_placement_id = 0,
        .offset_x = 0,
        .offset_y = 0,
    };
    try std.testing.expect(KittyState.shouldDrawPlacement(below, false));
    try std.testing.expect(!KittyState.shouldDrawPlacement(below, true));
    try std.testing.expect(!KittyState.shouldDrawPlacement(above, false));
    try std.testing.expect(KittyState.shouldDrawPlacement(above, true));
}
