const terminal_font = @import("../terminal_font.zig");

const c = terminal_font.c;

pub fn pickPreferred(self: anytype, codepoint: u32) struct { face: ?c.FT_Face, hb: ?*c.hb_font_t } {
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

pub fn pickFallback(self: anytype, codepoint: u32) struct { face: ?c.FT_Face, hb: ?*c.hb_font_t } {
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

fn hasGlyph(face: c.FT_Face, codepoint: u32) bool {
    return c.FT_Get_Char_Index(face, codepoint) != 0;
}

fn preferSymbols(codepoint: u32) bool {
    return (codepoint >= 0xE000 and codepoint <= 0xF8FF) or
        (codepoint >= 0xF0000 and codepoint <= 0xFFFFD) or
        (codepoint >= 0x100000 and codepoint <= 0x10FFFD) or
        (codepoint >= 0x2500 and codepoint <= 0x259F) or
        (codepoint >= 0x2800 and codepoint <= 0x28FF) or
        (codepoint >= 0x1FB00 and codepoint <= 0x1FBFF);
}

fn preferEmoji(codepoint: u32) bool {
    return (codepoint >= 0x1F000 and codepoint <= 0x1FAFF) or
        (codepoint >= 0x1F1E6 and codepoint <= 0x1F1FF) or
        (codepoint >= 0x2600 and codepoint <= 0x27BF);
}

fn preferUnicode(codepoint: u32) bool {
    return (codepoint >= 0x2500 and codepoint <= 0x259F) or
        (codepoint >= 0x2190 and codepoint <= 0x21FF) or
        (codepoint >= 0x2800 and codepoint <= 0x28FF) or
        (codepoint >= 0x1FB00 and codepoint <= 0x1FBFF);
}
