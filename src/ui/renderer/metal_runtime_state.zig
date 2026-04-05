const std = @import("std");
const terminal_font_mod = @import("../terminal_font.zig");
const metal_backend = @import("metal_backend.zig");
const surface_draw = @import("surface_draw.zig");

const TerminalFont = terminal_font_mod.TerminalFont;

pub const AtlasPreviewSource = enum {
    unavailable,
    seeded_color_block,
    uploaded_coverage_glyph,
    uploaded_color_glyph,
};

pub const State = struct {
    backend_context: ?metal_backend.BackendContext = null,
    frame: ?metal_backend.Frame = null,
    queued_surface_draws: std.ArrayListUnmanaged(surface_draw.SurfaceDraw) = .{},
    diagnostic_font: ?TerminalFont = null,
    preview_source: AtlasPreviewSource = .unavailable,
};
