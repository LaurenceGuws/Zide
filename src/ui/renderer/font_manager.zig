const std = @import("std");
const app_logger = @import("../../app_logger.zig");
const terminal_font_mod = @import("../terminal_font.zig");
const TerminalFont = terminal_font_mod.TerminalFont;
const iface = @import("interface.zig");

pub fn initFonts(renderer: anytype, size: f32) !void {
    const log = app_logger.logger("renderer.font");
    const render_scale = if (renderer.render_scale > 0.0) renderer.render_scale else 1.0;
    const raster_size = size * render_scale;
    log.logf(
        .info,
        "initFonts path={s} base={d:.2} render_scale={d:.3} raster={d:.2} hinting={s} autohint={d} lcd={d}",
        .{
            renderer.font_path,
            size,
            render_scale,
            raster_size,
            @tagName(renderer.font_rendering.hinting),
            @intFromBool(renderer.font_rendering.autohint),
            @intFromBool(renderer.font_rendering.lcd),
        },
    );
    renderer.terminal_font = try TerminalFont.init(
        renderer.allocator,
        renderer.font_path,
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
    renderer.terminal_font.render_scale = render_scale;
    renderer.terminal_font.setAtlasFilterPoint();
    // Keep logical cell metrics in render-scale units so zoom changes do not
    // oscillate spacing due to extra whole-pixel quantization in layout space.
    renderer.terminal_metrics = .{
        .ascent = renderer.terminal_font.ascent / render_scale,
        .descent = renderer.terminal_font.descent / render_scale,
        .line_height = renderer.terminal_font.line_height / render_scale,
        .cell_width = renderer.terminal_font.cell_width / render_scale,
        .cell_height = renderer.terminal_font.line_height / render_scale,
        .baseline_from_top = renderer.terminal_font.baseline_from_top / render_scale,
    };
    renderer.terminal_cell_width = renderer.terminal_metrics.cell_width;
    renderer.terminal_cell_height = renderer.terminal_metrics.cell_height;
    renderer.char_width = renderer.terminal_metrics.cell_width;
    renderer.char_height = renderer.terminal_metrics.cell_height;

    renderer.icon_font = try TerminalFont.init(
        renderer.allocator,
        renderer.font_path,
        raster_size * 2.0,
        iface.SYMBOLS_FALLBACK_PATH,
        iface.UNICODE_SYMBOLS2_PATH,
        iface.UNICODE_SYMBOLS_PATH,
        iface.UNICODE_MONO_PATH,
        iface.UNICODE_SANS_PATH,
        iface.EMOJI_COLOR_FALLBACK_PATH,
        iface.EMOJI_TEXT_FALLBACK_PATH,
        renderer.font_rendering,
    );
    renderer.icon_font.render_scale = render_scale;
    renderer.icon_font.setAtlasFilterPoint();
    renderer.icon_font_size = size * 2.0;
    renderer.icon_metrics = .{
        .ascent = renderer.icon_font.ascent / render_scale,
        .descent = renderer.icon_font.descent / render_scale,
        .line_height = renderer.icon_font.line_height / render_scale,
        .cell_width = renderer.icon_font.cell_width / render_scale,
        .cell_height = renderer.icon_font.line_height / render_scale,
        .baseline_from_top = renderer.icon_font.baseline_from_top / render_scale,
    };
    renderer.icon_char_width = renderer.icon_metrics.cell_width;
    renderer.icon_char_height = renderer.icon_metrics.cell_height;
    log.logf(
        .info,
        "metrics editor_font={d:.2} line={d:.2} asc={d:.2} desc={d:.2} cell={d:.2}x{d:.2} baseline={d:.2} icon_font={d:.2} icon_line={d:.2} icon_asc={d:.2} icon_desc={d:.2} icon_cell={d:.2}x{d:.2} icon_baseline={d:.2}",
        .{
            renderer.font_size,
            renderer.terminal_metrics.line_height,
            renderer.terminal_metrics.ascent,
            renderer.terminal_metrics.descent,
            renderer.terminal_metrics.cell_width,
            renderer.terminal_metrics.cell_height,
            renderer.terminal_metrics.baseline_from_top,
            renderer.icon_font_size,
            renderer.icon_metrics.line_height,
            renderer.icon_metrics.ascent,
            renderer.icon_metrics.descent,
            renderer.icon_metrics.cell_width,
            renderer.icon_metrics.cell_height,
            renderer.icon_metrics.baseline_from_top,
        },
    );
}

pub fn loadFont(renderer: anytype, path: [*:0]const u8, size: f32) void {
    const log = app_logger.logger("renderer.font");
    if (renderer.font_path_owned) |owned| {
        renderer.allocator.free(owned);
        renderer.font_path_owned = null;
    }
    renderer.font_path = path;
    renderer.base_font_size = size;
    applyFontScale(renderer) catch |err| {
        log.logf(.warning, "load font apply scale failed err={s}", .{@errorName(err)});
    };
}

pub fn setFontConfig(renderer: anytype, path: ?[]const u8, size: ?f32) !void {
    if (path) |raw| {
        const owned = try renderer.allocator.alloc(u8, raw.len + 1);
        std.mem.copyForwards(u8, owned[0..raw.len], raw);
        owned[raw.len] = 0;
        if (renderer.font_path_owned) |old| {
            renderer.allocator.free(old);
        }
        renderer.font_path_owned = owned;
        const ptr: [*:0]u8 = @ptrCast(owned.ptr);
        renderer.font_path = ptr;
    }
    if (size) |value| {
        if (value > 0.0) {
            renderer.base_font_size = value;
        }
    }
    try applyFontScale(renderer);
}

pub fn applyFontScale(renderer: anytype) !void {
    const size = renderer.base_font_size * renderer.ui_scale * renderer.user_zoom;
    var font_it = renderer.font_cache.iterator();
    while (font_it.next()) |entry| {
        entry.value_ptr.*.deinit();
        renderer.allocator.destroy(entry.value_ptr.*);
    }
    renderer.font_cache.clearRetainingCapacity();
    renderer.terminal_font.deinit();
    renderer.icon_font.deinit();
    renderer.font_size = size;
    try initFonts(renderer, size);
}

pub fn fontForSize(renderer: anytype, size: f32) ?*TerminalFont {
    const log = app_logger.logger("renderer.font");
    if (std.math.approxEqAbs(f32, size, renderer.font_size, 0.01)) return &renderer.terminal_font;
    if (std.math.approxEqAbs(f32, size, renderer.icon_font_size, 0.01)) return &renderer.icon_font;
    const key: u32 = @intFromFloat(std.math.round(size));
    if (renderer.font_cache.get(key)) |font_ptr| return font_ptr;

    const font_ptr = renderer.allocator.create(TerminalFont) catch |err| {
        log.logf(.warning, "font cache alloc failed size_key={d} err={s}", .{ key, @errorName(err) });
        return null;
    };
    font_ptr.* = TerminalFont.init(
        renderer.allocator,
        renderer.font_path,
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
