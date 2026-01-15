#include "vterm.h"

typedef struct {
    uint32_t codepoint;
    uint8_t width;
    uint8_t bold;
    uint8_t italic;
    uint8_t underline;
    uint8_t blink;
    uint8_t reverse;
    uint8_t strike;
    uint8_t fg_r;
    uint8_t fg_g;
    uint8_t fg_b;
    uint8_t bg_r;
    uint8_t bg_g;
    uint8_t bg_b;
} ZideVTermCell;

int zide_vterm_get_cell(VTermScreen *screen, int row, int col, ZideVTermCell *out) {
    if (!screen || !out) {
        return 0;
    }

    VTermScreenCell cell;
    VTermPos pos = { .row = row, .col = col };
    if (!vterm_screen_get_cell(screen, pos, &cell)) {
        return 0;
    }

    VTermColor fg = cell.fg;
    VTermColor bg = cell.bg;
    vterm_screen_convert_color_to_rgb(screen, &fg);
    vterm_screen_convert_color_to_rgb(screen, &bg);

    out->codepoint = cell.chars[0];
    out->width = (uint8_t)cell.width;
    out->bold = cell.attrs.bold ? 1 : 0;
    out->italic = cell.attrs.italic ? 1 : 0;
    out->underline = cell.attrs.underline ? 1 : 0;
    out->blink = cell.attrs.blink ? 1 : 0;
    out->reverse = cell.attrs.reverse ? 1 : 0;
    out->strike = cell.attrs.strike ? 1 : 0;
    out->fg_r = fg.rgb.red;
    out->fg_g = fg.rgb.green;
    out->fg_b = fg.rgb.blue;
    out->bg_r = bg.rgb.red;
    out->bg_g = bg.rgb.green;
    out->bg_b = bg.rgb.blue;

    return 1;
}
