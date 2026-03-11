const std = @import("std");
const app_logger = @import("../app_logger.zig");
const builtin = @import("builtin");
const gl = @import("renderer/gl.zig");
const types = @import("renderer/types.zig");
const terminal_glyphs = @import("renderer/terminal_glyphs.zig");
const font_atlas = @import("font/atlas.zig");
const font_fallback = @import("font/fallback.zig");
const font_shaping = @import("font/shaping.zig");
const font_special_glyphs = @import("font/special_glyphs.zig");
const font_system_fallback = @import("font/system_fallback.zig");

pub var windows_com_initialized = std.atomic.Value(bool).init(false);

pub const windows_dwrite = if (builtin.target.os.tag == .windows) struct {
    const HRESULT = i32;
    const ULONG = u32;
    const UINT32 = u32;
    const UINT16 = u16;
    const BOOL = i32;

    const GUID = extern struct {
        Data1: u32,
        Data2: u16,
        Data3: u16,
        Data4: [8]u8,
    };

    const IID_IDWriteFactory = GUID{
        .Data1 = 0xB859EE5A,
        .Data2 = 0xD838,
        .Data3 = 0x4B5B,
        .Data4 = .{ 0xA2, 0xE8, 0x1A, 0xDC, 0x7D, 0x93, 0xDB, 0x48 },
    };
    const IID_IDWriteLocalFontFileLoader = GUID{
        .Data1 = 0xB2D9F3EC,
        .Data2 = 0xC9FE,
        .Data3 = 0x4A11,
        .Data4 = .{ 0xA2, 0xEC, 0xD8, 0x62, 0x08, 0xF7, 0xC0, 0xA2 },
    };

    const IID_IUnknown = GUID{
        .Data1 = 0x00000000,
        .Data2 = 0x0000,
        .Data3 = 0x0000,
        .Data4 = .{ 0xC0, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x46 },
    };

    const IUnknown = extern struct {
        vtbl: *const Vtbl,
        const Vtbl = extern struct {
            QueryInterface: *const fn (*IUnknown, *const GUID, *?*anyopaque) callconv(.winapi) HRESULT,
            AddRef: *const fn (*IUnknown) callconv(.winapi) ULONG,
            Release: *const fn (*IUnknown) callconv(.winapi) ULONG,
        };
    };

    const IDWriteFontFileLoader = extern struct {
        vtbl: *const IUnknown.Vtbl,
    };

    const IDWriteLocalFontFileLoader = extern struct {
        vtbl: *const Vtbl,
        const Vtbl = extern struct {
            QueryInterface: *const fn (*IDWriteLocalFontFileLoader, *const GUID, *?*anyopaque) callconv(.winapi) HRESULT,
            AddRef: *const fn (*IDWriteLocalFontFileLoader) callconv(.winapi) ULONG,
            Release: *const fn (*IDWriteLocalFontFileLoader) callconv(.winapi) ULONG,
            // IDWriteFontFileLoader methods
            CreateStreamFromKey: *const fn (*IDWriteLocalFontFileLoader, *const anyopaque, UINT32, *?*anyopaque) callconv(.winapi) HRESULT,
            // IDWriteLocalFontFileLoader methods
            GetFilePathLengthFromKey: *const fn (*IDWriteLocalFontFileLoader, *const anyopaque, UINT32, *UINT32) callconv(.winapi) HRESULT,
            GetFilePathFromKey: *const fn (*IDWriteLocalFontFileLoader, *const anyopaque, UINT32, [*]UINT16, UINT32) callconv(.winapi) HRESULT,
            GetLastWriteTimeFromKey: *const fn (*IDWriteLocalFontFileLoader, *const anyopaque, UINT32, *u64) callconv(.winapi) HRESULT,
        };
    };

    const IDWriteFontFile = extern struct {
        vtbl: *const Vtbl,
        const Vtbl = extern struct {
            QueryInterface: *const fn (*IDWriteFontFile, *const GUID, *?*anyopaque) callconv(.winapi) HRESULT,
            AddRef: *const fn (*IDWriteFontFile) callconv(.winapi) ULONG,
            Release: *const fn (*IDWriteFontFile) callconv(.winapi) ULONG,
            GetReferenceKey: *const fn (*IDWriteFontFile, *?*const anyopaque, *UINT32) callconv(.winapi) HRESULT,
            GetLoader: *const fn (*IDWriteFontFile, *?*IDWriteFontFileLoader) callconv(.winapi) HRESULT,
            Analyze: *const fn (*IDWriteFontFile, *BOOL, *u32, *u32, *BOOL) callconv(.winapi) HRESULT,
        };
    };

    const IDWriteFontFace = extern struct {
        vtbl: *const Vtbl,
        const Vtbl = extern struct {
            QueryInterface: *const fn (*IDWriteFontFace, *const GUID, *?*anyopaque) callconv(.winapi) HRESULT,
            AddRef: *const fn (*IDWriteFontFace) callconv(.winapi) ULONG,
            Release: *const fn (*IDWriteFontFace) callconv(.winapi) ULONG,
            GetType: *const fn (*IDWriteFontFace) callconv(.winapi) u32,
            GetFiles: *const fn (*IDWriteFontFace, *UINT32, ?[*]?*IDWriteFontFile) callconv(.winapi) HRESULT,
            GetIndex: *const fn (*IDWriteFontFace) callconv(.winapi) UINT32,
            GetSimulations: *const fn (*IDWriteFontFace) callconv(.winapi) u32,
            IsSymbolFont: *const fn (*IDWriteFontFace) callconv(.winapi) BOOL,
            GetMetrics: *const fn (*IDWriteFontFace, *anyopaque) callconv(.winapi) void,
            GetGlyphCount: *const fn (*IDWriteFontFace, *UINT16) callconv(.winapi) HRESULT,
            GetDesignGlyphMetrics: *const fn (*IDWriteFontFace, *const UINT16, UINT32, *anyopaque, BOOL) callconv(.winapi) HRESULT,
            GetGlyphIndices: *const fn (*IDWriteFontFace, *const UINT32, UINT32, *UINT16) callconv(.winapi) HRESULT,
        };
    };

    const IDWriteFont = extern struct {
        vtbl: *const Vtbl,
        const Vtbl = extern struct {
            QueryInterface: *const fn (*IDWriteFont, *const GUID, *?*anyopaque) callconv(.winapi) HRESULT,
            AddRef: *const fn (*IDWriteFont) callconv(.winapi) ULONG,
            Release: *const fn (*IDWriteFont) callconv(.winapi) ULONG,
            GetFontFamily: *const fn (*IDWriteFont, *?*IDWriteFontFamily) callconv(.winapi) HRESULT,
            GetWeight: *const fn (*IDWriteFont) callconv(.winapi) u32,
            GetStretch: *const fn (*IDWriteFont) callconv(.winapi) u32,
            GetStyle: *const fn (*IDWriteFont) callconv(.winapi) u32,
            IsSymbolFont: *const fn (*IDWriteFont) callconv(.winapi) BOOL,
            CreateFontFace: *const fn (*IDWriteFont, *?*IDWriteFontFace) callconv(.winapi) HRESULT,
        };
    };

    const IDWriteFontFamily = extern struct {
        vtbl: *const Vtbl,
        const Vtbl = extern struct {
            QueryInterface: *const fn (*IDWriteFontFamily, *const GUID, *?*anyopaque) callconv(.winapi) HRESULT,
            AddRef: *const fn (*IDWriteFontFamily) callconv(.winapi) ULONG,
            Release: *const fn (*IDWriteFontFamily) callconv(.winapi) ULONG,
            GetFontCollection: *const fn (*IDWriteFontFamily, *?*IDWriteFontCollection) callconv(.winapi) HRESULT,
            GetFontCount: *const fn (*IDWriteFontFamily, *UINT32) callconv(.winapi) HRESULT,
            GetFont: *const fn (*IDWriteFontFamily, UINT32, *?*IDWriteFont) callconv(.winapi) HRESULT,
        };
    };

    const IDWriteFontCollection = extern struct {
        vtbl: *const Vtbl,
        const Vtbl = extern struct {
            QueryInterface: *const fn (*IDWriteFontCollection, *const GUID, *?*anyopaque) callconv(.winapi) HRESULT,
            AddRef: *const fn (*IDWriteFontCollection) callconv(.winapi) ULONG,
            Release: *const fn (*IDWriteFontCollection) callconv(.winapi) ULONG,
            GetFontFamilyCount: *const fn (*IDWriteFontCollection) callconv(.winapi) UINT32,
            GetFontFamily: *const fn (*IDWriteFontCollection, UINT32, *?*IDWriteFontFamily) callconv(.winapi) HRESULT,
        };
    };

    const IDWriteFactory = extern struct {
        vtbl: *const Vtbl,
        const Vtbl = extern struct {
            QueryInterface: *const fn (*IDWriteFactory, *const GUID, *?*anyopaque) callconv(.winapi) HRESULT,
            AddRef: *const fn (*IDWriteFactory) callconv(.winapi) ULONG,
            Release: *const fn (*IDWriteFactory) callconv(.winapi) ULONG,
            GetSystemFontCollection: *const fn (*IDWriteFactory, *?*IDWriteFontCollection, BOOL) callconv(.winapi) HRESULT,
        };
    };

    const DWRITE_FACTORY_TYPE_SHARED: u32 = 0;

    extern "dwrite" fn DWriteCreateFactory(factory_type: u32, iid: *const GUID, out_factory: *?*anyopaque) callconv(.winapi) HRESULT;
    extern "ole32" fn CoInitializeEx(reserved: ?*anyopaque, coinit: u32) callconv(.winapi) HRESULT;

    const COINIT_MULTITHREADED: u32 = 0;
    const RPC_E_CHANGED_MODE: HRESULT = @bitCast(@as(u32, 0x80010106));

    fn release(ptr: anytype) void {
        if (ptr) |p| {
            const T = @TypeOf(p);
            _ = T.vtbl.Release(p);
        }
    }

    fn queryInterface(comptime T: type, unk: *IUnknown, iid: *const GUID) ?*T {
        var out: ?*anyopaque = null;
        if (unk.vtbl.QueryInterface(unk, iid, &out) < 0) return null;
        return @ptrCast(out.?);
    }
} else struct {};

pub const c = @cImport({
    @cInclude("ft2build.h");
    @cInclude("freetype/freetype.h");
    @cInclude("freetype/ftglyph.h");
    @cInclude("harfbuzz/hb.h");
    @cInclude("harfbuzz/hb-ft.h");
});

pub const HintingMode = enum {
    default,
    none,
    light,
    normal,
};

pub const RenderingOptions = struct {
    lcd: bool = false,
    hinting: HintingMode = .default,
    autohint: bool = false,
    glyph_overflow: AllowSquareGlyphOverflow = .when_followed_by_space,
};

// FreeType encodes the target render mode in bits 16..19 of the load flags.
// The upstream macro is `FT_LOAD_TARGET_MODE` but it may import as a function.
const ft_load_target_mode_mask: c_int = 0xF0000;

fn computeFtLoadFlagsBase(opts: RenderingOptions) c_int {
    var flags: c_int = c.FT_LOAD_DEFAULT;

    if (opts.autohint) flags |= c.FT_LOAD_FORCE_AUTOHINT;

    switch (opts.hinting) {
        .default => {},
        .none => {
            flags |= c.FT_LOAD_NO_HINTING;
            flags &= ~ft_load_target_mode_mask;
        },
        .light => {
            flags &= ~ft_load_target_mode_mask;
            flags |= c.FT_LOAD_TARGET_LIGHT;
        },
        .normal => {
            flags &= ~ft_load_target_mode_mask;
            flags |= c.FT_LOAD_TARGET_NORMAL;
        },
    }

    if (opts.lcd) {
        flags &= ~ft_load_target_mode_mask;
        flags |= c.FT_LOAD_TARGET_LCD;
    }

    return flags;
}

pub fn applyHbLoadFlags(hb_font: *c.hb_font_t, ft_load_flags: c_int) void {
    // HarfBuzz should use the same load flags as rasterization for consistent
    // advances and layout.
    if (@hasDecl(c, "hb_ft_font_set_load_flags")) {
        c.hb_ft_font_set_load_flags(hb_font, ft_load_flags);
    }
}

pub const fc = if (builtin.target.os.tag == .linux) @cImport({
    @cInclude("fontconfig/fontconfig.h");
}) else struct {
    pub const FcConfig = opaque {};
    pub const FcPattern = opaque {};
    pub const FcCharSet = opaque {};
    pub const FcResult = enum(c_int) { FcResultMatch = 0 };
    pub const FcResultMatch: FcResult = .FcResultMatch;
    pub const FcChar8 = u8;
    pub const FcMatchPattern: c_int = 0;
    pub const FC_CHARSET: c_int = 0;
    pub const FC_SCALABLE: c_int = 0;
    pub const FC_FILE: c_int = 0;

    pub fn FcInit() c_int {
        return 0;
    }

    pub fn FcConfigGetCurrent() ?*FcConfig {
        return null;
    }

    pub fn FcPatternCreate() ?*FcPattern {
        return null;
    }

    pub fn FcPatternDestroy(_: ?*FcPattern) void {}

    pub fn FcCharSetCreate() ?*FcCharSet {
        return null;
    }

    pub fn FcCharSetDestroy(_: ?*FcCharSet) void {}

    pub fn FcCharSetAddChar(_: ?*FcCharSet, _: u32) c_int {
        return 0;
    }

    pub fn FcPatternAddCharSet(_: ?*FcPattern, _: c_int, _: ?*FcCharSet) c_int {
        return 0;
    }

    pub fn FcPatternAddBool(_: ?*FcPattern, _: c_int, _: c_int) c_int {
        return 0;
    }

    pub fn FcConfigSubstitute(_: ?*FcConfig, _: ?*FcPattern, _: c_int) c_int {
        return 0;
    }

    pub fn FcDefaultSubstitute(_: ?*FcPattern) void {}

    pub fn FcFontMatch(_: ?*FcConfig, _: ?*FcPattern, _: *FcResult) ?*FcPattern {
        return null;
    }

    pub fn FcPatternGetString(_: ?*FcPattern, _: c_int, _: c_int, _: *[*c]FcChar8) FcResult {
        return .FcResultMatch;
    }
};

const FcConfigPtr = *fc.FcConfig;
// TODO(macOS): Add CoreText-based fallback resolution for missing glyphs.
// TODO(Windows): Improve DirectWrite fallback performance (current implementation enumerates system fonts with caps and caches by codepoint).

pub const AllowSquareGlyphOverflow = enum {
    never,
    always,
    when_followed_by_space,
};

pub const Rect = types.Rect;
pub const Texture = types.Texture;
pub const TextureKind = types.TextureKind;
pub const Rgba = types.Rgba;

pub const DrawContext = struct {
    ctx: *anyopaque,
    drawTexture: *const fn (ctx: *anyopaque, texture: Texture, src: Rect, dest: Rect, color: Rgba, kind: TextureKind) void,
};

fn isPowerlineCodepoint(cp: u32) bool {
    return cp >= 0xE0B0 and cp <= 0xE0BF;
}

fn isThickPowerlineCodepoint(cp: u32) bool {
    return cp == 0xE0B0 or cp == 0xE0B2;
}

pub const Glyph = struct {
    rect: Rect,
    bearing_x: i32,
    bearing_y: i32,
    advance: f32,
    width: i32,
    height: i32,
    is_color: bool,
};

pub const SpecialGlyphSpriteKey = types.SpecialGlyphSpriteKey;
pub const SpecialGlyphVariant = types.SpecialGlyphVariant;
pub const SpecialGlyphSprite = types.SpecialGlyphSprite;

pub const FacePair = struct {
    face: ?c.FT_Face = null,
    hb: ?*c.hb_font_t = null,

    // If a face was created via FT_New_Memory_Face, this buffer must stay alive
    // until the face is destroyed.
    owned_data: ?[]u8 = null,
};

pub const GlyphError = error{
    HbShapeFailed,
    FtLoadFailed,
    FtRenderFailed,
    AtlasFull,
    OutOfMemory,
};

const GlyphKey = struct {
    face: c.FT_Face,
    glyph_id: u32,
    want_color: bool,
};

pub const TerminalFont = struct {
    allocator: std.mem.Allocator,
    ft_library: c.FT_Library,
    ft_face: c.FT_Face,
    symbols_ft_face: ?c.FT_Face,
    unicode_symbols2_ft_face: ?c.FT_Face,
    unicode_symbols_ft_face: ?c.FT_Face,
    unicode_mono_ft_face: ?c.FT_Face,
    unicode_sans_ft_face: ?c.FT_Face,
    emoji_color_ft_face: ?c.FT_Face,
    emoji_text_ft_face: ?c.FT_Face,
    hb_font: *c.hb_font_t,
    symbols_hb_font: ?*c.hb_font_t,
    unicode_symbols2_hb_font: ?*c.hb_font_t,
    unicode_symbols_hb_font: ?*c.hb_font_t,
    unicode_mono_hb_font: ?*c.hb_font_t,
    unicode_sans_hb_font: ?*c.hb_font_t,
    emoji_color_hb_font: ?*c.hb_font_t,
    emoji_text_hb_font: ?*c.hb_font_t,
    fc_enabled: bool,
    fc_config: ?FcConfigPtr,
    system_fallback_by_cp: std.AutoHashMap(u32, ?[]u8),
    system_faces: std.StringHashMapUnmanaged(FacePair),
    coverage_texture: Texture,
    color_texture: Texture,
    atlas_width: i32,
    atlas_height: i32,
    pen_x: i32,
    pen_y: i32,
    row_h: i32,
    padding: i32,
    glyphs: std.AutoHashMap(GlyphKey, Glyph),
    glyph_order: std.ArrayList(GlyphKey),
    special_glyph_sprites: std.AutoHashMap(SpecialGlyphSpriteKey, SpecialGlyphSprite),
    max_glyphs: usize,
    upload_buffer: []u8,
    upload_buffer_capacity: usize,
    ascent: f32,
    descent: f32,
    line_height: f32,
    baseline_from_top: f32,
    cell_width: f32,
    ft_load_flags_base: c_int,
    render_scale: f32,
    use_lcd: bool,
    overflow_policy: AllowSquareGlyphOverflow,
    ascii_primary_glyph_ids: [128]u32,

    pub const FontChoice = struct {
        face: c.FT_Face,
        hb_font: *c.hb_font_t,
        want_color: bool,
    };

    pub fn init(
        allocator: std.mem.Allocator,
        path: [*:0]const u8,
        size: f32,
        symbols_path: ?[*:0]const u8,
        unicode_symbols2_path: ?[*:0]const u8,
        unicode_symbols_path: ?[*:0]const u8,
        unicode_mono_path: ?[*:0]const u8,
        unicode_sans_path: ?[*:0]const u8,
        emoji_color_path: ?[*:0]const u8,
        emoji_text_path: ?[*:0]const u8,
        opts: RenderingOptions,
    ) !TerminalFont {
        var ft_library: c.FT_Library = null;
        if (c.FT_Init_FreeType(&ft_library) != 0) return error.FtInitFailed;
        errdefer _ = c.FT_Done_FreeType(ft_library);

        var ft_face: c.FT_Face = null;
        if (c.FT_New_Face(ft_library, path, 0, &ft_face) != 0) return error.FtFaceFailed;
        errdefer _ = c.FT_Done_Face(ft_face);
        if (c.FT_Set_Pixel_Sizes(ft_face, 0, @intFromFloat(size)) != 0) return error.FtSizeFailed;

        const hb_font = c.hb_ft_font_create(ft_face, null) orelse return error.HbInitFailed;
        errdefer c.hb_font_destroy(hb_font);

        const ft_load_flags_base = computeFtLoadFlagsBase(opts);
        applyHbLoadFlags(hb_font, ft_load_flags_base);

        const loadFace = struct {
            fn call(
                library: c.FT_Library,
                fpath: ?[*:0]const u8,
                size_px: f32,
                name: []const u8,
                log: app_logger.Logger,
                allow_fixed_size: bool,
                hb_load_flags_base: c_int,
            ) FacePair {
                if (fpath) |path_c| {
                    const path_str = std.mem.sliceTo(path_c, 0);
                    if (std.fs.cwd().access(path_str, .{})) |_| {
                        log.logf(.info, "font load: {s} path={s}", .{ name, path_str });
                    } else |err| {
                        log.logf(.info, "font load: {s} path={s} access_err={s}", .{ name, path_str, @errorName(err) });
                    }
                    var fb_face: c.FT_Face = null;
                    const new_face_err = c.FT_New_Face(library, path_c, 0, &fb_face);
                    if (new_face_err == 0) {
                        const size_err = c.FT_Set_Pixel_Sizes(fb_face, 0, @intFromFloat(size_px));
                        if (size_err != 0 and allow_fixed_size and fb_face.*.num_fixed_sizes > 0) {
                            var best_idx: c_int = 0;
                            var best_delta: u32 = std.math.maxInt(u32);
                            var idx: c_int = 0;
                            while (idx < fb_face.*.num_fixed_sizes) : (idx += 1) {
                                const s = fb_face.*.available_sizes[@intCast(idx)];
                                const delta: u32 = @intCast(@abs(@as(i32, @intCast(s.height)) - @as(i32, @intFromFloat(size_px))));
                                if (delta < best_delta) {
                                    best_delta = delta;
                                    best_idx = idx;
                                }
                            }
                            _ = c.FT_Select_Size(fb_face, best_idx);
                        } else if (size_err != 0) {
                            log.logf(.info, "font load failed: {s} set_pixel_sizes err={d}", .{ name, size_err });
                        }
                        if (size_err == 0 or (allow_fixed_size and fb_face.*.num_fixed_sizes > 0)) {
                            if (c.hb_ft_font_create(fb_face, null)) |fb_hb| {
                                applyHbLoadFlags(fb_hb, hb_load_flags_base);
                                return .{ .face = fb_face, .hb = fb_hb };
                            }
                            log.logf(.info, "font load failed: {s} hb_ft_font_create returned null", .{name});
                        }
                        _ = c.FT_Done_Face(fb_face);
                    } else {
                        log.logf(.info, "font load failed: {s} FT_New_Face err={d}", .{ name, new_face_err });
                    }
                } else {
                    log.logf(.info, "font load skipped: {s} path not set", .{name});
                }
                return .{};
            }
        }.call;

        const log = app_logger.logger("terminal.font");
        const symbols_pair = loadFace(ft_library, symbols_path, size, "symbols", log, false, ft_load_flags_base);
        const unicode_symbols2_pair = loadFace(ft_library, unicode_symbols2_path, size, "unicode_symbols2", log, false, ft_load_flags_base);
        const unicode_symbols_pair = loadFace(ft_library, unicode_symbols_path, size, "unicode_symbols", log, false, ft_load_flags_base);
        const unicode_mono_pair = loadFace(ft_library, unicode_mono_path, size, "unicode_mono", log, false, ft_load_flags_base);
        const unicode_sans_pair = loadFace(ft_library, unicode_sans_path, size, "unicode_sans", log, false, ft_load_flags_base);
        const emoji_color_pair = loadFace(ft_library, emoji_color_path, size, "emoji_color", log, true, ft_load_flags_base);
        const emoji_text_pair = loadFace(ft_library, emoji_text_path, size, "emoji_text", log, false, ft_load_flags_base);

        var fc_enabled = false;
        var fc_config: ?FcConfigPtr = null;
        if (builtin.target.os.tag == .linux) {
            if (fc.FcInit() != 0) {
                fc_enabled = true;
                fc_config = fc.FcConfigGetCurrent();
            } else {
                log.logf(.info, "fontconfig init failed", .{});
            }
        }

        const cp_arrow: u32 = 0x21E1; // ⇡
        const cp_braille: u32 = 0x28FF; // ⣿
        const cp_emoji: u32 = 0x1F600; // 😀
        const has_cp = struct {
            fn call(face_opt: ?c.FT_Face, cp: u32) bool {
                if (face_opt) |face| return c.FT_Get_Char_Index(face, cp) != 0;
                return false;
            }
        }.call;

        log.logf(.info,
            "font load: primary={d} symbols={d} sym2={d} sym={d} mono={d} sans={d} emoji_color={d} emoji_text={d}",
            .{
                @as(u8, if (ft_face != null) 1 else 0),
                @as(u8, if (symbols_pair.face != null) 1 else 0),
                @as(u8, if (unicode_symbols2_pair.face != null) 1 else 0),
                @as(u8, if (unicode_symbols_pair.face != null) 1 else 0),
                @as(u8, if (unicode_mono_pair.face != null) 1 else 0),
                @as(u8, if (unicode_sans_pair.face != null) 1 else 0),
                @as(u8, if (emoji_color_pair.face != null) 1 else 0),
                @as(u8, if (emoji_text_pair.face != null) 1 else 0),
            },
        );
        log.logf(.info,
            "glyph coverage: ⇡ p={d} sym={d} s2={d} s={d} m={d} sans={d} | ⣿ p={d} sym={d} s2={d} s={d} m={d} sans={d} | 😀 p={d} sym={d} s2={d} s={d} m={d} sans={d} ec={d} et={d}",
            .{
                @as(u8, if (has_cp(ft_face, cp_arrow)) 1 else 0),
                @as(u8, if (has_cp(symbols_pair.face, cp_arrow)) 1 else 0),
                @as(u8, if (has_cp(unicode_symbols2_pair.face, cp_arrow)) 1 else 0),
                @as(u8, if (has_cp(unicode_symbols_pair.face, cp_arrow)) 1 else 0),
                @as(u8, if (has_cp(unicode_mono_pair.face, cp_arrow)) 1 else 0),
                @as(u8, if (has_cp(unicode_sans_pair.face, cp_arrow)) 1 else 0),
                @as(u8, if (has_cp(ft_face, cp_braille)) 1 else 0),
                @as(u8, if (has_cp(symbols_pair.face, cp_braille)) 1 else 0),
                @as(u8, if (has_cp(unicode_symbols2_pair.face, cp_braille)) 1 else 0),
                @as(u8, if (has_cp(unicode_symbols_pair.face, cp_braille)) 1 else 0),
                @as(u8, if (has_cp(unicode_mono_pair.face, cp_braille)) 1 else 0),
                @as(u8, if (has_cp(unicode_sans_pair.face, cp_braille)) 1 else 0),
                @as(u8, if (has_cp(ft_face, cp_emoji)) 1 else 0),
                @as(u8, if (has_cp(symbols_pair.face, cp_emoji)) 1 else 0),
                @as(u8, if (has_cp(unicode_symbols2_pair.face, cp_emoji)) 1 else 0),
                @as(u8, if (has_cp(unicode_symbols_pair.face, cp_emoji)) 1 else 0),
                @as(u8, if (has_cp(unicode_mono_pair.face, cp_emoji)) 1 else 0),
                @as(u8, if (has_cp(unicode_sans_pair.face, cp_emoji)) 1 else 0),
                @as(u8, if (has_cp(emoji_color_pair.face, cp_emoji)) 1 else 0),
                @as(u8, if (has_cp(emoji_text_pair.face, cp_emoji)) 1 else 0),
            },
        );

        const metrics = ft_face.*.size.*.metrics;
        const ascent_raw = @as(f32, @floatFromInt(metrics.ascender)) / 64.0;
        const descent_raw = @abs(@as(f32, @floatFromInt(metrics.descender)) / 64.0);
        const line_height_raw = @as(f32, @floatFromInt(metrics.height)) / 64.0;

        // Derive a reasonable monospace cell width from representative ASCII.
        // Some fonts (especially Nerd Font builds) can report a very large
        // `max_advance` due to extra-wide symbols; using it directly causes
        // gaps/cursor width regressions.
        var cell_width: f32 = 0;
        const max_advance = @as(f32, @floatFromInt(metrics.max_advance >> 6));
        const samples = [_]u32{ '0', ' ', 'M', 'W', 'i', 'n' };
        for (samples) |cp| {
            // HarfBuzz advance
            const buffer = c.hb_buffer_create();
            defer c.hb_buffer_destroy(buffer);
            c.hb_buffer_add_utf32(buffer, &cp, 1, 0, 1);
            c.hb_buffer_guess_segment_properties(buffer);
            c.hb_shape(hb_font, buffer, null, 0);
            var sample_len: c_uint = 0;
            const sample_pos = c.hb_buffer_get_glyph_positions(buffer, &sample_len);
            if (sample_len > 0) {
                const adv = @as(f32, @floatFromInt(sample_pos[0].x_advance)) / 64.0;
                if (adv > cell_width) cell_width = adv;
            }

            // FreeType metrics for visual width (bitmap + bearing)
            if (c.FT_Load_Char(ft_face, cp, ft_load_flags_base) == 0) {
                const slot = ft_face.*.glyph;
                const metric_w = @as(f32, @floatFromInt(slot.*.metrics.width >> 6));
                const bearing = @as(f32, @floatFromInt(@max(0, slot.*.bitmap_left)));
                const visual = metric_w + bearing;
                if (visual > cell_width) cell_width = visual;
                const adv_ft = @as(f32, @floatFromInt(slot.*.advance.x >> 6));
                if (adv_ft > cell_width) cell_width = adv_ft;
            }
        }

        if (cell_width <= 0) cell_width = max_advance;
        if (cell_width <= 0) {
            cell_width = size * 0.6;
        }
        const cell_width_px = @as(f32, @floatFromInt(@as(i32, @intFromFloat(std.math.round(cell_width)))));

        const ascent_px_rounded = @as(f32, @floatFromInt(@as(i32, @intFromFloat(std.math.ceil(ascent_raw)))));
        const descent_px = @as(f32, @floatFromInt(@as(i32, @intFromFloat(std.math.ceil(descent_raw)))));
        const line_height_px = @as(f32, @floatFromInt(@as(i32, @intFromFloat(std.math.ceil(line_height_raw)))));
        // Keep baseline placement stable by ensuring ascent does not undershoot the
        // line-height/descent relationship at fractional UI/render scales.
        const ascent_from_line = @max(1.0, line_height_px - descent_px);
        const ascent_px = @max(ascent_px_rounded, ascent_from_line);

        // Follow ghostty-style terminal metrics: derive a rounded baseline from
        // line-height/descent with centered line-gap distribution in the cell.
        const line_gap_raw = line_height_raw - (ascent_raw + descent_raw);
        const half_line_gap = line_gap_raw / 2.0;
        const face_baseline_from_bottom = half_line_gap + descent_raw;
        const cell_baseline = std.math.round(face_baseline_from_bottom - (line_height_px - line_height_raw) / 2.0);
        const baseline_from_top = @max(1.0, @min(line_height_px, line_height_px - cell_baseline));

        const atlas_width: i32 = 2048;
        const atlas_height: i32 = 2048;
        const padding: i32 = 1;

        const zero_cov_len: usize = @as(usize, @intCast(atlas_width * atlas_height));
        const zero_cov_buf = allocator.alloc(u8, zero_cov_len) catch return error.OutOfMemory;
        defer allocator.free(zero_cov_buf);
        @memset(zero_cov_buf, 0);
        const coverage_texture = font_atlas.createTextureR8(atlas_width, atlas_height, zero_cov_buf);

        const zero_col_len: usize = @as(usize, @intCast(atlas_width * atlas_height * 4));
        const zero_col_buf = allocator.alloc(u8, zero_col_len) catch return error.OutOfMemory;
        defer allocator.free(zero_col_buf);
        @memset(zero_col_buf, 0);
        const color_texture = font_atlas.createTexture(atlas_width, atlas_height, zero_col_buf);

        return .{
            .allocator = allocator,
            .ft_library = ft_library,
            .ft_face = ft_face,
            .symbols_ft_face = symbols_pair.face,
            .unicode_symbols2_ft_face = unicode_symbols2_pair.face,
            .unicode_symbols_ft_face = unicode_symbols_pair.face,
            .unicode_mono_ft_face = unicode_mono_pair.face,
            .unicode_sans_ft_face = unicode_sans_pair.face,
            .emoji_color_ft_face = emoji_color_pair.face,
            .emoji_text_ft_face = emoji_text_pair.face,
            .hb_font = hb_font,
            .symbols_hb_font = symbols_pair.hb,
            .unicode_symbols2_hb_font = unicode_symbols2_pair.hb,
            .unicode_symbols_hb_font = unicode_symbols_pair.hb,
            .unicode_mono_hb_font = unicode_mono_pair.hb,
            .unicode_sans_hb_font = unicode_sans_pair.hb,
            .emoji_color_hb_font = emoji_color_pair.hb,
            .emoji_text_hb_font = emoji_text_pair.hb,
            .fc_enabled = fc_enabled,
            .fc_config = fc_config,
            .system_fallback_by_cp = std.AutoHashMap(u32, ?[]u8).init(allocator),
            .system_faces = .{},
            .coverage_texture = coverage_texture,
            .color_texture = color_texture,
            .atlas_width = atlas_width,
            .atlas_height = atlas_height,
            .pen_x = padding,
            .pen_y = padding,
            .row_h = 0,
            .padding = padding,
            .glyphs = std.AutoHashMap(GlyphKey, Glyph).init(allocator),
            .glyph_order = .empty,
            .special_glyph_sprites = std.AutoHashMap(SpecialGlyphSpriteKey, SpecialGlyphSprite).init(allocator),
            .max_glyphs = 2048,
            .upload_buffer = &[_]u8{},
            .upload_buffer_capacity = 0,
            .ascent = ascent_px,
            .descent = descent_px,
            .line_height = if (line_height_px > 0) line_height_px else ascent_px + descent_px,
            .baseline_from_top = baseline_from_top,
            .cell_width = if (cell_width_px > 0) cell_width_px else size * 0.6,
            .ft_load_flags_base = ft_load_flags_base,
            .render_scale = 1.0,
            .use_lcd = opts.lcd,
            .overflow_policy = opts.glyph_overflow,
            .ascii_primary_glyph_ids = buildAsciiPrimaryGlyphIds(ft_face),
        };
    }

    pub fn deinit(self: *TerminalFont) void {
        self.glyphs.deinit();
        self.glyph_order.deinit(self.allocator);
        self.special_glyph_sprites.deinit();
        if (self.upload_buffer_capacity > 0) {
            self.allocator.free(self.upload_buffer);
        }
        {
            var it = self.system_fallback_by_cp.iterator();
            while (it.next()) |entry| {
                if (entry.value_ptr.*) |path| {
                    if (!self.system_faces.contains(path)) {
                        self.allocator.free(path);
                    }
                }
            }
            self.system_fallback_by_cp.deinit();
        }

        var face_it = self.system_faces.iterator();
        while (face_it.next()) |entry| {
            if (entry.value_ptr.*.hb) |hb| c.hb_font_destroy(hb);
            if (entry.value_ptr.*.face) |face| _ = c.FT_Done_Face(face);
            if (entry.value_ptr.*.owned_data) |data| self.allocator.free(data);
            self.allocator.free(entry.key_ptr.*);
        }
        self.system_faces.deinit(self.allocator);

        if (self.coverage_texture.id != 0) gl.DeleteTextures(1, &self.coverage_texture.id);
        if (self.color_texture.id != 0) gl.DeleteTextures(1, &self.color_texture.id);
        if (self.symbols_hb_font) |fb_hb| c.hb_font_destroy(fb_hb);
        if (self.symbols_ft_face) |fb_face| _ = c.FT_Done_Face(fb_face);
        if (self.unicode_symbols2_hb_font) |fb_hb| c.hb_font_destroy(fb_hb);
        if (self.unicode_symbols2_ft_face) |fb_face| _ = c.FT_Done_Face(fb_face);
        if (self.unicode_symbols_hb_font) |fb_hb| c.hb_font_destroy(fb_hb);
        if (self.unicode_symbols_ft_face) |fb_face| _ = c.FT_Done_Face(fb_face);
        if (self.unicode_mono_hb_font) |fb_hb| c.hb_font_destroy(fb_hb);
        if (self.unicode_mono_ft_face) |fb_face| _ = c.FT_Done_Face(fb_face);
        if (self.unicode_sans_hb_font) |fb_hb| c.hb_font_destroy(fb_hb);
        if (self.unicode_sans_ft_face) |fb_face| _ = c.FT_Done_Face(fb_face);
        if (self.emoji_color_hb_font) |fb_hb| c.hb_font_destroy(fb_hb);
        if (self.emoji_color_ft_face) |fb_face| _ = c.FT_Done_Face(fb_face);
        if (self.emoji_text_hb_font) |fb_hb| c.hb_font_destroy(fb_hb);
        if (self.emoji_text_ft_face) |fb_face| _ = c.FT_Done_Face(fb_face);
        c.hb_font_destroy(self.hb_font);
        _ = c.FT_Done_Face(self.ft_face);
        _ = c.FT_Done_FreeType(self.ft_library);
    }

    fn getGlyphByKey(self: *TerminalFont, key: GlyphKey, hb_x_advance: c_int) GlyphError!*Glyph {
        if (self.glyphs.getPtr(key)) |glyph| return glyph;
        try self.rasterizeGlyphKey(key, hb_x_advance, true);
        return self.glyphs.getPtr(key).?;
    }

    pub fn getGlyphById(self: *TerminalFont, face: c.FT_Face, glyph_id: u32, want_color: bool, hb_x_advance: c_int) GlyphError!*Glyph {
        const key = GlyphKey{ .face = face, .glyph_id = glyph_id, .want_color = want_color };
        return self.getGlyphByKey(key, hb_x_advance);
    }

    pub fn pickFontForCodepoint(self: *TerminalFont, codepoint_in: u32) FontChoice {
        var codepoint = codepoint_in;
        if (codepoint == 0) codepoint = ' ';

        var face = self.ft_face;
        var hb_font = self.hb_font;
        const preferred = font_fallback.pickPreferred(self, codepoint);
        if (preferred.face) |p_face| {
            if (preferred.hb) |p_hb| {
                face = p_face;
                hb_font = p_hb;
            }
        } else if (!hasGlyph(face, codepoint)) {
            const fallback = font_fallback.pickFallback(self, codepoint);
            if (fallback.face) |fb_face| {
                if (fallback.hb) |fb_hb| {
                    face = fb_face;
                    hb_font = fb_hb;
                }
            }
            if (!hasGlyph(face, codepoint)) {
                if (self.systemFallback(codepoint)) |pair| {
                    if (pair.face) |sf_face| {
                        if (pair.hb) |sf_hb| {
                            face = sf_face;
                            hb_font = sf_hb;
                        }
                    }
                }
            }
        }

        const is_color_face = c.FT_HAS_COLOR(face) or (self.emoji_color_ft_face != null and face == self.emoji_color_ft_face.?);
        return .{ .face = face, .hb_font = hb_font, .want_color = is_color_face };
    }

    pub const DirectFastGlyph = struct {
        face: c.FT_Face,
        want_color: bool,
        glyph_id: u32,
        simple_ascii: bool,
    };

    pub fn directFastGlyphForCodepoint(self: *TerminalFont, codepoint_in: u32) ?DirectFastGlyph {
        const codepoint = if (codepoint_in == 0) @as(u32, ' ') else codepoint_in;
        if (codepoint < self.ascii_primary_glyph_ids.len) {
            const glyph_id = self.ascii_primary_glyph_ids[codepoint];
            if (glyph_id != 0) {
                return .{
                    .face = self.ft_face,
                    .want_color = false,
                    .glyph_id = glyph_id,
                    .simple_ascii = true,
                };
            }
        }
        return null;
    }

    pub fn setAtlasFilterPoint(self: *TerminalFont) void {
        font_atlas.setAtlasFilterPoint(self);
    }

    pub fn specialGlyphSpriteKey(
        self: *const TerminalFont,
        codepoint: u32,
        raster_w_px: i32,
        raster_h_px: i32,
        variant: SpecialGlyphVariant,
    ) SpecialGlyphSpriteKey {
        return font_special_glyphs.specialGlyphSpriteKey(self, codepoint, raster_w_px, raster_h_px, variant);
    }

    pub fn getSpecialGlyphSprite(
        self: *TerminalFont,
        key: SpecialGlyphSpriteKey,
    ) ?*SpecialGlyphSprite {
        return font_special_glyphs.getSpecialGlyphSprite(self, key);
    }

    pub fn putSpecialGlyphSprite(
        self: *TerminalFont,
        key: SpecialGlyphSpriteKey,
        sprite: SpecialGlyphSprite,
    ) !void {
        try font_special_glyphs.putSpecialGlyphSprite(self, key, sprite);
    }

    pub fn getOrCreateSpecialGlyphSprite(
        self: *TerminalFont,
        codepoint: u32,
        cell_w_px: i32,
        cell_h_px: i32,
        raster_w_px: i32,
        raster_h_px: i32,
        variant: SpecialGlyphVariant,
    ) ?*SpecialGlyphSprite {
        return font_special_glyphs.getOrCreateSpecialGlyphSprite(self, codepoint, cell_w_px, cell_h_px, raster_w_px, raster_h_px, variant);
    }

    pub fn drawGlyph(self: *TerminalFont, draw: DrawContext, codepoint: u32, x: f32, y: f32, cell_width: f32, cell_height: f32, followed_by_space: bool, color: Rgba) void {
        font_shaping.drawGlyph(self, draw, codepoint, x, y, cell_width, cell_height, followed_by_space, color);
    }

    pub fn drawGrapheme(
        self: *TerminalFont,
        draw: DrawContext,
        base: u32,
        combining: []const u32,
        x: f32,
        y: f32,
        cell_width: f32,
        cell_height: f32,
        followed_by_space: bool,
        color: Rgba,
    ) void {
        font_shaping.drawGrapheme(self, draw, base, combining, x, y, cell_width, cell_height, followed_by_space, color);
    }

    pub fn glyphAdvance(self: *TerminalFont, codepoint: u32) GlyphError!f32 {
        return font_shaping.glyphAdvance(self, codepoint);
    }

    fn getGlyphForCodepoint(self: *TerminalFont, codepoint: u32) GlyphError!*Glyph {
        return font_shaping.getGlyphForCodepoint(self, codepoint);
    }

    fn hasGlyph(face: c.FT_Face, codepoint: u32) bool {
        return c.FT_Get_Char_Index(face, codepoint) != 0;
    }

    fn buildAsciiPrimaryGlyphIds(face: c.FT_Face) [128]u32 {
        var glyph_ids: [128]u32 = [_]u32{0} ** 128;
        var cp: usize = 0;
        while (cp < glyph_ids.len) : (cp += 1) {
            const mapped = if (cp == 0) @as(u32, ' ') else @as(u32, @intCast(cp));
            glyph_ids[cp] = c.FT_Get_Char_Index(face, mapped);
        }
        return glyph_ids;
    }

    pub fn ftLoadFlags(self: *const TerminalFont, want_color: bool) c_int {
        var flags: c_int = self.ft_load_flags_base;
        if (want_color) flags |= c.FT_LOAD_COLOR;
        // If subpixel mode is enabled, only apply it to coverage glyphs.
        if (self.use_lcd and !want_color) {
            flags &= ~ft_load_target_mode_mask;
            flags |= c.FT_LOAD_TARGET_LCD;
        }
        return flags;
    }

    fn preferSymbols(codepoint: u32) bool {
        return (codepoint >= 0xE000 and codepoint <= 0xF8FF) or // PUA (Nerd Font)
            (codepoint >= 0xF0000 and codepoint <= 0xFFFFD) or // PUA-A
            (codepoint >= 0x100000 and codepoint <= 0x10FFFD) or // PUA-B
            (codepoint >= 0x2500 and codepoint <= 0x259F) or // Box Drawing + Block Elements
            (codepoint >= 0x2800 and codepoint <= 0x28FF) or // Braille Patterns
            (codepoint >= 0x1FB00 and codepoint <= 0x1FBFF); // Symbols for Legacy Computing
    }

    fn preferEmoji(codepoint: u32) bool {
        return (codepoint >= 0x1F000 and codepoint <= 0x1FAFF) or // main emoji blocks
            (codepoint >= 0x1F1E6 and codepoint <= 0x1F1FF) or // regional indicators
            (codepoint >= 0x2600 and codepoint <= 0x27BF); // misc symbols/dingbats
    }

    fn preferUnicode(codepoint: u32) bool {
        return (codepoint >= 0x2500 and codepoint <= 0x259F) or // Box Drawing + Block Elements
            (codepoint >= 0x2190 and codepoint <= 0x21FF) or // Arrows
            (codepoint >= 0x2800 and codepoint <= 0x28FF) or // Braille Patterns
            (codepoint >= 0x1FB00 and codepoint <= 0x1FBFF); // Symbols for Legacy Computing
    }

    fn pickPreferred(self: *TerminalFont, codepoint: u32) struct { face: ?c.FT_Face, hb: ?*c.hb_font_t } {
        if (preferSymbols(codepoint)) {
            if (self.symbols_ft_face) |face| {
                if (self.symbols_hb_font) |hb| {
                    if (hasGlyph(face, codepoint)) return .{ .face = face, .hb = hb };
                }
            }
        }
        if (preferUnicode(codepoint)) {
            if (self.unicode_symbols2_ft_face) |face| {
                if (self.unicode_symbols2_hb_font) |hb| {
                    if (hasGlyph(face, codepoint)) return .{ .face = face, .hb = hb };
                }
            }
            if (self.unicode_symbols_ft_face) |face| {
                if (self.unicode_symbols_hb_font) |hb| {
                    if (hasGlyph(face, codepoint)) return .{ .face = face, .hb = hb };
                }
            }
            if (self.unicode_mono_ft_face) |face| {
                if (self.unicode_mono_hb_font) |hb| {
                    if (hasGlyph(face, codepoint)) return .{ .face = face, .hb = hb };
                }
            }
            if (self.unicode_sans_ft_face) |face| {
                if (self.unicode_sans_hb_font) |hb| {
                    if (hasGlyph(face, codepoint)) return .{ .face = face, .hb = hb };
                }
            }
        }
        if (preferEmoji(codepoint)) {
            if (self.emoji_color_ft_face) |face| {
                if (self.emoji_color_hb_font) |hb| {
                    if (hasGlyph(face, codepoint)) return .{ .face = face, .hb = hb };
                }
            }
            if (self.emoji_text_ft_face) |face| {
                if (self.emoji_text_hb_font) |hb| {
                    if (hasGlyph(face, codepoint)) return .{ .face = face, .hb = hb };
                }
            }
        }
        return .{ .face = null, .hb = null };
    }

    fn pickFallback(self: *TerminalFont, codepoint: u32) struct { face: ?c.FT_Face, hb: ?*c.hb_font_t } {
        if (self.symbols_ft_face) |face| {
            if (self.symbols_hb_font) |hb| {
                if (hasGlyph(face, codepoint)) return .{ .face = face, .hb = hb };
            }
        }
        if (self.unicode_symbols2_ft_face) |face| {
            if (self.unicode_symbols2_hb_font) |hb| {
                if (hasGlyph(face, codepoint)) return .{ .face = face, .hb = hb };
            }
        }
        if (self.unicode_symbols_ft_face) |face| {
            if (self.unicode_symbols_hb_font) |hb| {
                if (hasGlyph(face, codepoint)) return .{ .face = face, .hb = hb };
            }
        }
        if (self.unicode_mono_ft_face) |face| {
            if (self.unicode_mono_hb_font) |hb| {
                if (hasGlyph(face, codepoint)) return .{ .face = face, .hb = hb };
            }
        }
        if (self.unicode_sans_ft_face) |face| {
            if (self.unicode_sans_hb_font) |hb| {
                if (hasGlyph(face, codepoint)) return .{ .face = face, .hb = hb };
            }
        }
        if (self.emoji_color_ft_face) |face| {
            if (self.emoji_color_hb_font) |hb| {
                if (hasGlyph(face, codepoint)) return .{ .face = face, .hb = hb };
            }
        }
        if (self.emoji_text_ft_face) |face| {
            if (self.emoji_text_hb_font) |hb| {
                if (hasGlyph(face, codepoint)) return .{ .face = face, .hb = hb };
            }
        }

        return .{ .face = null, .hb = null };
    }

    fn systemFallback(self: *TerminalFont, codepoint: u32) ?FacePair {
        return font_system_fallback.systemFallback(self, codepoint);
    }

    fn rasterizeGlyphKey(self: *TerminalFont, key: GlyphKey, hb_x_advance: c_int, allow_compact: bool) GlyphError!void {
        try font_atlas.rasterizeGlyphKey(self, key, hb_x_advance, allow_compact);
    }

    fn compactAtlas(self: *TerminalFont) GlyphError!void {
        try font_atlas.compactAtlas(self);
    }
};
