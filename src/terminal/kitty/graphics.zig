const std = @import("std");
const app_logger = @import("../../app_logger.zig");
const common = @import("common.zig");
const transport_mod = @import("transport.zig");
const placement_mod = @import("placement_ops.zig");
const storage_mod = @import("storage_ops.zig");
const protocol_mod = @import("protocol_ops.zig");

pub const KittyImageFormat = common.KittyImageFormat;
pub const KittyImage = common.KittyImage;
pub const KittyPlacement = common.KittyPlacement;
pub const KittyKV = common.KittyKV;
pub const KittyPartial = common.KittyPartial;
pub const KittyControl = common.KittyControl;
pub const KittyBuildError = common.KittyBuildError;
pub const KittyState = common.KittyState;

const KittyTransport = transport_mod.KittyTransport;
const KittyPlacementOps = placement_mod.KittyPlacementOps;
const KittyStorageOps = storage_mod.KittyStorageOps;
const KittyProtocolOps = protocol_mod.KittyProtocolOps;

pub fn deinitKittyState(self: anytype, state: *KittyState) void {
    KittyStorageOps.deinitKittyState(self, state);
}

pub fn kittyState(self: anytype) *KittyState {
    return common.kittyState(self);
}

pub fn kittyStateConst(self: anytype) *const KittyState {
    return common.kittyStateConst(self);
}

pub fn parseKittyGraphics(self: anytype, payload: []const u8) void {
    KittyProtocolOps.parseAndDispatch(self, payload);
}

pub const parseKittyControl = protocol_mod.parseKittyControl;
pub const parseKittyValue = protocol_mod.parseKittyValue;
pub const parseKittySigned = protocol_mod.parseKittySigned;
pub const resolveKittyImageId = protocol_mod.resolveKittyImageId;
pub const validateKittyControl = protocol_mod.validateKittyControl;

pub fn updateKittyPlacementsForScroll(self: anytype) void {
    placement_mod.updateKittyPlacementsForScroll(self);
}

pub fn shiftKittyPlacementsUp(self: anytype, top: usize, bottom: usize, count: usize) void {
    placement_mod.shiftKittyPlacementsUp(self, top, bottom, count);
}

pub fn shiftKittyPlacementsDown(self: anytype, top: usize, bottom: usize, count: usize) void {
    placement_mod.shiftKittyPlacementsDown(self, top, bottom, count);
}

fn placeKittyImage(self: anytype, image_id: u32, control: KittyControl) ?[]const u8 {
    return placement_mod.placeKittyImage(self, image_id, control);
}

pub const writeKittyResponse = protocol_mod.writeKittyResponse;

pub fn clearKittyImages(self: anytype) void {
    KittyStorageOps.clearActive(self);
}

pub fn clearAllKittyImages(self: anytype) void {
    KittyStorageOps.clearAll(self);
}

test "kitty dirty region derives implicit cell span from image dimensions" {
    const image = KittyImage{
        .id = 1,
        .width = 20,
        .height = 40,
        .format = .rgba,
        .data = &.{},
        .version = 1,
    };
    const placement = KittyPlacement{
        .image_id = 1,
        .placement_id = 0,
        .row = 2,
        .col = 3,
        .cols = 0,
        .rows = 0,
        .z = 0,
        .anchor_row = 0,
        .is_virtual = false,
        .parent_image_id = 0,
        .parent_placement_id = 0,
        .offset_x = 0,
        .offset_y = 0,
    };

    switch (common.kittyPlacementDirtyRegion(image, placement, 10, 10, 8, 16)) {
        .partial => |region| {
            try std.testing.expectEqual(@as(usize, 2), region.start_row);
            try std.testing.expectEqual(@as(usize, 4), region.end_row);
            try std.testing.expectEqual(@as(usize, 3), region.start_col);
            try std.testing.expectEqual(@as(usize, 5), region.end_col);
        },
        else => try std.testing.expect(false),
    }
}

test "kitty dirty region falls back to full when implicit span cannot be derived" {
    const image = KittyImage{
        .id = 1,
        .width = 20,
        .height = 40,
        .format = .rgba,
        .data = &.{},
        .version = 1,
    };
    const placement = KittyPlacement{
        .image_id = 1,
        .placement_id = 0,
        .row = 0,
        .col = 0,
        .cols = 0,
        .rows = 0,
        .z = 0,
        .anchor_row = 0,
        .is_virtual = false,
        .parent_image_id = 0,
        .parent_placement_id = 0,
        .offset_x = 0,
        .offset_y = 0,
    };

    try std.testing.expectEqual(
        common.KittyDirtyPlacement.full,
        common.kittyPlacementDirtyRegion(image, placement, 10, 10, 0, 16),
    );
}
