const std = @import("std");
const compositor = @import("../platform/compositor.zig");
const editor_render = @import("../editor/render/renderer_ops.zig");
const terminal_font_mod = @import("terminal_font.zig");
const TerminalFont = terminal_font_mod.TerminalFont;
const gl = @import("renderer/gl.zig");
const types = @import("renderer/types.zig");
const app_logger = @import("../app_logger.zig");

const sdl = gl.c;

var active_renderer: ?*Renderer = null;
var mouse_wheel_delta: f32 = 0.0;

pub const FontFamily = enum {
    iosevka,
    jetbrains_mono,
};

pub const FONT_FAMILY: FontFamily = .jetbrains_mono;

pub const FONT_PATH: [*:0]const u8 = switch (FONT_FAMILY) {
    .iosevka => "assets/fonts/IosevkaTermNerdFont-Regular.ttf",
    .jetbrains_mono => "assets/fonts/JetBrainsMonoNerdFont-Regular.ttf",
};

pub const SYMBOLS_FALLBACK_PATH: ?[*:0]const u8 = null;
pub const UNICODE_SYMBOLS2_PATH: ?[*:0]const u8 = null;
pub const UNICODE_SYMBOLS_PATH: ?[*:0]const u8 = null;
pub const UNICODE_MONO_PATH: ?[*:0]const u8 = null;
pub const UNICODE_SANS_PATH: ?[*:0]const u8 = null;
pub const EMOJI_COLOR_FALLBACK_PATH: ?[*:0]const u8 = null;
pub const EMOJI_TEXT_FALLBACK_PATH: ?[*:0]const u8 = null;

pub const Color = struct {
    r: u8,
    g: u8,
    b: u8,
    a: u8 = 255,

    pub fn toRgba(self: Color) types.Rgba {
        return .{ .r = self.r, .g = self.g, .b = self.b, .a = self.a };
    }

    pub const black = Color{ .r = 0, .g = 0, .b = 0 };
    pub const white = Color{ .r = 255, .g = 255, .b = 255 };
    pub const gray = Color{ .r = 76, .g = 86, .b = 106 };
    pub const dark_gray = Color{ .r = 46, .g = 52, .b = 64 };
    pub const light_gray = Color{ .r = 67, .g = 76, .b = 94 };

    // Nordic palette colors
    pub const bg = Color{ .r = 36, .g = 41, .b = 51 };
    pub const fg = Color{ .r = 187, .g = 195, .b = 212 };
    pub const selection = Color{ .r = 59, .g = 66, .b = 82 };
    pub const comment = Color{ .r = 76, .g = 86, .b = 106 };
    pub const cyan = Color{ .r = 143, .g = 188, .b = 187 };
    pub const green = Color{ .r = 163, .g = 190, .b = 140 };
    pub const orange = Color{ .r = 208, .g = 135, .b = 112 };
    pub const pink = Color{ .r = 180, .g = 142, .b = 173 };
    pub const purple = Color{ .r = 190, .g = 157, .b = 184 };
    pub const red = Color{ .r = 197, .g = 114, .b = 122 };
    pub const yellow = Color{ .r = 235, .g = 203, .b = 139 };
};

pub const MousePos = struct {
    x: f32,
    y: f32,
};

pub const Theme = struct {
    background: Color = Color.bg,
    foreground: Color = Color.fg,
    selection: Color = Color.selection,
    cursor: Color = Color{ .r = 216, .g = 222, .b = 233 },
    link: Color = Color{ .r = 129, .g = 161, .b = 193 },
    line_number: Color = Color.comment,
    line_number_bg: Color = Color{ .r = 30, .g = 34, .b = 42 },
    current_line: Color = Color{ .r = 25, .g = 29, .b = 36 },

    // Syntax colors
    comment_color: Color = Color.comment,
    string: Color = Color.green,
    keyword: Color = Color.orange,
    number: Color = Color.purple,
    function: Color = Color{ .r = 136, .g = 192, .b = 208 },
    variable: Color = Color.fg,
    type_name: Color = Color.yellow,
    operator: Color = Color.fg,
    builtin_color: Color = Color{ .r = 94, .g = 129, .b = 172 },
    punctuation: Color = Color{ .r = 96, .g = 114, .b = 138 },
    constant: Color = Color.purple,
    attribute: Color = Color.cyan,
    namespace: Color = Color{ .r = 231, .g = 193, .b = 115 },
    label: Color = Color.orange,
    error_token: Color = Color.red,
};

const key_repeat_key_count: usize = @intCast(sdl.SDL_NUM_SCANCODES);
const mouse_button_count: usize = 8;
const input_queue_capacity: usize = 8192;
const KeyPress = struct {
    scancode: i32,
    repeated: bool,
};

const InputQueue = struct {
    mutex: std.Thread.Mutex = .{},
    events: []sdl.SDL_Event = &.{},
    head: usize = 0,
    tail: usize = 0,
    count: usize = 0,
    dropped: usize = 0,

    fn init(allocator: std.mem.Allocator, capacity: usize) !InputQueue {
        return .{
            .events = try allocator.alloc(sdl.SDL_Event, capacity),
        };
    }

    fn deinit(self: *InputQueue, allocator: std.mem.Allocator) void {
        if (self.events.len == 0) return;
        allocator.free(self.events);
        self.events = &.{};
        self.head = 0;
        self.tail = 0;
        self.count = 0;
        self.dropped = 0;
    }

    fn push(self: *InputQueue, event: sdl.SDL_Event) void {
        self.mutex.lock();
        defer self.mutex.unlock();

        if (self.events.len == 0) return;

        if (self.count == self.events.len) {
            self.head = (self.head + 1) % self.events.len;
            self.count -= 1;
            self.dropped +|= 1;
        }

        self.events[self.tail] = event;
        self.tail = (self.tail + 1) % self.events.len;
        self.count += 1;
    }

    fn drain(self: *InputQueue, out: *std.ArrayList(sdl.SDL_Event)) void {
        self.mutex.lock();
        defer self.mutex.unlock();

        if (self.count == 0) return;
        if (out.capacity < self.count) return;

        var idx = self.head;
        for (0..self.count) |_| {
            out.appendAssumeCapacity(self.events[idx]);
            idx = (idx + 1) % self.events.len;
        }
        self.head = 0;
        self.tail = 0;
        self.count = 0;
    }
};

const RenderTarget = struct {
    texture: types.Texture,
    fbo: gl.GLuint,
};

const BatchDraw = struct {
    texture_id: gl.GLuint,
    start: usize,
    count: usize,
};

const Vertex = packed struct {
    x: f32,
    y: f32,
    u: f32,
    v: f32,
    r: f32,
    g: f32,
    b: f32,
    a: f32,
};

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
    input_queue: InputQueue,
    input_drain: std.ArrayList(sdl.SDL_Event),
    input_thread: ?std.Thread,
    input_thread_running: std.atomic.Value(bool),
    input_pending: std.atomic.Value(bool),
    clipboard_buffer: std.ArrayList(u8),
    batch_vertices: std.ArrayList(Vertex),
    batch_draws: std.ArrayList(BatchDraw),
    should_close_flag: bool,
    window_resized_flag: bool,

    start_counter: u64,
    perf_freq: f64,

    fn snapInt(value: f32) i32 {
        return @intFromFloat(std.math.round(value));
    }

    fn snapFloat(value: f32) f32 {
        return @as(f32, @floatFromInt(snapInt(value)));
    }

    pub fn init(allocator: std.mem.Allocator, width: i32, height: i32, title: [*:0]const u8) !*Renderer {
        if (sdl.SDL_Init(sdl.SDL_INIT_VIDEO | sdl.SDL_INIT_TIMER) != 0) {
            return error.SdlInitFailed;
        }
        errdefer sdl.SDL_Quit();

        _ = sdl.SDL_GL_SetAttribute(sdl.SDL_GL_CONTEXT_MAJOR_VERSION, 3);
        _ = sdl.SDL_GL_SetAttribute(sdl.SDL_GL_CONTEXT_MINOR_VERSION, 3);
        _ = sdl.SDL_GL_SetAttribute(sdl.SDL_GL_CONTEXT_PROFILE_MASK, sdl.SDL_GL_CONTEXT_PROFILE_CORE);
        _ = sdl.SDL_GL_SetAttribute(sdl.SDL_GL_DOUBLEBUFFER, 1);

        const window = sdl.SDL_CreateWindow(
            title,
            sdl.SDL_WINDOWPOS_CENTERED,
            sdl.SDL_WINDOWPOS_CENTERED,
            width,
            height,
            sdl.SDL_WINDOW_OPENGL | sdl.SDL_WINDOW_RESIZABLE | sdl.SDL_WINDOW_ALLOW_HIGHDPI,
        ) orelse return error.SdlWindowFailed;
        errdefer sdl.SDL_DestroyWindow(window);

        const gl_context = sdl.SDL_GL_CreateContext(window) orelse return error.SdlGlContextFailed;
        errdefer sdl.SDL_GL_DeleteContext(gl_context);
        _ = sdl.SDL_GL_MakeCurrent(window, gl_context);
        _ = sdl.SDL_GL_SetSwapInterval(1);

        try gl.load();

        var renderer = try allocator.create(Renderer);
        errdefer allocator.destroy(renderer);

        const drawable = getDrawableSize(window);
        const window_size = getWindowSize(window);

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
            .input_queue = .{},
            .input_drain = std.ArrayList(sdl.SDL_Event).empty,
            .input_thread = null,
            .input_thread_running = std.atomic.Value(bool).init(false),
            .input_pending = std.atomic.Value(bool).init(false),
            .clipboard_buffer = std.ArrayList(u8).empty,
            .batch_vertices = std.ArrayList(Vertex).empty,
            .batch_draws = std.ArrayList(BatchDraw).empty,
            .should_close_flag = false,
            .window_resized_flag = false,
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
        self.input_queue = try InputQueue.init(self.allocator, input_queue_capacity);
        errdefer self.input_queue.deinit(self.allocator);

        try self.input_drain.ensureTotalCapacity(self.allocator, input_queue_capacity);
        errdefer self.input_drain.deinit(self.allocator);

        self.input_thread_running.store(true, .release);
        self.input_pending.store(false, .release);
        self.input_thread = try std.Thread.spawn(.{}, inputThreadMain, .{self});
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

        self.key_queue.deinit(self.allocator);
        self.char_queue.deinit(self.allocator);
        self.input_drain.deinit(self.allocator);
        self.input_queue.deinit(self.allocator);
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
        if (!self.input_thread_running.load(.acquire)) return;
        self.input_thread_running.store(false, .release);
        if (self.input_thread) |thread| {
            thread.join();
            self.input_thread = null;
        }
    }

    fn initGlResources(self: *Renderer) !void {
        const vertex_src =
            "#version 330 core\n" ++
            "layout (location = 0) in vec2 a_pos;\n" ++
            "layout (location = 1) in vec2 a_uv;\n" ++
            "layout (location = 2) in vec4 a_color;\n" ++
            "out vec2 v_uv;\n" ++
            "out vec4 v_color;\n" ++
            "uniform mat4 u_proj;\n" ++
            "void main() {\n" ++
            "    v_uv = a_uv;\n" ++
            "    v_color = a_color;\n" ++
            "    gl_Position = u_proj * vec4(a_pos, 0.0, 1.0);\n" ++
            "}\n";
        const fragment_src =
            "#version 330 core\n" ++
            "in vec2 v_uv;\n" ++
            "in vec4 v_color;\n" ++
            "out vec4 frag_color;\n" ++
            "uniform sampler2D u_tex;\n" ++
            "void main() {\n" ++
            "    vec4 tex = texture(u_tex, v_uv);\n" ++
            "    frag_color = tex * v_color;\n" ++
            "}\n";

        const vert = try compileShader(gl.c.GL_VERTEX_SHADER, vertex_src);
        defer gl.DeleteShader(vert);
        const frag = try compileShader(gl.c.GL_FRAGMENT_SHADER, fragment_src);
        defer gl.DeleteShader(frag);
        const program = try linkProgram(vert, frag);
        self.shader_program = program;
        gl.UseProgram(program);

        self.uniform_proj = gl.GetUniformLocation(program, "u_proj");
        self.uniform_tex = gl.GetUniformLocation(program, "u_tex");
        if (self.uniform_tex >= 0) gl.Uniform1i(self.uniform_tex, 0);

        gl.GenVertexArrays(1, &self.vao);
        gl.GenBuffers(1, &self.vbo);
        gl.BindVertexArray(self.vao);
        gl.BindBuffer(gl.c.GL_ARRAY_BUFFER, self.vbo);
        gl.BufferData(
            gl.c.GL_ARRAY_BUFFER,
            @as(gl.GLsizeiptr, @intCast(@sizeOf(Vertex) * 6)),
            null,
            gl.c.GL_DYNAMIC_DRAW,
        );
        self.vbo_capacity_vertices = 6;

        gl.EnableVertexAttribArray(0);
        gl.VertexAttribPointer(0, 2, gl.c.GL_FLOAT, gl.c.GL_FALSE, @sizeOf(Vertex), @ptrFromInt(0));
        gl.EnableVertexAttribArray(1);
        gl.VertexAttribPointer(1, 2, gl.c.GL_FLOAT, gl.c.GL_FALSE, @sizeOf(Vertex), @ptrFromInt(2 * @sizeOf(f32)));
        gl.EnableVertexAttribArray(2);
        gl.VertexAttribPointer(2, 4, gl.c.GL_FLOAT, gl.c.GL_FALSE, @sizeOf(Vertex), @ptrFromInt(4 * @sizeOf(f32)));

        gl.Enable(gl.c.GL_BLEND);
        gl.BlendFunc(gl.c.GL_SRC_ALPHA, gl.c.GL_ONE_MINUS_SRC_ALPHA);
        gl.Disable(gl.c.GL_DEPTH_TEST);
        gl.Disable(gl.c.GL_CULL_FACE);

        self.white_texture = createSolidTexture(1, 1, .{ 255, 255, 255, 255 });
        self.updateProjection(self.render_width, self.render_height);
    }

    fn initFonts(self: *Renderer, size: f32) !void {
        self.terminal_font = try TerminalFont.init(
            self.allocator,
            FONT_PATH,
            size,
            SYMBOLS_FALLBACK_PATH,
            UNICODE_SYMBOLS2_PATH,
            UNICODE_SYMBOLS_PATH,
            UNICODE_MONO_PATH,
            UNICODE_SANS_PATH,
            EMOJI_COLOR_FALLBACK_PATH,
            EMOJI_TEXT_FALLBACK_PATH,
        );
        self.terminal_font.setAtlasFilterPoint();
        self.terminal_cell_width = @as(f32, @floatFromInt(@as(i32, @intFromFloat(std.math.round(self.terminal_font.cell_width)))));
        self.terminal_cell_height = @as(f32, @floatFromInt(@as(i32, @intFromFloat(std.math.round(self.terminal_font.line_height)))));
        self.char_width = self.terminal_cell_width;
        self.char_height = self.terminal_cell_height;

        self.icon_font = try TerminalFont.init(
            self.allocator,
            FONT_PATH,
            size * 2.0,
            SYMBOLS_FALLBACK_PATH,
            UNICODE_SYMBOLS2_PATH,
            UNICODE_SYMBOLS_PATH,
            UNICODE_MONO_PATH,
            UNICODE_SANS_PATH,
            EMOJI_COLOR_FALLBACK_PATH,
            EMOJI_TEXT_FALLBACK_PATH,
        );
        self.icon_font.setAtlasFilterPoint();
        self.icon_font_size = size * 2.0;
        self.icon_char_width = self.icon_font.cell_width;
        self.icon_char_height = self.icon_font.line_height;
    }

    pub fn loadFont(self: *Renderer, path: [*:0]const u8, size: f32) void {
        self.terminal_font.deinit();
        self.terminal_font = TerminalFont.init(
            self.allocator,
            path,
            size,
            SYMBOLS_FALLBACK_PATH,
            UNICODE_SYMBOLS2_PATH,
            UNICODE_SYMBOLS_PATH,
            UNICODE_MONO_PATH,
            UNICODE_SANS_PATH,
            EMOJI_COLOR_FALLBACK_PATH,
            EMOJI_TEXT_FALLBACK_PATH,
        ) catch return;
        self.terminal_font.setAtlasFilterPoint();
        self.font_size = size;
        self.char_width = self.terminal_font.cell_width;
        self.char_height = self.terminal_font.line_height;
        self.terminal_cell_width = self.char_width;
        self.terminal_cell_height = self.char_height;
    }

    pub fn loadFontWithGlyphs(self: *Renderer, allocator: std.mem.Allocator, path: [*:0]const u8, size: f32) void {
        _ = allocator;
        self.loadFont(path, size);
    }

    fn queryUiScale(self: *Renderer) f32 {
        var scale: f32 = 1.0;
        const dpi = self.getDpiScale();
        scale = @max(dpi.x, dpi.y);

        if (compositor.isWayland()) {
            const now = getTime();
            if (now - self.wayland_scale_last_update > 1.0) {
                self.wayland_scale_cache = compositor.getWaylandScale(self.allocator);
                self.wayland_scale_last_update = now;
            }
            if (self.wayland_scale_cache) |wl_scale| {
                if (wl_scale > 0.0) scale = wl_scale;
            }
        }

        if (std.c.getenv("ZIDE_UI_SCALE")) |raw| {
            const s = std.mem.trim(u8, std.mem.span(raw), " \t\r\n");
            const env_scale = std.fmt.parseFloat(f32, s) catch 1.0;
            if (env_scale > 0.0) scale *= env_scale;
        }

        return if (scale > 0.1) scale else 1.0;
    }

    fn applyFontScale(self: *Renderer) !void {
        const size = self.base_font_size * self.ui_scale * self.user_zoom;
        var font_it = self.font_cache.iterator();
        while (font_it.next()) |entry| {
            entry.value_ptr.*.deinit();
            self.allocator.destroy(entry.value_ptr.*);
        }
        self.font_cache.clearRetainingCapacity();
        self.terminal_font.deinit();
        self.icon_font.deinit();
        self.font_size = size;
        try self.initFonts(size);
    }

    pub fn queueUserZoom(self: *Renderer, delta: f32, now: f64) bool {
        const next = std.math.clamp(self.user_zoom_target + delta, 0.5, 3.0);
        if (std.math.approxEqAbs(f32, next, self.user_zoom_target, 0.0001)) return false;
        self.user_zoom_target = next;
        self.last_zoom_request_time = now;
        return true;
    }

    pub fn resetUserZoomTarget(self: *Renderer, now: f64) bool {
        if (std.math.approxEqAbs(f32, self.user_zoom_target, 1.0, 0.0001)) return false;
        self.user_zoom_target = 1.0;
        self.last_zoom_request_time = now;
        return true;
    }

    pub fn refreshUiScale(self: *Renderer) !bool {
        const next = self.queryUiScale();
        if (std.math.approxEqAbs(f32, next, self.ui_scale, 0.0001)) return false;
        self.ui_scale = next;
        try self.applyFontScale();
        return true;
    }

    pub fn applyPendingZoom(self: *Renderer, now: f64) !bool {
        if (std.math.approxEqAbs(f32, self.user_zoom_target, self.user_zoom, 0.0001)) return false;
        if (now - self.last_zoom_request_time < 0.04) return false;
        if (now - self.last_zoom_apply_time < 0.02) return false;
        self.user_zoom = self.user_zoom_target;
        try self.applyFontScale();
        self.last_zoom_apply_time = now;
        return true;
    }

    pub fn uiScaleFactor(self: *const Renderer) f32 {
        return self.ui_scale * self.user_zoom;
    }

    pub fn shouldClose(self: *Renderer) bool {
        return self.should_close_flag;
    }

    pub fn beginFrame(self: *Renderer) void {
        const window_size = getWindowSize(self.window);
        const drawable = getDrawableSize(self.window);
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
        _ = sdl.SDL_SetClipboardText(text);
    }

    pub fn getClipboardText(self: *Renderer) ?[]const u8 {
        const ptr = sdl.SDL_GetClipboardText();
        if (ptr == null) return null;
        const slice = std.mem.span(@as([*:0]const u8, @ptrCast(ptr)));
        if (slice.len == 0) {
            sdl.SDL_free(ptr);
            return null;
        }
        self.clipboard_buffer.clearRetainingCapacity();
        _ = self.clipboard_buffer.appendSlice(self.allocator, slice) catch {
            sdl.SDL_free(ptr);
            return null;
        };
        sdl.SDL_free(ptr);
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
        const pos = self.getMousePosRaw();
        return .{ .x = pos.x * self.mouse_scale.x, .y = pos.y * self.mouse_scale.y };
    }

    pub fn getMousePosScaled(self: *Renderer, scale: f32) MousePos {
        const pos = self.getMousePosRaw();
        return .{ .x = pos.x * scale, .y = pos.y * scale };
    }

    pub fn getMousePosRaw(_: *Renderer) MousePos {
        var x: c_int = 0;
        var y: c_int = 0;
        _ = sdl.SDL_GetMouseState(&x, &y);
        return .{ .x = @floatFromInt(x), .y = @floatFromInt(y) };
    }

    pub fn getDpiScale(self: *Renderer) MousePos {
        const window_size = getWindowSize(self.window);
        const drawable = getDrawableSize(self.window);
        if (window_size.w <= 0 or window_size.h <= 0) return .{ .x = 1.0, .y = 1.0 };
        return .{
            .x = @as(f32, @floatFromInt(drawable.w)) / @as(f32, @floatFromInt(window_size.w)),
            .y = @as(f32, @floatFromInt(drawable.h)) / @as(f32, @floatFromInt(window_size.h)),
        };
    }

    pub fn getScreenSize(self: *Renderer) MousePos {
        const window_size = getWindowSize(self.window);
        return .{ .x = @floatFromInt(window_size.w), .y = @floatFromInt(window_size.h) };
    }

    pub fn getMonitorSize(self: *Renderer) MousePos {
        const display = sdl.SDL_GetWindowDisplayIndex(self.window);
        var rect: sdl.SDL_Rect = undefined;
        if (display >= 0 and sdl.SDL_GetDisplayBounds(display, &rect) == 0) {
            return .{ .x = @floatFromInt(rect.w), .y = @floatFromInt(rect.h) };
        }
        return self.getScreenSize();
    }

    fn updateMouseScale(self: *Renderer) void {
        const window_size = getWindowSize(self.window);
        const drawable = getDrawableSize(self.window);
        var sx: f32 = if (window_size.w > 0) @as(f32, @floatFromInt(drawable.w)) / @as(f32, @floatFromInt(window_size.w)) else 1.0;
        var sy: f32 = if (window_size.h > 0) @as(f32, @floatFromInt(drawable.h)) / @as(f32, @floatFromInt(window_size.h)) else 1.0;

        if (compositor.isWayland()) {
            // SDL already reports logical mouse coords; drawable/window ratio matches render scale.
            // Avoid double-applying compositor scale here.
        }

        if (std.c.getenv("ZIDE_MOUSE_SCALE")) |raw| {
            const s = std.mem.sliceTo(raw, 0);
            const env_scale = std.fmt.parseFloat(f32, s) catch 1.0;
            sx *= env_scale;
            sy *= env_scale;
        }

        self.mouse_scale = .{ .x = sx, .y = sy };
    }

    pub fn getRenderSize(self: *Renderer) MousePos {
        const drawable = getDrawableSize(self.window);
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
        if (std.math.approxEqAbs(f32, size, self.font_size, 0.01)) return &self.terminal_font;
        if (std.math.approxEqAbs(f32, size, self.icon_font_size, 0.01)) return &self.icon_font;
        const key: u32 = @intFromFloat(std.math.round(size));
        if (self.font_cache.get(key)) |font_ptr| return font_ptr;

        const font_ptr = self.allocator.create(TerminalFont) catch return null;
        font_ptr.* = TerminalFont.init(
            self.allocator,
            FONT_PATH,
            @floatFromInt(key),
            SYMBOLS_FALLBACK_PATH,
            UNICODE_SYMBOLS2_PATH,
            UNICODE_SYMBOLS_PATH,
            UNICODE_MONO_PATH,
            UNICODE_SANS_PATH,
            EMOJI_COLOR_FALLBACK_PATH,
            EMOJI_TEXT_FALLBACK_PATH,
        ) catch {
            self.allocator.destroy(font_ptr);
            return null;
        };
        font_ptr.setAtlasFilterPoint();
        _ = self.font_cache.put(key, font_ptr) catch {};
        return font_ptr;
    }

    fn drawTextWithFont(self: *Renderer, font: *TerminalFont, cell_w: f32, cell_h: f32, text: []const u8, x: f32, y: f32, color: Color) void {
        if (text.len == 0) return;

        var codepoints = std.ArrayList(u32).empty;
        defer codepoints.deinit(self.allocator);
        var cp_idx: usize = 0;
        while (true) {
            const cp = nextCodepointLossy(text, &cp_idx) orelse break;
            _ = codepoints.append(self.allocator, cp) catch {};
        }
        if (codepoints.items.len == 0) return;

        var cursor_x = x;
        const draw = terminal_font_mod.DrawContext{
            .ctx = self,
            .drawTexture = drawTextureThunk,
        };
        var idx: usize = 0;
        while (idx < codepoints.items.len) : (idx += 1) {
            const cp = codepoints.items[idx];
            const next = if (idx + 1 < codepoints.items.len) codepoints.items[idx + 1] else 0;
            const followed_by_space = next == ' ';
            font.drawGlyph(draw, cp, cursor_x, y, cell_w, cell_h, followed_by_space, color.toRgba());
            const adv = font.glyphAdvance(cp) catch cell_w;
            cursor_x += if (adv > 0) adv else cell_w;
        }
    }

    fn drawTextWithFontMonospace(self: *Renderer, font: *TerminalFont, cell_w: f32, cell_h: f32, text: []const u8, x: f32, y: f32, color: Color) void {
        if (text.len == 0) return;

        var codepoints = std.ArrayList(u32).empty;
        defer codepoints.deinit(self.allocator);
        var cp_idx: usize = 0;
        while (true) {
            const cp = nextCodepointLossy(text, &cp_idx) orelse break;
            _ = codepoints.append(self.allocator, cp) catch {};
        }
        if (codepoints.items.len == 0) return;

        var cursor_x = x;
        const draw = terminal_font_mod.DrawContext{
            .ctx = self,
            .drawTexture = drawTextureThunk,
        };
        var idx: usize = 0;
        while (idx < codepoints.items.len) : (idx += 1) {
            const cp = codepoints.items[idx];
            const next = if (idx + 1 < codepoints.items.len) codepoints.items[idx + 1] else 0;
            const followed_by_space = next == ' ';
            font.drawGlyph(draw, cp, cursor_x, y, cell_w, cell_h, followed_by_space, color.toRgba());
            cursor_x += cell_w;
        }
    }

    fn measureTextWidth(_: *Renderer, font: *TerminalFont, text: []const u8) f32 {
        if (text.len == 0) return 0;
        var width: f32 = 0;
        var idx: usize = 0;
        while (true) {
            const cp = nextCodepointLossy(text, &idx) orelse break;
            const adv = font.glyphAdvance(cp) catch font.cell_width;
            width += if (adv > 0) adv else font.cell_width;
        }
        return width;
    }

    fn nextCodepointLossy(text: []const u8, idx: *usize) ?u32 {
        if (idx.* >= text.len) return null;
        const first = text[idx.*];
        const seq_len = std.unicode.utf8ByteSequenceLength(first) catch {
            idx.* += 1;
            return 0xFFFD;
        };
        if (idx.* + seq_len > text.len) {
            idx.* += 1;
            return 0xFFFD;
        }
        const slice = text[idx.* .. idx.* + seq_len];
        const cp = std.unicode.utf8Decode(slice) catch {
            idx.* += 1;
            return 0xFFFD;
        };
        idx.* += seq_len;
        return cp;
    }

    fn bindDefaultTarget(self: *Renderer) void {
        gl.BindFramebuffer(gl.c.GL_FRAMEBUFFER, 0);
        self.updateProjection(self.render_width, self.render_height);
    }

    fn beginRenderTarget(self: *Renderer, target: ?RenderTarget) bool {
        if (target) |t| {
            gl.BindFramebuffer(gl.c.GL_FRAMEBUFFER, t.fbo);
            self.updateProjection(t.texture.width, t.texture.height);
            return true;
        }
        return false;
    }

    fn ensureRenderTarget(self: *Renderer, target: *?RenderTarget, width: i32, height: i32, filter: i32) bool {
        if (width <= 0 or height <= 0) return false;
        if (target.*) |t| {
            if (t.texture.width == width and t.texture.height == height) return false;
            self.destroyRenderTarget(target);
        }

        const texture = createTextureEmpty(width, height, filter);
        var fbo: gl.GLuint = 0;
        gl.GenFramebuffers(1, &fbo);
        gl.BindFramebuffer(gl.c.GL_FRAMEBUFFER, fbo);
        gl.FramebufferTexture2D(gl.c.GL_FRAMEBUFFER, gl.c.GL_COLOR_ATTACHMENT0, gl.c.GL_TEXTURE_2D, texture.id, 0);
        const status = gl.CheckFramebufferStatus(gl.c.GL_FRAMEBUFFER);
        gl.BindFramebuffer(gl.c.GL_FRAMEBUFFER, 0);
        if (status != gl.c.GL_FRAMEBUFFER_COMPLETE) {
            gl.DeleteFramebuffers(1, &fbo);
            gl.DeleteTextures(1, &texture.id);
            return false;
        }

        target.* = .{ .texture = texture, .fbo = fbo };
        return true;
    }

    fn destroyRenderTarget(_: *Renderer, target: *?RenderTarget) void {
        if (target.*) |t| {
            gl.DeleteFramebuffers(1, &t.fbo);
            gl.DeleteTextures(1, &t.texture.id);
            target.* = null;
        }
    }

    fn updateProjection(self: *Renderer, width: i32, height: i32) void {
        self.target_width = width;
        self.target_height = height;
        gl.Viewport(0, 0, width, height);
        if (self.uniform_proj >= 0) {
            const w = @as(f32, @floatFromInt(width));
            const h = @as(f32, @floatFromInt(height));
            const proj = [_]f32{
                2.0 / w, 0, 0, 0,
                0, -2.0 / h, 0, 0,
                0, 0, 1, 0,
                -1, 1, 0, 1,
            };
            gl.UseProgram(self.shader_program);
            gl.UniformMatrix4fv(self.uniform_proj, 1, gl.c.GL_FALSE, &proj);
        }
    }

    pub fn beginTerminalBatch(self: *Renderer) void {
        self.batch_vertices.clearRetainingCapacity();
        self.batch_draws.clearRetainingCapacity();
    }

    pub fn flushTerminalBatch(self: *Renderer) void {
        const vertex_count = self.batch_vertices.items.len;
        if (vertex_count == 0) return;
        self.ensureVboCapacity(vertex_count);
        gl.UseProgram(self.shader_program);
        gl.BindVertexArray(self.vao);
        gl.BindBuffer(gl.c.GL_ARRAY_BUFFER, self.vbo);
        gl.BufferSubData(
            gl.c.GL_ARRAY_BUFFER,
            0,
            @as(gl.GLsizeiptr, @intCast(@sizeOf(Vertex) * vertex_count)),
            self.batch_vertices.items.ptr,
        );
        for (self.batch_draws.items) |draw| {
            if (draw.texture_id == 0) continue;
            gl.ActiveTexture(gl.c.GL_TEXTURE0);
            gl.BindTexture(gl.c.GL_TEXTURE_2D, draw.texture_id);
            gl.DrawArrays(gl.c.GL_TRIANGLES, @intCast(draw.start), @intCast(draw.count));
        }
    }

    fn drawTextureRect(self: *Renderer, texture: types.Texture, src: types.Rect, dest: types.Rect, color: types.Rgba) void {
        if (texture.id == 0 or texture.width <= 0 or texture.height <= 0) return;
        gl.UseProgram(self.shader_program);
        gl.BindVertexArray(self.vao);
        gl.ActiveTexture(gl.c.GL_TEXTURE0);
        gl.BindTexture(gl.c.GL_TEXTURE_2D, texture.id);

        const tex_w = @as(f32, @floatFromInt(texture.width));
        const tex_h = @as(f32, @floatFromInt(texture.height));
        const u_min = src.x / tex_w;
        const v_min = src.y / tex_h;
        const u_max = (src.x + src.width) / tex_w;
        const v_max = (src.y + src.height) / tex_h;

        const r = @as(f32, @floatFromInt(color.r)) / 255.0;
        const g = @as(f32, @floatFromInt(color.g)) / 255.0;
        const b = @as(f32, @floatFromInt(color.b)) / 255.0;
        const a = @as(f32, @floatFromInt(color.a)) / 255.0;

        const x0 = dest.x;
        const y0 = dest.y;
        const x1 = dest.x + dest.width;
        const y1 = dest.y + dest.height;

        const verts = [_]Vertex{
            .{ .x = x0, .y = y0, .u = u_min, .v = v_min, .r = r, .g = g, .b = b, .a = a },
            .{ .x = x1, .y = y0, .u = u_max, .v = v_min, .r = r, .g = g, .b = b, .a = a },
            .{ .x = x1, .y = y1, .u = u_max, .v = v_max, .r = r, .g = g, .b = b, .a = a },
            .{ .x = x0, .y = y0, .u = u_min, .v = v_min, .r = r, .g = g, .b = b, .a = a },
            .{ .x = x1, .y = y1, .u = u_max, .v = v_max, .r = r, .g = g, .b = b, .a = a },
            .{ .x = x0, .y = y1, .u = u_min, .v = v_max, .r = r, .g = g, .b = b, .a = a },
        };

        gl.BindBuffer(gl.c.GL_ARRAY_BUFFER, self.vbo);
        gl.BufferSubData(
            gl.c.GL_ARRAY_BUFFER,
            0,
            @as(gl.GLsizeiptr, @intCast(@sizeOf(Vertex) * 6)),
            &verts,
        );
        gl.DrawArrays(gl.c.GL_TRIANGLES, 0, 6);
    }

    fn ensureVboCapacity(self: *Renderer, vertex_count: usize) void {
        if (vertex_count <= self.vbo_capacity_vertices) return;
        var next_cap = self.vbo_capacity_vertices * 2;
        if (next_cap < 6) next_cap = 6;
        if (next_cap < vertex_count) next_cap = vertex_count;
        gl.BindBuffer(gl.c.GL_ARRAY_BUFFER, self.vbo);
        gl.BufferData(
            gl.c.GL_ARRAY_BUFFER,
            @as(gl.GLsizeiptr, @intCast(@sizeOf(Vertex) * next_cap)),
            null,
            gl.c.GL_DYNAMIC_DRAW,
        );
        self.vbo_capacity_vertices = next_cap;
    }

    fn addBatchQuad(self: *Renderer, texture: types.Texture, src: types.Rect, dest: types.Rect, color: types.Rgba) void {
        if (texture.id == 0 or texture.width <= 0 or texture.height <= 0) return;
        const tex_w = @as(f32, @floatFromInt(texture.width));
        const tex_h = @as(f32, @floatFromInt(texture.height));
        const u_min = src.x / tex_w;
        const v_min = src.y / tex_h;
        const u_max = (src.x + src.width) / tex_w;
        const v_max = (src.y + src.height) / tex_h;

        const r = @as(f32, @floatFromInt(color.r)) / 255.0;
        const g = @as(f32, @floatFromInt(color.g)) / 255.0;
        const b = @as(f32, @floatFromInt(color.b)) / 255.0;
        const a = @as(f32, @floatFromInt(color.a)) / 255.0;

        const x0 = dest.x;
        const y0 = dest.y;
        const x1 = dest.x + dest.width;
        const y1 = dest.y + dest.height;

        const base = self.batch_vertices.items.len;
        const verts = [_]Vertex{
            .{ .x = x0, .y = y0, .u = u_min, .v = v_min, .r = r, .g = g, .b = b, .a = a },
            .{ .x = x1, .y = y0, .u = u_max, .v = v_min, .r = r, .g = g, .b = b, .a = a },
            .{ .x = x1, .y = y1, .u = u_max, .v = v_max, .r = r, .g = g, .b = b, .a = a },
            .{ .x = x0, .y = y0, .u = u_min, .v = v_min, .r = r, .g = g, .b = b, .a = a },
            .{ .x = x1, .y = y1, .u = u_max, .v = v_max, .r = r, .g = g, .b = b, .a = a },
            .{ .x = x0, .y = y1, .u = u_min, .v = v_max, .r = r, .g = g, .b = b, .a = a },
        };
        self.batch_vertices.appendSlice(self.allocator, &verts) catch return;
        if (self.batch_draws.items.len > 0) {
            const last_idx = self.batch_draws.items.len - 1;
            if (self.batch_draws.items[last_idx].texture_id == texture.id) {
                self.batch_draws.items[last_idx].count += 6;
                return;
            }
        }
        _ = self.batch_draws.append(self.allocator, .{
            .texture_id = texture.id,
            .start = base,
            .count = 6,
        }) catch {};
    }

    pub fn addTerminalRect(self: *Renderer, x: i32, y: i32, w: i32, h: i32, color: Color) void {
        if (w <= 0 or h <= 0) return;
        const dest = types.Rect{
            .x = @floatFromInt(x),
            .y = @floatFromInt(y),
            .width = @floatFromInt(w),
            .height = @floatFromInt(h),
        };
        const src = types.Rect{ .x = 0, .y = 0, .width = 1, .height = 1 };
        self.addBatchQuad(self.white_texture, src, dest, color.toRgba());
    }

    fn drawTextureBatchThunk(ctx: *anyopaque, texture: types.Texture, src: types.Rect, dest: types.Rect, color: types.Rgba) void {
        const renderer: *Renderer = @ptrCast(@alignCast(ctx));
        renderer.addBatchQuad(texture, src, dest, color);
    }

    fn drawTextureThunk(ctx: *anyopaque, texture: types.Texture, src: types.Rect, dest: types.Rect, color: types.Rgba) void {
        const renderer: *Renderer = @ptrCast(@alignCast(ctx));
        renderer.drawTextureRect(texture, src, dest, color);
    }

    pub fn createTextureFromRgba(_: *Renderer, width: i32, height: i32, data: []const u8, filter: i32) ?types.Texture {
        if (width <= 0 or height <= 0) return null;
        if (@as(usize, @intCast(width * height * 4)) > data.len) return null;

        var id: gl.GLuint = 0;
        gl.GenTextures(1, &id);
        gl.BindTexture(gl.c.GL_TEXTURE_2D, id);
        gl.TexParameteri(gl.c.GL_TEXTURE_2D, gl.c.GL_TEXTURE_MIN_FILTER, filter);
        gl.TexParameteri(gl.c.GL_TEXTURE_2D, gl.c.GL_TEXTURE_MAG_FILTER, filter);
        gl.TexParameteri(gl.c.GL_TEXTURE_2D, gl.c.GL_TEXTURE_WRAP_S, gl.c.GL_CLAMP_TO_EDGE);
        gl.TexParameteri(gl.c.GL_TEXTURE_2D, gl.c.GL_TEXTURE_WRAP_T, gl.c.GL_CLAMP_TO_EDGE);
        gl.PixelStorei(gl.c.GL_UNPACK_ALIGNMENT, 1);
        gl.TexImage2D(
            gl.c.GL_TEXTURE_2D,
            0,
            gl.c.GL_RGBA,
            width,
            height,
            0,
            gl.c.GL_RGBA,
            gl.c.GL_UNSIGNED_BYTE,
            data.ptr,
        );
        return .{ .id = id, .width = width, .height = height };
    }

    pub fn createTextureFromRgb(_: *Renderer, width: i32, height: i32, data: []const u8, filter: i32) ?types.Texture {
        if (width <= 0 or height <= 0) return null;
        if (@as(usize, @intCast(width * height * 3)) > data.len) return null;

        var id: gl.GLuint = 0;
        gl.GenTextures(1, &id);
        gl.BindTexture(gl.c.GL_TEXTURE_2D, id);
        gl.TexParameteri(gl.c.GL_TEXTURE_2D, gl.c.GL_TEXTURE_MIN_FILTER, filter);
        gl.TexParameteri(gl.c.GL_TEXTURE_2D, gl.c.GL_TEXTURE_MAG_FILTER, filter);
        gl.TexParameteri(gl.c.GL_TEXTURE_2D, gl.c.GL_TEXTURE_WRAP_S, gl.c.GL_CLAMP_TO_EDGE);
        gl.TexParameteri(gl.c.GL_TEXTURE_2D, gl.c.GL_TEXTURE_WRAP_T, gl.c.GL_CLAMP_TO_EDGE);
        gl.PixelStorei(gl.c.GL_UNPACK_ALIGNMENT, 1);
        gl.TexImage2D(
            gl.c.GL_TEXTURE_2D,
            0,
            gl.c.GL_RGB,
            width,
            height,
            0,
            gl.c.GL_RGB,
            gl.c.GL_UNSIGNED_BYTE,
            data.ptr,
        );
        return .{ .id = id, .width = width, .height = height };
    }

    pub fn destroyTexture(_: *Renderer, texture: *types.Texture) void {
        if (texture.id != 0) {
            gl.DeleteTextures(1, &texture.id);
            texture.id = 0;
        }
    }

    pub fn drawTexture(self: *Renderer, texture: types.Texture, src: types.Rect, dest: types.Rect, color: Color) void {
        self.drawTextureRect(texture, src, dest, color.toRgba());
    }

    fn pollInputEvents(self: *Renderer) void {
        const input_log = app_logger.logger("input.sdl");
        @memset(self.key_pressed[0..], false);
        @memset(self.key_repeated[0..], false);
        @memset(self.key_released[0..], false);
        @memset(self.mouse_pressed[0..], false);
        @memset(self.mouse_released[0..], false);
        self.window_resized_flag = false;
        mouse_wheel_delta = 0.0;

        self.input_drain.clearRetainingCapacity();
        self.input_queue.drain(&self.input_drain);
        if (self.input_drain.items.len > 0) {
            self.input_pending.store(false, .release);
        }
        for (self.input_drain.items) |event| {
            switch (event.type) {
                sdl.SDL_QUIT => {
                    self.should_close_flag = true;
                },
                sdl.SDL_WINDOWEVENT => {
                    if (event.window.event == sdl.SDL_WINDOWEVENT_RESIZED or event.window.event == sdl.SDL_WINDOWEVENT_SIZE_CHANGED) {
                        self.window_resized_flag = true;
                    } else if (event.window.event == sdl.SDL_WINDOWEVENT_CLOSE) {
                        self.should_close_flag = true;
                    }
                },
                sdl.SDL_KEYDOWN => {
                    const sc = @as(i32, @intCast(event.key.keysym.scancode));
                    if (sc >= 0 and @as(usize, @intCast(sc)) < key_repeat_key_count) {
                        self.key_down[@intCast(sc)] = true;
                        if (event.key.repeat == 0) {
                            self.key_pressed[@intCast(sc)] = true;
                        } else {
                            self.key_repeated[@intCast(sc)] = true;
                        }
                        _ = self.key_queue.append(self.allocator, .{
                            .scancode = sc,
                            .repeated = event.key.repeat != 0,
                        }) catch {};
                    }
                    if (input_log.enabled_file or input_log.enabled_console) {
                        input_log.logf(
                            "keydown sc={d} sym={d} repeat={d}",
                            .{ sc, @as(i32, @intCast(event.key.keysym.sym)), event.key.repeat },
                        );
                    }
                },
                sdl.SDL_KEYUP => {
                    const sc = @as(i32, @intCast(event.key.keysym.scancode));
                    if (sc >= 0 and @as(usize, @intCast(sc)) < key_repeat_key_count) {
                        self.key_down[@intCast(sc)] = false;
                        self.key_released[@intCast(sc)] = true;
                    }
                    if (input_log.enabled_file or input_log.enabled_console) {
                        input_log.logf(
                            "keyup sc={d} sym={d}",
                            .{ sc, @as(i32, @intCast(event.key.keysym.sym)) },
                        );
                    }
                },
                sdl.SDL_TEXTINPUT => {
                    const text = std.mem.span(@as([*:0]const u8, @ptrCast(&event.text.text)));
                    var it = std.unicode.Utf8View.initUnchecked(text).iterator();
                    while (it.nextCodepoint()) |cp| {
                        _ = self.char_queue.append(self.allocator, cp) catch {};
                    }
                    if (input_log.enabled_file or input_log.enabled_console) {
                        input_log.logf("textinput bytes={d}", .{text.len});
                    }
                },
                sdl.SDL_MOUSEBUTTONDOWN => {
                    const btn = @as(i32, @intCast(event.button.button));
                    if (btn >= 0 and @as(usize, @intCast(btn)) < mouse_button_count) {
                        self.mouse_down[@intCast(btn)] = true;
                        self.mouse_pressed[@intCast(btn)] = true;
                    }
                },
                sdl.SDL_MOUSEBUTTONUP => {
                    const btn = @as(i32, @intCast(event.button.button));
                    if (btn >= 0 and @as(usize, @intCast(btn)) < mouse_button_count) {
                        self.mouse_down[@intCast(btn)] = false;
                        self.mouse_released[@intCast(btn)] = true;
                    }
                },
                sdl.SDL_MOUSEWHEEL => {
                    mouse_wheel_delta += @floatFromInt(event.wheel.y);
                },
                else => {},
            }
        }
    }
};

fn inputThreadMain(self: *Renderer) void {
    var event: sdl.SDL_Event = undefined;
    while (self.input_thread_running.load(.acquire)) {
        if (sdl.SDL_WaitEventTimeout(&event, 8) != 0) {
            self.input_queue.push(event);
            self.input_pending.store(true, .release);
            while (sdl.SDL_PollEvent(&event) != 0) {
                self.input_queue.push(event);
            }
            self.input_pending.store(true, .release);
        }
    }
}

fn compileShader(kind: gl.GLenum, source: []const u8) !gl.GLuint {
    const shader = gl.CreateShader(kind);
    const src_ptr: [*]const gl.GLchar = @ptrCast(source.ptr);
    const src_len: gl.GLint = @intCast(source.len);
    const lengths = [_]gl.GLint{src_len};
    gl.ShaderSource(shader, 1, @ptrCast(&src_ptr), @ptrCast(&lengths));
    gl.CompileShader(shader);
    var status: gl.GLint = 0;
    gl.GetShaderiv(shader, gl.c.GL_COMPILE_STATUS, &status);
    if (status == 0) {
        var log_buf: [1024]u8 = undefined;
        var len: gl.GLsizei = 0;
        gl.GetShaderInfoLog(shader, log_buf.len, &len, @ptrCast(&log_buf));
        return error.GlShaderCompileFailed;
    }
    return shader;
}

fn linkProgram(vert: gl.GLuint, frag: gl.GLuint) !gl.GLuint {
    const program = gl.CreateProgram();
    gl.AttachShader(program, vert);
    gl.AttachShader(program, frag);
    gl.LinkProgram(program);
    var status: gl.GLint = 0;
    gl.GetProgramiv(program, gl.c.GL_LINK_STATUS, &status);
    if (status == 0) {
        var log_buf: [1024]u8 = undefined;
        var len: gl.GLsizei = 0;
        gl.GetProgramInfoLog(program, log_buf.len, &len, @ptrCast(&log_buf));
        return error.GlProgramLinkFailed;
    }
    return program;
}

fn createSolidTexture(width: i32, height: i32, rgba: [4]u8) types.Texture {
    var id: gl.GLuint = 0;
    gl.GenTextures(1, &id);
    gl.BindTexture(gl.c.GL_TEXTURE_2D, id);
    gl.TexParameteri(gl.c.GL_TEXTURE_2D, gl.c.GL_TEXTURE_MIN_FILTER, gl.c.GL_NEAREST);
    gl.TexParameteri(gl.c.GL_TEXTURE_2D, gl.c.GL_TEXTURE_MAG_FILTER, gl.c.GL_NEAREST);
    gl.TexParameteri(gl.c.GL_TEXTURE_2D, gl.c.GL_TEXTURE_WRAP_S, gl.c.GL_CLAMP_TO_EDGE);
    gl.TexParameteri(gl.c.GL_TEXTURE_2D, gl.c.GL_TEXTURE_WRAP_T, gl.c.GL_CLAMP_TO_EDGE);
    gl.PixelStorei(gl.c.GL_UNPACK_ALIGNMENT, 1);
    gl.TexImage2D(
        gl.c.GL_TEXTURE_2D,
        0,
        gl.c.GL_RGBA,
        width,
        height,
        0,
        gl.c.GL_RGBA,
        gl.c.GL_UNSIGNED_BYTE,
        &rgba,
    );
    return .{ .id = id, .width = width, .height = height };
}

fn createTextureEmpty(width: i32, height: i32, filter: i32) types.Texture {
    var id: gl.GLuint = 0;
    gl.GenTextures(1, &id);
    gl.BindTexture(gl.c.GL_TEXTURE_2D, id);
    gl.TexParameteri(gl.c.GL_TEXTURE_2D, gl.c.GL_TEXTURE_MIN_FILTER, filter);
    gl.TexParameteri(gl.c.GL_TEXTURE_2D, gl.c.GL_TEXTURE_MAG_FILTER, filter);
    gl.TexParameteri(gl.c.GL_TEXTURE_2D, gl.c.GL_TEXTURE_WRAP_S, gl.c.GL_CLAMP_TO_EDGE);
    gl.TexParameteri(gl.c.GL_TEXTURE_2D, gl.c.GL_TEXTURE_WRAP_T, gl.c.GL_CLAMP_TO_EDGE);
    gl.PixelStorei(gl.c.GL_UNPACK_ALIGNMENT, 1);
    gl.TexImage2D(
        gl.c.GL_TEXTURE_2D,
        0,
        gl.c.GL_RGBA,
        width,
        height,
        0,
        gl.c.GL_RGBA,
        gl.c.GL_UNSIGNED_BYTE,
        null,
    );
    return .{ .id = id, .width = width, .height = height };
}

fn getWindowSize(window: *sdl.SDL_Window) struct { w: i32, h: i32 } {
    var w: c_int = 0;
    var h: c_int = 0;
    sdl.SDL_GetWindowSize(window, &w, &h);
    return .{ .w = w, .h = h };
}

fn getDrawableSize(window: *sdl.SDL_Window) struct { w: i32, h: i32 } {
    var w: c_int = 0;
    var h: c_int = 0;
    sdl.SDL_GL_GetDrawableSize(window, &w, &h);
    return .{ .w = w, .h = h };
}

pub fn pollInputEvents() void {
    if (active_renderer) |renderer| {
        renderer.pollInputEvents();
    }
}

pub fn waitTime(seconds: f64) void {
    if (seconds <= 0) return;
    const total_ms = @as(u32, @intFromFloat(seconds * 1000.0));
    if (total_ms == 0) return;

    var remaining = total_ms;
    while (remaining > 0) {
        if (active_renderer) |renderer| {
            if (renderer.input_pending.load(.acquire)) return;
        }
        const step: u32 = if (remaining > 1) 1 else remaining;
        sdl.SDL_Delay(step);
        remaining -= step;
    }
}

pub fn getTime() f64 {
    if (active_renderer) |renderer| {
        const counter = sdl.SDL_GetPerformanceCounter();
        if (renderer.perf_freq <= 0) return 0.0;
        return @as(f64, @floatFromInt(counter - renderer.start_counter)) / renderer.perf_freq;
    }
    const counter = sdl.SDL_GetPerformanceCounter();
    const freq = sdl.SDL_GetPerformanceFrequency();
    if (freq == 0) return 0.0;
    return @as(f64, @floatFromInt(counter)) / @as(f64, @floatFromInt(freq));
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

pub const KEY_ENTER = @as(i32, @intCast(sdl.SDL_SCANCODE_RETURN));
pub const KEY_BACKSPACE = @as(i32, @intCast(sdl.SDL_SCANCODE_BACKSPACE));
pub const KEY_DELETE = @as(i32, @intCast(sdl.SDL_SCANCODE_DELETE));
pub const KEY_TAB = @as(i32, @intCast(sdl.SDL_SCANCODE_TAB));
pub const KEY_ESCAPE = @as(i32, @intCast(sdl.SDL_SCANCODE_ESCAPE));
pub const KEY_UP = @as(i32, @intCast(sdl.SDL_SCANCODE_UP));
pub const KEY_DOWN = @as(i32, @intCast(sdl.SDL_SCANCODE_DOWN));
pub const KEY_LEFT = @as(i32, @intCast(sdl.SDL_SCANCODE_LEFT));
pub const KEY_RIGHT = @as(i32, @intCast(sdl.SDL_SCANCODE_RIGHT));
pub const KEY_HOME = @as(i32, @intCast(sdl.SDL_SCANCODE_HOME));
pub const KEY_END = @as(i32, @intCast(sdl.SDL_SCANCODE_END));
pub const KEY_PAGE_UP = @as(i32, @intCast(sdl.SDL_SCANCODE_PAGEUP));
pub const KEY_PAGE_DOWN = @as(i32, @intCast(sdl.SDL_SCANCODE_PAGEDOWN));
pub const KEY_INSERT = @as(i32, @intCast(sdl.SDL_SCANCODE_INSERT));
pub const KEY_KP_0 = @as(i32, @intCast(sdl.SDL_SCANCODE_KP_0));
pub const KEY_KP_1 = @as(i32, @intCast(sdl.SDL_SCANCODE_KP_1));
pub const KEY_KP_2 = @as(i32, @intCast(sdl.SDL_SCANCODE_KP_2));
pub const KEY_KP_3 = @as(i32, @intCast(sdl.SDL_SCANCODE_KP_3));
pub const KEY_KP_4 = @as(i32, @intCast(sdl.SDL_SCANCODE_KP_4));
pub const KEY_KP_5 = @as(i32, @intCast(sdl.SDL_SCANCODE_KP_5));
pub const KEY_KP_6 = @as(i32, @intCast(sdl.SDL_SCANCODE_KP_6));
pub const KEY_KP_7 = @as(i32, @intCast(sdl.SDL_SCANCODE_KP_7));
pub const KEY_KP_8 = @as(i32, @intCast(sdl.SDL_SCANCODE_KP_8));
pub const KEY_KP_9 = @as(i32, @intCast(sdl.SDL_SCANCODE_KP_9));
pub const KEY_KP_DECIMAL = @as(i32, @intCast(sdl.SDL_SCANCODE_KP_DECIMAL));
pub const KEY_KP_DIVIDE = @as(i32, @intCast(sdl.SDL_SCANCODE_KP_DIVIDE));
pub const KEY_KP_MULTIPLY = @as(i32, @intCast(sdl.SDL_SCANCODE_KP_MULTIPLY));
pub const KEY_KP_SUBTRACT = @as(i32, @intCast(sdl.SDL_SCANCODE_KP_MINUS));
pub const KEY_KP_ADD = @as(i32, @intCast(sdl.SDL_SCANCODE_KP_PLUS));
pub const KEY_KP_ENTER = @as(i32, @intCast(sdl.SDL_SCANCODE_KP_ENTER));
pub const KEY_KP_EQUAL = @as(i32, @intCast(sdl.SDL_SCANCODE_KP_EQUALS));
pub const KEY_LEFT_CONTROL = @as(i32, @intCast(sdl.SDL_SCANCODE_LCTRL));
pub const KEY_RIGHT_CONTROL = @as(i32, @intCast(sdl.SDL_SCANCODE_RCTRL));
pub const KEY_LEFT_SHIFT = @as(i32, @intCast(sdl.SDL_SCANCODE_LSHIFT));
pub const KEY_RIGHT_SHIFT = @as(i32, @intCast(sdl.SDL_SCANCODE_RSHIFT));
pub const KEY_LEFT_ALT = @as(i32, @intCast(sdl.SDL_SCANCODE_LALT));
pub const KEY_RIGHT_ALT = @as(i32, @intCast(sdl.SDL_SCANCODE_RALT));
pub const KEY_LEFT_SUPER = @as(i32, @intCast(sdl.SDL_SCANCODE_LGUI));
pub const KEY_RIGHT_SUPER = @as(i32, @intCast(sdl.SDL_SCANCODE_RGUI));
pub const KEY_ZERO = @as(i32, @intCast(sdl.SDL_SCANCODE_0));
pub const KEY_ONE = @as(i32, @intCast(sdl.SDL_SCANCODE_1));
pub const KEY_TWO = @as(i32, @intCast(sdl.SDL_SCANCODE_2));
pub const KEY_THREE = @as(i32, @intCast(sdl.SDL_SCANCODE_3));
pub const KEY_FOUR = @as(i32, @intCast(sdl.SDL_SCANCODE_4));
pub const KEY_FIVE = @as(i32, @intCast(sdl.SDL_SCANCODE_5));
pub const KEY_SIX = @as(i32, @intCast(sdl.SDL_SCANCODE_6));
pub const KEY_SEVEN = @as(i32, @intCast(sdl.SDL_SCANCODE_7));
pub const KEY_EIGHT = @as(i32, @intCast(sdl.SDL_SCANCODE_8));
pub const KEY_NINE = @as(i32, @intCast(sdl.SDL_SCANCODE_9));
pub const KEY_SPACE = @as(i32, @intCast(sdl.SDL_SCANCODE_SPACE));
pub const KEY_MINUS = @as(i32, @intCast(sdl.SDL_SCANCODE_MINUS));
pub const KEY_EQUAL = @as(i32, @intCast(sdl.SDL_SCANCODE_EQUALS));
pub const KEY_LEFT_BRACKET = @as(i32, @intCast(sdl.SDL_SCANCODE_LEFTBRACKET));
pub const KEY_RIGHT_BRACKET = @as(i32, @intCast(sdl.SDL_SCANCODE_RIGHTBRACKET));
pub const KEY_BACKSLASH = @as(i32, @intCast(sdl.SDL_SCANCODE_BACKSLASH));
pub const KEY_SEMICOLON = @as(i32, @intCast(sdl.SDL_SCANCODE_SEMICOLON));
pub const KEY_APOSTROPHE = @as(i32, @intCast(sdl.SDL_SCANCODE_APOSTROPHE));
pub const KEY_GRAVE = @as(i32, @intCast(sdl.SDL_SCANCODE_GRAVE));
pub const KEY_COMMA = @as(i32, @intCast(sdl.SDL_SCANCODE_COMMA));
pub const KEY_PERIOD = @as(i32, @intCast(sdl.SDL_SCANCODE_PERIOD));
pub const KEY_SLASH = @as(i32, @intCast(sdl.SDL_SCANCODE_SLASH));
pub const KEY_S = @as(i32, @intCast(sdl.SDL_SCANCODE_S));
pub const KEY_Z = @as(i32, @intCast(sdl.SDL_SCANCODE_Z));
pub const KEY_Y = @as(i32, @intCast(sdl.SDL_SCANCODE_Y));
pub const KEY_C = @as(i32, @intCast(sdl.SDL_SCANCODE_C));
pub const KEY_V = @as(i32, @intCast(sdl.SDL_SCANCODE_V));
pub const KEY_X = @as(i32, @intCast(sdl.SDL_SCANCODE_X));
pub const KEY_A = @as(i32, @intCast(sdl.SDL_SCANCODE_A));
pub const KEY_B = @as(i32, @intCast(sdl.SDL_SCANCODE_B));
pub const KEY_D = @as(i32, @intCast(sdl.SDL_SCANCODE_D));
pub const KEY_E = @as(i32, @intCast(sdl.SDL_SCANCODE_E));
pub const KEY_F = @as(i32, @intCast(sdl.SDL_SCANCODE_F));
pub const KEY_G = @as(i32, @intCast(sdl.SDL_SCANCODE_G));
pub const KEY_H = @as(i32, @intCast(sdl.SDL_SCANCODE_H));
pub const KEY_I = @as(i32, @intCast(sdl.SDL_SCANCODE_I));
pub const KEY_J = @as(i32, @intCast(sdl.SDL_SCANCODE_J));
pub const KEY_K = @as(i32, @intCast(sdl.SDL_SCANCODE_K));
pub const KEY_L = @as(i32, @intCast(sdl.SDL_SCANCODE_L));
pub const KEY_M = @as(i32, @intCast(sdl.SDL_SCANCODE_M));
pub const KEY_N = @as(i32, @intCast(sdl.SDL_SCANCODE_N));
pub const KEY_O = @as(i32, @intCast(sdl.SDL_SCANCODE_O));
pub const KEY_P = @as(i32, @intCast(sdl.SDL_SCANCODE_P));
pub const KEY_Q = @as(i32, @intCast(sdl.SDL_SCANCODE_Q));
pub const KEY_R = @as(i32, @intCast(sdl.SDL_SCANCODE_R));
pub const KEY_T = @as(i32, @intCast(sdl.SDL_SCANCODE_T));
pub const KEY_U = @as(i32, @intCast(sdl.SDL_SCANCODE_U));
pub const KEY_W = @as(i32, @intCast(sdl.SDL_SCANCODE_W));

pub const MOUSE_LEFT = @as(i32, @intCast(sdl.SDL_BUTTON_LEFT));
pub const MOUSE_RIGHT = @as(i32, @intCast(sdl.SDL_BUTTON_RIGHT));
pub const MOUSE_MIDDLE = @as(i32, @intCast(sdl.SDL_BUTTON_MIDDLE));
