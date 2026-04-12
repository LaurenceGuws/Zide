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
- terminal-host now also owns the first in-app artifact install/update path:
  it can fetch the published manifest, resolve/download the archive, verify the
  SHA-256 + size contract, extract the prefix into app-private storage, and
  rewrite the local `.zide-userland-bootstrap.json` stamp without going through
  the developer ops command
- product blocker/debug surfaces now also carry explicit install state:
  `idle`, `installing`, and `failed`
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
  `https://github.com/LaurenceGuws/zide-mobile-pm/releases/download/android-dev-2026.04.12.002012/android-dev-prefix.release.manifest.json`
- artifact staging verifies package name, prefix, archive root, provider
  metadata, size, and SHA-256 before pushing the prefix to the device
- Note10 validation confirms the artifact-staged prefix runs:
  - Bash 5.3.9
  - Neovim 0.12.1
  - `nvim --headless +qall`
  - `htop` 3.5.0
  - `gotop` 4.2.0
- the current published Android dev snapshot is now
  `android-dev-2026.04.12.002012`
- terminal-host product flow can now press `Install` / `Update` and fetch that
  published snapshot without going through the developer ops command
- device validation now also proves the staged prefix contains and runs
  `zide-pm` under `run-as dev.zide.terminal`:
  - `zide-pm doctor --prefix /data/user/0/dev.zide.terminal/files/usr`
  - `zide-pm list-available --prefix /data/user/0/dev.zide.terminal/files/usr`
- terminal-host now exposes one honest app-owned package action through the
  hidden sidebar:
  `Packages` runs `zide-pm doctor` plus `zide-pm list-available` against the
  installed prefix and surfaces the output in debug view
- the published snapshot contract is now owned in one checked-in descriptor:
  `android/terminal-host/app/src/main/assets/userland_release.json`
  - Android runtime reads it for in-app install/update
  - `./ops/android_terminal_host.py userland-stage-artifact` reads the same
    file for its default manifest URL
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
- product view can surface missing/invalid/upgrade-needed userland state
  honestly instead of pretending the shell is simply broken
- the package/userland model is explicit enough that the repo does not need
  near-term naming or ownership churn before returning to rendering work
- `apt update` works against the configured repo/channel
- one small package can be installed or materialized from that channel through
  a repo-owned package flow
- package state survives process restart
- failure surfaces are honest enough that the user can recover

Stop `AU-A2` before:

- broad package curation
- editor bootstrap
- background package-daemon ideas
- arbitrary provider-switching UX

## AU-A2 Work Spree Stop Marker

Leave `AU-A2` only when this narrower foundation is true:

- app-private userland install/update is coherent enough that the app does not
  need to be refactored or renamed again next week
- the artifact contract is the only install/update input; no provider package
  internals leak into product flow
- staged state is explicit:
  - missing
  - invalid
  - ready-current
  - ready-upgrade-needed
- `zide-pm` is staged as part of the installed prefix and remains the intended
  first-class package surface
- provider semantics are explicit:
  - `termux-main` is the first supported Android provider
  - provider is not product identity
  - future Zide-owned providers can replace the default without changing the
    package UX
- shell policy is structurally configurable later even if Bash remains the only
  supported default today

Do not leave this lane claiming:

- broad package UX
- multiple Android shells fully supported
- product-polished onboarding
- product-clean provider replacement already implemented

## AU-A2 Exit Checklist

`AU-A2` is now met for the current Android foundation.

Validated truth:

- app-private userland install/update is app-owned and coherent enough for the
  current terminal-host lane
- the artifact contract is the only install/update input in product flow
- staged state is explicit and product-visible:
  - missing
  - invalid
  - ready-current
  - ready-upgrade-needed
- the hidden sidebar exposes one honest package action:
  `Packages` runs `zide-pm doctor` plus `zide-pm list-available` from the
  installed prefix and surfaces the result in debug view
- `zide-pm` is staged in the installed prefix and device-proven runnable
- provider semantics are explicit:
  - `termux-main` is the first supported Android provider
  - provider is not product identity
  - a future Zide-owned provider can replace the default without changing the
    package UX
- Bash startup no longer touches the stale
  `/data/data/com.termux/files/usr/etc/bash.bashrc` path; terminal-host now
  launches Bash with clean startup flags and environment-owned prompt hooks

AU-A2 intentionally does not claim:

- broad package curation
- multiple Android shells fully supported
- product-polished onboarding
- product-clean provider replacement

That means the next highest-leverage work should leave package/userland churn
and return to the active renderer blocker unless a concrete Android package
regression appears.

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

1. Record the AU-A2 execution plan before more code lands, then keep `main` as
   the one cohesive Android terminal line.
2. Add Android-host-owned userland install state so the app can represent:
   idle, installing, install-failed, ready-current, and ready-upgrade-needed.
3. Replace the current ops-only artifact staging posture with an app-owned
   install/update path that still consumes only the published manifest/archive
   contract.
4. Keep `termux-main` as the first supported Android provider while preserving
   provider provenance and leaving room for a future Zide-owned default
   provider.
5. Treat current `dev` naming only as bootstrap-profile/channel maturity
   language, not as long-term product semantics.

## AU-A2 Execution Plan

Execute the remaining AU-A2 work in this order:

1. lock the plan in repo authority and keep commits small
2. add one app-owned install state machine for userland install/update
3. wire one honest product action that starts install/update from the published
   artifact contract
4. persist installed/requested artifact identity in one app-owned place
5. prove the staged prefix still contains and can run `zide-pm`
6. stop the lane once install/update/userland state is boring enough that
   native rendering can retake priority

Implementation guardrails for this sequence:

- do not reopen direct provider-package staging in product flow
- do not add a second package-management surface beside `zide-pm`
- do not bake temporary `dev` wording deeper into runtime ownership
- keep the in-app installer strictly artifact-contract-owned; do not let
  provider package internals leak into it
