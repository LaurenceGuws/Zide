const std = @import("std");
const app_logger = @import("../app_logger.zig");

const app_shell = @import("../app_shell.zig");
const font_sample_section_host = @import("font_sample_section_host.zig");
const metal_text_diagnostic_view = @import("metal_text_diagnostic_view.zig");
const terminal_font_mod = @import("terminal_font.zig");
const renderer_mod = @import("renderer.zig");
const metal_text_sample_runtime = @import("renderer/metal_text_sample_runtime.zig");
const metal_backend = @import("renderer/metal_backend.zig");
const renderer_presentable_host = @import("renderer/renderer_presentable_host.zig");
const renderer_surface_host = @import("renderer/renderer_surface_host.zig");
const renderer_text_host = @import("renderer/renderer_text_host.zig");
const draw_ops = @import("renderer/draw_ops.zig");
const iface = @import("renderer/interface.zig");
const text_draw = @import("renderer/text_draw.zig");
const types = @import("renderer/types.zig");

const Shell = app_shell.Shell;
const Color = app_shell.Color;
const Section = font_sample_section_host.Section;
const Renderer = renderer_mod.Renderer;
const TerminalFont = terminal_font_mod.TerminalFont;
const TextRenderingMode = renderer_mod.TextRenderingMode;

const SampleFontFace = struct {
    font: TerminalFont,
    metrics: Renderer.ScaledFontMetrics,

    fn init(allocator: std.mem.Allocator, renderer: *Renderer, path: [*:0]const u8, layout_size: f32) !SampleFontFace {
        const raster_scale = renderer.logicalLengthToRaster(1.0);
        const raster_size = renderer.logicalLengthToRaster(layout_size);
        const atlas_upload_hooks = metal_backend.terminalFontAtlasUploadHooksForRenderer(renderer) orelse switch (renderer.capabilities().planned_atlas_storage_mode) {
            .metal_textures => return error.MetalBackendContextUnavailable,
            else => null,
        };
        var font = try TerminalFont.initWithAtlasUploadHooks(
            allocator,
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
            atlas_upload_hooks,
        );
        errdefer font.deinit();
        font.render_scale = raster_scale;
        font.setAtlasFilterPoint();
        return .{
            .font = font,
            .metrics = .{
                .ascent = renderer.rasterLengthToLogical(font.ascent),
                .descent = renderer.rasterLengthToLogical(font.descent),
                .line_height = renderer.rasterLengthToLogical(font.line_height),
                .cell_width = renderer.rasterLengthToLogical(font.cell_width),
                .cell_height = renderer.rasterLengthToLogical(font.line_height),
                .baseline_from_top = renderer.rasterLengthToLogical(font.baseline_from_top),
            },
        };
    }

    fn deinit(self: *SampleFontFace) void {
        self.font.deinit();
    }
};

pub const FontSampleView = struct {
    allocator: std.mem.Allocator,
    size: f32,
    raster_scale: f32,
    left: SampleFontFace,
    right: SampleFontFace,
    left_name: []const u8,
    right_name: []const u8,

    pub fn init(allocator: std.mem.Allocator, renderer: *Renderer) !FontSampleView {
        const size = parseEnvF32("ZIDE_FONT_SAMPLE_SIZE", renderer.base_font_size);
        const left_path: [*:0]const u8 = "assets/fonts/JetBrainsMonoNerdFont-Regular.ttf";
        const right_path: [*:0]const u8 = "assets/fonts/IosevkaTermNerdFont-Regular.ttf";

        var left = try SampleFontFace.init(allocator, renderer, left_path, size);
        errdefer left.deinit();

        var right = try SampleFontFace.init(allocator, renderer, right_path, size);
        errdefer right.deinit();

        return .{
            .allocator = allocator,
            .size = size,
            .raster_scale = renderer.logicalLengthToRaster(1.0),
            .left = left,
            .right = right,
            .left_name = "JetBrainsMono",
            .right_name = "IosevkaTerm",
        };
    }

    pub fn deinit(self: *FontSampleView) void {
        self.left.deinit();
        self.right.deinit();
    }

    pub fn update(self: *FontSampleView, renderer: *Renderer, input: anytype) bool {
        const log = app_logger.logger("ui.font-sample");
        // Returns true if the view changed and needs redraw.
        // +/- adjust size and rebuild the sample fonts.
        const mods = input.mods;
        const increase = (input.keyPressed(.equal) and mods.shift) or input.keyPressed(.kp_add);
        const decrease = input.keyPressed(.minus) or input.keyPressed(.kp_subtract);
        const next = if (increase) self.size + 1.0 else if (decrease) self.size - 1.0 else self.size;
        const clamped = @max(6.0, @min(64.0, next));
        const next_raster_scale = renderer.logicalLengthToRaster(1.0);
        const size_changed = !std.math.approxEqAbs(f32, clamped, self.size, 0.001);
        const scale_changed = !std.math.approxEqAbs(f32, next_raster_scale, self.raster_scale, 0.0001);
        if (!size_changed and !scale_changed) return false;

        const left_path: [*:0]const u8 = "assets/fonts/JetBrainsMonoNerdFont-Regular.ttf";
        const right_path: [*:0]const u8 = "assets/fonts/IosevkaTermNerdFont-Regular.ttf";

        var new_left = SampleFontFace.init(self.allocator, renderer, left_path, clamped) catch |err| {
            log.logf(.warning, "font sample left font rebuild failed err={s}", .{@errorName(err)});
            return false;
        };
        errdefer new_left.deinit();

        const new_right = SampleFontFace.init(self.allocator, renderer, right_path, clamped) catch |err| {
            log.logf(.warning, "font sample right font rebuild failed err={s}", .{@errorName(err)});
            new_left.deinit();
            return false;
        };

        // Swap in new fonts.
        self.left.deinit();
        self.right.deinit();
        self.left = new_left;
        self.right = new_right;
        self.size = clamped;
        self.raster_scale = next_raster_scale;
        return true;
    }

    pub fn draw(self: *FontSampleView, shell: *Shell) void {
        const r = shell.rendererPtr();
        const theme = shell.theme();
        const geometry = shell.uiGeometryContext();
        const w = geometry.window.width;
        const h = geometry.window.height;
        if (w <= 0 or h <= 0) return;

        if (r.textRenderingMode() == .unavailable and r.plannedTextRenderingMode() == .metal_texture_atlas) {
            _ = (metal_text_diagnostic_view.View{}).activate(shell);
        }

        // Render into the offscreen target so we can do linear blending in a
        // controlled way (target is linear; presentation converts to sRGB).
        if (renderer_presentable_host.ensurePresentable(r, .editor, @intFromFloat(w), @intFromFloat(h))) {
            if (renderer_presentable_host.beginPresentable(r, .editor)) {
                renderer_surface_host.drawRect(r, 0, 0, @intFromFloat(w), @intFromFloat(h), theme.background);
                drawContents(self, r, theme, w, h);
                renderer_presentable_host.endPresentable(r, .editor);
                renderer_presentable_host.drawPresentable(r, .editor, .{ .x = 0, .y = 0 });
                return;
            }
        }

        // Fallback: draw directly to the window.
        renderer_surface_host.drawRect(r, 0, 0, @intFromFloat(w), @intFromFloat(h), theme.background);
        drawContents(self, r, theme, w, h);
    }

    fn drawContents(self: *FontSampleView, r: *Renderer, theme: *const app_shell.Theme, w: f32, h: f32) void {
        const padding: f32 = 16;
        const header_y: f32 = padding;
        const col_gap: f32 = 18;
        const col_w: f32 = @max(0, (w - padding * 2 - col_gap) * 0.5);
        const left_x: f32 = padding;
        const right_x: f32 = padding + col_w + col_gap;

        var title_buf: [160]u8 = undefined;
        const title = std.fmt.bufPrint(
            &title_buf,
            "Font Sample (size={d:.1})  keys: +/-",
            .{self.size},
        ) catch "Font Sample";
        drawStatusText(r, title, padding, header_y, theme.foreground);

        if (r.textRenderingMode() != .gl_texture_atlas) {
            drawTextModeStatus(r, theme, padding, header_y + r.char_height * 1.8);
            return;
        }

        const section_gap: f32 = 10;
        var y_cursor: f32 = header_y + r.char_height * 1.8;

        y_cursor = drawSection(self, r, theme, w, left_x, right_x, y_cursor, col_w, "normal", theme.background, theme.foreground);
        y_cursor += section_gap;
        y_cursor = drawSection(self, r, theme, w, left_x, right_x, y_cursor, col_w, "selection", theme.selection, theme.foreground);
        y_cursor += section_gap;
        _ = drawSection(self, r, theme, w, left_x, right_x, y_cursor, col_w, "cursor", theme.cursor, theme.background);

        _ = h;
    }

    fn drawTextModeStatus(r: *Renderer, theme: *const app_shell.Theme, x: f32, y: f32) void {
        if (r.textRenderingMode() == .unavailable and r.plannedTextRenderingMode() == .metal_texture_atlas) {
            const swatch_x = x;
            const swatch_y = y;
            const swatch_size = @max(r.char_height * 1.25, 18.0);
            const swatch_width = @max(r.char_width * 6.0, swatch_size * 3.4);
            renderer_surface_host.drawRect(
                r,
                @intFromFloat(std.math.round(swatch_x - 6.0)),
                @intFromFloat(std.math.round(swatch_y - 6.0)),
                @intFromFloat(std.math.round(swatch_width + 12.0)),
                @intFromFloat(std.math.round(swatch_size + 12.0)),
                theme.ui_panel_overlay,
            );
            _ = metal_backend.drawSampleTextRequest(r, metal_text_sample_runtime.SampleTextRequest{
                .text = "METAL\nTEXT",
                .x = swatch_x,
                .y = swatch_y,
                .tint = theme.foreground.toRgba(),
                .layout = .monospace_cell,
                .clip_rect = .{
                    .x = swatch_x,
                    .y = swatch_y,
                    .width = swatch_width,
                    .height = swatch_size + r.char_height * 1.4,
                },
            });
        }
        drawStatusText(r, "Text sample unavailable on this runtime path.", x, y, theme.foreground);

        var live_buf: [96]u8 = undefined;
        const live = std.fmt.bufPrint(&live_buf, "live text mode: {s}", .{@tagName(r.textRenderingMode())}) catch "live text mode: <error>";
        drawStatusText(r, live, x, y + r.char_height * 1.4, theme.ui_text_inactive);

        var planned_buf: [96]u8 = undefined;
        const planned = std.fmt.bufPrint(&planned_buf, "planned text mode: {s}", .{@tagName(r.plannedTextRenderingMode())}) catch "planned text mode: <error>";
        drawStatusText(r, planned, x, y + r.char_height * 2.8, theme.ui_modified);
    }

    fn drawStatusText(r: *Renderer, text: []const u8, x: f32, y: f32, color: Color) void {
        if (r.textRenderingMode() == .unavailable and r.plannedTextRenderingMode() == .metal_texture_atlas) {
            renderer_text_host.drawTextMonospace(r, text, x, y, color);
            return;
        }
        renderer_text_host.drawText(r, text, x, y, color);
    }

    fn drawSection(
        self: *FontSampleView,
        r: *Renderer,
        theme: *const app_shell.Theme,
        w: f32,
        left_x: f32,
        right_x: f32,
        y: f32,
        col_w: f32,
        label: []const u8,
        bg: Color,
        fg: Color,
    ) f32 {
        const section_pad_y: f32 = 8;
        const line_h = self.left.metrics.line_height;
        const lines = sampleLines();
        const content_h: f32 = @as(f32, @floatFromInt(lines.len)) * line_h + baselineStressHeight(line_h);
        const section_h: f32 = r.char_height + section_pad_y + content_h + section_pad_y;
        const content_y: f32 = y + r.char_height + section_pad_y;
        const section = Section.init(r, bg);

        section.fillRect(0, @intFromFloat(y), @intFromFloat(w), @intFromFloat(section_h), bg);
        section.drawText(label, 16, y, theme.foreground);

        section.applyBg();
        drawColumnWithColor(self, r, left_x, content_y, col_w, self.left_name, &self.left, fg);
        drawColumnWithColor(self, r, right_x, content_y, col_w, self.right_name, &self.right, fg);
        section.clearBg();

        return y + section_h;
    }

    fn drawColumn(self: *FontSampleView, r: *Renderer, x: f32, y: f32, w: f32, name: []const u8, font: *SampleFontFace) void {
        drawColumnWithColor(self, r, x, y, w, name, font, Color.white);
    }

    fn drawColumnWithColor(self: *FontSampleView, r: *Renderer, x: f32, y: f32, w: f32, name: []const u8, font: *SampleFontFace, fg: Color) void {
        _ = w;
        const theme = r.theme;

        var header_buf: [192]u8 = undefined;
        const header = std.fmt.bufPrint(
            &header_buf,
            "{s}  line_h={d:.1} cell_w={d:.1}",
            .{ name, font.metrics.line_height, font.metrics.cell_width },
        ) catch name;
        renderer_text_host.drawText(r, header, x, y, theme.foreground);

        const start_y = y + r.char_height * 1.6;
        const line_h = font.metrics.line_height;

        const lines = sampleLines();
        var row: usize = 0;
        while (row < lines.len) : (row += 1) {
            const text = lines[row];
            drawTextWithFont(r, self.allocator, font, text, x, start_y + @as(f32, @floatFromInt(row)) * line_h, fg);
        }

        var stress_y = start_y + @as(f32, @floatFromInt(lines.len)) * line_h + line_h * 0.5;
        renderer_text_host.drawText(r, "baseline zoom stress: x0.9 x1.0 x1.1", x, stress_y, theme.line_number);
        stress_y += line_h;

        const stress_text = "Baseline probe: iiii llll zzzz vava mMwW 1Il|";
        const zooms = [_]f32{ 0.9, 1.0, 1.1 };
        for (zooms, 0..) |zoom, idx| {
            drawTextWithFontZoom(r, self.allocator, font, stress_text, x, stress_y, fg, zoom);
            if (idx + 1 < zooms.len) {
                stress_y += line_h * zoom + line_h * 0.1;
            }
        }
    }

    fn drawTextWithFont(
        r: *Renderer,
        allocator: std.mem.Allocator,
        face: *SampleFontFace,
        text: []const u8,
        x: f32,
        y: f32,
        color: Color,
    ) void {
        if (r.textRenderingMode() != .gl_texture_atlas) return;
        const draw_ctx = terminal_font_mod.DrawContext{ .ctx = r, .drawTexture = drawTextureThunk };
        text_draw.drawText(
            allocator,
            &face.font,
            draw_ctx.ctx,
            draw_ctx.drawTexture,
            text,
            x,
            y,
            face.metrics.cell_width,
            face.metrics.line_height,
            color.toRgba(),
            true,
            false,
        );
    }

    fn drawTextWithFontZoom(
        r: *Renderer,
        allocator: std.mem.Allocator,
        face: *SampleFontFace,
        text: []const u8,
        x: f32,
        y: f32,
        color: Color,
        zoom: f32,
    ) void {
        if (r.textRenderingMode() != .gl_texture_atlas) return;
        const draw_ctx = terminal_font_mod.DrawContext{ .ctx = r, .drawTexture = drawTextureThunk };
        const cell_w = face.metrics.cell_width * zoom;
        const cell_h = face.metrics.line_height * zoom;
        text_draw.drawText(allocator, &face.font, draw_ctx.ctx, draw_ctx.drawTexture, text, x, y, cell_w, cell_h, color.toRgba(), true, false);
    }

    fn baselineStressHeight(line_h: f32) f32 {
        // 1 label + 3 zoomed lines + spacing
        return line_h * 4.8;
    }

    fn drawTextureThunk(ctx: *anyopaque, texture: types.Texture, src: types.Rect, dest: types.Rect, color: types.Rgba, kind: types.TextureKind) void {
        const renderer: *Renderer = @ptrCast(@alignCast(ctx));
        draw_ops.drawTextureRect(renderer, texture, src, dest, color, renderer.text_render.bg_rgba, kind);
    }

    fn parseEnvF32(env_key: [:0]const u8, default_value: f32) f32 {
        const raw = std.c.getenv(env_key) orelse return default_value;
        const slice = std.mem.sliceTo(raw, 0);
        if (slice.len == 0) return default_value;
        return std.fmt.parseFloat(f32, slice) catch default_value;
    }

    fn sampleLines() []const []const u8 {
        return &[_][]const u8{
            "The quick brown fox jumps over the lazy dog 0123456789",
            "iiii llll | ||  ..,,;;::  '" ++ "\"" ++ "`",
            "mwMW  O0oO  1Il|  {}[]()  <>  == != <= >=",
            "Ligatures: ->  ~>  =>  ==  ===  !=  !==  <=  >=  <=>",
            "Mixed operators: >>= <<== && || :: .. ... |> <|",
            "Box: \u{2500}\u{2502}\u{250c}\u{2510}\u{2514}\u{2518}  Braille: \u{28ff}",
            "Powerline: \u{e0b0}\u{e0b1}\u{e0b2}\u{e0b3}  Nerd: \u{f120}",
            "Combining: e\u{0301} a\u{0308} n\u{0303}  Emoji: \u{1f600}",
        };
    }
};
