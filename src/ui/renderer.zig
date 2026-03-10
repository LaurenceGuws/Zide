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
const scale_utils = @import("renderer/scale_utils.zig");
const targets = @import("renderer/targets.zig");
const text_draw = @import("renderer/text_draw.zig");
const gl_resources = @import("renderer/gl_resources.zig");
const draw_batch = @import("renderer/draw_batch.zig");
const target_draw = @import("renderer/target_draw.zig");
const shape_utils = @import("renderer/shape_utils.zig");
const shape_draw = @import("renderer/shape_draw.zig");
const terminal_glyphs = @import("renderer/terminal_glyphs.zig");
const clipboard_state = @import("renderer/clipboard_state.zig");
const terminal_underline = @import("renderer/terminal_underline.zig");
const texture_draw = @import("renderer/texture_draw.zig");
const window_flags = @import("renderer/window_flags.zig");
const input_logging = @import("renderer/input_logging.zig");
const window_metrics_state = @import("renderer/window_metrics_state.zig");
const screenshot = @import("renderer/screenshot.zig");
const input_runtime = @import("renderer/input_runtime.zig");
const font_runtime = @import("renderer/font_runtime.zig");
const text_runtime = @import("renderer/text_runtime.zig");
const glyph_cache = @import("glyph_cache.zig");
const platform_window = @import("../platform/window.zig");
const platform_input_events = @import("../platform/input_events.zig");
const platform_mouse = @import("../platform/mouse_state.zig");
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
    pub const SelectionOverlayStyle = struct {
        smooth_enabled: bool = true,
        corner_px: ?f32 = null,
        pad_px: ?f32 = null,
    };

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
    editor_selection_overlay_style: SelectionOverlayStyle,
    terminal_selection_overlay_style: SelectionOverlayStyle,
    terminal_texture_shift_enabled: bool,

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
    mouse_clicks: [mouse_button_count]u8,
    mouse_press_pos: [mouse_button_count]MousePos,
    mouse_press_pos_valid: [mouse_button_count]bool,
    key_queue: std.ArrayList(KeyPress),
    key_queue_head: usize,
    char_queue: std.ArrayList(TextPress),
    char_queue_head: usize,
    focus_queue: std.ArrayList(bool),
    focus_queue_head: usize,
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
            .editor_selection_overlay_style = .{},
            .terminal_selection_overlay_style = .{},
            .terminal_texture_shift_enabled = true,
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
            .mouse_clicks = [_]u8{0} ** mouse_button_count,
            .mouse_press_pos = [_]MousePos{.{ .x = 0, .y = 0 }} ** mouse_button_count,
            .mouse_press_pos_valid = [_]bool{false} ** mouse_button_count,
            .key_queue = std.ArrayList(KeyPress).empty,
            .key_queue_head = 0,
            .char_queue = std.ArrayList(TextPress).empty,
            .char_queue_head = 0,
            .focus_queue = std.ArrayList(bool).empty,
            .focus_queue_head = 0,
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

        // Mouse position is sampled directly each frame via SDL_GetMouseState;
        // we do not consume SDL mouse-motion events.
        sdl_api.setEventEnabled(sdl_api.EVENT_MOUSE_MOTION, false);

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
        self.focus_queue.deinit(self.allocator);
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
        font_runtime.setFontRenderingOptions(self, opts);
    }

    pub fn setTextRenderingConfig(self: *Renderer, gamma: ?f32, contrast: ?f32, linear_correction: ?bool) void {
        font_runtime.setTextRenderingConfig(self, gamma, contrast, linear_correction);
    }

    pub fn setEditorSelectionOverlayStyle(self: *Renderer, smooth_enabled: ?bool, corner_px: ?f32, pad_px: ?f32) void {
        if (smooth_enabled) |v| self.editor_selection_overlay_style.smooth_enabled = v;
        if (corner_px) |v| {
            if (v > 0) self.editor_selection_overlay_style.corner_px = v;
        }
        if (pad_px) |v| {
            if (v > 0) self.editor_selection_overlay_style.pad_px = v;
        }
    }

    pub fn setTerminalSelectionOverlayStyle(self: *Renderer, smooth_enabled: ?bool, corner_px: ?f32, pad_px: ?f32) void {
        if (smooth_enabled) |v| self.terminal_selection_overlay_style.smooth_enabled = v;
        if (corner_px) |v| {
            if (v > 0) self.terminal_selection_overlay_style.corner_px = v;
        }
        if (pad_px) |v| {
            if (v > 0) self.terminal_selection_overlay_style.pad_px = v;
        }
    }

    pub fn editorSelectionOverlayStyle(self: *const Renderer) SelectionOverlayStyle {
        return self.editor_selection_overlay_style;
    }

    pub fn terminalSelectionOverlayStyle(self: *const Renderer) SelectionOverlayStyle {
        return self.terminal_selection_overlay_style;
    }

    pub fn setTerminalTextureShiftEnabled(self: *Renderer, enabled: bool) void {
        self.terminal_texture_shift_enabled = enabled;
    }

    pub fn terminalTextureShiftEnabled(self: *const Renderer) bool {
        return self.terminal_texture_shift_enabled;
    }

    pub fn setTerminalLigatureConfig(self: *Renderer, strategy: ?TerminalDisableLigaturesStrategy, features_raw: ?[]const u8) void {
        font_runtime.setTerminalLigatureConfig(self, strategy, features_raw);
    }

    pub fn setEditorLigatureConfig(self: *Renderer, strategy: ?TerminalDisableLigaturesStrategy, features_raw: ?[]const u8) void {
        font_runtime.setEditorLigatureConfig(self, strategy, features_raw);
    }

    pub fn collectShapeFeatures(self: *Renderer, domain: ShapeFeatureDomain, disable_programming_ligatures: bool, out: []hb.hb_feature_t) usize {
        return font_runtime.collectShapeFeatures(self, domain, disable_programming_ligatures, out);
    }

    pub fn loadFontWithGlyphs(self: *Renderer, allocator: std.mem.Allocator, path: [*:0]const u8, size: f32) void {
        _ = allocator;
        self.loadFont(path, size);
    }

    fn queryUiScale(self: *Renderer) f32 {
        return font_runtime.queryUiScale(self);
    }

    fn applyFontScale(self: *Renderer) !void {
        try font_runtime.applyFontScale(self);
    }

    pub fn queueUserZoom(self: *Renderer, delta: f32, now: f64) bool {
        return font_runtime.queueUserZoom(self, delta, now);
    }

    pub fn resetUserZoomTarget(self: *Renderer, now: f64) bool {
        return font_runtime.resetUserZoomTarget(self, now);
    }

    pub fn refreshUiScale(self: *Renderer) !bool {
        return font_runtime.refreshUiScale(self);
    }

    pub fn applyPendingZoom(self: *Renderer, now: f64) !bool {
        return font_runtime.applyPendingZoom(self, now);
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
            const snapped_x = snapToDevicePixel(x, self.render_scale);
            const snapped_y = snapToDevicePixel(y, self.render_scale);
            const src = texture_draw.fullTextureSrcRect(target.texture);
            const dest = types.Rect{
                .x = snapped_x,
                .y = snapped_y,
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
            const snapped_x = snapToDevicePixel(x, self.render_scale);
            const snapped_y = snapToDevicePixel(y, self.render_scale);
            const src = texture_draw.fullTextureSrcRect(target.texture);
            const dest = types.Rect{
                .x = snapped_x,
                .y = snapped_y,
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

    pub fn getClipboardMimeData(self: *Renderer, allocator: std.mem.Allocator, mime_type: [*:0]const u8) ?[]u8 {
        _ = self;
        return clipboard_state.getData(allocator, mime_type);
    }

    pub fn drawText(self: *Renderer, text: []const u8, x: f32, y: f32, color: Color) void {
        text_runtime.drawText(self, text, x, y, color);
    }

    pub fn drawTextMonospace(self: *Renderer, text: []const u8, x: f32, y: f32, color: Color) void {
        text_runtime.drawTextMonospace(self, text, x, y, color);
    }

    pub fn drawTextMonospacePolicy(self: *Renderer, text: []const u8, x: f32, y: f32, color: Color, disable_programming_ligatures: bool) void {
        text_runtime.drawTextMonospacePolicy(self, text, x, y, color, disable_programming_ligatures);
    }

    pub fn drawTextMonospaceOnBg(self: *Renderer, text: []const u8, x: f32, y: f32, color: Color, bg: Color) void {
        text_runtime.drawTextMonospaceOnBg(self, text, x, y, color, bg);
    }

    pub fn drawTextMonospaceOnBgPolicy(self: *Renderer, text: []const u8, x: f32, y: f32, color: Color, bg: Color, disable_programming_ligatures: bool) void {
        text_runtime.drawTextMonospaceOnBgPolicy(self, text, x, y, color, bg, disable_programming_ligatures);
    }

    pub fn drawTextOnBg(self: *Renderer, text: []const u8, x: f32, y: f32, color: Color, bg: Color) void {
        text_runtime.drawTextOnBg(self, text, x, y, color, bg);
    }

    pub fn drawTextSized(self: *Renderer, text: []const u8, x: f32, y: f32, size: f32, color: Color) void {
        text_runtime.drawTextSized(self, text, x, y, size, color);
    }

    pub fn drawIconText(self: *Renderer, text: []const u8, x: f32, y: f32, color: Color) void {
        text_runtime.drawIconText(self, text, x, y, color);
    }

    pub fn measureIconTextWidth(self: *Renderer, text: []const u8) f32 {
        return text_runtime.measureIconTextWidth(self, text);
    }

    pub fn drawChar(self: *Renderer, char: u8, x: f32, y: f32, color: Color) void {
        text_runtime.drawChar(self, char, x, y, color);
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
        text_runtime.drawTerminalCell(self, codepoint, x, y, cell_width, cell_height, fg, bg, underline_color, bold, underline, is_cursor, followed_by_space, draw_bg);
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
        text_runtime.drawTerminalCellGrapheme(self, base, combining, x, y, cell_width, cell_height, fg, bg, underline_color, bold, underline, is_cursor, followed_by_space, draw_bg);
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
        text_runtime.drawTerminalCellGraphemeBatched(self, base, combining, x, y, cell_width, cell_height, fg, bg, underline_color, bold, underline, is_cursor, followed_by_space, draw_bg);
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
        text_runtime.drawTerminalCellBatched(self, codepoint, x, y, cell_width, cell_height, fg, bg, underline_color, bold, underline, is_cursor, followed_by_space, draw_bg);
    }

    pub fn getCharPressed(self: *Renderer) ?u32 {
        if (self.char_queue_head >= self.char_queue.items.len) return null;
        const value = self.char_queue.items[self.char_queue_head];
        self.char_queue_head += 1;
        return value.codepoint;
    }

    pub fn getTextPressed(self: *Renderer) ?TextPress {
        if (self.char_queue_head >= self.char_queue.items.len) return null;
        const value = self.char_queue.items[self.char_queue_head];
        self.char_queue_head += 1;
        return value;
    }

    pub fn getFocusEvent(self: *Renderer) ?bool {
        if (self.focus_queue_head >= self.focus_queue.items.len) return null;
        const value = self.focus_queue.items[self.focus_queue_head];
        self.focus_queue_head += 1;
        return value;
    }

    pub const TextComposition = input_state.TextComposition;

    pub fn getTextComposition(self: *Renderer) TextComposition {
        return input_state.snapshotTextComposition(
            self.composing_text.items,
            self.composing_cursor,
            self.composing_selection_len,
            self.composing_active,
        );
    }

    pub fn getKeyPressed(self: *Renderer) ?KeyPress {
        return input_state.popKeyPress(&self.key_queue, &self.key_queue_head);
    }

    pub fn keycodeFromScancode(_: *Renderer, scancode: i32, shift: bool) i32 {
        return sdl_api.keycodeFromScancode(scancode, shift);
    }

    pub fn keycodeFromScancodeMods(_: *Renderer, scancode: i32, shift: bool, alt: bool, ctrl: bool, super: bool) i32 {
        return sdl_api.keycodeFromScancodeMods(scancode, shift, alt, ctrl, super);
    }

    pub fn keycodeToCodepoint(_: *Renderer, keycode: i32) ?u32 {
        return sdl_api.keycodeToCodepoint(keycode);
    }

    pub fn isKeyDown(self: *Renderer, key: i32) bool {
        return input_state.isKeyActive(self.key_down[0..], key);
    }

    pub fn isKeyPressed(self: *Renderer, key: i32) bool {
        return input_state.isKeyActive(self.key_pressed[0..], key);
    }

    pub fn isKeyRepeated(self: *Renderer, key: i32) bool {
        return input_state.isKeyActive(self.key_repeated[0..], key);
    }

    pub fn isKeyReleased(self: *Renderer, key: i32) bool {
        return input_state.isKeyActive(self.key_released[0..], key);
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
        return input_state.isMouseButtonActive(self.mouse_pressed[0..], button);
    }

    pub fn isMouseButtonDown(self: *Renderer, button: i32) bool {
        return input_state.isMouseButtonActive(self.mouse_down[0..], button);
    }

    pub fn isMouseButtonReleased(self: *Renderer, button: i32) bool {
        return input_state.isMouseButtonActive(self.mouse_released[0..], button);
    }

    pub fn mouseButtonClicks(self: *Renderer, button: i32) u8 {
        if (button < 0) return 0;
        const idx: usize = @intCast(button);
        if (idx >= self.mouse_clicks.len) return 0;
        return self.mouse_clicks[idx];
    }

    pub fn mouseButtonPressPos(self: *Renderer, button: i32) ?MousePos {
        if (button < 0) return null;
        const idx: usize = @intCast(button);
        if (idx >= self.mouse_press_pos_valid.len) return null;
        if (!self.mouse_press_pos_valid[idx]) return null;
        return self.mouse_press_pos[idx];
    }

    pub fn anyMouseButtonsDown(self: *Renderer) bool {
        for (self.mouse_down) |down| {
            if (down) return true;
        }
        return false;
    }

    pub fn getMouseWheelMove(self: *Renderer) f32 {
        _ = self;
        return mouse_wheel_delta;
    }

    fn fontForSize(self: *Renderer, size: f32) ?*TerminalFont {
        return font_runtime.fontForSize(self, size);
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
        input_runtime.pollInputEvents(
            self,
            &mouse_wheel_delta,
            &sdl_input_env_logged,
            &sdl3_textinput_layout_logged,
            &sdl3_textediting_layout_logged,
        );
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
