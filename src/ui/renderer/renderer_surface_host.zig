const gl_backend = @import("gl_backend.zig");
const metal_text_sample_runtime = @import("metal_text_sample_runtime.zig");
const present_trace_runtime = @import("present_trace_runtime.zig");
const shape_draw = @import("shape_draw.zig");
const surface_draw = @import("surface_draw.zig");
const types = @import("types.zig");

fn recordSurfaceDraw(renderer: anytype, draw: surface_draw.SurfaceDraw) bool {
    return renderer.backend.ops.surface.recordSurfaceDraw(renderer, draw);
}

pub fn drawRect(renderer: anytype, x: i32, y: i32, w: i32, h: i32, color: anytype) void {
    if (w <= 0 or h <= 0) return;
    present_trace_runtime.noteEditorSurfaceFullPaneClear(renderer, x, y, w, h);
    _ = recordSolidSurfaceFromLogicalRect(
        renderer,
        @floatFromInt(x),
        @floatFromInt(y),
        @floatFromInt(w),
        @floatFromInt(h),
        color.toRgba(),
    );
}

pub fn drawRectF(renderer: anytype, x: f32, y: f32, w: f32, h: f32, color: anytype) void {
    if (w <= 0 or h <= 0) return;
    _ = recordSolidSurfaceFromLogicalRect(renderer, x, y, w, h, color.toRgba());
}

pub fn drawRectOutline(renderer: anytype, x: i32, y: i32, w: i32, h: i32, color: anytype) void {
    const RendererType = @TypeOf(renderer);
    const ColorType = @TypeOf(color);
    const Local = struct {
        fn drawRectThunk(ctx: *anyopaque, thunk_x: i32, thunk_y: i32, thunk_w: i32, thunk_h: i32, thunk_color: ColorType) void {
            const thunk_renderer: RendererType = @ptrCast(@alignCast(ctx));
            drawRect(thunk_renderer, thunk_x, thunk_y, thunk_w, thunk_h, thunk_color);
        }
    };
    shape_draw.drawRectOutline(Local.drawRectThunk, renderer, x, y, w, h, color);
}

pub fn recordSolidSurfaceFromLogicalRect(
    renderer: anytype,
    x: f32,
    y: f32,
    w: f32,
    h: f32,
    color: types.Rgba,
) bool {
    const clip = if (renderer.currentClipRect()) |c|
        metal_text_sample_runtime.pixelClipRect(renderer, c)
    else
        null;
    return recordSurfaceDraw(renderer, .{ .solid = .{
        .dest_rect = .{
            .x = renderer.logicalLengthToRaster(x),
            .y = renderer.logicalLengthToRaster(y),
            .width = renderer.logicalLengthToRaster(w),
            .height = renderer.logicalLengthToRaster(h),
        },
        .color = color,
        .clip_rect = clip,
    } });
}

/// OpenGL may queue `SurfaceDraw` solids for submit-time replay; flush now so subsequent
/// immediate surface work (overlays, selection, etc.) composites in list order.
pub fn flushQueuedSurfaceDrawsBeforeDependentSurfaceWork(renderer: anytype) void {
    gl_backend.flushQueuedSurfaceDrawsBeforeImmediateWork(renderer);
}
