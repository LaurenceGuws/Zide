# Windows Chrome Policy

Date: 2026-03-20

Purpose: define how Windows-native window chrome work should be split between
shared shell/platform services and per-product chrome policy.

This file is current technical authority for the Windows chrome lane. Use it
with:

- `app_architecture/APP_LAYERING.md`
- `docs/todo/windows/implementation.md`

## Why This Exists

Zide now has three products:

- IDE
- Editor
- Terminal

All three need Windows-native integration, but they should not each grow their
own separate custom chrome stack.

We are still pre-beta. This is the right time to remove structural smell, not
to preserve weak seams with a growing ladder of fallbacks and compatibility
branches.

The rule for this lane is:

- if the seam is wrong, replace it directly in a reviewable step
- do not keep multiple half-owned Windows chrome paths alive just in case
- do not preserve failed experimental seams as dormant runtime fallbacks

## Ownership Split

### 1. Platform Shell Services

These are shared Windows-native capabilities. They belong below product
composition.

Examples:

- caption hit-testing
- drag and resize semantics
- DWM/custom frame integration
- Win11 dark-frame and system-backdrop policy application
- AppUserModelID and launcher identity
- installer/runtime layout
- future Snap Layout / Mica / dark-frame integration
- future titlebar command hosting primitives

These services should be implemented once and reused.

They belong in shell/platform layers such as:

- `src/platform/*`
- `src/ui/renderer*`
- `src/app_shell.zig`

They must not be owned by:

- terminal backend
- editor backend
- IDE composition

### 2. Product Chrome Policy

These are product decisions about how the available shell services are composed.

Examples:

- terminal-only `native` vs `integrated` window chrome
- whether terminal tabs live in the titleband
- whether IDE/editor keep a native frame or use a shared app-owned titleband
- which actions appear in a titleband region

These belong in product policy/config/composition, not in the low-level Windows
service implementation.

## Product Direction

### Terminal

Terminal is the only current product that should use integrated titlebar chrome.

Reasons:

- terminal tabs naturally belong in the top band
- Windows Terminal is the primary native reference
- terminal already needs custom drag/caption/tab coordination

Terminal-specific integrated chrome should be treated as a product policy that
consumes shared shell services.

### Editor

Editor should not inherit terminal tab-titleband chrome.

Preferred direction:

- reuse the shared top-bar widget as the left-side titleband content
- use one app-owned titleband on Windows with app-owned caption buttons on the
  right
- do not mix app-owned left chrome with native-owned right chrome in one band
- do not fork a second editor-only caption-button stack away from shared shell
  services

### IDE

IDE is the richest composition product, but it is not the owner of native
services for the other products.

Preferred direction:

- reuse shared shell services
- reuse the same shared editor/IDE titleband surface as editor
- do not make IDE a privileged infrastructure owner for terminal or editor

## Architectural Rule For Follow-Up Work

When Windows chrome behavior is wrong, prefer a clean replacement of the bad
seam over adding more fallback branches.

Good example:

- replacing a weak top-level `WM_NCHITTEST` trick with a persistent
  Windows-Terminal-like drag/input sink if that is the correct long-term seam

Bad examples:

- keeping three partially overlapping maximize paths alive
- leaving failed child-sink and top-level handoff experiments as dormant runtime
  fallbacks
- adding product-specific Windows hacks directly into terminal/editor/IDE code
  when the behavior should belong to shared shell services

## Current Practical Consequences

1. The accepted terminal integrated chrome baseline stays stable.
2. Win11 Snap Layout hover is a separate follow-up, not permission to destabilize
   the accepted path.
3. The next Snap attempt may replace the current maximize-hover seam directly if
   that yields a cleaner Windows-native design.
4. Future IDE/editor titleband work should reuse the shared top-bar widget and
   shared caption-button shell services instead of building a mixed native/app
   split band.
5. Win11 frame/material attributes should be applied once through a shared shell
   service keyed off product chrome mode and focus state, not re-implemented
   per product.

## Reference Split

For this lane, use references with an explicit split:

- Windows Terminal:
  - native Win11 caption, drag/input sink, Snap, DWM truth
- WezTerm:
  - architecture split, config shape, overall quality bar
- VS Code / VSCodium / Electron:
  - secondary reference only for IDE/editor titlebar action layout
  - not primary authority for Win32 caption behavior

## Bottom Line

There should be one Windows shell-service layer and multiple product chrome
policies on top of it.

Terminal integrated chrome is one such policy.
Editor/IDE shared titleband chrome is another.

What we should not build is three unrelated custom titlebar systems plus a pile
of fallback paths for each.
