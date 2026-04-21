const std = @import("std");
const app_bootstrap = @import("bootstrap.zig");
const app_logger = @import("../app_logger.zig");
const app_shell = @import("../app_shell.zig");
const terminal_runtime = @import("../terminal/core/terminal_runtime.zig");
const session_runtime = @import("../terminal/core/session/runtime.zig");
const terminal_session_runtime_factory = @import("terminal/terminal_session_runtime_factory.zig");
const renderer_presentable_host = @import("../ui/renderer/renderer_presentable_host.zig");
const terminal_widget_draw = @import("../ui/widgets/terminal_widget_draw.zig");
const input_adapter_mod = @import("../ui/widgets/terminal_widget_input_bridge.zig");
const shared_types = @import("../types/mod.zig");

pub fn run(allocator: std.mem.Allocator) !void {
    const width = app_bootstrap.parseEnvI32("ZIDE_WINDOW_WIDTH", 1280);
    const height = app_bootstrap.parseEnvI32("ZIDE_WINDOW_HEIGHT", 720);
    const rows: u16 = @intCast(@max(@as(i32, 4), app_bootstrap.parseEnvI32("ZIDE_MACOS_METAL_TERMINAL_DIAGNOSTIC_ROWS", 8)));
    const cols: u16 = @intCast(@max(@as(i32, 8), app_bootstrap.parseEnvI32("ZIDE_MACOS_METAL_TERMINAL_DIAGNOSTIC_COLS", 28)));
    const frame_budget = app_bootstrap.parseEnvU64("ZIDE_MACOS_METAL_TERMINAL_DIAGNOSTIC_FRAMES", 90);
    const mutate_frame = app_bootstrap.parseEnvU64("ZIDE_MACOS_METAL_TERMINAL_DIAGNOSTIC_MUTATE_FRAME", std.math.maxInt(u64));
    const scroll_frame = app_bootstrap.parseEnvU64("ZIDE_MACOS_METAL_TERMINAL_DIAGNOSTIC_SCROLL_FRAME", std.math.maxInt(u64));
    const scroll_offset = @as(usize, @intCast(@max(@as(i32, 0), app_bootstrap.parseEnvI32("ZIDE_MACOS_METAL_TERMINAL_DIAGNOSTIC_SCROLL_OFFSET", 0))));
    const partial_update_frame = app_bootstrap.parseEnvU64("ZIDE_MACOS_METAL_TERMINAL_DIAGNOSTIC_PARTIAL_UPDATE_FRAME", std.math.maxInt(u64));
    const disable_kitty = app_bootstrap.parseEnvBool("ZIDE_MACOS_METAL_TERMINAL_DIAGNOSTIC_DISABLE_KITTY") orelse false;
    const special_glyph_fixture = app_bootstrap.parseEnvBool("ZIDE_MACOS_METAL_TERMINAL_DIAGNOSTIC_SPECIAL_GLYPHS") orelse false;
    const dashboard_fixture = app_bootstrap.parseEnvBool("ZIDE_MACOS_METAL_TERMINAL_DIAGNOSTIC_DASHBOARD") orelse false;
    const screenshot_path = app_bootstrap.envSlice("ZIDE_MACOS_METAL_TERMINAL_DIAGNOSTIC_SCREENSHOT");
    const title: [*:0]const u8 = "Zide macOS Metal Terminal Diagnostic";

    try app_logger.init();
    defer app_logger.deinit();

    const init_options: app_shell.RendererInitOptions = .{
        .renderer_backend = .metal,
        .runtime_profile = .backend_smoke,
    };

    const shell = try app_shell.Shell.init(allocator, width, height, title, init_options);
    defer shell.deinit(allocator);

    // Default renderer policy enables recent-input force-full publication; this diagnostic
    // injects PTY bytes without going through widget input, but disabling the policy keeps
    // partial-plan frames reproducible when any code path touches blink/input timing.
    shell.renderer.setTerminalRecentInputFullPublicationPolicy(false, null);

    // Metal cannot texture-scroll the snapshot presentable yet; leaving shift planning enabled
    // can pair generation-changed viewport-shift attempts with scrollPresentable=false and
    // force full-frame presentation. Disable shift only when exercising the partial snapshot
    // update proof so the planner can stay on honest row-local partial damage.
    if (partial_update_frame != std.math.maxInt(u64)) {
        shell.renderer.setTerminalPresentationShiftEnabled(false);
    }

    _ = try shell.refreshWindowState("macos-metal-terminal-diagnostic-init", .{
        .resized = true,
        .pixel_size_changed = true,
        .display_changed = true,
        .display_scale_changed = true,
    });

    var session = try terminal_runtime.init(allocator, rows, cols);
    defer session.deinit();
    session_runtime.attachExternalTransport(session);

    const cell_geometry = shell.terminalCellGeometry();
    try session_runtime.resizeWithCellSize(
        session,
        rows,
        cols,
        @intCast(@max(1, cell_geometry.cell_width_device_px)),
        @intCast(@max(1, cell_geometry.cell_height_device_px)),
    );

    const seed_bytes =
        if (dashboard_fixture)
            dashboardSeedBytes()
        else if (special_glyph_fixture)
            "\x1b[HCPU  92%  RAM\x1b[2;1HBOX ┌┬┐├┼┤└┴┘│─╭╮╯╰\x1b[3;1HSHD ░▒▓█▇▆▅▄▃▂▁\x1b[4;1HBRA ⣀⣤⣶⣿⣷⣄⡀ test\x1b[5;1HPWR \x1b[6;1HGLYPH lane stress active"
        else
            "\x1b[H1| build one\x1b[2;1H2| item two\x1b[3;1H3| plain ascii\x1b[4;1H4| fallback row\x1b[5;1H5| metal lane\x1b[6;1H6| terminal ok";
    if (!(try session_runtime.enqueueExternalBytes(session, seed_bytes))) return error.MetalTerminalDiagnosticSeedRejected;
    try session_runtime.poll(session);
    if (scroll_frame != std.math.maxInt(u64)) {
        const scroll_seed_bytes = if (dashboard_fixture)
            dashboardScrollSeedBytes()
        else
            "\n7| history one\n8| history two\n9| history three\n10| history four";
        if (!(try session_runtime.enqueueExternalBytes(session, scroll_seed_bytes))) return error.MetalTerminalDiagnosticScrollSeedRejected;
        try session_runtime.poll(session);
    }
    if (!disable_kitty) try seedDiagnosticKittyImages(session);

    var widget = terminal_session_runtime_factory.initWidget(session, .kitty, false, false);
    defer widget.deinit();
    widget.setUiFocused(true);
    const input_adapter = input_adapter_mod.TerminalInputAdapter.init(session);

    const input = shared_types.input.InputSnapshot.init(.{ .x = 0, .y = 0 }, .{});

    const log = app_logger.logger("macos.metal.terminal_diagnostic");
    const capabilities = shell.rendererCapabilities();
    log.logf(.info, "start width={d} height={d} rows={d} cols={d} frame_budget={d} special_glyph_fixture={d} dashboard_fixture={d}", .{ width, height, rows, cols, frame_budget, @intFromBool(special_glyph_fixture), @intFromBool(dashboard_fixture) });
    log.logf(
        .info,
        "capabilities composition={s} retained_targets={d} terminal_present={s} screenshot={s} text={s} planned_text={s} atlas={s} planned_atlas={s} raw_image_textures={d} snapshot_available={d}",
        .{
            @tagName(capabilities.scene_composition_mode),
            @intFromBool(capabilities.retained_targets),
            @tagName(capabilities.terminal_presentation_mode),
            @tagName(capabilities.screenshot_mode),
            @tagName(capabilities.text_rendering_mode),
            @tagName(capabilities.planned_text_rendering_mode),
            @tagName(capabilities.atlas_storage_mode),
            @tagName(capabilities.planned_atlas_storage_mode),
            @intFromBool(capabilities.raw_image_textures),
            @intFromBool(renderer_presentable_host.terminalPresentableInfo(shell.rendererPtr()) != null),
        },
    );

    var last_metrics_seq: u64 = 0;
    var frame_index: u64 = 0;
    while (frame_index < frame_budget and !shell.shouldClose()) : (frame_index += 1) {
        app_shell.pollInputEvents();
        if (frame_index == mutate_frame) {
            const mutation_bytes = if (dashboard_fixture)
                dashboardMutationBytes()
            else
                "\x1b[2;1H2| row changed\x1b[3;1H3| partial draw";
            if (!(try session_runtime.enqueueExternalBytes(session, mutation_bytes))) return error.MetalTerminalDiagnosticMutationRejected;
            try session_runtime.poll(session);
            input_adapter.setScrollOffset(0);
        }
        if (frame_index == partial_update_frame) {
            const partial_bytes = if (dashboard_fixture)
                dashboardPartialUpdateBytes()
            else blk: {
                var partial_scratch: [64]u8 = undefined;
                break :blk std.fmt.bufPrint(
                    &partial_scratch,
                    "\x1b[{d};{d}H*",
                    .{ rows, cols },
                ) catch unreachable;
            };
            if (!(try session_runtime.enqueueExternalBytes(session, partial_bytes))) return error.MetalTerminalDiagnosticPartialUpdateRejected;
            try session_runtime.poll(session);
        }
        if (frame_index == scroll_frame) {
            input_adapter.setScrollOffset(scroll_offset);
        }
        const changes = app_shell.windowChanges();
        if (changes.affectsWindowRefresh()) {
            _ = try shell.refreshWindowState("macos-metal-terminal-diagnostic-frame", changes);
        }

        const frame_ready = shell.beginFrame();
        if (frame_ready) {
            if (screenshot_path) |path| {
                if (frame_index + 1 == frame_budget) {
                    shell.armPresentCapture(path);
                }
            }

            const draw_outcome = widget.draw(shell, 0.0, 0.0, @floatFromInt(width), @floatFromInt(height), input);
            widget.stagePresentationFeedback(draw_outcome);
        }

        const submission = shell.endFrame();
        widget.completePendingPresentationFeedback(submission);
        if (!submission.succeeded) return error.MetalTerminalDiagnosticPresentFailed;

        const metrics = terminal_widget_draw.latestFrameLatencyMetrics();
        if (metrics.seq != 0 and metrics.seq != last_metrics_seq) {
            last_metrics_seq = metrics.seq;
            const uncategorized_special_glyphs =
                metrics.shaped_special_glyphs -
                metrics.powerline_special_glyphs -
                metrics.shade_special_glyphs -
                metrics.braille_special_glyphs -
                metrics.box_glyphs;
            log.logf(
                .info,
                "frame={d} submitted={d} sequence={d} special_sprite_glyphs={d} shaped_special_glyphs={d} powerline={d} shade={d} braille={d} box={d} other_special={d} kitty_ms={d:.3} snapshot_available={d} metric_present_sample={s}",
                .{
                    frame_index,
                    @intFromBool(submission.succeeded),
                    submission.sequence,
                    metrics.special_sprite_glyphs,
                    metrics.shaped_special_glyphs,
                    metrics.powerline_special_glyphs,
                    metrics.shade_special_glyphs,
                    metrics.braille_special_glyphs,
                    metrics.box_glyphs,
                    uncategorized_special_glyphs,
                    metrics.presentation_kitty_ms,
                    @intFromBool(renderer_presentable_host.terminalPresentableInfo(shell.rendererPtr()) != null),
                    @tagName(metrics.terminal_presentation_sample_mode),
                },
            );
            log.logf(.info, "frame={d} metric_terminal_present={s}", .{
                frame_index,
                @tagName(metrics.terminal_presentation_mode),
            });
        } else {
            log.logf(.info, "frame={d} submitted={d} sequence={d}", .{
                frame_index,
                @intFromBool(submission.succeeded),
                submission.sequence,
            });
        }

        app_shell.waitTime(0.016);
    }

    const final_metrics = terminal_widget_draw.latestFrameLatencyMetrics();
    const final_uncategorized_special_glyphs =
        final_metrics.shaped_special_glyphs -
        final_metrics.powerline_special_glyphs -
        final_metrics.shade_special_glyphs -
        final_metrics.braille_special_glyphs -
        final_metrics.box_glyphs;
    log.logf(
        .info,
        "complete frames={d} special_sprite_glyphs={d} shaped_special_glyphs={d} powerline={d} shade={d} braille={d} box={d} other_special={d} metric_terminal_present={s} metric_present_sample={s} kitty_ms={d:.3} snapshot_available={d}",
        .{
            frame_index,
            final_metrics.special_sprite_glyphs,
            final_metrics.shaped_special_glyphs,
            final_metrics.powerline_special_glyphs,
            final_metrics.shade_special_glyphs,
            final_metrics.braille_special_glyphs,
            final_metrics.box_glyphs,
            final_uncategorized_special_glyphs,
            @tagName(final_metrics.terminal_presentation_mode),
            @tagName(final_metrics.terminal_presentation_sample_mode),
            final_metrics.presentation_kitty_ms,
            @intFromBool(renderer_presentable_host.terminalPresentableInfo(shell.rendererPtr()) != null),
        },
    );
}

fn seedDiagnosticKittyImages(session: *terminal_runtime.TerminalRuntimeShell) !void {
    var below_rgba = [_]u8{
        0xD0, 0x44, 0x44, 0xFF, 0xD0, 0x44, 0x44, 0xFF,
        0xD0, 0x44, 0x44, 0xFF, 0xD0, 0x44, 0x44, 0xFF,
    };
    var above_rgba = [_]u8{
        0x44, 0x98, 0xE8, 0xFF, 0x44, 0x98, 0xE8, 0xFF,
        0x44, 0x98, 0xE8, 0xFF, 0x44, 0x98, 0xE8, 0xFF,
    };

    const seeds = [_]session_runtime.DiagnosticKittySeed{
        .{
            .which = .primary,
            .image = .{
                .id = 1,
                .width = 2,
                .height = 2,
                .format = .rgba,
                .data = below_rgba[0..],
                .version = 1,
            },
            .placement = .{
                .image_id = 1,
                .placement_id = 1,
                .row = 1,
                .col = 18,
                .cols = 2,
                .rows = 1,
                .z = -1,
                .anchor_row = 0,
                .is_virtual = false,
                .parent_image_id = 0,
                .parent_placement_id = 0,
                .offset_x = 0,
                .offset_y = 0,
            },
        },
        .{
            .which = .primary,
            .image = .{
                .id = 2,
                .width = 2,
                .height = 2,
                .format = .rgba,
                .data = above_rgba[0..],
                .version = 1,
            },
            .placement = .{
                .image_id = 2,
                .placement_id = 1,
                .row = 4,
                .col = 20,
                .cols = 2,
                .rows = 1,
                .z = 1,
                .anchor_row = 0,
                .is_virtual = false,
                .parent_image_id = 0,
                .parent_placement_id = 0,
                .offset_x = 0,
                .offset_y = 0,
            },
        },
    };
    try session_runtime.replaceDiagnosticKittyState(session, seeds[0..]);
}

fn dashboardSeedBytes() []const u8 {
    return "\x1b[H╭─ btop-ish metal lane ¹²³⁴° ─────────────────────╮" ++
        "\x1b[2;1H│ CPU  ███████░░░ 72%   NET  ▂▃▄▅▆▇█        │" ++
        "\x1b[3;1H│ MEM  ▏▎▍▌▋▊▉█ 61%   DISK ▔▕░▒▓█▇▆▅▄      │" ++
        "\x1b[4;1H╔══ dbl ══╦══ load ══╦══ nets ══╦══ bars ════╗" ++
        "\x1b[5;1H│ mixed    │╒╓╕╖╘╙╛╜╞╟╡╢╤╥╧╨╪╫│ box  │┌┬┐├┼┤││" ++
        "\x1b[6;1H│ heavy    │┏┳┓┣╋┫┗┻┛┠┨┰┸╂   │ pwr  ││" ++
        "\x1b[7;1H╠══ indi ═╬←↑→↓↵▶◀●○◆□✓✗╬══ brai ═╬══ ring ════╣" ++
        "\x1b[8;1H╰─ bars ▁▂▃▄▅▆▇█ braille ⣀⣤⣶  ╭╮╯╰ ───────╯";
}

fn dashboardMutationBytes() []const u8 {
    return "\x1b[2;1H│ CPU  ████████▓░ 86%   NET  ▃▄▅▆▇██        │" ++
        "\x1b[3;1H│ MEM  ▎▍▌▋▊▉██ 68%   DISK ▔▕▒▓████▇▆      │" ++
        "\x1b[6;1H│ temp 47C │█████████    │ pwr  ││";
}

fn dashboardPartialUpdateBytes() []const u8 {
    return "\x1b[8;9H▒▓█\x1b[8;26H⣶⣿⣷";
}

fn dashboardScrollSeedBytes() []const u8 {
    return "\n╔══ hist ══╦═ cpu ═╦═ mem ═╦═ net ═╗" ++
        "\n║ row 09   ║ ████  ║ ▓▓▓▒  ║ ⣀⣤  ║" ++
        "\n║ row 10   ║ █████ ║ ▓▓▓▓  ║ ⣤⣶  ║" ++
        "\n╚══════════╩═══════╩═══════╩═══════╝";
}
