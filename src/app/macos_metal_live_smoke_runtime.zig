const std = @import("std");
const app_bootstrap = @import("bootstrap.zig");
const app_logger = @import("../app_logger.zig");
const app_shell = @import("../app_shell.zig");
const metal_text_diagnostic_view = @import("../ui/metal_text_diagnostic_view.zig");

pub fn shouldRun() bool {
    return app_bootstrap.parseEnvBool("ZIDE_MACOS_METAL_LIVE_SMOKE") orelse false;
}

pub fn run(allocator: std.mem.Allocator) !void {
    const width = app_bootstrap.parseEnvI32("ZIDE_WINDOW_WIDTH", 1280);
    const height = app_bootstrap.parseEnvI32("ZIDE_WINDOW_HEIGHT", 720);
    const frame_budget = app_bootstrap.parseEnvU64("ZIDE_MACOS_METAL_LIVE_SMOKE_FRAMES", 90);
    const screenshot_path = app_bootstrap.envSlice("ZIDE_MACOS_METAL_LIVE_SMOKE_SCREENSHOT");
    const title: [*:0]const u8 = "Zide macOS Metal Live Smoke";

    try app_logger.init();
    defer app_logger.deinit();

    const init_options: app_shell.RendererInitOptions = .{
        .renderer_backend = .metal,
        .runtime_profile = .backend_smoke,
    };

    const shell = try app_shell.Shell.init(allocator, width, height, title, init_options);
    defer shell.deinit(allocator);

    _ = try shell.refreshWindowState("macos-metal-live-smoke-init", .{
        .resized = true,
        .pixel_size_changed = true,
        .display_changed = true,
        .display_scale_changed = true,
    });

    const log = app_logger.logger("macos.metal.live_smoke");
    const capabilities = shell.rendererCapabilities();
    const atlas_upload_probe = (metal_text_diagnostic_view.View{}).activate(shell);
    const atlas_preview_source = shell.rendererPtr().metalAtlasPreviewSource();
    log.logf(.info, "start width={d} height={d} frame_budget={d}", .{ width, height, frame_budget });
    log.logf(
        .info,
        "capabilities composition={s} retained_targets={d} screenshot={s} text={s} planned_text={s} atlas={s} planned_atlas={s} atlas_ready={d} atlas_upload_probe={d} atlas_preview_source={s}",
        .{
            @tagName(capabilities.scene_composition_mode),
            @intFromBool(capabilities.retained_targets),
            @tagName(capabilities.screenshot_mode),
            @tagName(capabilities.text_rendering_mode),
            @tagName(capabilities.planned_text_rendering_mode),
            @tagName(capabilities.atlas_storage_mode),
            @tagName(capabilities.planned_atlas_storage_mode),
            @intFromBool(shell.rendererPtr().metalGlyphAtlasReady()),
            @intFromBool(atlas_upload_probe),
            @tagName(atlas_preview_source),
        },
    );

    var frame_index: u64 = 0;
    while (frame_index < frame_budget and !shell.shouldClose()) : (frame_index += 1) {
        app_shell.pollInputEvents();
        const changes = app_shell.windowChanges();
        if (changes.affectsWindowRefresh()) {
            _ = try shell.refreshWindowState("macos-metal-live-smoke-frame", changes);
        }

        shell.beginFrame();
        if (screenshot_path) |path| {
            if (frame_index + 1 == frame_budget) {
                shell.armPresentCapture(path);
            }
        }
        const submission = shell.endFrame();
        log.logf(.info, "frame={d} submitted={d} sequence={d}", .{
            frame_index,
            @intFromBool(submission.succeeded),
            submission.sequence,
        });
        if (!submission.succeeded) return error.MetalLiveSmokePresentFailed;

        app_shell.waitTime(0.016);
    }

    log.logf(.info, "complete frames={d}", .{frame_index});
}
