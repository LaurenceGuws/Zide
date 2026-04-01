const types = @import("../model/types.zig");
const parser_csi = @import("../parser/csi.zig");
const input_modes = @import("../core/input_modes.zig");
const terminal_publication = @import("../core/publication/terminal_publication.zig");
const terminal_core_protocol = @import("../core/protocol/terminal_core_protocol.zig");
const app_logger = @import("../../app_logger.zig");

const Color = types.Color;

pub fn applyDecstrReset(self: anytype) void {
    self.core.resetParserState();
    self.core.clearSavedCharsetState();
    self.core.clearTitleBuffer();
    self.core.setDefaultTitle();
    self.interaction.report_color_scheme_2031 = false;
    self.interaction.grapheme_cluster_shaping_2027 = false;
    self.core.primary.setGraphemeClusterShaping2027(false);
    self.core.alt.setGraphemeClusterShaping2027(false);
    self.interaction.inband_resize_notifications_2048 = false;
    self.interaction.kitty_paste_events_5522 = false;
    input_modes.resetInputModesLocked(self);
    self.core.column_mode_132 = false;
    terminal_publication.setSyncUpdatesLocked(self, false);
    terminal_core_protocol.clearAllKittyImages(self);
    self.core.activeScreen().resetState();
    input_modes.publishSnapshot(self);
    self.core.activeScreen().markDirtyAllWithReason(.decstr_soft_reset, @src());
}

pub fn applySgr(self: anytype, action: parser_csi.CsiAction, effective_sgr_param_count: *const fn (action: parser_csi.CsiAction) usize) void {
    const params = action.params;
    const n_params = effective_sgr_param_count(action);
    const screen = self.core.activeScreen();
    const current_attrs = &screen.current_attrs;
    const default_attrs = &screen.default_attrs;
    const log = app_logger.logger("terminal.sgr");
    log.logf(.debug, "sgr count={d} params={d},{d},{d},{d},{d},{d},{d},{d},{d},{d},{d},{d},{d},{d},{d},{d}", .{
        n_params, params[0], params[1], params[2], params[3], params[4], params[5], params[6], params[7], params[8], params[9], params[10], params[11], params[12], params[13], params[14], params[15],
    });
    var i: usize = 0;
    while (i < n_params) {
        const p = params[i];
        if (p == 38 or p == 48 or p == 58) {
            if (i + 1 < n_params) {
                const mode = params[i + 1];
                if (mode == 5 and i + 2 < n_params) {
                    const idx = types.clampColorIndex(params[i + 2]);
                    const color = terminal_core_protocol.paletteColor(self, idx);
                    switch (p) {
                        38 => current_attrs.fg = color,
                        48 => current_attrs.bg = color,
                        58 => current_attrs.underline_color = color,
                        else => {},
                    }
                    i += 3;
                    continue;
                }
                if (mode == 2) {
                    const base: usize = i + 2;
                    if (base + 2 < n_params) {
                        const r = types.clampColorIndex(params[base]);
                        const g = types.clampColorIndex(params[base + 1]);
                        const b = types.clampColorIndex(params[base + 2]);
                        const color = Color{ .r = r, .g = g, .b = b, .a = 255 };
                        switch (p) {
                            38 => current_attrs.fg = color,
                            48 => current_attrs.bg = color,
                            58 => current_attrs.underline_color = color,
                            else => {},
                        }
                        i = base + 3;
                        continue;
                    }
                }
                if (mode == 6) {
                    const base: usize = i + 2;
                    if (base + 3 < n_params) {
                        const r = types.clampColorIndex(params[base]);
                        const g = types.clampColorIndex(params[base + 1]);
                        const b = types.clampColorIndex(params[base + 2]);
                        const a = types.clampColorIndex(params[base + 3]);
                        const color = Color{ .r = r, .g = g, .b = b, .a = a };
                        switch (p) {
                            38 => current_attrs.fg = color,
                            48 => current_attrs.bg = color,
                            58 => current_attrs.underline_color = color,
                            else => {},
                        }
                        i = base + 4;
                        continue;
                    }
                }
            }
            i += 1;
            continue;
        }
        switch (p) {
            0 => current_attrs.* = default_attrs.*,
            1 => current_attrs.bold = true,
            5 => {
                current_attrs.blink = true;
                current_attrs.blink_fast = false;
            },
            6 => {
                current_attrs.blink = true;
                current_attrs.blink_fast = true;
            },
            22 => current_attrs.bold = false,
            25 => {
                current_attrs.blink = false;
                current_attrs.blink_fast = false;
            },
            4 => current_attrs.underline = true,
            24 => current_attrs.underline = false,
            7 => current_attrs.reverse = true,
            27 => current_attrs.reverse = false,
            39 => current_attrs.fg = default_attrs.fg,
            49 => current_attrs.bg = default_attrs.bg,
            59 => current_attrs.underline_color = default_attrs.underline_color,
            30...37 => current_attrs.fg = terminal_core_protocol.paletteColor(self, @intCast(p - 30)),
            40...47 => current_attrs.bg = terminal_core_protocol.paletteColor(self, @intCast(p - 40)),
            90...97 => current_attrs.fg = terminal_core_protocol.paletteColor(self, @intCast(8 + (p - 90))),
            100...107 => current_attrs.bg = terminal_core_protocol.paletteColor(self, @intCast(8 + (p - 100))),
            else => {},
        }
        i += 1;
    }
}
