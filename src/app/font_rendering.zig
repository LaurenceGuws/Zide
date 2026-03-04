const app_bootstrap = @import("bootstrap.zig");
const config_mod = @import("../config/lua_config.zig");
const terminal_font_mod = @import("../ui/terminal_font.zig");
const app_shell = @import("../app_shell.zig");

const Shell = app_shell.Shell;

fn buildFontRenderingOptions(config: *const config_mod.Config) terminal_font_mod.RenderingOptions {
    var font_opts: terminal_font_mod.RenderingOptions = .{};
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

pub fn applyRendererFontRenderingConfig(shell: *Shell, config: *const config_mod.Config, rebuild_fonts: bool) !void {
    const renderer = shell.rendererPtr();
    renderer.setFontRenderingOptions(buildFontRenderingOptions(config));
    renderer.setTextRenderingConfig(config.text_gamma, config.text_contrast, config.text_linear_correction);
    if (rebuild_fonts) {
        try renderer.setFontConfig(null, null);
    }
}
