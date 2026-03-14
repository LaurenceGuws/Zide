# Releasing Beta Artifacts

This repository should not commit generated release binaries (`releases/`, `dist/`).
Publish them as GitHub Release assets instead.

## Versioning

- Use semver-style tags, including prerelease tags when needed:
  - `beta-0.0.1`
  - `v0.1.0`

## Build Output Layout

- Keep generated artifacts under `releases/<tag>/...` locally.
- Include:
  - terminal bundle archive
  - editor bundle archive
  - ide bundle archive
  - terminal FFI package (`libzide-terminal-ffi.so`, header, `RELEASE.txt`, `SHA256SUMS`)
  - editor FFI package (`libzide-editor-ffi.so`, header, `RELEASE.txt`, `SHA256SUMS`)
  - combined `dist/` archives + top-level checksums

## Publish to GitHub Release

Example with GitHub CLI:

```bash
TAG=beta-0.0.2
gh release create "$TAG" \
  --title "$TAG" \
  --notes "zide beta release $TAG" \
  releases/$TAG/dist/zide-terminal-bundle-$TAG-linux-x86_64.tar.gz \
  releases/$TAG/dist/zide-editor-bundle-$TAG-linux-x86_64.tar.gz \
  releases/$TAG/dist/zide-ide-bundle-$TAG-linux-x86_64.tar.gz \
  releases/$TAG/dist/zide-terminal-ffi-$TAG-linux-x86_64.tar.gz \
  releases/$TAG/dist/zide-editor-ffi-$TAG-linux-x86_64.tar.gz \
  releases/$TAG/dist/SHA256SUMS
```

If the release already exists:

```bash
gh release upload "$TAG" \
  releases/$TAG/dist/zide-terminal-bundle-$TAG-linux-x86_64.tar.gz \
  releases/$TAG/dist/zide-editor-bundle-$TAG-linux-x86_64.tar.gz \
  releases/$TAG/dist/zide-ide-bundle-$TAG-linux-x86_64.tar.gz \
  releases/$TAG/dist/zide-terminal-ffi-$TAG-linux-x86_64.tar.gz \
  releases/$TAG/dist/zide-editor-ffi-$TAG-linux-x86_64.tar.gz \
  releases/$TAG/dist/SHA256SUMS \
  --clobber
```

## Release Notes Policy

- Beta notes should stay high-level and technical, not read like a raw commit log.
- The next release after `beta-0.0.2` should include a concise technical
  breakdown of the first VT/render rewrite release:
  - renderer-owned scene target as the normal main composition path
  - default framebuffer reduced to present sink / degraded fallback
  - explicit renderer-owned present acknowledgement semantics
  - major post-rewrite hardening fixes that closed real compatibility gaps
    (`Codex` inline history, Zig `std.Progress`, focused input latency)
- Keep the tone honest: frame this as the first public release of the rewritten
  VT/render architecture, not as final parity with `kitty` / `ghostty`.
- Prefer a short architecture summary plus the most important user-visible
  compatibility wins over a long inventory of smaller fixes.

## Consumer Guidance

- Host apps should pin an explicit release tag and verify checksums before loading binaries.
- Keep local path overrides for development, but use release assets for shared testing/distribution.
