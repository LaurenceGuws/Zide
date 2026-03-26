# Resolved Theme Export Contract

This document defines the current contract for exporting a Neovim-resolved
editor theme artifact for Zide.

It is intentionally scoped to the resolved runtime highlight graph, not to
Neovim theme source files.

## Goal

Use Neovim as the authority for colorscheme resolution, then export a
normalized artifact that Zide can inspect, compare, and eventually ingest
without inheriting arbitrary theme-source implementation details.

The contract is designed around what Neovim has already resolved:

- named highlight groups
- Treesitter capture names
- explicit links
- style flags
- resolved color values

## Current Focus

- keep the base resolved-theme contract stable and reviewable
- keep theme breadth expansion paused unless it answers a concrete unresolved
  contract or runtime question
- prepare the next lane around LSP/semantic-token overlay integration without
  forcing that policy into the base theme contract early

## Non-goals

- Parsing every theme repo's source representation
- Treating one startup-only colorscheme snapshot as universal truth
- Flattening semantic-token/LSP overlays into the base theme layer

## Authority

Current prototype exporter:

- `tools/editor/theme/nvim_resolved_theme_export.lua`

Current comparison probe:

- `tools/editor/theme/nvim_resolved_theme_compare.py`

Current queue owner:

- `docs/todo/editor/theme_import.md`

Current authority for editor-level entrypoints:

- `app_architecture/editor/DESIGN.md`

## Maintenance Check

Default maintenance workflow:

```sh
nvim --headless "+lua dofile('tools/editor/theme/nvim_resolved_theme_export.lua')" -- \
  --colorscheme tokyonight-night \
  --profile treesitter \
  --preset zide-core \
  --out /tmp/tokyonight-preset.json

python3 tools/editor/theme/nvim_resolved_theme_compare.py --summary /tmp/tokyonight-preset.json
```

This is the preferred quick check when validating the current base contract.

One-command baseline workflow:

```sh
tools/editor/theme/editor_theme_resolved_baseline.sh tokyonight-night
```

That command runs export, summary compare, and resolved-overlay apply/register
using the current default bridge policy.
It also cleans an older legacy resolved registration for the same colorscheme
name shape if one exists, so reruns do not keep stacking throwaway resolved
fixtures in the runtime registry.

Explicit cleanup command:

```sh
python3 tools/editor/theme/editor_theme_import.py --remove-generated tokyonight-night-resolved
```

## First Bridge

Current first bridge from resolved export into Zide's existing Lua overlay
shape:

```sh
python3 tools/editor/theme/editor_theme_import.py \
  --resolved-export /tmp/tokyonight-preset.json \
  --resolved-name tokyonight-resolved \
  --apply \
  --register
```

Current behavior:

- reads `aggregate`
- renders the existing `editor.theme.groups/captures/links` Lua overlay shape
- ignores `@lsp.*` names for base ingestion
- current recommended prune policy:
  - `editor-surface`
  - this is now the default resolved-export bridge mode
  - keeps high-signal editor UI, classic syntax groups, and core capture
    families
  - avoids shipping the full raw plugin/runtime group surface by default
- with `--register`, adds the generated overlay to `assets/themes/init.lua` so
  runtime theme discovery keeps using the same Lua registry authority as the
  mature imported-theme path

Current caveat:

- pruning policy is still heuristic and should remain explicit at the CLI level
- it is a reviewability/tooling cut, not a frozen semantic contract

## Export Model

The artifact is JSON with this top-level shape:

```json
{
  "metadata": { "...": "..." },
  "base": { "...": "..." },
  "contexts": [ { "...": "..." } ],
  "aggregate": { "...": "..." }
}
```

### Top-level `metadata`

Current fields:

- `colorscheme`
- `background`
- `profile`
- `nvim_version`
- `context_count`
- `preset`

Meaning:

- `colorscheme`: resolved Neovim colorscheme name
- `background`: active `vim.o.background`
- `profile`: export mode such as `base` or `treesitter`
- `nvim_version`: Neovim runtime version metadata
- `context_count`: number of named context snapshots in `contexts`
- `preset`: optional exporter preset name if one was used

### Snapshot sections

`base`, each item in `contexts`, and `aggregate` are all snapshot sections with
the same shape:

```json
{
  "metadata": { "...": "..." },
  "groups": { "...": { "...": "..." } },
  "captures": { "...": { "...": "..." } },
  "links": { "...": "..." },
  "counts": { "groups": 0, "captures": 0, "links": 0 }
}
```

#### Snapshot `metadata`

Current fields:

- `colorscheme`
- `background`
- `profile`
- `nvim_version`
- `file`
- `filetype`
- `name`
- `treesitter_error`

Notes:

- `file` and `filetype` are populated when the snapshot came from a file-backed
  context.
- `name` is populated for named entries in `contexts`.
- `treesitter_error` is optional and records a context-local parser startup
  failure without aborting the whole export.

#### `groups`

Named non-capture highlight groups keyed by Neovim group name.

Example keys:

- `Normal`
- `Comment`
- `CursorLine`
- `DiagnosticUnderlineError`

#### `captures`

Named Treesitter-style capture entries keyed by Neovim capture name.

Example keys:

- `@comment`
- `@keyword.control`
- `@function.method`

#### `links`

Explicit resolved links keyed by source highlight name with the link target as
 the value.

Example:

```json
{
  "@comment": "Comment",
  "@function.call": "@function",
  "Function": "Identifier"
}
```

#### `counts`

Quick summary counts for the snapshot:

- `groups`
- `captures`
- `links`

These are convenience fields for audits and comparison output. They are not
theme semantics.

## Entry Value Shape

Entries inside `groups` and `captures` use a narrow normalized key/value shape.

Supported resolved keys today:

- `fg`
- `bg`
- `sp`
- `bold`
- `italic`
- `underline`
- `undercurl`
- `strikethrough`
- `reverse`
- `nocombine`

Current exporter also passes through some Neovim-resolved style keys that Zide
does not yet treat as supported runtime semantics:

- `underdouble`
- `underdotted`
- `underdashed`
- `standout`

Colors are exported as `#RRGGBB`.

If a resolved entry is a pure link, it is represented in `links` instead of as
an inline `{ "link": ... }` payload inside `groups` or `captures`.

## Profiles

### `base`

Startup colorscheme state only.

This is useful for:

- editor UI groups
- generic colorscheme sanity checks
- minimal importer prototyping

It is not enough to represent the full language-aware runtime highlight graph.

### `treesitter`

Opens file-backed contexts, sets filetype, and attempts to start Treesitter
before export.

This is currently the preferred profile for editor-theme comparison work.

## Context Semantics

### `base`

The `base` snapshot is the startup-state baseline for the selected colorscheme
and profile before named context expansion.

### `contexts`

Each named context is a file-backed runtime probe with its own metadata and
resolved snapshot.

Current CLI forms:

- `--file <path> --filetype <ft>`
- `--context <name>:<filetype>:<path>`
- `--preset <name>`

### `aggregate`

`aggregate` is the union of:

- `base`
- every snapshot in `contexts`

This is currently the best candidate for the first Zide-side import authority
because it captures more realistic highlight richness than a startup-only
snapshot without pretending any single filetype context is universal.

Current policy:

- later context entries may contribute additional groups, captures, and links
- `aggregate` is a coverage-oriented union artifact, not provenance-preserving
  source data

If provenance becomes necessary later, the source of truth remains `contexts`,
not `aggregate`.

## Current Preset

Current built-in preset:

- `zide-core`

Current entries:

- `zig:zig:src/main.zig`
- `lua:lua:assets/themes/init.lua`
- `markdown:markdown:docs/todo/editor/theme_import.md`
- `vimdoc:help:reference_repos/editors/neovim/runtime/doc/treesitter.txt`

This preset is repo-local and pragmatic. It is not yet a universal export
policy.

## Current Fit Against Zide

Using the current comparison probe on `tokyonight-night` with the `zide-core`
preset:

- high-signal UI groups are present
- coarse syntax-slot coverage reaches `21/21`
- `groups`, `captures`, and `links` are already viable import surfaces

The main remaining questions are now:

- whether unsupported styles such as `underdouble` matter enough to expand
  Zide's runtime semantics
- how the future LSP overlay artifact should compose on top of the base theme
  contract

LSP overlay boundary:

- `app_architecture/editor/LSP_THEME_OVERLAY_BOUNDARY.md`

## Deferred Decisions

These decisions are intentionally not frozen yet:

- semantic-token / LSP overlay artifact shape and merge policy
- diagnostics/user-highlight layering policy
- whether `aggregate` should eventually carry provenance metadata per key
- whether unsupported style families should be preserved, ignored, or modeled
  explicitly in Zide
