# Releasing Artifacts

This repository should not commit generated release binaries (`releases/`, `dist/`).
Publish them as GitHub Release assets instead.

## Versioning

- Use one semver-first version line across package metadata, release tags,
  artifact names, and docs.
- Canonical product/package version lives in [`build.zig.zon`](build.zig.zon).
- Distinguish clearly between:
  - product version: plain semver, e.g. `0.1.0-beta.1`
  - git/GitHub release tag: `v` + product version, e.g. `v0.1.0-beta.1`
- Prereleases should use semver prerelease tags:
  - product version: `0.1.0-beta.1`
  - release tag: `v0.1.0-beta.1`
  - product version: `0.1.0-beta.2`
  - release tag: `v0.1.0-beta.2`
- Stable releases should use plain semver tags:
  - product version: `0.1.0`
  - release tag: `v0.1.0`
  - product version: `0.1.1`
  - release tag: `v0.1.1`
- Avoid ad hoc tag formats like `beta-0.0.2`; they make the project look less
  disciplined and drift from package metadata.
- Legacy `beta-0.0.x` releases should be treated as historical snapshots only.
  Do not continue that tag line; all new releases should use the semver + `v`
  tag scheme above.

## Build Output Layout

- Keep generated artifacts under `releases/<tag>/...` locally.
- Include:
  - terminal bundle archive
  - editor bundle archive
  - ide bundle archive
  - terminal FFI package (`libzide-terminal-ffi.so`, header, `RELEASE.txt`, `SHA256SUMS`)
  - editor FFI package (`libzide-editor-ffi.so`, header, `RELEASE.txt`, `SHA256SUMS`)
  - combined `dist/` archives + top-level checksums

## Release Branch Policy

- Cut a release branch from the exact `main` commit you intend to publish.
- Treat that branch as the stable release snapshot.
- If release-specific artifacts or Pages assets must be committed, do that on
  the release branch, not on `main`.
- Tag the release from the release-branch commit that actually produced the
  published artifacts.

## Publish to GitHub Release

Example with GitHub CLI:

```bash
VERSION=0.1.0-beta.2
TAG="v$VERSION"
gh release create "$TAG" \
  --title "$TAG" \
  --notes "zide beta release $TAG" \
  releases/$TAG/dist/zide-terminal-bundle-$VERSION-linux-x86_64.tar.gz \
  releases/$TAG/dist/zide-editor-bundle-$VERSION-linux-x86_64.tar.gz \
  releases/$TAG/dist/zide-ide-bundle-$VERSION-linux-x86_64.tar.gz \
  releases/$TAG/dist/zide-terminal-ffi-$VERSION-linux-x86_64.tar.gz \
  releases/$TAG/dist/zide-editor-ffi-$VERSION-linux-x86_64.tar.gz \
  releases/$TAG/dist/SHA256SUMS
```

If the release already exists:

```bash
VERSION=0.1.0-beta.2
TAG="v$VERSION"
gh release upload "$TAG" \
  releases/$TAG/dist/zide-terminal-bundle-$VERSION-linux-x86_64.tar.gz \
  releases/$TAG/dist/zide-editor-bundle-$VERSION-linux-x86_64.tar.gz \
  releases/$TAG/dist/zide-ide-bundle-$VERSION-linux-x86_64.tar.gz \
  releases/$TAG/dist/zide-terminal-ffi-$VERSION-linux-x86_64.tar.gz \
  releases/$TAG/dist/zide-editor-ffi-$VERSION-linux-x86_64.tar.gz \
  releases/$TAG/dist/SHA256SUMS \
  --clobber
```

## Release Notes Policy

- Beta notes should stay high-level and technical, not read like a raw commit log.
- The next prerelease after `0.1.0-beta.2` should include a concise technical
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
- Start from [`docs/NEXT_BETA_RELEASE_NOTES_TEMPLATE.md`](docs/NEXT_BETA_RELEASE_NOTES_TEMPLATE.md)
  so the first VT/render rewrite release story stays consistent.

## Artifact Naming

- Release artifacts should embed the product version, not the `v`-prefixed git
  tag.
- Example:
  - `zide-terminal-bundle-0.1.0-beta.2-linux-x86_64.tar.gz`
  - `zide-editor-bundle-0.1.0-beta.2-linux-x86_64.tar.gz`
  - `zide-ide-bundle-0.1.0-beta.2-linux-x86_64.tar.gz`

## Consumer Guidance

- Host apps should pin an explicit release tag and verify checksums before loading binaries.
- Keep local path overrides for development, but use release assets for shared testing/distribution.

## Docs Explorer Pages Policy

- `main` stays source-only for `tools/docs_explorer`; do not commit generated
  `build/js/` assets there.
- If a release needs a GitHub Pages snapshot of the docs explorer, publish it
  from the release branch.
- Release-branch ritual for docs explorer Pages:
  - run `npm run build:docs-explorer`
  - verify `tools/docs_explorer/config/project.pages.json`
  - commit the built explorer assets on the release branch if needed for Pages
  - point GitHub Pages at that release branch snapshot
