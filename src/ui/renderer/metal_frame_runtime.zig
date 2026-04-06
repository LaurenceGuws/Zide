const app_logger = @import("../../app_logger.zig");
const screenshot = @import("screenshot.zig");
const present_trace_runtime = @import("present_trace_runtime.zig");
const sdl_api = @import("../../platform/sdl_api.zig");
const metal_backend = @import("metal_backend.zig");

pub fn beginFrame(renderer: anytype) void {
    metal_backend.clearQueuedSurfaceDraws(renderer);
    if (metal_backend.backendContext(renderer)) |context| {
        metal_backend.resizeBackendContext(context, renderer.render_width, renderer.render_height);
        var frame = metal_backend.acquireFrame(context) orelse {
            renderer.present.main_composition_target = .default_target;
            metal_backend.clearCurrentFrame(renderer);
            return;
        };
        const bg = renderer.theme.background.toRgba();
        const cleared = metal_backend.clearFrame(&frame, .{
            @as(f32, @floatFromInt(bg.r)) / 255.0,
            @as(f32, @floatFromInt(bg.g)) / 255.0,
            @as(f32, @floatFromInt(bg.b)) / 255.0,
            @as(f32, @floatFromInt(bg.a)) / 255.0,
        });
        if (!cleared) {
            metal_backend.abandonFrame(&frame);
            renderer.present.main_composition_target = .default_target;
            metal_backend.clearCurrentFrame(renderer);
            return;
        }
        renderer.present.main_composition_target = .backend_surface;
        metal_backend.storeCurrentFrame(renderer, frame);
    } else {
        renderer.present.main_composition_target = .default_target;
        metal_backend.clearCurrentFrame(renderer);
    }
}

pub fn submitFrame(renderer: anytype) present_trace_runtime.FrameSubmission {
    defer metal_backend.clearQueuedSurfaceDraws(renderer);
    const present_start = sdl_api.getPerformanceCounter();
    const succeeded = if (metal_backend.backendContext(renderer)) |context|
        if (metal_backend.currentFrame(renderer)) |frame| inner: {
            var capture_readback: ?metal_backend.Readback = null;
            defer if (capture_readback) |*readback| metal_backend.deinitReadback(readback);

            if (renderer.present.capture_armed) {
                capture_readback = metal_backend.prepareFrameReadback(context, frame);
            }

            metal_backend.replayQueuedSurfaceDraws(renderer, context, frame);

            _ = metal_backend.captureTerminalSnapshot(context, frame);

            metal_backend.encodePresent(frame);
            metal_backend.commitFrame(frame);

            if (capture_readback) |*readback| {
                metal_backend.waitForFrame(frame);
                if (renderer.present.capture_path) |path| {
                    const rgba = metal_backend.copyReadbackRgba(renderer.allocator, readback) catch |err| rgba_capture: {
                        app_logger.logger("renderer.present").logf(.warning, "capture failed frame_seq={d} path={s} err={s}", .{
                            renderer.present.frame_seq,
                            path,
                            @errorName(err),
                        });
                        break :rgba_capture null;
                    };
                    if (rgba) |pixels| {
                        defer renderer.allocator.free(pixels);
                        screenshot.dumpRgbaPixelsPpmScaled(
                            renderer.allocator,
                            pixels,
                            readback.width,
                            readback.height,
                            renderer.width,
                            renderer.height,
                            path,
                            .top_left,
                        ) catch |err| {
                            app_logger.logger("renderer.present").logf(.warning, "capture failed frame_seq={d} path={s} err={s}", .{
                                renderer.present.frame_seq,
                                path,
                                @errorName(err),
                            });
                        };
                        renderer.present.trace_current.captured_path = path;
                    }
                }
            } else if (renderer.present.capture_armed) {
                if (renderer.present.capture_path) |path| {
                    app_logger.logger("renderer.present").logf(.warning, "capture failed frame_seq={d} path={s} err=MetalReadbackUnavailable", .{
                        renderer.present.frame_seq,
                        path,
                    });
                }
            }

            metal_backend.releaseFrame(frame);
            metal_backend.clearCurrentFrame(renderer);
            break :inner true;
        } else false
    else
        false;
    const present_end = sdl_api.getPerformanceCounter();
    renderer.present.last_swap_ms = present_trace_runtime.performanceDeltaMs(present_start, present_end, renderer.perf_freq);
    renderer.present.main_composition_target = .default_target;
    renderer.present.trace_last = renderer.present.trace_current;
    renderer.present.capture_path = null;
    renderer.present.capture_armed = false;
    renderer.present.capture_frame_seq = 0;
    if (succeeded) renderer.present.submission_sequence += 1;
    return .{
        .succeeded = succeeded,
        .sequence = renderer.present.submission_sequence,
        .terminal_presented = renderer.present.trace_current.terminal_presentation_count > 0,
        .terminal_presented_generation = renderer.present.trace_current.terminal_presented_generation,
    };
}

pub fn dumpWindowScreenshotPpm(_: anytype, _: []const u8) !void {
    return error.RendererScreenshotUnavailable;
}

pub fn dumpWindowScreenshotPpmSized(_: anytype, _: []const u8, _: i32, _: i32) !void {
    return error.RendererScreenshotUnavailable;
}
