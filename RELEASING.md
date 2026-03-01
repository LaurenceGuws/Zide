# Releasing FFI Artifacts

This repository should not commit generated FFI release binaries (`releases/`, `dist/`).
Publish them as GitHub Release assets instead.

## Versioning

- Use semver-style tags, including prerelease tags when needed:
  - `beta-0.0.1`
  - `v0.1.0`

## Build Output Layout

- Keep generated artifacts under `releases/<tag>/...` locally.
- Include:
  - terminal FFI package (`libzide-terminal-ffi.so`, header, `RELEASE.txt`, `SHA256SUMS`)
  - editor FFI package (`libzide-editor-ffi.so`, header, `RELEASE.txt`, `SHA256SUMS`)
  - optional combined `dist/` archives + top-level checksums

## Publish to GitHub Release

Example with GitHub CLI:

```bash
TAG=beta-0.0.1
gh release create "$TAG" \
  --title "$TAG" \
  --notes "zide ffi release $TAG" \
  releases/$TAG/dist/zide-terminal-ffi-$TAG-linux-x86_64.tar.gz \
  releases/$TAG/dist/zide-editor-ffi-$TAG-linux-x86_64.tar.gz \
  releases/$TAG/dist/SHA256SUMS
```

If the release already exists:

```bash
gh release upload "$TAG" \
  releases/$TAG/dist/zide-terminal-ffi-$TAG-linux-x86_64.tar.gz \
  releases/$TAG/dist/zide-editor-ffi-$TAG-linux-x86_64.tar.gz \
  releases/$TAG/dist/SHA256SUMS \
  --clobber
```

## Consumer Guidance

- Host apps should pin an explicit release tag and verify checksums before loading binaries.
- Keep local path overrides for development, but use release assets for shared testing/distribution.
