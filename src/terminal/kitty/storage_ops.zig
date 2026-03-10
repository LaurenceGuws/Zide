const std = @import("std");
const app_logger = @import("../../app_logger.zig");
const common = @import("common.zig");
const placement_mod = @import("placement_ops.zig");

const KittyPlacementOps = placement_mod.KittyPlacementOps;

pub const KittyStorageOps = struct {
    pub fn store(self: anytype, image: common.KittyImage) void {
        const log = app_logger.logger("terminal.kitty");
        const kitty = common.kittyState(self);
        kitty.generation += 1;
        const version = kitty.generation;
        var idx: usize = 0;
        while (idx < kitty.images.items.len) : (idx += 1) {
            if (kitty.images.items[idx].id == image.id) {
                const old_len = kitty.images.items[idx].data.len;
                KittyPlacementOps.dropForImage(self, image.id, false);
                if (image.data.len > common.kitty_max_bytes) {
                    self.allocator.free(image.data);
                    return;
                }
                const extra = if (image.data.len > old_len) image.data.len - old_len else 0;
                if (!ensureCapacity(self, extra)) {
                    self.allocator.free(image.data);
                    return;
                }
                self.allocator.free(kitty.images.items[idx].data);
                kitty.total_bytes -= old_len;
                kitty.images.items[idx] = image;
                kitty.images.items[idx].version = version;
                kitty.total_bytes += image.data.len;
                log.logf(.info, "kitty image updated id={d} format={s} bytes={d}", .{ image.id, @tagName(image.format), image.data.len });
                return;
            }
        }
        if (image.data.len > common.kitty_max_bytes) {
            self.allocator.free(image.data);
            return;
        }
        if (!ensureCapacity(self, image.data.len)) {
            self.allocator.free(image.data);
            return;
        }
        var stored = image;
        stored.version = version;
        kitty.images.append(self.allocator, stored) catch |err| {
            self.allocator.free(stored.data);
            log.logf(.warning, "kitty image store failed id={d} err={s}", .{ stored.id, @errorName(err) });
            return;
        };
        kitty.total_bytes += stored.data.len;
        log.logf(.info, "kitty image stored id={d} format={s} bytes={d}", .{ stored.id, @tagName(stored.format), stored.data.len });
    }

    pub fn deleteImages(self: anytype, image_id: ?u32) void {
        const kitty = common.kittyState(self);
        if (image_id) |id| {
            var i: usize = 0;
            while (i < kitty.images.items.len) {
                if (kitty.images.items[i].id == id) {
                    removeAt(self, i, true);
                } else {
                    i += 1;
                }
            }
            return;
        }
        for (kitty.placements.items) |placement| {
            KittyPlacementOps.markPlacementDirty(self, placement, @src());
        }
        clearState(self, kitty);
    }

    pub fn clearActive(self: anytype) void {
        clearState(self, common.kittyState(self));
    }

    pub fn clearAll(self: anytype) void {
        clearState(self, &self.core.kitty_primary);
        clearState(self, &self.core.kitty_alt);
    }

    pub fn deinitKittyState(self: anytype, state: *common.KittyState) void {
        for (state.images.items) |image| {
            self.allocator.free(image.data);
        }
        state.images.deinit(self.allocator);
        state.placements.deinit(self.allocator);
        var partial_it = state.partials.iterator();
        while (partial_it.next()) |entry| {
            entry.value_ptr.data.deinit(self.allocator);
        }
        state.partials.deinit();
    }

    fn ensureCapacity(self: anytype, additional: usize) bool {
        const kitty = common.kittyState(self);
        if (additional == 0) return true;
        while (kitty.total_bytes + additional > common.kitty_max_bytes) {
            if (!evict(self, true)) {
                if (!evict(self, false)) return false;
            }
        }
        return true;
    }

    fn dropPartial(self: anytype, image_id: u32) void {
        const kitty = common.kittyState(self);
        if (kitty.partials.getEntry(image_id)) |entry| {
            entry.value_ptr.data.deinit(self.allocator);
            _ = kitty.partials.remove(image_id);
        }
    }

    fn removeAt(self: anytype, idx: usize, include_children: bool) void {
        const kitty = common.kittyState(self);
        const image = kitty.images.items[idx];
        KittyPlacementOps.dropForImage(self, image.id, include_children);
        self.allocator.free(image.data);
        kitty.total_bytes -= image.data.len;
        _ = kitty.images.swapRemove(idx);
        dropPartial(self, image.id);
    }

    fn evict(self: anytype, prefer_unplaced: bool) bool {
        const kitty = common.kittyState(self);
        if (kitty.images.items.len == 0) return false;
        var best_idx: ?usize = null;
        var best_version: u64 = std.math.maxInt(u64);
        for (kitty.images.items, 0..) |image, idx| {
            if (prefer_unplaced and common.kittyImageHasPlacement(self, image.id)) continue;
            if (image.version < best_version) {
                best_version = image.version;
                best_idx = idx;
            }
        }
        if (best_idx == null) return false;
        removeAt(self, best_idx.?, false);
        kitty.generation += 1;
        return true;
    }

    fn clearState(self: anytype, kitty: *common.KittyState) void {
        for (kitty.images.items) |image| {
            self.allocator.free(image.data);
        }
        kitty.images.clearRetainingCapacity();
        kitty.placements.clearRetainingCapacity();
        var partial_it = kitty.partials.iterator();
        while (partial_it.next()) |entry| {
            entry.value_ptr.data.deinit(self.allocator);
        }
        kitty.partials.clearRetainingCapacity();
        kitty.total_bytes = 0;
        kitty.generation += 1;
    }
};
