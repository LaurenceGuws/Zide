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

fn rendererBackendFromEnv() ?renderer_mod.Renderer.RendererBackend {
    const slice = app_bootstrap.envSlice("ZIDE_RENDERER_BACKEND") orelse return null;
    if (std.mem.eql(u8, slice, "metal")) return .metal;
    if (std.mem.eql(u8, slice, "opengl")) return .opengl;
    return null;
}

fn resolveAppFontPath(config: *const config_mod.Config) ?[]const u8 {
    return config.app_font_path;
}

fn resolveEditorFontPath(config: *const config_mod.Config) ?[]const u8 {
    return config.editor_font_path orelse config.app_font_path;
}

fn resolveTerminalFontPath(config: *const config_mod.Config) ?[]const u8 {
    return config.terminal_font_path orelse config.app_font_path;
}

fn resolveBaseFontSize(size_opt: ?f32) f32 {
    return if (size_opt) |value| if (value > 0.0) value else 16.0 else 16.0;
}

fn resolveAppBaseFontSize(config: *const config_mod.Config) f32 {
    return resolveBaseFontSize(config.app_font_size);
}

fn resolveEditorBaseFontSize(config: *const config_mod.Config) f32 {
    return if (config.editor_font_size) |value|
        if (value > 0.0) value else resolveAppBaseFontSize(config)
    else
        resolveAppBaseFontSize(config);
}

fn resolveTerminalBaseFontSize(config: *const config_mod.Config) f32 {
    return if (config.terminal_font_size) |value|
        if (value > 0.0) value else resolveAppBaseFontSize(config)
    else
        resolveAppBaseFontSize(config);
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
        .app_font_size = resolveAppBaseFontSize(config),
        .app_font_path = resolveAppFontPath(config),
        .editor_font_size = resolveEditorBaseFontSize(config),
        .editor_font_path = resolveEditorFontPath(config),
        .terminal_font_size = resolveTerminalBaseFontSize(config),
        .terminal_font_path = resolveTerminalFontPath(config),
        .font_rendering = buildFontRenderingOptions(config),
        .text_gamma = resolveTextGamma(config),
        .text_contrast = resolveTextContrast(config),
        .text_linear_correction = config.text_linear_correction orelse true,
        .renderer_backend = rendererBackendFromEnv() orelse .opengl,
    };
}

pub fn applyRendererFontRenderingConfig(shell: *Shell, config: *const config_mod.Config, rebuild_fonts: bool) !void {
    const renderer = shell.rendererPtr();
    renderer.setFontRenderingOptions(buildFontRenderingOptions(config));
    renderer.setTextRenderingConfig(config.text_gamma, config.text_contrast, config.text_linear_correction);
    if (rebuild_fonts) {
        try renderer.setFontConfig(null, null, null, null, null, null);
    }
}

pub fn applyRendererReloadConfig(shell: *Shell, config: *const config_mod.Config) !RendererConfigApplyResult {
    const renderer = shell.rendererPtr();
    const init = buildRendererInitOptions(config);

    const current_app_path = std.mem.span(renderer.font_config.app_font_path);
    const current_editor_path = std.mem.span(renderer.font_config.editor_font_path);
    const current_terminal_path = std.mem.span(renderer.font_config.terminal_font_path);
    const next_app_path = init.app_font_path orelse std.mem.span(renderer_mod.FONT_PATH);
    const next_editor_path = init.editor_font_path orelse next_app_path;
    const next_terminal_path = init.terminal_font_path orelse next_app_path;

    const app_changed = !std.mem.eql(u8, current_app_path, next_app_path) or
        !std.math.approxEqAbs(f32, renderer.base_font_size, init.app_font_size, 0.0001);
    const editor_changed = !std.mem.eql(u8, current_editor_path, next_editor_path) or
        !std.math.approxEqAbs(f32, renderer.editor_base_font_size, init.editor_font_size orelse renderer.base_font_size, 0.0001);
    const terminal_changed = !std.mem.eql(u8, current_terminal_path, next_terminal_path) or
        !std.math.approxEqAbs(f32, renderer.terminal_base_font_size, init.terminal_font_size orelse renderer.base_font_size, 0.0001);

    const font_choice_changed = app_changed or editor_changed or terminal_changed;
    const font_rendering_changed = !std.meta.eql(renderer.font_config.font_rendering, init.font_rendering);
    const text_rendering_changed =
        !std.math.approxEqAbs(f32, renderer.text_render.gamma, init.text_gamma, 0.0001) or
        !std.math.approxEqAbs(f32, renderer.text_render.contrast, init.text_contrast, 0.0001) or
        renderer.text_render.linear_correction != init.text_linear_correction;

    renderer.setFontRenderingOptions(init.font_rendering);
    renderer.setTextRenderingConfig(init.text_gamma, init.text_contrast, init.text_linear_correction);

    if (font_choice_changed or font_rendering_changed) {
        try renderer.setFontConfig(
            if (app_changed) next_app_path else null,
            if (!std.math.approxEqAbs(f32, renderer.base_font_size, init.app_font_size, 0.0001)) init.app_font_size else null,
            if (editor_changed) next_editor_path else null,
            if (!std.math.approxEqAbs(f32, renderer.editor_base_font_size, init.editor_font_size orelse renderer.base_font_size, 0.0001)) init.editor_font_size else null,
            if (terminal_changed) next_terminal_path else null,
            if (!std.math.approxEqAbs(f32, renderer.terminal_base_font_size, init.terminal_font_size orelse renderer.base_font_size, 0.0001)) init.terminal_font_size else null,
        );
    }

    return .{
        .font_choice_changed = font_choice_changed,
        .font_rendering_changed = font_rendering_changed,
        .text_rendering_changed = text_rendering_changed,
        .rebuilt_fonts = font_choice_changed or font_rendering_changed,
    };
}

test "buildRendererInitOptions keeps per-domain font ownership" {
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
    try std.testing.expectEqualStrings("app.ttf", init.app_font_path.?);
    try std.testing.expectEqualStrings("editor.ttf", init.editor_font_path.?);
    try std.testing.expectEqualStrings("terminal.ttf", init.terminal_font_path.?);
    try std.testing.expectApproxEqAbs(@as(f32, 14.0), init.app_font_size, 0.0001);
    try std.testing.expectApproxEqAbs(@as(f32, 15.0), init.editor_font_size.?, 0.0001);
    try std.testing.expectApproxEqAbs(@as(f32, 16.0), init.terminal_font_size.?, 0.0001);
}

test "buildRendererInitOptions falls back editor and terminal to app font" {
    const allocator = std.testing.allocator;
    var config = config_mod.emptyConfig();
    defer config_mod.freeConfig(allocator, &config);

    config.app_font_path = try allocator.dupe(u8, "app.ttf");
    config.app_font_size = 14.0;

    const init = buildRendererInitOptions(&config);
    try std.testing.expectEqualStrings("app.ttf", init.app_font_path.?);
    try std.testing.expectEqualStrings("app.ttf", init.editor_font_path.?);
    try std.testing.expectEqualStrings("app.ttf", init.terminal_font_path.?);
    try std.testing.expectApproxEqAbs(@as(f32, 14.0), init.app_font_size, 0.0001);
    try std.testing.expectApproxEqAbs(@as(f32, 14.0), init.editor_font_size.?, 0.0001);
    try std.testing.expectApproxEqAbs(@as(f32, 14.0), init.terminal_font_size.?, 0.0001);
}
