const std = @import("std");
const app_logger = @import("../app_logger.zig");
const builtin = @import("builtin");
const gl = @import("renderer/gl.zig");
const types = @import("renderer/types.zig");

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
pub const Rgba = types.Rgba;

pub const DrawContext = struct {
    ctx: *anyopaque,
    drawTexture: *const fn (ctx: *anyopaque, texture: Texture, src: Rect, dest: Rect, color: Rgba) void,
};

pub const Glyph = struct {
    rect: Rect,
    bearing_x: i32,
    bearing_y: i32,
    advance: f32,
    width: i32,
    height: i32,
    is_color: bool,
};

const FacePair = struct {
    face: ?c.FT_Face = null,
    hb: ?*c.hb_font_t = null,

    // If a face was created via FT_New_Memory_Face, this buffer must stay alive
    // until the face is destroyed.
    owned_data: ?[]u8 = null,
};

const GlyphError = error{
    HbShapeFailed,
    FtLoadFailed,
    FtRenderFailed,
    AtlasFull,
    OutOfMemory,
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
    texture: Texture,
    atlas_width: i32,
    atlas_height: i32,
    pen_x: i32,
    pen_y: i32,
    row_h: i32,
    padding: i32,
    glyphs: std.AutoHashMap(u32, Glyph),
    glyph_order: std.ArrayList(u32),
    max_glyphs: usize,
    upload_buffer: []u8,
    upload_buffer_capacity: usize,
    ascent: f32,
    descent: f32,
    line_height: f32,
    cell_width: f32,
    render_scale: f32,
    use_lcd: bool,
    overflow_policy: AllowSquareGlyphOverflow,

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

        const loadFace = struct {
            fn call(
                library: c.FT_Library,
                fpath: ?[*:0]const u8,
                size_px: f32,
                name: []const u8,
                log: app_logger.Logger,
                allow_fixed_size: bool,
            ) FacePair {
                if (fpath) |path_c| {
                    const path_str = std.mem.sliceTo(path_c, 0);
                    if (log.enabled_file or log.enabled_console) {
                        if (std.fs.cwd().access(path_str, .{})) |_| {
                            log.logf("font load: {s} path={s}", .{ name, path_str });
                        } else |err| {
                            log.logf("font load: {s} path={s} access_err={s}", .{ name, path_str, @errorName(err) });
                        }
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
                        } else if (size_err != 0 and (log.enabled_file or log.enabled_console)) {
                            log.logf("font load failed: {s} set_pixel_sizes err={d}", .{ name, size_err });
                        }
                        if (size_err == 0 or (allow_fixed_size and fb_face.*.num_fixed_sizes > 0)) {
                            if (c.hb_ft_font_create(fb_face, null)) |fb_hb| {
                                return .{ .face = fb_face, .hb = fb_hb };
                            }
                            if (log.enabled_file or log.enabled_console) {
                                log.logf("font load failed: {s} hb_ft_font_create returned null", .{name});
                            }
                        }
                        _ = c.FT_Done_Face(fb_face);
                    } else if (log.enabled_file or log.enabled_console) {
                        log.logf("font load failed: {s} FT_New_Face err={d}", .{ name, new_face_err });
                    }
                } else if (log.enabled_file or log.enabled_console) {
                    log.logf("font load skipped: {s} path not set", .{name});
                }
                return .{};
            }
        }.call;

        const log = app_logger.logger("terminal.font");
        const symbols_pair = loadFace(ft_library, symbols_path, size, "symbols", log, false);
        const unicode_symbols2_pair = loadFace(ft_library, unicode_symbols2_path, size, "unicode_symbols2", log, false);
        const unicode_symbols_pair = loadFace(ft_library, unicode_symbols_path, size, "unicode_symbols", log, false);
        const unicode_mono_pair = loadFace(ft_library, unicode_mono_path, size, "unicode_mono", log, false);
        const unicode_sans_pair = loadFace(ft_library, unicode_sans_path, size, "unicode_sans", log, false);
        const emoji_color_pair = loadFace(ft_library, emoji_color_path, size, "emoji_color", log, true);
        const emoji_text_pair = loadFace(ft_library, emoji_text_path, size, "emoji_text", log, false);

        var fc_enabled = false;
        var fc_config: ?FcConfigPtr = null;
        if (builtin.target.os.tag == .linux) {
            if (fc.FcInit() != 0) {
                fc_enabled = true;
                fc_config = fc.FcConfigGetCurrent();
            } else if (log.enabled_file or log.enabled_console) {
                log.logf("fontconfig init failed", .{});
            }
        }

        if (log.enabled_file or log.enabled_console) {
            const cp_arrow: u32 = 0x21E1; // ⇡
            const cp_braille: u32 = 0x28FF; // ⣿
            const cp_emoji: u32 = 0x1F600; // 😀
            const has_cp = struct {
                fn call(face_opt: ?c.FT_Face, cp: u32) bool {
                    if (face_opt) |face| return c.FT_Get_Char_Index(face, cp) != 0;
                    return false;
                }
            }.call;

            log.logf(
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
            log.logf(
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
        }

        const metrics = ft_face.*.size.*.metrics;
        const ascent_raw = @as(f32, @floatFromInt(metrics.ascender >> 6));
        const descent_raw = @as(f32, @floatFromInt(@abs(metrics.descender >> 6)));
        const line_height_raw = @as(f32, @floatFromInt(metrics.height >> 6));

        // Use typical ASCII glyphs to avoid oversized cell widths.
        var cell_width: f32 = 0;
        const max_advance = @as(f32, @floatFromInt(metrics.max_advance >> 6));
        if (max_advance > 0) {
            cell_width = max_advance;
        }
        const samples = [_]u32{ 'M', 'W', 'd' };
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
            if (c.FT_Load_Char(ft_face, cp, c.FT_LOAD_DEFAULT) == 0) {
                const slot = ft_face.*.glyph;
                const metric_w = @as(f32, @floatFromInt(slot.*.metrics.width >> 6));
                const bearing = @as(f32, @floatFromInt(@max(0, slot.*.bitmap_left)));
                const visual = metric_w + bearing;
                if (visual > cell_width) cell_width = visual;
                const adv_ft = @as(f32, @floatFromInt(slot.*.advance.x >> 6));
                if (adv_ft > cell_width) cell_width = adv_ft;
            }
        }

        if (cell_width <= 0) {
            cell_width = max_advance;
        }
        if (cell_width <= 0) {
            cell_width = size * 0.6;
        }
        const cell_width_px = @as(f32, @floatFromInt(@as(i32, @intFromFloat(std.math.round(cell_width)))));

        const ascent_px = @as(f32, @floatFromInt(@as(i32, @intFromFloat(std.math.round(ascent_raw)))));
        const descent_px = @as(f32, @floatFromInt(@as(i32, @intFromFloat(std.math.round(descent_raw)))));
        const line_height_px = @as(f32, @floatFromInt(@as(i32, @intFromFloat(std.math.round(line_height_raw)))));

        const atlas_width: i32 = 2048;
        const atlas_height: i32 = 2048;
        const padding: i32 = 1;

        const zero_len: usize = @as(usize, @intCast(atlas_width * atlas_height * 4));
        const zero_buf = allocator.alloc(u8, zero_len) catch return error.OutOfMemory;
        defer allocator.free(zero_buf);
        @memset(zero_buf, 0);
        const texture = createTexture(atlas_width, atlas_height, zero_buf);

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
            .texture = texture,
            .atlas_width = atlas_width,
            .atlas_height = atlas_height,
            .pen_x = padding,
            .pen_y = padding,
            .row_h = 0,
            .padding = padding,
            .glyphs = std.AutoHashMap(u32, Glyph).init(allocator),
            .glyph_order = .empty,
            .max_glyphs = 2048,
            .upload_buffer = &[_]u8{},
            .upload_buffer_capacity = 0,
            .ascent = ascent_px,
            .descent = descent_px,
            .line_height = if (line_height_px > 0) line_height_px else ascent_px + descent_px,
            .cell_width = if (cell_width_px > 0) cell_width_px else size * 0.6,
            .render_scale = 1.0,
            .use_lcd = std.c.getenv("ZIDE_FONT_LCD") != null,
            .overflow_policy = blk: {
                if (std.c.getenv("ZIDE_GLYPH_OVERFLOW")) |raw| {
                    const s = std.mem.sliceTo(raw, 0);
                    if (std.mem.eql(u8, s, "never")) break :blk .never;
                    if (std.mem.eql(u8, s, "always")) break :blk .always;
                }
                break :blk .when_followed_by_space;
            },
        };
    }

    pub fn deinit(self: *TerminalFont) void {
        self.glyphs.deinit();
        self.glyph_order.deinit(self.allocator);
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

        if (self.texture.id != 0) {
            gl.DeleteTextures(1, &self.texture.id);
        }
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

    pub fn setAtlasFilterPoint(self: *TerminalFont) void {
        gl.BindTexture(gl.c.GL_TEXTURE_2D, self.texture.id);
        gl.TexParameteri(gl.c.GL_TEXTURE_2D, gl.c.GL_TEXTURE_MIN_FILTER, gl.c.GL_NEAREST);
        gl.TexParameteri(gl.c.GL_TEXTURE_2D, gl.c.GL_TEXTURE_MAG_FILTER, gl.c.GL_NEAREST);
    }

    pub fn drawGlyph(self: *TerminalFont, draw: DrawContext, codepoint: u32, x: f32, y: f32, cell_width: f32, cell_height: f32, followed_by_space: bool, color: Rgba) void {
        if (codepoint == 0) return;
        const glyph = self.getGlyph(codepoint) catch return;
        const render_scale = if (self.render_scale > 0.0) self.render_scale else 1.0;
        const inv_scale = 1.0 / render_scale;
        const baseline = y + self.ascent * inv_scale;

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

        const overflow_scale = if (!allow_width_overflow and glyph_w > cell_width and glyph_w > 0) cell_width / glyph_w else 1.0;
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
            const snapped_x = @as(f32, @floatFromInt(@as(i32, @intFromFloat(std.math.round(draw_x)))));
            const snapped_y = @as(f32, @floatFromInt(@as(i32, @intFromFloat(std.math.round(draw_y)))));
            const dest = Rect{ .x = snapped_x, .y = snapped_y, .width = scaled_w, .height = scaled_h };
            draw.drawTexture(draw.ctx, self.texture, glyph.rect, dest, draw_color);
            return;
        }

        // Normal glyph: draw at bearing position, clamped to not go left of cell.
        const draw_x = if (allow_width_overflow) x + bearing * overflow_scale else @max(x, x + bearing * overflow_scale);
        const draw_y = baseline - bearing_y * overflow_scale;
        const snapped_x = @as(f32, @floatFromInt(@as(i32, @intFromFloat(std.math.round(draw_x)))));
        const snapped_y = @as(f32, @floatFromInt(@as(i32, @intFromFloat(std.math.round(draw_y)))));
        const dest = Rect{ .x = snapped_x, .y = snapped_y, .width = scaled_w, .height = scaled_h };
        draw.drawTexture(draw.ctx, self.texture, glyph.rect, dest, draw_color);
    }

    pub fn glyphAdvance(self: *TerminalFont, codepoint: u32) GlyphError!f32 {
        const glyph = try self.getGlyph(codepoint);
        const render_scale = if (self.render_scale > 0.0) self.render_scale else 1.0;
        return glyph.advance / render_scale;
    }

    fn getGlyph(self: *TerminalFont, codepoint: u32) GlyphError!*Glyph {
        if (self.glyphs.getPtr(codepoint)) |glyph| return glyph;

        try self.rasterizeGlyph(codepoint, true);
        return self.glyphs.getPtr(codepoint).?;
    }

    fn hasGlyph(face: c.FT_Face, codepoint: u32) bool {
        return c.FT_Get_Char_Index(face, codepoint) != 0;
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

        if (self.system_fallback_by_cp.get(codepoint)) |cached| {
            if (cached) |path| {
                if (self.system_faces.get(path)) |pair| return pair;
                _ = self.system_fallback_by_cp.put(codepoint, null) catch {};
            }
            return null;
        }

        if (os_tag == .windows) {
            const pair = self.windowsSystemFallback(codepoint);
            if (pair == null) {
                _ = self.system_fallback_by_cp.put(codepoint, null) catch {};
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
            _ = self.system_fallback_by_cp.put(codepoint, null) catch {};
            return null;
        }
        defer fc.FcPatternDestroy(match);

        var file_ptr: [*c]fc.FcChar8 = null;
        if (fc.FcPatternGetString(match, fc.FC_FILE, 0, &file_ptr) != fc.FcResultMatch) {
            _ = self.system_fallback_by_cp.put(codepoint, null) catch {};
            return null;
        }

        const path = std.mem.sliceTo(@as([*:0]const u8, @ptrCast(file_ptr)), 0);
        if (self.system_faces.getEntry(path)) |entry| {
            _ = self.system_fallback_by_cp.put(codepoint, @constCast(entry.key_ptr.*)) catch return null;
            return entry.value_ptr.*;
        }

        const owned = self.allocator.dupe(u8, path) catch return null;
        errdefer self.allocator.free(owned);

        var fb_pair: FacePair = .{};
        if (!ftNewFaceFromFile(self, owned, &fb_pair)) {
            _ = self.system_fallback_by_cp.put(codepoint, null) catch {};
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
            _ = self.system_fallback_by_cp.put(codepoint, null) catch {};
            return null;
        }
        const fb_hb = c.hb_ft_font_create(fb_face, null) orelse {
            _ = c.FT_Done_Face(fb_face);
            _ = self.system_fallback_by_cp.put(codepoint, null) catch {};
            return null;
        };

        fb_pair.hb = fb_hb;
        self.system_faces.put(self.allocator, owned, fb_pair) catch {
            c.hb_font_destroy(fb_hb);
            _ = c.FT_Done_Face(fb_face);
            if (fb_pair.owned_data) |data| self.allocator.free(data);
            self.allocator.free(owned);
            _ = self.system_fallback_by_cp.put(codepoint, null) catch {};
            return null;
        };
        _ = self.system_fallback_by_cp.put(codepoint, owned) catch {};
        result = fb_pair;
        return result;
    }

    fn ftNewFace(self: *TerminalFont, path: []const u8, out_face: *c.FT_Face) bool {
        // FreeType expects a 0-terminated path. Avoid storing the terminator in
        // the hash-map key by allocating a temporary sentinel buffer here.
        var tmp = self.allocator.alloc(u8, path.len + 1) catch return false;
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
        // Load a file into memory and create a FreeType face from it. This is a
        // fallback for paths that FreeType cannot open directly (encoding or
        // sandbox constraints). The buffer must remain alive.
        var file = std.fs.openFileAbsolute(path, .{}) catch return false;
        defer file.close();
        const bytes = file.readToEndAlloc(self.allocator, 32 * 1024 * 1024) catch return false;
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
        const windir = std.c.getenv("WINDIR") orelse return null;
        const base = std.mem.sliceTo(windir, 0);
        return std.fs.path.join(allocator, &.{ base, "Fonts" }) catch return null;
    }

    fn windowsSystemFallback(self: *TerminalFont, codepoint: u32) ?FacePair {
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
                _ = self.system_fallback_by_cp.put(codepoint, @constCast(entry.key_ptr.*)) catch {};
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

            fb_pair.hb = fb_hb;
            self.system_faces.put(self.allocator, owned, fb_pair) catch {
                c.hb_font_destroy(fb_hb);
                _ = c.FT_Done_Face(fb_face);
                if (fb_pair.owned_data) |data| self.allocator.free(data);
                self.allocator.free(owned);
                return null;
            };
            _ = self.system_fallback_by_cp.put(codepoint, owned) catch {};
            return fb_pair;
        }

        if (self.windowsDirectWriteResolveFontPath(codepoint)) |path_utf8| {
            // If we've already loaded this face, reuse it.
            if (self.system_faces.getEntry(path_utf8)) |entry| {
                self.allocator.free(path_utf8);
                _ = self.system_fallback_by_cp.put(codepoint, @constCast(entry.key_ptr.*)) catch {};
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
            _ = self.system_fallback_by_cp.put(codepoint, owned) catch {};
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

    fn rasterizeGlyph(self: *TerminalFont, codepoint: u32, allow_compact: bool) GlyphError!void {
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

        const glyph_id = infos[0].codepoint;
        const is_color_face = c.FT_HAS_COLOR(face) or (self.emoji_color_ft_face != null and face == self.emoji_color_ft_face.?);
        const want_color = is_color_face;
        const load_flags: c_int = blk: {
            var flags: c_int = c.FT_LOAD_DEFAULT;
            if (want_color) flags |= c.FT_LOAD_COLOR;
            if (self.use_lcd and !want_color) flags |= c.FT_LOAD_TARGET_LCD;
            break :blk flags;
        };
        if (c.FT_Load_Glyph(face, glyph_id, load_flags) != 0) {
            if (self.emoji_color_ft_face != null and face == self.emoji_color_ft_face.? and self.emoji_text_ft_face != null and self.emoji_text_hb_font != null) {
                face = self.emoji_text_ft_face.?;
                hb_font = self.emoji_text_hb_font.?;
                if (c.FT_Load_Glyph(face, glyph_id, c.FT_LOAD_DEFAULT) != 0) return error.FtLoadFailed;
            } else {
                return error.FtLoadFailed;
            }
        }
        const render_mode: c.FT_Render_Mode = if (self.use_lcd and !want_color) c.FT_RENDER_MODE_LCD else c.FT_RENDER_MODE_NORMAL;
        if (c.FT_Render_Glyph(face.*.glyph, render_mode) != 0) {
            if (self.use_lcd and c.FT_Render_Glyph(face.*.glyph, c.FT_RENDER_MODE_NORMAL) == 0) {
                // fall back to grayscale
            } else {
                return error.FtRenderFailed;
            }
        }

        const slot = face.*.glyph;
        const bitmap = slot.*.bitmap;
        const width: i32 = if (bitmap.pixel_mode == c.FT_PIXEL_MODE_LCD) @intCast(bitmap.width / 3) else @intCast(bitmap.width);
        const height: i32 = @intCast(bitmap.rows);

        if (width > 0 and height > 0) {
            if (self.pen_x + width + self.padding > self.atlas_width) {
                self.pen_x = self.padding;
                self.pen_y += self.row_h + self.padding;
                self.row_h = 0;
            }
            if (self.pen_y + height + self.padding > self.atlas_height) {
                if (allow_compact) {
                    // Try to compact and retry once.
                    try self.compactAtlas();
                    try self.rasterizeGlyph(codepoint, false);
                    return;
                }
                return error.AtlasFull;
            }

            const pixel_count = @as(usize, @intCast(width * height));
            const needed = pixel_count * 4;
            if (needed > self.upload_buffer_capacity) {
                if (self.upload_buffer_capacity > 0) {
                    self.allocator.free(self.upload_buffer);
                }
                self.upload_buffer = try self.allocator.alloc(u8, needed);
                self.upload_buffer_capacity = needed;
            }
            const rgba = self.upload_buffer[0..needed];

            var y: i32 = 0;
            while (y < height) : (y += 1) {
                var x: i32 = 0;
                while (x < width) : (x += 1) {
                    var r: u8 = 0;
                    var g: u8 = 0;
                    var b: u8 = 0;
                    var a: u8 = 0;
                    if (bitmap.pixel_mode == c.FT_PIXEL_MODE_BGRA) {
                        const base = @as(usize, @intCast(y * @as(i32, @intCast(bitmap.pitch)) + x * 4));
                        b = bitmap.buffer[base + 0];
                        g = bitmap.buffer[base + 1];
                        r = bitmap.buffer[base + 2];
                        a = bitmap.buffer[base + 3];
                    } else if (bitmap.pixel_mode == c.FT_PIXEL_MODE_LCD) {
                        const base = @as(usize, @intCast(y * @as(i32, @intCast(bitmap.pitch)) + x * 3));
                        r = bitmap.buffer[base + 0];
                        g = bitmap.buffer[base + 1];
                        b = bitmap.buffer[base + 2];
                        a = @max(r, @max(g, b));
                    } else {
                        const src_idx = @as(usize, @intCast(y * @as(i32, @intCast(bitmap.pitch)) + x));
                        a = bitmap.buffer[src_idx];
                        r = a;
                        g = a;
                        b = a;
                    }
                    const dst_idx = @as(usize, @intCast((y * width + x) * 4));
                    if (bitmap.pixel_mode == c.FT_PIXEL_MODE_BGRA) {
                        rgba[dst_idx] = r;
                        rgba[dst_idx + 1] = g;
                        rgba[dst_idx + 2] = b;
                        rgba[dst_idx + 3] = a;
                    } else {
                        const gamma = 1.0 / 2.2;
                        const rf = std.math.pow(f32, @as(f32, @floatFromInt(r)) / 255.0, gamma);
                        const gf = std.math.pow(f32, @as(f32, @floatFromInt(g)) / 255.0, gamma);
                        const bf = std.math.pow(f32, @as(f32, @floatFromInt(b)) / 255.0, gamma);
                        const af = std.math.pow(f32, @as(f32, @floatFromInt(a)) / 255.0, gamma);
                        rgba[dst_idx] = @intFromFloat(@min(255.0, rf * 255.0));
                        rgba[dst_idx + 1] = @intFromFloat(@min(255.0, gf * 255.0));
                        rgba[dst_idx + 2] = @intFromFloat(@min(255.0, bf * 255.0));
                        rgba[dst_idx + 3] = @intFromFloat(@min(255.0, af * 255.0));
                    }
                }
            }

            const rec = Rect{
                .x = @floatFromInt(self.pen_x),
                .y = @floatFromInt(self.pen_y),
                .width = @floatFromInt(width),
                .height = @floatFromInt(height),
            };
            updateTextureRegion(self.texture, rec, rgba);

            if (height > self.row_h) self.row_h = height;
            const advance = @as(f32, @floatFromInt(positions[0].x_advance)) / 64.0;
            const glyph = Glyph{
                .rect = rec,
                .bearing_x = slot.*.bitmap_left,
                .bearing_y = slot.*.bitmap_top,
                .advance = if (advance > 0) advance else @as(f32, @floatFromInt(slot.*.advance.x)) / 64.0,
                .width = width,
                .height = height,
                .is_color = bitmap.pixel_mode == c.FT_PIXEL_MODE_BGRA,
            };
            if (self.max_glyphs > 0 and self.glyphs.count() >= self.max_glyphs) {
                if (self.glyph_order.items.len > 0) {
                    const evict = self.glyph_order.orderedRemove(0);
                    _ = self.glyphs.remove(evict);
                }
            }
            try self.glyphs.put(codepoint, glyph);
            try self.glyph_order.append(self.allocator, codepoint);
            self.pen_x += width + self.padding;
            return;
        }

        const glyph = Glyph{
            .rect = .{ .x = 0, .y = 0, .width = 0, .height = 0 },
            .bearing_x = 0,
            .bearing_y = 0,
            .advance = @as(f32, @floatFromInt(slot.*.advance.x)) / 64.0,
            .width = 0,
            .height = 0,
            .is_color = false,
        };
        if (self.max_glyphs > 0 and self.glyphs.count() >= self.max_glyphs) {
            if (self.glyph_order.items.len > 0) {
                const evict = self.glyph_order.orderedRemove(0);
                _ = self.glyphs.remove(evict);
            }
        }
        try self.glyphs.put(codepoint, glyph);
        try self.glyph_order.append(self.allocator, codepoint);
        return;
    }

    fn compactAtlas(self: *TerminalFont) GlyphError!void {
        var old_order = try self.glyph_order.clone(self.allocator);
        defer old_order.deinit(self.allocator);

        self.glyphs.clearRetainingCapacity();
        self.glyph_order.clearRetainingCapacity();

        self.pen_x = self.padding;
        self.pen_y = self.padding;
        self.row_h = 0;

        if (self.texture.id != 0) {
            gl.DeleteTextures(1, &self.texture.id);
        }
        const zero_len: usize = @as(usize, @intCast(self.atlas_width * self.atlas_height * 4));
        const zero_buf = self.allocator.alloc(u8, zero_len) catch return error.OutOfMemory;
        defer self.allocator.free(zero_buf);
        @memset(zero_buf, 0);
        self.texture = createTexture(self.atlas_width, self.atlas_height, zero_buf);

        const count = old_order.items.len;
        var kept: usize = 0;
        var idx: usize = 0;
        while (idx < count and kept < self.max_glyphs) : (idx += 1) {
            const codepoint = old_order.items[count - 1 - idx];
            if (self.glyphs.contains(codepoint)) continue;
            try self.rasterizeGlyph(codepoint, false);
            kept += 1;
        }
    }
};

fn createTexture(width: i32, height: i32, data: []const u8) Texture {
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
        data.ptr,
    );
    return .{ .id = id, .width = width, .height = height };
}

fn updateTextureRegion(texture: Texture, rect: Rect, data: []const u8) void {
    const w: i32 = @intFromFloat(rect.width);
    const h: i32 = @intFromFloat(rect.height);
    if (w <= 0 or h <= 0) return;
    gl.BindTexture(gl.c.GL_TEXTURE_2D, texture.id);
    gl.PixelStorei(gl.c.GL_UNPACK_ALIGNMENT, 1);
    gl.TexSubImage2D(
        gl.c.GL_TEXTURE_2D,
        0,
        @intFromFloat(rect.x),
        @intFromFloat(rect.y),
        w,
        h,
        gl.c.GL_RGBA,
        gl.c.GL_UNSIGNED_BYTE,
        data.ptr,
    );
}
