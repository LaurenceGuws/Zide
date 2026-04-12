const std = @import("std");
const builtin = @import("builtin");
const terminal_font_mod = @import("../terminal_font.zig");
const hb = terminal_font_mod.c;
const FaceSlot = terminal_font_mod.FaceSlot;
const RenderingOptions = terminal_font_mod.RenderingOptions;
const PreparedGlyphRaster = terminal_font_mod.PreparedGlyphRaster;
const scale_utils = @import("scale_utils.zig");
const font_manager = @import("font_manager.zig");
const iface = @import("interface.zig");
const renderer_font_backend_host = @import("renderer_font_backend_host.zig");
const text_input = @import("text_input.zig");
const app_logger = @import("../../app_logger.zig");
const platform_window = @import("../../platform/window_metrics.zig");
const renderer_root = @import("../renderer.zig");
const TerminalDisableLigaturesStrategy = renderer_root.TerminalDisableLigaturesStrategy;

pub const ScaleState = struct {
    render_scale: f32 = 1.0,
    user_zoom: f32 = 1.0,
    user_zoom_target: f32 = 1.0,
    ui_scale: f32 = 1.0,
    last_zoom_request_time: f64 = 0.0,
    last_zoom_apply_time: f64 = 0.0,
    last_terminal_prepare_time: f64 = 0.0,
    font_rebuild_pending: bool = false,
    wayland_scale_cache: ?f32 = null,
    wayland_scale_last_update: f64 = 0.0,
};

pub const TerminalGlyphPrepEntry = struct {
    face_slot: FaceSlot,
    glyph_id: u32,
    want_color: bool,
    italic: bool,
    hb_x_advance: i32,
};

pub const TerminalGlyphPrepRequest = struct {
    generation: u64,
    committed_raster_size_px: u32,
    render_scale_milli: u32,
    entries: []TerminalGlyphPrepEntry,

    pub fn deinit(self: *TerminalGlyphPrepRequest, allocator: std.mem.Allocator) void {
        allocator.free(self.entries);
        self.* = undefined;
    }
};

pub const PreparedTerminalGlyph = struct {
    entry: TerminalGlyphPrepEntry,
    raster: PreparedGlyphRaster,

    pub fn deinit(self: *PreparedTerminalGlyph, allocator: std.mem.Allocator) void {
        self.raster.deinit(allocator);
        self.* = undefined;
    }
};

pub const TerminalGlyphPrepResult = struct {
    generation: u64,
    committed_raster_size_px: u32,
    render_scale_milli: u32,
    glyphs: []PreparedTerminalGlyph,

    pub fn deinit(self: *TerminalGlyphPrepResult, allocator: std.mem.Allocator) void {
        for (self.glyphs) |*glyph| glyph.deinit(allocator);
        allocator.free(self.glyphs);
        self.* = undefined;
    }
};

pub const TerminalGlyphPrepRuntimeState = struct {
    worker: ?std.Thread = null,
    worker_running: bool = false,
    stop_requested: bool = false,
    mutex: std.Thread.Mutex = .{},
    cond: std.Thread.Condition = .{},
    compute_in_flight: bool = false,
    next_generation: u64 = 0,
    last_request_hash: u64 = 0,
    last_request_raster_size_px: u32 = 0,
    last_request_render_scale_milli: u32 = 0,
    last_request_entry_count: usize = 0,
    last_collect_view_generation: u64 = 0,
    last_collect_rows: usize = 0,
    last_collect_cols: usize = 0,
    last_collect_raster_size_px: u32 = 0,
    last_collect_render_scale_milli: u32 = 0,
    has_last_collect_signature: bool = false,
    result_needs_redraw: bool = false,
    request: ?TerminalGlyphPrepRequest = null,
    result: ?TerminalGlyphPrepResult = null,
};

pub fn deinitTerminalGlyphPrepRuntimeState(self: anytype) void {
    self.terminal_glyph_prep.mutex.lock();
    self.terminal_glyph_prep.stop_requested = true;
    self.terminal_glyph_prep.cond.broadcast();
    self.terminal_glyph_prep.mutex.unlock();
    if (self.terminal_glyph_prep.worker) |worker| worker.join();
    self.terminal_glyph_prep.worker = null;
    self.terminal_glyph_prep.worker_running = false;
    self.terminal_glyph_prep.mutex.lock();
    defer self.terminal_glyph_prep.mutex.unlock();
    if (self.terminal_glyph_prep.request) |*request| request.deinit(self.allocator);
    self.terminal_glyph_prep.request = null;
    if (self.terminal_glyph_prep.result) |*result| result.deinit(self.allocator);
    self.terminal_glyph_prep.result = null;
}

pub fn lockTerminalGlyphPrepRuntime(self: anytype) void {
    self.terminal_glyph_prep.mutex.lock();
}

pub fn unlockTerminalGlyphPrepRuntime(self: anytype) void {
    self.terminal_glyph_prep.mutex.unlock();
}

pub fn waitTerminalGlyphPrepRuntime(self: anytype) void {
    self.terminal_glyph_prep.cond.wait(&self.terminal_glyph_prep.mutex);
}

pub fn signalTerminalGlyphPrepRuntime(self: anytype) void {
    self.terminal_glyph_prep.cond.signal();
}

pub fn broadcastTerminalGlyphPrepRuntime(self: anytype) void {
    self.terminal_glyph_prep.cond.broadcast();
}

pub fn clearPendingTerminalGlyphPrepRequest(self: anytype) void {
    if (self.terminal_glyph_prep.request) |*request| request.deinit(self.allocator);
    self.terminal_glyph_prep.request = null;
}

pub fn clearPendingTerminalGlyphPrepResult(self: anytype) void {
    if (self.terminal_glyph_prep.result) |*result| result.deinit(self.allocator);
    self.terminal_glyph_prep.result = null;
}

pub const StageTerminalGlyphPrepRequestOutcome = struct {
    generation: u64,
    staged: bool,
};

pub fn stageTerminalGlyphPrepRequest(
    self: anytype,
    committed_raster_size_px: u32,
    render_scale_milli: u32,
    request_hash: u64,
    entries: []const TerminalGlyphPrepEntry,
) !StageTerminalGlyphPrepRequestOutcome {
    if (self.terminal_glyph_prep.last_request_hash == request_hash and
        self.terminal_glyph_prep.last_request_raster_size_px == committed_raster_size_px and
        self.terminal_glyph_prep.last_request_render_scale_milli == render_scale_milli and
        self.terminal_glyph_prep.last_request_entry_count == entries.len)
    {
        return .{
            .generation = self.terminal_glyph_prep.next_generation,
            .staged = false,
        };
    }

    ensureTerminalGlyphPrepWorkerRunning(self);
    const owned_entries = try self.allocator.dupe(TerminalGlyphPrepEntry, entries);
    clearPendingTerminalGlyphPrepRequest(self);
    self.terminal_glyph_prep.next_generation +|= 1;
    self.terminal_glyph_prep.last_request_hash = request_hash;
    self.terminal_glyph_prep.last_request_raster_size_px = committed_raster_size_px;
    self.terminal_glyph_prep.last_request_render_scale_milli = render_scale_milli;
    self.terminal_glyph_prep.last_request_entry_count = entries.len;
    self.terminal_glyph_prep.request = .{
        .generation = self.terminal_glyph_prep.next_generation,
        .committed_raster_size_px = committed_raster_size_px,
        .render_scale_milli = render_scale_milli,
        .entries = owned_entries,
    };
    return .{
        .generation = self.terminal_glyph_prep.next_generation,
        .staged = true,
    };
}

pub fn publishTerminalGlyphPrepResult(self: anytype, result: TerminalGlyphPrepResult) void {
    clearPendingTerminalGlyphPrepResult(self);
    self.terminal_glyph_prep.result = result;
    self.terminal_glyph_prep.result_needs_redraw = true;
}

pub fn shouldCollectTerminalGlyphPrepEntries(
    self: anytype,
    view_generation: u64,
    rows: usize,
    cols: usize,
    committed_raster_size_px: u32,
    render_scale_milli: u32,
) bool {
    if (!self.terminal_glyph_prep.has_last_collect_signature) return true;
    return !(self.terminal_glyph_prep.last_collect_view_generation == view_generation and
        self.terminal_glyph_prep.last_collect_rows == rows and
        self.terminal_glyph_prep.last_collect_cols == cols and
        self.terminal_glyph_prep.last_collect_raster_size_px == committed_raster_size_px and
        self.terminal_glyph_prep.last_collect_render_scale_milli == render_scale_milli);
}

pub fn noteTerminalGlyphPrepCollection(
    self: anytype,
    view_generation: u64,
    rows: usize,
    cols: usize,
    committed_raster_size_px: u32,
    render_scale_milli: u32,
) void {
    self.terminal_glyph_prep.last_collect_view_generation = view_generation;
    self.terminal_glyph_prep.last_collect_rows = rows;
    self.terminal_glyph_prep.last_collect_cols = cols;
    self.terminal_glyph_prep.last_collect_raster_size_px = committed_raster_size_px;
    self.terminal_glyph_prep.last_collect_render_scale_milli = render_scale_milli;
    self.terminal_glyph_prep.has_last_collect_signature = true;
}

pub fn takeTerminalGlyphPrepResult(self: anytype) ?TerminalGlyphPrepResult {
    const result = self.terminal_glyph_prep.result;
    self.terminal_glyph_prep.result = null;
    self.terminal_glyph_prep.result_needs_redraw = false;
    return result;
}

pub fn terminalGlyphPrepResultNeedsRedraw(self: anytype) bool {
    return self.terminal_glyph_prep.result_needs_redraw;
}

fn ensureTerminalGlyphPrepWorkerRunning(self: anytype) void {
    if (self.terminal_glyph_prep.worker_running) return;
    const worker = std.Thread.spawn(.{}, terminalGlyphPrepWorkerMain, .{self}) catch |err| {
        const log = app_logger.logger("renderer.font");
        log.logf(.warning, "terminal glyph prep worker spawn failed err={s}", .{@errorName(err)});
        return;
    };
    self.terminal_glyph_prep.worker = worker;
    self.terminal_glyph_prep.worker_running = true;
}

const TerminalGlyphPrepConfigSnapshot = struct {
    font_path: [:0]u8,
    render_options: RenderingOptions,

    fn deinit(self: *TerminalGlyphPrepConfigSnapshot, allocator: std.mem.Allocator) void {
        allocator.free(self.font_path);
        self.* = undefined;
    }
};

fn snapshotTerminalGlyphPrepConfig(self: *renderer_root.Renderer) ?TerminalGlyphPrepConfigSnapshot {
    self.lockTerminalGlyphPrepRuntime();
    defer self.unlockTerminalGlyphPrepRuntime();
    const font_path = self.allocator.dupeZ(u8, std.mem.span(self.font_config.terminal_font_path)) catch return null;
    return .{
        .font_path = font_path,
        .render_options = self.font_config.font_rendering,
    };
}

fn terminalGlyphPrepLayoutSize(request: TerminalGlyphPrepRequest) f32 {
    const render_scale = @as(f32, @floatFromInt(request.render_scale_milli)) / 1000.0;
    return @as(f32, @floatFromInt(request.committed_raster_size_px)) / (if (render_scale > 0.0) render_scale else 1.0);
}

fn initTerminalGlyphPrepFont(
    allocator: std.mem.Allocator,
    config: TerminalGlyphPrepConfigSnapshot,
    request: TerminalGlyphPrepRequest,
) !terminal_font_mod.TerminalFont {
    return terminal_font_mod.TerminalFont.initCpuPrepared(
        allocator,
        @ptrCast(config.font_path.ptr),
        terminalGlyphPrepLayoutSize(request) * (@as(f32, @floatFromInt(request.render_scale_milli)) / 1000.0),
        iface.SYMBOLS_FALLBACK_PATH,
        iface.UNICODE_SYMBOLS2_PATH,
        iface.UNICODE_SYMBOLS_PATH,
        iface.UNICODE_MONO_PATH,
        iface.UNICODE_SANS_PATH,
        iface.EMOJI_COLOR_FALLBACK_PATH,
        iface.EMOJI_TEXT_FALLBACK_PATH,
        config.render_options,
    );
}

fn computeTerminalGlyphPrepResult(
    allocator: std.mem.Allocator,
    config: TerminalGlyphPrepConfigSnapshot,
    request: TerminalGlyphPrepRequest,
) !TerminalGlyphPrepResult {
    var font = try initTerminalGlyphPrepFont(allocator, config, request);
    defer font.deinit();

    var glyphs = try allocator.alloc(PreparedTerminalGlyph, request.entries.len);
    var produced: usize = 0;
    errdefer {
        var i: usize = 0;
        while (i < produced) : (i += 1) glyphs[i].deinit(allocator);
        allocator.free(glyphs);
    }

    for (request.entries) |entry| {
        const face = font.faceForSlot(entry.face_slot) orelse continue;
        const raster = font.prepareGlyphRaster(face, entry.glyph_id, entry.want_color, entry.italic, entry.hb_x_advance) catch continue;
        glyphs[produced] = .{
            .entry = entry,
            .raster = raster,
        };
        produced += 1;
    }

    return .{
        .generation = request.generation,
        .committed_raster_size_px = request.committed_raster_size_px,
        .render_scale_milli = request.render_scale_milli,
        .glyphs = glyphs[0..produced],
    };
}

fn terminalGlyphPrepWorkerMain(self: *renderer_root.Renderer) void {
    const log = app_logger.logger("renderer.font");
    while (true) {
        self.lockTerminalGlyphPrepRuntime();
        while (!self.terminal_glyph_prep.stop_requested and
            (self.terminal_glyph_prep.request == null or self.terminal_glyph_prep.compute_in_flight))
        {
            self.waitTerminalGlyphPrepRuntime();
        }
        if (self.terminal_glyph_prep.stop_requested) {
            self.unlockTerminalGlyphPrepRuntime();
            return;
        }

        var request = self.terminal_glyph_prep.request.?;
        self.terminal_glyph_prep.request = null;
        self.terminal_glyph_prep.compute_in_flight = true;
        self.unlockTerminalGlyphPrepRuntime();

        var config = snapshotTerminalGlyphPrepConfig(self) orelse {
            request.deinit(self.allocator);
            self.lockTerminalGlyphPrepRuntime();
            self.terminal_glyph_prep.compute_in_flight = false;
            self.broadcastTerminalGlyphPrepRuntime();
            continue;
        };
        defer config.deinit(self.allocator);
        log.logf(.info, "terminal_glyph_prep_worker_start generation={d} raster={d} scale_milli={d} entries={d}", .{
            request.generation,
            request.committed_raster_size_px,
            request.render_scale_milli,
            request.entries.len,
        });

        const result = computeTerminalGlyphPrepResult(self.allocator, config, request) catch |err| blk: {
            log.logf(.warning, "terminal glyph prep compute failed generation={d} err={s}", .{ request.generation, @errorName(err) });
            break :blk null;
        };
        request.deinit(self.allocator);

        self.lockTerminalGlyphPrepRuntime();
        self.terminal_glyph_prep.compute_in_flight = false;
        if (result) |prepared| {
            if (prepared.generation == self.terminal_glyph_prep.next_generation and !self.terminal_glyph_prep.stop_requested) {
                log.logf(.info, "terminal_glyph_prep_worker_publish generation={d} raster={d} scale_milli={d} glyphs={d}", .{
                    prepared.generation,
                    prepared.committed_raster_size_px,
                    prepared.render_scale_milli,
                    prepared.glyphs.len,
                });
                self.publishTerminalGlyphPrepResult(prepared);
            } else {
                log.logf(.info, "terminal_glyph_prep_worker_stale generation={d} next_generation={d} stop={d} glyphs={d}", .{
                    prepared.generation,
                    self.terminal_glyph_prep.next_generation,
                    @intFromBool(self.terminal_glyph_prep.stop_requested),
                    prepared.glyphs.len,
                });
                var stale = prepared;
                stale.deinit(self.allocator);
            }
        }
        self.broadcastTerminalGlyphPrepRuntime();
        self.unlockTerminalGlyphPrepRuntime();
    }
}

pub fn initScaleState(
    allocator: std.mem.Allocator,
    display_metrics: platform_window.DisplayMetrics,
) ScaleState {
    var wayland_scale = scale_utils.WaylandScaleState{
        .cache = null,
        .last_update = -1000.0,
    };
    const ui_scale = scale_utils.queryUiScale(allocator, display_metrics.dpi, 0.0, &wayland_scale);
    return .{
        .render_scale = display_metrics.render_scale,
        .user_zoom = 1.0,
        .user_zoom_target = 1.0,
        .ui_scale = ui_scale,
        .last_zoom_request_time = 0.0,
        .last_zoom_apply_time = 0.0,
        .last_terminal_prepare_time = 0.0,
        .font_rebuild_pending = false,
        .wayland_scale_cache = wayland_scale.cache,
        .wayland_scale_last_update = wayland_scale.last_update,
    };
}

pub fn setFontRenderingOptions(self: anytype, opts: RenderingOptions) void {
    self.font_config.font_rendering = opts;
    font_manager.clearCommittedTerminalFontCache(self);
}

pub fn setTextRenderingConfig(self: anytype, gamma: ?f32, contrast: ?f32, linear_correction: ?bool) void {
    var changed = false;
    if (gamma) |v| {
        if (v > 0 and self.text_render.gamma != v) {
            self.text_render.gamma = v;
            changed = true;
        }
    }
    if (contrast) |v| {
        if (v > 0 and self.text_render.contrast != v) {
            self.text_render.contrast = v;
            changed = true;
        }
    }
    if (linear_correction) |v| {
        if (self.text_render.linear_correction != v) {
            self.text_render.linear_correction = v;
            changed = true;
        }
    }

    if (!changed) return;
    self.text_render.config_dirty = true;
    renderer_font_backend_host.syncTextRenderConfig(self);
}

pub fn setTerminalLigatureConfig(self: anytype, strategy: ?TerminalDisableLigaturesStrategy, features_raw: ?[]const u8) void {
    if (strategy) |s| self.font_config.terminal_disable_ligatures = s;
    if (features_raw) |raw| setFontFeatureListRaw(self, &self.font_config.terminal_font_features_raw, &self.font_config.terminal_font_features, raw);
}

pub fn setEditorLigatureConfig(self: anytype, strategy: ?TerminalDisableLigaturesStrategy, features_raw: ?[]const u8) void {
    if (strategy) |s| self.font_config.editor_disable_ligatures = s;
    if (features_raw) |raw| setFontFeatureListRaw(self, &self.font_config.editor_font_features_raw, &self.font_config.editor_font_features, raw);
}

fn setFontFeatureListRaw(self: anytype, raw_slot: *?[]u8, list: *std.ArrayListUnmanaged(hb.hb_feature_t), raw: []const u8) void {
    const log = app_logger.logger("renderer.font");
    if (raw_slot.*) |owned| {
        self.allocator.free(owned);
        raw_slot.* = null;
    }
    raw_slot.* = self.allocator.dupe(u8, raw) catch |err| blk: {
        log.logf(.warning, "font feature raw dup failed len={d} err={s}", .{ raw.len, @errorName(err) });
        break :blk null;
    };
    rebuildFontFeaturesList(self, raw_slot.*, list);
}

fn rebuildFontFeaturesList(self: anytype, raw_opt: ?[]u8, list: *std.ArrayListUnmanaged(hb.hb_feature_t)) void {
    const log = app_logger.logger("renderer.font");
    list.items.len = 0;
    const raw = raw_opt orelse return;
    var it = std.mem.splitScalar(u8, raw, ',');
    while (it.next()) |piece| {
        const token = std.mem.trim(u8, piece, " \t\r\n");
        if (token.len == 0) continue;
        var feature: hb.hb_feature_t = undefined;
        if (hb.hb_feature_from_string(token.ptr, @intCast(token.len), &feature) != 0) {
            list.append(self.allocator, feature) catch |err| {
                log.logf(.warning, "font feature append failed token={s} err={s}", .{ token, @errorName(err) });
                return;
            };
        }
    }
}

fn hbTag(a: u8, b: u8, cch: u8, d: u8) u32 {
    return (@as(u32, a) << 24) | (@as(u32, b) << 16) | (@as(u32, cch) << 8) | @as(u32, d);
}

const hb_feature_all: u32 = 0xFFFFFFFF;

pub fn collectShapeFeatures(self: anytype, domain: anytype, disable_programming_ligatures: bool, out: []hb.hb_feature_t) usize {
    var len: usize = 0;
    const base = switch (domain) {
        .terminal => self.font_config.terminal_font_features.items,
        .editor => if (self.font_config.editor_font_features_raw != null)
            self.font_config.editor_font_features.items
        else
            self.font_config.terminal_font_features.items,
    };

    for (base) |f| {
        if (len >= out.len) break;
        out[len] = f;
        len += 1;
    }

    if (disable_programming_ligatures and len < out.len) {
        out[len] = .{
            .tag = hbTag('c', 'a', 'l', 't'),
            .value = 0,
            .start = 0,
            .end = hb_feature_all,
        };
        len += 1;
    }
    return len;
}

pub fn queryUiScale(self: anytype) f32 {
    const metrics = platform_window.collectDisplayMetrics(self.window);
    var wayland = scale_utils.WaylandScaleState{
        .cache = self.scale.wayland_scale_cache,
        .last_update = self.scale.wayland_scale_last_update,
    };
    const scale = scale_utils.queryUiScale(self.allocator, metrics.dpi, renderer_root.getTime(), &wayland);
    self.scale.wayland_scale_cache = wayland.cache;
    self.scale.wayland_scale_last_update = wayland.last_update;
    return scale;
}

pub fn applyFontScale(self: anytype) !void {
    try font_manager.applyFontScale(self);
    self.scale.font_rebuild_pending = false;
    if (comptime !(builtin.target.os.tag == .linux and builtin.target.abi == .android)) {
        text_input.reapplyRect(&self.input.text_input_state, self.window);
    }
}

pub fn applyLiveUserZoomScale(self: anytype) void {
    font_manager.applyLiveUserZoomScale(self);
    self.scale.font_rebuild_pending = true;
}

pub fn queueUserZoom(self: anytype, delta: f32, now: f64) bool {
    const result = scale_utils.queueUserZoom(self.scale.user_zoom_target, delta, now, 0.5, 3.0);
    self.scale.user_zoom_target = result.next_target;
    self.scale.last_zoom_request_time = result.request_time;
    return result.changed;
}

pub fn applyPinchZoomScale(self: anytype, scale_factor: f32, now: f64) !bool {
    if (!(scale_factor > 0.0) or std.math.isNan(scale_factor)) return false;
    const next_zoom = std.math.clamp(self.scale.user_zoom * scale_factor, 0.5, 3.0);
    if (std.math.approxEqAbs(f32, next_zoom, self.scale.user_zoom, 0.0001)) return false;
    const prev_zoom = self.scale.user_zoom;
    const prev_font = self.font_size;
    const prev_terminal_font = self.terminal_font_size;
    const prev_cell_w = self.terminal_cell_width;
    const prev_cell_h = self.terminal_cell_height;
    self.scale.user_zoom = next_zoom;
    self.scale.user_zoom_target = next_zoom;
    self.scale.last_zoom_request_time = now;
    self.scale.last_zoom_apply_time = now;
    const ui_log = app_logger.logger("ui.scale");
    const font_log = app_logger.logger("renderer.font");
    const ui_log_enabled = ui_log.enabled_file or ui_log.enabled_console;
    const font_log_enabled = font_log.enabled_file or font_log.enabled_console;
    const layout_size = self.base_font_size * self.scale.ui_scale * self.scale.user_zoom;
    const raster_size = layout_size * self.scale.render_scale;
    if (ui_log_enabled) {
        ui_log.logf(.info, "ui_pinch_zoom window={d:.3} render={d:.3} user_zoom={d:.3} font={d:.2}->{d:.2}", .{
            self.scale.ui_scale,
            self.scale.render_scale,
            self.scale.user_zoom,
            self.font_size,
            layout_size,
        });
        ui_log.logf(.info, "ui_pinch_zoom layout_size={d:.2} raster_size={d:.2}", .{ layout_size, raster_size });
    }
    applyLiveUserZoomScale(self);
    const prepared_target = font_manager.prepareCurrentCommittedTerminalFontForLiveZoom(self, now);
    const committed_swap = font_manager.commitPreparedTerminalFontScale(self);
    if (committed_swap) {
        self.scale.font_rebuild_pending = true;
    }
    if (font_log_enabled) {
        font_log.logf(.info, "terminal_pinch_tick t={d:.3} factor={d:.4} zoom={d:.3}->{d:.3} app_font={d:.2}->{d:.2} term_font={d:.2}->{d:.2} cell={d:.2}x{d:.2}->{d:.2}x{d:.2} committed_raster={d} live_visual={d:.3} cache_entries={d} prepared_target={d} committed_swap={d}", .{
            now,
            scale_factor,
            prev_zoom,
            self.scale.user_zoom,
            prev_font,
            self.font_size,
            prev_terminal_font,
            self.terminal_font_size,
            prev_cell_w,
            prev_cell_h,
            self.terminal_cell_width,
            self.terminal_cell_height,
            self.terminal_font.committed_raster_size_px,
            self.terminal_font.live_visual_scale,
            self.font_config.terminal_font_cache.count(),
            @intFromBool(prepared_target),
            @intFromBool(committed_swap),
        });
    }
    return true;
}

pub fn resetUserZoomTarget(self: anytype, now: f64) bool {
    const result = scale_utils.resetUserZoomTarget(self.scale.user_zoom_target, now);
    self.scale.user_zoom_target = result.next_target;
    self.scale.last_zoom_request_time = result.request_time;
    return result.changed;
}

pub fn refreshUiScaleFromDisplayMetrics(self: anytype, metrics: platform_window.DisplayMetrics) !bool {
    var wayland = scale_utils.WaylandScaleState{
        .cache = self.scale.wayland_scale_cache,
        .last_update = self.scale.wayland_scale_last_update,
    };
    const next = scale_utils.queryUiScale(self.allocator, metrics.dpi, renderer_root.getTime(), &wayland);
    self.scale.wayland_scale_cache = wayland.cache;
    self.scale.wayland_scale_last_update = wayland.last_update;
    const next_render = metrics.render_scale;
    const scale_changed = !std.math.approxEqAbs(f32, next, self.scale.ui_scale, 0.0001);
    const render_changed = !std.math.approxEqAbs(f32, next_render, self.scale.render_scale, 0.0001);
    if (!scale_changed and !render_changed) return false;
    const log = app_logger.logger("ui.scale");
    const log_enabled = log.enabled_file or log.enabled_console;
    const layout_size = self.base_font_size * next * self.scale.user_zoom;
    const raster_size = layout_size * next_render;
    if (log_enabled) {
        log.logf(.info, "ui_scale window={d:.3} render={d:.3}->{d:.3} user_zoom={d:.3} font={d:.2}->{d:.2}", .{
            next,
            self.scale.render_scale,
            next_render,
            self.scale.user_zoom,
            self.font_size,
            layout_size,
        });
        log.logf(.info, "ui_scale layout_size={d:.2} raster_size={d:.2}", .{ layout_size, raster_size });
    }
    self.scale.ui_scale = next;
    self.scale.render_scale = next_render;
    try applyFontScale(self);
    return true;
}

pub fn applyPendingZoom(self: anytype, now: f64) !bool {
    const commit_delay = 0.12;
    const result = scale_utils.applyPendingZoom(
        self.scale.user_zoom,
        self.scale.user_zoom_target,
        now,
        self.scale.last_zoom_request_time,
        self.scale.last_zoom_apply_time,
        0.04,
        0.02,
    );
    if (!result.changed) {
        if (self.scale.font_rebuild_pending and
            std.math.approxEqAbs(f32, self.scale.user_zoom_target, self.scale.user_zoom, 0.0001) and
            now - self.scale.last_zoom_apply_time >= commit_delay)
        {
            try applyFontScale(self);
            font_manager.prepareNeighborTerminalFonts(self);
            return true;
        }
        return false;
    }
    self.scale.user_zoom = result.next_zoom;
    const log = app_logger.logger("ui.scale");
    const log_enabled = log.enabled_file or log.enabled_console;
    const layout_size = self.base_font_size * self.scale.ui_scale * self.scale.user_zoom;
    const raster_size = layout_size * self.scale.render_scale;
    if (log_enabled) {
        log.logf(.info, "ui_zoom window={d:.3} render={d:.3} user_zoom={d:.3} font={d:.2}->{d:.2}", .{
            self.scale.ui_scale,
            self.scale.render_scale,
            self.scale.user_zoom,
            self.font_size,
            layout_size,
        });
        log.logf(.info, "ui_zoom layout_size={d:.2} raster_size={d:.2}", .{ layout_size, raster_size });
    }
    applyLiveUserZoomScale(self);
    if (log_enabled) {
        log.logf(
            .info,
            "ui_zoom_effective base={d:.2} ui={d:.3} zoom={d:.3} target={d:.3} render={d:.3} font={d:.2} term_cell={d:.2}x{d:.2}",
            .{
                self.base_font_size,
                self.scale.ui_scale,
                self.scale.user_zoom,
                self.scale.user_zoom_target,
                self.scale.render_scale,
                self.font_size,
                self.terminal_cell_width,
                self.terminal_cell_height,
            },
        );
    }
    self.scale.last_zoom_apply_time = result.apply_time;
    return true;
}

pub fn fontForSize(self: anytype, size: f32) ?*@import("../terminal_font.zig").TerminalFont {
    return font_manager.fontForSize(self, size);
}
