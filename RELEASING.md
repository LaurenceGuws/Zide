# Releasing Artifacts

Release binaries belong in GitHub Release assets, not in the main repository
history. Do not commit generated release binaries under `releases/` or `dist/`
on `main`.

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
- For the terminal beta branch, use `bash ops/linux/Stage-CurrentLinuxDist.sh` to
  stage the terminal bundle + terminal FFI package into this layout before
  publishing.

## Release Branch Policy

- Cut a release branch from the exact `main` commit you intend to publish.
- Treat that branch as the stable release snapshot.
- If release-specific artifacts or Pages assets must be committed, do that on
  the release branch, not on `main`.
- Tag the release from the release-branch commit that actually produced the
  published artifacts.
- Keep release-branch-only publication conveniences there; do not back-propagate
  built Pages payloads onto `main`.

## Release Sequence

Follow this order for a semver prerelease:

1. Bump the canonical product version in [`build.zig.zon`](build.zig.zon).
2. Draft or update the matching release-notes file under `docs/releases/`.
3. Update public entrypoints that should point at the new checkpoint:
   - `README.md`
   - `docs/INDEX.md`
   - any customer-facing architecture summary used as a release landing page
4. Cut the release branch from the exact `main` commit to publish.
5. Build release artifacts into `releases/<tag>/...` on that release branch.
6. Publish GitHub Release assets from the release-branch snapshot.
7. If needed, publish a docs-explorer Pages snapshot from the release branch,
   not from `main`.

## Current macOS GL Checkpoint Lane

The active macOS branch is allowed to produce a macOS-only prerelease on the
current SDL/OpenGL path before the later Metal migration, but only as an honest
checkpoint release.

Current policy for that lane:

- do not frame the macOS GL release as the long-term renderer direction
- keep dependency truth on published package pins; do not release from sibling
  path overrides
- require native macOS validation for:
  - `zig build`
  - `zig build -Dmode=editor`
  - `zig build -Dmode=terminal`
  - app launch
  - terminal shell startup
  - resize/scale behavior
  - basic editor/terminal interaction
- define the staged macOS artifact set explicitly on the release branch before
  publishing; do not assume the current Linux bundle layout applies unchanged

Current staged macOS checkpoint artifact set:

- `releases/<tag>/macos-arm64/dist/zide-ide-bundle-<version>-macos-arm64.tar.gz`
- `releases/<tag>/macos-arm64/dist/zide-editor-bundle-<version>-macos-arm64.tar.gz`
- `releases/<tag>/macos-arm64/dist/zide-terminal-bundle-<version>-macos-arm64.tar.gz`
- `releases/<tag>/macos-arm64/dist/SHA256SUMS-macos-arm64.txt`

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
- The next semver prerelease on the `0.1.0-beta.*` line should include a
  concise technical breakdown of the first VT/render rewrite release:
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

- Host apps should pin an explicit release tag and verify checksums before
  loading binaries.
- Keep local path overrides for development, but use release assets for shared testing/distribution.

## Docs Explorer Pages Policy

- The docs explorer now lives in the standalone repo:
  <https://github.com/LaurenceGuws/docs-explorer>
- Do not treat `zide` release-branch workflow as the ownership surface for the
  docs explorer runtime anymore.
- If Zide release docs need explorer-side updates, make them in the standalone
  docs-explorer repo and follow that repo's publication ritual.
