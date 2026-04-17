# RF-M5 Stabilization matrix (terminal-host)

Recorded validation for queue line: *execute stability matrix and close refocus campaign with review gate*.

Later extended by queue milestone **AX-M3** (*rerun stabilization matrix for input/surface lifecycle after AX hardening batch*) with dated smoke plus explicit manual gaps.

Queue milestone **AX-M4** (*execute remaining device-interactive lifecycle/input/surface matrix rows and record exact outcomes*) adds scripted **adb** evidence where possible and explicit **blocker + owner** rows where touch/IME chrome cannot be driven from the host.

---

## Smoke baseline (RF-M5 session, 2026-04-17)

- `./android/terminal-host/gradlew -p android/terminal-host :app:compileReleaseJavaWithJavac` — pass (2026-04-17)
- `python3 ops/android_terminal_host.py deploy` — pass (2026-04-17)
- `adb logcat -c && adb shell am start -n uk.laurencegouws.zide/uk.laurencegouws.terminal.ZideActivity && adb logcat -d -s AndroidRuntime:E` — pass, no lines (2026-04-17)
- Cold start: `adb shell am force-stop uk.laurencegouws.zide && adb shell am start -W -n uk.laurencegouws.zide/uk.laurencegouws.terminal.ZideActivity` — `LaunchState: COLD`, no `AndroidRuntime:E` (2026-04-17)

## Smoke baseline (AX-M3 matrix refresh, 2026-04-17)

- `./android/terminal-host/gradlew -p android/terminal-host :app:compileDebugJavaWithJavac` — pass (2026-04-17)
- `./android/terminal-host/gradlew -p android/terminal-host :app:compileReleaseJavaWithJavac` — pass (2026-04-17)
- `python3 ops/android_terminal_host.py deploy` — pass (2026-04-17)
- `adb logcat -c && adb shell am start -n uk.laurencegouws.zide/uk.laurencegouws.terminal.ZideActivity && adb logcat -d -s AndroidRuntime:E` — pass, no `AndroidRuntime:E` lines (2026-04-17)
- Cold start: `adb shell am force-stop uk.laurencegouws.zide && adb shell am start -W -n uk.laurencegouws.zide/uk.laurencegouws.terminal.ZideActivity` — `Status: ok`, `Complete` (device reported `LaunchState: UNKNOWN (0)`; no `AndroidRuntime:E`) (2026-04-17)

## Smoke baseline (AX-M4 matrix completion, 2026-04-17)

Recorded during engineer session `2026-04-17T22:19:03+02:00` (host clock). Device: attached via `adb` (physical override resize observed: `Physical size: 1440x3040`).

- `./android/terminal-host/gradlew -p android/terminal-host :app:compileDebugJavaWithJavac` — pass — last lines include `BUILD SUCCESSFUL in 418ms` and `Deprecated Gradle features were used in this build...`
- `./android/terminal-host/gradlew -p android/terminal-host :app:compileReleaseJavaWithJavac` — pass — last lines include `BUILD SUCCESSFUL in 400ms` and the same Gradle deprecation notice
- `python3 ops/android_terminal_host.py deploy` — pass — ends with `Performing Streamed Install` / `Success` and `Starting: Intent { cmp=uk.laurencegouws.zide/uk.laurencegouws.terminal.ZideActivity }`
- `adb logcat -c && adb shell am start -n uk.laurencegouws.zide/uk.laurencegouws.terminal.ZideActivity && adb logcat -d -s AndroidRuntime:E` — pass — stdout was only the start line `Warning: Activity not started, intent has been delivered to currently running top-most instance.` then empty `AndroidRuntime:E` buffer (no error lines)
- `adb shell am force-stop uk.laurencegouws.zide && adb shell am start -W -n uk.laurencegouws.zide/uk.laurencegouws.terminal.ZideActivity` — pass — exact stdout:
  - `Starting: Intent { cmp=uk.laurencegouws.zide/uk.laurencegouws.terminal.ZideActivity }`
  - `Status: ok`
  - `LaunchState: COLD`
  - `Activity: uk.laurencegouws.zide/uk.laurencegouws.terminal.ZideActivity`
  - `TotalTime: 556` / `WaitTime: 558` / `Complete`

## Smoke baseline (ASF-M1 operator-matrix closure, 2026-04-17)

Recorded during engineer session `2026-04-17T22:30:14+02:00` (host clock). Docs/matrix-only milestone; supports interactive rows with host smoke (no Java changes).

- `./android/terminal-host/gradlew -p android/terminal-host :app:compileDebugJavaWithJavac` — pass — `BUILD SUCCESSFUL in 388ms` (tasks UP-TO-DATE)
- `./android/terminal-host/gradlew -p android/terminal-host :app:compileReleaseJavaWithJavac` — pass — same Gradle task graph, `BUILD SUCCESSFUL`
- `python3 ops/android_terminal_host.py deploy` — pass — `Performing Streamed Install` / `Success`; `Starting: Intent { cmp=uk.laurencegouws.zide/uk.laurencegouws.terminal.ZideActivity }`
- `adb logcat -c && adb shell am start -n uk.laurencegouws.zide/uk.laurencegouws.terminal.ZideActivity && adb logcat -d -s AndroidRuntime:E` — pass — stdout: `Warning: Activity not started, intent has been delivered to currently running top-most instance.`; empty `AndroidRuntime:E` buffer
- `adb shell am force-stop uk.laurencegouws.zide && adb shell am start -W -n uk.laurencegouws.zide/uk.laurencegouws.terminal.ZideActivity` — pass — `Status: ok`, `Complete`, `LaunchState: UNKNOWN (0)`, `WaitTime: 3012`

---

## ASF-M1 operator runbook (terminal-host)

**Package / entry:** `uk.laurencegouws.zide` / `uk.laurencegouws.terminal.ZideActivity`  
**Layout authority:** `android/terminal-host/app/src/main/res/layout/activity_main.xml` (assist bar ids below). Chrome policy: `ChromeController` (IME toggle, assist bindings).

**Pass criteria (operator):** No crash; terminal remains usable; soft keyboard and gestures behave per device norm. **Fail criteria:** Crash, permanent hang, or IME/assist/gesture path clearly broken vs. prior baseline. **Optional host check after steps:** `adb logcat -d -s AndroidRuntime:E` (expect no lines).

### A — IME show/hide + assist row

**Preconditions:** Product terminal view visible (readiness overlay dismissed if applicable). Shell input uses invisible `ShellInputView`; focus by tapping the terminal surface area (`@+id/product_surface_container` region).

1. Tap the main terminal/surface area so the shell input view receives focus (cursor/IME policy per `windowSoftInputMode` + chrome).
2. **IME toggle:** Tap `@+id/assist_ime_button` (assist bar, bottom horizontal strip). Repeat to verify **show ↔ hide** of the soft keyboard (device IME UI).
3. **Assist keys (spot-check):** With assist bar visible/scrollable (`@+id/input_assist_scroll`), tap a subset of: `@+id/assist_esc_button`, `@+id/assist_tab_button`, `@+id/assist_pipe_button`, `@+id/assist_slash_button`, arrow keys `@+id/assist_up_button` … `@+id/assist_right_button`, and modifier latches `@+id/assist_ctrl_button`, `@+id/assist_alt_button`. Confirm characters/escapes reach the terminal (visible output or expected side effect).
4. **IME + resize interaction:** With keyboard open, rotate device or invoke split-screen (if supported) once; confirm no `AndroidRuntime` crash and viewport/IME recover acceptably.

**Record:** date, device model, Android version, pass/fail, short note (e.g. IME dismiss oddity).

### B — Selection + gestures (scroll overlay + pinch)

**Preconditions:** Terminal session running with visible content; `ScrollOverlayView` `@+id/terminal_scroll_overlay` may appear when scrollback gesture is active (end edge).

1. **Scroll overlay:** If the right-edge scroll affordance is visible, drag along it vertically (scrollback). If not visible, perform the product gesture that reveals scrollback per current gesture controller behavior (e.g. vertical drag on terminal surface as implemented).
2. **Pinch:** On the terminal `SurfaceView` region, two-finger pinch zoom if the product maps pinch (see `ProductGestureController` / gesture stack); note whether zoom or scrollback quantization changes.
3. **Selection handles:** Long-press to begin selection; drag handles if shown; copy/cancel as available. Note any mismatch with terminal selection state.

**Record:** date, pass/fail per sub-step, device model.

---

## ASF-M2 operator evidence ingest log

Ingest for **matrix verdict closure** (queue `ASF-M2`). Submissions are append-only; engineer records what was received in-repo.

| Runbook § | Received | Device | Android | Date (operator) | Verdict (pass / fail / notes) |
| --- | --- | --- | --- | --- | --- |
| **§A** IME + assist | **no** | — | — | — | *No §A packet delivered to engineering this session.* |
| **§B** gestures + selection | **no** | — | — | — | *No §B packet delivered to engineering this session.* |

**Ingest note (engineer session `2026-04-17T22:37:27+02:00`):** Without operator-submitted device model, API level, and pass/fail notes, **pass** and **fail** product verdicts cannot be asserted for §A/§B. Matrix rows below use explicit **blocked** verdicts (reason + owner + date) per `ASF-M2` gate.

---

## Smoke baseline (ASF-M2 verdict milestone, 2026-04-17)

Docs/matrix-only; session `2026-04-17T22:37:27+02:00`.

- `./android/terminal-host/gradlew -p android/terminal-host :app:compileDebugJavaWithJavac` — pass — `BUILD SUCCESSFUL in 382ms`
- `./android/terminal-host/gradlew -p android/terminal-host :app:compileReleaseJavaWithJavac` — pass — `BUILD SUCCESSFUL in 421ms`
- `python3 ops/android_terminal_host.py deploy` — pass — `Performing Streamed Install` / `Success`; `Starting: Intent { cmp=uk.laurencegouws.zide/uk.laurencegouws.terminal.ZideActivity }`
- `adb logcat -c && adb shell am start -n uk.laurencegouws.zide/uk.laurencegouws.terminal.ZideActivity && adb logcat -d -s AndroidRuntime:E` — pass — `Warning: Activity not started, intent has been delivered to currently running top-most instance.`; empty `AndroidRuntime:E` buffer
- `adb shell am force-stop uk.laurencegouws.zide && adb shell am start -W -n uk.laurencegouws.zide/uk.laurencegouws.terminal.ZideActivity` — pass — `Status: ok`, `LaunchState: COLD`, `TotalTime: 544`, `WaitTime: 548`, `Complete`

---

## Lifecycle matrix

| Check | Result | How verified |
| --- | --- | --- |
| `onCreate` / cold start | pass | force-stop + `am start -W`; cold launch; no Java crash log |
| `onStart` / `onResume` | pass | implied by successful foreground start; no `AndroidRuntime:E` |
| `onPause` / `onStop` | pass-smoke (adb) | **AX-M4:** `adb shell input keyevent KEYCODE_HOME` with app foreground; then `adb logcat -d -s AndroidRuntime:E` (empty); `adb shell am start -n uk.laurencegouws.zide/uk.laurencegouws.terminal.ZideActivity` to foreground; `AndroidRuntime:E` still empty |
| `onNewIntent` | pass-smoke (adb) | **AX-M4:** `ZideActivity` is `singleTop` (`AndroidManifest.xml`). Foreground relaunch: `adb shell am start -n uk.laurencegouws.zide/uk.laurencegouws.terminal.ZideActivity` twice; system reported `Warning: Activity not started, intent has been delivered to currently running top-most instance.`; `adb logcat -d -s AndroidRuntime:E` empty |

**Follow-up delta (AX-M4):** Scripted HOME/recents behavior is launcher-dependent; no `AndroidRuntime:E` observed in this pass. Deeper lifecycle logging (custom tags) still optional; no CI added per project policy.

---

## Input matrix

| Check | Result | How verified |
| --- | --- | --- |
| IME show/hide / assist row | **blocked** (2026-04-17) | **ASF-M2:** No operator §A evidence ingested (see **ASF-M2 operator evidence ingest log**). **Reason:** awaiting runbook return with device model, Android version, dated pass/fail. **Owner:** operator. Host smoke (ASF-M2 baseline): no `AndroidRuntime:E`. |
| Hardware keyboard | pass-smoke (adb) | **AX-M4:** `adb shell input keyevent 29` (A) and `66` (ENTER) with activity foreground; `adb logcat -d -s AndroidRuntime:E` empty |
| Selection / gestures (pinch, scroll overlay, handles) | **blocked** (2026-04-17) | **ASF-M2:** No operator §B evidence ingested (see log). **Reason:** awaiting runbook return with device model, Android version, dated pass/fail per sub-step. **Owner:** operator. Host smoke (ASF-M2 baseline): no `AndroidRuntime:E`. |

**AX batch code delta (AX-M1, pre matrix):** `ShellInputView` now fills `ExtractedText` partial range metadata for IME contract; hardware path handles legacy `ACTION_MULTIPLE` batched character delivery (narrow deprecation suppression for `-Werror`). **Does not replace** interactive IME/hardware/selection rows above.

**Follow-up delta (ASF-M2):** Former **cannot-verify** rows now have explicit **blocked** verdicts with owner/date/reason until operator evidence is ingested and matrix edited to **pass** or **fail**.

---

## Userland matrix

| Check | Result | How verified |
| --- | --- | --- |
| Readiness blocker presentation | pass-smoke | App reaches activity without `AndroidRuntime:E` after install; full readiness flows manual |
| Install / update / package-doctor / restart | not run | Manual; depends on staged prefix and operator workflow |

**Follow-up delta:** No userland Java changes in RF-M5 color commit; matrix unchanged from RF-M4 seam review. AX-M1+AX-M2 scope did not expand userland orchestration.

---

## Surface matrix

| Check | Result | How verified |
| --- | --- | --- |
| Surface create / attach | pass-smoke | Cold start completes; native bridge loads via deploy script |
| Resize / viewport | pass-smoke (adb) | **AX-M4:** With app foreground: `adb shell wm size 1080x1920` (override on device reporting `Physical size: 1440x3040`); `adb logcat -d -s AndroidRuntime:E` empty; `adb shell wm size reset`. Terminal grid/visual correctness not asserted from host. |
| Destroy / teardown | pass-smoke | **AX-M4:** Process teardown via `am force-stop` in smoke baseline; cold `am start -W` relaunch; no `AndroidRuntime:E` |

**AX batch code delta (AX-M1+AX-M2, pre matrix):** `SurfaceController.notifyVisibleViewport` skips redundant bridge updates when width/height/IME visibility match last notified; `ViewModeController` coalesces product-view viewport notify + scroll-overlay refresh into one `Handler` post. **Does not replace** manual resize/viewport/grid teardown rows.

**Follow-up delta (AX-M4):** `wm size` exercises configuration/viewport pressure without proving glyph grid alignment; operator still owns visual resize/regression on real rotations and split-screen if product scope requires it.

---

## Campaign close (RF-M5)

Refocus queue items through RF-M4 are complete; RF-M5 records smoke plus explicit manual gaps above. Re-run this matrix after harness/widget changes in the same lanes.

## AX-M3 checkpoint

Matrix refreshed after **AX-M1** (input) + **AX-M2** (surface/viewport handoff) hardening; dated smoke baselines and AX code deltas recorded. Remaining gaps are unchanged: device-interactive input/surface rows and scripted lifecycle coverage where noted.

## AX-M4 checkpoint

Interactive rows executed where **host `adb`** can drive them; remaining gaps are explicitly **blocker + owner: operator** (IME chrome, touch gestures). Smoke baseline re-recorded with exact stdout fragments for this session.

## ASF-M1 checkpoint

Operator runbook **§ ASF-M1 operator runbook** published in this doc. IME/assist and gesture matrix rows carry **cannot-verify (2026-04-17)** with **owner: operator** pending hands-on sign-off; host smoke (compile, deploy, `AndroidRuntime:E`, cold start) recorded under **Smoke baseline (ASF-M1 …)**. No Java changes in this milestone.

## ASF-M2 checkpoint

**ASF-M2 operator evidence ingest log** added; no §A/§B packets received this session. IME/assist and gesture rows closed to explicit **blocked (2026-04-17)** verdicts (**owner: operator**, reason: no evidence ingested). Hardware keyboard row unchanged. Next edit: replace **blocked** with **pass**/**fail** when operator returns runbook results.
