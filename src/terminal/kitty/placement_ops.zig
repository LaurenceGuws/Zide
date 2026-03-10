const std = @import("std");
const app_logger = @import("../../app_logger.zig");
const common = @import("common.zig");

pub const KittyPlacementOps = struct {
    pub fn dropForImage(self: anytype, image_id: u32, include_children: bool) void {
        const kitty = common.kittyState(self);
        markImageDirty(self, image_id, @src());
        var idx: usize = 0;
        while (idx < kitty.placements.items.len) {
            const placement = kitty.placements.items[idx];
            if (placement.image_id == image_id or (include_children and placement.parent_image_id == image_id)) {
                _ = kitty.placements.swapRemove(idx);
            } else {
                idx += 1;
            }
        }
    }

    pub fn markPlacementDirty(self: anytype, placement: common.KittyPlacement, src: std.builtin.SourceLocation) void {
        const screen = self.activeScreen();
        const kitty = common.kittyStateConst(self);
        const image = common.findKittyImageById(kitty.images.items, placement.image_id);
        switch (common.kittyPlacementDirtyRegion(
            image,
            placement,
            screen.grid.rows,
            screen.grid.cols,
            self.cell_width,
            self.cell_height,
        )) {
            .none => {},
            .partial => |region| screen.grid.markDirtyRange(region.start_row, region.end_row, region.start_col, region.end_col),
            .full => screen.grid.markDirtyAllWithReason(.kitty_graphics_changed, src),
        }
    }

    pub fn markImageDirty(self: anytype, image_id: u32, src: std.builtin.SourceLocation) void {
        const kitty = common.kittyStateConst(self);
        for (kitty.placements.items) |placement| {
            if (placement.image_id == image_id or placement.parent_image_id == image_id) {
                markPlacementDirty(self, placement, src);
            }
        }
    }

    pub fn find(self: anytype, image_id: u32, placement_id: u32) ?common.KittyPlacement {
        const kitty = common.kittyStateConst(self);
        for (kitty.placements.items) |placement| {
            if (placement.image_id == image_id and placement.placement_id == placement_id) return placement;
        }
        return null;
    }

    pub fn findIndex(self: anytype, image_id: u32, placement_id: u32) ?usize {
        const kitty = common.kittyStateConst(self);
        for (kitty.placements.items, 0..) |placement, idx| {
            if (placement.image_id == image_id and placement.placement_id == placement_id) return idx;
        }
        return null;
    }

    pub fn effectiveColumns(self: anytype, control: common.KittyControl, image_id: u32) u32 {
        if (control.cols > 0) return control.cols;
        const cell_w = @as(u32, self.cell_width);
        const width_px = if (control.width > 0) control.width else blk: {
            const kitty = common.kittyStateConst(self);
            const image = common.findKittyImageById(kitty.images.items, image_id) orelse break :blk 0;
            break :blk image.width;
        };
        if (cell_w == 0 or width_px == 0) return 0;
        return std.math.divCeil(u32, width_px, cell_w) catch 0;
    }

    pub fn effectiveRows(self: anytype, control: common.KittyControl, image_id: u32) u32 {
        if (control.rows > 0) return control.rows;
        const cell_h = @as(u32, self.cell_height);
        const height_px = if (control.height > 0) control.height else blk: {
            const kitty = common.kittyStateConst(self);
            const image = common.findKittyImageById(kitty.images.items, image_id) orelse break :blk 0;
            break :blk image.height;
        };
        if (cell_h == 0 or height_px == 0) return 0;
        if (height_px <= cell_h) return 0;
        return std.math.divCeil(u32, height_px, cell_h) catch 0;
    }
};

pub fn updateKittyPlacementsForScroll(self: anytype) void {
    const kitty = common.kittyState(self);
    if (kitty.placements.items.len == 0) return;
    const screen = self.activeScreenConst();
    const rows = @as(u64, screen.grid.rows);
    const top = common.kittyVisibleTop(self);
    const max_row = top + rows;
    var changed = false;
    var idx: usize = 0;
    while (idx < kitty.placements.items.len) {
        const placement = &kitty.placements.items[idx];
        if (placement.anchor_row < top or placement.anchor_row >= max_row) {
            KittyPlacementOps.markPlacementDirty(self, placement.*, @src());
            _ = kitty.placements.swapRemove(idx);
            changed = true;
            continue;
        }
        const new_row: u64 = placement.anchor_row - top;
        if (placement.row != @as(u16, @intCast(new_row))) {
            const old_placement = placement.*;
            placement.row = @as(u16, @intCast(new_row));
            KittyPlacementOps.markPlacementDirty(self, old_placement, @src());
            KittyPlacementOps.markPlacementDirty(self, placement.*, @src());
            changed = true;
        }
        idx += 1;
    }
    if (changed) {
        kitty.generation += 1;
    }
}

pub fn shiftKittyPlacementsUp(self: anytype, top: usize, bottom: usize, count: usize) void {
    const kitty = common.kittyState(self);
    if (count == 0 or kitty.placements.items.len == 0) return;
    var changed = false;
    var idx: usize = 0;
    while (idx < kitty.placements.items.len) {
        const placement = &kitty.placements.items[idx];
        if (placement.row < top or placement.row > bottom) {
            idx += 1;
            continue;
        }
        if (placement.row < top + count) {
            KittyPlacementOps.markPlacementDirty(self, placement.*, @src());
            _ = kitty.placements.swapRemove(idx);
            changed = true;
            continue;
        }
        const old_placement = placement.*;
        placement.row = @intCast(placement.row - count);
        if (placement.anchor_row >= count) {
            placement.anchor_row -= count;
        }
        KittyPlacementOps.markPlacementDirty(self, old_placement, @src());
        KittyPlacementOps.markPlacementDirty(self, placement.*, @src());
        changed = true;
        idx += 1;
    }
    if (changed) {
        kitty.generation += 1;
    }
}

pub fn shiftKittyPlacementsDown(self: anytype, top: usize, bottom: usize, count: usize) void {
    const kitty = common.kittyState(self);
    if (count == 0 or kitty.placements.items.len == 0) return;
    var changed = false;
    var idx: usize = 0;
    while (idx < kitty.placements.items.len) {
        const placement = &kitty.placements.items[idx];
        if (placement.row < top or placement.row > bottom) {
            idx += 1;
            continue;
        }
        if (placement.row + count > bottom) {
            KittyPlacementOps.markPlacementDirty(self, placement.*, @src());
            _ = kitty.placements.swapRemove(idx);
            changed = true;
            continue;
        }
        const old_placement = placement.*;
        placement.row = @intCast(placement.row + count);
        placement.anchor_row += count;
        KittyPlacementOps.markPlacementDirty(self, old_placement, @src());
        KittyPlacementOps.markPlacementDirty(self, placement.*, @src());
        changed = true;
        idx += 1;
    }
    if (changed) {
        kitty.generation += 1;
    }
}

pub fn placeKittyImage(self: anytype, image_id: u32, control: common.KittyControl) ?[]const u8 {
    const log = app_logger.logger("terminal.kitty");
    const kitty = common.kittyState(self);
    const screen = self.activeScreen();
    if (screen.grid.rows == 0 or screen.grid.cols == 0) return "EINVAL";
    if (common.findKittyImageById(kitty.images.items, image_id) == null) return "ENOENT";
    const base_row = @min(@as(u16, @intCast(screen.cursor.row)), screen.grid.rows - 1);
    const base_col = @min(@as(u16, @intCast(screen.cursor.col)), screen.grid.cols - 1);
    var row = base_row;
    var col = base_col;
    var parent_image_id: u32 = 0;
    var parent_placement_id: u32 = 0;
    if (control.parent_id != null or control.child_id != null) {
        const parent_id = control.parent_id orelse return "ENOPARENT";
        const parent_pid = control.child_id orelse return "ENOPARENT";
        const placement_id = control.placement_id orelse 0;
        if (placement_id != 0 and parent_id == image_id and parent_pid == placement_id) return "EINVAL";
        parent_image_id = parent_id;
        parent_placement_id = parent_pid;
        const parent = KittyPlacementOps.find(self, parent_id, parent_pid) orelse return "ENOPARENT";
        if (placement_id != 0) {
            const chain_check = kittyValidateParentChain(self, parent, image_id, placement_id);
            if (chain_check) |err_msg| return err_msg;
        } else {
            if (kittyParentChainTooDeep(self, parent)) return "ETOODEEP";
        }
        const offset_x: i32 = control.parent_x;
        const offset_y: i32 = control.parent_y;
        const parent_row: i32 = @intCast(parent.row);
        const parent_col: i32 = @intCast(parent.col);
        const new_row = parent_row + offset_y;
        const new_col = parent_col + offset_x;
        if (new_row < 0 or new_col < 0) return "EINVAL";
        row = @as(u16, @intCast(new_row));
        col = @as(u16, @intCast(new_col));
        if (row >= screen.grid.rows or col >= screen.grid.cols) return "EINVAL";
    }
    const visible_top = common.kittyVisibleTop(self);
    const placement_id = control.placement_id orelse 0;
    const placement = common.KittyPlacement{
        .image_id = image_id,
        .placement_id = placement_id,
        .row = row,
        .col = col,
        .cols = @intCast(control.cols),
        .rows = @intCast(control.rows),
        .z = control.z,
        .anchor_row = visible_top + @as(u64, row),
        .is_virtual = control.virtual != 0,
        .parent_image_id = parent_image_id,
        .parent_placement_id = parent_placement_id,
        .offset_x = control.parent_x,
        .offset_y = control.parent_y,
    };
    if (placement_id != 0) {
        if (KittyPlacementOps.findIndex(self, image_id, placement_id)) |idx| {
            KittyPlacementOps.markPlacementDirty(self, kitty.placements.items[idx], @src());
            kitty.placements.items[idx] = placement;
        } else {
            kitty.placements.append(self.allocator, placement) catch |err| {
                log.logf(.warning, "kitty placement append failed id={d} pid={d} err={s}", .{ image_id, placement_id, @errorName(err) });
                return "ENOMEM";
            };
        }
    } else {
        kitty.placements.append(self.allocator, placement) catch |err| {
            log.logf(.warning, "kitty placement append failed id={d} err={s}", .{ image_id, @errorName(err) });
            return "ENOMEM";
        };
    }
    KittyPlacementOps.markPlacementDirty(self, placement, @src());
    log.logf(.info, "kitty placed id={d} row={d} col={d} cols={d} rows={d}", .{ image_id, row, col, placement.cols, placement.rows });

    if (control.cursor_movement != 1) {
        const cols = KittyPlacementOps.effectiveColumns(self, control, image_id);
        const rows = KittyPlacementOps.effectiveRows(self, control, image_id);
        if (rows > 0) {
            var moved: u32 = 0;
            while (moved < rows) : (moved += 1) {
                self.newline();
            }
            screen.cursor.col = @min(@as(usize, col) + cols, @as(usize, screen.grid.cols - 1));
        } else if (cols > 0) {
            screen.cursor.col = @min(@as(usize, col) + cols, @as(usize, screen.grid.cols - 1));
        }
        screen.wrap_next = false;
    }
    return null;
}

fn kittyValidateParentChain(self: anytype, parent: common.KittyPlacement, image_id: u32, placement_id: u32) ?[]const u8 {
    var current = parent;
    var depth: u8 = 1;
    while (true) {
        if (depth > common.kitty_parent_max_depth) return "ETOODEEP";
        if (current.parent_image_id == 0 or current.parent_placement_id == 0) break;
        if (current.parent_image_id == image_id and current.parent_placement_id == placement_id) return "ECYCLE";
        const next = KittyPlacementOps.find(self, current.parent_image_id, current.parent_placement_id) orelse break;
        current = next;
        depth += 1;
    }
    return null;
}

fn kittyParentChainTooDeep(self: anytype, parent: common.KittyPlacement) bool {
    var current = parent;
    var depth: u8 = 1;
    while (true) {
        if (depth > common.kitty_parent_max_depth) return true;
        if (current.parent_image_id == 0 or current.parent_placement_id == 0) break;
        const next = KittyPlacementOps.find(self, current.parent_image_id, current.parent_placement_id) orelse break;
        current = next;
        depth += 1;
    }
    return false;
}
