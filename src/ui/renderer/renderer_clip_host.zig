const present_trace_runtime = @import("present_trace_runtime.zig");
const renderer_root = @import("../renderer.zig");
const types = @import("types.zig");

const Renderer = renderer_root.Renderer;

pub fn beginClip(renderer: *Renderer, x: i32, y: i32, w: i32, h: i32) void {
    present_trace_runtime.noteCompositionClip(renderer);
    const requested = logicalClipFromInts(x, y, w, h) orelse {
        renderer.clip_depth = 0;
        renderer.backend.ops.clip.applyClipRect(renderer, null);
        return;
    };
    const next = if (renderer.currentClipRect()) |current|
        intersectRect(current, requested) orelse types.Rect{
            .x = requested.x,
            .y = requested.y,
            .width = 0,
            .height = 0,
        }
    else
        requested;
    if (renderer.clip_depth < renderer.clip_stack.len) {
        renderer.clip_stack[renderer.clip_depth] = next;
        renderer.clip_depth += 1;
    } else {
        renderer.clip_stack[renderer.clip_stack.len - 1] = next;
    }
    renderer.backend.ops.clip.applyClipRect(renderer, next);
}

pub fn endClip(renderer: *Renderer) void {
    if (renderer.clip_depth > 0) renderer.clip_depth -= 1;
    renderer.backend.ops.clip.applyClipRect(renderer, renderer.currentClipRect());
}

fn logicalClipFromInts(x: i32, y: i32, w: i32, h: i32) ?types.Rect {
    if (w <= 0 or h <= 0) return null;
    return .{ .x = @floatFromInt(x), .y = @floatFromInt(y), .width = @floatFromInt(w), .height = @floatFromInt(h) };
}

fn intersectRect(a: types.Rect, b: types.Rect) ?types.Rect {
    const x0 = @max(a.x, b.x);
    const y0 = @max(a.y, b.y);
    const x1 = @min(a.x + a.width, b.x + b.width);
    const y1 = @min(a.y + a.height, b.y + b.height);
    if (x1 <= x0 or y1 <= y0) return null;
    return .{ .x = x0, .y = y0, .width = x1 - x0, .height = y1 - y0 };
}
