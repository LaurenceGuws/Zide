const app_bootstrap = @import("bootstrap.zig");
const builtin = @import("builtin");
const std = @import("std");
const config_mod = @import("../config/lua_config.zig");
const renderer_mod = @import("../ui/renderer.zig");
const terminal_font_mod = @import("../ui/terminal_font.zig");
const app_shell = @import("../app_shell.zig");

const Shell = app_shell.Shell;
pub const RendererInitOptions = app_shell.RendererInitOptions;

pub const RendererConfigApplyResult = struct {
    font_choice_changed: bool = false,
    font_rendering_changed: bool = false,
    text_rendering_changed: bool = false,
    rebuilt_fonts: bool = false,

    pub fn anyChanged(self: RendererConfigApplyResult) bool {
        return self.font_choice_changed or self.font_rendering_changed or self.text_rendering_changed;
    }
};

fn resolveSharedFontPath(config: *const config_mod.Config) ?[]const u8 {
    return config.terminal_font_path orelse config.editor_font_path orelse config.app_font_path;
}

fn resolveSharedBaseFontSize(config: *const config_mod.Config) f32 {
    const font_size = config.terminal_font_size orelse config.editor_font_size orelse config.app_font_size;
    return if (font_size) |value| if (value > 0.0) value else 16.0 else 16.0;
}

fn resolveTextGamma(config: *const config_mod.Config) f32 {
    return if (config.text_gamma) |value| if (value > 0.0) value else 1.0 else 1.0;
}

fn resolveTextContrast(config: *const config_mod.Config) f32 {
    return if (config.text_contrast) |value| if (value > 0.0) value else 1.0 else 1.0;
}

fn buildFontRenderingOptions(config: *const config_mod.Config) terminal_font_mod.RenderingOptions {
    var font_opts: terminal_font_mod.RenderingOptions = .{};
    if (builtin.os.tag == .windows) {
        // FreeType's default small-size rendering on Windows is too fragile for
        // the current editor path. Start from a more stable hinted baseline.
        font_opts.hinting = .light;
        font_opts.autohint = true;
    }
    if (config.font_lcd) |v| font_opts.lcd = v;
    if (app_bootstrap.parseEnvBool("ZIDE_FONT_RENDERING_LCD")) |v| font_opts.lcd = v;
    if (config.font_autohint) |v| font_opts.autohint = v;
    if (config.font_hinting) |mode| {
        font_opts.hinting = switch (mode) {
            .default => .default,
            .none => .none,
            .light => .light,
            .normal => .normal,
        };
    }
    if (config.font_glyph_overflow) |policy| {
        font_opts.glyph_overflow = switch (policy) {
            .when_followed_by_space => .when_followed_by_space,
            .never => .never,
            .always => .always,
        };
    }
    return font_opts;
}

pub fn buildRendererInitOptions(config: *const config_mod.Config) RendererInitOptions {
    return .{
        .base_font_size = resolveSharedBaseFontSize(config),
        .font_path = resolveSharedFontPath(config),
        .font_rendering = buildFontRenderingOptions(config),
        .text_gamma = resolveTextGamma(config),
        .text_contrast = resolveTextContrast(config),
        .text_linear_correction = config.text_linear_correction orelse true,
    };
}

pub fn applyRendererFontRenderingConfig(shell: *Shell, config: *const config_mod.Config, rebuild_fonts: bool) !void {
    const renderer = shell.rendererPtr();
    renderer.setFontRenderingOptions(buildFontRenderingOptions(config));
    renderer.setTextRenderingConfig(config.text_gamma, config.text_contrast, config.text_linear_correction);
    if (rebuild_fonts) {
        try renderer.setFontConfig(null, null);
    }
}

pub fn applyRendererReloadConfig(shell: *Shell, config: *const config_mod.Config) !RendererConfigApplyResult {
    const renderer = shell.rendererPtr();
    const init = buildRendererInitOptions(config);
    const current_path = std.mem.span(renderer.font_path);
    const next_path = init.font_path orelse std.mem.span(renderer_mod.FONT_PATH);
    const current_size = renderer.base_font_size;
    const next_size = init.base_font_size;
    const font_choice_changed = !std.mem.eql(u8, current_path, next_path) or
        !std.math.approxEqAbs(f32, current_size, next_size, 0.0001);
    const font_rendering_changed = !std.meta.eql(renderer.font_rendering, init.font_rendering);
    const text_rendering_changed =
        !std.math.approxEqAbs(f32, renderer.text_gamma, init.text_gamma, 0.0001) or
        !std.math.approxEqAbs(f32, renderer.text_contrast, init.text_contrast, 0.0001) or
        renderer.text_linear_correction != init.text_linear_correction;

    renderer.setFontRenderingOptions(init.font_rendering);
    renderer.setTextRenderingConfig(init.text_gamma, init.text_contrast, init.text_linear_correction);

    if (font_choice_changed or font_rendering_changed) {
        try renderer.setFontConfig(
            if (!std.mem.eql(u8, current_path, next_path)) next_path else null,
            if (!std.math.approxEqAbs(f32, current_size, next_size, 0.0001)) next_size else null,
        );
    }

    return .{
        .font_choice_changed = font_choice_changed,
        .font_rendering_changed = font_rendering_changed,
        .text_rendering_changed = text_rendering_changed,
        .rebuilt_fonts = font_choice_changed or font_rendering_changed,
    };
}

test "buildRendererInitOptions uses shared font precedence" {
    const allocator = std.testing.allocator;
    var config = config_mod.emptyConfig();
    defer config_mod.freeConfig(allocator, &config);

    config.app_font_path = try allocator.dupe(u8, "app.ttf");
    config.app_font_size = 14.0;
    config.editor_font_path = try allocator.dupe(u8, "editor.ttf");
    config.editor_font_size = 15.0;
    config.terminal_font_path = try allocator.dupe(u8, "terminal.ttf");
    config.terminal_font_size = 16.0;

    const init = buildRendererInitOptions(&config);
    try std.testing.expectEqualStrings("terminal.ttf", init.font_path.?);
    try std.testing.expectApproxEqAbs(@as(f32, 16.0), init.base_font_size, 0.0001);
}

test "buildRendererInitOptions falls back to default size for invalid font size" {
    var config = config_mod.emptyConfig();
    config.app_font_size = 0.0;

    const init = buildRendererInitOptions(&config);
    try std.testing.expectEqual(@as(?[]const u8, null), init.font_path);
    try std.testing.expectApproxEqAbs(@as(f32, 16.0), init.base_font_size, 0.0001);
}
