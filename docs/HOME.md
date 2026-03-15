<h1><img src="assets/icon/color_icon.png" alt="Z" style="width: 0.92em; height: 0.92em;" align="absmiddle" />ide</h1>

A native IDE and terminal stack built in Zig, aimed at fast local workspaces,
serious terminal quality, and resource-aware tooling.

![License](https://img.shields.io/badge/license-MIT-blue.svg)

## Links

- [Documentation](https://laurenceguws.github.io/Zide/tools/docs_explorer/?config=project.pages.json)
- [Releases](https://github.com/LaurenceGuws/Zide/releases)
- [Issues](https://github.com/LaurenceGuws/Zide/issues)

## Demo

<video src="assets/demo/zide-demo-2026-03-15.mp4" poster="assets/demo/zide-demo-2026-03-15-poster.jpg" controls muted playsinline width="960"></video>

## What Zide Is

Zide is being built for heavier real-world workspaces than the usual
"single-project editor" baseline. The practical driver is simple: many-service
workspaces can spawn many terminals, language servers, and background tooling,
and the normal answer is to burn RAM and idle CPU. Zide is aiming for a tighter
resource envelope without giving up native UX or terminal quality.

Current emphasis:

- Linux-native first
- integrated terminal quality and compatibility
- Zig-first implementation
- architecture that can later support embedded and foreign hosts honestly

## Current Status

Zide is in active beta. The large VT/render rewrite has landed, and current
work is focused on hardening, compatibility, and cleanup rather than broad new
surface area.

Current release outputs include:

- terminal bundles
- editor bundles
- IDE bundles
- terminal and editor FFI packages
- hosted release and architecture docs

Use the Releases page for published binaries.

## Quick Start

The hosted docs are the primary user-facing entrypoint:

- [Bootstrap and build notes](#doc=app_architecture/BOOTSTRAP.md)
- [Dependency details](#doc=docs/DEPENDENCIES.md)
- [Terminal compatibility](#doc=docs/terminal/compatibility.md)

Local Linux example:

```bash
sudo pacman -S zig wayland wayland-protocols libxkbcommon mesa fontconfig
./scripts/bootstrap.sh
zig build run
```

Important:

- In normal Linux/macOS flow, SDL3, Lua, FreeType, HarfBuzz, and tree-sitter
  are resolved through Zig package-managed dependencies.
- You still need platform/system libraries for native execution.
- For exact platform dependency details, prefer the hosted dependency docs over
  cargo-culting old package lists from stale snippets.

If you are testing the terminal seriously, install the bundled terminfo entry:

```bash
mkdir -p ~/.terminfo
tic -x -o ~/.terminfo terminfo/zide.terminfo
```

Then launch a fresh shell inside Zide and verify:

```bash
printf '%s\n' "$TERM"
```

Expected TERM selection is compatibility-first:

- if `xterm-kitty` terminfo is already installed, Zide currently prefers it for
  broad app compatibility
- otherwise Zide uses `xterm-zide`
- then `zide-256color`
- finally `xterm-256color`

That does not mean Zide is trying to identify as Kitty as a product. It means
the PTY path currently prefers the broadest already-installed compatible entry
before falling back to Zide-owned terminfo.

## Documentation

Primary docs site:

- [Docs Explorer](https://laurenceguws.github.io/Zide/tools/docs_explorer/?config=project.pages.json)

Useful starting points:

- [Getting started](#doc=app_architecture/BOOTSTRAP.md)
- [Dependency policy](#doc=docs/DEPENDENCIES.md)
- [Terminal compatibility](#doc=docs/terminal/compatibility.md)
- [Current beta release notes](#doc=docs/releases/v0.1.0-beta.1.md)

Repo-local contributor/operator doc map:

- [docs/INDEX.md](#doc=docs/INDEX.md)

## Developer Notes

Repository-local docs still own the detailed operator guidance:

- bootstrap/build/run/test:
  [app_architecture/BOOTSTRAP.md](#doc=app_architecture/BOOTSTRAP.md)
- dependency authority:
  [docs/DEPENDENCIES.md](#doc=docs/DEPENDENCIES.md)
- release process:
  [RELEASING.md](#doc=RELEASING.md)
- docs explorer local run instructions:
  [tools/docs_explorer/README.md](#doc=tools/docs_explorer/README.md)

Local docs explorer workflow:

```bash
cd /home/home/personal/zide
npm run build:docs-explorer

cd tools/docs_explorer
python3 docs_explorer.py
```

## Features and Direction

- native Wayland-first renderer and app shell
- integrated terminal with PTY, VT core, scrollback, and redraw/present work
- tree-sitter grammar pack support
- rope-backed editor core with undo/redo
- terminal and editor FFI surfaces
- strong bias toward low idle cost and explicit runtime ownership

## Packaging and Dev Channels

Local Linux dev launcher channels:

- `zide-stable`
- `zide-test`

Commands:

```bash
scripts/dev/deploy_linux_channel.sh stable
scripts/dev/deploy_linux_channel.sh test
scripts/dev/deploy_linux_channels.sh
```

This is a local developer workflow under `~/.local`, not the published release
packaging path.

## License

MIT
