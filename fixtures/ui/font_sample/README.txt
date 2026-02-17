Font sample reference captures (not “goldens” yet).

These images come from the built-in font sample mode:

  zig build run -- --mode font-sample

They are intended to catch obvious regressions while we redesign the font
pipeline (atlas formats, blending, gamma handling, hinting, etc.).

Deterministic fixture compare (sizes 12/14/16/20):

  tools/font_sample_compare.sh

Refresh fixtures explicitly (opt-in):

  tools/font_sample_compare.sh --update-fixtures

Artifacts are written to:

  zig-cache/font_sample_compare/

The compare script pins window size to each fixture's PPM dimensions via:
- `ZIDE_WINDOW_WIDTH`
- `ZIDE_WINDOW_HEIGHT`
- `ZIDE_FONT_SAMPLE_SCREENSHOT_WIDTH`
- `ZIDE_FONT_SAMPLE_SCREENSHOT_HEIGHT`

LCD experiment captures (does not update fixtures):

  tools/font_sample_capture_lcd.sh

Artifacts are written to:

  zig-cache/font_sample_lcd/

Initial LCD sweep note (2026-02-17):
- Captured sizes 12/14/16/20 with `tools/font_sample_capture_lcd.sh`.
- All LCD captures differ from default fixture captures (expected for this experiment path).

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

Ligature coverage in font-sample lines includes:
- ->  ~>  =>  ==  ===  !=  !==  <=  >=  <=>
- mixed operator chains (for run-splitting regressions)

Cursor-over ligature checks (terminal mode):

  zig build run -- --mode terminal

In .zide.lua, test these strategies:
- terminal.disable_ligatures = "never"
- terminal.disable_ligatures = "cursor"
- terminal.disable_ligatures = "always"

Then type/sample a ligature-heavy line (for example: `-> ~> => === != <= >=`)
and move the cursor through each symbol pair to validate cursor-split behavior.

Editor ligature regression captures (recommended matrix):

1) Default ligatures:
   - editor.disable_ligatures = "never"
   - editor.font_features unset

2) Explicit programming-ligature off:
   - editor.font_features = "-calt"

3) Cursor strategy:
   - editor.disable_ligatures = "cursor"

For each mode, capture:

  ZIDE_FONT_SAMPLE_FRAMES=2 \
  ZIDE_FONT_SAMPLE_SCREENSHOT=fixtures/ui/font_sample/editor_ligature_<mode>.ppm \
  zig build run -- --mode font-sample

Suggested filenames:
- editor_ligature_default.ppm
- editor_ligature_no_calt.ppm
- editor_ligature_cursor.ppm

Troubleshooting mismatches:
- Run font-sample commands serially; avoid launching multiple font-sample runs at once.
- Ensure font files exist and are the expected ones:
  - assets/fonts/JetBrainsMonoNerdFont-Regular.ttf
  - assets/fonts/IosevkaTermNerdFont-Regular.ttf
- Check for config/env overrides that affect rendering:
  - `.zide.lua` and user config `init.lua`
  - `ZIDE_FONT_RENDERING_LCD`, `ZIDE_FONT_SAMPLE_SIZE`, `ZIDE_FONT_SAMPLE_FRAMES`
  - `ZIDE_WINDOW_WIDTH`, `ZIDE_WINDOW_HEIGHT`
- Use generated artifacts for inspection:
  - default compare: `zig-cache/font_sample_compare/`
  - LCD experiment: `zig-cache/font_sample_lcd/`
