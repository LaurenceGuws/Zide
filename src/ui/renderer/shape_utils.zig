const types = @import("types.zig");

pub fn rectFromInts(x: i32, y: i32, w: i32, h: i32) types.Rect {
    return .{
        .x = @floatFromInt(x),
        .y = @floatFromInt(y),
        .width = @floatFromInt(w),
        .height = @floatFromInt(h),
    };
}

pub fn unitRect() types.Rect {
    return .{ .x = 0, .y = 0, .width = 1, .height = 1 };
}
