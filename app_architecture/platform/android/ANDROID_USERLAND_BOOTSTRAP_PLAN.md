# Android Userland Bootstrap Plan

Purpose: define the first honest Android userland lane after shell bring-up and
shared-renderer proof, so Android stops pretending `/system/bin/sh` is an
acceptable long-term product shell.

Owner docs:

- `docs/todo/android/implementation.md`
- `app_architecture/platform/android/ANDROID_SHELL_BRINGUP_PLAN.md`
- `app_architecture/platform/android/ANDROID_TERMINAL_HOST_PLAN.md`
- `docs/research/terminal/ANDROID_USERLAND_EXEC_POLICY_2026-04-11.md`
- sibling mobile package authority repo: `../zide-mobile-pm`

## Why This Is Next

Current Android truth is already strong enough in the prerequisite lanes:

- terminal-host/native/runtime truth is real
- shared Android renderer ownership is real enough for product shell use
- direct PTY input is real enough for current shell work

What is still not product-real:

- the current shell is still Android system `sh`
- there is no repo-owned Bash userland
- there is no package-managed path for `ripgrep`, `git`, `neovim`, or the
  rest of a serious terminal/IDE baseline

That means the next Android product blocker is not more shell polish.

It is:

- bootstrap an app-private userland
- launch Bash from that userland
- make package installation a first-class product capability

## Decision

Zide should not invent an Android package manager.

The first honest Android userland cut should be:

- app-private
- Bash-first
- `apt` / `dpkg` managed
- repo-owned in packaging and version authority

It may learn from the Termux bootstrap layout and package model, but it should
not depend on the Termux app as product infrastructure.

Local reference truth:

- `dev_references/terminals/termux-app/.../TermuxBootstrap.java` already shows
  the important proven shape:
  app-private bootstrap + `apt` package-manager variants
- that is good enough as structural evidence for Zide's first Android userland
  direction
- it is not an excuse to inherit Termux app coupling or product boundaries

That means:

- no shared Termux prefix
- no shared-user-ID coupling
- no "install Termux too" requirement
- no root/proot/chroot baseline
- no custom Java-side package manager

Current measured truth is narrower and better than the first assumption:

- the latest upstream aarch64 bootstrap zip can be downloaded on Linux and
  staged into `/data/data/dev.zide.terminal/files/usr`
- staged Bash executes successfully on-device under
  `run-as dev.zide.terminal` when `PREFIX`, `HOME`, `PATH`, `TMPDIR`,
  `LD_LIBRARY_PATH`, and `SHELL` are set explicitly
- the upstream bootstrap still embeds many `com.termux`-prefixed paths, but
  that is not a total Bash blocker by itself
- `apt-get update` can be relocated far enough with explicit environment,
  certificate, temp, and `Dir::*` overrides to reach the network and refresh
  package metadata on-device
- direct on-device `apt-get install` is not the right product claim yet:
  Termux `.deb` payloads install under `/data/data/com.termux/...`, which our
  app cannot own
- Linux-host package staging can now extract and relocate selected Termux
  `.deb` payloads into the Zide app-private prefix for development use
- `zide-pm-admin` now publishes a versioned Android dev snapshot prerelease
  built from pinned provider inputs
- Zide now has a consumer command,
  `./ops/android_terminal_host.py userland-stage-artifact`, that reads the
  published manifest, verifies the archive contract, and stages the prefix
  without parsing provider package internals
- terminal-host now reads the staged bootstrap stamp before auto-starting the
  shell:
  missing/invalid stamp or missing `${PREFIX}/bin/bash` blocks blind auto-start
  and reports explicit userland readiness in debug status instead
- product view now carries a minimal bootstrap blocker flow when userland is
  not launch-ready:
  retry rechecks staged state, and debug jumps directly to the detailed debug
  surface
- the Linux-host consumer path can now read the currently staged stamp from the
  device and compare it against the requested artifact:
  `userland-stage-artifact` reports `already-current` for matching staged
  artifact/version/provider state and only restages when the state differs or
  `--force` is used
- terminal-host also carries the pinned requested dev artifact identity in the
  app build, so launchable staged userland is classified as `ready-current` or
  `ready-upgrade-needed` instead of one generic ready state
- device-proven dev package set now includes:
  - Bash 5.3.9 from the staged bootstrap
  - Neovim 0.12.1 staged from relocated package payloads
  - `htop` 3.5.0 and `gotop` 4.2.0 as current top-like test tools
- `btop` is not present in the current Termux main aarch64 package index
- the executable-location boundary is target-SDK policy, not an unknown bug:
  Android 10/API 29+ blocks `execve()` from writable app home directories for
  normal untrusted app domains; `run-as` is explicitly exempt for debuggable
  workflows
- product posture is now explicit: terminal-host targets SDK 28 until a
  modern-target userland execution model is proven
- after the SDK 28 cut, live product-shell exec of staged Bash from the app
  process is device-proven on the Note10:
  `bash-5.3$`, `pwd`, and `/` appeared in the product transcript

## Product Boundary

Ownership should stay explicit.

Android/Java owns:

- first-run bootstrap extraction into app-private storage
- prefix version stamps and upgrade gating
- user-facing progress/error surfaces for bootstrap and package operations
- Android-native storage/network lifecycle concerns

Zig/native owns:

- shell/session selection
- PTY/session environment setup
- launch of the active shell from the extracted prefix
- terminal/runtime/product semantics once the userland exists

The package manager itself should remain userland-owned:

- `apt` / `dpkg` live inside the prefix
- package installs and upgrades execute as normal shell commands in that
  userland

## Prefix Model

The baseline shape should be:

- one app-private prefix under the app files directory
- one app-private home directory
- no write dependence on shared storage
- one explicit bootstrap version stamp

Current manual Bash validation target:

- `${PREFIX}/bin/bash`

Product shell target:

- Bash is now the live product shell target on the SDK 28 terminal-host path

Expected environment baseline:

- `PREFIX`
- `HOME`
- `PATH`
- `TMPDIR`
- `SHELL`
- `TERM`
- `COLORTERM`
- locale defaults only if the packaged userland proves they are needed

Execution policy baseline:

- terminal-host now chooses the Termux-compatible model:
  target SDK 28 plus Zide-built packages for the Zide `$PREFIX`
- modern-target execution remains research, not the active product baseline
- `run-as` success is useful developer evidence, but it is not equivalent to
  product app-process exec proof

## Package Strategy

Use `apt` / `dpkg` as the first package-management contract.

Why:

- it already has the least product speculation for Android terminal use
- it answers the real need directly: install and upgrade packages
- it keeps the product focused on terminal/IDE experience instead of package
  tooling invention

Package authority should be Zide-controlled, not vague upstream drift.

That now means:

- `../zide-mobile-pm` owns mobile package/artifact production and trust
  metadata
- providers are inputs to that package authority, not the product identity
- `termux-main` is the first supported Android provider
- `zide` consumes explicit manifests, checksums, archive URLs, version stamps,
  and provider provenance
- initial package set stays intentionally small and product-driven
- future Zide-owned Android providers may be added or become the default
  without changing the `zide-pm` surface

Initial package goals are not "all of Linux". They are:

- Bash
- package-manager runtime (`apt`, `dpkg`, certificates, transport, metadata)
- core terminal utilities
- the first `nvim` support baseline after the bootstrap proves honest

Development staging exception:

- host-side `.deb` extraction/relocation is allowed for AU-A1/AU-A3 device
  testing
- it is not the final package-manager contract
- it exists because upstream Termux package payloads are package-name rooted
  and cannot be installed directly by our app-owned `dpkg`
- the normal Zide dev consumer path is now the published Android
  `android-prefix-archive` manifest from `../zide-mobile-pm`, not direct `.deb`
  staging

## `AU-A1` Scope

`AU-A1` Android userland bootstrap

Purpose:

- replace system `sh` as the product shell baseline
- prove one repo-owned Bash prefix with package-management authority

Acceptance:

- the app can materialize a versioned bootstrap prefix into app-private storage
- that prefix contains a runnable Bash
- Android terminal-host can launch Bash from the owned userland without
  depending on `/system/bin/sh`
- device proof shows `bash --version`
- the prefix survives app restart without rebootstrap churn
- docs explain the bootstrap/version boundary clearly

Do not do:

- no full package universe yet
- no claim that host-side `.deb` extraction is the final package manager
- no distro manager
- no proot/root/chroot lane
- no custom package manager

Current checkpoint:

- `./ops/android_terminal_host.py userland-fetch-ref` downloads the latest
  upstream aarch64 bootstrap zip on Linux into `.cache/android-userland/`
- `./ops/android_terminal_host.py userland-inspect` restores archive truth
  honestly:
  - `bash` and `apt` exist in the bootstrap
  - `nvim` and `btop` do not
  - the archive still contains many hardcoded `com.termux` references
- `./ops/android_terminal_host.py userland-stage` restores symlinks, writes a
  version stamp, and stages the prefix into app-private storage on the device
- `./ops/android_terminal_host.py userland-stage-packages neovim htop gotop`
  resolves the Termux main dependency closure on Linux, downloads `.deb`
  files into `.cache/android-userland/packages/`, extracts their
  `/data/data/com.termux/files/usr` payloads, relocates them to
  `dev.zide.terminal`, and stages the merged prefix
- `./ops/android_terminal_host.py userland-stage-artifact` stages the published
  Android dev prefix artifact by manifest:
  `https://github.com/LaurenceGuws/zide-mobile-pm/releases/download/android-dev-2026.04.11.211834/android-dev-prefix.release.manifest.json`
- artifact staging verifies package name, prefix, archive root, provider
  metadata, size, and SHA-256 before pushing the prefix to the device
- Note10 validation confirms the artifact-staged prefix runs:
  - Bash 5.3.9
  - Neovim 0.12.1
  - `nvim --headless +qall`
  - `htop` 3.5.0
  - `gotop` 4.2.0
- fresh terminal-host launch after artifact staging reports
  `auto.shellStart status=started` and a Bash child under the
  `dev.zide.terminal` app process
- `./ops/android_terminal_host.py userland-bash-version` proves staged Bash on
  the Note10
- `./ops/android_terminal_host.py userland-apt-update` proves the current apt
  relocation cut can refresh package metadata on-device
- terminal-host now launches `${PREFIX}/bin/bash` as the live product shell
  after configuring `PREFIX`, `HOME`, `TMPDIR`, `PATH`, `SHELL`, cert,
  terminfo, XDG, `VIMRUNTIME`, and library paths
- device validation also proves:
  - product transcript prompt: `bash-5.3$`
  - product input smoke: `pwd` returned `/`
  - `nvim --version`
  - `nvim --headless +qall`
  - `htop --version`
  - `gotop --version`

## `AU-A2` Scope

`AU-A2` Android package-manager handshake

Acceptance:

- Zide can stage a prefix from a published manifest/release URL without
  parsing provider package internals
- terminal-host can distinguish missing/invalid/not-launchable staged userland
  from real shell-start failures before auto-start
- the consumer path can distinguish no staged artifact vs already-current vs
  restage-required artifact state before pushing files
- `apt update` works against the configured repo/channel
- one small package can be installed or materialized from that channel through
  a repo-owned package flow
- package state survives process restart
- failure surfaces are honest enough that the user can recover

Stop `AU-A2` before:

- broad package curation
- editor bootstrap
- background package-daemon ideas

## `AU-A3` Scope

`AU-A3` first curated terminal-dev baseline

Purpose:

- prove the userland is sufficient for serious terminal use, not just Bash

Initial likely package targets:

- `ripgrep`
- `git`
- `neovim` or the smallest package subset that proves the first `nvim`
  baseline honestly

## Stop Marker

Stop this lane when:

- product shell no longer depends on Android system `sh`
- Bash is the live product shell on device
- package metadata refresh works
- at least one real package install works
- the next blocker becomes curated package content or IDE integration depth,
  not "we still do not have a real userland"

## Immediate Next Moves

1. Make the artifact-staged prefix the normal dev bootstrap path.
2. Define provider policy for Android product installs:
   - keep `termux-main` as the first supported provider
   - keep provider provenance/configuration explicit
   - leave room for a future Zide-owned default provider without changing the
     product package UX.
3. Wire first-run/user-facing bootstrap UI around the artifact-staging contract
   instead of requiring the developer ops command.
