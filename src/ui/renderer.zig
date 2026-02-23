const std = @import("std");
const compositor = @import("../platform/compositor.zig");
const editor_render = @import("../editor/render/renderer_ops.zig");
const iface = @import("renderer/interface.zig");
const terminal_font_mod = @import("terminal_font.zig");
const TerminalFont = terminal_font_mod.TerminalFont;
const FontRenderingOptions = terminal_font_mod.RenderingOptions;
const hb = terminal_font_mod.c;
const font_manager = @import("renderer/font_manager.zig");
const draw_ops = @import("renderer/draw_ops.zig");
const gl_backend = @import("renderer/gl_backend.zig");
const input_constants = @import("renderer/input_constants.zig");
const clipboard = @import("renderer/clipboard.zig");
const texture_utils = @import("renderer/texture_utils.zig");
const text_input = @import("renderer/text_input.zig");
const time_utils = @import("renderer/time_utils.zig");
const window_init = @import("renderer/window_init.zig");
const input_state = @import("renderer/input_state.zig");
const input_queue = @import("renderer/input_queue.zig");
const scale_utils = @import("renderer/scale_utils.zig");
const targets = @import("renderer/targets.zig");
const text_draw = @import("renderer/text_draw.zig");
const gl_resources = @import("renderer/gl_resources.zig");
const draw_batch = @import("renderer/draw_batch.zig");
const target_draw = @import("renderer/target_draw.zig");
const key_state = @import("renderer/key_state.zig");
const shape_utils = @import("renderer/shape_utils.zig");
const shape_draw = @import("renderer/shape_draw.zig");
const terminal_glyphs = @import("renderer/terminal_glyphs.zig");
const clipboard_state = @import("renderer/clipboard_state.zig");
const terminal_underline = @import("renderer/terminal_underline.zig");
const mouse_state = @import("renderer/mouse_state.zig");
const texture_draw = @import("renderer/texture_draw.zig");
const text_composition = @import("renderer/text_composition.zig");
const window_flags = @import("renderer/window_flags.zig");
const mouse_wheel = @import("renderer/mouse_wheel.zig");
const input_logging = @import("renderer/input_logging.zig");
const window_metrics_state = @import("renderer/window_metrics_state.zig");
const key_queue = @import("renderer/key_queue.zig");
const screenshot = @import("renderer/screenshot.zig");
const glyph_cache = @import("glyph_cache.zig");
const platform_window = @import("../platform/window.zig");
const platform_input_events = @import("../platform/input_events.zig");
const platform_mouse = @import("../platform/mouse_state.zig");
const platform_window_events = @import("../platform/window_events.zig");
const build_options = @import("build_options");
const gl = @import("renderer/gl.zig");
const sdl_api = @import("../platform/sdl_api.zig");
const sdl_input = @import("renderer/sdl_input.zig");
const types = @import("renderer/types.zig");
const app_logger = @import("../app_logger.zig");

const sdl = gl.c;
const TextPress = platform_input_events.TextPress;

var active_renderer: ?*Renderer = null;
var mouse_wheel_delta: f32 = 0.0;
var sdl3_textinput_layout_logged: bool = false;
var sdl3_textediting_layout_logged: bool = false;
var sdl_input_env_logged: bool = false;

pub const FontFamily = iface.FontFamily;
pub const FONT_FAMILY = iface.FONT_FAMILY;
pub const FONT_PATH = iface.FONT_PATH;
pub const SYMBOLS_FALLBACK_PATH = iface.SYMBOLS_FALLBACK_PATH;
pub const UNICODE_SYMBOLS2_PATH = iface.UNICODE_SYMBOLS2_PATH;
pub const UNICODE_SYMBOLS_PATH = iface.UNICODE_SYMBOLS_PATH;
pub const UNICODE_MONO_PATH = iface.UNICODE_MONO_PATH;
pub const UNICODE_SANS_PATH = iface.UNICODE_SANS_PATH;
pub const EMOJI_COLOR_FALLBACK_PATH = iface.EMOJI_COLOR_FALLBACK_PATH;
pub const EMOJI_TEXT_FALLBACK_PATH = iface.EMOJI_TEXT_FALLBACK_PATH;

pub const Color = iface.Color;
pub const MousePos = iface.MousePos;
pub const Theme = iface.Theme;
pub const TerminalDisableLigaturesStrategy = enum {
    never,
    cursor,
    always,
};

pub const ShapeFeatureDomain = enum {
    terminal,
    editor,
};
pub const KEY_ENTER = input_constants.KEY_ENTER;
pub const KEY_BACKSPACE = input_constants.KEY_BACKSPACE;
pub const KEY_DELETE = input_constants.KEY_DELETE;
pub const KEY_TAB = input_constants.KEY_TAB;
pub const KEY_ESCAPE = input_constants.KEY_ESCAPE;
pub const KEY_UP = input_constants.KEY_UP;
pub const KEY_DOWN = input_constants.KEY_DOWN;
pub const KEY_LEFT = input_constants.KEY_LEFT;
pub const KEY_RIGHT = input_constants.KEY_RIGHT;
pub const KEY_HOME = input_constants.KEY_HOME;
pub const KEY_END = input_constants.KEY_END;
pub const KEY_PAGE_UP = input_constants.KEY_PAGE_UP;
pub const KEY_PAGE_DOWN = input_constants.KEY_PAGE_DOWN;
pub const KEY_INSERT = input_constants.KEY_INSERT;
pub const KEY_F1 = input_constants.KEY_F1;
pub const KEY_F2 = input_constants.KEY_F2;
pub const KEY_F3 = input_constants.KEY_F3;
pub const KEY_F4 = input_constants.KEY_F4;
pub const KEY_F5 = input_constants.KEY_F5;
pub const KEY_F6 = input_constants.KEY_F6;
pub const KEY_F7 = input_constants.KEY_F7;
pub const KEY_F8 = input_constants.KEY_F8;
pub const KEY_F9 = input_constants.KEY_F9;
pub const KEY_F10 = input_constants.KEY_F10;
pub const KEY_F11 = input_constants.KEY_F11;
pub const KEY_F12 = input_constants.KEY_F12;
pub const KEY_KP_0 = input_constants.KEY_KP_0;
pub const KEY_KP_1 = input_constants.KEY_KP_1;
pub const KEY_KP_2 = input_constants.KEY_KP_2;
pub const KEY_KP_3 = input_constants.KEY_KP_3;
pub const KEY_KP_4 = input_constants.KEY_KP_4;
pub const KEY_KP_5 = input_constants.KEY_KP_5;
pub const KEY_KP_6 = input_constants.KEY_KP_6;
pub const KEY_KP_7 = input_constants.KEY_KP_7;
pub const KEY_KP_8 = input_constants.KEY_KP_8;
pub const KEY_KP_9 = input_constants.KEY_KP_9;
pub const KEY_KP_DECIMAL = input_constants.KEY_KP_DECIMAL;
pub const KEY_KP_DIVIDE = input_constants.KEY_KP_DIVIDE;
pub const KEY_KP_MULTIPLY = input_constants.KEY_KP_MULTIPLY;
pub const KEY_KP_SUBTRACT = input_constants.KEY_KP_SUBTRACT;
pub const KEY_KP_ADD = input_constants.KEY_KP_ADD;
pub const KEY_KP_ENTER = input_constants.KEY_KP_ENTER;
pub const KEY_KP_EQUAL = input_constants.KEY_KP_EQUAL;
pub const KEY_LEFT_CONTROL = input_constants.KEY_LEFT_CONTROL;
pub const KEY_RIGHT_CONTROL = input_constants.KEY_RIGHT_CONTROL;
pub const KEY_LEFT_SHIFT = input_constants.KEY_LEFT_SHIFT;
pub const KEY_RIGHT_SHIFT = input_constants.KEY_RIGHT_SHIFT;
pub const KEY_LEFT_ALT = input_constants.KEY_LEFT_ALT;
pub const KEY_RIGHT_ALT = input_constants.KEY_RIGHT_ALT;
pub const KEY_LEFT_SUPER = input_constants.KEY_LEFT_SUPER;
pub const KEY_RIGHT_SUPER = input_constants.KEY_RIGHT_SUPER;
pub const KEY_ZERO = input_constants.KEY_ZERO;
pub const KEY_ONE = input_constants.KEY_ONE;
pub const KEY_TWO = input_constants.KEY_TWO;
pub const KEY_THREE = input_constants.KEY_THREE;
pub const KEY_FOUR = input_constants.KEY_FOUR;
pub const KEY_FIVE = input_constants.KEY_FIVE;
pub const KEY_SIX = input_constants.KEY_SIX;
pub const KEY_SEVEN = input_constants.KEY_SEVEN;
pub const KEY_EIGHT = input_constants.KEY_EIGHT;
pub const KEY_NINE = input_constants.KEY_NINE;
pub const KEY_SPACE = input_constants.KEY_SPACE;
pub const KEY_MINUS = input_constants.KEY_MINUS;
pub const KEY_EQUAL = input_constants.KEY_EQUAL;
pub const KEY_LEFT_BRACKET = input_constants.KEY_LEFT_BRACKET;
pub const KEY_RIGHT_BRACKET = input_constants.KEY_RIGHT_BRACKET;
pub const KEY_BACKSLASH = input_constants.KEY_BACKSLASH;
pub const KEY_SEMICOLON = input_constants.KEY_SEMICOLON;
pub const KEY_APOSTROPHE = input_constants.KEY_APOSTROPHE;
pub const KEY_GRAVE = input_constants.KEY_GRAVE;
pub const KEY_COMMA = input_constants.KEY_COMMA;
pub const KEY_PERIOD = input_constants.KEY_PERIOD;
pub const KEY_SLASH = input_constants.KEY_SLASH;
pub const KEY_S = input_constants.KEY_S;
pub const KEY_Z = input_constants.KEY_Z;
pub const KEY_Y = input_constants.KEY_Y;
pub const KEY_C = input_constants.KEY_C;
pub const KEY_V = input_constants.KEY_V;
pub const KEY_X = input_constants.KEY_X;
pub const KEY_A = input_constants.KEY_A;
pub const KEY_B = input_constants.KEY_B;
pub const KEY_D = input_constants.KEY_D;
pub const KEY_E = input_constants.KEY_E;
pub const KEY_F = input_constants.KEY_F;
pub const KEY_G = input_constants.KEY_G;
pub const KEY_H = input_constants.KEY_H;
pub const KEY_I = input_constants.KEY_I;
pub const KEY_J = input_constants.KEY_J;
pub const KEY_K = input_constants.KEY_K;
pub const KEY_L = input_constants.KEY_L;
pub const KEY_M = input_constants.KEY_M;
pub const KEY_N = input_constants.KEY_N;
pub const KEY_O = input_constants.KEY_O;
pub const KEY_P = input_constants.KEY_P;
pub const KEY_Q = input_constants.KEY_Q;
pub const KEY_R = input_constants.KEY_R;
pub const KEY_T = input_constants.KEY_T;
pub const KEY_U = input_constants.KEY_U;
pub const KEY_W = input_constants.KEY_W;
pub const MOUSE_LEFT = input_constants.MOUSE_LEFT;
pub const MOUSE_RIGHT = input_constants.MOUSE_RIGHT;
pub const MOUSE_MIDDLE = input_constants.MOUSE_MIDDLE;

pub const RendererBackend = enum {
    sdl_gl,
};

pub const renderer_backend: RendererBackend = parseRendererBackend(build_options.renderer_backend);

fn parseRendererBackend(_: []const u8) RendererBackend {
    return .sdl_gl;
}

const key_repeat_key_count: usize = sdl_api.scancode_count;
const mouse_button_count: usize = 8;
const input_queue_capacity: usize = 8192;
const KeyPress = input_state.KeyPress;

const RenderTarget = targets.RenderTarget;

const BatchDraw = draw_ops.BatchDraw;
const Vertex = draw_ops.Vertex;

pub const Renderer = struct {
    allocator: std.mem.Allocator,
    window: *sdl.SDL_Window,
    gl_context: sdl.SDL_GLContext,
    width: i32,
    height: i32,
    render_width: i32,
    render_height: i32,
    target_width: i32,
    target_height: i32,
    target_pixel_width: i32,
    target_pixel_height: i32,

    shader_program: gl.GLuint,
    vao: gl.GLuint,
    vbo: gl.GLuint,
    vbo_capacity_vertices: usize,
    uniform_proj: gl.GLint,
    uniform_tex: gl.GLint,
    uniform_kind: gl.GLint,
    uniform_text_gamma: gl.GLint,
    uniform_text_contrast: gl.GLint,
    uniform_dst_linear: gl.GLint,
    uniform_linear_correction: gl.GLint,
    dst_linear_active: bool,
    white_texture: types.Texture,

    text_gamma: f32,
    text_contrast: f32,
    text_linear_correction: bool,

    // Text background behind glyphs (used for optional linear correction).
    // Default is alpha=0, which disables correction in the shader.
    text_bg_rgba: types.Rgba,

    font_size: f32,
    base_font_size: f32,
    char_width: f32,
    char_height: f32,
    icon_font: TerminalFont,
    icon_font_size: f32,
    icon_char_width: f32,
    icon_char_height: f32,
    terminal_cell_width: f32,
    terminal_cell_height: f32,
    terminal_font: TerminalFont,
    terminal_disable_ligatures: TerminalDisableLigaturesStrategy,
    terminal_font_features_raw: ?[]u8,
    terminal_font_features: std.ArrayListUnmanaged(hb.hb_feature_t),
    editor_disable_ligatures: TerminalDisableLigaturesStrategy,
    editor_font_features_raw: ?[]u8,
    editor_font_features: std.ArrayListUnmanaged(hb.hb_feature_t),
    font_rendering: FontRenderingOptions,
    font_cache: std.AutoHashMap(u32, *TerminalFont),
    font_path: [*:0]const u8,
    font_path_owned: ?[]u8,

    terminal_target: ?RenderTarget,
    editor_target: ?RenderTarget,

    theme: Theme,
    mouse_scale: MousePos,
    render_scale: f32,
    user_zoom: f32,
    user_zoom_target: f32,
    ui_scale: f32,
    last_zoom_request_time: f64,
    last_zoom_apply_time: f64,
    wayland_scale_cache: ?f32,
    wayland_scale_last_update: f64,
    key_down: [key_repeat_key_count]bool,
    key_pressed: [key_repeat_key_count]bool,
    key_repeated: [key_repeat_key_count]bool,
    key_released: [key_repeat_key_count]bool,
    mouse_down: [mouse_button_count]bool,
    mouse_pressed: [mouse_button_count]bool,
    mouse_released: [mouse_button_count]bool,
    key_queue: std.ArrayList(KeyPress),
    char_queue: std.ArrayList(TextPress),
    composing_text: std.ArrayList(u8),
    composing_cursor: i32,
    composing_selection_len: i32,
    composing_active: bool,
    sdl_input: sdl_input.SdlInput,
    clipboard_buffer: std.ArrayList(u8),
    batch_vertices: std.ArrayList(Vertex),
    batch_draws: std.ArrayList(BatchDraw),
    terminal_glyph_cache: glyph_cache.GlyphCache,

    // Terminal run-based shaping scratch buffers.
    terminal_shape_first_pen: std.ArrayListUnmanaged(f32),
    terminal_shape_first_pen_set: std.ArrayListUnmanaged(bool),
    should_close_flag: bool,
    window_resized_flag: bool,
    text_input_state: text_input.TextInputState,

    start_counter: u64,
    perf_freq: f64,

    fn snapInt(value: f32) i32 {
        return @intFromFloat(std.math.round(value));
    }

    fn snapFloat(value: f32) f32 {
        return @as(f32, @floatFromInt(snapInt(value)));
    }

    fn snapToDevicePixel(value: f32, render_scale: f32) f32 {
        const scale = if (render_scale > 0.0) render_scale else 1.0;
        return @as(f32, @floatFromInt(@as(i32, @intFromFloat(std.math.round(value * scale))))) / scale;
    }

    pub fn init(allocator: std.mem.Allocator, width: i32, height: i32, title: [*:0]const u8) !*Renderer {
        try window_init.initSdl();
        errdefer sdl.SDL_Quit();

        window_init.configureGlAttributes();

        const window = try window_init.createWindow(width, height, title);
        errdefer sdl.SDL_DestroyWindow(window);

        const gl_context = try window_init.createGlContext(window);
        errdefer sdl_api.glDeleteContext(gl_context);

        try gl.load();

        var renderer = try allocator.create(Renderer);
        errdefer allocator.destroy(renderer);

        const drawable = platform_window.getDrawableSize(window);
        const window_size = platform_window.getWindowSize(window);

        const base_font_size: f32 = 16.0;
        const ui_scale: f32 = 1.0;
        const font_size = base_font_size * ui_scale;
        const render_scale = platform_window.getRenderScale(window);

        renderer.* = .{
            .allocator = allocator,
            .window = window,
            .gl_context = gl_context,
            .width = window_size.w,
            .height = window_size.h,
            .render_width = drawable.w,
            .render_height = drawable.h,
            .target_width = drawable.w,
            .target_height = drawable.h,
            .target_pixel_width = drawable.w,
            .target_pixel_height = drawable.h,
            .shader_program = 0,
            .vao = 0,
            .vbo = 0,
            .vbo_capacity_vertices = 0,
            .uniform_proj = -1,
            .uniform_tex = -1,
            .uniform_kind = -1,
            .uniform_text_gamma = -1,
            .uniform_text_contrast = -1,
            .uniform_dst_linear = -1,
            .uniform_linear_correction = -1,
            .dst_linear_active = false,
            .white_texture = .{ .id = 0, .width = 0, .height = 0 },
            .text_gamma = 1.0,
            .text_contrast = 1.0,
            .text_linear_correction = true,
            .text_bg_rgba = .{ .r = 0, .g = 0, .b = 0, .a = 0 },
            .font_size = font_size,
            .base_font_size = base_font_size,
            .char_width = font_size * 0.6,
            .char_height = font_size * 1.2,
            .icon_font = undefined,
            .icon_font_size = font_size * 2.0,
            .icon_char_width = font_size * 1.2,
            .icon_char_height = font_size * 1.2,
            .terminal_cell_width = font_size * 0.6,
            .terminal_cell_height = font_size * 1.2,
            .terminal_font = undefined,
            .terminal_disable_ligatures = .never,
            .terminal_font_features_raw = null,
            .terminal_font_features = .{},
            .editor_disable_ligatures = .never,
            .editor_font_features_raw = null,
            .editor_font_features = .{},
            .font_rendering = .{},
            .font_cache = std.AutoHashMap(u32, *TerminalFont).init(allocator),
            .font_path = FONT_PATH,
            .font_path_owned = null,
            .terminal_target = null,
            .editor_target = null,
            .theme = .{},
            .mouse_scale = .{ .x = 1.0, .y = 1.0 },
            .render_scale = render_scale,
            .user_zoom = 1.0,
            .user_zoom_target = 1.0,
            .ui_scale = ui_scale,
            .last_zoom_request_time = 0.0,
            .last_zoom_apply_time = 0.0,
            .wayland_scale_cache = null,
            .wayland_scale_last_update = -1000.0,
            .key_down = [_]bool{false} ** key_repeat_key_count,
            .key_pressed = [_]bool{false} ** key_repeat_key_count,
            .key_repeated = [_]bool{false} ** key_repeat_key_count,
            .key_released = [_]bool{false} ** key_repeat_key_count,
            .mouse_down = [_]bool{false} ** mouse_button_count,
            .mouse_pressed = [_]bool{false} ** mouse_button_count,
            .mouse_released = [_]bool{false} ** mouse_button_count,
            .key_queue = std.ArrayList(KeyPress).empty,
            .char_queue = std.ArrayList(TextPress).empty,
            .composing_text = std.ArrayList(u8).empty,
            .composing_cursor = 0,
            .composing_selection_len = 0,
            .composing_active = false,
            .sdl_input = .{},
            .clipboard_buffer = std.ArrayList(u8).empty,
            .batch_vertices = std.ArrayList(Vertex).empty,
            .batch_draws = std.ArrayList(BatchDraw).empty,
            .terminal_glyph_cache = glyph_cache.GlyphCache.init(allocator),
            .terminal_shape_first_pen = .{},
            .terminal_shape_first_pen_set = .{},
            .should_close_flag = false,
            .window_resized_flag = false,
            .text_input_state = text_input.initState(),
            .start_counter = sdl_api.getPerformanceCounter(),
            .perf_freq = @as(f64, @floatFromInt(sdl_api.getPerformanceFrequency())),
        };

        try renderer.initGlResources();
        try renderer.initFonts(font_size);

        sdl_api.startTextInput(window);
        try renderer.initInputThread();

        active_renderer = renderer;
        return renderer;
    }

    fn initInputThread(self: *Renderer) !void {
        try self.sdl_input.init(self.allocator, input_queue_capacity);
        errdefer self.sdl_input.deinit(self.allocator);
    }

    pub fn deinit(self: *Renderer) void {
        self.destroyRenderTarget(&self.terminal_target);
        self.destroyRenderTarget(&self.editor_target);

        var font_it = self.font_cache.iterator();
        while (font_it.next()) |entry| {
            entry.value_ptr.*.deinit();
            self.allocator.destroy(entry.value_ptr.*);
        }
        self.font_cache.deinit();

        self.terminal_font.deinit();
        self.icon_font.deinit();
        if (self.terminal_font_features_raw) |owned| {
            self.allocator.free(owned);
            self.terminal_font_features_raw = null;
        }
        self.terminal_font_features.deinit(self.allocator);
        if (self.editor_font_features_raw) |owned| {
            self.allocator.free(owned);
            self.editor_font_features_raw = null;
        }
        self.editor_font_features.deinit(self.allocator);
        if (self.font_path_owned) |owned| {
            self.allocator.free(owned);
            self.font_path_owned = null;
        }

        self.key_queue.deinit(self.allocator);
        self.char_queue.deinit(self.allocator);
        self.composing_text.deinit(self.allocator);
        self.sdl_input.deinit(self.allocator);
        self.clipboard_buffer.deinit(self.allocator);
        self.batch_vertices.deinit(self.allocator);
        self.batch_draws.deinit(self.allocator);
        self.terminal_glyph_cache.deinit();

        self.terminal_shape_first_pen.deinit(self.allocator);
        self.terminal_shape_first_pen_set.deinit(self.allocator);

        if (self.white_texture.id != 0) {
            gl.DeleteTextures(1, &self.white_texture.id);
        }
        gl_resources.destroy(.{
            .shader_program = self.shader_program,
            .vao = self.vao,
            .vbo = self.vbo,
            .uniform_proj = self.uniform_proj,
            .uniform_tex = self.uniform_tex,
        });

        sdl_api.stopTextInput(self.window);
        sdl_api.glDeleteContext(self.gl_context);
        sdl.SDL_DestroyWindow(self.window);
        sdl.SDL_Quit();

        if (active_renderer == self) active_renderer = null;
        self.allocator.destroy(self);
    }

    fn shutdownInputThread(self: *Renderer) void {
        _ = self;
    }

    fn initGlResources(self: *Renderer) !void {
        try gl_backend.initGlResources(self);
    }

    fn initFonts(self: *Renderer, size: f32) !void {
        try font_manager.initFonts(self, size);
    }

    pub fn loadFont(self: *Renderer, path: [*:0]const u8, size: f32) void {
        font_manager.loadFont(self, path, size);
    }

    pub fn setFontConfig(self: *Renderer, path: ?[]const u8, size: ?f32) !void {
        try font_manager.setFontConfig(self, path, size);
    }

    pub fn setFontRenderingOptions(self: *Renderer, opts: FontRenderingOptions) void {
        self.font_rendering = opts;
    }

    pub fn setTextRenderingConfig(self: *Renderer, gamma: ?f32, contrast: ?f32, linear_correction: ?bool) void {
        if (gamma) |v| {
            if (v > 0) self.text_gamma = v;
        }
        if (contrast) |v| {
            if (v > 0) self.text_contrast = v;
        }
        if (linear_correction) |v| {
            self.text_linear_correction = v;
        }

        // Update shader uniforms if GL is initialized.
        if (self.shader_program != 0) {
            gl.UseProgram(self.shader_program);
            if (self.uniform_text_gamma >= 0) gl.Uniform1f(self.uniform_text_gamma, self.text_gamma);
            if (self.uniform_text_contrast >= 0) gl.Uniform1f(self.uniform_text_contrast, self.text_contrast);
            if (self.uniform_linear_correction >= 0) gl.Uniform1i(self.uniform_linear_correction, if (self.text_linear_correction) 1 else 0);
        }
    }

    pub fn setTerminalLigatureConfig(self: *Renderer, strategy: ?TerminalDisableLigaturesStrategy, features_raw: ?[]const u8) void {
        if (strategy) |s| {
            self.terminal_disable_ligatures = s;
        }
        if (features_raw) |raw| {
            self.setFontFeatureListRaw(&self.terminal_font_features_raw, &self.terminal_font_features, raw);
        }
    }

    pub fn setEditorLigatureConfig(self: *Renderer, strategy: ?TerminalDisableLigaturesStrategy, features_raw: ?[]const u8) void {
        if (strategy) |s| {
            self.editor_disable_ligatures = s;
        }
        if (features_raw) |raw| {
            self.setFontFeatureListRaw(&self.editor_font_features_raw, &self.editor_font_features, raw);
        }
    }

    fn setFontFeatureListRaw(self: *Renderer, raw_slot: *?[]u8, list: *std.ArrayListUnmanaged(hb.hb_feature_t), raw: []const u8) void {
        if (raw_slot.*) |owned| {
            self.allocator.free(owned);
            raw_slot.* = null;
        }
        raw_slot.* = self.allocator.dupe(u8, raw) catch null;
        self.rebuildFontFeaturesList(raw_slot.*, list);
    }

    fn rebuildFontFeaturesList(self: *Renderer, raw_opt: ?[]u8, list: *std.ArrayListUnmanaged(hb.hb_feature_t)) void {
        list.items.len = 0;
        const raw = raw_opt orelse return;
        var it = std.mem.splitScalar(u8, raw, ',');
        while (it.next()) |piece| {
            const token = std.mem.trim(u8, piece, " \t\r\n");
            if (token.len == 0) continue;
            var feature: hb.hb_feature_t = undefined;
            if (hb.hb_feature_from_string(token.ptr, @intCast(token.len), &feature) != 0) {
                list.append(self.allocator, feature) catch return;
            }
        }
    }

    fn hbTag(a: u8, b: u8, cch: u8, d: u8) u32 {
        return (@as(u32, a) << 24) | (@as(u32, b) << 16) | (@as(u32, cch) << 8) | @as(u32, d);
    }

    const hb_feature_all: u32 = 0xFFFFFFFF;

    pub fn collectShapeFeatures(self: *Renderer, domain: ShapeFeatureDomain, disable_programming_ligatures: bool, out: []hb.hb_feature_t) usize {
        var len: usize = 0;
        const base = switch (domain) {
            .terminal => self.terminal_font_features.items,
            .editor => if (self.editor_font_features_raw != null)
                self.editor_font_features.items
            else
                self.terminal_font_features.items,
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

    pub fn loadFontWithGlyphs(self: *Renderer, allocator: std.mem.Allocator, path: [*:0]const u8, size: f32) void {
        _ = allocator;
        self.loadFont(path, size);
    }

    fn queryUiScale(self: *Renderer) f32 {
        const dpi = self.getDpiScale();
        var wayland = scale_utils.WaylandScaleState{
            .cache = self.wayland_scale_cache,
            .last_update = self.wayland_scale_last_update,
        };
        const scale = scale_utils.queryUiScale(self.allocator, dpi, getTime(), &wayland);
        self.wayland_scale_cache = wayland.cache;
        self.wayland_scale_last_update = wayland.last_update;
        return scale;
    }

    fn applyFontScale(self: *Renderer) !void {
        try font_manager.applyFontScale(self);
        text_input.reapplyRect(&self.text_input_state, self.window);
    }

    pub fn queueUserZoom(self: *Renderer, delta: f32, now: f64) bool {
        const result = scale_utils.queueUserZoom(self.user_zoom_target, delta, now, 0.5, 3.0);
        self.user_zoom_target = result.next_target;
        self.last_zoom_request_time = result.request_time;
        return result.changed;
    }

    pub fn resetUserZoomTarget(self: *Renderer, now: f64) bool {
        const result = scale_utils.resetUserZoomTarget(self.user_zoom_target, now);
        self.user_zoom_target = result.next_target;
        self.last_zoom_request_time = result.request_time;
        return result.changed;
    }

    pub fn refreshUiScale(self: *Renderer) !bool {
        const next = self.queryUiScale();
        const next_render = platform_window.getRenderScale(self.window);
        const scale_changed = !std.math.approxEqAbs(f32, next, self.ui_scale, 0.0001);
        const render_changed = !std.math.approxEqAbs(f32, next_render, self.render_scale, 0.0001);
        if (!scale_changed and !render_changed) return false;
        const log = app_logger.logger("ui.scale");
        if (log.enabled_file or log.enabled_console) {
            const layout_size = self.base_font_size * next * self.user_zoom;
            const raster_size = layout_size * next_render;
            log.logf("ui_scale window={d:.3} render={d:.3}->{d:.3} user_zoom={d:.3} font={d:.2}->{d:.2}", .{
                next,
                self.render_scale,
                next_render,
                self.user_zoom,
                self.font_size,
                layout_size,
            });
            log.logf("ui_scale layout_size={d:.2} raster_size={d:.2}", .{ layout_size, raster_size });
        }
        self.ui_scale = next;
        self.render_scale = next_render;
        try self.applyFontScale();
        return true;
    }

    pub fn applyPendingZoom(self: *Renderer, now: f64) !bool {
        const result = scale_utils.applyPendingZoom(
            self.user_zoom,
            self.user_zoom_target,
            now,
            self.last_zoom_request_time,
            self.last_zoom_apply_time,
            0.04,
            0.02,
        );
        if (!result.changed) return false;
        self.user_zoom = result.next_zoom;
        const log = app_logger.logger("ui.scale");
        if (log.enabled_file or log.enabled_console) {
            const layout_size = self.base_font_size * self.ui_scale * self.user_zoom;
            const raster_size = layout_size * self.render_scale;
            log.logf("ui_zoom window={d:.3} render={d:.3} user_zoom={d:.3} font={d:.2}->{d:.2}", .{
                self.ui_scale,
                self.render_scale,
                self.user_zoom,
                self.font_size,
                layout_size,
            });
            log.logf("ui_zoom layout_size={d:.2} raster_size={d:.2}", .{ layout_size, raster_size });
        }
        try self.applyFontScale();
        if (log.enabled_file or log.enabled_console) {
            log.logf(
                "ui_zoom_effective base={d:.2} ui={d:.3} zoom={d:.3} target={d:.3} render={d:.3} font={d:.2} term_cell={d:.2}x{d:.2}",
                .{
                    self.base_font_size,
                    self.ui_scale,
                    self.user_zoom,
                    self.user_zoom_target,
                    self.render_scale,
                    self.font_size,
                    self.terminal_cell_width,
                    self.terminal_cell_height,
                },
            );
        }
        self.last_zoom_apply_time = result.apply_time;
        return true;
    }

    pub fn uiScaleFactor(self: *const Renderer) f32 {
        return self.ui_scale * self.user_zoom;
    }

    pub fn userZoomFactor(self: *const Renderer) f32 {
        return self.user_zoom;
    }

    pub fn userZoomTargetFactor(self: *const Renderer) f32 {
        return self.user_zoom_target;
    }

    pub fn baseFontSize(self: *const Renderer) f32 {
        return self.base_font_size;
    }

    pub fn renderScaleFactor(self: *const Renderer) f32 {
        return self.render_scale;
    }

    pub fn shouldClose(self: *Renderer) bool {
        return self.should_close_flag;
    }

    pub fn beginFrame(self: *Renderer) void {
        const sizes = window_metrics_state.refresh(self.window);
        self.width = sizes.width;
        self.height = sizes.height;
        self.render_width = sizes.render_width;
        self.render_height = sizes.render_height;

        // Avoid leaking background context across different text draws.
        self.text_bg_rgba = .{ .r = 0, .g = 0, .b = 0, .a = 0 };

        self.bindDefaultTarget();
        self.updateMouseScale();
        gl.Disable(gl.c.GL_SCISSOR_TEST);

        const bg = self.theme.background.toRgba();
        gl.ClearColor(
            @as(f32, @floatFromInt(bg.r)) / 255.0,
            @as(f32, @floatFromInt(bg.g)) / 255.0,
            @as(f32, @floatFromInt(bg.b)) / 255.0,
            @as(f32, @floatFromInt(bg.a)) / 255.0,
        );
        gl.Clear(gl.c.GL_COLOR_BUFFER_BIT);
    }

    pub fn endFrame(self: *Renderer) void {
        sdl_api.glSwapWindow(self.window);
    }

    pub fn dumpWindowScreenshotPpm(self: *Renderer, path: []const u8) !void {
        // Ensure we're reading back the window framebuffer at the window pixel size.
        self.bindDefaultTarget();
        // Downscale to logical window size to keep captures stable across DPI/render scale.
        try screenshot.dumpFramebufferPpmScaled(self.allocator, self.render_width, self.render_height, self.width, self.height, path);
    }

    pub fn dumpWindowScreenshotPpmSized(self: *Renderer, path: []const u8, out_width: i32, out_height: i32) !void {
        if (out_width <= 0 or out_height <= 0) {
            try self.dumpWindowScreenshotPpm(path);
            return;
        }
        // Ensure we're reading back the window framebuffer at the window pixel size.
        self.bindDefaultTarget();
        try screenshot.dumpFramebufferPpmScaled(self.allocator, self.render_width, self.render_height, out_width, out_height, path);
    }

    pub fn clearToThemeBackground(self: *Renderer) void {
        const bg = self.theme.background.toRgba();
        var rr = @as(f32, @floatFromInt(bg.r)) / 255.0;
        var gg = @as(f32, @floatFromInt(bg.g)) / 255.0;
        var bb = @as(f32, @floatFromInt(bg.b)) / 255.0;
        const aa = @as(f32, @floatFromInt(bg.a)) / 255.0;
        if (self.dst_linear_active) {
            rr = srgbToLinear(rr);
            gg = srgbToLinear(gg);
            bb = srgbToLinear(bb);
        }
        gl.ClearColor(rr, gg, bb, aa);
        gl.Clear(gl.c.GL_COLOR_BUFFER_BIT);
    }

    fn srgbToLinear(c: f32) f32 {
        if (c <= 0.04045) return c / 12.92;
        return std.math.pow(f32, (c + 0.055) / 1.055, 2.4);
    }

    pub fn setTextInputRect(self: *Renderer, x: i32, y: i32, w: i32, h: i32) void {
        text_input.setRect(&self.text_input_state, self.window, x, y, w, h);
    }

    pub fn ensureTerminalTexture(self: *Renderer, width: i32, height: i32) bool {
        return self.ensureRenderTargetScaled(&self.terminal_target, width, height, target_draw.nearestFilter());
    }

    pub fn ensureEditorTexture(self: *Renderer, width: i32, height: i32) bool {
        return self.ensureRenderTargetScaled(&self.editor_target, width, height, target_draw.nearestFilter());
    }

    pub fn beginTerminalTexture(self: *Renderer) bool {
        return self.beginRenderTarget(self.terminal_target);
    }

    pub fn endTerminalTexture(self: *Renderer) void {
        self.bindDefaultTarget();
    }

    pub fn beginEditorTexture(self: *Renderer) bool {
        return self.beginRenderTarget(self.editor_target);
    }

    pub fn endEditorTexture(self: *Renderer) void {
        self.bindDefaultTarget();
    }

    pub fn drawTerminalTexture(self: *Renderer, x: f32, y: f32) void {
        if (self.terminal_target) |target| {
            const src = texture_draw.fullTextureSrcRect(target.texture);
            const dest = types.Rect{
                .x = x,
                .y = y,
                .width = @floatFromInt(target.logical_width),
                .height = @floatFromInt(target.logical_height),
            };
            draw_ops.drawTextureRect(self, target.texture, src, dest, Color.white.toRgba(), types.Rgba{ .r = 0, .g = 0, .b = 0, .a = 0 }, .linear_premul);
        }
    }

    pub fn scrollTerminalTexture(self: *Renderer, dx: i32, dy: i32) bool {
        if (self.terminal_target) |target| {
            return targets.scrollRenderTarget(self, self.terminal_target, dx, dy, target.logical_width, target.logical_height);
        }
        return false;
    }

    pub fn drawEditorTexture(self: *Renderer, x: f32, y: f32) void {
        if (self.editor_target) |target| {
            const src = texture_draw.fullTextureSrcRect(target.texture);
            const dest = types.Rect{
                .x = x,
                .y = y,
                .width = @floatFromInt(target.logical_width),
                .height = @floatFromInt(target.logical_height),
            };
            draw_ops.drawTextureRect(self, target.texture, src, dest, Color.white.toRgba(), types.Rgba{ .r = 0, .g = 0, .b = 0, .a = 0 }, .linear_premul);
        }
    }

    pub fn drawRect(self: *Renderer, x: i32, y: i32, w: i32, h: i32, color: Color) void {
        if (w <= 0 or h <= 0) return;
        const dest = shape_utils.rectFromInts(x, y, w, h);
        const src = texture_draw.unitSrcRect();
        self.drawTextureRect(self.white_texture, src, dest, color.toRgba());
    }

    pub fn drawRectOutline(self: *Renderer, x: i32, y: i32, w: i32, h: i32, color: Color) void {
        shape_draw.drawRectOutline(drawRectThunk, self, x, y, w, h, color);
    }

    pub fn setClipboardText(_: *Renderer, text: [*:0]const u8) void {
        clipboard.setText(text);
    }

    pub fn getClipboardText(self: *Renderer) ?[]const u8 {
        return clipboard_state.getText(self.allocator, &self.clipboard_buffer);
    }

    pub fn drawText(self: *Renderer, text: []const u8, x: f32, y: f32, color: Color) void {
        const prev = self.text_bg_rgba;
        defer self.text_bg_rgba = prev;
        self.text_bg_rgba = .{ .r = 0, .g = 0, .b = 0, .a = 0 };
        self.drawTextWithFont(&self.terminal_font, self.terminal_cell_width, self.terminal_cell_height, text, x, y, color);
    }

    pub fn drawTextMonospace(self: *Renderer, text: []const u8, x: f32, y: f32, color: Color) void {
        self.drawTextMonospacePolicy(text, x, y, color, false);
    }

    pub fn drawTextMonospacePolicy(self: *Renderer, text: []const u8, x: f32, y: f32, color: Color, disable_programming_ligatures: bool) void {
        const prev = self.text_bg_rgba;
        defer self.text_bg_rgba = prev;
        self.text_bg_rgba = .{ .r = 0, .g = 0, .b = 0, .a = 0 };
        self.drawTextWithFontMonospace(&self.terminal_font, self.terminal_cell_width, self.terminal_cell_height, text, x, y, color, disable_programming_ligatures);
    }

    pub fn drawTextMonospaceOnBg(self: *Renderer, text: []const u8, x: f32, y: f32, color: Color, bg: Color) void {
        self.drawTextMonospaceOnBgPolicy(text, x, y, color, bg, false);
    }

    pub fn drawTextMonospaceOnBgPolicy(self: *Renderer, text: []const u8, x: f32, y: f32, color: Color, bg: Color, disable_programming_ligatures: bool) void {
        const prev = self.text_bg_rgba;
        defer self.text_bg_rgba = prev;
        var bg_rgba = bg.toRgba();
        bg_rgba.a = 255;
        self.text_bg_rgba = bg_rgba;
        self.drawTextWithFontMonospace(&self.terminal_font, self.terminal_cell_width, self.terminal_cell_height, text, x, y, color, disable_programming_ligatures);
    }

    pub fn drawTextOnBg(self: *Renderer, text: []const u8, x: f32, y: f32, color: Color, bg: Color) void {
        const prev = self.text_bg_rgba;
        defer self.text_bg_rgba = prev;
        var bg_rgba = bg.toRgba();
        bg_rgba.a = 255;
        self.text_bg_rgba = bg_rgba;
        self.drawTextWithFont(&self.terminal_font, self.terminal_cell_width, self.terminal_cell_height, text, x, y, color);
    }

    pub fn drawTextSized(self: *Renderer, text: []const u8, x: f32, y: f32, size: f32, color: Color) void {
        const prev = self.text_bg_rgba;
        defer self.text_bg_rgba = prev;
        self.text_bg_rgba = .{ .r = 0, .g = 0, .b = 0, .a = 0 };
        const font = self.fontForSize(size) orelse {
            self.drawText(text, x, y, color);
            return;
        };
        const scale = if (self.render_scale > 0.0) self.render_scale else 1.0;
        self.drawTextWithFont(font, font.cell_width / scale, font.line_height / scale, text, x, y, color);
    }

    pub fn drawIconText(self: *Renderer, text: []const u8, x: f32, y: f32, color: Color) void {
        const prev = self.text_bg_rgba;
        defer self.text_bg_rgba = prev;
        self.text_bg_rgba = .{ .r = 0, .g = 0, .b = 0, .a = 0 };
        self.drawTextWithFont(&self.icon_font, self.icon_char_width, self.icon_char_height, text, x, y, color);
    }

    pub fn measureIconTextWidth(self: *Renderer, text: []const u8) f32 {
        return self.measureTextWidth(&self.icon_font, text);
    }

    pub fn drawChar(self: *Renderer, char: u8, x: f32, y: f32, color: Color) void {
        var buf = [1]u8{char};
        self.drawText(buf[0..], x, y, color);
    }

    pub fn drawLine(self: *Renderer, x1: i32, y1: i32, x2: i32, y2: i32, color: Color) void {
        shape_draw.drawLine(drawRectThunk, self, x1, y1, x2, y2, color);
    }

    pub fn beginClip(self: *Renderer, x: i32, y: i32, w: i32, h: i32) void {
        gl.Enable(gl.c.GL_SCISSOR_TEST);
        const scale_x = @as(f32, @floatFromInt(self.target_pixel_width)) / @as(f32, @floatFromInt(self.target_width));
        const scale_y = @as(f32, @floatFromInt(self.target_pixel_height)) / @as(f32, @floatFromInt(self.target_height));
        const sx: i32 = @intFromFloat(@as(f32, @floatFromInt(x)) * scale_x);
        const sy: i32 = @intFromFloat(@as(f32, @floatFromInt(self.target_height - (y + h))) * scale_y);
        const sw: i32 = @intFromFloat(@as(f32, @floatFromInt(w)) * scale_x);
        const sh: i32 = @intFromFloat(@as(f32, @floatFromInt(h)) * scale_y);
        gl.Scissor(sx, sy, sw, sh);
    }

    pub fn endClip(_: *Renderer) void {
        gl.Disable(gl.c.GL_SCISSOR_TEST);
    }

    pub fn drawEditorLine(
        self: *Renderer,
        line_num: usize,
        text: []const u8,
        y: f32,
        x: f32,
        gutter_width: f32,
        content_width: f32,
        is_current: bool,
    ) void {
        editor_render.drawEditorLine(self, line_num, text, y, x, gutter_width, content_width, is_current);
    }

    pub fn drawEditorLineBase(
        self: *Renderer,
        line_num: usize,
        y: f32,
        x: f32,
        gutter_width: f32,
        content_width: f32,
        is_current: bool,
    ) void {
        editor_render.drawEditorLineBase(self, line_num, y, x, gutter_width, content_width, is_current);
    }

    pub fn drawCursor(self: *Renderer, x: f32, y: f32, mode: enum { block, line, underline }) void {
        editor_render.drawCursor(self, x, y, mode);
    }

    pub fn drawTerminalCell(
        self: *Renderer,
        codepoint: u32,
        x: f32,
        y: f32,
        cell_width: f32,
        cell_height: f32,
        fg: Color,
        bg: Color,
        underline_color: Color,
        bold: bool,
        underline: bool,
        is_cursor: bool,
        followed_by_space: bool,
        draw_bg: bool,
    ) void {
        const snapped_x = snapToDevicePixel(x, self.render_scale);
        const snapped_y = snapToDevicePixel(y, self.render_scale);
        const snapped_cell_width = snapToDevicePixel(cell_width, self.render_scale);
        const snapped_cell_height = snapToDevicePixel(cell_height, self.render_scale);
        const snapped_cell_w_i = snapInt(snapped_cell_width);
        const snapped_cell_h_i = snapInt(snapped_cell_height);

        if (draw_bg) {
            self.drawRect(
                snapInt(snapped_x),
                snapInt(snapped_y),
                snapped_cell_w_i,
                snapped_cell_h_i,
                if (is_cursor) fg else bg,
            );
        }

        if (codepoint != 0) {
            const text_color = if (is_cursor) bg else fg;
            _ = bold;
            const draw = terminal_font_mod.DrawContext{
                .ctx = self,
                .drawTexture = drawTextureThunk,
            };
            const behind = if (is_cursor) fg else bg;
            var behind_rgba = behind.toRgba();
            behind_rgba.a = 255;
            self.text_bg_rgba = behind_rgba;
            if (!self.drawTerminalBoxGlyph(codepoint, snapped_x, snapped_y, snapped_cell_width, snapped_cell_height, text_color)) {
                self.terminal_font.drawGlyph(
                    draw,
                    codepoint,
                    snapped_x,
                    snapped_y,
                    snapped_cell_width,
                    snapped_cell_height,
                    followed_by_space,
                    text_color.toRgba(),
                );
            }
            if (underline) {
                terminal_underline.drawUnderline(
                    drawRectThunk,
                    self,
                    snapInt(snapped_x),
                    snapInt(snapped_y),
                    snapped_cell_w_i,
                    snapped_cell_h_i,
                    underline_color,
                );
            }
        }
    }

    pub fn drawTerminalCellGrapheme(
        self: *Renderer,
        base: u32,
        combining: []const u32,
        x: f32,
        y: f32,
        cell_width: f32,
        cell_height: f32,
        fg: Color,
        bg: Color,
        underline_color: Color,
        bold: bool,
        underline: bool,
        is_cursor: bool,
        followed_by_space: bool,
        draw_bg: bool,
    ) void {
        if (combining.len == 0) {
            self.drawTerminalCell(base, x, y, cell_width, cell_height, fg, bg, underline_color, bold, underline, is_cursor, followed_by_space, draw_bg);
            return;
        }

        const snapped_x = snapToDevicePixel(x, self.render_scale);
        const snapped_y = snapToDevicePixel(y, self.render_scale);
        const snapped_cell_width = snapToDevicePixel(cell_width, self.render_scale);
        const snapped_cell_height = snapToDevicePixel(cell_height, self.render_scale);
        const snapped_cell_w_i = snapInt(snapped_cell_width);
        const snapped_cell_h_i = snapInt(snapped_cell_height);

        if (draw_bg) {
            self.drawRect(
                snapInt(snapped_x),
                snapInt(snapped_y),
                snapped_cell_w_i,
                snapped_cell_h_i,
                if (is_cursor) fg else bg,
            );
        }

        if (base != 0) {
            const text_color = if (is_cursor) bg else fg;
            const draw = terminal_font_mod.DrawContext{ .ctx = self, .drawTexture = drawTextureThunk };
            const behind = if (is_cursor) fg else bg;
            var behind_rgba = behind.toRgba();
            behind_rgba.a = 255;
            self.text_bg_rgba = behind_rgba;

            // Box glyphs are single-codepoint only.
            if (!self.drawTerminalBoxGlyph(base, snapped_x, snapped_y, snapped_cell_width, snapped_cell_height, text_color)) {
                self.terminal_font.drawGrapheme(
                    draw,
                    base,
                    combining,
                    snapped_x,
                    snapped_y,
                    snapped_cell_width,
                    snapped_cell_height,
                    followed_by_space,
                    text_color.toRgba(),
                );
            }

            if (underline) {
                terminal_underline.drawUnderline(
                    drawRectThunk,
                    self,
                    snapInt(snapped_x),
                    snapInt(snapped_y),
                    snapped_cell_w_i,
                    snapped_cell_h_i,
                    underline_color,
                );
            }
        }
    }

    pub fn drawTerminalCellGraphemeBatched(
        self: *Renderer,
        base: u32,
        combining: []const u32,
        x: f32,
        y: f32,
        cell_width: f32,
        cell_height: f32,
        fg: Color,
        bg: Color,
        underline_color: Color,
        bold: bool,
        underline: bool,
        is_cursor: bool,
        followed_by_space: bool,
        draw_bg: bool,
    ) void {
        if (combining.len == 0) {
            self.drawTerminalCellBatched(base, x, y, cell_width, cell_height, fg, bg, underline_color, bold, underline, is_cursor, followed_by_space, draw_bg);
            return;
        }

        const snapped_x = snapToDevicePixel(x, self.render_scale);
        const snapped_y = snapToDevicePixel(y, self.render_scale);
        const snapped_cell_width = snapToDevicePixel(cell_width, self.render_scale);
        const snapped_cell_height = snapToDevicePixel(cell_height, self.render_scale);
        const snapped_cell_w_i = snapInt(snapped_cell_width);
        const snapped_cell_h_i = snapInt(snapped_cell_height);

        if (draw_bg) {
            self.addTerminalRect(
                snapInt(snapped_x),
                snapInt(snapped_y),
                snapped_cell_w_i,
                snapped_cell_h_i,
                if (is_cursor) fg else bg,
            );
        }

        if (base != 0) {
            const text_color = if (is_cursor) bg else fg;
            const draw = terminal_font_mod.DrawContext{ .ctx = self, .drawTexture = drawTextureGlyphCacheThunk };
            const behind = if (is_cursor) fg else bg;
            var behind_rgba = behind.toRgba();
            behind_rgba.a = 255;
            self.text_bg_rgba = behind_rgba;

            if (!self.drawTerminalBoxGlyphBatched(base, snapped_x, snapped_y, snapped_cell_width, snapped_cell_height, text_color)) {
                self.terminal_font.drawGrapheme(
                    draw,
                    base,
                    combining,
                    snapped_x,
                    snapped_y,
                    snapped_cell_width,
                    snapped_cell_height,
                    followed_by_space,
                    text_color.toRgba(),
                );
            }

            if (underline) {
                terminal_underline.drawUnderline(
                    addTerminalGlyphRectThunk,
                    self,
                    snapInt(snapped_x),
                    snapInt(snapped_y),
                    snapped_cell_w_i,
                    snapped_cell_h_i,
                    underline_color,
                );
            }
        }
    }

    pub fn drawTerminalCellBatched(
        self: *Renderer,
        codepoint: u32,
        x: f32,
        y: f32,
        cell_width: f32,
        cell_height: f32,
        fg: Color,
        bg: Color,
        underline_color: Color,
        bold: bool,
        underline: bool,
        is_cursor: bool,
        followed_by_space: bool,
        draw_bg: bool,
    ) void {
        const snapped_x = snapToDevicePixel(x, self.render_scale);
        const snapped_y = snapToDevicePixel(y, self.render_scale);
        const snapped_cell_width = snapToDevicePixel(cell_width, self.render_scale);
        const snapped_cell_height = snapToDevicePixel(cell_height, self.render_scale);
        const snapped_cell_w_i = snapInt(snapped_cell_width);
        const snapped_cell_h_i = snapInt(snapped_cell_height);

        if (draw_bg) {
            self.addTerminalRect(
                snapInt(snapped_x),
                snapInt(snapped_y),
                snapped_cell_w_i,
                snapped_cell_h_i,
                if (is_cursor) fg else bg,
            );
        }

        if (codepoint != 0) {
            const text_color = if (is_cursor) bg else fg;
            _ = bold;
            if (!self.drawTerminalBoxGlyphBatched(codepoint, snapped_x, snapped_y, snapped_cell_width, snapped_cell_height, text_color)) {
                const draw = terminal_font_mod.DrawContext{
                    .ctx = self,
                    .drawTexture = drawTextureGlyphCacheThunk,
                };
                const behind = if (is_cursor) fg else bg;
                var behind_rgba = behind.toRgba();
                behind_rgba.a = 255;
                self.text_bg_rgba = behind_rgba;
                self.terminal_font.drawGlyph(
                    draw,
                    codepoint,
                    snapped_x,
                    snapped_y,
                    snapped_cell_width,
                    snapped_cell_height,
                    followed_by_space,
                    text_color.toRgba(),
                );
            }
            if (underline) {
                terminal_underline.drawUnderline(
                    addTerminalGlyphRectThunk,
                    self,
                    snapInt(snapped_x),
                    snapInt(snapped_y),
                    snapped_cell_w_i,
                    snapped_cell_h_i,
                    underline_color,
                );
            }
        }
    }

    fn drawTerminalBoxGlyph(
        self: *Renderer,
        codepoint: u32,
        x: f32,
        y: f32,
        w: f32,
        h: f32,
        color: Color,
    ) bool {
        return terminal_glyphs.drawBoxGlyph(drawRectThunk, self, codepoint, x, y, w, h, color);
    }

    fn drawTerminalBoxGlyphBatched(
        self: *Renderer,
        codepoint: u32,
        x: f32,
        y: f32,
        w: f32,
        h: f32,
        color: Color,
    ) bool {
        return terminal_glyphs.drawBoxGlyphBatched(addTerminalGlyphRectThunk, self, codepoint, x, y, w, h, color);
    }

    pub fn getCharPressed(self: *Renderer) ?u32 {
        if (self.char_queue.items.len == 0) return null;
        return self.char_queue.orderedRemove(0).codepoint;
    }

    pub fn getTextPressed(self: *Renderer) ?TextPress {
        if (self.char_queue.items.len == 0) return null;
        return self.char_queue.orderedRemove(0);
    }

    pub const TextComposition = text_composition.TextComposition;

    pub fn getTextComposition(self: *Renderer) TextComposition {
        return text_composition.snapshot(
            self.composing_text.items,
            self.composing_cursor,
            self.composing_selection_len,
            self.composing_active,
        );
    }

    pub fn getKeyPressed(self: *Renderer) ?KeyPress {
        return key_queue.pop(&self.key_queue);
    }

    pub fn isKeyDown(self: *Renderer, key: i32) bool {
        return key_state.isKeyDown(self.key_down[0..], key);
    }

    pub fn isKeyPressed(self: *Renderer, key: i32) bool {
        return key_state.isKeyPressed(self.key_pressed[0..], key);
    }

    pub fn isKeyRepeated(self: *Renderer, key: i32) bool {
        return key_state.isKeyRepeated(self.key_repeated[0..], key);
    }

    pub fn isKeyReleased(self: *Renderer, key: i32) bool {
        return key_state.isKeyReleased(self.key_released[0..], key);
    }

    pub fn getMousePos(self: *Renderer) MousePos {
        const pos = platform_mouse.getScaledPos(.{ .x = self.mouse_scale.x, .y = self.mouse_scale.y });
        return .{ .x = pos.x, .y = pos.y };
    }

    pub fn getMousePosScaled(_: *Renderer, scale: f32) MousePos {
        const pos = platform_mouse.getScaledPosWithFactor(scale);
        return .{ .x = pos.x, .y = pos.y };
    }

    pub fn getMousePosRaw(_: *Renderer) MousePos {
        const pos = platform_mouse.getMousePosRaw();
        return .{ .x = pos.x, .y = pos.y };
    }

    pub fn getDpiScale(self: *Renderer) MousePos {
        return platform_window.getDpiScale(self.window);
    }

    pub fn getScreenSize(self: *Renderer) MousePos {
        return platform_window.getScreenSize(self.window);
    }

    pub fn getMonitorSize(self: *Renderer) MousePos {
        return platform_window.getMonitorSize(self.window);
    }

    pub const WindowMetrics = platform_window.WindowMetrics;

    pub fn refreshWindowMetrics(self: *Renderer, reason: []const u8) WindowMetrics {
        const window_size = platform_window.getWindowSize(self.window);
        const drawable = platform_window.getDrawableSize(self.window);
        self.width = window_size.w;
        self.height = window_size.h;
        self.render_width = drawable.w;
        self.render_height = drawable.h;
        self.updateMouseScale();
        return platform_window.collectWindowMetrics(self.window, reason);
    }

    fn updateMouseScale(self: *Renderer) void {
        const scale = platform_mouse.computeMouseScale(self.window);
        self.mouse_scale = .{ .x = scale.x, .y = scale.y };
    }

    pub fn getRenderSize(self: *Renderer) MousePos {
        const drawable = platform_window.getDrawableSize(self.window);
        return .{ .x = @floatFromInt(drawable.w), .y = @floatFromInt(drawable.h) };
    }

    pub fn isMouseButtonPressed(self: *Renderer, button: i32) bool {
        return mouse_state.isMouseButtonPressed(self.mouse_pressed[0..], button);
    }

    pub fn isMouseButtonDown(self: *Renderer, button: i32) bool {
        return mouse_state.isMouseButtonDown(self.mouse_down[0..], button);
    }

    pub fn isMouseButtonReleased(self: *Renderer, button: i32) bool {
        return mouse_state.isMouseButtonReleased(self.mouse_released[0..], button);
    }

    pub fn getMouseWheelMove(self: *Renderer) f32 {
        _ = self;
        return mouse_wheel_delta;
    }

    fn fontForSize(self: *Renderer, size: f32) ?*TerminalFont {
        return font_manager.fontForSize(self, size);
    }

    const TextOrigin = struct {
        x: f32,
        y: f32,
    };

    fn snapTextOrigin(self: *Renderer, x: f32, y: f32) TextOrigin {
        return .{
            .x = snapToDevicePixel(x, self.render_scale),
            .y = snapToDevicePixel(y, self.render_scale),
        };
    }

    fn drawTextWithFont(self: *Renderer, font: *TerminalFont, cell_w: f32, cell_h: f32, text: []const u8, x: f32, y: f32, color: Color) void {
        const origin = snapTextOrigin(self, x, y);
        text_draw.drawText(
            self.allocator,
            font,
            self,
            drawTextureThunk,
            text,
            origin.x,
            origin.y,
            cell_w,
            cell_h,
            color.toRgba(),
            false,
        );
    }

    fn drawTextWithFontMonospace(self: *Renderer, font: *TerminalFont, cell_w: f32, cell_h: f32, text: []const u8, x: f32, y: f32, color: Color, disable_programming_ligatures: bool) void {
        const origin = snapTextOrigin(self, x, y);
        if (self.drawTextWithFontMonospaceShaped(font, cell_w, cell_h, text, origin.x, origin.y, color.toRgba(), disable_programming_ligatures)) {
            return;
        }
        text_draw.drawText(self.allocator, font, self, drawTextureThunk, text, origin.x, origin.y, cell_w, cell_h, color.toRgba(), true);
    }

    fn drawTextWithFontMonospaceShaped(self: *Renderer, font: *TerminalFont, cell_w: f32, cell_h: f32, text: []const u8, x: f32, y: f32, color: types.Rgba, disable_programming_ligatures: bool) bool {
        if (text.len == 0) return true;

        if (!textLikelyNeedsShaping(text)) {
            var fast_features_buf: [16]hb.hb_feature_t = undefined;
            const fast_features_len = self.collectShapeFeatures(.editor, disable_programming_ligatures, fast_features_buf[0..]);
            if (fast_features_len == 0) return false;
        }

        var codepoints = std.ArrayList(u32).empty;
        defer codepoints.deinit(self.allocator);
        var idx: usize = 0;
        while (idx < text.len) {
            const first = text[idx];
            const seq_len = std.unicode.utf8ByteSequenceLength(first) catch {
                idx += 1;
                codepoints.append(self.allocator, 0xFFFD) catch return false;
                continue;
            };
            if (idx + seq_len > text.len) {
                idx += 1;
                codepoints.append(self.allocator, 0xFFFD) catch return false;
                continue;
            }
            const slice = text[idx .. idx + seq_len];
            const cp = std.unicode.utf8Decode(slice) catch 0xFFFD;
            codepoints.append(self.allocator, cp) catch return false;
            idx += seq_len;
        }
        if (codepoints.items.len == 0) return true;

        var span_start: usize = 0;
        while (span_start < codepoints.items.len) {
            const start_choice = font.pickFontForCodepoint(codepoints.items[span_start]);
            const span_hb_font = start_choice.hb_font;
            var span_end = span_start + 1;
            while (span_end < codepoints.items.len) : (span_end += 1) {
                const choice = font.pickFontForCodepoint(codepoints.items[span_end]);
                if (choice.hb_font != span_hb_font) break;
            }

            const buffer = hb.hb_buffer_create();
            defer hb.hb_buffer_destroy(buffer);

            var cp_i = span_start;
            while (cp_i < span_end) : (cp_i += 1) {
                const cp = if (codepoints.items[cp_i] == 0) @as(u32, ' ') else codepoints.items[cp_i];
                hb.hb_buffer_add(buffer, cp, @intCast(cp_i - span_start));
            }
            hb.hb_buffer_guess_segment_properties(buffer);
            var shape_features_buf: [16]hb.hb_feature_t = undefined;
            const shape_features_len = self.collectShapeFeatures(.editor, disable_programming_ligatures, shape_features_buf[0..]);
            hb.hb_shape(
                span_hb_font,
                buffer,
                if (shape_features_len > 0) shape_features_buf[0..].ptr else null,
                @intCast(shape_features_len),
            );

            var length: c_uint = 0;
            const infos = hb.hb_buffer_get_glyph_infos(buffer, &length);
            const positions = hb.hb_buffer_get_glyph_positions(buffer, &length);
            if (length == 0) {
                var fallback_x = x + @as(f32, @floatFromInt(span_start)) * cell_w;
                var j = span_start;
                while (j < span_end) : (j += 1) {
                    const cp = codepoints.items[j];
                    font.drawGlyph(.{ .ctx = self, .drawTexture = drawTextureThunk }, cp, fallback_x, y, cell_w, cell_h, false, color);
                    fallback_x += cell_w;
                }
                span_start = span_end;
                continue;
            }

            const span_len = span_end - span_start;
            self.terminal_shape_first_pen_set.items.len = 0;
            self.terminal_shape_first_pen.items.len = 0;
            self.terminal_shape_first_pen_set.ensureTotalCapacity(self.allocator, span_len) catch return false;
            self.terminal_shape_first_pen.ensureTotalCapacity(self.allocator, span_len) catch return false;
            self.terminal_shape_first_pen_set.items.len = span_len;
            self.terminal_shape_first_pen.items.len = span_len;
            @memset(self.terminal_shape_first_pen_set.items, false);
            @memset(self.terminal_shape_first_pen.items, 0);

            const glyph_len: usize = @intCast(length);
            const render_scale = if (font.render_scale > 0.0) font.render_scale else 1.0;
            const inv_scale = 1.0 / render_scale;
            var pen_x: f32 = 0;
            var gi: usize = 0;
            while (gi < glyph_len) : (gi += 1) {
                const cluster_u32 = infos[gi].cluster;
                const pen_before = pen_x;
                pen_x += (@as(f32, @floatFromInt(positions[gi].x_advance)) / 64.0) * inv_scale;
                if (cluster_u32 >= span_len) continue;
                const cluster: usize = @intCast(cluster_u32);

                if (!self.terminal_shape_first_pen_set.items[cluster]) {
                    self.terminal_shape_first_pen_set.items[cluster] = true;
                    self.terminal_shape_first_pen.items[cluster] = pen_before;
                }
                const pen_rel = pen_before - self.terminal_shape_first_pen.items[cluster];

                const glyph = font.getGlyphById(start_choice.face, infos[gi].codepoint, start_choice.want_color, positions[gi].x_advance) catch continue;
                const cell_x = x + @as(f32, @floatFromInt(span_start + cluster)) * cell_w;
                const baseline = y + font.baseline_from_top * inv_scale;
                const gx_off = (@as(f32, @floatFromInt(positions[gi].x_offset)) / 64.0) * inv_scale;
                const gy_off = (@as(f32, @floatFromInt(positions[gi].y_offset)) / 64.0) * inv_scale;
                const draw_x = cell_x + pen_rel + gx_off + @as(f32, @floatFromInt(glyph.bearing_x)) * inv_scale;
                const draw_y = (baseline - @as(f32, @floatFromInt(glyph.bearing_y)) * inv_scale) - gy_off;

                const dest: types.Rect = .{
                    .x = snapToDevicePixel(draw_x, render_scale),
                    .y = snapToDevicePixel(draw_y, render_scale),
                    .width = @as(f32, @floatFromInt(glyph.width)) * inv_scale,
                    .height = @as(f32, @floatFromInt(glyph.height)) * inv_scale,
                };
                const draw_color = if (glyph.is_color)
                    types.Rgba{ .r = 255, .g = 255, .b = 255, .a = 255 }
                else
                    color;
                if (glyph.is_color) {
                    drawTextureThunk(self, font.color_texture, glyph.rect, dest, draw_color, .rgba);
                } else {
                    drawTextureThunk(self, font.coverage_texture, glyph.rect, dest, draw_color, .font_coverage);
                }
            }

            span_start = span_end;
        }
        return true;
    }

    fn textLikelyNeedsShaping(text: []const u8) bool {
        // Fast path for common plain ASCII identifiers/words.
        // If text only contains simple alnum/space/underscore chars,
        // skip HarfBuzz shaping when no explicit features are active.
        for (text) |b| {
            if (b >= 0x80) return true;
            const is_alnum = (b >= 'a' and b <= 'z') or (b >= 'A' and b <= 'Z') or (b >= '0' and b <= '9');
            const is_simple = is_alnum or b == ' ' or b == '_' or b == '\t';
            if (!is_simple) return true;
        }
        return false;
    }

    fn measureTextWidth(self: *Renderer, font: *TerminalFont, text: []const u8) f32 {
        const scale = if (self.render_scale > 0.0) self.render_scale else 1.0;
        return text_draw.measureTextWidth(font, text, font.cell_width / scale);
    }

    fn bindDefaultTarget(self: *Renderer) void {
        self.dst_linear_active = false;
        targets.bindDefaultTarget(self);
    }

    fn beginRenderTarget(self: *Renderer, target: ?RenderTarget) bool {
        const ok = targets.beginRenderTarget(self, target);
        if (ok) self.dst_linear_active = true;
        return ok;
    }

    fn ensureRenderTargetScaled(self: *Renderer, target: *?RenderTarget, logical_width: i32, logical_height: i32, filter: i32) bool {
        const scale = if (self.render_scale > 0.0) self.render_scale else 1.0;
        const width = @max(1, @as(i32, @intFromFloat(std.math.round(@as(f32, @floatFromInt(logical_width)) * scale))));
        const height = @max(1, @as(i32, @intFromFloat(std.math.round(@as(f32, @floatFromInt(logical_height)) * scale))));
        return targets.ensureRenderTarget(target, width, height, logical_width, logical_height, filter);
    }

    fn destroyRenderTarget(_: *Renderer, target: *?RenderTarget) void {
        targets.destroyRenderTarget(target);
    }

    fn updateProjection(self: *Renderer, width: i32, height: i32) void {
        targets.updateProjection(self, width, height);
    }

    pub fn beginTerminalBatch(self: *Renderer) void {
        draw_batch.beginTerminalBatch(self);
    }

    pub fn flushTerminalBatch(self: *Renderer) void {
        draw_batch.flushTerminalBatch(self);
    }

    pub fn beginTerminalGlyphBatch(self: *Renderer) void {
        self.terminal_glyph_cache.begin();
    }

    pub fn flushTerminalGlyphBatch(self: *Renderer) void {
        self.terminal_glyph_cache.flush(self);
    }

    fn drawTextureRect(self: *Renderer, texture: types.Texture, src: types.Rect, dest: types.Rect, color: types.Rgba) void {
        draw_ops.drawTextureRect(self, texture, src, dest, color, types.Rgba{ .r = 0, .g = 0, .b = 0, .a = 0 }, .rgba);
    }

    fn drawTextureRectThunk(ctx: *anyopaque, texture: types.Texture, src: types.Rect, dest: types.Rect, color: types.Rgba, kind: types.TextureKind) void {
        const self: *Renderer = @ptrCast(@alignCast(ctx));
        draw_ops.drawTextureRect(self, texture, src, dest, color, self.text_bg_rgba, kind);
    }

    fn drawRectThunk(ctx: *anyopaque, x: i32, y: i32, w: i32, h: i32, color: Color) void {
        const self: *Renderer = @ptrCast(@alignCast(ctx));
        self.drawRect(x, y, w, h, color);
    }

    fn addTerminalRectThunk(ctx: *anyopaque, x: i32, y: i32, w: i32, h: i32, color: Color) void {
        const self: *Renderer = @ptrCast(@alignCast(ctx));
        self.addTerminalRect(x, y, w, h, color);
    }

    fn ensureVboCapacity(self: *Renderer, vertex_count: usize) void {
        draw_ops.ensureVboCapacity(self, vertex_count);
    }

    fn addBatchQuad(self: *Renderer, texture: types.Texture, src: types.Rect, dest: types.Rect, color: types.Rgba) void {
        draw_ops.addBatchQuad(self, texture, src, dest, color, types.Rgba{ .r = 0, .g = 0, .b = 0, .a = 0 }, .rgba);
    }

    pub fn addTerminalRect(self: *Renderer, x: i32, y: i32, w: i32, h: i32, color: Color) void {
        draw_ops.addTerminalRect(self, x, y, w, h, color.toRgba());
    }

    pub fn addTerminalGlyphRect(self: *Renderer, x: i32, y: i32, w: i32, h: i32, color: Color) void {
        self.terminal_glyph_cache.addRect(self.white_texture, x, y, w, h, color.toRgba());
    }

    fn drawTextureBatchThunk(ctx: *anyopaque, texture: types.Texture, src: types.Rect, dest: types.Rect, color: types.Rgba, kind: types.TextureKind) void {
        const renderer: *Renderer = @ptrCast(@alignCast(ctx));
        draw_ops.addBatchQuad(renderer, texture, src, dest, color, renderer.text_bg_rgba, kind);
    }

    fn drawTextureGlyphCacheThunk(ctx: *anyopaque, texture: types.Texture, src: types.Rect, dest: types.Rect, color: types.Rgba, kind: types.TextureKind) void {
        const renderer: *Renderer = @ptrCast(@alignCast(ctx));
        renderer.terminal_glyph_cache.addQuad(texture, src, dest, color, renderer.text_bg_rgba, kind);
    }

    fn addTerminalGlyphRectThunk(ctx: *anyopaque, x: i32, y: i32, w: i32, h: i32, color: Color) void {
        const renderer: *Renderer = @ptrCast(@alignCast(ctx));
        renderer.addTerminalGlyphRect(x, y, w, h, color);
    }

    fn drawTextureThunk(ctx: *anyopaque, texture: types.Texture, src: types.Rect, dest: types.Rect, color: types.Rgba, kind: types.TextureKind) void {
        const renderer: *Renderer = @ptrCast(@alignCast(ctx));
        draw_ops.drawTextureRect(renderer, texture, src, dest, color, renderer.text_bg_rgba, kind);
    }

    pub fn createTextureFromRgba(_: *Renderer, width: i32, height: i32, data: []const u8, filter: i32) ?types.Texture {
        return texture_utils.createTextureFromRgba(width, height, data, filter);
    }

    pub fn createTextureFromRgb(_: *Renderer, width: i32, height: i32, data: []const u8, filter: i32) ?types.Texture {
        return texture_utils.createTextureFromRgb(width, height, data, filter);
    }

    pub fn destroyTexture(_: *Renderer, texture: *types.Texture) void {
        texture_utils.destroyTexture(texture);
    }

    pub fn drawTexture(self: *Renderer, texture: types.Texture, src: types.Rect, dest: types.Rect, color: Color) void {
        self.drawTextureRect(texture, src, dest, color.toRgba());
    }

    fn pollInputEvents(self: *Renderer) void {
        const input_log = app_logger.logger("input.sdl");
        const window_log = app_logger.logger("sdl.window");
        if (!sdl_input_env_logged and (input_log.enabled_file or input_log.enabled_console)) {
            input_log.logf(
                "sdl build_version=sdl3 is_sdl3={d} event_size={d}",
                .{ @intFromBool(sdl_api.is_sdl3), sdl_api.sdlEventSize() },
            );
            sdl_input_env_logged = true;
        }
        const state = input_state.InputState{
            .key_down = self.key_down[0..],
            .key_pressed = self.key_pressed[0..],
            .key_repeated = self.key_repeated[0..],
            .key_released = self.key_released[0..],
            .mouse_down = self.mouse_down[0..],
            .mouse_pressed = self.mouse_pressed[0..],
            .mouse_released = self.mouse_released[0..],
            .key_queue = &self.key_queue,
            .char_queue = &self.char_queue,
            .composing_text = &self.composing_text,
            .composing_cursor = &self.composing_cursor,
            .composing_selection_len = &self.composing_selection_len,
            .composing_active = &self.composing_active,
            .mouse_wheel_delta = &mouse_wheel_delta,
            .window_resized_flag = &self.window_resized_flag,
        };
        input_state.resetForFrame(state);
        mouse_wheel.reset(&mouse_wheel_delta);

        if (sdl_api.is_sdl3) {
            var event: sdl.SDL_Event = undefined;
            var event_count: usize = 0;
            while (sdl_api.pollEvent(&event)) {
                event_count += 1;
                self.handleEvent(&event, input_log, window_log, state);
            }
            if ((input_log.enabled_file or input_log.enabled_console) and event_count > 0) {
                input_log.logf("sdl3 polled events={d}", .{event_count});
            }
            return;
        }

        const events = input_queue.drain(&self.sdl_input);
        for (events) |*event| {
            self.handleEvent(event, input_log, window_log, state);
        }
    }

    fn handleEvent(
        self: *Renderer,
        event: *const sdl.SDL_Event,
        input_log: app_logger.Logger,
        window_log: app_logger.Logger,
        state: input_state.InputState,
    ) void {
        switch (event.type) {
            sdl_api.EVENT_QUIT => {
                self.should_close_flag = true;
            },
            sdl_api.EVENT_WINDOW => {
                const evt = sdl_api.getWindowEventId(event);
                window_flags.handleWindowEvent(event.type, evt, &self.should_close_flag, &self.window_resized_flag);
                if (sdl_api.isFocusGainedEvent(event.type, evt)) {
                    sdl_api.startTextInput(self.window);
                    text_input.reapplyRect(&self.text_input_state, self.window);
                }
                if (sdl_api.isFocusLostEvent(event.type, evt)) {
                    sdl_api.stopTextInput(self.window);
                }
                if (window_log.enabled_file or window_log.enabled_console) {
                    window_log.logf(
                        "event={s} data1={d} data2={d}",
                        .{
                            sdl_api.windowEventName(event.type, evt),
                            sdl_api.windowEventData1(event),
                            sdl_api.windowEventData2(event),
                        },
                    );
                }
            },
            sdl_api.EVENT_KEY_DOWN => {
                const key_info = platform_input_events.handleKeyDown(
                    event,
                    self.key_down[0..],
                    self.key_pressed[0..],
                    self.key_repeated[0..],
                    &self.key_queue,
                    self.allocator,
                );
                if (input_log.enabled_file or input_log.enabled_console) {
                    input_log.logf(
                        "keydown sc={d} sym={d} repeat={d}",
                        .{ key_info.scancode, key_info.sym, key_info.repeat },
                    );
                }
            },
            sdl_api.EVENT_KEY_UP => {
                const key_info = platform_input_events.handleKeyUp(
                    event,
                    self.key_down[0..],
                    self.key_released[0..],
                );
                if (input_log.enabled_file or input_log.enabled_console) {
                    input_log.logf(
                        "keyup sc={d} sym={d}",
                        .{ key_info.scancode, key_info.sym },
                    );
                }
            },
            sdl_api.EVENT_TEXT_INPUT => {
                const text_was_composed = state.composing_active.*;
                const text_len = platform_input_events.handleTextInput(
                    event,
                    &self.char_queue,
                    self.allocator,
                    text_was_composed,
                );
                input_state.applyTextInputReset(state);
                input_logging.logTextInput(text_len);
                if (input_log.enabled_file or input_log.enabled_console) {
                    input_log.logf("textinput type={d}", .{event.type});
                }
                if (sdl_api.is_sdl3 and !sdl3_textinput_layout_logged and (input_log.enabled_file or input_log.enabled_console)) {
                    const layout = sdl_api.textInputLayout();
                    input_logging.logTextInputLayout(
                        layout.size,
                        sdl_api.sdlEventSize(),
                        layout.offset_type,
                        layout.offset_reserved,
                        layout.offset_timestamp,
                        layout.offset_window_id,
                        layout.offset_text,
                    );
                    input_logging.logEventBytes("textinput event", std.mem.asBytes(event));
                    sdl3_textinput_layout_logged = true;
                }
                input_logging.logTextInputPointer(text_len, sdl_api.textInputPointer(event));
                if (text_len > 0) {
                    const text_field = event.text;
                    const text = if (@hasField(@TypeOf(text_field), "text"))
                        sdl_api.textSpanWithLen(text_field.text, text_len)
                    else
                        "";
                    input_logging.logTextInputRaw(text);
                }
            },
            sdl_api.EVENT_TEXT_EDITING => {
                const edit_info = platform_input_events.handleTextEditing(
                    event,
                    &self.composing_text,
                    &self.composing_cursor,
                    &self.composing_selection_len,
                    &self.composing_active,
                    self.allocator,
                );
                input_logging.logTextEditing(edit_info.bytes, edit_info.cursor, edit_info.selection_len);
                if (sdl_api.is_sdl3 and !sdl3_textediting_layout_logged and (input_log.enabled_file or input_log.enabled_console)) {
                    const layout = sdl_api.textEditingLayout();
                    input_logging.logTextEditingLayout(
                        layout.size,
                        sdl_api.sdlEventSize(),
                        layout.offset_type,
                        layout.offset_reserved,
                        layout.offset_timestamp,
                        layout.offset_window_id,
                        layout.offset_text,
                        layout.offset_start,
                        layout.offset_length,
                        layout.offset_cursor,
                        layout.offset_selection_len,
                    );
                    input_logging.logEventBytes("textedit event", std.mem.asBytes(event));
                    sdl3_textediting_layout_logged = true;
                }
                input_logging.logTextEditingPointer(
                    edit_info.bytes,
                    edit_info.cursor,
                    edit_info.selection_len,
                    sdl_api.textEditingPointer(event),
                );
                if (edit_info.bytes > 0) {
                    const edit_field = event.edit;
                    const text = if (@hasField(@TypeOf(edit_field), "text"))
                        sdl_api.textSpanWithLen(edit_field.text, edit_info.bytes)
                    else
                        "";
                    input_logging.logTextEditingRaw(text, edit_info.cursor, edit_info.selection_len);
                }
            },
            sdl_api.EVENT_MOUSE_BUTTON_DOWN => {
                platform_input_events.handleMouseButtonDown(
                    event,
                    self.mouse_down[0..],
                    self.mouse_pressed[0..],
                );
            },
            sdl_api.EVENT_MOUSE_BUTTON_UP => {
                platform_input_events.handleMouseButtonUp(
                    event,
                    self.mouse_down[0..],
                    self.mouse_released[0..],
                );
            },
            sdl_api.EVENT_MOUSE_WHEEL => {
                mouse_wheel.add(&mouse_wheel_delta, platform_input_events.wheelDelta(event));
            },
            else => {
                if (sdl_api.isWindowEventType(event.type)) {
                    const evt = sdl_api.getWindowEventId(event);
                    window_flags.handleWindowEvent(event.type, evt, &self.should_close_flag, &self.window_resized_flag);
                    if (sdl_api.isFocusGainedEvent(event.type, evt)) {
                        sdl_api.startTextInput(self.window);
                        text_input.reapplyRect(&self.text_input_state, self.window);
                    }
                    if (sdl_api.isFocusLostEvent(event.type, evt)) {
                        sdl_api.stopTextInput(self.window);
                    }
                    if (window_log.enabled_file or window_log.enabled_console) {
                        window_log.logf(
                            "event={s} data1={d} data2={d}",
                            .{
                                sdl_api.windowEventName(event.type, evt),
                                sdl_api.windowEventData1(event),
                                sdl_api.windowEventData2(event),
                            },
                        );
                    }
                }
            },
        }
    }
};

pub fn pollInputEvents() void {
    if (active_renderer) |renderer| {
        renderer.pollInputEvents();
    }
}

pub fn waitTime(seconds: f64) void {
    if (active_renderer) |renderer| {
        _ = renderer;
        time_utils.waitTime(seconds);
    } else {
        time_utils.waitTime(seconds);
    }
}

pub fn getTime() f64 {
    if (active_renderer) |renderer| {
        return time_utils.getTime(renderer.start_counter, renderer.perf_freq);
    }
    return time_utils.getTime(null, null);
}

pub fn setSdlLogLevel(level: c_int) void {
    sdl_api.logSetAllPriority(@intCast(level));
}

pub fn isWindowResized() bool {
    if (active_renderer) |renderer| {
        return renderer.window_resized_flag;
    }
    return false;
}

pub fn getScreenWidth() i32 {
    if (active_renderer) |renderer| return renderer.width;
    return 0;
}

pub fn getScreenHeight() i32 {
    if (active_renderer) |renderer| return renderer.height;
    return 0;
}
