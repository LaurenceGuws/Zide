# Editor Theme Import

## Scope

Use real Neovim theme/cache artifacts to pressure-test and mature Zide's editor
theme schema.

Current status:

- theme-family expansion is paused for now
- current work should focus on cleanup, contract tightening, and preparing for
  future LSP-overlay integration
- do not add more theme breadth unless it is needed to answer a concrete
  contract/runtime question

Primary direction has now changed:

- source-level theme parsing is no longer the intended end-state architecture
- the long-term import path should come from Neovim's resolved highlight state,
  not from every theme author's internal source representation
- the existing source-parser lane remains useful as schema/runtime pressure-test
  work and as temporary manual-fixture generation, but not as the final
  universal import strategy

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
- Theme preview and imported-theme selection need to obey the same merged-config
  semantics as the rest of the config subsystem; previewing a theme must not
  silently drop local editor/app overrides.
- Imported theme registration must have one runtime authority. Theme families
  are growing too quickly for separate hardcoded name lists in tools, Lua, and
  Zig to stay coherent.
- The important long-term target is not "parse every theme repo source file"
  but "match the richness of Neovim's resolved theming output" across groups,
  Treesitter captures, links, and style metadata.
- Neovim theme source code is too implementation-specific to serve as a clean
  long-term import contract; the correct authority layer is the resolved
  highlight graph after Neovim has applied colorscheme logic.

## Constraints

- Keep the experiment grounded in real local Neovim cache artifacts, not
  invented theme examples.
- Treat imported themes as hostile input: record what maps cleanly and what does
  not.
- Prefer a small representative import set over broad one-off conversions.
- Evolve the schema only when a mismatch is real and recurring across themes.
- Reuse the existing import/tooling style where possible instead of inventing a
  separate theme stack.
- Do not mistake "resolved highlight richness" for "support every source-level
  theme implementation style". Those are different problems.
- Prefer normalized exported key/value theme state over source-parser growth
  whenever both could solve the same requirement.

## Architecture Pivot

The source-parser lane clarified the wrong abstraction:

- good outcome:
  - Zide now carries richer editor theme state well enough to render real
    Neovim-style groups, captures, links, and styles
  - imported-theme preview and config layering are materially healthier
- wrong assumption:
  - recursively supporting "all themes" by parsing theme source files is not a
    clean architecture target
  - theme source representations are too diverse and theme-author-specific

So the next architecture should be:

- Neovim resolves the theme
- a headless exporter captures the resolved highlight state
- Zide ingests that normalized exported state

That means the real import contract should be a resolved theme spec with:

- metadata:
  - colorscheme name
  - flavour/style/background
  - export profile/context
- `groups`
- `captures`
- `links`
- style flags
- color values:
  - `fg`
  - `bg`
  - `sp`

The current source-parser tooling should now be treated as:

- schema pressure-test work
- fixture generation
- exploration aid for exporter requirements

Not as:

- the final universal theme-import architecture

## Deferred Boundary

This queue is currently focused on editor/buffer theme quality and import
coverage, not a full IDE-wide theme split.

Direction is agreed, but deferred:

- Zide should eventually distinguish:
  - app chrome theme
  - editor/buffer theme
  - terminal theme
- Shared widgets should not implicitly read one global theme bucket forever.
- Shared widgets like `tab_bar` should eventually accept resolved style surfaces
  from the owning host/mode instead of assuming one flat theme source.

What this means right now:

- keep improving the editor/buffer theme surface and Neovim import quality
- do not let editor-theme work silently redefine the main IDE chrome model
- only borrow editor theme values into chrome intentionally
- defer the actual shared-widget and cross-surface split until the editor theme
  surface is stable enough to serve as a real authority

Likely first proving cut later:

- `tab_bar` should become a shared widget that accepts caller-provided theme
  tokens from editor, terminal, or app-chrome hosts instead of hardcoding one
  global theme assumption

## Initial Worklist

- [ ] `ED-THEME-NEW-01` Define the resolved-theme export contract
  - Write the normalized key/value spec Zide actually wants from Neovim after
    colorscheme resolution.
  - Keep it focused on:
    - editor UI groups
    - classic syntax groups
    - Treesitter captures
    - links
    - style flags
    - `fg` / `bg` / `sp`
  - Record explicit export context:
    - colorscheme/flavour/background
    - loaded parser/filetype scope
    - plugin/runtime scope if included
  - Current state:
    - authority:
      - `app_architecture/editor/RESOLVED_THEME_EXPORT_CONTRACT.md`
    - deferred LSP boundary/example:
      - `app_architecture/editor/LSP_THEME_OVERLAY_BOUNDARY.md`
    - current import-authority candidate:
      - `aggregate`
    - current result:
      - base contract is viable for `groups`, `captures`, `links`, and the
        core color/style keys
      - `@lsp.*` stays out of the base artifact contract

- [ ] `ED-THEME-NEW-02` Build a headless Neovim exporter prototype
  - Load a colorscheme in headless Neovim.
  - Export the resolved highlight graph instead of parsing source files.
  - Prove the exporter can emit one normalized artifact for a live theme.
  - Current state:
    - prototype:
      - `tools/editor/theme/nvim_resolved_theme_export.lua`
      - `tools/editor/theme/editor_theme_resolved_baseline.sh`
    - current preset workflow:
      - `nvim --headless "+lua dofile('tools/editor/theme/nvim_resolved_theme_export.lua')"`
      - `-- --colorscheme tokyonight-night --profile treesitter --preset zide-core`
      - or:
        `tools/editor/theme/editor_theme_resolved_baseline.sh tokyonight-night`
      - baseline helper also cleans older legacy `*-resolved` registry/file
        clutter for the same colorscheme when it can
    - current artifact shape:
      - top-level `metadata`, `base`, `contexts`, `aggregate`
    - current preset:
      - `zide-core`
    - current caveats:
      - preset coverage is still repo-local
      - `treesitter_error` is best-effort per context
      - no active semantic-token/LSP export lane is part of base work
      - raw `aggregate` still includes substantial plugin/runtime group noise

- [ ] `ED-THEME-NEW-03` Compare exported resolved state against Zide schema
  - Use the exported artifact as the actual authority.
  - Record what still maps cleanly, what is lossy, and what Zide still lacks.
  - Prefer schema fixes only for recurring resolved-state mismatches.
  - Current state:
    - comparison tool:
      - `tools/editor/theme/nvim_resolved_theme_compare.py`
    - useful modes:
      - full report
      - `--exclude-lsp`
      - `--summary`
    - current signals:
      - with LSP included, the current preset reaches `21/21` coarse syntax
        slots on `tokyonight-night`
      - with `--exclude-lsp`, the same export drops to `18/21`
      - recurring base-only weak spots in the current sample set are
        `escape`, `function_method`, and `type_builtin`
      - recurring unsupported style signal is currently `underdouble`

- [ ] `ED-THEME-NEW-06` Bridge resolved export into Zide overlay shape
  - Add a narrow adapter from resolved export JSON into the existing Zide
    `editor.theme.groups/captures/links` Lua overlay shape.
  - Keep base ingestion scoped to non-LSP names.
  - Current state:
    - adapter path now exists in:
      - `tools/editor/theme/editor_theme_import.py --resolved-export <artifact.json>`
    - current behavior:
      - reads `aggregate`
      - renders the existing overlay Lua shape
      - drops `@lsp.*` names from base ingestion
      - default prune policy is:
        `--resolved-prune editor-surface`
      - `--register` writes the generated overlay into
        `assets/themes/init.lua` so runtime imported-theme discovery stays on
        the existing Lua registry authority
      - baseline helper:
        `tools/editor/theme/editor_theme_resolved_baseline.sh <colorscheme>`
      - explicit cleanup:
        `python3 tools/editor/theme/editor_theme_import.py --remove-generated <resolved-name>`
    - current caveat:
      - pruning is still heuristic and should remain explicit
      - `editor-surface` is the current default and recommended reviewable
        bridge mode

- [ ] `ED-THEME-NEW-05` Cleanup and consolidation pass
  - Keep theme breadth paused until the editor/LSP integration lane is ready.
  - Clean docs so the current authority is obvious:
    - resolved-theme base contract
    - LSP overlay boundary/example contract
    - exporter prototype
    - comparison workflow
    - deferred LSP overlay policy
  - Clean tooling so maintenance workflows are clearer than exploration
    workflows.
  - Avoid adding new supported themes unless they are needed to validate a
    concrete unresolved runtime/style question.

- [ ] `ED-THEME-NEW-04` Reframe the current source-parser tooling
  - Keep `tools/editor/theme/editor_theme_import.py` as:
    - schema pressure-test tooling
    - manual fixture generation
    - generic intake/audit research
  - Stop treating it as the main path to "full Neovim theme support".

## Archived Context

Older source-parser expansion work, generated-overlay history, and broad
theme-family intake notes are now historical context rather than active queue
authority.

Keep using them only as supporting reference when needed:

- source-parser research/tooling:
  - `tools/editor/theme/editor_theme_import.py`
- current resolved-theme base authority:
  - `app_architecture/editor/RESOLVED_THEME_EXPORT_CONTRACT.md`
- deferred LSP overlay/example boundary:
  - `app_architecture/editor/LSP_THEME_OVERLAY_BOUNDARY.md`
- current editor theme/config authority:
  - `app_architecture/CONFIG.md`
  - `assets/config/theme_reference.lua`

Do not treat the old source-parser breadth work as the current architecture
target.
