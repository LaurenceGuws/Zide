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

## Verify

```bash
zide-terminal
```

## Remove

```bash
sudo pacman -Rns zide-terminal-bin-local
```
