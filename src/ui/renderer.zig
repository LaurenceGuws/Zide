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
const terminal_underline = @import("renderer/terminal_underline.zig");
const texture_draw = @import("renderer/texture_draw.zig");
const input_logging = @import("renderer/input_logging.zig");
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
const WindowSizes = struct {
    width: i32,
    height: i32,
    render_width: i32,
    render_height: i32,
};

var active_renderer: ?*Renderer = null;
var mouse_wheel_delta: f32 = 0.0;
var sdl3_textinput_layout_logged: bool = false;
var sdl3_textediting_layout_logged: bool = false;
var sdl_input_env_logged: bool = false;
const presentation_grid_side: usize = 3;
const presentation_grid_samples: usize = presentation_grid_side * presentation_grid_side;
const presentation_delta_threshold: u16 = 24;
const max_presentation_probes: usize = 16;

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
pub const PresentationProbeKind = enum {
    bg2,
    direct,
};

const PresentationReadBuffer = enum {
    front,
    back,
};

const PresentEdgeFallbackMode = enum {
    off,
    copy_back_to_front,
    finish_before_swap,
    finish_before_and_after_swap,
    swap_interval_0,
    swap_interval_0_cap_60hz,
    swap_interval_0_finish_before_swap,
    swap_interval_0_finish_before_and_after_swap,
    swap_interval_0_force_full_terminal_texture,
    swap_interval_0_force_full_terminal_texture_every_frame,
    swap_interval_0_force_full_terminal_texture_recovery_500ms,
    swap_interval_0_force_full_terminal_texture_recovery_2000ms,
    swap_interval_0_force_full_terminal_texture_recent_input_2000ms,
    swap_interval_0_force_full_terminal_texture_recent_input_1000ms,
    swap_interval_0_force_full_terminal_texture_recent_input_500ms,
    swap_interval_0_force_full_terminal_texture_recent_input_375ms,
    swap_interval_0_force_full_terminal_texture_recent_input_350ms,
    swap_interval_0_force_full_terminal_texture_recent_input_300ms,
    swap_interval_0_force_full_terminal_texture_recent_input_250ms,
};

const PresentationGridSample = struct {
    pixels: [presentation_grid_samples]types.Rgba = undefined,
    valid: [presentation_grid_samples]bool = [_]bool{false} ** presentation_grid_samples,
};

const PresentationGridDiff = struct {
    hits: usize = 0,
    samples: usize = 0,
    max_delta: u16 = 0,
};

const presentation_band_cols: usize = 8;
const presentation_band_rows: usize = 3;
const presentation_band_samples: usize = presentation_band_cols * presentation_band_rows;

const PresentationBandSample = struct {
    pixels: [presentation_band_samples]types.Rgba = undefined,
    valid: [presentation_band_samples]bool = [_]bool{false} ** presentation_band_samples,
};

const PresentationBandDiff = struct {
    hits: usize = 0,
    samples: usize = 0,
    max_delta: u16 = 0,
};

const PresentationProbe = struct {
    present: bool = false,
    kind: PresentationProbeKind = .direct,
    row: usize = 0,
    slot: isize = 0,
    col: usize = 0,
    codepoint: u32 = 0,
    logical_x: f32 = 0.0,
    logical_y: f32 = 0.0,
    fg: Color = Color.black,
    bg: Color = Color.black,
    baseline: PresentationGridSample = .{},
};

const PresentedProbeHistory = struct {
    present: bool = false,
    kind: PresentationProbeKind = .direct,
    row: usize = 0,
    slot: isize = 0,
    col: usize = 0,
    codepoint: u32 = 0,
    grid: PresentationGridSample = .{},
};

const FinalProbeHistory = struct {
    present: bool = false,
    kind: PresentationProbeKind = .direct,
    row: usize = 0,
    slot: isize = 0,
    col: usize = 0,
    codepoint: u32 = 0,
    grid: PresentationGridSample = .{},
};

const PreSwapProbeCapture = struct {
    present: bool = false,
    back_grid: PresentationGridSample = .{},
    front_grid: PresentationGridSample = .{},
};

const PreFallbackProbeCapture = struct {
    present: bool = false,
    front_grid: PresentationGridSample = .{},
};

pub const FrameSubmission = struct {
    succeeded: bool,
    sequence: u64,
};

const PresentationBandProbe = struct {
    present: bool = false,
    axis: enum {
        row,
        column,
    } = .row,
    row_start: usize = 0,
    row_end: usize = 0,
    col_start: usize = 0,
    col_end: usize = 0,
    logical_x: f32 = 0.0,
    logical_y: f32 = 0.0,
    logical_width: f32 = 0.0,
    logical_height: f32 = 0.0,
    baseline: PresentationBandSample = .{},
};

const PreSwapBandCapture = struct {
    present: bool = false,
    back_sample: PresentationBandSample = .{},
    front_sample: PresentationBandSample = .{},
};

const SwapGlState = struct {
    read_buffer: i32 = 0,
    draw_buffer: i32 = 0,
    framebuffer_binding: i32 = 0,
    read_framebuffer_binding: i32 = 0,
    draw_framebuffer_binding: i32 = 0,
};
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

fn parsePresentEdgeFallbackMode() PresentEdgeFallbackMode {
    const raw = std.c.getenv("ZIDE_PRESENT_EDGE_FALLBACK") orelse return .off;
    const slice = std.mem.sliceTo(raw, 0);
    if (slice.len == 0) return .off;
    if (std.mem.eql(u8, slice, "1") or
        std.ascii.eqlIgnoreCase(slice, "true") or
        std.ascii.eqlIgnoreCase(slice, "yes") or
        std.ascii.eqlIgnoreCase(slice, "on") or
        std.ascii.eqlIgnoreCase(slice, "copy_back_to_front"))
    {
        return .copy_back_to_front;
    }
    if (std.ascii.eqlIgnoreCase(slice, "finish_before_swap")) return .finish_before_swap;
    if (std.ascii.eqlIgnoreCase(slice, "finish_before_and_after_swap")) return .finish_before_and_after_swap;
    if (std.ascii.eqlIgnoreCase(slice, "swap_interval_0")) return .swap_interval_0;
    if (std.ascii.eqlIgnoreCase(slice, "swap_interval_0_cap_60hz")) return .swap_interval_0_cap_60hz;
    if (std.ascii.eqlIgnoreCase(slice, "swap_interval_0_finish_before_swap")) return .swap_interval_0_finish_before_swap;
    if (std.ascii.eqlIgnoreCase(slice, "swap_interval_0_finish_before_and_after_swap")) return .swap_interval_0_finish_before_and_after_swap;
    if (std.ascii.eqlIgnoreCase(slice, "swap_interval_0_force_full_terminal_texture")) return .swap_interval_0_force_full_terminal_texture;
    if (std.ascii.eqlIgnoreCase(slice, "swap_interval_0_force_full_terminal_texture_every_frame")) return .swap_interval_0_force_full_terminal_texture_every_frame;
    if (std.ascii.eqlIgnoreCase(slice, "swap_interval_0_force_full_terminal_texture_recovery_500ms")) return .swap_interval_0_force_full_terminal_texture_recovery_500ms;
    if (std.ascii.eqlIgnoreCase(slice, "swap_interval_0_force_full_terminal_texture_recovery_2000ms")) return .swap_interval_0_force_full_terminal_texture_recovery_2000ms;
    if (std.ascii.eqlIgnoreCase(slice, "swap_interval_0_force_full_terminal_texture_recent_input_2000ms")) return .swap_interval_0_force_full_terminal_texture_recent_input_2000ms;
    if (std.ascii.eqlIgnoreCase(slice, "swap_interval_0_force_full_terminal_texture_recent_input_1000ms")) return .swap_interval_0_force_full_terminal_texture_recent_input_1000ms;
    if (std.ascii.eqlIgnoreCase(slice, "swap_interval_0_force_full_terminal_texture_recent_input_500ms")) return .swap_interval_0_force_full_terminal_texture_recent_input_500ms;
    if (std.ascii.eqlIgnoreCase(slice, "swap_interval_0_force_full_terminal_texture_recent_input_375ms")) return .swap_interval_0_force_full_terminal_texture_recent_input_375ms;
    if (std.ascii.eqlIgnoreCase(slice, "swap_interval_0_force_full_terminal_texture_recent_input_350ms")) return .swap_interval_0_force_full_terminal_texture_recent_input_350ms;
    if (std.ascii.eqlIgnoreCase(slice, "swap_interval_0_force_full_terminal_texture_recent_input_300ms")) return .swap_interval_0_force_full_terminal_texture_recent_input_300ms;
    if (std.ascii.eqlIgnoreCase(slice, "swap_interval_0_force_full_terminal_texture_recent_input_250ms")) return .swap_interval_0_force_full_terminal_texture_recent_input_250ms;
    return .off;
}

fn parseTerminalPresentMitigationDisabled() bool {
    const raw = std.c.getenv("ZIDE_DEBUG_DISABLE_TERMINAL_PRESENT_MITIGATION") orelse return false;
    const slice = std.mem.sliceTo(raw, 0);
    if (slice.len == 0) return false;
    if (std.mem.eql(u8, slice, "1") or std.ascii.eqlIgnoreCase(slice, "true") or std.ascii.eqlIgnoreCase(slice, "yes") or std.ascii.eqlIgnoreCase(slice, "on")) return true;
    if (std.mem.eql(u8, slice, "0") or std.ascii.eqlIgnoreCase(slice, "false") or std.ascii.eqlIgnoreCase(slice, "no") or std.ascii.eqlIgnoreCase(slice, "off")) return false;
    return false;
}

fn presentEdgeFallbackName(mode: PresentEdgeFallbackMode) []const u8 {
    return switch (mode) {
        .off => "off",
        .copy_back_to_front => "copy_back_to_front",
        .finish_before_swap => "finish_before_swap",
        .finish_before_and_after_swap => "finish_before_and_after_swap",
        .swap_interval_0 => "swap_interval_0",
        .swap_interval_0_cap_60hz => "swap_interval_0_cap_60hz",
        .swap_interval_0_finish_before_swap => "swap_interval_0_finish_before_swap",
        .swap_interval_0_finish_before_and_after_swap => "swap_interval_0_finish_before_and_after_swap",
        .swap_interval_0_force_full_terminal_texture => "swap_interval_0_force_full_terminal_texture",
        .swap_interval_0_force_full_terminal_texture_every_frame => "swap_interval_0_force_full_terminal_texture_every_frame",
        .swap_interval_0_force_full_terminal_texture_recovery_500ms => "swap_interval_0_force_full_terminal_texture_recovery_500ms",
        .swap_interval_0_force_full_terminal_texture_recovery_2000ms => "swap_interval_0_force_full_terminal_texture_recovery_2000ms",
        .swap_interval_0_force_full_terminal_texture_recent_input_2000ms => "swap_interval_0_force_full_terminal_texture_recent_input_2000ms",
        .swap_interval_0_force_full_terminal_texture_recent_input_1000ms => "swap_interval_0_force_full_terminal_texture_recent_input_1000ms",
        .swap_interval_0_force_full_terminal_texture_recent_input_500ms => "swap_interval_0_force_full_terminal_texture_recent_input_500ms",
        .swap_interval_0_force_full_terminal_texture_recent_input_375ms => "swap_interval_0_force_full_terminal_texture_recent_input_375ms",
        .swap_interval_0_force_full_terminal_texture_recent_input_350ms => "swap_interval_0_force_full_terminal_texture_recent_input_350ms",
        .swap_interval_0_force_full_terminal_texture_recent_input_300ms => "swap_interval_0_force_full_terminal_texture_recent_input_300ms",
        .swap_interval_0_force_full_terminal_texture_recent_input_250ms => "swap_interval_0_force_full_terminal_texture_recent_input_250ms",
    };
}

fn compositorName(kind: compositor.Compositor) []const u8 {
    return switch (kind) {
        .hyprland => "hyprland",
        .kde => "kde",
        .unknown => "unknown",
    };
}

const key_repeat_key_count: usize = sdl_api.scancode_count;
const mouse_button_count: usize = 8;
const input_queue_capacity: usize = 8192;
const KeyPress = input_state.KeyPress;

const RenderTarget = targets.RenderTarget;

const BatchDraw = draw_ops.BatchDraw;
const Vertex = draw_ops.Vertex;

const SceneTargetInvalidation = packed struct(u8) {
    uninitialized: bool = false,
    drawable_resize: bool = false,
    display_change: bool = false,
    render_scale_change: bool = false,
    target_recreate_failure: bool = false,
    _padding: u3 = 0,

    fn any(self: SceneTargetInvalidation) bool {
        return self.uninitialized or
            self.drawable_resize or
            self.display_change or
            self.render_scale_change or
            self.target_recreate_failure;
    }
};

const SceneTargetContract = struct {
    logical_width: i32 = 0,
    logical_height: i32 = 0,
    drawable_width: i32 = 0,
    drawable_height: i32 = 0,
    display_index: i32 = -1,
    render_scale: f32 = 1.0,
};

const SceneTargetState = struct {
    target: ?RenderTarget = null,
    contract: SceneTargetContract = .{},
    invalidation: SceneTargetInvalidation = .{ .uninitialized = true },
    ready: bool = false,
};

fn logSceneTargetState(
    logger: app_logger.Logger,
    event: []const u8,
    contract: SceneTargetContract,
    invalidation: SceneTargetInvalidation,
    ready: bool,
) void {
    if (!(logger.enabled_console or logger.enabled_file)) return;
    logger.logf(
        .info,
        "event={s} ready={d} logical={d}x{d} drawable={d}x{d} display={d} render_scale={d:.3} invalidation=uninitialized:{d},drawable_resize:{d},display_change:{d},render_scale_change:{d},target_recreate_failure:{d}",
        .{
            event,
            @intFromBool(ready),
            contract.logical_width,
            contract.logical_height,
            contract.drawable_width,
            contract.drawable_height,
            contract.display_index,
            contract.render_scale,
            @intFromBool(invalidation.uninitialized),
            @intFromBool(invalidation.drawable_resize),
            @intFromBool(invalidation.display_change),
            @intFromBool(invalidation.render_scale_change),
            @intFromBool(invalidation.target_recreate_failure),
        },
    );
}

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
    terminal_recent_input_force_full_enabled: bool,
    terminal_recent_input_force_full_window_seconds: f64,
    terminal_present_mitigation_debug_disabled: bool,
    present_edge_fallback_mode: PresentEdgeFallbackMode,

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
    terminal_scroll_target: ?RenderTarget,
    editor_target: ?RenderTarget,
    scene_target: SceneTargetState,

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
    window_focused: bool,
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
    terminal_shape_buffer: *hb.hb_buffer_t,
    terminal_shape_first_pen: std.ArrayListUnmanaged(f32),
    terminal_shape_first_pen_set: std.ArrayListUnmanaged(bool),
    should_close_flag: bool,
    window_resized_flag: bool,
    text_input_state: text_input.TextInputState,

    start_counter: u64,
    perf_freq: f64,
    frame_seq: u64,
    submission_sequence: u64,
    last_present_counter: u64,
    last_present_gap_ms: f64,
    last_swap_ms: f64,
    last_present_cap_counter: u64,
    presentation_probe_count: usize,
    presentation_probes: [max_presentation_probes]PresentationProbe,
    presentation_band_probe_count: usize,
    presentation_band_probes: [max_presentation_probes]PresentationBandProbe,
    pre_fallback_probe_count: usize,
    pre_fallback_probes: [max_presentation_probes]PreFallbackProbeCapture,
    pre_swap_probe_count: usize,
    pre_swap_probes: [max_presentation_probes]PreSwapProbeCapture,
    pre_swap_band_probe_count: usize,
    pre_swap_band_probes: [max_presentation_probes]PreSwapBandCapture,
    pre_swap_gl_state: SwapGlState,
    previous_present_probe_count: usize,
    previous_present_probes: [max_presentation_probes]PresentedProbeHistory,
    previous_final_probe_count: usize,
    previous_final_probes: [max_presentation_probes]FinalProbeHistory,

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

        try window_init.configureGlAttributes();

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
        const terminal_shape_buffer = hb.hb_buffer_create() orelse return error.OutOfMemory;

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
            .terminal_recent_input_force_full_enabled = true,
            .terminal_recent_input_force_full_window_seconds = 0.375,
            .terminal_present_mitigation_debug_disabled = parseTerminalPresentMitigationDisabled(),
            .present_edge_fallback_mode = parsePresentEdgeFallbackMode(),
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
            .terminal_scroll_target = null,
            .editor_target = null,
            .scene_target = .{},
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
            .window_focused = true,
            .composing_text = std.ArrayList(u8).empty,
            .composing_cursor = 0,
            .composing_selection_len = 0,
            .composing_active = false,
            .sdl_input = .{},
            .clipboard_buffer = std.ArrayList(u8).empty,
            .batch_vertices = std.ArrayList(Vertex).empty,
            .batch_draws = std.ArrayList(BatchDraw).empty,
            .terminal_glyph_cache = glyph_cache.GlyphCache.init(allocator),
            .terminal_shape_buffer = terminal_shape_buffer,
            .terminal_shape_first_pen = .{},
            .terminal_shape_first_pen_set = .{},
            .should_close_flag = false,
            .window_resized_flag = false,
            .text_input_state = text_input.initState(),
            .start_counter = sdl_api.getPerformanceCounter(),
            .perf_freq = @as(f64, @floatFromInt(sdl_api.getPerformanceFrequency())),
            .frame_seq = 0,
            .submission_sequence = 0,
            .last_present_counter = 0,
            .last_present_gap_ms = 0.0,
            .last_swap_ms = 0.0,
            .last_present_cap_counter = 0,
            .presentation_probe_count = 0,
            .presentation_probes = [_]PresentationProbe{.{}} ** max_presentation_probes,
            .presentation_band_probe_count = 0,
            .presentation_band_probes = [_]PresentationBandProbe{.{}} ** max_presentation_probes,
            .pre_fallback_probe_count = 0,
            .pre_fallback_probes = [_]PreFallbackProbeCapture{.{}} ** max_presentation_probes,
            .pre_swap_probe_count = 0,
            .pre_swap_probes = [_]PreSwapProbeCapture{.{}} ** max_presentation_probes,
            .pre_swap_band_probe_count = 0,
            .pre_swap_band_probes = [_]PreSwapBandCapture{.{}} ** max_presentation_probes,
            .pre_swap_gl_state = .{},
            .previous_present_probe_count = 0,
            .previous_present_probes = [_]PresentedProbeHistory{.{}} ** max_presentation_probes,
            .previous_final_probe_count = 0,
            .previous_final_probes = [_]FinalProbeHistory{.{}} ** max_presentation_probes,
        };

        if ((renderer.present_edge_fallback_mode == .off and !renderer.terminal_present_mitigation_debug_disabled) or
            renderer.present_edge_fallback_mode == .swap_interval_0 or
            renderer.present_edge_fallback_mode == .swap_interval_0_cap_60hz or
            renderer.present_edge_fallback_mode == .swap_interval_0_finish_before_swap or
            renderer.present_edge_fallback_mode == .swap_interval_0_finish_before_and_after_swap or
            renderer.present_edge_fallback_mode == .swap_interval_0_force_full_terminal_texture or
            renderer.present_edge_fallback_mode == .swap_interval_0_force_full_terminal_texture_every_frame or
            renderer.present_edge_fallback_mode == .swap_interval_0_force_full_terminal_texture_recovery_500ms or
            renderer.present_edge_fallback_mode == .swap_interval_0_force_full_terminal_texture_recovery_2000ms or
            renderer.present_edge_fallback_mode == .swap_interval_0_force_full_terminal_texture_recent_input_2000ms or
            renderer.present_edge_fallback_mode == .swap_interval_0_force_full_terminal_texture_recent_input_1000ms or
            renderer.present_edge_fallback_mode == .swap_interval_0_force_full_terminal_texture_recent_input_500ms or
            renderer.present_edge_fallback_mode == .swap_interval_0_force_full_terminal_texture_recent_input_375ms or
            renderer.present_edge_fallback_mode == .swap_interval_0_force_full_terminal_texture_recent_input_350ms or
            renderer.present_edge_fallback_mode == .swap_interval_0_force_full_terminal_texture_recent_input_300ms or
            renderer.present_edge_fallback_mode == .swap_interval_0_force_full_terminal_texture_recent_input_250ms)
        {
            if (!sdl_api.glSetSwapInterval(0)) {
                app_logger.logger("sdl.gl").logStdout(.warning, "SDL_GL_SetSwapInterval failed interval=0 err={s}", .{sdl_api.getError()});
            }
        }

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
        self.destroyRenderTarget(&self.terminal_scroll_target);
        self.destroyRenderTarget(&self.editor_target);
        self.destroyRenderTarget(&self.scene_target.target);

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
        hb.hb_buffer_destroy(self.terminal_shape_buffer);

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

    pub fn setTerminalRecentInputFullPublicationPolicy(self: *Renderer, enabled: bool, window_ms: ?usize) void {
        self.terminal_recent_input_force_full_enabled = enabled;
        if (window_ms) |value| {
            const clamped_ms = std.math.clamp(value, 50, 5000);
            self.terminal_recent_input_force_full_window_seconds = @as(f64, @floatFromInt(clamped_ms)) / 1000.0;
        }
    }

    pub fn terminalRecentInputFullPublicationEnabled(self: *const Renderer) bool {
        if (self.terminal_present_mitigation_debug_disabled) return false;
        if (self.present_edge_fallback_mode != .off) {
            return self.present_edge_fallback_mode == .swap_interval_0_force_full_terminal_texture_recent_input_2000ms or
                self.present_edge_fallback_mode == .swap_interval_0_force_full_terminal_texture_recent_input_1000ms or
                self.present_edge_fallback_mode == .swap_interval_0_force_full_terminal_texture_recent_input_500ms or
                self.present_edge_fallback_mode == .swap_interval_0_force_full_terminal_texture_recent_input_375ms or
                self.present_edge_fallback_mode == .swap_interval_0_force_full_terminal_texture_recent_input_350ms or
                self.present_edge_fallback_mode == .swap_interval_0_force_full_terminal_texture_recent_input_300ms or
                self.present_edge_fallback_mode == .swap_interval_0_force_full_terminal_texture_recent_input_250ms;
        }
        return self.terminal_recent_input_force_full_enabled;
    }

    pub fn terminalRecentInputFullPublicationConfiguredEnabled(self: *const Renderer) bool {
        return self.terminal_recent_input_force_full_enabled;
    }

    pub fn terminalRecentInputFullPublicationWindowSeconds(self: *const Renderer) f64 {
        if (!self.terminalRecentInputFullPublicationEnabled()) return 0.0;
        if (self.present_edge_fallback_mode != .off) {
            return switch (self.present_edge_fallback_mode) {
                .swap_interval_0_force_full_terminal_texture_recent_input_250ms => 0.25,
                .swap_interval_0_force_full_terminal_texture_recent_input_300ms => 0.3,
                .swap_interval_0_force_full_terminal_texture_recent_input_350ms => 0.35,
                .swap_interval_0_force_full_terminal_texture_recent_input_375ms => 0.375,
                .swap_interval_0_force_full_terminal_texture_recent_input_500ms => 0.5,
                .swap_interval_0_force_full_terminal_texture_recent_input_1000ms => 1.0,
                .swap_interval_0_force_full_terminal_texture_recent_input_2000ms => 2.0,
                else => 0.0,
            };
        }
        return self.terminal_recent_input_force_full_window_seconds;
    }

    pub fn terminalRecentInputFullPublicationWindowMs(self: *const Renderer) usize {
        return @intFromFloat(std.math.round(self.terminalRecentInputFullPublicationWindowSeconds() * 1000.0));
    }

    pub fn terminalPresentMitigationDebugDisabled(self: *const Renderer) bool {
        return self.terminal_present_mitigation_debug_disabled;
    }

    pub fn forceFullTerminalTexturePublication(self: *const Renderer) bool {
        return self.present_edge_fallback_mode == .swap_interval_0_force_full_terminal_texture or
            self.present_edge_fallback_mode == .swap_interval_0_force_full_terminal_texture_every_frame;
    }

    pub fn forceFullTerminalTexturePublicationEveryFrame(self: *const Renderer) bool {
        return self.present_edge_fallback_mode == .swap_interval_0_force_full_terminal_texture_every_frame;
    }

    pub fn forceFullTerminalTexturePublicationRecoveryWindow(self: *const Renderer) bool {
        return self.present_edge_fallback_mode == .swap_interval_0_force_full_terminal_texture_recovery_500ms or
            self.present_edge_fallback_mode == .swap_interval_0_force_full_terminal_texture_recovery_2000ms;
    }

    pub fn fullTerminalTexturePublicationRecoveryWindowSeconds(self: *const Renderer) f64 {
        return switch (self.present_edge_fallback_mode) {
            .swap_interval_0_force_full_terminal_texture_recovery_500ms => 0.5,
            .swap_interval_0_force_full_terminal_texture_recovery_2000ms => 2.0,
            else => 0.0,
        };
    }

    pub fn forceFullTerminalTexturePublicationRecentInputWindow(self: *const Renderer) bool {
        return self.terminalRecentInputFullPublicationEnabled();
    }

    pub fn fullTerminalTexturePublicationRecentInputWindowSeconds(self: *const Renderer) f64 {
        return self.terminalRecentInputFullPublicationWindowSeconds();
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
        self.frame_seq +%= 1;
        const sizes = refreshWindowSizes(self.window);
        self.width = sizes.width;
        self.height = sizes.height;
        self.render_width = sizes.render_width;
        self.render_height = sizes.render_height;
        self.refreshSceneTargetContract();
        self.prepareSceneTarget(target_draw.nearestFilter());

        // Avoid leaking background context across different text draws.
        self.text_bg_rgba = .{ .r = 0, .g = 0, .b = 0, .a = 0 };

        self.bindMainCompositionTarget();
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
        self.presentation_probe_count = 0;
        self.presentation_band_probe_count = 0;
    }

    pub fn endFrame(self: *Renderer) bool {
        self.drawSceneTargetToDefault();
        const swap_start = sdl_api.getPerformanceCounter();
        if (self.present_edge_fallback_mode == .copy_back_to_front) self.capturePreFallbackFrameProbes();
        self.applyPreSwapFallback();
        self.capturePreSwapBackFrameProbes();
        const swap_ok = sdl_api.glSwapWindow(self.window);
        if (!swap_ok) {
            app_logger.logger("sdl.gl").logStdout(.warning, "SDL_GL_SwapWindow failed err={s}", .{sdl_api.getError()});
        }
        const swap_end = sdl_api.getPerformanceCounter();
        self.last_swap_ms = performanceDeltaMs(swap_start, swap_end, self.perf_freq);
        self.applyPostSwapFallback();
        self.logPresentedFrameProbes();
        self.presentation_probe_count = 0;
        self.presentation_band_probe_count = 0;
        self.applyPresentFrameCap();
        return swap_ok;
    }

    pub fn submitFrame(self: *Renderer) FrameSubmission {
        const succeeded = self.endFrame();
        if (succeeded) self.submission_sequence += 1;
        return .{
            .succeeded = succeeded,
            .sequence = self.submission_sequence,
        };
    }

    fn performanceDeltaMs(start: u64, end: u64, freq: f64) f64 {
        if (end <= start or freq <= 0.0) return 0.0;
        return (@as(f64, @floatFromInt(end - start)) * 1000.0) / freq;
    }

    fn applyPresentFrameCap(self: *Renderer) void {
        if (self.present_edge_fallback_mode != .swap_interval_0_cap_60hz) return;
        const cap_counter = sdl_api.getPerformanceCounter();
        defer self.last_present_cap_counter = sdl_api.getPerformanceCounter();
        if (self.last_present_cap_counter == 0 or self.perf_freq <= 0.0) return;
        const elapsed_ms = performanceDeltaMs(self.last_present_cap_counter, cap_counter, self.perf_freq);
        const target_ms = 1000.0 / 60.0;
        if (elapsed_ms >= target_ms) return;
        time_utils.waitTime((target_ms - elapsed_ms) / 1000.0);
    }

    fn applyPreSwapFallback(self: *Renderer) void {
        switch (self.present_edge_fallback_mode) {
            .off => {},
            .copy_back_to_front => self.copyBackBufferToFrontBuffer(),
            .finish_before_swap => gl.Finish(),
            .finish_before_and_after_swap => gl.Finish(),
            .swap_interval_0 => {},
            .swap_interval_0_cap_60hz => {},
            .swap_interval_0_finish_before_swap => gl.Finish(),
            .swap_interval_0_finish_before_and_after_swap => gl.Finish(),
            .swap_interval_0_force_full_terminal_texture => {},
            .swap_interval_0_force_full_terminal_texture_every_frame => {},
            .swap_interval_0_force_full_terminal_texture_recovery_500ms => {},
            .swap_interval_0_force_full_terminal_texture_recovery_2000ms => {},
            .swap_interval_0_force_full_terminal_texture_recent_input_2000ms => {},
            .swap_interval_0_force_full_terminal_texture_recent_input_1000ms => {},
            .swap_interval_0_force_full_terminal_texture_recent_input_500ms => {},
            .swap_interval_0_force_full_terminal_texture_recent_input_375ms => {},
            .swap_interval_0_force_full_terminal_texture_recent_input_350ms => {},
            .swap_interval_0_force_full_terminal_texture_recent_input_300ms => {},
            .swap_interval_0_force_full_terminal_texture_recent_input_250ms => {},
        }
    }

    fn applyPostSwapFallback(self: *Renderer) void {
        switch (self.present_edge_fallback_mode) {
            .finish_before_and_after_swap => gl.Finish(),
            .swap_interval_0_finish_before_and_after_swap => gl.Finish(),
            else => {},
        }
    }

    fn copyBackBufferToFrontBuffer(self: *Renderer) void {
        if (self.render_width <= 0 or self.render_height <= 0) return;
        self.bindDefaultTarget();
        gl.BindFramebuffer(gl.c.GL_READ_FRAMEBUFFER, 0);
        gl.BindFramebuffer(gl.c.GL_DRAW_FRAMEBUFFER, 0);
        gl.ReadBuffer(gl.c.GL_BACK);
        gl.DrawBuffer(gl.c.GL_FRONT);
        gl.BlitFramebuffer(
            0,
            0,
            self.render_width,
            self.render_height,
            0,
            0,
            self.render_width,
            self.render_height,
            gl.c.GL_COLOR_BUFFER_BIT,
            gl.c.GL_NEAREST,
        );
        // Keep subsequent frames on the normal back-buffer draw/read path.
        gl.DrawBuffer(gl.c.GL_BACK);
        gl.ReadBuffer(gl.c.GL_BACK);
        gl.BindFramebuffer(gl.c.GL_FRAMEBUFFER, 0);
    }

    fn refreshWindowSizes(window: *sdl.SDL_Window) WindowSizes {
        const window_size = platform_window.getWindowSize(window);
        const drawable = platform_window.getDrawableSize(window);
        return .{
            .width = window_size.w,
            .height = window_size.h,
            .render_width = drawable.w,
            .render_height = drawable.h,
        };
    }

    fn sceneTargetContractSnapshot(self: *const Renderer) SceneTargetContract {
        return .{
            .logical_width = self.width,
            .logical_height = self.height,
            .drawable_width = self.render_width,
            .drawable_height = self.render_height,
            .display_index = sdl_api.getWindowDisplayIndex(self.window),
            .render_scale = platform_window.getRenderScale(self.window),
        };
    }

    fn refreshSceneTargetContract(self: *Renderer) void {
        const log = app_logger.logger("renderer.scene_target");
        const next = self.sceneTargetContractSnapshot();
        var reasons: SceneTargetInvalidation = .{};
        const previous = self.scene_target.contract;

        if (!self.scene_target.ready and self.scene_target.target == null) {
            reasons.uninitialized = true;
        }
        if (previous.drawable_width != next.drawable_width or
            previous.drawable_height != next.drawable_height or
            previous.logical_width != next.logical_width or
            previous.logical_height != next.logical_height)
        {
            reasons.drawable_resize = true;
        }
        if (previous.display_index != next.display_index) {
            reasons.display_change = true;
        }
        if (!std.math.approxEqAbs(f32, previous.render_scale, next.render_scale, 0.0001)) {
            reasons.render_scale_change = true;
        }

        self.scene_target.contract = next;
        if (!reasons.any()) return;

        self.scene_target.invalidation = reasons;
        self.scene_target.ready = false;
        if (self.scene_target.target != null) {
            self.destroyRenderTarget(&self.scene_target.target);
        }
        logSceneTargetState(log, "invalidate", self.scene_target.contract, self.scene_target.invalidation, self.scene_target.ready);
    }

    fn noteSceneTargetRecreateFailure(self: *Renderer) void {
        self.scene_target.invalidation.target_recreate_failure = true;
        self.scene_target.ready = false;
        logSceneTargetState(
            app_logger.logger("renderer.scene_target"),
            "recreate_failed",
            self.scene_target.contract,
            self.scene_target.invalidation,
            self.scene_target.ready,
        );
    }

    fn clearSceneTargetInvalidation(self: *Renderer) void {
        self.scene_target.invalidation = .{};
        self.scene_target.ready = true;
        logSceneTargetState(
            app_logger.logger("renderer.scene_target"),
            "ready",
            self.scene_target.contract,
            self.scene_target.invalidation,
            self.scene_target.ready,
        );
    }

    fn ensureSceneTarget(self: *Renderer, filter: i32) bool {
        const contract = self.scene_target.contract;
        if (contract.logical_width <= 0 or contract.logical_height <= 0 or
            contract.drawable_width <= 0 or contract.drawable_height <= 0)
        {
            self.noteSceneTargetRecreateFailure();
            return false;
        }

        const recreated = self.ensureRenderTargetScaled(
            &self.scene_target.target,
            contract.logical_width,
            contract.logical_height,
            filter,
        );
        if (self.scene_target.target == null) {
            self.noteSceneTargetRecreateFailure();
            return false;
        }
        if (recreated or !self.scene_target.ready) {
            self.clearSceneTargetInvalidation();
        }
        return recreated;
    }

    fn prepareSceneTarget(self: *Renderer, filter: i32) void {
        const recreated = self.ensureSceneTarget(filter);
        if (self.scene_target.target == null or !recreated) return;

        if (!self.beginRenderTarget(self.scene_target.target)) {
            self.noteSceneTargetRecreateFailure();
            return;
        }
        gl.Disable(gl.c.GL_SCISSOR_TEST);
        const bg = self.theme.background.toRgba();
        gl.ClearColor(
            @as(f32, @floatFromInt(bg.r)) / 255.0,
            @as(f32, @floatFromInt(bg.g)) / 255.0,
            @as(f32, @floatFromInt(bg.b)) / 255.0,
            @as(f32, @floatFromInt(bg.a)) / 255.0,
        );
        gl.Clear(gl.c.GL_COLOR_BUFFER_BIT);
        self.bindDefaultTarget();
    }

    fn beginSceneFrame(self: *Renderer) bool {
        if (self.scene_target.target == null) return false;
        if (!self.beginRenderTarget(self.scene_target.target)) {
            self.noteSceneTargetRecreateFailure();
            return false;
        }
        return true;
    }

    fn drawSceneTargetToDefault(self: *Renderer) void {
        const target = self.scene_target.target orelse return;
        self.bindDefaultTarget();
        gl.Disable(gl.c.GL_SCISSOR_TEST);
        const bg = self.theme.background.toRgba();
        gl.ClearColor(
            @as(f32, @floatFromInt(bg.r)) / 255.0,
            @as(f32, @floatFromInt(bg.g)) / 255.0,
            @as(f32, @floatFromInt(bg.b)) / 255.0,
            @as(f32, @floatFromInt(bg.a)) / 255.0,
        );
        gl.Clear(gl.c.GL_COLOR_BUFFER_BIT);
        const src = texture_draw.fullTextureSrcRect(target.texture);
        const dest = types.Rect{
            .x = 0,
            .y = 0,
            .width = @floatFromInt(target.logical_width),
            .height = @floatFromInt(target.logical_height),
        };
        gl.Disable(gl.c.GL_BLEND);
        draw_ops.drawTextureRect(
            self,
            target.texture,
            src,
            dest,
            Color.white.toRgba(),
            types.Rgba{ .r = 0, .g = 0, .b = 0, .a = 0 },
            .linear_premul,
        );
        gl.Enable(gl.c.GL_BLEND);
    }

    fn bindMainCompositionTarget(self: *Renderer) void {
        if (!self.beginSceneFrame()) self.bindDefaultTarget();
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

    pub fn sampleCurrentTargetPixel(self: *Renderer, logical_x: f32, logical_y: f32) ?types.Rgba {
        if (self.target_width <= 0 or self.target_height <= 0 or self.target_pixel_width <= 0 or self.target_pixel_height <= 0) return null;

        const scale_x = @as(f32, @floatFromInt(self.target_pixel_width)) / @as(f32, @floatFromInt(self.target_width));
        const scale_y = @as(f32, @floatFromInt(self.target_pixel_height)) / @as(f32, @floatFromInt(self.target_height));
        const pixel_x: i32 = @intFromFloat(std.math.floor(logical_x * scale_x));
        const pixel_y_top: i32 = @intFromFloat(std.math.floor(logical_y * scale_y));
        if (pixel_x < 0 or pixel_x >= self.target_pixel_width or pixel_y_top < 0 or pixel_y_top >= self.target_pixel_height) return null;

        const pixel_y = self.target_pixel_height - 1 - pixel_y_top;
        var rgba: [4]u8 = undefined;
        gl.ReadPixels(pixel_x, pixel_y, 1, 1, gl.c.GL_RGBA, gl.c.GL_UNSIGNED_BYTE, &rgba);
        return .{
            .r = rgba[0],
            .g = rgba[1],
            .b = rgba[2],
            .a = rgba[3],
        };
    }

    pub fn registerPresentationProbe(
        self: *Renderer,
        kind: PresentationProbeKind,
        row: usize,
        slot: isize,
        col: usize,
        codepoint: u32,
        logical_x: f32,
        logical_y: f32,
        fg: Color,
        bg: Color,
        baseline_valid: [presentation_grid_samples]bool,
        baseline_pixels: [presentation_grid_samples]types.Rgba,
    ) void {
        if (self.presentation_probe_count >= self.presentation_probes.len) return;
        self.presentation_probes[self.presentation_probe_count] = .{
            .present = true,
            .kind = kind,
            .row = row,
            .slot = slot,
            .col = col,
            .codepoint = codepoint,
            .logical_x = logical_x,
            .logical_y = logical_y,
            .fg = fg,
            .bg = bg,
            .baseline = .{
                .pixels = baseline_pixels,
                .valid = baseline_valid,
            },
        };
        self.presentation_probe_count += 1;
    }

    pub fn registerPresentationBandProbe(
        self: *Renderer,
        row: usize,
        col_start: usize,
        col_end: usize,
        logical_x: f32,
        logical_y: f32,
        logical_width: f32,
        logical_height: f32,
        baseline_valid: [presentation_band_samples]bool,
        baseline_pixels: [presentation_band_samples]types.Rgba,
    ) void {
        if (self.presentation_band_probe_count >= self.presentation_band_probes.len) return;
        self.presentation_band_probes[self.presentation_band_probe_count] = .{
            .present = true,
            .axis = .row,
            .row_start = row,
            .row_end = row,
            .col_start = col_start,
            .col_end = col_end,
            .logical_x = logical_x,
            .logical_y = logical_y,
            .logical_width = logical_width,
            .logical_height = logical_height,
            .baseline = .{
                .pixels = baseline_pixels,
                .valid = baseline_valid,
            },
        };
        self.presentation_band_probe_count += 1;
    }

    pub fn registerPresentationColumnBandProbe(
        self: *Renderer,
        col: usize,
        row_start: usize,
        row_end: usize,
        logical_x: f32,
        logical_y: f32,
        logical_width: f32,
        logical_height: f32,
        baseline_valid: [presentation_band_samples]bool,
        baseline_pixels: [presentation_band_samples]types.Rgba,
    ) void {
        if (self.presentation_band_probe_count >= self.presentation_band_probes.len) return;
        self.presentation_band_probes[self.presentation_band_probe_count] = .{
            .present = true,
            .axis = .column,
            .row_start = row_start,
            .row_end = row_end,
            .col_start = col,
            .col_end = col,
            .logical_x = logical_x,
            .logical_y = logical_y,
            .logical_width = logical_width,
            .logical_height = logical_height,
            .baseline = .{
                .pixels = baseline_pixels,
                .valid = baseline_valid,
            },
        };
        self.presentation_band_probe_count += 1;
    }

    fn srgbToLinear(c: f32) f32 {
        if (c <= 0.04045) return c / 12.92;
        return std.math.pow(f32, (c + 0.055) / 1.055, 2.4);
    }

    fn rgbaDelta(a: types.Rgba, b: types.Rgba) u16 {
        const dr: u16 = @intCast(@abs(@as(i16, @intCast(a.r)) - @as(i16, @intCast(b.r))));
        const dg: u16 = @intCast(@abs(@as(i16, @intCast(a.g)) - @as(i16, @intCast(b.g))));
        const db: u16 = @intCast(@abs(@as(i16, @intCast(a.b)) - @as(i16, @intCast(b.b))));
        return dr + dg + db;
    }

    fn sampleWindowPixelFromBuffer(self: *Renderer, logical_x: f32, logical_y: f32, read_buffer: PresentationReadBuffer) ?types.Rgba {
        if (self.render_width <= 0 or self.render_height <= 0 or self.width <= 0 or self.height <= 0) return null;
        self.bindDefaultTarget();
        gl.ReadBuffer(switch (read_buffer) {
            .front => gl.c.GL_FRONT,
            .back => gl.c.GL_BACK,
        });
        defer gl.ReadBuffer(gl.c.GL_BACK);
        return self.sampleCurrentTargetPixel(logical_x, logical_y);
    }

    fn samplePresentedWindowPixel(self: *Renderer, logical_x: f32, logical_y: f32) ?types.Rgba {
        return self.sampleWindowPixelFromBuffer(logical_x, logical_y, .front);
    }

    fn captureSwapGlState(self: *Renderer) SwapGlState {
        var state = SwapGlState{};
        self.bindDefaultTarget();
        gl.GetIntegerv(gl.c.GL_READ_BUFFER, &state.read_buffer);
        gl.GetIntegerv(gl.c.GL_DRAW_BUFFER, &state.draw_buffer);
        gl.GetIntegerv(gl.c.GL_FRAMEBUFFER_BINDING, &state.framebuffer_binding);
        gl.GetIntegerv(gl.c.GL_READ_FRAMEBUFFER_BINDING, &state.read_framebuffer_binding);
        gl.GetIntegerv(gl.c.GL_DRAW_FRAMEBUFFER_BINDING, &state.draw_framebuffer_binding);
        return state;
    }

    fn previousPresentedProbeIndex(self: *const Renderer, probe: PresentationProbe) ?usize {
        var idx: usize = 0;
        while (idx < self.previous_present_probe_count) : (idx += 1) {
            const previous = self.previous_present_probes[idx];
            if (!previous.present) continue;
            if (previous.kind != probe.kind) continue;
            if (previous.row != probe.row) continue;
            if (previous.slot != probe.slot) continue;
            if (previous.col != probe.col) continue;
            return idx;
        }
        return null;
    }

    fn previousFinalProbeIndex(self: *const Renderer, probe: PresentationProbe) ?usize {
        var idx: usize = 0;
        while (idx < self.previous_final_probe_count) : (idx += 1) {
            const previous = self.previous_final_probes[idx];
            if (!previous.present) continue;
            if (previous.kind != probe.kind) continue;
            if (previous.row != probe.row) continue;
            if (previous.slot != probe.slot) continue;
            if (previous.col != probe.col) continue;
            return idx;
        }
        return null;
    }

    fn captureWindowGrid(self: *Renderer, logical_x: f32, logical_y: f32, read_buffer: PresentationReadBuffer) PresentationGridSample {
        const offsets = [_]f32{ -0.25, 0.0, 0.25 };
        const cell_w = if (self.terminal_cell_width > 0.0) self.terminal_cell_width else 1.0;
        const cell_h = if (self.terminal_cell_height > 0.0) self.terminal_cell_height else 1.0;
        var sample = PresentationGridSample{};
        var idx: usize = 0;
        for (offsets) |y_off| {
            for (offsets) |x_off| {
                const sample_x = logical_x + x_off * cell_w;
                const sample_y = logical_y + y_off * cell_h;
                if (self.sampleWindowPixelFromBuffer(sample_x, sample_y, read_buffer)) |rgba| {
                    sample.valid[idx] = true;
                    sample.pixels[idx] = rgba;
                }
                idx += 1;
            }
        }
        return sample;
    }

    fn capturePresentedGrid(self: *Renderer, logical_x: f32, logical_y: f32) PresentationGridSample {
        return self.captureWindowGrid(logical_x, logical_y, .front);
    }

    fn captureWindowBand(
        self: *Renderer,
        logical_x: f32,
        logical_y: f32,
        logical_width: f32,
        logical_height: f32,
        read_buffer: PresentationReadBuffer,
    ) PresentationBandSample {
        var sample = PresentationBandSample{};
        if (logical_width <= 0.0 or logical_height <= 0.0) return sample;

        const step_x = logical_width / @as(f32, @floatFromInt(presentation_band_cols));
        const step_y = logical_height / @as(f32, @floatFromInt(presentation_band_rows));
        var idx: usize = 0;
        var row_idx: usize = 0;
        while (row_idx < presentation_band_rows) : (row_idx += 1) {
            var col_idx: usize = 0;
            while (col_idx < presentation_band_cols) : (col_idx += 1) {
                const sample_x = logical_x + step_x * (@as(f32, @floatFromInt(col_idx)) + 0.5);
                const sample_y = logical_y + step_y * (@as(f32, @floatFromInt(row_idx)) + 0.5);
                if (self.sampleWindowPixelFromBuffer(sample_x, sample_y, read_buffer)) |rgba| {
                    sample.valid[idx] = true;
                    sample.pixels[idx] = rgba;
                }
                idx += 1;
            }
        }
        return sample;
    }

    fn capturePresentedBand(
        self: *Renderer,
        logical_x: f32,
        logical_y: f32,
        logical_width: f32,
        logical_height: f32,
    ) PresentationBandSample {
        return self.captureWindowBand(logical_x, logical_y, logical_width, logical_height, .front);
    }

    fn presentationGridCenterPixel(sample: *const PresentationGridSample) ?types.Rgba {
        const center_idx = presentation_grid_samples / 2;
        if (!sample.valid[center_idx]) return null;
        return sample.pixels[center_idx];
    }

    fn diffPresentationGrid(current: *const PresentationGridSample, baseline: *const PresentationGridSample) PresentationGridDiff {
        var diff = PresentationGridDiff{};
        var idx: usize = 0;
        while (idx < presentation_grid_samples) : (idx += 1) {
            if (!current.valid[idx] or !baseline.valid[idx]) continue;
            diff.samples += 1;
            const delta = rgbaDelta(current.pixels[idx], baseline.pixels[idx]);
            if (delta > diff.max_delta) diff.max_delta = delta;
            if (delta >= presentation_delta_threshold) diff.hits += 1;
        }
        return diff;
    }

    fn diffPresentationBand(current: *const PresentationBandSample, baseline: *const PresentationBandSample) PresentationBandDiff {
        var diff = PresentationBandDiff{};
        var idx: usize = 0;
        while (idx < presentation_band_samples) : (idx += 1) {
            if (!current.valid[idx] or !baseline.valid[idx]) continue;
            diff.samples += 1;
            const delta = rgbaDelta(current.pixels[idx], baseline.pixels[idx]);
            if (delta > diff.max_delta) diff.max_delta = delta;
            if (delta >= presentation_delta_threshold) diff.hits += 1;
        }
        return diff;
    }

    fn hashPresentationBand(sample: *const PresentationBandSample) u64 {
        var hasher = std.hash.Fnv1a_64.init();
        var idx: usize = 0;
        while (idx < presentation_band_samples) : (idx += 1) {
            const valid: u8 = @intFromBool(sample.valid[idx]);
            hasher.update(&[_]u8{valid});
            if (sample.valid[idx]) {
                const rgba = sample.pixels[idx];
                hasher.update(&[_]u8{ rgba.r, rgba.g, rgba.b, rgba.a });
            }
        }
        return hasher.final();
    }

    fn bestMatchingRowBandBaseline(
        self: *const Renderer,
        current_band_idx: usize,
        current: *const PresentationBandSample,
    ) ?struct {
        row: usize,
        hash: u64,
        diff: PresentationBandDiff,
        same_row: bool,
    } {
        var best_idx: ?usize = null;
        var best_diff = PresentationBandDiff{ .hits = std.math.maxInt(usize) };
        var idx: usize = 0;
        while (idx < self.presentation_band_probe_count) : (idx += 1) {
            if (idx == current_band_idx) continue;
            const candidate = self.presentation_band_probes[idx];
            if (!candidate.present or candidate.axis != .row) continue;
            const diff = diffPresentationBand(current, &candidate.baseline);
            if (best_idx == null or diff.hits < best_diff.hits or (diff.hits == best_diff.hits and diff.max_delta < best_diff.max_delta)) {
                best_idx = idx;
                best_diff = diff;
            }
        }
        if (best_idx) |best_match_idx| {
            const candidate = self.presentation_band_probes[best_match_idx];
            return .{
                .row = candidate.row_start,
                .hash = hashPresentationBand(&candidate.baseline),
                .diff = best_diff,
                .same_row = candidate.row_start == self.presentation_band_probes[current_band_idx].row_start,
            };
        }
        return null;
    }

    fn logPresentedFrameProbes(self: *Renderer) void {
        if (self.presentation_probe_count == 0 and self.presentation_band_probe_count == 0) return;
        const target_sample_log = app_logger.logger("terminal.ui.target_sample");
        if (!target_sample_log.enabled_file and !target_sample_log.enabled_console) return;

        const present_counter = sdl_api.getPerformanceCounter();
        const compositor_info = compositor.detect();
        const video_driver = sdl_api.getCurrentVideoDriver() orelse "unknown";
        const post_swap_gl_state = self.captureSwapGlState();
        self.last_present_gap_ms = if (self.last_present_counter == 0)
            0.0
        else
            performanceDeltaMs(self.last_present_counter, present_counter, self.perf_freq);
        self.last_present_counter = present_counter;
        var state_logged = false;

        var probe_idx: usize = 0;
        while (probe_idx < self.presentation_probe_count) : (probe_idx += 1) {
            const probe = self.presentation_probes[probe_idx];
            if (!probe.present) continue;

            const rgba = self.samplePresentedWindowPixel(probe.logical_x, probe.logical_y) orelse continue;
            const grid = self.capturePresentedGrid(probe.logical_x, probe.logical_y);
            const back_rgba = self.sampleWindowPixelFromBuffer(probe.logical_x, probe.logical_y, .back) orelse rgba;
            const back_grid = self.captureWindowGrid(probe.logical_x, probe.logical_y, .back);
            const diff = diffPresentationGrid(&grid, &probe.baseline);
            const back_diff = diffPresentationGrid(&back_grid, &probe.baseline);
            const pre_swap_back_grid = if (probe_idx < self.pre_swap_probe_count and self.pre_swap_probes[probe_idx].present)
                self.pre_swap_probes[probe_idx].back_grid
            else
                probe.baseline;
            const pre_swap_front_grid = if (probe_idx < self.pre_swap_probe_count and self.pre_swap_probes[probe_idx].present)
                self.pre_swap_probes[probe_idx].front_grid
            else
                probe.baseline;
            const pre_fallback_front_grid = if (probe_idx < self.pre_fallback_probe_count and self.pre_fallback_probes[probe_idx].present)
                self.pre_fallback_probes[probe_idx].front_grid
            else
                probe.baseline;
            const pre_swap_back_rgba = presentationGridCenterPixel(&pre_swap_back_grid) orelse rgba;
            const pre_swap_back_diff = diffPresentationGrid(&pre_swap_back_grid, &probe.baseline);
            const pre_swap_front_rgba = presentationGridCenterPixel(&pre_swap_front_grid) orelse rgba;
            const pre_swap_front_diff = diffPresentationGrid(&pre_swap_front_grid, &probe.baseline);
            const pre_fallback_front_rgba = presentationGridCenterPixel(&pre_fallback_front_grid) orelse rgba;
            const pre_fallback_front_diff = diffPresentationGrid(&pre_fallback_front_grid, &probe.baseline);
            const previous_idx = self.previousPresentedProbeIndex(probe);
            const previous_diff = if (previous_idx) |idx|
                diffPresentationGrid(&grid, &self.previous_present_probes[idx].grid)
            else
                PresentationGridDiff{};
            const previous_codepoint: u32 = if (previous_idx) |idx| self.previous_present_probes[idx].codepoint else 0;
            const previous_final_idx = self.previousFinalProbeIndex(probe);
            const previous_final_diff = if (previous_final_idx) |idx|
                diffPresentationGrid(&grid, &self.previous_final_probes[idx].grid)
            else
                PresentationGridDiff{};
            const previous_final_codepoint: u32 = if (previous_final_idx) |idx| self.previous_final_probes[idx].codepoint else 0;
            const suspicious = diff.hits > 0 or
                back_diff.hits > 0 or
                pre_swap_back_diff.hits > 0 or
                pre_swap_front_diff.hits > 0;
            if (!suspicious) {
                if (probe_idx < self.previous_present_probes.len) {
                    self.previous_present_probes[probe_idx] = .{
                        .present = true,
                        .kind = probe.kind,
                        .row = probe.row,
                        .slot = probe.slot,
                        .col = probe.col,
                        .codepoint = probe.codepoint,
                        .grid = grid,
                    };
                }
                if (probe_idx < self.previous_final_probes.len) {
                    self.previous_final_probes[probe_idx] = .{
                        .present = true,
                        .kind = probe.kind,
                        .row = probe.row,
                        .slot = probe.slot,
                        .col = probe.col,
                        .codepoint = probe.codepoint,
                        .grid = probe.baseline,
                    };
                }
                continue;
            }
            if (!state_logged) {
                target_sample_log.logf(
                    .info,
                    "event=present_state frame={d} focused={d} resized={d} swap_interval={d} present_edge={s} swap_ms={d:.2} present_gap_ms={d:.2} video_driver={s} wayland={d} compositor={s} window={d}x{d} drawable={d}x{d} probes={d} bands={d}",
                    .{
                        self.frame_seq,
                        @intFromBool(self.window_focused),
                        @intFromBool(self.window_resized_flag),
                        sdl_api.glGetSwapInterval(),
                        presentEdgeFallbackName(self.present_edge_fallback_mode),
                        self.last_swap_ms,
                        self.last_present_gap_ms,
                        video_driver,
                        @intFromBool(compositor_info.wayland),
                        compositorName(compositor_info.compositor),
                        self.width,
                        self.height,
                        self.render_width,
                        self.render_height,
                        self.presentation_probe_count,
                        self.presentation_band_probe_count,
                    },
                );
                target_sample_log.logf(
                    .info,
                    "event=present_gl_state pre_read={x} pre_draw={x} pre_fb={d} pre_read_fb={d} pre_draw_fb={d} post_read={x} post_draw={x} post_fb={d} post_read_fb={d} post_draw_fb={d}",
                    .{
                        @as(u32, @bitCast(self.pre_swap_gl_state.read_buffer)),
                        @as(u32, @bitCast(self.pre_swap_gl_state.draw_buffer)),
                        self.pre_swap_gl_state.framebuffer_binding,
                        self.pre_swap_gl_state.read_framebuffer_binding,
                        self.pre_swap_gl_state.draw_framebuffer_binding,
                        @as(u32, @bitCast(post_swap_gl_state.read_buffer)),
                        @as(u32, @bitCast(post_swap_gl_state.draw_buffer)),
                        post_swap_gl_state.framebuffer_binding,
                        post_swap_gl_state.read_framebuffer_binding,
                        post_swap_gl_state.draw_framebuffer_binding,
                    },
                );
                state_logged = true;
            }
            target_sample_log.logf(
                .info,
                "event=target_sample phase=pre_swap_back kind={s} row={d} slot={d} col={d} cp={d} rgba={d}:{d}:{d}:{d} fg={d}:{d}:{d} bg={d}:{d}:{d} diff_hits={d}/{d} diff_max={d}",
                .{
                    switch (probe.kind) {
                        .bg2 => "bg2",
                        .direct => "direct",
                    },
                    probe.row,
                    probe.slot,
                    probe.col,
                    probe.codepoint,
                    pre_swap_back_rgba.r,
                    pre_swap_back_rgba.g,
                    pre_swap_back_rgba.b,
                    pre_swap_back_rgba.a,
                    probe.fg.r,
                    probe.fg.g,
                    probe.fg.b,
                    probe.bg.r,
                    probe.bg.g,
                    probe.bg.b,
                    pre_swap_back_diff.hits,
                    pre_swap_back_diff.samples,
                    pre_swap_back_diff.max_delta,
                },
            );
            if (self.present_edge_fallback_mode == .copy_back_to_front) {
                target_sample_log.logf(
                    .info,
                    "event=target_sample phase=pre_fallback_front kind={s} row={d} slot={d} col={d} cp={d} rgba={d}:{d}:{d}:{d} fg={d}:{d}:{d} bg={d}:{d}:{d} diff_hits={d}/{d} diff_max={d}",
                    .{
                        switch (probe.kind) {
                            .bg2 => "bg2",
                            .direct => "direct",
                        },
                        probe.row,
                        probe.slot,
                        probe.col,
                        probe.codepoint,
                        pre_fallback_front_rgba.r,
                        pre_fallback_front_rgba.g,
                        pre_fallback_front_rgba.b,
                        pre_fallback_front_rgba.a,
                        probe.fg.r,
                        probe.fg.g,
                        probe.fg.b,
                        probe.bg.r,
                        probe.bg.g,
                        probe.bg.b,
                        pre_fallback_front_diff.hits,
                        pre_fallback_front_diff.samples,
                        pre_fallback_front_diff.max_delta,
                    },
                );
            }
            target_sample_log.logf(
                .info,
                "event=target_sample phase=pre_swap_front kind={s} row={d} slot={d} col={d} cp={d} rgba={d}:{d}:{d}:{d} fg={d}:{d}:{d} bg={d}:{d}:{d} diff_hits={d}/{d} diff_max={d}",
                .{
                    switch (probe.kind) {
                        .bg2 => "bg2",
                        .direct => "direct",
                    },
                    probe.row,
                    probe.slot,
                    probe.col,
                    probe.codepoint,
                    pre_swap_front_rgba.r,
                    pre_swap_front_rgba.g,
                    pre_swap_front_rgba.b,
                    pre_swap_front_rgba.a,
                    probe.fg.r,
                    probe.fg.g,
                    probe.fg.b,
                    probe.bg.r,
                    probe.bg.g,
                    probe.bg.b,
                    pre_swap_front_diff.hits,
                    pre_swap_front_diff.samples,
                    pre_swap_front_diff.max_delta,
                },
            );
            target_sample_log.logf(
                .info,
                "event=target_sample phase=present kind={s} row={d} slot={d} col={d} cp={d} rgba={d}:{d}:{d}:{d} fg={d}:{d}:{d} bg={d}:{d}:{d} diff_hits={d}/{d} diff_max={d} back_rgba={d}:{d}:{d}:{d} back_hits={d}/{d} back_max={d}",
                .{
                    switch (probe.kind) {
                        .bg2 => "bg2",
                        .direct => "direct",
                    },
                    probe.row,
                    probe.slot,
                    probe.col,
                    probe.codepoint,
                    rgba.r,
                    rgba.g,
                    rgba.b,
                    rgba.a,
                    probe.fg.r,
                    probe.fg.g,
                    probe.fg.b,
                    probe.bg.r,
                    probe.bg.g,
                    probe.bg.b,
                    diff.hits,
                    diff.samples,
                    diff.max_delta,
                    back_rgba.r,
                    back_rgba.g,
                    back_rgba.b,
                    back_rgba.a,
                    back_diff.hits,
                    back_diff.samples,
                    back_diff.max_delta,
                },
            );
            target_sample_log.logf(
                .info,
                "event=present_compare kind={s} row={d} slot={d} col={d} cp={d} prev_cp={d} prev_hits={d}/{d} prev_max={d} prev_final_cp={d} prev_final_hits={d}/{d} prev_final_max={d}",
                .{
                    switch (probe.kind) {
                        .bg2 => "bg2",
                        .direct => "direct",
                    },
                    probe.row,
                    probe.slot,
                    probe.col,
                    probe.codepoint,
                    previous_codepoint,
                    previous_diff.hits,
                    previous_diff.samples,
                    previous_diff.max_delta,
                    previous_final_codepoint,
                    previous_final_diff.hits,
                    previous_final_diff.samples,
                    previous_final_diff.max_delta,
                },
            );

            if (probe_idx < self.previous_present_probes.len) {
                self.previous_present_probes[probe_idx] = .{
                    .present = true,
                    .kind = probe.kind,
                    .row = probe.row,
                    .slot = probe.slot,
                    .col = probe.col,
                    .codepoint = probe.codepoint,
                    .grid = grid,
                };
            }
            if (probe_idx < self.previous_final_probes.len) {
                self.previous_final_probes[probe_idx] = .{
                    .present = true,
                    .kind = probe.kind,
                    .row = probe.row,
                    .slot = probe.slot,
                    .col = probe.col,
                    .codepoint = probe.codepoint,
                    .grid = probe.baseline,
                };
            }
        }
        var band_idx: usize = 0;
        while (band_idx < self.presentation_band_probe_count) : (band_idx += 1) {
            const band = self.presentation_band_probes[band_idx];
            if (!band.present) continue;

            const front = self.capturePresentedBand(band.logical_x, band.logical_y, band.logical_width, band.logical_height);
            const back = self.captureWindowBand(band.logical_x, band.logical_y, band.logical_width, band.logical_height, .back);
            const front_diff = diffPresentationBand(&front, &band.baseline);
            const back_diff = diffPresentationBand(&back, &band.baseline);
            const pre_swap_back = if (band_idx < self.pre_swap_band_probe_count and self.pre_swap_band_probes[band_idx].present)
                self.pre_swap_band_probes[band_idx].back_sample
            else
                band.baseline;
            const pre_swap_front = if (band_idx < self.pre_swap_band_probe_count and self.pre_swap_band_probes[band_idx].present)
                self.pre_swap_band_probes[band_idx].front_sample
            else
                band.baseline;
            const pre_swap_back_diff = diffPresentationBand(&pre_swap_back, &band.baseline);
            const pre_swap_front_diff = diffPresentationBand(&pre_swap_front, &band.baseline);
            if (front_diff.hits == 0 and back_diff.hits == 0 and pre_swap_back_diff.hits == 0 and pre_swap_front_diff.hits == 0) continue;
            if (!state_logged) {
                target_sample_log.logf(
                    .info,
                    "event=present_state frame={d} focused={d} resized={d} swap_interval={d} present_edge={s} swap_ms={d:.2} present_gap_ms={d:.2} video_driver={s} wayland={d} compositor={s} window={d}x{d} drawable={d}x{d} probes={d} bands={d}",
                    .{
                        self.frame_seq,
                        @intFromBool(self.window_focused),
                        @intFromBool(self.window_resized_flag),
                        sdl_api.glGetSwapInterval(),
                        presentEdgeFallbackName(self.present_edge_fallback_mode),
                        self.last_swap_ms,
                        self.last_present_gap_ms,
                        video_driver,
                        @intFromBool(compositor_info.wayland),
                        compositorName(compositor_info.compositor),
                        self.width,
                        self.height,
                        self.render_width,
                        self.render_height,
                        self.presentation_probe_count,
                        self.presentation_band_probe_count,
                    },
                );
                target_sample_log.logf(
                    .info,
                    "event=present_gl_state pre_read={x} pre_draw={x} pre_fb={d} pre_read_fb={d} pre_draw_fb={d} post_read={x} post_draw={x} post_fb={d} post_read_fb={d} post_draw_fb={d}",
                    .{
                        @as(u32, @bitCast(self.pre_swap_gl_state.read_buffer)),
                        @as(u32, @bitCast(self.pre_swap_gl_state.draw_buffer)),
                        self.pre_swap_gl_state.framebuffer_binding,
                        self.pre_swap_gl_state.read_framebuffer_binding,
                        self.pre_swap_gl_state.draw_framebuffer_binding,
                        @as(u32, @bitCast(post_swap_gl_state.read_buffer)),
                        @as(u32, @bitCast(post_swap_gl_state.draw_buffer)),
                        post_swap_gl_state.framebuffer_binding,
                        post_swap_gl_state.read_framebuffer_binding,
                        post_swap_gl_state.draw_framebuffer_binding,
                    },
                );
                state_logged = true;
            }
            switch (band.axis) {
                .row => {
                    target_sample_log.logf(
                        .info,
                        "event=target_band phase=pre_swap_back axis=row row={d} cols={d}..{d} sig={x} diff_hits={d}/{d} diff_max={d}",
                        .{
                            band.row_start,
                            band.col_start,
                            band.col_end,
                            hashPresentationBand(&pre_swap_back),
                            pre_swap_back_diff.hits,
                            pre_swap_back_diff.samples,
                            pre_swap_back_diff.max_delta,
                        },
                    );
                    target_sample_log.logf(
                        .info,
                        "event=target_band phase=pre_swap_front axis=row row={d} cols={d}..{d} sig={x} diff_hits={d}/{d} diff_max={d}",
                        .{
                            band.row_start,
                            band.col_start,
                            band.col_end,
                            hashPresentationBand(&pre_swap_front),
                            pre_swap_front_diff.hits,
                            pre_swap_front_diff.samples,
                            pre_swap_front_diff.max_delta,
                        },
                    );
                },
                .column => {
                    target_sample_log.logf(
                        .info,
                        "event=target_band phase=pre_swap_back axis=column col={d} rows={d}..{d} sig={x} diff_hits={d}/{d} diff_max={d}",
                        .{
                            band.col_start,
                            band.row_start,
                            band.row_end,
                            hashPresentationBand(&pre_swap_back),
                            pre_swap_back_diff.hits,
                            pre_swap_back_diff.samples,
                            pre_swap_back_diff.max_delta,
                        },
                    );
                    target_sample_log.logf(
                        .info,
                        "event=target_band phase=pre_swap_front axis=column col={d} rows={d}..{d} sig={x} diff_hits={d}/{d} diff_max={d}",
                        .{
                            band.col_start,
                            band.row_start,
                            band.row_end,
                            hashPresentationBand(&pre_swap_front),
                            pre_swap_front_diff.hits,
                            pre_swap_front_diff.samples,
                            pre_swap_front_diff.max_delta,
                        },
                    );
                },
            }
            switch (band.axis) {
                .row => {
                    const alias = self.bestMatchingRowBandBaseline(band_idx, &front);
                    target_sample_log.logf(
                        .info,
                        "event=present_band axis=row row={d} cols={d}..{d} sig={x} diff_hits={d}/{d} diff_max={d} back_sig={x} back_hits={d}/{d} back_max={d} final_sig={x} alias_row={d} alias_sig={x} alias_hits={d}/{d} alias_max={d}",
                        .{
                            band.row_start,
                            band.col_start,
                            band.col_end,
                            hashPresentationBand(&front),
                            front_diff.hits,
                            front_diff.samples,
                            front_diff.max_delta,
                            hashPresentationBand(&back),
                            back_diff.hits,
                            back_diff.samples,
                            back_diff.max_delta,
                            hashPresentationBand(&band.baseline),
                            if (alias) |value| value.row else band.row_start,
                            if (alias) |value| value.hash else hashPresentationBand(&band.baseline),
                            if (alias) |value| value.diff.hits else front_diff.hits,
                            if (alias) |value| value.diff.samples else front_diff.samples,
                            if (alias) |value| value.diff.max_delta else front_diff.max_delta,
                        },
                    );
                },
                .column => target_sample_log.logf(
                    .info,
                    "event=present_band axis=column col={d} rows={d}..{d} sig={x} diff_hits={d}/{d} diff_max={d} back_sig={x} back_hits={d}/{d} back_max={d} final_sig={x}",
                    .{
                        band.col_start,
                        band.row_start,
                        band.row_end,
                        hashPresentationBand(&front),
                        front_diff.hits,
                        front_diff.samples,
                        front_diff.max_delta,
                        hashPresentationBand(&back),
                        back_diff.hits,
                        back_diff.samples,
                        back_diff.max_delta,
                        hashPresentationBand(&band.baseline),
                    },
                ),
            }
        }
        self.previous_present_probe_count = self.presentation_probe_count;
        self.previous_final_probe_count = self.presentation_probe_count;
    }

    fn capturePreSwapBackFrameProbes(self: *Renderer) void {
        self.pre_swap_gl_state = self.captureSwapGlState();
        self.pre_swap_probe_count = self.presentation_probe_count;
        var probe_idx: usize = 0;
        while (probe_idx < self.presentation_probe_count) : (probe_idx += 1) {
            const probe = self.presentation_probes[probe_idx];
            self.pre_swap_probes[probe_idx] = .{
                .present = probe.present,
                .back_grid = if (probe.present)
                    self.captureWindowGrid(probe.logical_x, probe.logical_y, .back)
                else
                    .{},
                .front_grid = if (probe.present)
                    self.captureWindowGrid(probe.logical_x, probe.logical_y, .front)
                else
                    .{},
            };
        }

        self.pre_swap_band_probe_count = self.presentation_band_probe_count;
        var band_idx: usize = 0;
        while (band_idx < self.presentation_band_probe_count) : (band_idx += 1) {
            const band = self.presentation_band_probes[band_idx];
            self.pre_swap_band_probes[band_idx] = .{
                .present = band.present,
                .back_sample = if (band.present)
                    self.captureWindowBand(band.logical_x, band.logical_y, band.logical_width, band.logical_height, .back)
                else
                    .{},
                .front_sample = if (band.present)
                    self.captureWindowBand(band.logical_x, band.logical_y, band.logical_width, band.logical_height, .front)
                else
                    .{},
            };
        }
    }

    fn capturePreFallbackFrameProbes(self: *Renderer) void {
        self.pre_fallback_probe_count = self.presentation_probe_count;
        var probe_idx: usize = 0;
        while (probe_idx < self.presentation_probe_count) : (probe_idx += 1) {
            const probe = self.presentation_probes[probe_idx];
            self.pre_fallback_probes[probe_idx] = .{
                .present = probe.present,
                .front_grid = if (probe.present)
                    self.captureWindowGrid(probe.logical_x, probe.logical_y, .front)
                else
                    .{},
            };
        }
    }

    pub fn setTextInputRect(self: *Renderer, x: i32, y: i32, w: i32, h: i32) void {
        text_input.setRect(&self.text_input_state, self.window, x, y, w, h);
    }

    pub fn ensureTerminalTexture(self: *Renderer, width: i32, height: i32) bool {
        const recreated = self.ensureRenderTargetScaled(&self.terminal_target, width, height, target_draw.nearestFilter());
        _ = self.ensureRenderTargetScaled(&self.terminal_scroll_target, width, height, target_draw.nearestFilter());
        return recreated;
    }

    pub fn ensureEditorTexture(self: *Renderer, width: i32, height: i32) bool {
        return self.ensureRenderTargetScaled(&self.editor_target, width, height, target_draw.nearestFilter());
    }

    pub fn beginTerminalTexture(self: *Renderer) bool {
        return self.beginRenderTarget(self.terminal_target);
    }

    pub fn endTerminalTexture(self: *Renderer) void {
        self.bindMainCompositionTarget();
    }

    pub fn beginEditorTexture(self: *Renderer) bool {
        return self.beginRenderTarget(self.editor_target);
    }

    pub fn endEditorTexture(self: *Renderer) void {
        self.bindMainCompositionTarget();
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
            return targets.scrollRenderTarget(
                self,
                self.terminal_target,
                &self.terminal_scroll_target,
                dx,
                dy,
                target.logical_width,
                target.logical_height,
            );
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
        return clipboard.copyText(self.allocator, &self.clipboard_buffer);
    }

    pub fn getClipboardMimeData(self: *Renderer, allocator: std.mem.Allocator, mime_type: [*:0]const u8) ?[]u8 {
        _ = self;
        return clipboard.copyData(allocator, mime_type);
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
