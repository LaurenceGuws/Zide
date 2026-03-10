const types = @import("../model/types.zig");
const parser_csi = @import("../parser/csi.zig");
const app_logger = @import("../../app_logger.zig");

const Color = types.Color;

pub const SgrContext = struct {
    ctx: *anyopaque,
    palette_color_fn: *const fn (ctx: *anyopaque, idx: u8) Color,
    current_attrs_ptr_fn: *const fn (ctx: *anyopaque) *types.CellAttrs,
    default_attrs_ptr_fn: *const fn (ctx: *anyopaque) *const types.CellAttrs,

    pub fn from(session: anytype) SgrContext {
        const SessionPtr = @TypeOf(session);
        return .{
            .ctx = @ptrCast(session),
            .palette_color_fn = struct {
                fn call(ctx: *anyopaque, idx: u8) Color {
                    const s: SessionPtr = @ptrCast(@alignCast(ctx));
                    return s.paletteColor(idx);
                }
            }.call,
            .current_attrs_ptr_fn = struct {
                fn call(ctx: *anyopaque) *types.CellAttrs {
                    const s: SessionPtr = @ptrCast(@alignCast(ctx));
                    return &s.activeScreen().current_attrs;
                }
            }.call,
            .default_attrs_ptr_fn = struct {
                fn call(ctx: *anyopaque) *const types.CellAttrs {
                    const s: SessionPtr = @ptrCast(@alignCast(ctx));
                    return &s.activeScreen().default_attrs;
                }
            }.call,
        };
    }

    pub fn paletteColor(self: *const SgrContext, idx: u8) Color { return self.palette_color_fn(self.ctx, idx); }
    pub fn currentAttrs(self: *const SgrContext) *types.CellAttrs { return self.current_attrs_ptr_fn(self.ctx); }
    pub fn defaultAttrs(self: *const SgrContext) *const types.CellAttrs { return self.default_attrs_ptr_fn(self.ctx); }
};

pub const DecstrContext = struct {
    ctx: *anyopaque,
    reset_parser_fn: *const fn (ctx: *anyopaque) void,
    reset_saved_charset_fn: *const fn (ctx: *anyopaque) void,
    clear_title_buffer_fn: *const fn (ctx: *anyopaque) void,
    set_default_title_fn: *const fn (ctx: *anyopaque) void,
    set_report_color_scheme_2031_fn: *const fn (ctx: *anyopaque, enabled: bool) void,
    set_grapheme_cluster_shaping_2027_fn: *const fn (ctx: *anyopaque, enabled: bool) void,
    set_primary_grapheme_cluster_shaping_2027_fn: *const fn (ctx: *anyopaque, enabled: bool) void,
    set_alt_grapheme_cluster_shaping_2027_fn: *const fn (ctx: *anyopaque, enabled: bool) void,
    set_inband_resize_notifications_2048_fn: *const fn (ctx: *anyopaque, enabled: bool) void,
    set_kitty_paste_events_5522_fn: *const fn (ctx: *anyopaque, enabled: bool) void,
    reset_input_modes_locked_fn: *const fn (ctx: *anyopaque) void,
    set_column_mode_132_fn: *const fn (ctx: *anyopaque, enabled: bool) void,
    set_sync_updates_locked_fn: *const fn (ctx: *anyopaque, enabled: bool) void,
    clear_all_kitty_images_fn: *const fn (ctx: *anyopaque) void,
    reset_active_screen_state_fn: *const fn (ctx: *anyopaque) void,
    mark_active_screen_decstr_dirty_fn: *const fn (ctx: *anyopaque) void,

    pub fn from(session: anytype) DecstrContext {
        const SessionPtr = @TypeOf(session);
        return .{
            .ctx = @ptrCast(session),
            .reset_parser_fn = struct { fn call(ctx: *anyopaque) void { const s: SessionPtr = @ptrCast(@alignCast(ctx)); s.parser.reset(); } }.call,
            .reset_saved_charset_fn = struct { fn call(ctx: *anyopaque) void { const s: SessionPtr = @ptrCast(@alignCast(ctx)); s.saved_charset = .{}; } }.call,
            .clear_title_buffer_fn = struct { fn call(ctx: *anyopaque) void { const s: SessionPtr = @ptrCast(@alignCast(ctx)); s.title_buffer.clearRetainingCapacity(); } }.call,
            .set_default_title_fn = struct { fn call(ctx: *anyopaque) void { const s: SessionPtr = @ptrCast(@alignCast(ctx)); s.title = "Terminal"; } }.call,
            .set_report_color_scheme_2031_fn = struct { fn call(ctx: *anyopaque, enabled: bool) void { const s: SessionPtr = @ptrCast(@alignCast(ctx)); s.report_color_scheme_2031 = enabled; } }.call,
            .set_grapheme_cluster_shaping_2027_fn = struct { fn call(ctx: *anyopaque, enabled: bool) void { const s: SessionPtr = @ptrCast(@alignCast(ctx)); s.grapheme_cluster_shaping_2027 = enabled; } }.call,
            .set_primary_grapheme_cluster_shaping_2027_fn = struct { fn call(ctx: *anyopaque, enabled: bool) void { const s: SessionPtr = @ptrCast(@alignCast(ctx)); s.primary.setGraphemeClusterShaping2027(enabled); } }.call,
            .set_alt_grapheme_cluster_shaping_2027_fn = struct { fn call(ctx: *anyopaque, enabled: bool) void { const s: SessionPtr = @ptrCast(@alignCast(ctx)); s.alt.setGraphemeClusterShaping2027(enabled); } }.call,
            .set_inband_resize_notifications_2048_fn = struct { fn call(ctx: *anyopaque, enabled: bool) void { const s: SessionPtr = @ptrCast(@alignCast(ctx)); s.inband_resize_notifications_2048 = enabled; } }.call,
            .set_kitty_paste_events_5522_fn = struct { fn call(ctx: *anyopaque, enabled: bool) void { const s: SessionPtr = @ptrCast(@alignCast(ctx)); s.kitty_paste_events_5522 = enabled; } }.call,
            .reset_input_modes_locked_fn = struct { fn call(ctx: *anyopaque) void { const s: SessionPtr = @ptrCast(@alignCast(ctx)); s.resetInputModesLocked(); } }.call,
            .set_column_mode_132_fn = struct { fn call(ctx: *anyopaque, enabled: bool) void { const s: SessionPtr = @ptrCast(@alignCast(ctx)); s.column_mode_132 = enabled; } }.call,
            .set_sync_updates_locked_fn = struct { fn call(ctx: *anyopaque, enabled: bool) void { const s: SessionPtr = @ptrCast(@alignCast(ctx)); s.setSyncUpdatesLocked(enabled); } }.call,
            .clear_all_kitty_images_fn = struct { fn call(ctx: *anyopaque) void { const s: SessionPtr = @ptrCast(@alignCast(ctx)); s.clearAllKittyImages(); } }.call,
            .reset_active_screen_state_fn = struct { fn call(ctx: *anyopaque) void { const s: SessionPtr = @ptrCast(@alignCast(ctx)); s.activeScreen().resetState(); } }.call,
            .mark_active_screen_decstr_dirty_fn = struct { fn call(ctx: *anyopaque) void { const s: SessionPtr = @ptrCast(@alignCast(ctx)); s.activeScreen().markDirtyAllWithReason(.decstr_soft_reset, @src()); } }.call,
        };
    }

    pub fn resetParser(self: *const DecstrContext) void { self.reset_parser_fn(self.ctx); }
    pub fn resetSavedCharset(self: *const DecstrContext) void { self.reset_saved_charset_fn(self.ctx); }
    pub fn clearTitleBuffer(self: *const DecstrContext) void { self.clear_title_buffer_fn(self.ctx); }
    pub fn setDefaultTitle(self: *const DecstrContext) void { self.set_default_title_fn(self.ctx); }
    pub fn setReportColorScheme2031(self: *const DecstrContext, enabled: bool) void { self.set_report_color_scheme_2031_fn(self.ctx, enabled); }
    pub fn setGraphemeClusterShaping2027(self: *const DecstrContext, enabled: bool) void { self.set_grapheme_cluster_shaping_2027_fn(self.ctx, enabled); }
    pub fn setPrimaryGraphemeClusterShaping2027(self: *const DecstrContext, enabled: bool) void { self.set_primary_grapheme_cluster_shaping_2027_fn(self.ctx, enabled); }
    pub fn setAltGraphemeClusterShaping2027(self: *const DecstrContext, enabled: bool) void { self.set_alt_grapheme_cluster_shaping_2027_fn(self.ctx, enabled); }
    pub fn setInbandResizeNotifications2048(self: *const DecstrContext, enabled: bool) void { self.set_inband_resize_notifications_2048_fn(self.ctx, enabled); }
    pub fn setKittyPasteEvents5522(self: *const DecstrContext, enabled: bool) void { self.set_kitty_paste_events_5522_fn(self.ctx, enabled); }
    pub fn resetInputModesLocked(self: *const DecstrContext) void { self.reset_input_modes_locked_fn(self.ctx); }
    pub fn setColumnMode132(self: *const DecstrContext, enabled: bool) void { self.set_column_mode_132_fn(self.ctx, enabled); }
    pub fn setSyncUpdatesLocked(self: *const DecstrContext, enabled: bool) void { self.set_sync_updates_locked_fn(self.ctx, enabled); }
    pub fn clearAllKittyImages(self: *const DecstrContext) void { self.clear_all_kitty_images_fn(self.ctx); }
    pub fn resetActiveScreenState(self: *const DecstrContext) void { self.reset_active_screen_state_fn(self.ctx); }
    pub fn markActiveScreenDecstrDirty(self: *const DecstrContext) void { self.mark_active_screen_decstr_dirty_fn(self.ctx); }
};

pub fn applyDecstrReset(context: DecstrContext) void {
    context.resetParser();
    context.resetSavedCharset();
    context.clearTitleBuffer();
    context.setDefaultTitle();
    context.setReportColorScheme2031(false);
    context.setGraphemeClusterShaping2027(false);
    context.setPrimaryGraphemeClusterShaping2027(false);
    context.setAltGraphemeClusterShaping2027(false);
    context.setInbandResizeNotifications2048(false);
    context.setKittyPasteEvents5522(false);
    context.resetInputModesLocked();
    context.setColumnMode132(false);
    context.setSyncUpdatesLocked(false);
    context.clearAllKittyImages();
    context.resetActiveScreenState();
    context.markActiveScreenDecstrDirty();
}

pub fn applySgr(context: SgrContext, action: parser_csi.CsiAction, effective_sgr_param_count: *const fn (action: parser_csi.CsiAction) usize) void {
    const params = action.params;
    const n_params = effective_sgr_param_count(action);
    const current_attrs = context.currentAttrs();
    const default_attrs = context.defaultAttrs();
    const log = app_logger.logger("terminal.sgr");
    log.logf(.debug, "sgr count={d} params={d},{d},{d},{d},{d},{d},{d},{d},{d},{d},{d},{d},{d},{d},{d},{d}", .{
        n_params, params[0], params[1], params[2], params[3], params[4], params[5], params[6], params[7], params[8], params[9], params[10], params[11], params[12], params[13], params[14], params[15],
    });
    var i: usize = 0;
    while (i < n_params) {
        const p = params[i];
        if (p == 38 or p == 48 or p == 58) {
            if (i + 1 < n_params) {
                const mode = params[i + 1];
                if (mode == 5 and i + 2 < n_params) {
                    const idx = types.clampColorIndex(params[i + 2]);
                    const color = context.paletteColor(idx);
                    switch (p) { 38 => current_attrs.fg = color, 48 => current_attrs.bg = color, 58 => current_attrs.underline_color = color, else => {} }
                    i += 3;
                    continue;
                }
                if (mode == 2) {
                    const base: usize = i + 2;
                    if (base + 2 < n_params) {
                        const r = types.clampColorIndex(params[base]);
                        const g = types.clampColorIndex(params[base + 1]);
                        const b = types.clampColorIndex(params[base + 2]);
                        const color = Color{ .r = r, .g = g, .b = b, .a = 255 };
                        switch (p) { 38 => current_attrs.fg = color, 48 => current_attrs.bg = color, 58 => current_attrs.underline_color = color, else => {} }
                        i = base + 3;
                        continue;
                    }
                }
                if (mode == 6) {
                    const base: usize = i + 2;
                    if (base + 3 < n_params) {
                        const r = types.clampColorIndex(params[base]);
                        const g = types.clampColorIndex(params[base + 1]);
                        const b = types.clampColorIndex(params[base + 2]);
                        const a = types.clampColorIndex(params[base + 3]);
                        const color = Color{ .r = r, .g = g, .b = b, .a = a };
                        switch (p) { 38 => current_attrs.fg = color, 48 => current_attrs.bg = color, 58 => current_attrs.underline_color = color, else => {} }
                        i = base + 4;
                        continue;
                    }
                }
            }
            i += 1;
            continue;
        }
        switch (p) {
            0 => current_attrs.* = default_attrs.*,
            1 => current_attrs.bold = true,
            5 => { current_attrs.blink = true; current_attrs.blink_fast = false; },
            6 => { current_attrs.blink = true; current_attrs.blink_fast = true; },
            22 => current_attrs.bold = false,
            25 => { current_attrs.blink = false; current_attrs.blink_fast = false; },
            4 => current_attrs.underline = true,
            24 => current_attrs.underline = false,
            7 => current_attrs.reverse = true,
            27 => current_attrs.reverse = false,
            39 => current_attrs.fg = default_attrs.fg,
            49 => current_attrs.bg = default_attrs.bg,
            59 => current_attrs.underline_color = default_attrs.underline_color,
            30...37 => current_attrs.fg = context.paletteColor(@intCast(p - 30)),
            40...47 => current_attrs.bg = context.paletteColor(@intCast(p - 40)),
            90...97 => current_attrs.fg = context.paletteColor(@intCast(8 + (p - 90))),
            100...107 => current_attrs.bg = context.paletteColor(@intCast(8 + (p - 100))),
            else => {},
        }
        i += 1;
    }
}
