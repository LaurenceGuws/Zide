# Editor Reference Comparison 2026-03-18

## Purpose

Capture the first focused reference comparison for Zide's editor subsystem using
a small set of strong local references by concern, not a vague survey.

This write-up is not trying to score winners. Its job is to sharpen Zide's own
design reasoning.

## Compared References

- `dev_references/editors/helix`
- `dev_references/editors/neovim`
- `dev_references/editors/zed`
- `dev_references/editors/lapce`

## Concern Map

### Helix

Most useful for:

- editor-core semantics
- rope/transaction-oriented editing model
- indentation/search/syntax modules that stay editor-core owned

Local code paths worth revisiting:

- `dev_references/editors/helix/helix-core/src/transaction.rs`
- `dev_references/editors/helix/helix-core/src/indent.rs`
- `dev_references/editors/helix/helix-core/src/search.rs`
- `dev_references/editors/helix/helix-core/src/syntax.rs`
- `dev_references/editors/helix/helix-core/src/selection.rs`

Design pressure on Zide:

- keep line/edit semantics as true editor-core operations
- avoid leaking editing behavior into widget/app routing code
- keep syntax/search integration close to editor truth rather than UI-local state

### Neovim

Most useful for:

- syntax/query richness
- resolved theme authority
- runtime/editor-state authority boundaries

Local code/doc paths worth revisiting:

- `dev_references/editors/neovim/runtime/doc/treesitter.txt`
- `dev_references/editors/neovim/runtime/lua/vim/hl.lua`
- theme/runtime-related files under `runtime/`

Design pressure on Zide:

- separate theme/runtime authority from theme-source implementation details
- keep tree-sitter/query richness as a real subsystem capability
- prefer resolved-state contracts when source formats are chaotic

### Zed

Most useful for:

- editor/IDE host layering
- multi-buffer/workspace model
- render/performance instrumentation culture

Local code/doc paths worth revisiting:

- `dev_references/editors/zed/crates/multi_buffer`
- `dev_references/editors/zed/crates/search`
- `dev_references/editors/zed/docs/src/development.md`
- `dev_references/editors/zed/docs/src/multibuffers.md`
- `dev_references/editors/zed/docs/src/migrate/vs-code.md`

Design pressure on Zide:

- document the editor/app host seam clearly
- keep stress/perf instrumentation as a normal engineering path, not an afterthought
- make multi-buffer/editor-host structure explicit in docs before the subsystem grows further

### Lapce

Most useful for:

- rope-backed GUI editor structure
- proxy/background work separation
- tree-sitter and search work off the main interaction path

Local code/doc paths worth revisiting:

- `dev_references/editors/lapce/docs/why-lapce.md`
- `dev_references/editors/lapce/lapce-core`
- `dev_references/editors/lapce/lapce-proxy/src/dispatch.rs`
- `dev_references/editors/lapce/lapce-proxy/src/buffer.rs`

Design pressure on Zide:

- keep background/editor-runtime responsibilities explicit
- continue treating syntax/highlight/search as pipeline work, not as incidental widget logic
- stay honest about where work should be synchronous versus off-thread

## Current Zide Position

Zide is now in a healthier place than it was earlier in the editor lane:

- editor-core line operations now exist as real core behavior
- app/editor shortcut routing is cleaner and Lua-owned at the binding layer
- resolved theme import has a cleaner authority model
- editor FFI is now documented as a first-class boundary

But Zide still needs stronger investigation in three places:

1. end-to-end editor pipeline stress from input through render
2. clearer documentation of render/cache behavior under editor workloads
3. deeper comparison against Helix/Zed/Lapce on core-vs-host boundary discipline

## Initial Conclusions

### 1. No new reference repos are required yet

The current local set is already good enough to ask the first serious editor
architecture questions.

Adding more repos right now would mostly increase browsing noise rather than
clarity.

### 2. Helix is the strongest immediate pressure for editor-core quality

If the question is "should this behavior live in editor core or in app/widget
glue?", Helix is the cleanest comparison pressure in the current set.

### 3. Zed is the strongest immediate pressure for editor/IDE host reasoning

If the question is "how should a modern editor subsystem relate to workspaces,
search, multibuffer views, and performance instrumentation?", Zed is currently
the most relevant large reference already on disk.

### 4. Neovim remains the authority for theme/query richness

Neovim is not the ideal comparison for native app/editor host structure, but it
is still the most useful local authority for resolved theming richness and
tree-sitter/query behavior.

## Next Reference Questions

- How should Zide document the editor render/cache path with the same precision
  as the terminal present path?
- Which editor stress cases should be measured first so results are comparable
  across Zide, Helix, Zed, and Lapce by concern rather than by vague feel?
- Is there a missing reference only after those first questions are answered?
