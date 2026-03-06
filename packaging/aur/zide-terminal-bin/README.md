# zide-terminal-bin (AUR skeleton)

This folder is the AUR-style package skeleton for `zide-terminal-bin`.

## Install flow (after publishing to AUR)

```bash
yay -S zide-terminal-bin
```

## What the package installs

- Bundle root: `/opt/zide-terminal-bundle`
- Launcher symlink: `/usr/bin/zide-terminal -> /opt/zide-terminal-bundle/zide-terminal`

## Local package test (before AUR publish)

```bash
cd packaging/aur/zide-terminal-bin
makepkg -si
```

## Notes

- `pkgver` must match a released tag (`v${pkgver}`) that contains:
  - `zide-terminal-bundle-${pkgver}-linux-x86_64.tar.gz`
- `sha256sums` is `SKIP` in this skeleton; replace with pinned checksum for release-grade packaging.
