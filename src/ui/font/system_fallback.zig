const std = @import("std");
const builtin = @import("builtin");
const app_logger = @import("../../app_logger.zig");
const terminal_font = @import("../terminal_font.zig");

const c = terminal_font.c;
const FacePair = terminal_font.FacePair;
const fc = terminal_font.fc;
const windows_com_initialized = terminal_font.windows_com_initialized;
const windows_dwrite = terminal_font.windows_dwrite;

pub fn systemFallback(self: anytype, codepoint: u32) ?FacePair {
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
        const pair = windowsSystemFallback(self, codepoint);
        if (pair == null) {
            self.system_fallback_by_cp.put(codepoint, null) catch |err| {
                log.logf(.warning, "windows fallback cache negative store failed cp={d} err={s}", .{ codepoint, @errorName(err) });
            };
        }
        return pair;
    }

    if (!self.fc_enabled or self.fc_config == null) return null;

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
    terminal_font.applyHbLoadFlags(fb_hb, self.ft_load_flags_base);

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
    return fb_pair;
}

fn ftNewFace(self: anytype, path: []const u8, out_face: *c.FT_Face) bool {
    const log = app_logger.logger("terminal.font");
    var tmp = self.allocator.alloc(u8, path.len + 1) catch |err| {
        log.logf(.warning, "ftNewFace temp path alloc failed len={d} err={s}", .{ path.len + 1, @errorName(err) });
        return false;
    };
    defer self.allocator.free(tmp);
    std.mem.copyForwards(u8, tmp[0..path.len], path);
    tmp[path.len] = 0;
    return c.FT_New_Face(self.ft_library, tmp.ptr, 0, out_face) == 0;
}

fn ftNewFaceFromFile(self: anytype, path: []const u8, out_pair: *FacePair) bool {
    var face: c.FT_Face = null;
    if (!ftNewFace(self, path, &face)) return false;
    out_pair.* = .{ .face = face, .hb = null, .owned_data = null };
    return true;
}

fn ftNewFaceFromMemoryFile(self: anytype, path: []const u8, out_pair: *FacePair) bool {
    const log = app_logger.logger("terminal.font");
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

fn windowsSystemFallback(self: anytype, codepoint: u32) ?FacePair {
    const log = app_logger.logger("terminal.font");
    const font_dir = windowsFontDir(self.allocator) orelse return null;
    defer self.allocator.free(font_dir);

    const candidates = [_][]const u8{
        "seguiemj.ttf",
        "seguisym.ttf",
        "segoeui.ttf",
        "consola.ttf",
        "arial.ttf",
        "times.ttf",
    };

    for (candidates) |file| {
        const path = std.fs.path.join(self.allocator, &.{ font_dir, file }) catch continue;
        defer self.allocator.free(path);

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

        if (c.FT_Get_Char_Index(fb_face, codepoint) == 0) continue;
        if (c.FT_Set_Pixel_Sizes(fb_face, 0, @intFromFloat(self.line_height)) != 0) {
            _ = c.FT_Done_Face(fb_face);
            continue;
        }

        const fb_hb = c.hb_ft_font_create(fb_face, null) orelse continue;
        terminal_font.applyHbLoadFlags(fb_hb, self.ft_load_flags_base);

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

    if (windowsDirectWriteResolveFontPath(self, codepoint)) |path_utf8| {
        if (self.system_faces.getEntry(path_utf8)) |entry| {
            self.allocator.free(path_utf8);
            self.system_fallback_by_cp.put(codepoint, @constCast(entry.key_ptr.*)) catch |err| {
                log.logf(.warning, "windows dwrite cache store failed cp={d} path={s} err={s}", .{ codepoint, entry.key_ptr.*, @errorName(err) });
            };
            return entry.value_ptr.*;
        }

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

        if (c.FT_Set_Pixel_Sizes(fb_face, 0, @intFromFloat(self.line_height)) != 0) return null;

        const fb_hb = c.hb_ft_font_create(fb_face, null) orelse return null;
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

fn windowsDirectWriteResolveFontPath(self: anytype, codepoint: u32) ?[]u8 {
    if (builtin.target.os.tag != .windows) return null;
    if (!ensureWindowsComInit()) return null;

    var factory_any: ?*anyopaque = null;
    if (windows_dwrite.DWriteCreateFactory(windows_dwrite.DWRITE_FACTORY_TYPE_SHARED, &windows_dwrite.IID_IDWriteFactory, &factory_any) < 0) return null;
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
