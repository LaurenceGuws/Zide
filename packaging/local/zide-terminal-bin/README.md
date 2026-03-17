# Local package test: `zide-terminal-bin-local`

This package is for local install testing from your current repo checkout.

## Build + install

```bash
cd packaging/local/zide-terminal-bin
makepkg -si
```

What it does:
- builds `ReleaseFast` terminal binary from repo root
- creates a bundle with bundled libs + terminfo
- installs to `/opt/zide-terminal-bundle`
- installs launcher symlink at `/usr/bin/zide-terminal`
- installs a desktop entry as `zide-terminal.desktop`
- installs an app icon as `zide-terminal`

## Versioning note

Arch packages cannot use hyphens in `pkgver`, so this package stores the
upstream product version separately and uses an Arch-safe package version.

## Verify

```bash
zide-terminal
```

Or launch `Zide Terminal` from your desktop launcher. This launcher points at the
packaged `/usr/bin/zide-terminal` path, so it matches the local dogfood package
instead of older ad hoc binaries under `~/.local/bin`.

## Remove

```bash
sudo pacman -Rns zide-terminal-bin-local
```
