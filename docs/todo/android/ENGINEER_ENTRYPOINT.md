# Android Engineer Entrypoint (Dual Mode)

Execution-only brief for the engineer session.

## Mode + Roles

- Mode: `dual`
- Engineer: execution only
- Architect: scope, gating, review
- User: product direction and approval

Do not redefine scope or reorder tickets.

## Vision + Authority

- Vision source: `refocus_android.txt` (read-only scratchpad context)
- Execution authority:
  1. `docs/todo/android/implementation.md`
  2. `docs/AGENT_HANDOFF.md`
  3. `app_architecture/platform/android/ANDROID_REFOCUS_CASE_STUDY.md`
  4. `app_architecture/platform/android/ANDROID_JAVA_HOST_STRUCTURE.md`
  5. `app_architecture/platform/android/ANDROID_JAVA_NAMING_CONTRACT.md`
  6. `AGENTS.md`
  7. `docs/WORKFLOW.md`

## Current Target

- Active milestone, queue line, and per-milestone tasks: **`docs/todo/android/implementation.md`** (authoritative).
- Userland harness contract reference: `app_architecture/platform/android/USERLAND_HOST_CONTRACT.md`

## Ticket Plan

Follow the **active milestone** section in `docs/todo/android/implementation.md` sequentially. Older RF-M1 ticket allowlists in this file are historical; do not use stale file lists if they conflict with the current milestone in the queue.

Typical wave (when the queue specifies it):

1. Milestone state sync (`docs/todo/android/implementation.md`, `docs/AGENT_HANDOFF.md` as allowed).
2. Code cuts per milestone scope in the queue.
3. Validation gate (exact commands from `implementation.md` or queue):
   - `./android/terminal-host/gradlew -p android/terminal-host :app:compileReleaseJavaWithJavac`
   - `python3 ops/android_terminal_host.py deploy`
   - `adb logcat -c && adb shell am start -n uk.laurencegouws.zide/uk.laurencegouws.terminal.ZideActivity && adb logcat -d -s AndroidRuntime:E`
4. Queue update + stop marker at milestone boundary.

## Commit Rules

- Commit in small, coherent checkpoints.
- No amend/squash unless explicitly requested.
- Each commit must compile clean.
- Do not include `refocus_android.txt` in commits.

## Hard Stop Conditions

Stop immediately and report:

`Blocked by humain review needed: true`

when:

- a required change needs files outside current ticket allowlist
- architecture docs conflict with code reality in a way that changes scope
- validation fails and cannot be fixed inside current ticket

Otherwise continue autonomously with:

`Blocked by humain review needed: false`

## Response Contract (Every Response)

Use exact headers:

- `#DONE`
- `#OUTSTANDING`
- `COMMITS`
- `VALIDATION`
- `Blocked by humain review needed: true|false`
