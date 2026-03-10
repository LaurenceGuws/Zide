const std = @import("std");
const snapshot_mod = @import("../core/snapshot.zig");

pub const KittyImageFormat = snapshot_mod.KittyImageFormat;
pub const KittyImage = snapshot_mod.KittyImage;
pub const KittyPlacement = snapshot_mod.KittyPlacement;

pub const KittyKV = struct {
    key: u8,
    value: u32,
};

pub const KittyPartial = struct {
    id: u32,
    width: u32,
    height: u32,
    format: KittyImageFormat,
    format_value: u32,
    data: std.ArrayList(u8),
    expected_size: u32,
    received: u32,
    compression: u8,
    quiet: u8,
    size_initialized: bool,
    auto_place: bool,
    placement_id: ?u32,
    cols: u32,
    rows: u32,
    z: i32,
    cursor_movement: u8,
    virtual: u32,
    parent_id: ?u32,
    child_id: ?u32,
    parent_x: i32,
    parent_y: i32,
};

pub const KittyControl = struct {
    action: u8 = 't',
    quiet: u8 = 0,
    delete_action: u8 = 'a',
    format: u32 = 0,
    medium: u8 = 'd',
    compression: u8 = 0,
    width: u32 = 0,
    height: u32 = 0,
    size: u32 = 0,
    offset: u32 = 0,
    image_id: ?u32 = null,
    image_number: ?u32 = null,
    placement_id: ?u32 = null,
    cols: u32 = 0,
    rows: u32 = 0,
    x: u32 = 0,
    y: u32 = 0,
    x_offset: u32 = 0,
    y_offset: u32 = 0,
    z: i32 = 0,
    cursor_movement: u8 = 0,
    virtual: u32 = 0,
    parent_id: ?u32 = null,
    child_id: ?u32 = null,
    parent_x: i32 = 0,
    parent_y: i32 = 0,
    more: bool = false,
};

pub const KittyBuildError = error{
    InvalidData,
    BadPng,
};

pub const kitty_max_bytes: usize = 320 * 1024 * 1024;
pub const kitty_parent_max_depth: u8 = 10;

pub const KittyState = struct {
    images: std.ArrayList(KittyImage),
    placements: std.ArrayList(KittyPlacement),
    partials: std.AutoHashMap(u32, KittyPartial),
    next_id: u32,
    loading_image_id: ?u32,
    generation: u64,
    total_bytes: usize,
    scrollback_total: u64,
};

pub fn kittyState(self: anytype) *KittyState {
    return if (self.core.active == .alt) &self.core.kitty_alt else &self.core.kitty_primary;
}

pub fn kittyStateConst(self: anytype) *const KittyState {
    return if (self.core.active == .alt) &self.core.kitty_alt else &self.core.kitty_primary;
}

pub fn clearKittyLoading(kitty: *KittyState, image_id: u32) void {
    if (kitty.loading_image_id) |loading_id| {
        if (loading_id == image_id) {
            kitty.loading_image_id = null;
        }
    }
}

pub fn findKittyImageById(images: []const KittyImage, image_id: u32) ?KittyImage {
    for (images) |image| {
        if (image.id == image_id) return image;
    }
    return null;
}

pub fn kittyImageHasPlacement(self: anytype, image_id: u32) bool {
    const kitty = kittyStateConst(self);
    for (kitty.placements.items) |placement| {
        if (placement.image_id == image_id) return true;
    }
    return false;
}

pub fn kittyVisibleTop(self: anytype) u64 {
    if (self.core.active == .alt) return 0;
    const kitty = kittyStateConst(self);
    const count = self.core.history.scrollbackCount();
    if (kitty.scrollback_total < count) return 0;
    return kitty.scrollback_total - count;
}

pub const KittyDirtyRegion = struct {
    start_row: usize,
    end_row: usize,
    start_col: usize,
    end_col: usize,
};

pub const KittyDirtyPlacement = union(enum) {
    none,
    partial: KittyDirtyRegion,
    full,
};

pub fn kittyPlacementDirtyRegion(
    image: ?KittyImage,
    placement: KittyPlacement,
    screen_rows: usize,
    screen_cols: usize,
    cell_width: u16,
    cell_height: u16,
) KittyDirtyPlacement {
    if (screen_rows == 0 or screen_cols == 0) return .none;

    const start_row = @as(usize, placement.row);
    const start_col = @as(usize, placement.col);
    if (start_row >= screen_rows or start_col >= screen_cols) return .none;

    const col_span = if (placement.cols > 0)
        @as(usize, placement.cols)
    else blk: {
        const kitty_image = image orelse return .full;
        if (cell_width == 0 or kitty_image.width == 0) return .full;
        break :blk @as(usize, std.math.divCeil(u32, kitty_image.width, cell_width) catch return .full);
    };
    const row_span = if (placement.rows > 0)
        @as(usize, placement.rows)
    else blk: {
        const kitty_image = image orelse return .full;
        if (cell_height == 0 or kitty_image.height == 0) return .full;
        break :blk @as(usize, std.math.divCeil(u32, kitty_image.height, cell_height) catch return .full);
    };

    const dirty_cols = @max(@as(usize, 1), col_span);
    const dirty_rows = @max(@as(usize, 1), row_span);
    return .{
        .partial = .{
            .start_row = start_row,
            .end_row = @min(screen_rows - 1, start_row + dirty_rows - 1),
            .start_col = start_col,
            .end_col = @min(screen_cols - 1, start_col + dirty_cols - 1),
        },
    };
}
