const std = @import("std");
const app_bootstrap = @import("bootstrap.zig");
const app_logger = @import("../app_logger.zig");
const app_shell = @import("../app_shell.zig");
const metal_text_diagnostic_view = @import("../ui/metal_text_diagnostic_view.zig");
const metal_text_sample_runtime = @import("../ui/renderer/metal_text_sample_runtime.zig");

pub fn run(allocator: std.mem.Allocator) !void {
    const width = app_bootstrap.parseEnvI32("ZIDE_WINDOW_WIDTH", 1280);
    const height = app_bootstrap.parseEnvI32("ZIDE_WINDOW_HEIGHT", 720);
    const frame_budget = app_bootstrap.parseEnvU64("ZIDE_MACOS_METAL_TEXT_DIAGNOSTIC_FRAMES", 90);
    const screenshot_path = app_bootstrap.envSlice("ZIDE_MACOS_METAL_TEXT_DIAGNOSTIC_SCREENSHOT");
    const title: [*:0]const u8 = "Zide macOS Metal Text Diagnostic";

    try app_logger.init();
    defer app_logger.deinit();

    const init_options: app_shell.RendererInitOptions = .{
        .renderer_backend = .metal,
        .runtime_profile = .backend_smoke,
    };

    const shell = try app_shell.Shell.init(allocator, width, height, title, init_options);
    defer shell.deinit(allocator);

    _ = try shell.refreshWindowState("macos-metal-text-diagnostic-init", .{
        .resized = true,
        .pixel_size_changed = true,
        .display_changed = true,
        .display_scale_changed = true,
    });

    const log = app_logger.logger("macos.metal.text_diagnostic");
    const capabilities = shell.rendererCapabilities();
    const atlas_upload_probe = (metal_text_diagnostic_view.View{}).activate(shell);
    const sample_text_draw = shell.rendererPtr().drawSampleTextRequest(metal_text_sample_runtime.SampleTextRequest{
        .text = "METAL\nTEXT",
        .x = 24.0,
        .y = 96.0,
        .tint = shell.theme().foreground.toRgba(),
        .layout = .monospace_cell,
        .clip_rect = .{
            .x = 24.0,
            .y = 96.0,
            .width = 220.0,
            .height = 96.0,
        },
    });
    shell.beginClip(
        24,
        220,
        @intFromFloat(std.math.round(shell.terminalCellWidth() * 8.0)),
        @intFromFloat(std.math.round(shell.terminalCellHeight())),
    );
    defer shell.endClip();
    const renderer = shell.rendererPtr();
    const terminal_cell_run_draw = renderer.drawTerminalCellRun(&renderer.terminal_font, metal_text_sample_runtime.TerminalCellRunRequest{
        .text = "$ ls",
        .x = 24.0,
        .y = 220.0,
        .cell_width = shell.terminalCellWidth(),
        .cell_height = shell.terminalCellHeight(),
        .tint = shell.theme().foreground.toRgba(),
    });
    const atlas_preview_source = shell.macosMetalAtlasPreviewSource();
    log.logf(.info, "start width={d} height={d} frame_budget={d}", .{ width, height, frame_budget });
    log.logf(
        .info,
        "capabilities composition={s} retained_targets={d} screenshot={s} text={s} planned_text={s} atlas={s} planned_atlas={s} atlas_ready={d} atlas_upload_probe={d} atlas_preview_source={s} sample_text_draw={d} terminal_cell_run_draw={d}",
        .{
            @tagName(capabilities.scene_composition_mode),
            @intFromBool(capabilities.retained_targets),
            @tagName(capabilities.screenshot_mode),
            @tagName(capabilities.text_rendering_mode),
            @tagName(capabilities.planned_text_rendering_mode),
            @tagName(capabilities.atlas_storage_mode),
            @tagName(capabilities.planned_atlas_storage_mode),
            @intFromBool(shell.macosMetalGlyphAtlasReady()),
            @intFromBool(atlas_upload_probe),
            @tagName(atlas_preview_source),
            @intFromBool(sample_text_draw),
            @intFromBool(terminal_cell_run_draw),
        },
    );

    var frame_index: u64 = 0;
    while (frame_index < frame_budget and !shell.shouldClose()) : (frame_index += 1) {
        app_shell.pollInputEvents();
        const changes = app_shell.windowChanges();
        if (changes.affectsWindowRefresh()) {
            _ = try shell.refreshWindowState("macos-metal-text-diagnostic-frame", changes);
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
        if (!submission.succeeded) return error.MetalTextDiagnosticPresentFailed;

        app_shell.waitTime(0.016);
    }

    log.logf(.info, "complete frames={d}", .{frame_index});
}
