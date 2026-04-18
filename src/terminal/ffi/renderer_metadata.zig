//! Renderer-facing metadata for the terminal FFI surface (platform-agnostic).
//! Native hosts (including Android JNI) obtain glyph classification and damage
//! policy bits through `core_api.rendererMetadata` → this module — single path.

const shared = @import("shared.zig");

pub fn fillRendererMetadata(out: *shared.RendererMetadata, codepoint: u32) void {
    out.* = .{
        .abi_version = shared.renderer_metadata_abi_version,
        .struct_size = @sizeOf(shared.RendererMetadata),
        .codepoint = codepoint,
        .glyph_class_flags = classifyGlyphClassFlags(codepoint),
        .damage_policy_flags = @intFromEnum(shared.DamagePolicyFlags.advisory_bounds) |
            @intFromEnum(shared.DamagePolicyFlags.full_redraw_safe_default),
    };
}

/// Bitmask of `shared.GlyphClassFlags` for shaping / atlas hints.
pub fn classifyGlyphClassFlags(codepoint: u32) u32 {
    var flags: u32 = 0;
    if (isBoxGlyph(codepoint)) flags |= @intFromEnum(shared.GlyphClassFlags.box);
    if (isRoundedBoxGlyph(codepoint)) flags |= @intFromEnum(shared.GlyphClassFlags.box_rounded);
    if (isGraphGlyph(codepoint)) flags |= @intFromEnum(shared.GlyphClassFlags.graph);
    if (isBrailleGlyph(codepoint)) flags |= @intFromEnum(shared.GlyphClassFlags.braille);
    if (isPowerlineGlyph(codepoint)) flags |= @intFromEnum(shared.GlyphClassFlags.powerline);
    if (isRoundedPowerlineGlyph(codepoint)) flags |= @intFromEnum(shared.GlyphClassFlags.powerline_rounded);
    return flags;
}

fn isBoxGlyph(codepoint: u32) bool {
    return codepoint >= 0x2500 and codepoint <= 0x259F;
}

fn isRoundedBoxGlyph(codepoint: u32) bool {
    return switch (codepoint) {
        0x256D, 0x256E, 0x256F, 0x2570 => true,
        else => false,
    };
}

fn isGraphGlyph(codepoint: u32) bool {
    return (codepoint >= 0x2580 and codepoint <= 0x259F) or
        (codepoint >= 0x2800 and codepoint <= 0x28FF) or
        (codepoint >= 0x1FB00 and codepoint <= 0x1FBAF) or
        codepoint == 0x1FBE6 or
        codepoint == 0x1FBE7;
}

fn isBrailleGlyph(codepoint: u32) bool {
    return codepoint >= 0x2800 and codepoint <= 0x28FF;
}

fn isPowerlineGlyph(codepoint: u32) bool {
    return (codepoint >= 0xE0B0 and codepoint <= 0xE0BF) or
        codepoint == 0xE0D6 or
        codepoint == 0xE0D7;
}

fn isRoundedPowerlineGlyph(codepoint: u32) bool {
    return switch (codepoint) {
        0xE0B4, 0xE0B5, 0xE0B6, 0xE0B7 => true,
        else => false,
    };
}
