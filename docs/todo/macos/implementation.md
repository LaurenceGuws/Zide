# macOS First-Class Implementation Journey

## Scope

Track the work required to make macOS a first-class native platform, not a
"the SDL/OpenGL path happens to run there" side effect.

This queue owns:

- macOS-native app/window/runtime bring-up sequencing
- the renderer/backend migration path needed for a serious macOS product
- macOS-specific validation, polish, and install-surface follow-up once the
  native runtime path is real

This queue does not own:

- the default repo-wide VT priority lane in `docs/AGENT_HANDOFF.md`
- general UI modularization that is not macOS-specific
- speculative cross-platform backend work without a concrete macOS need

## Why This Queue Exists

The repo currently has some shared macOS-aware details such as config paths and
target metadata, but it does not yet have an explicit macOS-native execution
queue. Without one, macOS work will drift into opportunistic patches and the
platform will stay second-class.

This file is the coordination point for reopening macOS as a deliberate product
lane.

## Product Direction

1. Treat macOS as a first-class desktop target, not as a tolerated side build.
2. Use Ghostty's macOS implementation as the strongest terminal reference
   pressure for native platform quality.
3. Target Metal + AppKit/Cocoa as the destination state for macOS rendering and
   window integration.
4. Do not treat SDL3 + OpenGL on macOS as the end-state architecture.
5. Keep progress explicit: every meaningful macOS milestone should be tracked
   here before code starts to sprawl.

## Non-Negotiable Constraints

- Metal is the destination backend for macOS.
- AppKit/Cocoa ownership must be explicit where native behavior requires it.
- OpenGL may remain part of current code truth during migration, but it is not
  the macOS target story.
- Reference pressure should come from:
  - `dev_references/terminals/ghostty/macos/`
  - `dev_references/sdlwiki_md/SDL3/README-macos.md`
- Keep work reviewable. Do not start by scattering macOS special cases through
  unrelated subsystems.

## Current State

- Shared config/runtime code already knows about macOS config-path semantics.
- Build metadata already recognizes macOS as a supported target.
- Current live renderer/runtime truth is still SDL3 + OpenGL oriented.
- No dedicated macOS-first-class implementation queue existed before this file.
- Current native macOS build truth is green on the active arm64 host.
- `ziglua` is back on the pinned package path.
- `zlua-portable` is back on a published pinned package path after the
  `v0.1.0-beta.2` package fix.

## Entry Points

- `app_architecture/ui/DEVELOPMENT_JOURNEY.md`
- `build_system/platform_capabilities.zig`
- `src/platform/sdl_api.zig`
- `src/ui/renderer.zig`
- `src/ui/renderer/window_init.zig`
- `dev_references/terminals/ghostty/macos/`
- `dev_references/sdlwiki_md/SDL3/README-macos.md`

## Milestones

- [x] `MAC-00` Create a dedicated macOS feature branch from current `main`
  - Branch: `macos-implementation`

- [x] `MAC-01` Seed the workspace-local reference surface needed for the first
  macOS pass
  - Current synced references:
    - `dev_references/terminals/ghostty/macos/Sources/Helpers/MetalView.swift`
    - `dev_references/terminals/ghostty/macos/Sources/Ghostty/Surface View/SurfaceView.swift`
    - `dev_references/terminals/ghostty/macos/Sources/App/macOS/AppDelegate.swift`
    - `dev_references/terminals/ghostty/macos/Sources/App/macOS/AppDelegate+Ghostty.swift`
    - `dev_references/terminals/ghostty/macos/Sources/Helpers/HostingWindow.swift`
    - `dev_references/sdlwiki_md/SDL3/README-macos.md`
    - `dev_references/sdlwiki_md/SDL3/README/macos.md`
    - `dev_references/sdlwiki_md/SDL3/SDL_PROP_WINDOW_COCOA_WINDOW_POINTER.md`
    - `dev_references/sdlwiki_md/SDL3/SDL_PROP_WINDOW_CREATE_COCOA_WINDOW_POINTER.md`
    - `dev_references/sdlwiki_md/SDL3/SDL_PROP_WINDOW_CREATE_COCOA_VIEW_POINTER.md`

- [ ] `MAC-02` Write the first honest macOS technical target note
  - Required output:
    - explicit statement of destination backend and native host surfaces
    - first ownership split between shared SDL layers and AppKit/Metal layers

- [ ] `MAC-03` Audit the current renderer/window/app stack against the macOS
  destination
  - Required output:
    - concrete contradiction list between current SDL/OpenGL truth and the
      desired macOS-first-class shape
    - ranked blockers, not a grab bag of ideas

- [ ] `MAC-04` Define the native window/app lifecycle seam
  - Focus:
    - `NSApplication`/delegate ownership
    - menu/file-open/app-activation lifecycle
    - SDL window to Cocoa handle access strategy

- [ ] `MAC-05` Define the Metal renderer migration plan
  - Focus:
    - backend seam shape
    - drawable/layer ownership
    - present contract and resize/scale handling
    - minimum migration cuts that keep diffs reviewable

- [ ] `MAC-06` Land the first code groundwork for native macOS surfaces
  - Example candidates:
    - SDL Cocoa window/view handle access
    - framework linkage cleanup for AppKit/QuartzCore/Metal
    - native host shim boundaries
  - 2026-04-05 checkpoint:
    - local native package-path bring-up is now in place for the current
      macOS host:
      - the package-side `zlua-portable` fix is now published as
        `v0.1.0-beta.2`
      - `build.zig.zon` now points `zlua_portable` back at the published pin
      - `zlua-portable` no longer forces `lua5.4` pkg-config resolution during
        ordinary dependency graph evaluation
      - `zlua-portable` now reuses `ziglua`'s generated C module instead of
        doing its own standalone Lua header import
      - `src/terminal/io/pty_unix.zig` now uses macOS-appropriate PTY headers
        (`util.h`) and no longer unconditionally imports Linux-only
        `sys/prctl.h`

- [ ] `MAC-07` Bring up the first Metal-backed render path
  - Exit criteria:
    - window creation
    - clear/present loop
    - resize handling
    - no fake "supported" claim before manual smoke truth exists

- [ ] `MAC-08` Re-establish normal macOS validation truth
  - Required checks:
    - build
    - launch
    - text input
    - resize/scale
    - terminal/editor basic interaction
  - 2026-04-05 build checkpoint:
    - `zig build` passed on native macOS arm64
    - `zig build -Dmode=editor` passed on native macOS arm64
    - `zig build -Dmode=terminal` passed on native macOS arm64
    - this is compile/build truth only; GUI launch/manual interaction truth is
      still pending
  - 2026-04-05 CLI/bootstrap smoke checkpoint:
    - ran the smoke from the published dependency graph using a workspace-local
      macOS-style `HOME`
    - validated:
      - `--write-default-config`
      - rerun-without-`--force` preserve behavior
      - `--force`
      - `--write-default-config=<path>`
      - `--write-default-config --stdout`
      - `--config-scope=editor --stdout`
      - `--config-scope=terminal --stdout`
      - `--write-default-config --with-lua-meta`
      - `--install-user-lua-meta`
    - verified written files under:
      - `~/Library/Application Support/Zide/init.lua`
      - `~/Library/Application Support/Zide/lua/zide-meta.lua`
      - `~/Library/Application Support/Zide/.luarc.json`

- [ ] `MAC-09` Prepare a macOS-only SDL/OpenGL checkpoint release before Metal
  - Current intent:
    - publish a macOS-native prerelease on the current GL path
    - treat it as a checkpoint release, not as the long-term macOS renderer
      story
  - Required before signoff:
    - define the macOS stage-release artifact shape in the release docs
    - run manual native validation for launch, shell startup, resize/scale, and
      basic editor/terminal interaction
    - draft the matching release notes once a version/tag is chosen

## Progress Ledger

- 2026-04-05:
  - created `macos-implementation` from current `main`
  - confirmed there was no pre-existing dedicated macOS queue
  - pulled a narrow Ghostty macOS reference slice plus SDL macOS reference docs
    into the workspace-local `dev_references/` tree
  - decided the lane should target Metal/AppKit first-class work, not a narrow
    macOS file-dialog patch
  - landed the first native package/build fixes needed to make the current
    SDL/OpenGL lane compile on native macOS:
    - `zlua-portable` is now self-contained against packaged `ziglua`
    - `zlua-portable` no longer depends on forced `lua5.4` pkg-config lookup
      for normal package consumption
    - published `zlua-portable` package fix as `v0.1.0-beta.2`
    - repinned `build.zig.zon` back to the published package graph
    - `ziglua` returned to the pinned package path
    - macOS PTY header split in `src/terminal/io/pty_unix.zig`
    - macOS default interactive shell startup now execs the shell directly as a
      login shell instead of misusing `/usr/bin/login`
  - native build truth is now green for:
    - `zig build`
    - `zig build -Dmode=editor`
    - `zig build -Dmode=terminal`
  - native CLI/bootstrap smoke truth is now also green for the config-export
    and Lua-meta flows from the published dependency graph
  - package validation is also green for:
    - `zig build test` in `../zlua-portable`
  - manual GUI/runtime validation is still open

## Immediate Next Pass

1. Define the macOS GL checkpoint release shape and validation ritual.
2. Run the macOS CLI/bootstrap smoke pass from the published dependency graph.
3. Then return to `MAC-02` / `MAC-03` and the Metal/AppKit architecture lane.
