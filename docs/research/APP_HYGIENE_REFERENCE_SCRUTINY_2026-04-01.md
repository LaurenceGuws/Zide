# App Hygiene Reference Scrutiny

Date: 2026-04-01

## Purpose

Pressure-test the initial app-hygiene findings against:

- official dependency documentation
- the populated `dev_references` corpus in the main `zide` clone
- architecture and build-surface patterns from strong peers

This is not a final authority doc. The owning execution queue is:

- `docs/todo/app_hygiene_cleanup.md`

## Initial Findings Under Test

The initial branch investigation claimed:

1. `src/platform/compositor.zig` is likely SDL3-era residue
2. the dependency model is broadly correct, but the build graph is overgrown
3. `zlua-portable` and `zide-tree-sitter` were justified extractions
4. more repo extraction is not the default answer
5. app runtime hook/callback sprawl deserves its own hygiene campaign

## Official Dependency Docs

### Zig build system

Official Zig build guidance supports the current high-level dependency model,
but it also sharpens one of the warnings:

- upstream maintainers are encouraged to provide libraries via the Zig build
  system for reproducible cross-platform builds
- downstream packagers still need a system-library path
- system-tool dependencies make projects harder to build
- the install prefix is user-owned, not project-owned

Relevant source:

- https://ziglang.org/learn/build-system/

Judgment against Zide:

- Zide's package-managed dependency model is directionally correct
- `build_system/target_profile.zig` and `build_system/dependency_resolver.zig`
  match that intent well
- however, `build_system/ide_graph.zig` now does more than build planning:
  it also acts as repo workflow glue
- `build_system/target_config.zig` still carries hardcoded include fallbacks
  such as `/usr/include/freetype2` and `/usr/include/harfbuzz`
- those hardcoded assumptions are weaker than the official Zig framing around
  explicit build-mode handling and user-provided system search roots

### SDL3 high DPI and Wayland

Official SDL3 docs strongly reinforce the first branch finding.

SDL3 documents:

- native coordinates are the baseline
- high DPI support should use window pixel density and display scale
- Wayland should be handled as a DPI-aware path, not by legacy scale forcing
- legacy scale forcing exists, but new applications should not depend on it
- mouse coordinates are window-relative through SDL

Relevant sources:

- https://wiki.libsdl.org/SDL3/README-highdpi
- https://wiki.libsdl.org/SDL3/SDL_GetMouseState
- https://wiki.libsdl.org/SDL3/SDL_HINT_VIDEO_WAYLAND_SCALE_TO_DISPLAY

Judgment against Zide:

- `src/platform/compositor.zig` reads even more like residue under SDL3's
  official model
- `src/platform/mouse_state.zig` already behaves as if SDL is authoritative,
  because the `compositor.isWayland()` branch does nothing
- the live code path and the official SDL docs both point toward deleting or
  drastically reducing compositor-specific scale probing

### Tree-sitter runtime vs tooling

Official Tree-sitter docs are also consistent with the repo-boundary judgment:

- the runtime library is designed to be embedded in applications
- the CLI is a build tool used to generate parsers and is not needed once a
  parser has been generated

Relevant sources:

- https://tree-sitter.github.io/tree-sitter/index.html
- https://tree-sitter.github.io/tree-sitter/5-implementation.html

Judgment against Zide:

- keeping editor/runtime semantics in `zide` is correct
- moving grammar production/tooling/assets toward `zide-tree-sitter` is also
  correct
- the current weakness is not the repo split itself
- the weakness is that `zide` still contains sibling-repo path assumptions in
  `src/editor/tree_sitter_assets.zig` and `build_system/ide_graph.zig`

## Reference Repo Comparison

Reference corpus used from the populated main clone:

- `../zide/dev_references/terminals/ghostty`
- `../zide/dev_references/terminals/alacritty`
- `../zide/dev_references/editors/lite-xl`
- `../zide/dev_references/editors/zed`

### Ghostty

Ghostty is especially useful here because it is also Zig-based and has a large
build surface.

Key observation from `dev_references/terminals/ghostty/build.zig`:

- the top-level build file is broad, but it still reads as build composition
- major concerns are delegated into explicit modules under `src/build/`
- resources, docs, executable, dist, shared deps, and lib surfaces are treated
  as named build concepts rather than one large maintenance script blob

Judgment against Zide:

- Zide's build system is not wrong for being custom
- the main concern is that `build_system/ide_graph.zig` mixes build graph
  planning with operator workflow and cross-repo task running more than
  Ghostty's top-level build surface does

### Lite XL

Lite XL provides a useful counterexample:

- Meson handles the project build/install graph
- scripts such as `scripts/build.sh` provide workflow and convenience behavior
- the build description is not also the universal owner of every maintainer
  action

Relevant sources:

- `dev_references/editors/lite-xl/README.md`
- `dev_references/editors/lite-xl/meson.build`

Judgment against Zide:

- the issue is not "Zig build vs Meson"
- the issue is separation of responsibilities
- Zide currently embeds more workflow glue directly into the build graph than
  this reference does

### Zed

Zed is a good reference for repo-boundary discipline:

- it has a large monorepo and still keeps product/runtime internals in-repo
- it uses separate crates and docs rather than separate repos for most internal
  architecture
- it does not suggest that repo splitting is the default cure for internal
  complexity

Relevant source:

- `dev_references/editors/zed/README.md`

Judgment against Zide:

- more repo extraction is not justified by default
- internal ownership cleanup should come first
- only genuinely reusable producer/tooling layers should leave the repo

### Alacritty

Alacritty is useful as a reminder that not every concern belongs in the app:

- it integrates with external tools instead of reimplementing everything
- its README presents a focused build/config/runtime surface without trying to
  absorb unrelated workflow into the product core

Relevant source:

- `dev_references/terminals/alacritty/README.md`

Judgment against Zide:

- Zide should be aggressive about deleting helper layers that survive only from
  migration history
- it should not grow app/build surfaces that merely centralize convenience

## Re-scored Findings

### Stronger after scrutiny

1. `src/platform/compositor.zig` is residue
2. the dependency sourcing model is broadly good
3. `zlua-portable` was a good extraction
4. `zide-tree-sitter` was a good extraction in principle
5. more repo extraction is not the default answer

### Sharpened after scrutiny

1. the real build-system issue is not Zig
   - it is build-graph scope creep

2. the real `zide-tree-sitter` issue is not the split
   - it is unfinished consumer contract hardening

3. app runtime modularization needs a second look
   - the risk is app-level wrapper theater, not merely large files

## Current Branch Judgment

The app-hygiene campaign should proceed on this order:

1. SDL3 residue purge
   - start with `src/platform/compositor.zig`

2. Tree-sitter contract hardening
   - remove sibling-repo path knowledge from live consumer code

3. Build graph scope control
   - separate build policy from maintainer workflow glue

4. App orchestration honesty
   - audit callback/runtime hook sprawl for fake centers

## Candidate Next Cuts

1. `src/platform/compositor.zig`
2. `src/platform/mouse_state.zig`
3. `src/editor/tree_sitter_assets.zig`
4. `build_system/ide_graph.zig`
5. `build_system/target_config.zig`
6. `src/app/update_frame_hooks_runtime.zig`

