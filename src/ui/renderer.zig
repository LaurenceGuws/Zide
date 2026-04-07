const std = @import("std");
const iface = @import("renderer/interface.zig");
const terminal_font_mod = @import("terminal_font.zig");
const TerminalFont = terminal_font_mod.TerminalFont;
const AtlasStorageMode = terminal_font_mod.AtlasStorageMode;
const FontRenderingOptions = terminal_font_mod.RenderingOptions;
const hb = terminal_font_mod.c;
const capability_contract = @import("renderer/capability_contract.zig");
const bootstrap_runtime = @import("renderer/bootstrap_runtime.zig");
const renderer_global_runtime = @import("renderer/renderer_global_runtime.zig");
const font_manager = @import("renderer/font_manager.zig");
const draw_ops = @import("renderer/draw_ops.zig");
const backend_dispatch = @import("renderer/backend_dispatch.zig");
const renderer_backend_host = @import("renderer/renderer_backend_host.zig");
const metal_runtime_state = @import("renderer/metal_runtime_state.zig");
const renderer_clip_host = @import("renderer/renderer_clip_host.zig");
const renderer_frame_host = @import("renderer/renderer_frame_host.zig");
const renderer_presentable_host = @import("renderer/renderer_presentable_host.zig");
const renderer_surface_host = @import("renderer/renderer_surface_host.zig");
const scene_target_state = @import("renderer/scene_target_state.zig");
const surface_draw = @import("renderer/surface_draw.zig");
const input_constants = @import("renderer/input_constants.zig");
const clipboard = @import("renderer/clipboard.zig");
const text_input = @import("renderer/text_input.zig");
const time_utils = @import("renderer/time_utils.zig");
const window_init = @import("renderer/window_init.zig");
const input_state = @import("renderer/input_state.zig");
const scale_utils = @import("renderer/scale_utils.zig");
const text_draw = @import("renderer/text_draw.zig");
const gl_resources = @import("renderer/gl_resources.zig");
const shape_utils = @import("renderer/shape_utils.zig");
const shape_draw = @import("renderer/shape_draw.zig");
const terminal_glyphs = @import("renderer/terminal_glyphs.zig");
const terminal_underline = @import("renderer/terminal_underline.zig");
const texture_draw = @import("renderer/texture_draw.zig");
const input_runtime = @import("renderer/input_runtime.zig");
const font_runtime = @import("renderer/font_runtime.zig");
const presentable_contract = @import("renderer/presentable_contract.zig");
const present_trace_runtime = @import("renderer/present_trace_runtime.zig");
const metal_text_sample_runtime = @import("renderer/metal_text_sample_runtime.zig");
const text_runtime = @import("renderer/text_runtime.zig");
const window_chrome_runtime = @import("renderer/window_chrome_runtime.zig");
const macos_host = @import("../platform/macos_host.zig");
const lifecycle_runtime = @import("renderer/lifecycle_runtime.zig");
const windows_snap_layout_sink = @import("../platform/windows_snap_layout_sink.zig");
const windows_frame_material = @import("../platform/windows_frame_material.zig");
const windows_integrated_frame = @import("../platform/windows_integrated_frame.zig");
const native_host = @import("../platform/native_host.zig");
const platform_window = @import("../platform/window_metrics.zig");
const platform_input_events = @import("../platform/input_events.zig");
const build_options = @import("build_options");
const sdl_api = @import("../platform/sdl_api.zig");
const types = @import("renderer/types.zig");
const app_logger = @import("../app_logger.zig");
const builtin = @import("builtin");
const shared_types = @import("../types/mod.zig");

const TextPress = platform_input_events.TextPress;
pub const WindowSizes = struct {
    width: i32,
    height: i32,
    render_width: i32,
    render_height: i32,
};

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
pub const UiGeometryContext = shared_types.layout.UiGeometryContext;
pub const TerminalViewGeometry = shared_types.layout.TerminalViewGeometry;
pub const WindowChangeMask = sdl_api.WindowChangeMask;
pub const QuantizedAxis = struct {
    origin: f32,
    size: f32,
};
pub const WindowGeometryDiagnostics = struct {
    window_w: i32,
    window_h: i32,
    drawable_w: i32,
    drawable_h: i32,
    display_w: i32,
    display_h: i32,
    display_index: i32,
    dpi: MousePos,
    display_scale: f32,
    pixel_density: f32,
    ui_scale: f32,
    render_scale: f32,
    screen: MousePos,
    render: MousePos,
    monitor: MousePos,
};
pub const WindowRefreshResult = struct {
    changes: WindowChangeMask = .{},
    geometry: WindowGeometryDiagnostics,
    ui_scale_changed: bool = false,
    scene_target_invalidation: SceneTargetInvalidation = .{},

    pub fn needsRedraw(self: WindowRefreshResult) bool {
        return self.changes.affectsWindowRefresh() or
            self.ui_scale_changed or
            self.scene_target_invalidation.any();
    }

    pub fn needsUiLayoutRefresh(self: WindowRefreshResult) bool {
        return self.ui_scale_changed;
    }

    pub fn needsDeferredTerminalResize(self: WindowRefreshResult) bool {
        return self.scene_target_invalidation.drawable_resize or
            self.scene_target_invalidation.display_change or
            self.scene_target_invalidation.render_scale_change;
    }
};

pub const ScreenshotMode = capability_contract.ScreenshotMode;
pub const SceneCompositionMode = capability_contract.SceneCompositionMode;
pub const TerminalPresentationMode = capability_contract.TerminalPresentationMode;
pub const TextRenderingMode = capability_contract.TextRenderingMode;
pub const KittyImageMode = capability_contract.KittyImageMode;

pub const RawImageFormat = enum {
    rgb,
    rgba,
};

pub const AtlasPreviewSource = metal_runtime_state.AtlasPreviewSource;

pub const RendererCapabilities = capability_contract.RendererCapabilities;
pub const EditorTextStyleFlags = iface.EditorTextStyleFlags;
pub const editor_syntax_style_slots = iface.editor_syntax_style_slots;

pub const FrameSubmission = present_trace_runtime.FrameSubmission;
pub const PresentTrace = present_trace_runtime.PresentTrace;
pub const InputRuntimeState = input_state.InputRuntimeState;
pub const WindowChromeState = window_chrome_runtime.WindowChromeState;
pub const ScaleState = font_runtime.ScaleState;
pub const FontConfigState = font_manager.FontConfigState;
pub const ClipboardState = clipboard.ClipboardState;
pub const TerminalTextState = text_runtime.TerminalTextState;
pub const PresentableDraw = presentable_contract.PresentableDraw;
pub const PresentableInfo = presentable_contract.PresentableInfo;
pub const MetalSampleTextRequest = metal_text_sample_runtime.SampleTextRequest;
pub const MetalTerminalCellRunRequest = metal_text_sample_runtime.TerminalCellRunRequest;
pub const SceneTargetInvalidation = scene_target_state.SceneTargetInvalidation;
pub const SceneTargetContract = scene_target_state.SceneTargetContract;
const MainCompositionTarget = present_trace_runtime.MainCompositionTarget;
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

const key_repeat_key_count: usize = sdl_api.scancode_count;
const mouse_button_count: usize = 8;
const input_queue_capacity: usize = 8192;
const clip_stack_capacity: usize = 8;
const KeyPress = input_state.KeyPress;

const BatchState = draw_ops.BatchState;

pub fn sceneTargetContractFromDisplayMetrics(metrics: platform_window.DisplayMetrics) SceneTargetContract {
    return scene_target_state.contractFromDisplayMetrics(metrics);
}

pub fn logSceneTargetState(
    logger: app_logger.Logger,
    event: []const u8,
    contract: SceneTargetContract,
    invalidation: SceneTargetInvalidation,
    ready: bool,
) void {
    scene_target_state.logState(logger, event, contract, invalidation, ready);
}

pub const Renderer = struct {
    const Self = @This();

    pub const InitOptions = struct {
        app_font_size: f32 = 16.0,
        app_font_path: ?[]const u8 = null,
        editor_font_size: ?f32 = null,
        editor_font_path: ?[]const u8 = null,
        terminal_font_size: ?f32 = null,
        terminal_font_path: ?[]const u8 = null,
        font_rendering: FontRenderingOptions = .{},
        text_gamma: f32 = 1.0,
        text_contrast: f32 = 1.0,
        text_linear_correction: bool = true,
        renderer_backend: RendererBackend = .opengl,
        runtime_profile: RendererRuntimeProfile = .full_ui,
    };

    pub const ScaledFontMetrics = struct {
        ascent: f32,
        descent: f32,
        line_height: f32,
        cell_width: f32,
        cell_height: f32,
        baseline_from_top: f32,
    };

    pub const TerminalCellGeometry = struct {
        cell_width_logical_exact: f32,
        cell_height_logical_exact: f32,
        baseline_logical_exact: f32,
        cell_width_device_px: i32,
        cell_height_device_px: i32,
        baseline_device_px: i32,
    };

    pub const SelectionOverlayStyle = struct {
        smooth_enabled: bool = true,
        corner_px: ?f32 = null,
        pad_px: ?f32 = null,
    };

    const SelectionOverlayState = struct {
        editor: SelectionOverlayStyle = .{},
        terminal: SelectionOverlayStyle = .{},
    };

    const TerminalRecentInputPolicy = struct {
        force_full_enabled: bool = true,
        window_seconds: f64 = 0.375,
    };

    const TerminalRenderPolicy = struct {
        texture_shift_enabled: bool = true,
        recent_input_full_publication: TerminalRecentInputPolicy = .{},
    };

    const TextRenderState = struct {
        gamma: f32 = 1.0,
        contrast: f32 = 1.0,
        linear_correction: bool = true,
        dst_linear_active: bool = false,
        bg_rgba: types.Rgba = .{ .r = 0, .g = 0, .b = 0, .a = 0 },
    };

    const BackendHost = renderer_backend_host.Host(
        Self,
        FrameSubmission,
        RendererCapabilities,
        PresentableDraw,
        PresentableInfo,
        RawImageFormat,
        SceneTargetInvalidation,
        WindowChangeMask,
    );

    pub const WindowChromeMode = window_chrome_runtime.WindowChromeMode;
    pub const WindowChromeContract = window_chrome_runtime.WindowChromeContract;
    pub const ExternalIntent = native_host.ExternalIntent;
    pub const RendererBackend = enum {
        opengl,
        metal,
    };
    pub const RendererRuntimeProfile = bootstrap_runtime.RendererRuntimeProfile;
    pub const RenderSurfaceAttachment = window_init.RenderSurfaceAttachment;

    allocator: std.mem.Allocator,
    backend: BackendHost,
    runtime_profile: RendererRuntimeProfile,
    app_host: native_host.PlatformAppHost,
    app_event_watch_installed: bool,
    appkit_delegate_installation: ?lifecycle_runtime.Installation,
    render_host: native_host.PlatformRenderHost,
    render_surface_attachment: RenderSurfaceAttachment,
    window: *sdl_api.c.SDL_Window,
    fonts_ready: bool,
    width: i32,
    height: i32,
    render_width: i32,
    render_height: i32,
    display_metrics: platform_window.DisplayMetrics,
    target_width: i32,
    target_height: i32,
    target_pixel_width: i32,
    target_pixel_height: i32,

    text_render: TextRenderState,
    selection_overlay: SelectionOverlayState,
    terminal_render_policy: TerminalRenderPolicy,

    font_size: f32,
    base_font_size: f32,
    char_width: f32,
    char_height: f32,
    app_font: TerminalFont,
    app_metrics: ScaledFontMetrics,
    editor_font_size: f32,
    editor_base_font_size: f32,
    editor_char_width: f32,
    editor_char_height: f32,
    editor_metrics: ScaledFontMetrics,
    editor_font: TerminalFont,
    icon_font: TerminalFont,
    icon_font_size: f32,
    icon_char_width: f32,
    icon_char_height: f32,
    icon_metrics: ScaledFontMetrics,
    terminal_cell_width: f32,
    terminal_cell_height: f32,
    terminal_font_size: f32,
    terminal_base_font_size: f32,
    terminal_metrics: ScaledFontMetrics,
    terminal_font: TerminalFont,
    font_config: FontConfigState,

    window_chrome: WindowChromeState,

    theme: Theme,
    scale: ScaleState,
    input: InputRuntimeState,
    clipboard: ClipboardState,
    batch: BatchState,
    terminal_text: TerminalTextState,

    start_counter: u64,
    perf_freq: f64,
    present: present_trace_runtime.PresentState,
    clip_stack: [clip_stack_capacity]types.Rect,
    clip_depth: usize,

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

    fn intersectRect(lhs: types.Rect, rhs: types.Rect) ?types.Rect {
        const x0 = @max(lhs.x, rhs.x);
        const y0 = @max(lhs.y, rhs.y);
        const x1 = @min(lhs.x + lhs.width, rhs.x + rhs.width);
        const y1 = @min(lhs.y + lhs.height, rhs.y + rhs.height);
        const width = x1 - x0;
        const height = y1 - y0;
        if (width <= 0 or height <= 0) return null;
        return .{ .x = x0, .y = y0, .width = width, .height = height };
    }

    fn logicalClipFromInts(x: i32, y: i32, w: i32, h: i32) ?types.Rect {
        if (w <= 0 or h <= 0) return null;
        return .{
            .x = @floatFromInt(x),
            .y = @floatFromInt(y),
            .width = @floatFromInt(w),
            .height = @floatFromInt(h),
        };
    }

    pub fn currentClipRect(self: *const Renderer) ?types.Rect {
        if (self.clip_depth == 0) return null;
        return self.clip_stack[self.clip_depth - 1];
    }

    pub fn init(allocator: std.mem.Allocator, width: i32, height: i32, title: [*:0]const u8, init_options: InitOptions) !*Renderer {
        const startup_backend = init_options.renderer_backend;
        const runtime_profile = init_options.runtime_profile;
        var renderer_bootstrap = try bootstrap_runtime.initRendererBootstrap(
            width,
            height,
            title,
            startup_backend,
            runtime_profile,
        );
        errdefer bootstrap_runtime.deinitRendererBootstrap(&renderer_bootstrap);

        const app_host = native_host.currentAppHost();
        const window = renderer_bootstrap.window_state.window;
        const render_host = renderer_bootstrap.window_state.render_host;
        const render_surface_attachment = renderer_bootstrap.window_state.render_surface_attachment;

        const renderer = try allocator.create(Renderer);
        errdefer allocator.destroy(renderer);

        const display_metrics = platform_window.collectDisplayMetrics(window);
        const scale = font_runtime.initScaleState(allocator, display_metrics);
        const base_font_size = if (init_options.app_font_size > 0.0) init_options.app_font_size else 16.0;
        const editor_base_font_size = if (init_options.editor_font_size) |value| if (value > 0.0) value else base_font_size else base_font_size;
        const terminal_base_font_size = if (init_options.terminal_font_size) |value| if (value > 0.0) value else base_font_size else base_font_size;
        const font_size = base_font_size * scale.ui_scale;
        const editor_font_size = editor_base_font_size * scale.ui_scale;
        const terminal_font_size = terminal_base_font_size * scale.ui_scale;
        const terminal_text = try text_runtime.initTerminalTextState(allocator);
        errdefer {
            var terminal_text_cleanup = terminal_text;
            terminal_text_cleanup.glyph_cache.deinit();
            hb.hb_buffer_destroy(terminal_text_cleanup.shape_buffer);
            terminal_text_cleanup.shape_first_pen.deinit(allocator);
            terminal_text_cleanup.shape_first_pen_set.deinit(allocator);
        }
        const font_config = try font_manager.initFontConfigState(allocator, init_options);
        errdefer {
            var font_config_cleanup = font_config;
            if (font_config_cleanup.terminal_font_features_raw) |owned| allocator.free(owned);
            font_config_cleanup.terminal_font_features.deinit(allocator);
            if (font_config_cleanup.editor_font_features_raw) |owned| allocator.free(owned);
            font_config_cleanup.editor_font_features.deinit(allocator);
            font_config_cleanup.font_cache.deinit();
            if (font_config_cleanup.app_font_path_owned) |owned| allocator.free(owned);
            if (font_config_cleanup.editor_font_path_owned) |owned| allocator.free(owned);
            if (font_config_cleanup.terminal_font_path_owned) |owned| allocator.free(owned);
        }

        renderer.* = .{
            .allocator = allocator,
            .backend = .{
                .ops = backend_dispatch.opsFor(
                Self,
                RendererBackend,
                FrameSubmission,
                RendererCapabilities,
                PresentableDraw,
                PresentableInfo,
                RawImageFormat,
                SceneTargetInvalidation,
                WindowChangeMask,
                startup_backend,
            ),
            },
            .runtime_profile = runtime_profile,
            .app_host = app_host,
            .app_event_watch_installed = false,
            .appkit_delegate_installation = null,
            .render_host = render_host,
            .render_surface_attachment = render_surface_attachment,
            .window = window,
            .fonts_ready = false,
            .width = display_metrics.window_w,
            .height = display_metrics.window_h,
            .render_width = display_metrics.drawable_w,
            .render_height = display_metrics.drawable_h,
            .display_metrics = display_metrics,
            .target_width = display_metrics.drawable_w,
            .target_height = display_metrics.drawable_h,
            .target_pixel_width = display_metrics.drawable_w,
            .target_pixel_height = display_metrics.drawable_h,
            .text_render = .{
                .gamma = init_options.text_gamma,
                .contrast = init_options.text_contrast,
                .linear_correction = init_options.text_linear_correction,
            },
            .selection_overlay = .{},
            .terminal_render_policy = .{},
            .font_size = font_size,
            .base_font_size = base_font_size,
            .char_width = font_size * 0.6,
            .char_height = font_size * 1.2,
            .app_font = undefined,
            .app_metrics = .{
                .ascent = font_size,
                .descent = font_size * 0.2,
                .line_height = font_size * 1.2,
                .cell_width = font_size * 0.6,
                .cell_height = font_size * 1.2,
                .baseline_from_top = font_size,
            },
            .editor_font_size = editor_font_size,
            .editor_base_font_size = editor_base_font_size,
            .editor_char_width = editor_font_size * 0.6,
            .editor_char_height = editor_font_size * 1.2,
            .editor_metrics = .{
                .ascent = editor_font_size,
                .descent = editor_font_size * 0.2,
                .line_height = editor_font_size * 1.2,
                .cell_width = editor_font_size * 0.6,
                .cell_height = editor_font_size * 1.2,
                .baseline_from_top = editor_font_size,
            },
            .editor_font = undefined,
            .icon_font = undefined,
            .icon_font_size = font_size * 2.0,
            .icon_char_width = font_size * 1.2,
            .icon_char_height = font_size * 1.2,
            .icon_metrics = .{
                .ascent = font_size,
                .descent = font_size * 0.2,
                .line_height = font_size * 1.2,
                .cell_width = font_size * 1.2,
                .cell_height = font_size * 1.2,
                .baseline_from_top = font_size,
            },
            .terminal_cell_width = terminal_font_size * 0.6,
            .terminal_cell_height = terminal_font_size * 1.2,
            .terminal_font_size = terminal_font_size,
            .terminal_base_font_size = terminal_base_font_size,
            .terminal_metrics = .{
                .ascent = terminal_font_size,
                .descent = terminal_font_size * 0.2,
                .line_height = terminal_font_size * 1.2,
                .cell_width = terminal_font_size * 0.6,
                .cell_height = terminal_font_size * 1.2,
                .baseline_from_top = terminal_font_size,
            },
            .terminal_font = undefined,
            .font_config = font_config,
            .window_chrome = .{},
            .theme = .{},
            .scale = scale,
            .input = .{},
            .clipboard = .{},
            .batch = .{},
            .terminal_text = terminal_text,
            .start_counter = sdl_api.getPerformanceCounter(),
            .perf_freq = @as(f64, @floatFromInt(sdl_api.getPerformanceFrequency())),
            .present = .{},
            .clip_stack = undefined,
            .clip_depth = 0,
        };

        try lifecycle_runtime.finalizeRendererInit(Renderer, renderer);
        return renderer;
    }

    pub fn runStartupBackendSmoke(width: i32, height: i32, title: [*:0]const u8, backend: RendererBackend) !bool {
        return bootstrap_runtime.runStartupBackendSmoke(width, height, title, backend);
    }

    pub fn deinit(self: *Renderer) void {
        if (self.fonts_ready) {
            self.app_font.deinit();
            self.editor_font.deinit();
            self.terminal_font.deinit();
            self.icon_font.deinit();
        }
        font_manager.deinitFontConfigState(self);

        input_state.deinit(self.inputDomain());
        clipboard.deinit(&self.clipboard, self.allocator);
        draw_ops.deinit(&self.batch, self.allocator);
        text_runtime.deinitTerminalTextState(self);

        lifecycle_runtime.beginRendererShutdown(Renderer, self);
        window_chrome_runtime.deinit(self.windowChromeDomain());
        self.backend.ops.runtime.deinitRuntime(self);
        bootstrap_runtime.deinitRendererWindowResources(&self.render_surface_attachment, self.window);
        bootstrap_runtime.deinitSdlRuntime();

        self.allocator.destroy(self);
    }

    pub fn initFonts(self: *Renderer) !void {
        try font_manager.initFonts(self);
    }

    pub fn loadFont(self: *Renderer, path: [*:0]const u8, size: f32) void {
        font_manager.loadFont(self, path, size);
    }

    pub fn setFontConfig(self: *Renderer, app_path: ?[]const u8, app_size: ?f32, editor_path: ?[]const u8, editor_size: ?f32, terminal_path: ?[]const u8, terminal_size: ?f32) !void {
        try font_manager.setFontConfig(self, app_path, app_size, editor_path, editor_size, terminal_path, terminal_size);
    }

    pub fn setFontRenderingOptions(self: *Renderer, opts: FontRenderingOptions) void {
        font_runtime.setFontRenderingOptions(self, opts);
    }

    pub fn setTextRenderingConfig(self: *Renderer, gamma: ?f32, contrast: ?f32, linear_correction: ?bool) void {
        font_runtime.setTextRenderingConfig(self, gamma, contrast, linear_correction);
    }

    pub fn setEditorSelectionOverlayStyle(self: *Renderer, smooth_enabled: ?bool, corner_px: ?f32, pad_px: ?f32) void {
        applySelectionOverlayStyle(&self.selection_overlay.editor, smooth_enabled, corner_px, pad_px);
    }

    pub fn setTerminalSelectionOverlayStyle(self: *Renderer, smooth_enabled: ?bool, corner_px: ?f32, pad_px: ?f32) void {
        applySelectionOverlayStyle(&self.selection_overlay.terminal, smooth_enabled, corner_px, pad_px);
    }

    pub fn editorSelectionOverlayStyle(self: *const Renderer) SelectionOverlayStyle {
        return self.selection_overlay.editor;
    }

    pub fn terminalSelectionOverlayStyle(self: *const Renderer) SelectionOverlayStyle {
        return self.selection_overlay.terminal;
    }

    fn applySelectionOverlayStyle(style: *SelectionOverlayStyle, smooth_enabled: ?bool, corner_px: ?f32, pad_px: ?f32) void {
        if (smooth_enabled) |v| style.smooth_enabled = v;
        if (corner_px) |v| {
            if (v > 0) style.corner_px = v;
        }
        if (pad_px) |v| {
            if (v > 0) style.pad_px = v;
        }
    }

    pub fn setTerminalPresentationShiftEnabled(self: *Renderer, enabled: bool) void {
        self.terminal_render_policy.texture_shift_enabled = enabled;
    }

    pub fn terminalPresentationShiftEnabled(self: *const Renderer) bool {
        return self.terminal_render_policy.texture_shift_enabled;
    }

    pub fn setTerminalRecentInputFullPublicationPolicy(self: *Renderer, enabled: bool, window_ms: ?usize) void {
        self.terminal_render_policy.recent_input_full_publication.force_full_enabled = enabled;
        if (window_ms) |value| {
            const clamped_ms = std.math.clamp(value, 50, 5000);
            self.terminal_render_policy.recent_input_full_publication.window_seconds = @as(f64, @floatFromInt(clamped_ms)) / 1000.0;
        }
    }

    pub fn terminalRecentInputFullPublicationEnabled(self: *const Renderer) bool {
        return self.terminal_render_policy.recent_input_full_publication.force_full_enabled;
    }

    pub fn terminalRecentInputFullPublicationConfiguredEnabled(self: *const Renderer) bool {
        return self.terminal_render_policy.recent_input_full_publication.force_full_enabled;
    }

    pub fn terminalRecentInputFullPublicationWindowSeconds(self: *const Renderer) f64 {
        if (!self.terminalRecentInputFullPublicationEnabled()) return 0.0;
        return self.terminal_render_policy.recent_input_full_publication.window_seconds;
    }

    pub fn terminalRecentInputFullPublicationWindowMs(self: *const Renderer) usize {
        return @intFromFloat(std.math.round(self.terminalRecentInputFullPublicationWindowSeconds() * 1000.0));
    }

    pub fn forceFullTerminalPresentationRecentInputWindow(self: *const Renderer) bool {
        return self.terminalRecentInputFullPublicationEnabled();
    }

    pub fn fullTerminalPresentationRecentInputWindowSeconds(self: *const Renderer) f64 {
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
        self.backend.ops.runtime.clearDiagnosticFont(self);
        try font_runtime.applyFontScale(self);
    }

    pub fn queueUserZoom(self: *Renderer, delta: f32, now: f64) bool {
        return font_runtime.queueUserZoom(self, delta, now);
    }

    pub fn resetUserZoomTarget(self: *Renderer, now: f64) bool {
        return font_runtime.resetUserZoomTarget(self, now);
    }

    pub fn applyPendingZoom(self: *Renderer, now: f64) !WindowRefreshResult {
        const changed = try font_runtime.applyPendingZoom(self, now);
        const scene_target_invalidation: SceneTargetInvalidation = if (changed and self.capabilities().scene_composition_mode == .offscreen_scene_target)
            .{ .render_scale_change = true }
        else
            .{};
        self.backend.ops.runtime.mergePendingSceneTargetInvalidation(self, scene_target_invalidation);
        return .{
            .changes = .{},
            .geometry = self.windowGeometryDiagnostics(),
            .ui_scale_changed = changed,
            .scene_target_invalidation = scene_target_invalidation,
        };
    }

    pub fn uiScaleFactor(self: *const Renderer) f32 {
        return self.scale.ui_scale * self.scale.user_zoom;
    }

    pub fn userZoomFactor(self: *const Renderer) f32 {
        return self.scale.user_zoom;
    }

    pub fn userZoomTargetFactor(self: *const Renderer) f32 {
        return self.scale.user_zoom_target;
    }

    pub fn baseFontSize(self: *const Renderer) f32 {
        return self.base_font_size;
    }

    pub fn editorBaseFontSize(self: *const Renderer) f32 {
        return self.editor_base_font_size;
    }

    pub fn terminalBaseFontSize(self: *const Renderer) f32 {
        return self.terminal_base_font_size;
    }

    pub fn devicePixelStep(self: *const Renderer) f32 {
        const scale = if (self.scale.render_scale > 0.0) self.scale.render_scale else 1.0;
        return 1.0 / scale;
    }

    pub fn logicalLengthToRaster(self: *const Renderer, value: f32) f32 {
        return value / self.devicePixelStep();
    }

    pub fn rasterLengthToLogical(self: *const Renderer, value: f32) f32 {
        return value * self.devicePixelStep();
    }

    pub fn snapLogicalToDevicePixel(self: *const Renderer, value: f32) f32 {
        return snapToDevicePixel(value, self.scale.render_scale);
    }

    pub fn quantizeLogicalHorizontalAxis(self: *const Renderer, origin: f32, size: f32) QuantizedAxis {
        const snapped_origin = self.snapLogicalToDevicePixel(origin);
        const snapped_end = self.snapLogicalToDevicePixel(origin + size);
        return .{
            .origin = snapped_origin,
            .size = @max(self.devicePixelStep(), snapped_end - snapped_origin),
        };
    }

    pub fn quantizeLogicalVerticalAxis(self: *const Renderer, origin: f32, size: f32) QuantizedAxis {
        return .{
            .origin = self.snapLogicalToDevicePixel(origin),
            .size = @max(self.devicePixelStep(), size),
        };
    }

    fn windowGeometryDiagnosticsFromDisplayMetrics(self: *const Renderer, metrics: platform_window.DisplayMetrics) WindowGeometryDiagnostics {
        const monitor = platform_window.getMonitorSize(self.window);
        return .{
            .window_w = metrics.window_w,
            .window_h = metrics.window_h,
            .drawable_w = metrics.drawable_w,
            .drawable_h = metrics.drawable_h,
            .display_w = @intFromFloat(monitor.x),
            .display_h = @intFromFloat(monitor.y),
            .display_index = metrics.display_index,
            .dpi = metrics.dpi,
            .display_scale = metrics.display_scale,
            .pixel_density = metrics.pixel_density,
            .ui_scale = self.uiScaleFactor(),
            .render_scale = metrics.render_scale,
            .screen = platform_window.getScreenSize(self.window),
            .render = .{ .x = @floatFromInt(metrics.drawable_w), .y = @floatFromInt(metrics.drawable_h) },
            .monitor = monitor,
        };
    }

    fn applyDisplayMetricsSnapshot(self: *Renderer, metrics: platform_window.DisplayMetrics) void {
        self.width = metrics.window_w;
        self.height = metrics.window_h;
        self.render_width = metrics.drawable_w;
        self.render_height = metrics.drawable_h;
        self.display_metrics = metrics;
    }

    fn logWindowMetricsSnapshot(self: *Renderer, metrics: platform_window.DisplayMetrics, reason: []const u8) void {
        _ = self;
        _ = platform_window.collectWindowMetricsFromDisplayMetrics(metrics, reason);
    }

    fn shouldRefreshScaleStateForWindowChanges(changes: WindowChangeMask) bool {
        return changes.affectsWindowRefresh();
    }

    fn refreshScaleStateForWindowChanges(self: *Renderer, changes: WindowChangeMask, metrics: platform_window.DisplayMetrics) !bool {
        if (!shouldRefreshScaleStateForWindowChanges(changes)) return false;
        return font_runtime.refreshUiScaleFromDisplayMetrics(self, metrics);
    }

    fn collectDisplayMetricsForWindowChanges(self: *Renderer, changes: WindowChangeMask) platform_window.DisplayMetrics {
        if (changes.affectsUiScale()) {
            return platform_window.collectDisplayMetrics(self.window);
        }
        const dm = self.display_metrics;
        // Geometry-only merge keeps display-coupled fields from the previous snapshot. If SDL had
        // not yet reported positive display scale / pixel density at the last full collect, stay on
        // the full re-query path until the host snapshot is real (Linux/Wayland fractional startup).
        if (dm.display_scale <= 0.0 and dm.pixel_density <= 0.0) {
            return platform_window.collectDisplayMetrics(self.window);
        }
        const geometry = platform_window.collectWindowGeometryMetrics(self.window);
        return platform_window.mergeWindowGeometryMetrics(dm, geometry);
    }

    pub fn windowGeometryDiagnostics(self: *const Renderer) WindowGeometryDiagnostics {
        return self.windowGeometryDiagnosticsFromDisplayMetrics(self.display_metrics);
    }

    pub fn refreshWindowGeometryDiagnostics(self: *Renderer, reason: []const u8) WindowGeometryDiagnostics {
        const metrics = platform_window.collectDisplayMetrics(self.window);
        self.applyDisplayMetricsSnapshot(metrics);
        self.logWindowMetricsSnapshot(metrics, reason);
        return self.windowGeometryDiagnosticsFromDisplayMetrics(metrics);
    }

    pub fn refreshWindowState(self: *Renderer, reason: []const u8, changes: WindowChangeMask) !WindowRefreshResult {
        const metrics = self.collectDisplayMetricsForWindowChanges(changes);
        const scene_target_invalidation = self.backend.ops.runtime.sceneTargetInvalidationForRefresh(self, changes, metrics);
        self.applyDisplayMetricsSnapshot(metrics);
        self.backend.ops.runtime.mergePendingSceneTargetInvalidation(self, scene_target_invalidation);
        self.logWindowMetricsSnapshot(metrics, reason);
        const ui_scale_changed = try self.refreshScaleStateForWindowChanges(changes, metrics);
        return .{
            .changes = changes,
            .geometry = self.windowGeometryDiagnosticsFromDisplayMetrics(metrics),
            .ui_scale_changed = ui_scale_changed,
            .scene_target_invalidation = scene_target_invalidation,
        };
    }

    pub fn uiGeometryContext(self: *const Renderer) UiGeometryContext {
        return .{
            .window = .{
                .x = 0,
                .y = 0,
                .width = @floatFromInt(self.width),
                .height = @floatFromInt(self.height),
            },
            .ui_scale = self.uiScaleFactor(),
        };
    }

    pub fn shouldClose(self: *Renderer) bool {
        return self.input.should_close_flag;
    }

    pub fn windowFocused(self: *Renderer) bool {
        return input_state.windowFocused(self.inputDomain());
    }

    pub fn beginFrame(self: *Renderer) void {
        renderer_frame_host.beginFrameHost(self);
        self.backend.ops.frame.beginFrame(self);
        self.backend.ops.clip.applyClipRect(self, null);
    }

    pub fn submitFrame(self: *Renderer) FrameSubmission {
        return self.backend.ops.frame.submitFrame(self);
    }

    pub fn armPresentCapture(self: *Renderer, path: []const u8) void {
        self.present.capture_path = path;
        self.present.capture_armed = true;
        self.present.capture_frame_seq = self.present.frame_seq;
    }

    pub fn lastPresentTrace(self: *const Renderer) PresentTrace {
        return self.present.trace_last;
    }

    pub fn dumpWindowScreenshotPpm(self: *Renderer, path: []const u8) !void {
        return self.backend.ops.frame.dumpWindowScreenshotPpm(self, path);
    }

    pub fn dumpWindowScreenshotPpmSized(self: *Renderer, path: []const u8, out_width: i32, out_height: i32) !void {
        return self.backend.ops.frame.dumpWindowScreenshotPpmSized(self, path, out_width, out_height);
    }

    pub fn kittyImageMode(self: *const Renderer) KittyImageMode {
        return self.capabilities().kitty_image_mode;
    }

    pub fn screenshotMode(self: *const Renderer) ScreenshotMode {
        return self.capabilities().screenshot_mode;
    }

    pub fn textRenderingMode(self: *const Renderer) TextRenderingMode {
        return self.capabilities().text_rendering_mode;
    }

    pub fn plannedTextRenderingMode(self: *const Renderer) TextRenderingMode {
        return self.capabilities().planned_text_rendering_mode;
    }

    pub fn capabilities(self: *const Renderer) RendererCapabilities {
        return self.backend.ops.runtime.capabilities(self);
    }

    pub fn setTextInputRect(self: *Renderer, x: i32, y: i32, w: i32, h: i32) void {
        text_input.setRect(&self.input.text_input_state, self.window, x, y, w, h);
    }

    pub fn setClipboardText(_: *Renderer, text: [*:0]const u8) void {
        clipboard.setText(text);
    }

    pub fn getClipboardText(self: *Renderer) ?[]const u8 {
        return clipboard.copyTextState(&self.clipboard, self.allocator);
    }

    pub fn getClipboardMimeData(self: *Renderer, allocator: std.mem.Allocator, mime_type: [*:0]const u8) ?[]u8 {
        _ = self;
        return clipboard.copyData(allocator, mime_type);
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
        return input_state.popCharPressed(self.inputDomain());
    }

    pub fn getTextPressed(self: *Renderer) ?TextPress {
        return input_state.popTextPressed(self.inputDomain());
    }

    pub fn getFocusEvent(self: *Renderer) ?bool {
        return input_state.popFocusQueued(self.inputDomain());
    }

    pub const TextComposition = input_state.TextComposition;

    pub fn getTextComposition(self: *Renderer) TextComposition {
        return input_state.snapshotTextCompositionDomain(self.inputDomain());
    }

    pub fn getKeyPressed(self: *Renderer) ?KeyPress {
        return input_state.popKeyPressed(self.inputDomain());
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
        return input_state.isKeyDown(self.inputDomain(), key);
    }

    pub fn isKeyPressed(self: *Renderer, key: i32) bool {
        return input_state.isKeyPressed(self.inputDomain(), key);
    }

    pub fn isKeyRepeated(self: *Renderer, key: i32) bool {
        return input_state.isKeyRepeated(self.inputDomain(), key);
    }

    pub fn isKeyReleased(self: *Renderer, key: i32) bool {
        return input_state.isKeyReleased(self.inputDomain(), key);
    }

    pub fn getMousePos(self: *Renderer) MousePos {
        _ = self;
        return getMousePosSdl();
    }

    pub fn getMousePosRaw(_: *Renderer) MousePos {
        return getMousePosSdl();
    }

    fn windowChromeDomain(self: *Renderer) window_chrome_runtime.WindowChromeDomain {
        return .{
            .render_host = &self.render_host,
            .window = self.window,
            .window_focused = self.input.window_focused,
            .contract = &self.window_chrome.contract,
            .applied_mode = &self.window_chrome.applied_mode,
            .applied_material = &self.window_chrome.applied_material,
            .integrated_frame = &self.window_chrome.integrated_frame,
            .snap_sink = &self.window_chrome.snap_sink,
            .hit_test_callback = windowHitTestCallback,
            .hit_test_data = @ptrCast(self),
        };
    }

    pub fn setWindowChrome(self: *Renderer, contract: WindowChromeContract) void {
        window_chrome_runtime.applyContract(self.windowChromeDomain(), contract);
    }

    pub fn minimizeWindow(self: *Renderer) bool {
        if (builtin.target.os.tag != .windows) return false;
        return sdl_api.minimizeWindow(self.window);
    }

    pub fn showWindowSystemMenu(self: *Renderer, x: i32, y: i32) bool {
        if (builtin.target.os.tag != .windows) return false;
        return sdl_api.showWindowSystemMenu(self.window, x, y);
    }

    pub fn toggleMaximizeWindow(self: *Renderer) bool {
        if (builtin.target.os.tag != .windows) return false;
        return if (self.windowIsMaximized())
            sdl_api.restoreWindow(self.window)
        else
            sdl_api.maximizeWindow(self.window);
    }

    pub fn windowIsMaximized(self: *Renderer) bool {
        return window_chrome_runtime.windowIsMaximized(self.window);
    }

    pub fn windowIsFullscreen(self: *Renderer) bool {
        return window_chrome_runtime.windowIsFullscreen(self.window);
    }

    pub fn integratedWindowChromeSinkActive(self: *const Renderer) bool {
        return window_chrome_runtime.sinkActive(&self.window_chrome.snap_sink);
    }

    pub fn integratedWindowChromeMinimizeHovered(self: *const Renderer) bool {
        return window_chrome_runtime.minimizeHovered(&self.window_chrome.snap_sink);
    }

    pub fn integratedWindowChromeMaximizeHovered(self: *const Renderer) bool {
        return window_chrome_runtime.maximizeHovered(&self.window_chrome.snap_sink);
    }

    pub fn integratedWindowChromeCloseHovered(self: *const Renderer) bool {
        return window_chrome_runtime.closeHovered(&self.window_chrome.snap_sink);
    }

    pub fn integratedWindowChromeMinimizePressed(self: *const Renderer) bool {
        return window_chrome_runtime.minimizePressed(&self.window_chrome.snap_sink);
    }

    pub fn integratedWindowChromeMaximizePressed(self: *const Renderer) bool {
        return window_chrome_runtime.maximizePressed(&self.window_chrome.snap_sink);
    }

    pub fn integratedWindowChromeClosePressed(self: *const Renderer) bool {
        return window_chrome_runtime.closePressed(&self.window_chrome.snap_sink);
    }

    pub fn integratedWindowChromeSinkOwnsChrome(self: *const Renderer) bool {
        return window_chrome_runtime.sinkOwnsChrome(&self.window_chrome.snap_sink);
    }

    pub fn takePendingExternalIntent(self: *Renderer) ?ExternalIntent {
        return self.app_host.takePendingIntent();
    }

    pub fn macosRequestActivation(self: *Renderer) void {
        macos_host.requestActivation(&self.app_host);
    }

    pub fn macosRequestQuit(self: *Renderer) void {
        macos_host.requestQuit(&self.app_host);
    }

    pub fn macosRequestOpenFile(self: *Renderer, path: []const u8) bool {
        return macos_host.requestOpenFile(&self.app_host, path);
    }

    fn windowHitTestCallback(_: ?*sdl_api.c.SDL_Window, area: [*c]const sdl_api.c.SDL_Point, data: ?*anyopaque) callconv(.c) sdl_api.HitTestResult {
        const raw = data orelse return sdl_api.c.SDL_HITTEST_NORMAL;
        const self: *Renderer = @ptrCast(@alignCast(raw));
        return window_chrome_runtime.hitTest(
            self.window_chrome.contract,
            self.width,
            self.height,
            self.windowIsMaximized(),
            @floatFromInt(area.*.x),
            @floatFromInt(area.*.y),
        );
    }

    pub const DisplayMetrics = platform_window.DisplayMetrics;

    pub fn isMouseButtonPressed(self: *Renderer, button: i32) bool {
        return input_state.isMouseButtonPressed(self.inputDomain(), button);
    }

    pub fn isMouseButtonDown(self: *Renderer, button: i32) bool {
        return input_state.isMouseButtonDown(self.inputDomain(), button);
    }

    pub fn isMouseButtonReleased(self: *Renderer, button: i32) bool {
        return input_state.isMouseButtonReleased(self.inputDomain(), button);
    }

    pub fn mouseButtonClicks(self: *Renderer, button: i32) u8 {
        return input_state.mouseButtonClicks(self.inputDomain(), button);
    }

    pub fn mouseButtonPressPos(self: *Renderer, button: i32) ?MousePos {
        return input_state.mouseButtonPressPos(self.inputDomain(), button);
    }

    pub fn anyMouseButtonsDown(self: *Renderer) bool {
        return input_state.anyMouseButtonsDown(self.inputDomain());
    }

    pub fn getMouseWheelMove(self: *Renderer) f32 {
        _ = self;
        return input_runtime.mouseWheelMove();
    }

    fn fontForSize(self: *Renderer, size: f32) ?*TerminalFont {
        return font_runtime.fontForSize(self, size);
    }

    pub fn beginTerminalBatch(self: *Renderer) void {
        draw_ops.beginTerminalBatch(self);
    }

    pub fn flushTerminalBatch(self: *Renderer) void {
        draw_ops.flushTerminalBatch(self);
    }

    pub fn beginTerminalGlyphBatch(self: *Renderer) void {
        text_runtime.beginTerminalGlyphBatch(self);
    }

    pub fn flushTerminalGlyphBatch(self: *Renderer) void {
        text_runtime.flushTerminalGlyphBatch(self);
    }

    fn drawTextureRect(self: *Renderer, texture: types.Texture, src: types.Rect, dest: types.Rect, color: types.Rgba) void {
        draw_ops.drawTextureRect(self, texture, src, dest, color, types.Rgba{ .r = 0, .g = 0, .b = 0, .a = 0 }, .rgba);
    }

    fn drawTextureRectThunk(ctx: *anyopaque, texture: types.Texture, src: types.Rect, dest: types.Rect, color: types.Rgba, kind: types.TextureKind) void {
        const self: *Renderer = @ptrCast(@alignCast(ctx));
        draw_ops.drawTextureRect(self, texture, src, dest, color, self.text_render.bg_rgba, kind);
    }

    fn drawRectThunk(ctx: *anyopaque, x: i32, y: i32, w: i32, h: i32, color: Color) void {
        const self: *Renderer = @ptrCast(@alignCast(ctx));
        renderer_surface_host.drawRect(self, x, y, w, h, color);
    }

    fn ensureVboCapacity(self: *Renderer, vertex_count: usize) void {
        draw_ops.ensureVboCapacity(self, vertex_count);
    }

    fn addBatchQuad(self: *Renderer, texture: types.Texture, src: types.Rect, dest: types.Rect, color: types.Rgba) void {
        draw_ops.addBatchQuad(self, texture, src, dest, color, types.Rgba{ .r = 0, .g = 0, .b = 0, .a = 0 }, .rgba);
    }

    pub fn terminalCellGeometry(self: *Renderer) TerminalCellGeometry {
        const scale = if (self.scale.render_scale > 0.0) self.scale.render_scale else 1.0;
        const cell_width_device_px = @max(1, @as(i32, @intFromFloat(std.math.round(self.terminal_metrics.cell_width * scale))));
        const cell_height_device_px = @max(1, @as(i32, @intFromFloat(std.math.round(self.terminal_metrics.cell_height * scale))));
        const baseline_device_px = @max(1, @as(i32, @intFromFloat(std.math.round(self.terminal_metrics.baseline_from_top * scale))));
        return .{
            .cell_width_logical_exact = @as(f32, @floatFromInt(cell_width_device_px)) / scale,
            .cell_height_logical_exact = @as(f32, @floatFromInt(cell_height_device_px)) / scale,
            .baseline_logical_exact = @as(f32, @floatFromInt(baseline_device_px)) / scale,
            .cell_width_device_px = cell_width_device_px,
            .cell_height_device_px = cell_height_device_px,
            .baseline_device_px = baseline_device_px,
        };
    }

    pub fn terminalViewGeometry(self: *Renderer, viewport: shared_types.layout.Rect, rows: usize, cols: usize) TerminalViewGeometry {
        const geom = self.terminalCellGeometry();
        const fit = shared_types.layout.fitTerminalGrid(
            viewport.width,
            viewport.height,
            geom,
            0,
            0,
            cols,
            rows,
        );
        const remainder_x = @max(0.0, viewport.width - fit.width);
        const remainder_y = @max(0.0, viewport.height - fit.height);
        const origin_x = snapToDevicePixel(viewport.x + remainder_x * 0.5, self.scale.render_scale);
        const origin_y = snapToDevicePixel(viewport.y + remainder_y * 0.5, self.scale.render_scale);
        return .{
            .viewport = viewport,
            .origin_x = origin_x,
            .origin_y = origin_y,
            .viewport_width = fit.width,
            .viewport_height = fit.height,
            .rows = fit.rows,
            .cols = fit.cols,
            .cell_width = geom.cell_width_logical_exact,
            .cell_height = geom.cell_height_logical_exact,
            .baseline_from_top = geom.baseline_logical_exact,
        };
    }

    pub fn terminalShapeBuffer(self: *Renderer) *hb.hb_buffer_t {
        return self.terminal_text.shape_buffer;
    }

    fn drawTextureBatchThunk(ctx: *anyopaque, texture: types.Texture, src: types.Rect, dest: types.Rect, color: types.Rgba, kind: types.TextureKind) void {
        const renderer: *Renderer = @ptrCast(@alignCast(ctx));
        draw_ops.addBatchQuad(renderer, texture, src, dest, color, renderer.text_render.bg_rgba, kind);
    }

    fn drawTextureGlyphCacheThunk(ctx: *anyopaque, texture: types.Texture, src: types.Rect, dest: types.Rect, color: types.Rgba, kind: types.TextureKind) void {
        const renderer: *Renderer = @ptrCast(@alignCast(ctx));
        renderer.backend.ops.terminal_draw.addTerminalGlyphQuad(renderer, texture, src, dest, color, kind);
    }

    fn addTerminalGlyphRectThunk(ctx: *anyopaque, x: i32, y: i32, w: i32, h: i32, color: Color) void {
        const renderer: *Renderer = @ptrCast(@alignCast(ctx));
        renderer.backend.ops.terminal_draw.addTerminalGlyphRect(renderer, x, y, w, h, color.toRgba());
    }

    fn drawTextureThunk(ctx: *anyopaque, texture: types.Texture, src: types.Rect, dest: types.Rect, color: types.Rgba, kind: types.TextureKind) void {
        const renderer: *Renderer = @ptrCast(@alignCast(ctx));
        draw_ops.drawTextureRect(renderer, texture, src, dest, color, renderer.text_render.bg_rgba, kind);
    }

    pub fn inputDomain(self: *Renderer) input_state.InputDomain {
        return .{
            .allocator = self.allocator,
            .app_host = &self.app_host,
            .window = self.window,
            .should_close_flag = &self.input.should_close_flag,
            .key_down = self.input.key_down[0..],
            .key_pressed = self.input.key_pressed[0..],
            .key_repeated = self.input.key_repeated[0..],
            .key_released = self.input.key_released[0..],
            .mouse_down = self.input.mouse_down[0..],
            .mouse_pressed = self.input.mouse_pressed[0..],
            .mouse_released = self.input.mouse_released[0..],
            .mouse_clicks = self.input.mouse_clicks[0..],
            .mouse_press_pos = self.input.mouse_press_pos[0..],
            .mouse_press_pos_valid = self.input.mouse_press_pos_valid[0..],
            .key_queue = &self.input.key_queue,
            .key_queue_head = &self.input.key_queue_head,
            .char_queue = &self.input.char_queue,
            .char_queue_head = &self.input.char_queue_head,
            .focus_queue = &self.input.focus_queue,
            .focus_queue_head = &self.input.focus_queue_head,
            .window_focused = &self.input.window_focused,
            .suppress_super_until_release = &self.input.suppress_super_until_release,
            .composing_text = &self.input.composing_text,
            .composing_cursor = &self.input.composing_cursor,
            .composing_selection_len = &self.input.composing_selection_len,
            .composing_active = &self.input.composing_active,
            .window_changes = &self.input.window_changes,
            .text_input_state = &self.input.text_input_state,
            .pending_wait_event = &self.input.pending_wait_event,
            .pending_wait_event_valid = &self.input.pending_wait_event_valid,
        };
    }

    fn getMousePosSdl() MousePos {
        var x: f32 = 0;
        var y: f32 = 0;
        sdl_api.getMouseState(&x, &y);
        return .{ .x = x, .y = y };
    }

    fn pollInputEvents(self: *Renderer) void {
        input_runtime.pollInputEventsWithRuntimeWheel(self.inputDomain());
    }
};

pub fn pollInputEvents() void {
    renderer_global_runtime.pollInputEvents(Renderer, Renderer.pollInputEvents);
}

pub fn waitTime(seconds: f64) void {
    renderer_global_runtime.waitTime(seconds);
}

pub fn waitForWakeOrTimeout(seconds: f64) void {
    renderer_global_runtime.waitForWakeOrTimeout(Renderer, seconds);
}

pub fn requestWake() void {
    renderer_global_runtime.requestWake(Renderer);
}

pub fn getTime() f64 {
    return renderer_global_runtime.getTime(Renderer);
}

pub fn setSdlLogLevel(level: c_int) void {
    renderer_global_runtime.setSdlLogLevel(level);
}

pub fn windowChanges() WindowChangeMask {
    return renderer_global_runtime.windowChanges(Renderer);
}

pub fn getScreenWidth() i32 {
    return renderer_global_runtime.getScreenWidth(Renderer);
}

pub fn getScreenHeight() i32 {
    return renderer_global_runtime.getScreenHeight(Renderer);
}

test "scale state refresh follows any real window refresh signal" {
    try std.testing.expect(!Renderer.shouldRefreshScaleStateForWindowChanges(.{}));
    try std.testing.expect(Renderer.shouldRefreshScaleStateForWindowChanges(.{ .resized = true }));
    try std.testing.expect(Renderer.shouldRefreshScaleStateForWindowChanges(.{ .pixel_size_changed = true }));
    try std.testing.expect(Renderer.shouldRefreshScaleStateForWindowChanges(.{ .display_changed = true }));
    try std.testing.expect(Renderer.shouldRefreshScaleStateForWindowChanges(.{ .display_scale_changed = true }));
}

test "moved-only window changes do not refresh scale state" {
    try std.testing.expect(!Renderer.shouldRefreshScaleStateForWindowChanges(.{ .moved = true }));
}

test "window refresh results redraw for exposed or resized events" {
    const geometry: WindowGeometryDiagnostics = .{
        .window_w = 100,
        .window_h = 100,
        .drawable_w = 100,
        .drawable_h = 100,
        .display_w = 100,
        .display_h = 100,
        .display_index = 0,
        .dpi = .{ .x = 1.0, .y = 1.0 },
        .display_scale = 1.0,
        .pixel_density = 1.0,
        .ui_scale = 1.0,
        .render_scale = 1.0,
        .screen = .{ .x = 100.0, .y = 100.0 },
        .render = .{ .x = 100.0, .y = 100.0 },
        .monitor = .{ .x = 100.0, .y = 100.0 },
    };

    try std.testing.expect((WindowRefreshResult{
        .changes = .{ .contents_exposed = true },
        .geometry = geometry,
    }).needsRedraw());
    try std.testing.expect((WindowRefreshResult{
        .changes = .{ .resized = true },
        .geometry = geometry,
    }).needsRedraw());
}
