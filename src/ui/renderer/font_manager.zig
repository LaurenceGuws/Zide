const std = @import("std");
const app_logger = @import("../../app_logger.zig");
const renderer_root = @import("../renderer.zig");
const terminal_font_mod = @import("../terminal_font.zig");
const TerminalFont = terminal_font_mod.TerminalFont;
const iface = @import("interface.zig");

const Renderer = renderer_root.Renderer;

const FontInitResult = struct {
    font: TerminalFont,
    metrics: Renderer.ScaledFontMetrics,
};

fn initFont(renderer: anytype, path: [*:0]const u8, layout_size: f32) !FontInitResult {
    const render_scale = if (renderer.render_scale > 0.0) renderer.render_scale else 1.0;
    const raster_size = layout_size * render_scale;
    var font = try TerminalFont.init(
        renderer.allocator,
        path,
        raster_size,
        iface.SYMBOLS_FALLBACK_PATH,
        iface.UNICODE_SYMBOLS2_PATH,
        iface.UNICODE_SYMBOLS_PATH,
        iface.UNICODE_MONO_PATH,
        iface.UNICODE_SANS_PATH,
        iface.EMOJI_COLOR_FALLBACK_PATH,
        iface.EMOJI_TEXT_FALLBACK_PATH,
        renderer.font_rendering,
    );
    font.render_scale = render_scale;
    font.setAtlasFilterPoint();
    return .{
        .font = font,
        .metrics = .{
            .ascent = font.ascent / render_scale,
            .descent = font.descent / render_scale,
            .line_height = font.line_height / render_scale,
            .cell_width = font.cell_width / render_scale,
            .cell_height = font.line_height / render_scale,
            .baseline_from_top = font.baseline_from_top / render_scale,
        },
    };
}

fn setOwnedFontPath(renderer: anytype, owned_slot: *?[]u8, path_slot: *[*:0]const u8, raw: []const u8) !void {
    const owned = try renderer.allocator.alloc(u8, raw.len + 1);
    errdefer renderer.allocator.free(owned);
    std.mem.copyForwards(u8, owned[0..raw.len], raw);
    owned[raw.len] = 0;
    if (owned_slot.*) |old| renderer.allocator.free(old);
    owned_slot.* = owned;
    path_slot.* = @ptrCast(owned.ptr);
}

pub fn initFonts(renderer: anytype) !void {
    const log = app_logger.logger("renderer.font");
    const render_scale = if (renderer.render_scale > 0.0) renderer.render_scale else 1.0;

    log.logf(
        .info,
        "initFonts app_path={s} app_base={d:.2} editor_path={s} editor_base={d:.2} terminal_path={s} terminal_base={d:.2} render_scale={d:.3} hinting={s} autohint={d} lcd={d}",
        .{
            renderer.app_font_path,
            renderer.font_size,
            renderer.editor_font_path,
            renderer.editor_font_size,
            renderer.terminal_font_path,
            renderer.terminal_font_size,
            render_scale,
            @tagName(renderer.font_rendering.hinting),
            @intFromBool(renderer.font_rendering.autohint),
            @intFromBool(renderer.font_rendering.lcd),
        },
    );

    var app_init = try initFont(renderer, renderer.app_font_path, renderer.font_size);
    errdefer app_init.font.deinit();
    var editor_init = try initFont(renderer, renderer.editor_font_path, renderer.editor_font_size);
    errdefer editor_init.font.deinit();
    var terminal_init = try initFont(renderer, renderer.terminal_font_path, renderer.terminal_font_size);
    errdefer terminal_init.font.deinit();
    var icon_init = try initFont(renderer, renderer.app_font_path, renderer.font_size * 2.0);
    errdefer icon_init.font.deinit();

    renderer.app_font = app_init.font;
    renderer.app_metrics = app_init.metrics;
    renderer.char_width = renderer.app_metrics.cell_width;
    renderer.char_height = renderer.app_metrics.cell_height;

    renderer.editor_font = editor_init.font;
    renderer.editor_metrics = editor_init.metrics;
    renderer.editor_char_width = renderer.editor_metrics.cell_width;
    renderer.editor_char_height = renderer.editor_metrics.cell_height;

    renderer.terminal_font = terminal_init.font;
    renderer.terminal_metrics = terminal_init.metrics;
    renderer.terminal_cell_width = renderer.terminal_metrics.cell_width;
    renderer.terminal_cell_height = renderer.terminal_metrics.cell_height;

    renderer.icon_font = icon_init.font;
    renderer.icon_font_size = renderer.font_size * 2.0;
    renderer.icon_metrics = icon_init.metrics;
    renderer.icon_char_width = renderer.icon_metrics.cell_width;
    renderer.icon_char_height = renderer.icon_metrics.cell_height;

    log.logf(
        .info,
        "metrics app={d:.2} app_cell={d:.2}x{d:.2} editor={d:.2} editor_cell={d:.2}x{d:.2} terminal={d:.2} terminal_cell={d:.2}x{d:.2} icon={d:.2}",
        .{
            renderer.font_size,
            renderer.app_metrics.cell_width,
            renderer.app_metrics.cell_height,
            renderer.editor_font_size,
            renderer.editor_metrics.cell_width,
            renderer.editor_metrics.cell_height,
            renderer.terminal_font_size,
            renderer.terminal_metrics.cell_width,
            renderer.terminal_metrics.cell_height,
            renderer.icon_font_size,
        },
    );
}

pub fn loadFont(renderer: anytype, path: [*:0]const u8, size: f32) void {
    const log = app_logger.logger("renderer.font");
    if (renderer.app_font_path_owned) |owned| {
        renderer.allocator.free(owned);
        renderer.app_font_path_owned = null;
    }
    renderer.app_font_path = path;
    renderer.base_font_size = size;
    applyFontScale(renderer) catch |err| {
        log.logf(.warning, "load font apply scale failed err={s}", .{@errorName(err)});
    };
}

pub fn setFontConfig(renderer: anytype, app_path: ?[]const u8, app_size: ?f32, editor_path: ?[]const u8, editor_size: ?f32, terminal_path: ?[]const u8, terminal_size: ?f32) !void {
    if (app_path) |raw| try setOwnedFontPath(renderer, &renderer.app_font_path_owned, &renderer.app_font_path, raw);
    if (app_size) |value| {
        if (value > 0.0) renderer.base_font_size = value;
    }
    if (editor_path) |raw| try setOwnedFontPath(renderer, &renderer.editor_font_path_owned, &renderer.editor_font_path, raw);
    if (editor_size) |value| {
        if (value > 0.0) renderer.editor_base_font_size = value;
    }
    if (terminal_path) |raw| try setOwnedFontPath(renderer, &renderer.terminal_font_path_owned, &renderer.terminal_font_path, raw);
    if (terminal_size) |value| {
        if (value > 0.0) renderer.terminal_base_font_size = value;
    }
    try applyFontScale(renderer);
}

pub fn applyFontScale(renderer: anytype) !void {
    renderer.font_size = renderer.base_font_size * renderer.ui_scale * renderer.user_zoom;
    renderer.editor_font_size = renderer.editor_base_font_size * renderer.ui_scale * renderer.user_zoom;
    renderer.terminal_font_size = renderer.terminal_base_font_size * renderer.ui_scale * renderer.user_zoom;

    var font_it = renderer.font_cache.iterator();
    while (font_it.next()) |entry| {
        entry.value_ptr.*.deinit();
        renderer.allocator.destroy(entry.value_ptr.*);
    }
    renderer.font_cache.clearRetainingCapacity();

    renderer.app_font.deinit();
    renderer.editor_font.deinit();
    renderer.terminal_font.deinit();
    renderer.icon_font.deinit();
    try initFonts(renderer);
}

pub fn fontForSize(renderer: anytype, size: f32) ?*TerminalFont {
    const log = app_logger.logger("renderer.font");
    if (std.math.approxEqAbs(f32, size, renderer.font_size, 0.01)) return &renderer.app_font;
    if (std.math.approxEqAbs(f32, size, renderer.icon_font_size, 0.01)) return &renderer.icon_font;
    const key: u32 = @intFromFloat(std.math.round(size));
    if (renderer.font_cache.get(key)) |font_ptr| return font_ptr;

    const font_ptr = renderer.allocator.create(TerminalFont) catch |err| {
        log.logf(.warning, "font cache alloc failed size_key={d} err={s}", .{ key, @errorName(err) });
        return null;
    };
    font_ptr.* = TerminalFont.init(
        renderer.allocator,
        renderer.app_font_path,
        @as(f32, @floatFromInt(key)) * renderer.render_scale,
        iface.SYMBOLS_FALLBACK_PATH,
        iface.UNICODE_SYMBOLS2_PATH,
        iface.UNICODE_SYMBOLS_PATH,
        iface.UNICODE_MONO_PATH,
        iface.UNICODE_SANS_PATH,
        iface.EMOJI_COLOR_FALLBACK_PATH,
        iface.EMOJI_TEXT_FALLBACK_PATH,
        renderer.font_rendering,
    ) catch {
        renderer.allocator.destroy(font_ptr);
        return null;
    };
    font_ptr.render_scale = renderer.render_scale;
    font_ptr.setAtlasFilterPoint();
    renderer.font_cache.put(key, font_ptr) catch |err| {
        log.logf(.warning, "font cache insert failed size_key={d} err={s}", .{ key, @errorName(err) });
        font_ptr.deinit();
        renderer.allocator.destroy(font_ptr);
        return null;
    };
    return font_ptr;
}
