# Tooling Install Surfaces

Purpose: define the cross-OS tooling model for local install/testing and staged
release preparation.

This doc is architecture/process authority for install-surface intent and
terminology. It does not replace the platform-specific layout docs such as
Windows installation authority.

## Problem

Current tooling drift is real:

- Windows has a formal staged install and registration path with:
  - local dist staging
  - per-user install
  - package-identity registration
  - uninstall
- Linux has multiple separate surfaces that overlap in purpose but not shape:
  - `zig build gui-smokes-manual`
  - local dev channel install scripts
  - terminal-only bundle/release scripts

That makes it hard to reason about:

- which tool is for smoke vs install vs release
- what "dev", "stable", and "release" actually mean on each OS
- whether launcher identity, icons, desktop integration, and runtime layout are
  part of the same contract

## Standard Model

Standardize tooling by intent first, then by OS-specific implementation.

The three supported tooling intents should be:

1. `smoke`
2. `install-local`
3. `stage-release`

These intents should exist on both Linux and Windows, even if the underlying
implementation differs by platform.

## Intent Definitions

### `smoke`

Purpose:

- build and launch the product shapes we claim to support
- verify basic runtime truth without performing a user-style install

Shared expectations:

- should work from a repo checkout
- should not mutate stable user install state by default
- should be the first stop for platform catch-up and bug triage

Current examples:

- `zig build gui-smokes-manual`

### `install-local`

Purpose:

- install launchable local builds into OS-native user surfaces for everyday
  testing
- validate desktop/finder/taskbar/start-menu behavior that repo-local smoke
  launches do not fully cover

Shared expectations:

- explicit channel vocabulary
- owned install roots / launch surfaces
- launcher identity, icons, and OS-native metadata are part of the contract
- uninstall/update/replace behavior should be deliberate, not incidental
- install and remove entrypoints should be symmetric for each owned channel

Supported channel vocabulary:

- `dev`
  - debug-oriented, fast local iteration, allowed to point at repo state
- `stable`
  - optimized local install intended to feel like a near-release daily driver

Notes:

- Linux `test` should be renamed to `dev` for consistency.
- Windows local dist install should grow the same channel vocabulary where
  useful, even if package identity remains the same core mechanism.

### `stage-release`

Purpose:

- produce reviewable local release artifacts without pretending they are
  installed
- validate release layout, naming, checksums, and asset completeness

Shared expectations:

- explicit output directory under `releases/`
- deterministic artifact names
- checksums and metadata emitted beside staged artifacts
- platform-specific install registration stays out of this intent

## Platform Mapping Direction

### Linux

Target direction:

- `smoke`
  - keep `zig build gui-smokes-manual`
- `install-local`
  - unify current local desktop install scripts under one channel contract:
    - `dev`
    - `stable`
  - canonical local entrypoints now live under:
    - `scripts/linux/install-local/deploy_channel.sh <stable|dev>`
    - `scripts/linux/install-local/deploy_channels.sh`
    - `scripts/linux/install-local/remove_channel.sh <stable|dev>`
    - `scripts/linux/install-local/remove_channels.sh`
    - `scripts/linux/install-local/sync_channel.sh <stable|dev>`
    - `scripts/linux/install-local/sync_channels.sh`
  - legacy `scripts/dev/*linux*` paths should remain thin compatibility
    wrappers only until the repo fully stops referencing them
- `stage-release`
  - current local stage script is now:
    - `scripts/linux/Stage-CurrentLinuxDist.sh`
  - this stages app/editor/terminal bundles together plus editor/terminal FFI
    artifacts under one Linux release model
  - terminal-only staging should remain compatibility-only and should not be
    treated as the main Linux release path anymore

Important Linux note:

- on Wayland/KDE, launcher icons and grouping may depend on both runtime SDL
  state and desktop-entry/install metadata
- that means `install-local` is the real authority for finder/taskbar UX, not
  repo-local smoke alone

### Windows

Target direction:

- `smoke`
  - keep `zig build gui-smokes-manual`
- `install-local`
  - keep the per-user installer and package-identity registration flow as the
    main native authority
  - align naming and reporting with the shared `dev` / `stable` vocabulary when
    doing local validation installs
- `stage-release`
  - keep staged dist preparation separate from actual install/registration

Windows execution note:

- Do not finish the Windows tooling standardization from Linux.
- The remaining Windows work should be done in a real Windows session because
  package identity, Start Menu surfaces, Explorer integration, shortcut/icon
  behavior, and local install validation all need native verification.
- When that Windows session starts, treat this doc plus
  `app_architecture/windows/INSTALLATION.md` as the implementation brief.

Windows follow-up checklist for the next native Windows session:

1. Map the current Windows scripts into the shared intent model explicitly:
   - `smoke`
   - `install-local`
   - `stage-release`
2. Decide whether local Windows validation installs should expose the same
   `dev` / `stable` channel vocabulary as Linux, or whether the existing
   package-identity flow should keep one install surface with build-mode flags.
3. Move or wrap the Windows script layout so it is visibly parallel to Linux by
   intent, not by historical script names alone.
4. Re-run native validation for:
   - Start Menu launcher identity
   - AppUserModelID grouping
   - packaged Explorer commands
   - local dist staging and installer flow
5. Update `app_architecture/windows/INSTALLATION.md` once the Windows-native
   script shape is settled.

## Non-Goals

- force identical script languages across OSes
- erase real OS differences such as package identity on Windows or desktop
  files on Linux
- keep terminal-only release tooling as a privileged permanent exception unless
  terminal-only artifacts are explicitly still a product requirement

## Immediate Refactor Direction

1. Document the current tool-to-intent mapping in one place.
2. Rename Linux local channels from `test/stable` to `dev/stable`.
   - current migration policy: accept `test` as a short compatibility alias for
     `dev` during the transition, but stop documenting it as the preferred
     surface
3. Define a shared script layout by intent:
   - `scripts/<os>/smoke/*`
   - `scripts/<os>/install-local/*`
   - `scripts/<os>/stage-release/*`
4. Move or wrap legacy tools so old entrypoints can disappear once the new
   contract is live.
5. Update platform docs so Linux and Windows both describe the same intent
   model, then only diverge on OS-native implementation details.
