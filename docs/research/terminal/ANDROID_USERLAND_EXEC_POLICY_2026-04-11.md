# Android Userland Exec Policy Research

Date: 2026-04-11

Purpose: record why the Android terminal-host needed a Termux-compatible target
SDK posture before it could use app-private Bash as the live product shell.

## Sources

- Android 10 behavior changes for apps targeting API 29+:
  <https://developer.android.com/about/versions/10/behavior-changes-10#execute-permission>
- AOSP SELinux policy change that blocks app-home `execve()` for non-legacy
  untrusted apps:
  <https://android.googlesource.com/platform/system/sepolicy/+/c5ecb5c12c1913a44a112b0259bf34926e3e3e64%5E2..c5ecb5c12c1913a44a112b0259bf34926e3e3e64/>
- Local Termux reference:
  `dev_references/terminals/termux-app/README.md`
- Local Termux constants:
  `dev_references/terminals/termux-app/termux-shared/src/main/java/com/termux/shared/termux/TermuxConstants.java`

## Findings

Android 10 introduced a target-SDK-gated W^X rule: apps targeting API 29 or
higher must not execute files from their writable app home directory. The
public Android behavior-change page frames this as app-home execution being a
W^X violation and says API 29+ apps cannot invoke `execve()` directly on files
inside the app home directory.

AOSP SELinux policy confirms the mechanism:

- `untrusted_app_25` and `untrusted_app_27` retain app-data execution for
  compatibility.
- `runas_app` is allowed to execute app-data files for debuggable workflows.
- non-legacy untrusted app domains are covered by a `neverallow` against
  `execute_no_trans` on `app_data_file` / `privapp_data_file`.

That matches current device truth:

- `run-as dev.zide.terminal ... $PREFIX/bin/bash` worked before the SDK cut.
- product PTY exec from the app process hit `AccessDenied` while terminal-host
  targeted SDK 35.
- after terminal-host moved to target SDK 28, product PTY exec of staged Bash
  is device-proven.
- the original difference was expected because `run-as` enters the `runas_app`
  domain, while the SDK 35 live app process stayed in a modern untrusted-app
  domain.

Termux avoids this for its mainline app by targeting SDK 28. The local Termux
reference currently sets:

- `targetSdkVersion=28`
- package name `com.termux`
- prefix `/data/data/com.termux/files/usr`

Termux also documents that changing the package name requires rebuilding the
bootstrap zip and packages for the new `$PREFIX`. Rewriting paths after the
fact is useful for probes, but it is not a clean product package-management
model.

## Zide Consequences

When Zide Android terminal-host targeted SDK 35, it could not expect to
live-exec mutable userland binaries from:

`/data/data/dev.zide.terminal/files/usr`

The terminal-host now targets SDK 28 for the terminal product. That makes
app-private Bash viable as the live product shell, but it does not make
unmodified Termux package payloads product-correct for Zide's package name.

The current host-side relocation path remains a dev bootstrap tool for package
content such as Neovim, htop, and gotop. It does not replace a real
Zide-prefix package channel.

## Viable Product Directions

1. Termux-compatible target lane:
   - target SDK 28 for the terminal product
   - build Zide-owned bootstrap and packages for
     `/data/data/dev.zide.terminal/files/usr`
   - accept the compatibility posture explicitly

2. Modern-target shipped-binary lane:
   - keep target SDK 35
   - execute only binaries delivered through APK/native-library mechanisms or
     another Android-supported executable location
   - do not claim arbitrary `apt`-installed binaries are live product shells

3. Split dev/product lane:
   - keep SDK 35 for product experiments
   - keep `run-as` userland staging only for developer validation
   - product shell remains `/system/bin/sh` until a modern executable model is
     chosen

Current decision: use the Termux-compatible target lane for the Android
terminal product until a modern-target userland execution model is proven.
Do not keep patching around `AccessDenied`; build the userland/package path
that matches the SDK 28 posture.
