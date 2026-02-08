Font sample reference captures (not “goldens” yet).

These images come from the built-in font sample mode:

  zig build run -- --mode font-sample

They are intended to catch obvious regressions while we redesign the font
pipeline (atlas formats, blending, gamma handling, hinting, etc.).

Capture command (example):

  ZIDE_TEXT_GAMMA=1.0 ZIDE_TEXT_CONTRAST=1.0 \
  ZIDE_FONT_SAMPLE_SIZE=16 ZIDE_FONT_SAMPLE_FRAMES=2 \
  ZIDE_FONT_SAMPLE_SCREENSHOT=fixtures/ui/font_sample/jbmono_iosevka_size16.ppm \
  zig build run -- --mode font-sample

Font columns in the view are fixed to:
- JetBrainsMonoNerdFont-Regular.ttf
- IosevkaTermNerdFont-Regular.ttf

Current captures:
- jbmono_iosevka_size12.ppm
- jbmono_iosevka_size14.ppm
- jbmono_iosevka_size16.ppm
- jbmono_iosevka_size20.ppm

Each capture includes multiple background bands to exercise background-aware
correction:
- normal background
- selection background
- cursor (inverted) background
