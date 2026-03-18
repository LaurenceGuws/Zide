# Editor Theme Import

## Scope

Use real Neovim theme/cache artifacts to pressure-test and mature Zide's editor
theme schema.

This queue owns:

- importing editor themes from external sources beyond terminal palette files
- validating Zide's theme schema against real Neovim highlight data
- documenting schema gaps, lossy mappings, and recurring conversion heuristics
- producing a small local library of converted editor themes for manual testing

This queue does not own:

- terminal-only palette import work already covered by existing Kitty/Ghostty
  tooling
- syntax/highlight query authoring except where import gaps expose schema issues
- optimization-led editor work

## Why This Matters

- Real Neovim themes are a better stress test than hand-authored Zide themes.
- Import pressure should expose where our palette/group/capture/link schema is
  too weak, too awkward, or too ad hoc.
- A conversion lane gives us repeatable editor-theme fixtures instead of
  abstract schema debates.
- This should improve both editor theming quality and config ergonomics.

## Constraints

- Keep the experiment grounded in real local Neovim cache artifacts, not
  invented theme examples.
- Treat imported themes as hostile input: record what maps cleanly and what does
  not.
- Prefer a small representative import set over broad one-off conversions.
- Evolve the schema only when a mismatch is real and recurring across themes.
- Reuse the existing import/tooling style where possible instead of inventing a
  separate theme stack.

## Initial Worklist

- [ ] `ED-THEME-01` Audit local Neovim theme/cache sources
  - Identify the actual theme/cache artifacts available locally.
  - Choose 2-3 representative themes with different highlight styles.
  - Record which artifact shape is the best importer input source.
  - Progress:
    - Local Neovim persistence currently records the active theme in
      `~/.local/share/nvim/theme.lua`; current value is `ayu`.
    - Local lazy-installed theme sources are available under
      `~/.local/share/nvim/lazy/` and already include good first-pass targets:
      `neovim-ayu`, `tokyonight.nvim`, `kanagawa-dragon`, `catppuccin`,
      `onedark.nvim`, `onedarkpro.nvim`, `rose-pine`, and others.
    - The cleanest importer inputs are theme-native Lua group/palette sources,
      not generated cache dumps:
      - Tokyo Night:
        - `~/.local/share/nvim/lazy/tokyonight.nvim/colors/tokyonight-*.lua`
        - `~/.local/share/nvim/lazy/tokyonight.nvim/lua/tokyonight/groups/*.lua`
      - Kanagawa:
        - `~/.local/share/nvim/lazy/kanagawa-dragon/lua/kanagawa/colors.lua`
        - `~/.local/share/nvim/lazy/kanagawa-dragon/lua/kanagawa/highlights/*.lua`
      - Catppuccin:
        - `~/.local/share/nvim/lazy/catppuccin/lua/catppuccin/palettes/*.lua`
        - `~/.local/share/nvim/lazy/catppuccin/lua/catppuccin/groups/*.lua`
      - Ayu:
        - `~/.local/share/nvim/lazy/neovim-ayu/lua/ayu/colors.lua`
        - `~/.local/share/nvim/lazy/neovim-ayu/colors/ayu-*.lua`
    - First shortlist for import pressure:
      - `tokyonight-night`
        - Best first implementation target.
        - Clean Lua palette/group structure.
        - Already aligned with Zide defaults, so mismatches will be easy to see.
      - `ayu`
        - Worth importing early because it is the currently persisted local
          theme and should reflect real user workflow, not just a synthetic test
          theme.
      - `kanagawa-dragon`
        - Good higher-complexity target because it has explicit editor,
          Treesitter, syntax, and plugin highlight layers.
      - `catppuccin-mocha`
        - Good follow-up stress target because it separates palettes, editor
          groups, Treesitter groups, semantic tokens, and multiple flavour
          variants.
    - Recommendation:
      - Use `tokyonight-night` for `ED-THEME-03`.
      - Keep `ayu` and `kanagawa-dragon` as the next two pressure-test imports.

- [ ] `ED-THEME-02` Define importer target against current Zide schema
  - Map Neovim palette, highlight groups, Treesitter captures, and links into
    Zide's current theme model.
  - Explicitly note what is lossless, lossy, or unsupported.
  - Keep the first cut narrow and reviewable.
  - Progress:
    - Zide already has one shared theme schema, not separate terminal/editor
      models:
      - global/app/editor/terminal all share `theme.palette`
      - editor additionally supports `theme.syntax`, named `groups`,
        tree-sitter `captures`, and explicit `links`
    - Current authority for that shape is:
      - `assets/config/theme_reference.lua`
      - `app_architecture/CONFIG.md`
      - `src/config/lua_config_theme_parse.zig`
    - Import target for Neovim-derived editor themes should therefore be:
      - shared palette fields where the concept overlaps
      - editor `syntax` for common token buckets
      - editor `groups` for named Neovim highlight groups
      - editor `captures` for Treesitter capture mappings
      - editor `links` for group/capture link chains
    - First-pass mapping policy:
      - `Normal`, `NormalFloat`, `StatusLine`, `TabLine*`, `LineNr`,
        `CursorLine`, `Visual`, `Search`, `IncSearch`, `ErrorMsg`,
        `WarningMsg`, `Diagnostic*`:
        - map into shared/app/editor palette where Zide already has a true
          semantic slot
        - keep the original named group in `editor.theme.groups` as authority
          for anything more specific
      - classic syntax groups like `Comment`, `String`, `Keyword`, `Number`,
        `Function`, `Identifier`, `Type`, `Operator`, `Constant`, `Special`,
        `PreProc`, `Delimiter`, `Label`, `Error`:
        - map into `editor.theme.syntax` when the bucket exists
        - also preserve the original group name in `editor.theme.groups`
      - Treesitter captures like `@comment`, `@keyword.control`,
        `@function.method`, `@string.special.url`, `@markup.link.url`:
        - map into `editor.theme.captures`
      - explicit Neovim highlight links:
        - preserve as `editor.theme.links`
    - First-pass loss model:
      - Lossless enough:
        - foreground/background colors
        - direct group colors
        - Treesitter capture colors
        - group/capture links
      - Partially supported / lossy:
        - bold / italic / underline / undercurl / strikethrough
        - blend / nocombine / reverse / standout
        - special underline colors (`sp`)
        - semantic-token-only distinctions when Zide lacks a stable bucket
      - Out of scope for the first cut:
        - plugin-specific highlight ecosystems
        - statusline/bufferline-specific component theme exports
        - terminal palette extras that are already better served by the
          existing Kitty/Ghostty import path
    - Cross-IDE direction:
      - This importer should stay shaped like a general IDE theme ingest path,
        not a Neovim-only one-off.
      - If we keep the importer target centered on shared palette + editor
        groups/captures/links, later importers for VS Code or other IDEs can
        reuse the same target model.

- [ ] `ED-THEME-03` Land one end-to-end Neovim theme import
  - Convert one real theme from the local cache.
  - Produce a Zide theme artifact that can be loaded without extra glue.
  - Use it to identify the first concrete schema gaps.
  - Progress:
    - Landed the first concrete converted theme artifact:
      - `assets/themes/tokyonight-night.lua`
    - Landed the second concrete converted theme artifact:
      - `assets/themes/ayu.lua`
    - Landed the third concrete converted theme artifact:
      - `assets/themes/kanagawa-dragon.lua`
    - Added a shared imported-theme loader:
      - `assets/themes/init.lua`
      - local config can now switch imported themes by name instead of editing
        raw `dofile(...)` paths
    - Local project config is now pointed at imported theme name
      `kanagawa-dragon` for the next schema-pressure pass.
    - This first cut intentionally targets the existing shared Zide schema:
      - shared `theme.palette`
      - shared `theme.syntax`
      - `editor.theme.palette`
      - `editor.theme.syntax`
      - `editor.theme.groups`
      - `editor.theme.captures`
      - `editor.theme.links`
    - Source authority for this first import:
      - `~/.local/share/nvim/lazy/tokyonight.nvim/extras/lua/tokyonight_night.lua`
      - `~/.local/share/nvim/lazy/tokyonight.nvim/lua/tokyonight/groups/*.lua`
    - First-cut limitations:
      - style metadata is now preserved through config/theme loading for the
        main syntax buckets, but rendering still does not consume it yet
      - only a representative subset of groups/captures is imported, not the
        full Tokyo Night surface
      - this is enough to validate the artifact shape and the schema fit before
        building a proper importer

- [ ] `ED-THEME-04` Tighten schema and importer heuristics
  - Fix recurring issues in groups, capture links, semantic aliases, and palette
    fallback.
  - Document the schema changes in the owning architecture docs.
  - Progress:
    - After importing `tokyonight-night`, `ayu`, and `kanagawa-dragon`, the
      recurring schema gaps are now concrete instead of theoretical.
    - Cleanly supported today:
      - fg/bg color mapping
      - palette overlap for editor/app/UI surfaces
      - named group colors
      - Treesitter capture colors
      - explicit group/capture link chains
    - Recurrently lossy across all three imported themes:
      - `italic`
      - `bold`
      - `underline`
      - `undercurl`
      - `strikethrough`
      - special underline color via `sp`
      - `reverse`
      - `nocombine`
    - Practical conclusion:
      - the first schema-tightening cut should preserve editor highlight style
        metadata through config/theme parsing and merging
      - the first runtime cut should consume the low-cost decoration subset:
        underline / strikethrough / special underline color
      - the next runtime cut should render a basic undercurl approximation
      - the next runtime cut after that should render italic via synthetic
        glyph slant at raster/cache time instead of a fake paint-layer trick
      - after that, the next gap is the remaining Neovim semantics
    - Current importer policy should therefore remain:
      - keep landing real Neovim theme artifacts
      - record style loss honestly
      - do not invent fake color-only substitutes for style semantics that
        should instead be modeled properly
    - Current artifact tightening progress:
      - `tokyonight-night`, `ayu`, and `kanagawa-dragon` now carry a
        representative first-pass subset of real style metadata instead of
        remaining almost entirely color-only.
      - That subset currently includes:
        - italic comments / keywords where the source theme uses them
        - bold statement or boolean groups where the source theme uses them
        - diagnostic undercurl groups with `sp` colors
        - a small markdown style subset for Tokyo Night captures
      - This is still intentionally selective:
        - base/editor/high-signal groups first
        - no plugin-noise bulk import yet
        - enough to make the runtime/style pipeline honest under manual checks

- [ ] `ED-THEME-05` Build a small converted-theme library
  - Keep a compact set of imported editor themes for manual regression checks.
  - Use this set as an editor-theme health check when evolving theming logic.
  - Progress:
    - Added [fixtures/editor/theme_style_fixture.md](/home/home/personal/zide/fixtures/editor/theme_style_fixture.md)
      as the stable manual visual target for imported style semantics.
    - Use it with the imported themes to check:
      - italic
      - bold
      - underline / undercurl-adjacent decoration
      - strikethrough
      - links
      - mixed markdown and code spans
    - Added a small built-in preview surface for the shipped imported themes:
      - `View -> Next Imported Theme`
      - `View -> Previous Imported Theme`
      - `Ctrl+Alt+]` / `Ctrl+Alt+[`
      - this cycles `ayu`, `kanagawa-dragon`, and `tokyonight-night`
      - it is intentionally transient session state, not a config-file rewrite
      - the status bar now also shows the active imported theme name during the
        session

## Current Implementation Context

- Existing shared palette import helper:
  - `assets/config/theme_import.lua`
- Current default config/theme authority:
  - `assets/config/init.lua`
  - `assets/config/theme_reference.lua`
- Config/schema wiring:
  - `src/config/lua_config_iface.zig`
  - `src/config/lua_config_ziglua_parse.zig`
  - `src/config/lua_config_shared.zig`
- Editor highlight/theme consumers:
  - `src/editor/search_highlight.zig`
  - `src/editor/syntax.zig`

## Expected Outputs

- one importer path for Neovim-derived editor themes
- one or more converted theme artifacts usable by Zide
- explicit notes on schema pressure and required follow-up changes

## Notes

- This is a schema health exercise, not just a theme-conversion convenience
  task.
- Keep terminal palette import and editor theme import aligned where the shared
  model genuinely overlaps, but do not force terminal-shaped constraints onto
  editor semantics.
- Current highest-value schema gap for "proper Neovim import" is editor style
  metadata, not more palette work.
