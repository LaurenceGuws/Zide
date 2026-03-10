const std = @import("std");
const app_logger = @import("../app_logger.zig");
const builtin = @import("builtin");
const gl = @import("renderer/gl.zig");
const types = @import("renderer/types.zig");
const terminal_glyphs = @import("renderer/terminal_glyphs.zig");
const font_atlas = @import("font/atlas.zig");

var windows_com_initialized = std.atomic.Value(bool).init(false);

const windows_dwrite = if (builtin.target.os.tag == .windows) struct {
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

fn applyHbLoadFlags(hb_font: *c.hb_font_t, ft_load_flags: c_int) void {
    // HarfBuzz should use the same load flags as rasterization for consistent
    // advances and layout.
    if (@hasDecl(c, "hb_ft_font_set_load_flags")) {
        c.hb_ft_font_set_load_flags(hb_font, ft_load_flags);
    }
}

const fc = if (builtin.target.os.tag == .linux) @cImport({
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

const FacePair = struct {
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
        const preferred = self.pickPreferred(codepoint);
        if (preferred.face) |p_face| {
            if (preferred.hb) |p_hb| {
                face = p_face;
                hb_font = p_hb;
            }
        } else if (!hasGlyph(face, codepoint)) {
            const fallback = self.pickFallback(codepoint);
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

    pub fn setAtlasFilterPoint(self: *TerminalFont) void {
        font_atlas.setAtlasFilterPoint(self);
    }

    fn snapToDevicePixel(value: f32, render_scale: f32) f32 {
        const scale = if (render_scale > 0.0) render_scale else 1.0;
        return @as(f32, @floatFromInt(@as(i32, @intFromFloat(std.math.round(value * scale))))) / scale;
    }

    fn rasterizePowerlineOutlineMask(
        self: *TerminalFont,
        codepoint: u32,
        width: i32,
        height: i32,
        out_alpha: []u8,
    ) bool {
        if (!isPowerlineCodepoint(codepoint) or width <= 0 or height <= 0) return false;
        const needed: usize = @intCast(width * height);
        if (out_alpha.len < needed) return false;
        @memset(out_alpha[0..needed], 0);

        const face = self.pickFontForCodepoint(codepoint).face;
        const glyph_id = c.FT_Get_Char_Index(face, codepoint);
        if (glyph_id == 0) return false;

        // Experimental A/B path: render at higher internal resolution, then
        // downsample into target sprite size for smoother diagonal coverage.
        const prev_x_ppem: c_uint = face.*.size.*.metrics.x_ppem;
        const prev_y_ppem: c_uint = face.*.size.*.metrics.y_ppem;
        const internal_h: i32 = @max(1, height * 2);
        if (c.FT_Set_Pixel_Sizes(face, 0, @intCast(internal_h)) != 0) return false;
        defer _ = c.FT_Set_Pixel_Sizes(face, prev_x_ppem, prev_y_ppem);

        var load_flags: c_int = self.ftLoadFlags(false);
        load_flags |= c.FT_LOAD_NO_HINTING;
        if (c.FT_Load_Glyph(face, glyph_id, load_flags) != 0) return false;
        if (c.FT_Render_Glyph(face.*.glyph, c.FT_RENDER_MODE_NORMAL) != 0) return false;

        const slot = face.*.glyph;
        const bitmap = slot.*.bitmap;
        const bmp_w: i32 = @intCast(bitmap.width);
        const bmp_h: i32 = @intCast(bitmap.rows);
        if (bmp_w <= 0 or bmp_h <= 0) return false;

        const pitch_i: i32 = @intCast(bitmap.pitch);
        const pitch_abs: i32 = if (pitch_i < 0) -pitch_i else pitch_i;
        const alphaAt = struct {
            fn call(bitmap_ptr: c.FT_Bitmap, pitch_signed: i32, pitch: i32, x: i32, y: i32) u8 {
                const rows_i: i32 = @intCast(bitmap_ptr.rows);
                const row = if (pitch_signed >= 0) y else (rows_i - 1 - y);
                const idx: usize = @intCast(row * pitch + x);
                return bitmap_ptr.buffer[idx];
            }
        }.call;

        // Build tight alpha bbox from the rendered outline.
        var min_x = bmp_w;
        var min_y = bmp_h;
        var max_x: i32 = -1;
        var max_y: i32 = -1;
        var sy: i32 = 0;
        while (sy < bmp_h) : (sy += 1) {
            var sx: i32 = 0;
            while (sx < bmp_w) : (sx += 1) {
                if (alphaAt(bitmap, pitch_i, pitch_abs, sx, sy) == 0) continue;
                if (sx < min_x) min_x = sx;
                if (sy < min_y) min_y = sy;
                if (sx > max_x) max_x = sx;
                if (sy > max_y) max_y = sy;
            }
        }
        if (max_x < min_x or max_y < min_y) return false;

        const src_w_i = max_x - min_x + 1;
        const src_h_i = max_y - min_y + 1;
        const src_w_f: f32 = @floatFromInt(src_w_i);
        const src_h_f: f32 = @floatFromInt(src_h_i);
        const dst_w_f: f32 = @floatFromInt(width);
        const dst_h_f: f32 = @floatFromInt(height);
        const bilinearSample = struct {
            fn call(
                bitmap_ptr: c.FT_Bitmap,
                pitch_signed: i32,
                pitch: i32,
                min_x_src: i32,
                min_y_src: i32,
                src_w: i32,
                src_h: i32,
                fx_in: f32,
                fy_in: f32,
            ) f32 {
                const fx = std.math.clamp(fx_in, 0.0, @as(f32, @floatFromInt(src_w - 1)));
                const fy = std.math.clamp(fy_in, 0.0, @as(f32, @floatFromInt(src_h - 1)));
                const x0 = @as(i32, @intFromFloat(@floor(fx)));
                const y0 = @as(i32, @intFromFloat(@floor(fy)));
                const x1 = @min(src_w - 1, x0 + 1);
                const y1 = @min(src_h - 1, y0 + 1);
                const tx = fx - @as(f32, @floatFromInt(x0));
                const ty = fy - @as(f32, @floatFromInt(y0));

                const ax0y0 = @as(f32, @floatFromInt(alphaAt(bitmap_ptr, pitch_signed, pitch, min_x_src + x0, min_y_src + y0)));
                const ax1y0 = @as(f32, @floatFromInt(alphaAt(bitmap_ptr, pitch_signed, pitch, min_x_src + x1, min_y_src + y0)));
                const ax0y1 = @as(f32, @floatFromInt(alphaAt(bitmap_ptr, pitch_signed, pitch, min_x_src + x0, min_y_src + y1)));
                const ax1y1 = @as(f32, @floatFromInt(alphaAt(bitmap_ptr, pitch_signed, pitch, min_x_src + x1, min_y_src + y1)));

                const top = ax0y0 + (ax1y0 - ax0y0) * tx;
                const bot = ax0y1 + (ax1y1 - ax0y1) * tx;
                return top + (bot - top) * ty;
            }
        }.call;

        // Normalize the rendered glyph into the full target sprite box.
        // This removes face-bearing/baseline variance from the special sprite path.
        var dy: i32 = 0;
        while (dy < height) : (dy += 1) {
            var dx: i32 = 0;
            while (dx < width) : (dx += 1) {
                // 2x2 area sampling reduces step-like diagonal jitter vs single-point bilinear.
                const su0 = ((@as(f32, @floatFromInt(dx)) + 0.25) * src_w_f / dst_w_f) - 0.5;
                const su1 = ((@as(f32, @floatFromInt(dx)) + 0.75) * src_w_f / dst_w_f) - 0.5;
                const sv0 = ((@as(f32, @floatFromInt(dy)) + 0.25) * src_h_f / dst_h_f) - 0.5;
                const sv1 = ((@as(f32, @floatFromInt(dy)) + 0.75) * src_h_f / dst_h_f) - 0.5;
                const a00 = bilinearSample(bitmap, pitch_i, pitch_abs, min_x, min_y, src_w_i, src_h_i, su0, sv0);
                const a10 = bilinearSample(bitmap, pitch_i, pitch_abs, min_x, min_y, src_w_i, src_h_i, su1, sv0);
                const a01 = bilinearSample(bitmap, pitch_i, pitch_abs, min_x, min_y, src_w_i, src_h_i, su0, sv1);
                const a11 = bilinearSample(bitmap, pitch_i, pitch_abs, min_x, min_y, src_w_i, src_h_i, su1, sv1);
                const a_f = (a00 + a10 + a01 + a11) * 0.25;
                const a: u8 = @intFromFloat(std.math.round(std.math.clamp(a_f, 0.0, 255.0)));
                out_alpha[@intCast(dy * width + dx)] = a;
            }
        }

        // Lock the flat edge fully opaque to avoid background seam bleed.
        if (codepoint == 0xE0B0) {
            var py: i32 = 0;
            while (py < height) : (py += 1) {
                out_alpha[@intCast(py * width)] = 255;
            }
        } else if (codepoint == 0xE0B2) {
            const edge_x = width - 1;
            var py: i32 = 0;
            while (py < height) : (py += 1) {
                out_alpha[@intCast(py * width + edge_x)] = 255;
            }
        }

        var non_zero = false;
        for (out_alpha[0..needed]) |a| {
            if (a != 0) {
                non_zero = true;
                break;
            }
        }
        return non_zero;
    }

    pub fn specialGlyphSpriteKey(
        self: *const TerminalFont,
        codepoint: u32,
        raster_w_px: i32,
        raster_h_px: i32,
        variant: SpecialGlyphVariant,
    ) SpecialGlyphSpriteKey {
        const rs = if (self.render_scale > 0.0) self.render_scale else 1.0;
        const rs_milli_f = std.math.round(rs * 1000.0);
        const rs_milli_i: i32 = @intFromFloat(rs_milli_f);
        const rs_milli_u16: u16 = @intCast(@max(0, @min(@as(i32, std.math.maxInt(u16)), rs_milli_i)));
        const cw_u16: u16 = @intCast(@max(0, @min(@as(i32, std.math.maxInt(u16)), raster_w_px)));
        const ch_u16: u16 = @intCast(@max(0, @min(@as(i32, std.math.maxInt(u16)), raster_h_px)));
        return .{
            .codepoint = codepoint,
            .cell_w_px = cw_u16,
            .cell_h_px = ch_u16,
            .render_scale_milli = rs_milli_u16,
            .variant = variant,
        };
    }

    pub fn getSpecialGlyphSprite(
        self: *TerminalFont,
        key: SpecialGlyphSpriteKey,
    ) ?*SpecialGlyphSprite {
        return self.special_glyph_sprites.getPtr(key);
    }

    pub fn putSpecialGlyphSprite(
        self: *TerminalFont,
        key: SpecialGlyphSpriteKey,
        sprite: SpecialGlyphSprite,
    ) !void {
        try self.special_glyph_sprites.put(key, sprite);
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
        const special_log = app_logger.logger("terminal.glyph.special");
        if (cell_w_px <= 0 or cell_h_px <= 0 or raster_w_px <= 0 or raster_h_px <= 0) return null;
        const key = self.specialGlyphSpriteKey(codepoint, raster_w_px, raster_h_px, variant);
        if (self.special_glyph_sprites.getPtr(key)) |existing| return existing;

        const rs = if (self.render_scale > 0.0) self.render_scale else 1.0;
        const width = raster_w_px;
        const height = raster_h_px;
        const needed: usize = @intCast(width * height);
        if (needed == 0) return null;
        if (needed > self.upload_buffer_capacity) {
            if (self.upload_buffer_capacity > 0) {
                self.allocator.free(self.upload_buffer);
            }
            self.upload_buffer = self.allocator.alloc(u8, needed) catch |err| {
                                    special_log.logf(.warning, "special glyph upload buffer alloc failed bytes={d} err={s}", .{ needed, @errorName(err) });
                return null;
            };
            self.upload_buffer_capacity = needed;
        }
        const mask = self.upload_buffer[0..needed];
        const outline_experiment_enabled = true;
        var path_name: []const u8 = "analytic_v1";
        var rasterized = false;
        if (outline_experiment_enabled and variant == .powerline and isThickPowerlineCodepoint(codepoint)) {
            rasterized = self.rasterizePowerlineOutlineMask(codepoint, width, height, mask);
            if (rasterized) path_name = "outline_ft_v4";
        }
        if (!rasterized) {
            rasterized = terminal_glyphs.rasterizeSpecialGlyphCoverage(codepoint, width, height, mask);
            if (rasterized) path_name = "analytic_v1";
        }
        if (!rasterized) {
            if (variant == .powerline or isPowerlineCodepoint(codepoint)) {
                special_log.logf(.info, 
                    "sprite_create_fail cp=U+{X} reason=rasterize_failed cell={d}x{d} raster={d}x{d} rs={d:.3}",
                    .{ codepoint, cell_w_px, cell_h_px, width, height, rs },
                );
            }
            return null;
        }

        var non_zero = false;
        for (mask) |a| {
            if (a != 0) {
                non_zero = true;
                break;
            }
        }
        if (!non_zero) {
            if (variant == .powerline or isPowerlineCodepoint(codepoint)) {
                special_log.logf(.info, 
                    "sprite_create_fail cp=U+{X} reason=empty_mask cell={d}x{d} raster={d}x{d} rs={d:.3}",
                    .{ codepoint, cell_w_px, cell_h_px, width, height, rs },
                );
            }
            return null;
        }

        if (self.pen_x + width + self.padding > self.atlas_width) {
            self.pen_x = self.padding;
            self.pen_y += self.row_h + self.padding;
            self.row_h = 0;
        }
        if (self.pen_y + height + self.padding > self.atlas_height) {
            if (variant == .powerline or isPowerlineCodepoint(codepoint)) {
                special_log.logf(.info, 
                    "sprite_create_fail cp=U+{X} reason=atlas_full cell={d}x{d} raster={d}x{d} rs={d:.3}",
                    .{ codepoint, cell_w_px, cell_h_px, width, height, rs },
                );
            }
            return null;
        }

        const rec = Rect{
            .x = @floatFromInt(self.pen_x),
            .y = @floatFromInt(self.pen_y),
            .width = @floatFromInt(width),
            .height = @floatFromInt(height),
        };
        font_atlas.updateTextureRegionR8(self.coverage_texture, rec, mask);

        if (height > self.row_h) self.row_h = height;
        self.pen_x += width + self.padding;

        const sprite = SpecialGlyphSprite{
            .rect = rec,
            .bearing_x = 0,
            .bearing_y = height,
            .advance = @floatFromInt(cell_w_px),
            .width = width,
            .height = height,
        };
        self.special_glyph_sprites.put(key, sprite) catch |err| {
                            special_log.logf(.warning, "special glyph sprite cache insert failed cp=U+{X} err={s}", .{ codepoint, @errorName(err) });
            return null;
        };
        if (variant == .powerline or isPowerlineCodepoint(codepoint)) {
            special_log.logf(.info, 
                "sprite_create cp=U+{X} variant={s} path={s} cell={d}x{d} raster={d}x{d} rs={d:.3}",
                .{ codepoint, @tagName(variant), path_name, cell_w_px, cell_h_px, width, height, rs },
            );
        }
        return self.special_glyph_sprites.getPtr(key);
    }

    pub fn drawGlyph(self: *TerminalFont, draw: DrawContext, codepoint: u32, x: f32, y: f32, cell_width: f32, cell_height: f32, followed_by_space: bool, color: Rgba) void {
        if (codepoint == 0) return;
        const glyph = self.getGlyphForCodepoint(codepoint) catch |err| {
            app_logger.logger("terminal.glyph").logf(.debug, "drawGlyph getGlyphForCodepoint failed cp=U+{X} err={s}", .{ codepoint, @errorName(err) });
            return;
        };
        const render_scale = if (self.render_scale > 0.0) self.render_scale else 1.0;
        const inv_scale = 1.0 / render_scale;
        const baseline = y + self.baseline_from_top * inv_scale;

        const glyph_w = @as(f32, @floatFromInt(glyph.width)) * inv_scale;
        const glyph_h = @as(f32, @floatFromInt(glyph.height)) * inv_scale;

        // Check if codepoint is in Private Use Area (PUA) or symbol ranges.
        // These are typically icons that should be allowed to overflow.
        const is_symbol_glyph = (codepoint >= 0xE000 and codepoint <= 0xF8FF) or // BMP PUA (Nerd Font)
            (codepoint >= 0xF0000 and codepoint <= 0xFFFFD) or // Supplementary PUA-A
            (codepoint >= 0x100000 and codepoint <= 0x10FFFD) or // Supplementary PUA-B
            (codepoint >= 0x2700 and codepoint <= 0x27BF) or // Dingbats (❯, etc.)
            (codepoint >= 0x2600 and codepoint <= 0x26FF); // Misc Symbols

        const aspect = if (cell_height > 0) glyph_w / cell_height else 0.0;
        const is_square_or_wide = aspect >= 0.7;
        const allow_width_overflow = if (is_symbol_glyph) true else if (is_square_or_wide) switch (self.overflow_policy) {
            .never => false,
            .always => true,
            .when_followed_by_space => followed_by_space,
        } else false;

        // Only apply width-fit scaling for square/wide glyphs (icons, box-ish symbols).
        // Scaling normal text glyphs to fit the cell can cause visible baseline jitter at
        // certain fractional scales.
        const overflow_eps: f32 = 0.25;
        const should_fit = (!allow_width_overflow) and is_square_or_wide;
        const overflow_scale = if (should_fit and glyph_w > cell_width + overflow_eps and glyph_w > 0) cell_width / glyph_w else 1.0;
        const scaled_w = glyph_w * overflow_scale;
        const scaled_h = glyph_h * overflow_scale;

        const bearing = @as(f32, @floatFromInt(glyph.bearing_x)) * inv_scale;
        const bearing_y = @as(f32, @floatFromInt(glyph.bearing_y)) * inv_scale;

        // For symbol/icon glyphs: center in cell with left bias to prevent right clipping.
        const draw_color = if (glyph.is_color)
            Rgba{ .r = 255, .g = 255, .b = 255, .a = 255 }
        else
            color;

        if (is_symbol_glyph) {
            const draw_x = @max(x, x + bearing * overflow_scale);
            const draw_y = baseline - bearing_y * overflow_scale;
            const snapped_x = snapToDevicePixel(draw_x, render_scale);
            const snapped_y = snapToDevicePixel(draw_y, render_scale);
            const dest = Rect{ .x = snapped_x, .y = snapped_y, .width = scaled_w, .height = scaled_h };
            if (glyph.is_color) {
                draw.drawTexture(draw.ctx, self.color_texture, glyph.rect, dest, draw_color, .rgba);
            } else {
                draw.drawTexture(draw.ctx, self.coverage_texture, glyph.rect, dest, draw_color, .font_coverage);
            }
            return;
        }

        // Normal glyph: draw at bearing position, clamped to not go left of cell.
        const draw_x = if (allow_width_overflow) x + bearing * overflow_scale else @max(x, x + bearing * overflow_scale);
        const draw_y = baseline - bearing_y * overflow_scale;
        const snapped_x = snapToDevicePixel(draw_x, render_scale);
        const snapped_y = snapToDevicePixel(draw_y, render_scale);
        const dest = Rect{ .x = snapped_x, .y = snapped_y, .width = scaled_w, .height = scaled_h };
        if (glyph.is_color) {
            draw.drawTexture(draw.ctx, self.color_texture, glyph.rect, dest, draw_color, .rgba);
        } else {
            draw.drawTexture(draw.ctx, self.coverage_texture, glyph.rect, dest, draw_color, .font_coverage);
        }
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
        if (base == 0) return;
        if (combining.len == 0) {
            self.drawGlyph(draw, base, x, y, cell_width, cell_height, followed_by_space, color);
            return;
        }

        // Shape the grapheme cluster using the chosen face for the base glyph.
        var face = self.ft_face;
        var hb_font = self.hb_font;
        const preferred = self.pickPreferred(base);
        if (preferred.face) |p_face| {
            if (preferred.hb) |p_hb| {
                face = p_face;
                hb_font = p_hb;
            }
        } else if (!hasGlyph(face, base)) {
            const fallback = self.pickFallback(base);
            if (fallback.face) |fb_face| {
                if (fallback.hb) |fb_hb| {
                    face = fb_face;
                    hb_font = fb_hb;
                }
            }
        }

        var cps_buf: [3]u32 = .{ base, 0, 0 };
        var cps_len: usize = 1;
        for (combining) |cp| {
            if (cps_len >= cps_buf.len) break;
            cps_buf[cps_len] = cp;
            cps_len += 1;
        }

        const buffer = c.hb_buffer_create();
        defer c.hb_buffer_destroy(buffer);
        c.hb_buffer_add_utf32(buffer, &cps_buf, @intCast(cps_len), 0, @intCast(cps_len));
        c.hb_buffer_guess_segment_properties(buffer);
        c.hb_shape(hb_font, buffer, null, 0);

        var length: c_uint = 0;
        const infos = c.hb_buffer_get_glyph_infos(buffer, &length);
        const positions = c.hb_buffer_get_glyph_positions(buffer, &length);
        if (length == 0) return;

        const render_scale = if (self.render_scale > 0.0) self.render_scale else 1.0;
        const inv_scale = 1.0 / render_scale;
        const baseline = y + self.baseline_from_top * inv_scale;

        const is_color_face = c.FT_HAS_COLOR(face) or (self.emoji_color_ft_face != null and face == self.emoji_color_ft_face.?);
        const want_color = is_color_face;

        // Use the base codepoint for symbol overflow policy.
        const is_symbol_glyph = (base >= 0xE000 and base <= 0xF8FF) or
            (base >= 0xF0000 and base <= 0xFFFFD) or
            (base >= 0x100000 and base <= 0x10FFFD) or
            (base >= 0x2700 and base <= 0x27BF) or
            (base >= 0x2600 and base <= 0x26FF);

        var pen_x: f32 = 0;
        var i: usize = 0;
        while (i < length) : (i += 1) {
            const gid: u32 = infos[i].codepoint;
            const key = GlyphKey{ .face = face, .glyph_id = gid, .want_color = want_color };
            const glyph = self.getGlyphByKey(key, positions[i].x_advance) catch continue;

            const gx_off = (@as(f32, @floatFromInt(positions[i].x_offset)) / 64.0) * inv_scale;
            const gy_off = (@as(f32, @floatFromInt(positions[i].y_offset)) / 64.0) * inv_scale;
            const origin_x = x + pen_x + gx_off;

            const glyph_w = @as(f32, @floatFromInt(glyph.width)) * inv_scale;
            const glyph_h = @as(f32, @floatFromInt(glyph.height)) * inv_scale;
            const bearing_x = @as(f32, @floatFromInt(glyph.bearing_x)) * inv_scale;
            const bearing_y = @as(f32, @floatFromInt(glyph.bearing_y)) * inv_scale;

            const aspect = if (cell_height > 0) glyph_w / cell_height else 0.0;
            const is_square_or_wide = aspect >= 0.7;
            const allow_width_overflow = if (is_symbol_glyph) true else if (is_square_or_wide) switch (self.overflow_policy) {
                .never => false,
                .always => true,
                .when_followed_by_space => followed_by_space,
            } else false;
            const overflow_eps: f32 = 0.25;
            const should_fit = (!allow_width_overflow) and is_square_or_wide;
            const overflow_scale = if (should_fit and glyph_w > cell_width + overflow_eps and glyph_w > 0) cell_width / glyph_w else 1.0;
            const scaled_w = glyph_w * overflow_scale;
            const scaled_h = glyph_h * overflow_scale;

            const draw_x = if (allow_width_overflow) origin_x + bearing_x * overflow_scale else @max(x, origin_x + bearing_x * overflow_scale);
            const draw_y = (baseline - bearing_y * overflow_scale) - gy_off;

            const snapped_x = snapToDevicePixel(draw_x, render_scale);
            const snapped_y = snapToDevicePixel(draw_y, render_scale);
            const dest = Rect{ .x = snapped_x, .y = snapped_y, .width = scaled_w, .height = scaled_h };

            const draw_color = if (glyph.is_color)
                Rgba{ .r = 255, .g = 255, .b = 255, .a = 255 }
            else
                color;

            if (glyph.is_color) {
                draw.drawTexture(draw.ctx, self.color_texture, glyph.rect, dest, draw_color, .rgba);
            } else {
                draw.drawTexture(draw.ctx, self.coverage_texture, glyph.rect, dest, draw_color, .font_coverage);
            }

            pen_x += (@as(f32, @floatFromInt(positions[i].x_advance)) / 64.0) * inv_scale;
        }
    }

    pub fn glyphAdvance(self: *TerminalFont, codepoint: u32) GlyphError!f32 {
        const glyph = try self.getGlyphForCodepoint(codepoint);
        const render_scale = if (self.render_scale > 0.0) self.render_scale else 1.0;
        return glyph.advance / render_scale;
    }

    fn getGlyphForCodepoint(self: *TerminalFont, codepoint: u32) GlyphError!*Glyph {
        if (codepoint == 0) return error.FtLoadFailed;

        var face = self.ft_face;
        var hb_font = self.hb_font;
        const preferred = self.pickPreferred(codepoint);
        if (preferred.face) |p_face| {
            if (preferred.hb) |p_hb| {
                face = p_face;
                hb_font = p_hb;
            }
        } else if (!hasGlyph(face, codepoint)) {
            const fallback = self.pickFallback(codepoint);
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

        const buffer = c.hb_buffer_create();
        defer c.hb_buffer_destroy(buffer);
        c.hb_buffer_add_utf32(buffer, &codepoint, 1, 0, 1);
        c.hb_buffer_guess_segment_properties(buffer);
        c.hb_shape(hb_font, buffer, null, 0);

        var length: c_uint = 0;
        const infos = c.hb_buffer_get_glyph_infos(buffer, &length);
        const positions = c.hb_buffer_get_glyph_positions(buffer, &length);
        if (length == 0) return error.HbShapeFailed;

        const glyph_id: u32 = infos[0].codepoint;
        const is_color_face = c.FT_HAS_COLOR(face) or (self.emoji_color_ft_face != null and face == self.emoji_color_ft_face.?);
        const want_color = is_color_face;
        const key = GlyphKey{ .face = face, .glyph_id = glyph_id, .want_color = want_color };
        return self.getGlyphByKey(key, positions[0].x_advance);
    }

    fn hasGlyph(face: c.FT_Face, codepoint: u32) bool {
        return c.FT_Get_Char_Index(face, codepoint) != 0;
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
        const os_tag = builtin.target.os.tag;
        if (os_tag != .linux and os_tag != .windows) return null;
        const log = app_logger.logger("terminal.font");

        if (self.system_fallback_by_cp.get(codepoint)) |cached| {
            if (cached) |path| {
                if (self.system_faces.get(path)) |pair| return pair;
                self.system_fallback_by_cp.put(codepoint, null) catch |err| {
                                            log.logf(.warning, "system fallback cache miss reset failed cp={d} err={s}", .{ codepoint, @errorName(err) });
                };
            }
            return null;
        }

        if (os_tag == .windows) {
            const pair = self.windowsSystemFallback(codepoint);
            if (pair == null) {
                self.system_fallback_by_cp.put(codepoint, null) catch |err| {
                                            log.logf(.warning, "windows fallback cache negative store failed cp={d} err={s}", .{ codepoint, @errorName(err) });
                };
            }
            return pair;
        }

        if (!self.fc_enabled or self.fc_config == null) return null;

        var result: ?FacePair = null;
        const pattern = fc.FcPatternCreate() orelse return null;
        defer fc.FcPatternDestroy(pattern);

        const charset = fc.FcCharSetCreate() orelse return null;
        defer fc.FcCharSetDestroy(charset);
        _ = fc.FcCharSetAddChar(charset, codepoint);
        _ = fc.FcPatternAddCharSet(pattern, fc.FC_CHARSET, charset);
        _ = fc.FcPatternAddBool(pattern, fc.FC_SCALABLE, 1);

        if (self.fc_config) |cfg| {
            _ = fc.FcConfigSubstitute(cfg, pattern, fc.FcMatchPattern);
        }
        fc.FcDefaultSubstitute(pattern);

        var res: fc.FcResult = fc.FcResultMatch;
        const match = fc.FcFontMatch(self.fc_config, pattern, &res);
        if (match == null) {
            self.system_fallback_by_cp.put(codepoint, null) catch |err| {
                                    log.logf(.warning, "fontconfig match miss cache store failed cp={d} err={s}", .{ codepoint, @errorName(err) });
            };
            return null;
        }
        defer fc.FcPatternDestroy(match);

        var file_ptr: [*c]fc.FcChar8 = null;
        if (fc.FcPatternGetString(match, fc.FC_FILE, 0, &file_ptr) != fc.FcResultMatch) {
            self.system_fallback_by_cp.put(codepoint, null) catch |err| {
                                    log.logf(.warning, "fontconfig path lookup miss cache store failed cp={d} err={s}", .{ codepoint, @errorName(err) });
            };
            return null;
        }

        const path = std.mem.sliceTo(@as([*:0]const u8, @ptrCast(file_ptr)), 0);
        if (self.system_faces.getEntry(path)) |entry| {
            _ = self.system_fallback_by_cp.put(codepoint, @constCast(entry.key_ptr.*)) catch |err| {
                                    log.logf(.warning, "fallback cp cache put failed cp={d} path={s} err={s}", .{ codepoint, entry.key_ptr.*, @errorName(err) });
                return null;
            };
            return entry.value_ptr.*;
        }

        const owned = self.allocator.dupe(u8, path) catch |err| {
                            log.logf(.warning, "fallback path dup failed cp={d} path={s} err={s}", .{ codepoint, path, @errorName(err) });
            return null;
        };
        var keep_owned = false;
        defer if (!keep_owned) self.allocator.free(owned);

        var fb_pair: FacePair = .{};
        if (!ftNewFaceFromFile(self, owned, &fb_pair)) {
            self.system_fallback_by_cp.put(codepoint, null) catch |err| {
                                    log.logf(.warning, "fallback face load failed cache store failed cp={d} err={s}", .{ codepoint, @errorName(err) });
            };
            return null;
        }
        const fb_face = fb_pair.face.?;
        errdefer {
            if (fb_pair.hb) |hb| c.hb_font_destroy(hb);
            if (fb_pair.face) |face| _ = c.FT_Done_Face(face);
            if (fb_pair.owned_data) |data| self.allocator.free(data);
        }
        if (c.FT_Set_Pixel_Sizes(fb_face, 0, @intFromFloat(self.line_height)) != 0) {
            _ = c.FT_Done_Face(fb_face);
            self.system_fallback_by_cp.put(codepoint, null) catch |err| {
                                    log.logf(.warning, "fallback pixel size failed cache store failed cp={d} err={s}", .{ codepoint, @errorName(err) });
            };
            return null;
        }
        const fb_hb = c.hb_ft_font_create(fb_face, null) orelse {
            _ = c.FT_Done_Face(fb_face);
            self.system_fallback_by_cp.put(codepoint, null) catch |err| {
                                    log.logf(.warning, "fallback hb font create failed cache store failed cp={d} err={s}", .{ codepoint, @errorName(err) });
            };
            return null;
        };
        applyHbLoadFlags(fb_hb, self.ft_load_flags_base);

        fb_pair.hb = fb_hb;
        self.system_faces.put(self.allocator, owned, fb_pair) catch {
            c.hb_font_destroy(fb_hb);
            _ = c.FT_Done_Face(fb_face);
            if (fb_pair.owned_data) |data| self.allocator.free(data);
            self.system_fallback_by_cp.put(codepoint, null) catch |put_err| {
                                    log.logf(.warning, "fallback map insert failed and cache-null store failed cp={d} err={s}", .{ codepoint, @errorName(put_err) });
            };
            return null;
        };
        keep_owned = true;
        self.system_fallback_by_cp.put(codepoint, owned) catch |err| {
                            log.logf(.warning, "fallback cache store failed cp={d} path={s} err={s}", .{ codepoint, owned, @errorName(err) });
        };
        result = fb_pair;
        return result;
    }

    fn ftNewFace(self: *TerminalFont, path: []const u8, out_face: *c.FT_Face) bool {
        const log = app_logger.logger("terminal.font");
        // FreeType expects a 0-terminated path. Avoid storing the terminator in
        // the hash-map key by allocating a temporary sentinel buffer here.
        var tmp = self.allocator.alloc(u8, path.len + 1) catch |err| {
                            log.logf(.warning, "ftNewFace temp path alloc failed len={d} err={s}", .{ path.len + 1, @errorName(err) });
            return false;
        };
        defer self.allocator.free(tmp);
        std.mem.copyForwards(u8, tmp[0..path.len], path);
        tmp[path.len] = 0;
        return c.FT_New_Face(self.ft_library, tmp.ptr, 0, out_face) == 0;
    }

    fn ftNewFaceFromFile(self: *TerminalFont, path: []const u8, out_pair: *FacePair) bool {
        var face: c.FT_Face = null;
        if (!ftNewFace(self, path, &face)) return false;
        out_pair.* = .{ .face = face, .hb = null, .owned_data = null };
        return true;
    }

    fn ftNewFaceFromMemoryFile(self: *TerminalFont, path: []const u8, out_pair: *FacePair) bool {
        const log = app_logger.logger("terminal.font");
        // Load a file into memory and create a FreeType face from it. This is a
        // fallback for paths that FreeType cannot open directly (encoding or
        // sandbox constraints). The buffer must remain alive.
        var file = std.fs.openFileAbsolute(path, .{}) catch |err| {
                            log.logf(.warning, "ft memory fallback open failed path={s} err={s}", .{ path, @errorName(err) });
            return false;
        };
        defer file.close();
        const bytes = file.readToEndAlloc(self.allocator, 32 * 1024 * 1024) catch |err| {
                            log.logf(.warning, "ft memory fallback read failed path={s} err={s}", .{ path, @errorName(err) });
            return false;
        };
        errdefer self.allocator.free(bytes);
        var face: c.FT_Face = null;
        if (c.FT_New_Memory_Face(self.ft_library, bytes.ptr, @intCast(bytes.len), 0, &face) != 0) {
            self.allocator.free(bytes);
            return false;
        }
        out_pair.* = .{ .face = face, .hb = null, .owned_data = bytes };
        return true;
    }

    fn windowsFontDir(allocator: std.mem.Allocator) ?[]u8 {
        const log = app_logger.logger("terminal.font");
        const windir = std.c.getenv("WINDIR") orelse return null;
        const base = std.mem.sliceTo(windir, 0);
        return std.fs.path.join(allocator, &.{ base, "Fonts" }) catch |err| {
                            log.logf(.warning, "windows font dir join failed base={s} err={s}", .{ base, @errorName(err) });
            return null;
        };
    }

    fn windowsSystemFallback(self: *TerminalFont, codepoint: u32) ?FacePair {
        const log = app_logger.logger("terminal.font");
        const font_dir = windowsFontDir(self.allocator) orelse return null;
        defer self.allocator.free(font_dir);

        // Prefer a small set of well-known Windows fonts first. This is a
        // pragmatic fallback (DirectWrite-based matching is still TODO).
        const candidates = [_][]const u8{
            "seguiemj.ttf", // Segoe UI Emoji
            "seguisym.ttf", // Segoe UI Symbol
            "segoeui.ttf", // Segoe UI
            "consola.ttf", // Consolas
            "arial.ttf", // Arial
            "times.ttf", // Times New Roman (some installs)
        };

        for (candidates) |file| {
            const path = std.fs.path.join(self.allocator, &.{ font_dir, file }) catch continue;
            defer self.allocator.free(path);

            // If we've already loaded this face, reuse it.
            if (self.system_faces.getEntry(path)) |entry| {
                self.system_fallback_by_cp.put(codepoint, @constCast(entry.key_ptr.*)) catch |err| {
                                            log.logf(.warning, "windows fallback cache store failed cp={d} path={s} err={s}", .{ codepoint, entry.key_ptr.*, @errorName(err) });
                };
                return entry.value_ptr.*;
            }

            const owned = self.allocator.dupe(u8, path) catch continue;
            errdefer self.allocator.free(owned);

            var fb_pair: FacePair = .{};
            if (!ftNewFaceFromFile(self, owned, &fb_pair) and !ftNewFaceFromMemoryFile(self, owned, &fb_pair)) {
                continue;
            }
            const fb_face = fb_pair.face.?;
            errdefer {
                if (fb_pair.hb) |hb| c.hb_font_destroy(hb);
                if (fb_pair.face) |face| _ = c.FT_Done_Face(face);
                if (fb_pair.owned_data) |data| self.allocator.free(data);
            }

            if (c.FT_Get_Char_Index(fb_face, codepoint) == 0) {
                // Not a match; cleanup via errdefer.
                continue;
            }

            if (c.FT_Set_Pixel_Sizes(fb_face, 0, @intFromFloat(self.line_height)) != 0) {
                _ = c.FT_Done_Face(fb_face);
                continue;
            }

            const fb_hb = c.hb_ft_font_create(fb_face, null) orelse {
                continue;
            };
            applyHbLoadFlags(fb_hb, self.ft_load_flags_base);

            fb_pair.hb = fb_hb;
            self.system_faces.put(self.allocator, owned, fb_pair) catch {
                c.hb_font_destroy(fb_hb);
                _ = c.FT_Done_Face(fb_face);
                if (fb_pair.owned_data) |data| self.allocator.free(data);
                self.allocator.free(owned);
                return null;
            };
            self.system_fallback_by_cp.put(codepoint, owned) catch |err| {
                                    log.logf(.warning, "windows fallback cache store failed cp={d} path={s} err={s}", .{ codepoint, owned, @errorName(err) });
            };
            return fb_pair;
        }

        if (self.windowsDirectWriteResolveFontPath(codepoint)) |path_utf8| {
            // If we've already loaded this face, reuse it.
            if (self.system_faces.getEntry(path_utf8)) |entry| {
                self.allocator.free(path_utf8);
                self.system_fallback_by_cp.put(codepoint, @constCast(entry.key_ptr.*)) catch |err| {
                                            log.logf(.warning, "windows dwrite cache store failed cp={d} path={s} err={s}", .{ codepoint, entry.key_ptr.*, @errorName(err) });
                };
                return entry.value_ptr.*;
            }

            // Take ownership of the returned path for cache keys.
            const owned = path_utf8;
            errdefer self.allocator.free(owned);

            var fb_pair: FacePair = .{};
            if (!ftNewFaceFromFile(self, owned, &fb_pair) and !ftNewFaceFromMemoryFile(self, owned, &fb_pair)) {
                return null;
            }
            const fb_face = fb_pair.face.?;
            errdefer {
                if (fb_pair.hb) |hb| c.hb_font_destroy(hb);
                if (fb_pair.face) |face| _ = c.FT_Done_Face(face);
                if (fb_pair.owned_data) |data| self.allocator.free(data);
            }

            if (c.FT_Set_Pixel_Sizes(fb_face, 0, @intFromFloat(self.line_height)) != 0) {
                return null;
            }

            const fb_hb = c.hb_ft_font_create(fb_face, null) orelse {
                return null;
            };
            fb_pair.hb = fb_hb;
            self.system_faces.put(self.allocator, owned, fb_pair) catch {
                c.hb_font_destroy(fb_hb);
                _ = c.FT_Done_Face(fb_face);
                if (fb_pair.owned_data) |data| self.allocator.free(data);
                return null;
            };
            self.system_fallback_by_cp.put(codepoint, owned) catch |err| {
                                    log.logf(.warning, "windows dwrite fallback cache store failed cp={d} path={s} err={s}", .{ codepoint, owned, @errorName(err) });
            };
            return fb_pair;
        }

        return null;
    }

    fn ensureWindowsComInit() bool {
        if (windows_com_initialized.load(.acquire)) return true;
        const hr = windows_dwrite.CoInitializeEx(null, windows_dwrite.COINIT_MULTITHREADED);
        if (hr >= 0 or hr == windows_dwrite.RPC_E_CHANGED_MODE) {
            windows_com_initialized.store(true, .release);
            return true;
        }
        return false;
    }

    fn windowsDirectWriteResolveFontPath(self: *TerminalFont, codepoint: u32) ?[]u8 {
        if (builtin.target.os.tag != .windows) return null;
        if (!ensureWindowsComInit()) return null;

        var factory_any: ?*anyopaque = null;
        if (windows_dwrite.DWriteCreateFactory(
            windows_dwrite.DWRITE_FACTORY_TYPE_SHARED,
            &windows_dwrite.IID_IDWriteFactory,
            &factory_any,
        ) < 0) return null;
        const factory: *windows_dwrite.IDWriteFactory = @ptrCast(@alignCast(factory_any.?));
        defer _ = factory.vtbl.Release(factory);

        var collection: ?*windows_dwrite.IDWriteFontCollection = null;
        if (factory.vtbl.GetSystemFontCollection(factory, &collection, 0) < 0) return null;
        defer _ = collection.?.vtbl.Release(collection.?);

        const family_count = collection.?.vtbl.GetFontFamilyCount(collection.?);
        const max_families: windows_dwrite.UINT32 = @min(family_count, 900);

        var family_idx: windows_dwrite.UINT32 = 0;
        while (family_idx < max_families) : (family_idx += 1) {
            var family: ?*windows_dwrite.IDWriteFontFamily = null;
            if (collection.?.vtbl.GetFontFamily(collection.?, family_idx, &family) < 0) continue;
            defer _ = family.?.vtbl.Release(family.?);

            var font_count: windows_dwrite.UINT32 = 0;
            if (family.?.vtbl.GetFontCount(family.?, &font_count) < 0) continue;
            const max_fonts: windows_dwrite.UINT32 = @min(font_count, 4);

            var font_idx: windows_dwrite.UINT32 = 0;
            while (font_idx < max_fonts) : (font_idx += 1) {
                var font: ?*windows_dwrite.IDWriteFont = null;
                if (family.?.vtbl.GetFont(family.?, font_idx, &font) < 0) continue;
                defer _ = font.?.vtbl.Release(font.?);

                var face: ?*windows_dwrite.IDWriteFontFace = null;
                if (font.?.vtbl.CreateFontFace(font.?, &face) < 0) continue;
                defer _ = face.?.vtbl.Release(face.?);

                var cp: windows_dwrite.UINT32 = codepoint;
                var glyph: windows_dwrite.UINT16 = 0;
                if (face.?.vtbl.GetGlyphIndices(face.?, &cp, 1, &glyph) < 0) continue;
                if (glyph == 0) continue;

                // Resolve the local font file path.
                var file_count: windows_dwrite.UINT32 = 0;
                if (face.?.vtbl.GetFiles(face.?, &file_count, null) < 0) continue;
                if (file_count == 0) continue;

                const files = self.allocator.alloc(?*windows_dwrite.IDWriteFontFile, file_count) catch continue;
                defer self.allocator.free(files);
                @memset(files, null);
                if (face.?.vtbl.GetFiles(face.?, &file_count, files.ptr) < 0) continue;

                const file0 = files[0] orelse continue;
                defer {
                    for (files) |f_opt| {
                        if (f_opt) |f| _ = f.vtbl.Release(f);
                    }
                }

                var key_ptr: ?*const anyopaque = null;
                var key_size: windows_dwrite.UINT32 = 0;
                if (file0.vtbl.GetReferenceKey(file0, &key_ptr, &key_size) < 0) continue;
                if (key_ptr == null or key_size == 0) continue;

                var loader: ?*windows_dwrite.IDWriteFontFileLoader = null;
                if (file0.vtbl.GetLoader(file0, &loader) < 0 or loader == null) continue;
                const loader_unk: *windows_dwrite.IUnknown = @ptrCast(@alignCast(loader.?));
                defer _ = loader_unk.vtbl.Release(loader_unk);

                var local_any: ?*anyopaque = null;
                if (loader_unk.vtbl.QueryInterface(loader_unk, &windows_dwrite.IID_IDWriteLocalFontFileLoader, &local_any) < 0) continue;
                const local_loader: *windows_dwrite.IDWriteLocalFontFileLoader = @ptrCast(@alignCast(local_any.?));
                defer _ = local_loader.vtbl.Release(local_loader);

                var path_len: windows_dwrite.UINT32 = 0;
                if (local_loader.vtbl.GetFilePathLengthFromKey(local_loader, key_ptr.?, key_size, &path_len) < 0) continue;
                if (path_len == 0) continue;

                // +1 for null terminator.
                var wbuf = self.allocator.alloc(u16, @intCast(path_len + 1)) catch continue;
                defer self.allocator.free(wbuf);
                if (local_loader.vtbl.GetFilePathFromKey(local_loader, key_ptr.?, key_size, wbuf.ptr, path_len + 1) < 0) continue;
                wbuf[@intCast(path_len)] = 0;

                const path_utf8 = std.unicode.utf16LeToUtf8Alloc(self.allocator, wbuf[0..@intCast(path_len)]) catch continue;
                return path_utf8;
            }
        }

        return null;
    }

    fn rasterizeGlyphKey(self: *TerminalFont, key: GlyphKey, hb_x_advance: c_int, allow_compact: bool) GlyphError!void {
        try font_atlas.rasterizeGlyphKey(self, key, hb_x_advance, allow_compact);
    }

    fn compactAtlas(self: *TerminalFont) GlyphError!void {
        try font_atlas.compactAtlas(self);
    }
};
