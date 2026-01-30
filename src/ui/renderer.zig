const std = @import("std");
const compositor = @import("../platform/compositor.zig");
const editor_render = @import("../editor/render/renderer_ops.zig");
const iface = @import("renderer/interface.zig");
const terminal_font_mod = @import("terminal_font.zig");
const TerminalFont = terminal_font_mod.TerminalFont;
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
const platform_window = @import("../platform/window.zig");
const platform_input_events = @import("../platform/input_events.zig");
const platform_mouse = @import("../platform/mouse_state.zig");
const platform_window_events = @import("../platform/window_events.zig");
const build_options = @import("build_options");
const gl = @import("renderer/gl.zig");
const sdl_input = @import("renderer/sdl_input.zig");
const types = @import("renderer/types.zig");
const app_logger = @import("../app_logger.zig");

const sdl = gl.c;

var active_renderer: ?*Renderer = null;
var mouse_wheel_delta: f32 = 0.0;

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
    wgl,
    egl,
};

pub const renderer_backend: RendererBackend = parseRendererBackend(build_options.renderer_backend);

fn parseRendererBackend(raw: []const u8) RendererBackend {
    if (std.mem.eql(u8, raw, "wgl")) return .wgl;
    if (std.mem.eql(u8, raw, "egl")) return .egl;
    return .sdl_gl;
}

const key_repeat_key_count: usize = @intCast(sdl.SDL_NUM_SCANCODES);
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

    shader_program: gl.GLuint,
    vao: gl.GLuint,
    vbo: gl.GLuint,
    vbo_capacity_vertices: usize,
    uniform_proj: gl.GLint,
    uniform_tex: gl.GLint,
    white_texture: types.Texture,

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
    font_cache: std.AutoHashMap(u32, *TerminalFont),
    font_path: [*:0]const u8,
    font_path_owned: ?[]u8,

    terminal_target: ?RenderTarget,
    editor_target: ?RenderTarget,

    theme: Theme,
    mouse_scale: MousePos,
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
    char_queue: std.ArrayList(u32),
    composing_text: std.ArrayList(u8),
    composing_cursor: i32,
    composing_selection_len: i32,
    composing_active: bool,
    sdl_input: sdl_input.SdlInput,
    clipboard_buffer: std.ArrayList(u8),
    batch_vertices: std.ArrayList(Vertex),
    batch_draws: std.ArrayList(BatchDraw),
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

    pub fn init(allocator: std.mem.Allocator, width: i32, height: i32, title: [*:0]const u8) !*Renderer {
        try window_init.initSdl();
        errdefer sdl.SDL_Quit();

        window_init.configureGlAttributes();

        const window = try window_init.createWindow(width, height, title);
        errdefer sdl.SDL_DestroyWindow(window);

        const gl_context = try window_init.createGlContext(window);
        errdefer sdl.SDL_GL_DeleteContext(gl_context);

        try gl.load();

        var renderer = try allocator.create(Renderer);
        errdefer allocator.destroy(renderer);

        const drawable = platform_window.getDrawableSize(window);
        const window_size = platform_window.getWindowSize(window);

        const base_font_size: f32 = 16.0;
        const ui_scale: f32 = 1.0;
        const font_size = base_font_size * ui_scale;

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
            .shader_program = 0,
            .vao = 0,
            .vbo = 0,
            .vbo_capacity_vertices = 0,
            .uniform_proj = -1,
            .uniform_tex = -1,
            .white_texture = .{ .id = 0, .width = 0, .height = 0 },
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
            .font_cache = std.AutoHashMap(u32, *TerminalFont).init(allocator),
            .font_path = FONT_PATH,
            .font_path_owned = null,
            .terminal_target = null,
            .editor_target = null,
            .theme = .{},
            .mouse_scale = .{ .x = 1.0, .y = 1.0 },
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
            .char_queue = std.ArrayList(u32).empty,
            .composing_text = std.ArrayList(u8).empty,
            .composing_cursor = 0,
            .composing_selection_len = 0,
            .composing_active = false,
            .sdl_input = .{},
            .clipboard_buffer = std.ArrayList(u8).empty,
            .batch_vertices = std.ArrayList(Vertex).empty,
            .batch_draws = std.ArrayList(BatchDraw).empty,
            .should_close_flag = false,
            .window_resized_flag = false,
            .text_input_state = text_input.initState(),
            .start_counter = sdl.SDL_GetPerformanceCounter(),
            .perf_freq = @as(f64, @floatFromInt(sdl.SDL_GetPerformanceFrequency())),
        };

        try renderer.initGlResources();
        try renderer.initFonts(font_size);

        sdl.SDL_StartTextInput();
        try renderer.initInputThread();

        active_renderer = renderer;
        return renderer;
    }

    fn initInputThread(self: *Renderer) !void {
        try self.sdl_input.init(self.allocator, input_queue_capacity);
        errdefer self.sdl_input.deinit(self.allocator);
        try self.sdl_input.startThread();
    }

    pub fn deinit(self: *Renderer) void {
        self.shutdownInputThread();
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

        if (self.white_texture.id != 0) {
            gl.DeleteTextures(1, &self.white_texture.id);
        }
        if (self.vbo != 0) {
            gl.DeleteBuffers(1, &self.vbo);
        }
        if (self.vao != 0) {
            gl.DeleteVertexArrays(1, &self.vao);
        }
        if (self.shader_program != 0) {
            gl.DeleteProgram(self.shader_program);
        }

        sdl.SDL_StopTextInput();
        sdl.SDL_GL_DeleteContext(self.gl_context);
        sdl.SDL_DestroyWindow(self.window);
        sdl.SDL_Quit();

        if (active_renderer == self) active_renderer = null;
        self.allocator.destroy(self);
    }

    fn shutdownInputThread(self: *Renderer) void {
        self.sdl_input.stopThread();
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
        if (std.math.approxEqAbs(f32, next, self.ui_scale, 0.0001)) return false;
        self.ui_scale = next;
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
        try self.applyFontScale();
        self.last_zoom_apply_time = result.apply_time;
        return true;
    }

    pub fn uiScaleFactor(self: *const Renderer) f32 {
        return self.ui_scale * self.user_zoom;
    }

    pub fn shouldClose(self: *Renderer) bool {
        return self.should_close_flag;
    }

    pub fn beginFrame(self: *Renderer) void {
        const window_size = platform_window.getWindowSize(self.window);
        const drawable = platform_window.getDrawableSize(self.window);
        self.width = window_size.w;
        self.height = window_size.h;
        self.render_width = drawable.w;
        self.render_height = drawable.h;

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
        sdl.SDL_GL_SwapWindow(self.window);
    }

    pub fn setTextInputRect(self: *Renderer, x: i32, y: i32, w: i32, h: i32) void {
        text_input.setRect(&self.text_input_state, x, y, w, h);
    }

    pub fn ensureTerminalTexture(self: *Renderer, width: i32, height: i32) bool {
        return self.ensureRenderTarget(&self.terminal_target, width, height, gl.c.GL_NEAREST);
    }

    pub fn ensureEditorTexture(self: *Renderer, width: i32, height: i32) bool {
        return self.ensureRenderTarget(&self.editor_target, width, height, gl.c.GL_NEAREST);
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
            const src = types.Rect{
                .x = 0,
                .y = @floatFromInt(target.texture.height),
                .width = @floatFromInt(target.texture.width),
                .height = -@as(f32, @floatFromInt(target.texture.height)),
            };
            const dest = types.Rect{
                .x = x,
                .y = y,
                .width = @floatFromInt(target.texture.width),
                .height = @floatFromInt(target.texture.height),
            };
            self.drawTextureRect(target.texture, src, dest, Color.white.toRgba());
        }
    }

    pub fn drawEditorTexture(self: *Renderer, x: f32, y: f32) void {
        if (self.editor_target) |target| {
            const src = types.Rect{
                .x = 0,
                .y = @floatFromInt(target.texture.height),
                .width = @floatFromInt(target.texture.width),
                .height = -@as(f32, @floatFromInt(target.texture.height)),
            };
            const dest = types.Rect{
                .x = x,
                .y = y,
                .width = @floatFromInt(target.texture.width),
                .height = @floatFromInt(target.texture.height),
            };
            self.drawTextureRect(target.texture, src, dest, Color.white.toRgba());
        }
    }

    pub fn drawRect(self: *Renderer, x: i32, y: i32, w: i32, h: i32, color: Color) void {
        if (w <= 0 or h <= 0) return;
        const dest = types.Rect{
            .x = @floatFromInt(x),
            .y = @floatFromInt(y),
            .width = @floatFromInt(w),
            .height = @floatFromInt(h),
        };
        const src = types.Rect{ .x = 0, .y = 0, .width = 1, .height = 1 };
        self.drawTextureRect(self.white_texture, src, dest, color.toRgba());
    }

    pub fn drawRectOutline(self: *Renderer, x: i32, y: i32, w: i32, h: i32, color: Color) void {
        const thick: i32 = 1;
        self.drawRect(x, y, w, thick, color);
        self.drawRect(x, y + h - thick, w, thick, color);
        self.drawRect(x, y, thick, h, color);
        self.drawRect(x + w - thick, y, thick, h, color);
    }

    pub fn setClipboardText(_: *Renderer, text: [*:0]const u8) void {
        clipboard.setText(text);
    }

    pub fn getClipboardText(self: *Renderer) ?[]const u8 {
        const slice = clipboard.getText() orelse return null;
        if (slice.len == 0) {
            clipboard.freeText(slice);
            return null;
        }
        self.clipboard_buffer.clearRetainingCapacity();
        _ = self.clipboard_buffer.appendSlice(self.allocator, slice) catch {
            clipboard.freeText(slice);
            return null;
        };
        clipboard.freeText(slice);
        return self.clipboard_buffer.items;
    }

    pub fn drawText(self: *Renderer, text: []const u8, x: f32, y: f32, color: Color) void {
        self.drawTextWithFont(&self.terminal_font, self.terminal_font.cell_width, self.terminal_font.line_height, text, x, y, color);
    }

    pub fn drawTextMonospace(self: *Renderer, text: []const u8, x: f32, y: f32, color: Color) void {
        self.drawTextWithFontMonospace(&self.terminal_font, self.terminal_font.cell_width, self.terminal_font.line_height, text, x, y, color);
    }

    pub fn drawTextSized(self: *Renderer, text: []const u8, x: f32, y: f32, size: f32, color: Color) void {
        const font = self.fontForSize(size) orelse {
            self.drawText(text, x, y, color);
            return;
        };
        self.drawTextWithFont(font, font.cell_width, font.line_height, text, x, y, color);
    }

    pub fn drawIconText(self: *Renderer, text: []const u8, x: f32, y: f32, color: Color) void {
        self.drawTextWithFont(&self.icon_font, self.icon_font.cell_width, self.icon_font.line_height, text, x, y, color);
    }

    pub fn measureIconTextWidth(self: *Renderer, text: []const u8) f32 {
        return self.measureTextWidth(&self.icon_font, text);
    }

    pub fn drawChar(self: *Renderer, char: u8, x: f32, y: f32, color: Color) void {
        var buf = [1]u8{char};
        self.drawText(buf[0..], x, y, color);
    }

    pub fn drawLine(self: *Renderer, x1: i32, y1: i32, x2: i32, y2: i32, color: Color) void {
        if (x1 == x2) {
            const top = @min(y1, y2);
            const h = @abs(y2 - y1) + 1;
            self.drawRect(x1, top, 1, h, color);
            return;
        }
        if (y1 == y2) {
            const left = @min(x1, x2);
            const w = @abs(x2 - x1) + 1;
            self.drawRect(left, y1, w, 1, color);
            return;
        }
        // Fallback: draw bounding rect for diagonal lines.
        const left = @min(x1, x2);
        const top = @min(y1, y2);
        const w = @abs(x2 - x1) + 1;
        const h = @abs(y2 - y1) + 1;
        self.drawRect(left, top, w, h, color);
    }

    pub fn beginClip(self: *Renderer, x: i32, y: i32, w: i32, h: i32) void {
        gl.Enable(gl.c.GL_SCISSOR_TEST);
        gl.Scissor(x, self.target_height - (y + h), w, h);
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
        const snapped_x = snapFloat(x);
        const snapped_y = snapFloat(y);
        const snapped_cell_width = snapFloat(cell_width);
        const snapped_cell_height = snapFloat(cell_height);
        const snapped_cell_w_i = snapInt(self.terminal_cell_width);
        const snapped_cell_h_i = snapInt(self.terminal_cell_height);

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
                const underline_y: i32 = snapInt(snapped_y + self.terminal_cell_height - 2);
                self.drawRect(
                    snapInt(snapped_x),
                    underline_y,
                    snapped_cell_w_i,
                    2,
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
        const snapped_x = snapFloat(x);
        const snapped_y = snapFloat(y);
        const snapped_cell_width = snapFloat(cell_width);
        const snapped_cell_height = snapFloat(cell_height);
        const snapped_cell_w_i = snapInt(self.terminal_cell_width);
        const snapped_cell_h_i = snapInt(self.terminal_cell_height);

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
                    .drawTexture = drawTextureBatchThunk,
                };
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
                const underline_y: i32 = snapInt(snapped_y + self.terminal_cell_height - 2);
                self.addTerminalRect(
                    snapInt(snapped_x),
                    underline_y,
                    snapped_cell_w_i,
                    2,
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
        const ix = @as(i32, @intFromFloat(x));
        const iy = @as(i32, @intFromFloat(y));
        const iw = @as(i32, @intFromFloat(w));
        const ih = @as(i32, @intFromFloat(h));
        const mid_x = ix + @divTrunc(iw, 2);
        const mid_y = iy + @divTrunc(ih, 2);
        const thin: i32 = 1;
        const thick: i32 = @max(2, @divTrunc(ih, 6));
        const extend: i32 = 0;

        switch (codepoint) {
            0x2500 => { // ─
                self.drawRect(ix, mid_y, iw, thin, color);
                return true;
            },
            0x2501 => { // ━
                self.drawRect(ix, mid_y - @divTrunc(thick, 2), iw, thick, color);
                return true;
            },
            0x2502 => { // │
                self.drawRect(mid_x, iy - extend, thin, ih + extend * 2, color);
                return true;
            },
            0x2503 => { // ┃
                self.drawRect(mid_x - @divTrunc(thick, 2), iy - extend, thick, ih + extend * 2, color);
                return true;
            },
            0x256d => { // ╭
                self.drawRect(mid_x, mid_y, iw - (mid_x - ix), thin, color);
                self.drawRect(mid_x, mid_y, thin, ih - (mid_y - iy) + extend, color);
                return true;
            },
            0x256e => { // ╮
                self.drawRect(ix, mid_y, mid_x - ix + thin, thin, color);
                self.drawRect(mid_x, mid_y, thin, ih - (mid_y - iy) + extend, color);
                return true;
            },
            0x256f => { // ╯
                self.drawRect(ix, mid_y, mid_x - ix + thin, thin, color);
                self.drawRect(mid_x, iy - extend, thin, mid_y - iy + thin + extend, color);
                return true;
            },
            0x2570 => { // ╰
                self.drawRect(mid_x, mid_y, iw - (mid_x - ix), thin, color);
                self.drawRect(mid_x, iy - extend, thin, mid_y - iy + thin + extend, color);
                return true;
            },
            0x250c => { // ┌
                self.drawRect(mid_x, mid_y, iw - (mid_x - ix), thin, color);
                self.drawRect(mid_x, mid_y, thin, ih - (mid_y - iy) + extend, color);
                return true;
            },
            0x2510 => { // ┐
                self.drawRect(ix, mid_y, mid_x - ix + thin, thin, color);
                self.drawRect(mid_x, mid_y, thin, ih - (mid_y - iy) + extend, color);
                return true;
            },
            0x2514 => { // └
                self.drawRect(mid_x, mid_y, iw - (mid_x - ix), thin, color);
                self.drawRect(mid_x, iy - extend, thin, mid_y - iy + thin + extend, color);
                return true;
            },
            0x2518 => { // ┘
                self.drawRect(ix, mid_y, mid_x - ix + thin, thin, color);
                self.drawRect(mid_x, iy - extend, thin, mid_y - iy + thin + extend, color);
                return true;
            },
            0x2574 => { // ╴
                self.drawRect(ix, mid_y, mid_x - ix + thin, thin, color);
                return true;
            },
            0x2575 => { // ╵
                self.drawRect(mid_x, iy - extend, thin, mid_y - iy + thin + extend, color);
                return true;
            },
            0x2576 => { // ╶
                self.drawRect(mid_x, mid_y, iw - (mid_x - ix), thin, color);
                return true;
            },
            0x2577 => { // ╷
                self.drawRect(mid_x, mid_y, thin, ih - (mid_y - iy) + extend, color);
                return true;
            },
            0x251c => { // ├
                self.drawRect(mid_x, iy - extend, thin, ih + extend * 2, color);
                self.drawRect(mid_x, mid_y, iw - (mid_x - ix), thin, color);
                return true;
            },
            0x2524 => { // ┤
                self.drawRect(mid_x, iy - extend, thin, ih + extend * 2, color);
                self.drawRect(ix, mid_y, mid_x - ix + thin, thin, color);
                return true;
            },
            0x252c => { // ┬
                self.drawRect(ix, mid_y, iw, thin, color);
                self.drawRect(mid_x, mid_y, thin, ih - (mid_y - iy) + extend, color);
                return true;
            },
            0x2534 => { // ┴
                self.drawRect(ix, mid_y, iw, thin, color);
                self.drawRect(mid_x, iy - extend, thin, mid_y - iy + thin + extend, color);
                return true;
            },
            0x253c => { // ┼
                self.drawRect(ix, mid_y, iw, thin, color);
                self.drawRect(mid_x, iy - extend, thin, ih + extend * 2, color);
                return true;
            },
            0x2580 => { // ▀
                self.drawRect(ix, iy, iw, @divTrunc(ih, 2), color);
                return true;
            },
            0x2584 => { // ▄
                const half = @divTrunc(ih, 2);
                self.drawRect(ix, iy + half, iw, ih - half, color);
                return true;
            },
            0x2588 => { // █
                self.drawRect(ix, iy, iw, ih, color);
                return true;
            },
            else => return false,
        }
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
        const ix = @as(i32, @intFromFloat(x));
        const iy = @as(i32, @intFromFloat(y));
        const iw = @as(i32, @intFromFloat(w));
        const ih = @as(i32, @intFromFloat(h));
        const mid_x = ix + @divTrunc(iw, 2);
        const mid_y = iy + @divTrunc(ih, 2);
        const thin: i32 = 1;
        const thick: i32 = @max(2, @divTrunc(ih, 6));
        const extend: i32 = 0;

        switch (codepoint) {
            0x2500 => { // ─
                self.addTerminalRect(ix, mid_y, iw, thin, color);
                return true;
            },
            0x2501 => { // ━
                self.addTerminalRect(ix, mid_y - @divTrunc(thick, 2), iw, thick, color);
                return true;
            },
            0x2502 => { // │
                self.addTerminalRect(mid_x, iy - extend, thin, ih + extend * 2, color);
                return true;
            },
            0x2503 => { // ┃
                self.addTerminalRect(mid_x - @divTrunc(thick, 2), iy - extend, thick, ih + extend * 2, color);
                return true;
            },
            0x256d => { // ╭
                self.addTerminalRect(mid_x, mid_y, iw - (mid_x - ix), thin, color);
                self.addTerminalRect(mid_x, mid_y, thin, ih - (mid_y - iy) + extend, color);
                return true;
            },
            0x256e => { // ╮
                self.addTerminalRect(ix, mid_y, mid_x - ix + thin, thin, color);
                self.addTerminalRect(mid_x, mid_y, thin, ih - (mid_y - iy) + extend, color);
                return true;
            },
            0x256f => { // ╯
                self.addTerminalRect(ix, mid_y, mid_x - ix + thin, thin, color);
                self.addTerminalRect(mid_x, iy - extend, thin, mid_y - iy + thin + extend, color);
                return true;
            },
            0x2570 => { // ╰
                self.addTerminalRect(mid_x, mid_y, iw - (mid_x - ix), thin, color);
                self.addTerminalRect(mid_x, iy - extend, thin, mid_y - iy + thin + extend, color);
                return true;
            },
            0x250c => { // ┌
                self.addTerminalRect(mid_x, mid_y, iw - (mid_x - ix), thin, color);
                self.addTerminalRect(mid_x, mid_y, thin, ih - (mid_y - iy) + extend, color);
                return true;
            },
            0x2510 => { // ┐
                self.addTerminalRect(ix, mid_y, mid_x - ix + thin, thin, color);
                self.addTerminalRect(mid_x, mid_y, thin, ih - (mid_y - iy) + extend, color);
                return true;
            },
            0x2514 => { // └
                self.addTerminalRect(mid_x, mid_y, iw - (mid_x - ix), thin, color);
                self.addTerminalRect(mid_x, iy - extend, thin, mid_y - iy + thin + extend, color);
                return true;
            },
            0x2518 => { // ┘
                self.addTerminalRect(ix, mid_y, mid_x - ix + thin, thin, color);
                self.addTerminalRect(mid_x, iy - extend, thin, mid_y - iy + thin + extend, color);
                return true;
            },
            0x2574 => { // ╴
                self.addTerminalRect(ix, mid_y, mid_x - ix + thin, thin, color);
                return true;
            },
            0x2575 => { // ╵
                self.addTerminalRect(mid_x, iy - extend, thin, mid_y - iy + thin + extend, color);
                return true;
            },
            0x2576 => { // ╶
                self.addTerminalRect(mid_x, mid_y, iw - (mid_x - ix), thin, color);
                return true;
            },
            0x2577 => { // ╷
                self.addTerminalRect(mid_x, mid_y, thin, ih - (mid_y - iy) + extend, color);
                return true;
            },
            0x251c => { // ├
                self.addTerminalRect(mid_x, iy - extend, thin, ih + extend * 2, color);
                self.addTerminalRect(mid_x, mid_y, iw - (mid_x - ix), thin, color);
                return true;
            },
            0x2524 => { // ┤
                self.addTerminalRect(mid_x, iy - extend, thin, ih + extend * 2, color);
                self.addTerminalRect(ix, mid_y, mid_x - ix + thin, thin, color);
                return true;
            },
            0x252c => { // ┬
                self.addTerminalRect(ix, mid_y, iw, thin, color);
                self.addTerminalRect(mid_x, mid_y, thin, ih - (mid_y - iy) + extend, color);
                return true;
            },
            0x2534 => { // ┴
                self.addTerminalRect(ix, mid_y, iw, thin, color);
                self.addTerminalRect(mid_x, iy - extend, thin, mid_y - iy + thin + extend, color);
                return true;
            },
            0x253c => { // ┼
                self.addTerminalRect(ix, mid_y, iw, thin, color);
                self.addTerminalRect(mid_x, iy - extend, thin, ih + extend * 2, color);
                return true;
            },
            0x2580 => { // ▀
                self.addTerminalRect(ix, iy, iw, @divTrunc(ih, 2), color);
                return true;
            },
            0x2584 => { // ▄
                const half = @divTrunc(ih, 2);
                self.addTerminalRect(ix, iy + half, iw, ih - half, color);
                return true;
            },
            0x2588 => { // █
                self.addTerminalRect(ix, iy, iw, ih, color);
                return true;
            },
            else => return false,
        }
    }

    pub fn getCharPressed(self: *Renderer) ?u32 {
        if (self.char_queue.items.len == 0) return null;
        return self.char_queue.orderedRemove(0);
    }

    pub const TextComposition = struct {
        text: []const u8,
        cursor: i32,
        selection_len: i32,
        active: bool,
    };

    pub fn getTextComposition(self: *Renderer) TextComposition {
        return .{
            .text = self.composing_text.items,
            .cursor = self.composing_cursor,
            .selection_len = self.composing_selection_len,
            .active = self.composing_active,
        };
    }

    pub fn getKeyPressed(self: *Renderer) ?KeyPress {
        if (self.key_queue.items.len == 0) return null;
        return self.key_queue.orderedRemove(0);
    }

    pub fn isKeyDown(self: *Renderer, key: i32) bool {
        if (key < 0) return false;
        const idx: usize = @intCast(key);
        if (idx >= key_repeat_key_count) return false;
        return self.key_down[idx];
    }

    pub fn isKeyPressed(self: *Renderer, key: i32) bool {
        if (key < 0) return false;
        const idx: usize = @intCast(key);
        if (idx >= key_repeat_key_count) return false;
        return self.key_pressed[idx];
    }

    pub fn isKeyRepeated(self: *Renderer, key: i32) bool {
        if (key < 0) return false;
        const idx: usize = @intCast(key);
        if (idx >= key_repeat_key_count) return false;
        return self.key_repeated[idx];
    }

    pub fn isKeyReleased(self: *Renderer, key: i32) bool {
        if (key < 0) return false;
        const idx: usize = @intCast(key);
        if (idx >= key_repeat_key_count) return false;
        return self.key_released[idx];
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
        if (button < 0 or @as(usize, @intCast(button)) >= mouse_button_count) return false;
        return self.mouse_pressed[@intCast(button)];
    }

    pub fn isMouseButtonDown(self: *Renderer, button: i32) bool {
        if (button < 0 or @as(usize, @intCast(button)) >= mouse_button_count) return false;
        return self.mouse_down[@intCast(button)];
    }

    pub fn isMouseButtonReleased(self: *Renderer, button: i32) bool {
        if (button < 0 or @as(usize, @intCast(button)) >= mouse_button_count) return false;
        return self.mouse_released[@intCast(button)];
    }

    pub fn getMouseWheelMove(_: *Renderer) f32 {
        return mouse_wheel_delta;
    }

    fn fontForSize(self: *Renderer, size: f32) ?*TerminalFont {
        return font_manager.fontForSize(self, size);
    }

    fn drawTextWithFont(self: *Renderer, font: *TerminalFont, cell_w: f32, cell_h: f32, text: []const u8, x: f32, y: f32, color: Color) void {
        text_draw.drawText(
            self.allocator,
            font,
            self,
            drawTextureThunk,
            text,
            x,
            y,
            cell_w,
            cell_h,
            color.toRgba(),
            false,
        );
    }

    fn drawTextWithFontMonospace(self: *Renderer, font: *TerminalFont, cell_w: f32, cell_h: f32, text: []const u8, x: f32, y: f32, color: Color) void {
        text_draw.drawText(
            self.allocator,
            font,
            self,
            drawTextureThunk,
            text,
            x,
            y,
            cell_w,
            cell_h,
            color.toRgba(),
            true,
        );
    }

    fn measureTextWidth(_: *Renderer, font: *TerminalFont, text: []const u8) f32 {
        return text_draw.measureTextWidth(font, text, font.cell_width);
    }

    fn bindDefaultTarget(self: *Renderer) void {
        targets.bindDefaultTarget(self);
    }

    fn beginRenderTarget(self: *Renderer, target: ?RenderTarget) bool {
        return targets.beginRenderTarget(self, target);
    }

    fn ensureRenderTarget(self: *Renderer, target: *?RenderTarget, width: i32, height: i32, filter: i32) bool {
        _ = self;
        return targets.ensureRenderTarget(target, width, height, filter);
    }

    fn destroyRenderTarget(_: *Renderer, target: *?RenderTarget) void {
        targets.destroyRenderTarget(target);
    }

    fn updateProjection(self: *Renderer, width: i32, height: i32) void {
        targets.updateProjection(self, width, height);
    }

    pub fn beginTerminalBatch(self: *Renderer) void {
        draw_ops.beginTerminalBatch(self);
    }

    pub fn flushTerminalBatch(self: *Renderer) void {
        draw_ops.flushTerminalBatch(self);
    }

    fn drawTextureRect(self: *Renderer, texture: types.Texture, src: types.Rect, dest: types.Rect, color: types.Rgba) void {
        draw_ops.drawTextureRect(self, texture, src, dest, color);
    }

    fn ensureVboCapacity(self: *Renderer, vertex_count: usize) void {
        draw_ops.ensureVboCapacity(self, vertex_count);
    }

    fn addBatchQuad(self: *Renderer, texture: types.Texture, src: types.Rect, dest: types.Rect, color: types.Rgba) void {
        draw_ops.addBatchQuad(self, texture, src, dest, color);
    }

    pub fn addTerminalRect(self: *Renderer, x: i32, y: i32, w: i32, h: i32, color: Color) void {
        draw_ops.addTerminalRect(self, x, y, w, h, color.toRgba());
    }

    fn drawTextureBatchThunk(ctx: *anyopaque, texture: types.Texture, src: types.Rect, dest: types.Rect, color: types.Rgba) void {
        const renderer: *Renderer = @ptrCast(@alignCast(ctx));
        draw_ops.addBatchQuad(renderer, texture, src, dest, color);
    }

    fn drawTextureThunk(ctx: *anyopaque, texture: types.Texture, src: types.Rect, dest: types.Rect, color: types.Rgba) void {
        const renderer: *Renderer = @ptrCast(@alignCast(ctx));
        draw_ops.drawTextureRect(renderer, texture, src, dest, color);
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
        const ime_log = app_logger.logger("sdl.ime");
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

        const events = input_queue.drain(&self.sdl_input);
        for (events) |event| {
            switch (event.type) {
                sdl.SDL_QUIT => {
                    self.should_close_flag = true;
                },
                sdl.SDL_WINDOWEVENT => {
                    const evt = event.window.event;
                    if (platform_window_events.isResizeEvent(evt)) {
                        self.window_resized_flag = true;
                    } else if (platform_window_events.isCloseEvent(evt)) {
                        self.should_close_flag = true;
                    }
                    if (window_log.enabled_file or window_log.enabled_console) {
                        window_log.logf(
                            "event={s} data1={d} data2={d}",
                            .{
                                platform_window_events.eventName(evt),
                                @as(i32, @intCast(event.window.data1)),
                                @as(i32, @intCast(event.window.data2)),
                            },
                        );
                    }
                },
                sdl.SDL_KEYDOWN => {
                    const key_info = platform_input_events.handleKeyDown(
                        &event,
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
                sdl.SDL_KEYUP => {
                    const key_info = platform_input_events.handleKeyUp(
                        &event,
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
                sdl.SDL_TEXTINPUT => {
                    const text_len = platform_input_events.handleTextInput(
                        &event,
                        &self.char_queue,
                        self.allocator,
                    );
                    input_state.applyTextInputReset(state);
                    if (input_log.enabled_file or input_log.enabled_console) {
                        input_log.logf("textinput bytes={d}", .{text_len});
                    }
                },
                sdl.SDL_TEXTEDITING => {
                    const edit_info = platform_input_events.handleTextEditing(
                        &event,
                        &self.composing_text,
                        &self.composing_cursor,
                        &self.composing_selection_len,
                        &self.composing_active,
                        self.allocator,
                    );
                    if (ime_log.enabled_file or ime_log.enabled_console) {
                        ime_log.logf(
                            "textediting bytes={d} cursor={d} selection={d}",
                            .{ edit_info.bytes, edit_info.cursor, edit_info.selection_len },
                        );
                    }
                },
                sdl.SDL_MOUSEBUTTONDOWN => {
                    platform_input_events.handleMouseButtonDown(
                        &event,
                        self.mouse_down[0..],
                        self.mouse_pressed[0..],
                    );
                },
                sdl.SDL_MOUSEBUTTONUP => {
                    platform_input_events.handleMouseButtonUp(
                        &event,
                        self.mouse_down[0..],
                        self.mouse_released[0..],
                    );
                },
                sdl.SDL_MOUSEWHEEL => {
                    mouse_wheel_delta += platform_input_events.wheelDelta(&event);
                },
                else => {},
            }
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
        time_utils.waitTime(seconds, &renderer.sdl_input);
    } else {
        time_utils.waitTime(seconds, null);
    }
}

pub fn getTime() f64 {
    if (active_renderer) |renderer| {
        return time_utils.getTime(renderer.start_counter, renderer.perf_freq);
    }
    return time_utils.getTime(null, null);
}

pub fn setSdlLogLevel(level: c_int) void {
    _ = sdl.SDL_LogSetAllPriority(@intCast(level));
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
