# Android Java Naming Contract

Purpose: define one naming grammar and glossary for
`android/terminal-host/app/src/main/java/uk/laurencegouws/terminal/**` so names stay
short, unambiguous, and package-led.

This document is naming authority only. It does not replace ownership contracts
in `ANDROID_JAVA_HOST_STRUCTURE.md`.

## Naming Strategy

- prefer package context over long class prefixes
- keep class names role-first and short
- use one canonical term per concept
- avoid stacked synonyms in one class name (`Host` + `Bridge` + `Callbacks`)
- keep behavior-neutral mechanical renames separate from behavior changes

## Event Key Grammar

- `appendEvent(...)` keys must use `domain.subject.action`
- each segment is lowercase and underscore-safe
- dynamic values belong in key/value suffixes after a space, not in key tokens
  (example: `product.selection.copy result=ok chars=12`)

## Glossary

- `Readiness`: current product-operable state for Android userland
- `Provisioning`: filesystem/prefix materialization and artifact staging
- `BaselinePackages`: required package set needed for first-class use
- `PackageManager`: user-facing package CLI integration (`zide-pm`)

- `Controller`: owns behavior/state transitions for one concern
- `Assembly`: wires a construction graph and returns immutable assembled result
- `Factory`: creates related objects without owning runtime policy
- `Bridge`: adapts one interface boundary to another
- `Callbacks`: typed callback contract passed into an owner
- `Native`: JNI/NDK boundary only

## Package Rules

- keep top-level domains explicit: `debug`, `gesture`, `host`, `input`,
  `scroll`, `selection`, `session`, `userland`
- when a domain grows, split by concern and shorten local class names instead
  of adding more prefixes
- for host-heavy seams, prefer child packages (for example `host.runtime`,
  `host.userland`, `host.lifecycle`) and use local names like
  `RuntimeAssembly`, `WorkflowCallbacks`, `LifecycleController`

## Practical Conventions

- do not include `Terminal` when package already scopes terminal host context
- reserve `Product` only for user-facing product behavior distinctions
- reserve `Host` for boundary context where needed; do not repeat it when the
  package or role already encodes host ownership
- keep JSON/wire/schema keys stable unless a migration is explicitly scoped

## Rename Campaign Rules

- one mechanical slice at a time
- run local naming gates before commit:
  - `./ops/lint_android_java_events.py`
  - `./ops/lint_android_naming_all.py`
  - `./ops/check_android_naming_gate.py`
  - `./ops/precommit_android.sh` (naming gate + deploy smoke)
- compile after each slice with:
  `./android/terminal-host/gradlew -p android/terminal-host :app:compileReleaseJavaWithJavac`
- update this naming contract and the Java ownership contract in the same slice
  when naming boundaries move
