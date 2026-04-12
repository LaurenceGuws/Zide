//! Font-manager ownership note:
//! live interactive scale changes are currently too expensive because font
//! state rebuild still tears down cached/active fonts. Keep this file under
//! render-thread scrutiny until that cost is split or staged properly.
const std = @import("std");
const app_logger = @import("../../app_logger.zig");
const renderer_root = @import("../renderer.zig");
const terminal_font_mod = @import("../terminal_font.zig");
const TerminalFont = terminal_font_mod.TerminalFont;
const iface = @import("interface.zig");
const renderer_font_backend_host = @import("renderer_font_backend_host.zig");

const Renderer = renderer_root.Renderer;

pub const FontConfigState = struct {
    app_font_path: [*:0]const u8,
    app_font_path_owned: ?[]u8 = null,
    editor_font_path: [*:0]const u8,
    editor_font_path_owned: ?[]u8 = null,
    terminal_font_path: [*:0]const u8,
    terminal_font_path_owned: ?[]u8 = null,
    terminal_disable_ligatures: renderer_root.TerminalDisableLigaturesStrategy = .never,
    terminal_font_features_raw: ?[]u8 = null,
    terminal_font_features: std.ArrayListUnmanaged(terminal_font_mod.c.hb_feature_t) = .{},
    editor_disable_ligatures: renderer_root.TerminalDisableLigaturesStrategy = .never,
    editor_font_features_raw: ?[]u8 = null,
    editor_font_features: std.ArrayListUnmanaged(terminal_font_mod.c.hb_feature_t) = .{},
    font_rendering: terminal_font_mod.RenderingOptions = .{},
    font_cache: std.AutoHashMap(u32, *TerminalFont),
    terminal_font_cache: std.AutoHashMap(u64, *TerminalFont),
};

const OwnedFontPath = struct {
    path: [*:0]const u8,
    owned: ?[]u8,
};

const FontInitResult = struct {
    font: TerminalFont,
    metrics: Renderer.ScaledFontMetrics,
};

const terminal_neighbor_steps = [_]i32{
    -12, -11, -10, -9, -8, -7, -6, -5, -4, -3, -2, -1,
    1,   2,   3,   4,  5,  6,  7,  8,  9,  10, 11, 12,
};
const max_terminal_font_cache_entries = terminal_neighbor_steps.len + 1;

fn scaleMetrics(metrics: *Renderer.ScaledFontMetrics, factor: f32) void {
    metrics.ascent *= factor;
    metrics.descent *= factor;
    metrics.line_height *= factor;
    metrics.cell_width *= factor;
    metrics.cell_height *= factor;
    metrics.baseline_from_top *= factor;
}

fn scaleLiveFontVisual(font: *TerminalFont, factor: f32) void {
    if (!(factor > 0.0) or std.math.isNan(factor)) return;
    const current = if (font.live_visual_scale > 0.0) font.live_visual_scale else 1.0;
    font.live_visual_scale = current * factor;
}

fn resolveFontPath(allocator: std.mem.Allocator, raw: []const u8) !OwnedFontPath {
    if (std.fs.path.isAbsolute(raw)) {
        const owned = try allocator.alloc(u8, raw.len + 1);
        std.mem.copyForwards(u8, owned[0..raw.len], raw);
        owned[raw.len] = 0;
        return .{ .path = @ptrCast(owned.ptr), .owned = owned };
    }

    if (std.fs.cwd().openFile(raw, .{})) |file| {
        file.close();
        const owned = try allocator.alloc(u8, raw.len + 1);
        std.mem.copyForwards(u8, owned[0..raw.len], raw);
        owned[raw.len] = 0;
        return .{ .path = @ptrCast(owned.ptr), .owned = owned };
    } else |_| {}

    const exe_dir = std.fs.selfExeDirPathAlloc(allocator) catch null;
    defer if (exe_dir) |dir| allocator.free(dir);

    if (exe_dir) |dir| {
        const joined = try std.fs.path.join(allocator, &.{ dir, raw });
        return .{ .path = @ptrCast(joined.ptr), .owned = joined };
    }

    const owned = try allocator.alloc(u8, raw.len + 1);
    std.mem.copyForwards(u8, owned[0..raw.len], raw);
    owned[raw.len] = 0;
    return .{ .path = @ptrCast(owned.ptr), .owned = owned };
}

fn dupFontPath(allocator: std.mem.Allocator, raw_opt: ?[]const u8) !OwnedFontPath {
    if (raw_opt) |raw| {
        return try resolveFontPath(allocator, raw);
    }
    return try resolveFontPath(allocator, std.mem.span(renderer_root.FONT_PATH));
}

pub fn initFontConfigState(
    allocator: std.mem.Allocator,
    init_options: Renderer.InitOptions,
) !FontConfigState {
    const app_font_path = try dupFontPath(allocator, init_options.app_font_path);
    errdefer if (app_font_path.owned) |owned| allocator.free(owned);
    const editor_font_path = try dupFontPath(allocator, init_options.editor_font_path orelse init_options.app_font_path);
    errdefer if (editor_font_path.owned) |owned| allocator.free(owned);
    const terminal_font_path = try dupFontPath(allocator, init_options.terminal_font_path orelse init_options.app_font_path);
    errdefer if (terminal_font_path.owned) |owned| allocator.free(owned);

    return .{
        .app_font_path = app_font_path.path,
        .app_font_path_owned = app_font_path.owned,
        .editor_font_path = editor_font_path.path,
        .editor_font_path_owned = editor_font_path.owned,
        .terminal_font_path = terminal_font_path.path,
        .terminal_font_path_owned = terminal_font_path.owned,
        .terminal_disable_ligatures = .never,
        .terminal_font_features_raw = null,
        .terminal_font_features = .{},
        .editor_disable_ligatures = .never,
        .editor_font_features_raw = null,
        .editor_font_features = .{},
        .font_rendering = init_options.font_rendering,
        .font_cache = std.AutoHashMap(u32, *TerminalFont).init(allocator),
        .terminal_font_cache = std.AutoHashMap(u64, *TerminalFont).init(allocator),
    };
}

pub fn clearCommittedTerminalFontCache(renderer: anytype) void {
    var font_it = renderer.font_config.terminal_font_cache.iterator();
    while (font_it.next()) |entry| {
        entry.value_ptr.*.deinit();
        renderer.allocator.destroy(entry.value_ptr.*);
    }
    renderer.font_config.terminal_font_cache.clearRetainingCapacity();
}

pub fn deinitFontConfigState(renderer: anytype) void {
    var font_it = renderer.font_config.font_cache.iterator();
    while (font_it.next()) |entry| {
        entry.value_ptr.*.deinit();
        renderer.allocator.destroy(entry.value_ptr.*);
    }
    renderer.font_config.font_cache.deinit();
    clearCommittedTerminalFontCache(renderer);
    renderer.font_config.terminal_font_cache.deinit();

    if (renderer.font_config.terminal_font_features_raw) |owned| {
        renderer.allocator.free(owned);
        renderer.font_config.terminal_font_features_raw = null;
    }
    renderer.font_config.terminal_font_features.deinit(renderer.allocator);
    if (renderer.font_config.editor_font_features_raw) |owned| {
        renderer.allocator.free(owned);
        renderer.font_config.editor_font_features_raw = null;
    }
    renderer.font_config.editor_font_features.deinit(renderer.allocator);
    if (renderer.font_config.app_font_path_owned) |owned| {
        renderer.allocator.free(owned);
        renderer.font_config.app_font_path_owned = null;
    }
    if (renderer.font_config.editor_font_path_owned) |owned| {
        renderer.allocator.free(owned);
        renderer.font_config.editor_font_path_owned = null;
    }
    if (renderer.font_config.terminal_font_path_owned) |owned| {
        renderer.allocator.free(owned);
        renderer.font_config.terminal_font_path_owned = null;
    }
}

fn metalAtlasHooks(renderer: anytype) ?terminal_font_mod.AtlasUploadHooks {
    return renderer_font_backend_host.atlasUploadHooksForFontInit(renderer);
}

fn committedFontKey(raster_size_px: u32, render_scale: f32) u64 {
    const scale_key: u32 = @intFromFloat(@max(1.0, std.math.round((if (render_scale > 0.0) render_scale else 1.0) * 1000.0)));
    return (@as(u64, scale_key) << 32) | @as(u64, raster_size_px);
}

fn committedFontKeyForLayout(layout_size: f32, render_scale: f32) u64 {
    const raster_size_px: u32 = @intFromFloat(@max(1.0, std.math.round(layout_size * (if (render_scale > 0.0) render_scale else 1.0))));
    return committedFontKey(raster_size_px, render_scale);
}

fn committedRasterSizeForLayout(layout_size: f32, render_scale: f32) u32 {
    return @intFromFloat(@max(1.0, std.math.round(layout_size * (if (render_scale > 0.0) render_scale else 1.0))));
}

fn layoutSizeForCommittedRaster(raster_size_px: u32, render_scale: f32) f32 {
    return @as(f32, @floatFromInt(raster_size_px)) / (if (render_scale > 0.0) render_scale else 1.0);
}

fn initFont(renderer: anytype, path: [*:0]const u8, layout_size: f32) !FontInitResult {
    const render_scale = if (renderer.scale.render_scale > 0.0) renderer.scale.render_scale else 1.0;
    const raster_size = layout_size * render_scale;
    var font = try TerminalFont.initWithAtlasUploadHooks(
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
        renderer.font_config.font_rendering,
        metalAtlasHooks(renderer),
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

fn metricsFromFont(font: *const TerminalFont, render_scale: f32) Renderer.ScaledFontMetrics {
    return .{
        .ascent = font.ascent / render_scale,
        .descent = font.descent / render_scale,
        .line_height = font.line_height / render_scale,
        .cell_width = font.cell_width / render_scale,
        .cell_height = font.line_height / render_scale,
        .baseline_from_top = font.baseline_from_top / render_scale,
    };
}

fn takeCachedTerminalFont(renderer: anytype, layout_size: f32, render_scale: f32) ?FontInitResult {
    const key = committedFontKeyForLayout(layout_size, render_scale);
    const font_ptr = renderer.font_config.terminal_font_cache.fetchRemove(key) orelse return null;
    defer renderer.allocator.destroy(font_ptr.value);
    font_ptr.value.live_visual_scale = 1.0;
    font_ptr.value.render_scale = render_scale;
    return .{
        .font = font_ptr.value.*,
        .metrics = metricsFromFont(font_ptr.value, render_scale),
    };
}

fn initTerminalFont(renderer: anytype, layout_size: f32) !FontInitResult {
    const render_scale = if (renderer.scale.render_scale > 0.0) renderer.scale.render_scale else 1.0;
    if (takeCachedTerminalFont(renderer, layout_size, render_scale)) |cached| return cached;
    return initFont(renderer, renderer.font_config.terminal_font_path, layout_size);
}

fn prepareCommittedTerminalFont(renderer: anytype, raster_size_px: u32, render_scale: f32) void {
    const key = committedFontKey(raster_size_px, render_scale);
    if (renderer.terminal_font.committed_raster_size_px == raster_size_px and
        std.math.approxEqAbs(f32, renderer.terminal_font.render_scale, render_scale, 0.0001))
    {
        return;
    }
    if (renderer.font_config.terminal_font_cache.get(key) != null) return;
    const font_ptr = renderer.allocator.create(TerminalFont) catch return;
    const layout_size = layoutSizeForCommittedRaster(raster_size_px, render_scale);
    const init = initFont(renderer, renderer.font_config.terminal_font_path, layout_size) catch {
        renderer.allocator.destroy(font_ptr);
        return;
    };
    font_ptr.* = init.font;
    renderer.font_config.terminal_font_cache.put(key, font_ptr) catch {
        font_ptr.deinit();
        renderer.allocator.destroy(font_ptr);
    };
}

fn pruneTerminalFontCache(renderer: anytype, center_raster_size_px: u32, render_scale: f32) void {
    var keep_keys: [max_terminal_font_cache_entries]u64 = undefined;
    var keep_len: usize = 0;
    keep_keys[keep_len] = committedFontKey(center_raster_size_px, render_scale);
    keep_len += 1;
    for (terminal_neighbor_steps) |step| {
        const candidate_i32 = @as(i32, @intCast(center_raster_size_px)) + step;
        if (candidate_i32 <= 0) continue;
        keep_keys[keep_len] = committedFontKey(@intCast(candidate_i32), render_scale);
        keep_len += 1;
    }

    var remove_keys: [16]u64 = undefined;
    var remove_len: usize = 0;
    var it = renderer.font_config.terminal_font_cache.iterator();
    while (it.next()) |entry| {
        var keep = false;
        for (keep_keys[0..keep_len]) |key| {
            if (entry.key_ptr.* == key) {
                keep = true;
                break;
            }
        }
        if (!keep and remove_len < remove_keys.len) {
            remove_keys[remove_len] = entry.key_ptr.*;
            remove_len += 1;
        }
    }

    for (remove_keys[0..remove_len]) |key| {
        if (renderer.font_config.terminal_font_cache.fetchRemove(key)) |entry| {
            entry.value.deinit();
            renderer.allocator.destroy(entry.value);
        }
    }
}

pub fn prepareNeighborTerminalFonts(renderer: anytype) void {
    const render_scale = if (renderer.scale.render_scale > 0.0) renderer.scale.render_scale else 1.0;
    const center = committedRasterSizeForLayout(renderer.terminal_font_size, render_scale);
    for (terminal_neighbor_steps) |step| {
        const candidate_i32 = @as(i32, @intCast(center)) + step;
        if (candidate_i32 <= 0) continue;
        prepareCommittedTerminalFont(renderer, @intCast(candidate_i32), render_scale);
    }
    pruneTerminalFontCache(renderer, center, render_scale);
}

pub fn ensureCommittedTerminalFontCacheEntry(
    renderer: anytype,
    raster_size_px: u32,
    render_scale: f32,
) ?*TerminalFont {
    if (renderer.terminal_font.committed_raster_size_px == raster_size_px and
        std.math.approxEqAbs(f32, renderer.terminal_font.render_scale, render_scale, 0.0001))
    {
        return &renderer.terminal_font;
    }

    const key = committedFontKey(raster_size_px, render_scale);
    if (renderer.font_config.terminal_font_cache.getPtr(key)) |font_ptr_ptr| {
        return font_ptr_ptr.*;
    }

    const font_ptr = renderer.allocator.create(TerminalFont) catch return null;
    const layout_size = layoutSizeForCommittedRaster(raster_size_px, render_scale);
    const init = initFont(renderer, renderer.font_config.terminal_font_path, layout_size) catch {
        renderer.allocator.destroy(font_ptr);
        return null;
    };
    font_ptr.* = init.font;
    renderer.font_config.terminal_font_cache.put(key, font_ptr) catch {
        font_ptr.deinit();
        renderer.allocator.destroy(font_ptr);
        return null;
    };
    return renderer.font_config.terminal_font_cache.getPtr(key).?.*;
}

/// During aggressive live pinch, the exact committed target can jump outside
/// the prewarmed neighbor window. This bounded helper prepares that exact
/// target on a slower cadence so committed raster adoption can still progress
/// mid-gesture instead of waiting entirely for the settled rebuild.
pub fn prepareCurrentCommittedTerminalFontForLiveZoom(renderer: anytype, now: f64) bool {
    const prepare_interval = 0.03;
    const max_inline_raster_delta = 2;
    if (now - renderer.scale.last_terminal_prepare_time < prepare_interval) return false;
    const render_scale = if (renderer.scale.render_scale > 0.0) renderer.scale.render_scale else 1.0;
    const target_raster_px = committedRasterSizeForLayout(renderer.terminal_font_size, render_scale);
    const key = committedFontKey(target_raster_px, render_scale);
    if (renderer.terminal_font.committed_raster_size_px == target_raster_px and
        std.math.approxEqAbs(f32, renderer.terminal_font.render_scale, render_scale, 0.0001))
    {
        renderer.scale.last_terminal_prepare_time = now;
        return false;
    }
    if (renderer.font_config.terminal_font_cache.get(key) != null) {
        renderer.scale.last_terminal_prepare_time = now;
        return false;
    }
    const current_raster_px = renderer.terminal_font.committed_raster_size_px;
    const raster_delta = if (target_raster_px > current_raster_px)
        target_raster_px - current_raster_px
    else
        current_raster_px - target_raster_px;
    if (raster_delta > max_inline_raster_delta) {
        return false;
    }
    renderer.scale.last_terminal_prepare_time = now;
    prepareCommittedTerminalFont(renderer, target_raster_px, render_scale);
    return renderer.font_config.terminal_font_cache.get(key) != null;
}

/// Swap the terminal font to a prepared committed raster size during live
/// terminal zoom. This deliberately does not rebuild app/editor/icon fonts;
/// those remain owned by the settled `applyFontScale(...)` commit path.
pub fn commitPreparedTerminalFontScale(renderer: anytype) bool {
    const render_scale = if (renderer.scale.render_scale > 0.0) renderer.scale.render_scale else 1.0;
    const target_raster_px = committedRasterSizeForLayout(renderer.terminal_font_size, render_scale);
    if (renderer.terminal_font.committed_raster_size_px == target_raster_px and
        std.math.approxEqAbs(f32, renderer.terminal_font.render_scale, render_scale, 0.0001))
    {
        renderer.terminal_font.live_visual_scale = 1.0;
        return false;
    }

    const committed_layout_size = layoutSizeForCommittedRaster(target_raster_px, render_scale);
    const terminal_init = takeCachedTerminalFont(renderer, committed_layout_size, render_scale) orelse return false;
    cacheActiveTerminalFont(renderer);
    renderer.terminal_font = terminal_init.font;
    renderer.terminal_metrics = terminal_init.metrics;
    renderer.terminal_cell_width = renderer.terminal_metrics.cell_width;
    renderer.terminal_cell_height = renderer.terminal_metrics.cell_height;
    prepareNeighborTerminalFonts(renderer);
    return true;
}

/// Cheap terminal-only settle for external-host pinch flows.
///
/// If the current committed terminal target is already active, this just clears
/// any remaining live preview scale. If a prepared committed target is ready,
/// it swaps to that target without rebuilding the app/editor/icon font stack.
pub fn settlePreparedTerminalFontScale(renderer: anytype) bool {
    const render_scale = if (renderer.scale.render_scale > 0.0) renderer.scale.render_scale else 1.0;
    const target_raster_px = committedRasterSizeForLayout(renderer.terminal_font_size, render_scale);
    if (renderer.terminal_font.committed_raster_size_px == target_raster_px and
        std.math.approxEqAbs(f32, renderer.terminal_font.render_scale, render_scale, 0.0001))
    {
        if (std.math.approxEqAbs(f32, renderer.terminal_font.live_visual_scale, 1.0, 0.0001)) {
            return false;
        }
        renderer.terminal_font.live_visual_scale = 1.0;
        return true;
    }
    return commitPreparedTerminalFontScale(renderer);
}

fn cacheActiveTerminalFont(renderer: anytype) void {
    const key = committedFontKey(renderer.terminal_font.committed_raster_size_px, renderer.terminal_font.render_scale);
    if (renderer.font_config.terminal_font_cache.get(key) != null) {
        renderer.terminal_font.deinit();
        return;
    }
    const font_ptr = renderer.allocator.create(TerminalFont) catch {
        renderer.terminal_font.deinit();
        return;
    };
    renderer.terminal_font.live_visual_scale = 1.0;
    font_ptr.* = renderer.terminal_font;
    renderer.font_config.terminal_font_cache.put(key, font_ptr) catch {
        font_ptr.deinit();
        renderer.allocator.destroy(font_ptr);
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
    const log_enabled = log.enabled_file or log.enabled_console;
    const render_scale = if (renderer.scale.render_scale > 0.0) renderer.scale.render_scale else 1.0;

    if (log_enabled) {
        log.logf(
            .info,
            "initFonts app_path={s} app_base={d:.2} editor_path={s} editor_base={d:.2} terminal_path={s} terminal_base={d:.2} render_scale={d:.3} hinting={s} autohint={d} lcd={d}",
            .{
                renderer.font_config.app_font_path,
                renderer.font_size,
                renderer.font_config.editor_font_path,
                renderer.editor_font_size,
                renderer.font_config.terminal_font_path,
                renderer.terminal_font_size,
                render_scale,
                @tagName(renderer.font_config.font_rendering.hinting),
                @intFromBool(renderer.font_config.font_rendering.autohint),
                @intFromBool(renderer.font_config.font_rendering.lcd),
            },
        );
    }

    var app_init = try initFont(renderer, renderer.font_config.app_font_path, renderer.font_size);
    errdefer app_init.font.deinit();
    var editor_init = try initFont(renderer, renderer.font_config.editor_font_path, renderer.editor_font_size);
    errdefer editor_init.font.deinit();
    var terminal_init = try initTerminalFont(renderer, renderer.terminal_font_size);
    errdefer terminal_init.font.deinit();
    var icon_init = try initFont(renderer, renderer.font_config.app_font_path, renderer.font_size * 2.0);
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

    if (log_enabled) {
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
}

pub fn loadFont(renderer: anytype, path: [*:0]const u8, size: f32) void {
    const log = app_logger.logger("renderer.font");
    if (renderer.font_config.app_font_path_owned) |owned| {
        renderer.allocator.free(owned);
        renderer.font_config.app_font_path_owned = null;
    }
    renderer.font_config.app_font_path = path;
    renderer.base_font_size = size;
    applyFontScale(renderer) catch |err| {
        log.logf(.warning, "load font apply scale failed err={s}", .{@errorName(err)});
    };
}

pub fn setFontConfig(renderer: anytype, app_path: ?[]const u8, app_size: ?f32, editor_path: ?[]const u8, editor_size: ?f32, terminal_path: ?[]const u8, terminal_size: ?f32) !void {
    if (app_path) |raw| try setOwnedFontPath(renderer, &renderer.font_config.app_font_path_owned, &renderer.font_config.app_font_path, raw);
    if (app_size) |value| {
        if (value > 0.0) renderer.base_font_size = value;
    }
    if (editor_path) |raw| try setOwnedFontPath(renderer, &renderer.font_config.editor_font_path_owned, &renderer.font_config.editor_font_path, raw);
    if (editor_size) |value| {
        if (value > 0.0) renderer.editor_base_font_size = value;
    }
    if (terminal_path) |raw| try setOwnedFontPath(renderer, &renderer.font_config.terminal_font_path_owned, &renderer.font_config.terminal_font_path, raw);
    if (terminal_size) |value| {
        if (value > 0.0) renderer.terminal_base_font_size = value;
    }
    clearCommittedTerminalFontCache(renderer);
    try applyFontScale(renderer);
}

/// Render-thread scrutiny: this is currently too expensive for a hot
/// interactive path. It tears down cached fonts and rebuilds active font
/// state from scratch. Keep this design under active pressure until live scale
/// changes stop paying full font-stack rebuild cost.
pub fn applyFontScale(renderer: anytype) !void {
    renderer.font_size = renderer.base_font_size * renderer.scale.ui_scale * renderer.scale.user_zoom;
    renderer.editor_font_size = renderer.editor_base_font_size * renderer.scale.ui_scale * renderer.scale.user_zoom;
    renderer.terminal_font_size = renderer.terminal_base_font_size * renderer.scale.ui_scale * renderer.scale.user_zoom;

    var font_it = renderer.font_config.font_cache.iterator();
    while (font_it.next()) |entry| {
        entry.value_ptr.*.deinit();
        renderer.allocator.destroy(entry.value_ptr.*);
    }
    renderer.font_config.font_cache.clearRetainingCapacity();

    renderer.app_font.deinit();
    renderer.editor_font.deinit();
    cacheActiveTerminalFont(renderer);
    renderer.icon_font.deinit();
    try initFonts(renderer);
    prepareNeighborTerminalFonts(renderer);
}

/// Cheap live zoom path for interactive gestures.
///
/// This updates logical font sizes and derived cell metrics without destroying
/// font atlases or rebuilding active font faces. A later commit step must call
/// `applyFontScale(...)` when the interaction settles so raster font assets
/// catch up to the final target size.
pub fn applyLiveUserZoomScale(renderer: anytype) void {
    const old_app = renderer.font_size;
    const old_editor = renderer.editor_font_size;
    const old_terminal = renderer.terminal_font_size;
    const old_icon = renderer.icon_font_size;

    renderer.font_size = renderer.base_font_size * renderer.scale.ui_scale * renderer.scale.user_zoom;
    renderer.editor_font_size = renderer.editor_base_font_size * renderer.scale.ui_scale * renderer.scale.user_zoom;
    renderer.terminal_font_size = renderer.terminal_base_font_size * renderer.scale.ui_scale * renderer.scale.user_zoom;
    renderer.icon_font_size = renderer.font_size * 2.0;

    if (old_app > 0.0) {
        const factor = renderer.font_size / old_app;
        scaleMetrics(&renderer.app_metrics, factor);
        scaleLiveFontVisual(&renderer.app_font, factor);
        renderer.char_width = renderer.app_metrics.cell_width;
        renderer.char_height = renderer.app_metrics.cell_height;
    }
    if (old_editor > 0.0) {
        const factor = renderer.editor_font_size / old_editor;
        scaleMetrics(&renderer.editor_metrics, factor);
        scaleLiveFontVisual(&renderer.editor_font, factor);
        renderer.editor_char_width = renderer.editor_metrics.cell_width;
        renderer.editor_char_height = renderer.editor_metrics.cell_height;
    }
    if (old_terminal > 0.0) {
        const factor = renderer.terminal_font_size / old_terminal;
        scaleMetrics(&renderer.terminal_metrics, factor);
        scaleLiveFontVisual(&renderer.terminal_font, factor);
        renderer.terminal_cell_width = renderer.terminal_metrics.cell_width;
        renderer.terminal_cell_height = renderer.terminal_metrics.cell_height;
    }
    if (old_icon > 0.0) {
        const factor = renderer.icon_font_size / old_icon;
        scaleMetrics(&renderer.icon_metrics, factor);
        scaleLiveFontVisual(&renderer.icon_font, factor);
        renderer.icon_char_width = renderer.icon_metrics.cell_width;
        renderer.icon_char_height = renderer.icon_metrics.cell_height;
    }
}

pub fn fontForSize(renderer: anytype, size: f32) ?*TerminalFont {
    const log = app_logger.logger("renderer.font");
    if (std.math.approxEqAbs(f32, size, renderer.font_size, 0.01)) return &renderer.app_font;
    if (std.math.approxEqAbs(f32, size, renderer.icon_font_size, 0.01)) return &renderer.icon_font;
    const key: u32 = @intFromFloat(std.math.round(size));
    if (renderer.font_config.font_cache.get(key)) |font_ptr| return font_ptr;

    const font_ptr = renderer.allocator.create(TerminalFont) catch |err| {
        log.logf(.warning, "font cache alloc failed size_key={d} err={s}", .{ key, @errorName(err) });
        return null;
    };
    font_ptr.* = TerminalFont.initWithAtlasUploadHooks(
        renderer.allocator,
        renderer.font_config.app_font_path,
        @as(f32, @floatFromInt(key)) * renderer.scale.render_scale,
        iface.SYMBOLS_FALLBACK_PATH,
        iface.UNICODE_SYMBOLS2_PATH,
        iface.UNICODE_SYMBOLS_PATH,
        iface.UNICODE_MONO_PATH,
        iface.UNICODE_SANS_PATH,
        iface.EMOJI_COLOR_FALLBACK_PATH,
        iface.EMOJI_TEXT_FALLBACK_PATH,
        renderer.font_config.font_rendering,
        metalAtlasHooks(renderer),
    ) catch {
        renderer.allocator.destroy(font_ptr);
        return null;
    };
    font_ptr.render_scale = renderer.scale.render_scale;
    font_ptr.setAtlasFilterPoint();
    renderer.font_config.font_cache.put(key, font_ptr) catch |err| {
        log.logf(.warning, "font cache insert failed size_key={d} err={s}", .{ key, @errorName(err) });
        font_ptr.deinit();
        renderer.allocator.destroy(font_ptr);
        return null;
    };
    return font_ptr;
}
