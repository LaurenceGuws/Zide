const terminal_font_mod = @import("../terminal_font.zig");

const AtlasStorageMode = terminal_font_mod.AtlasStorageMode;

pub const ScreenshotMode = enum {
    unavailable,
    direct_window_readback,
    present_capture,
};

pub const SceneCompositionMode = enum {
    direct_main_target,
    offscreen_scene_target,
};

pub const TerminalPresentationMode = enum {
    direct_main_target,
    direct_snapshot_cache,
    retained_surface,
};

pub const TextRenderingMode = enum {
    unavailable,
    gl_texture_atlas,
    metal_texture_atlas,
};

pub const KittyImageMode = enum {
    unsupported,
    persistent_textures,
    direct_raw_images,
};

pub const RendererCapabilities = struct {
    scene_composition_mode: SceneCompositionMode,
    retained_targets: bool,
    terminal_presentation_mode: TerminalPresentationMode,
    screenshot_mode: ScreenshotMode,
    text_rendering_mode: TextRenderingMode,
    planned_text_rendering_mode: TextRenderingMode,
    kitty_image_mode: KittyImageMode,
    atlas_storage_mode: AtlasStorageMode,
    planned_atlas_storage_mode: AtlasStorageMode,
    raw_image_textures: bool,
};
