# RF-M5 Stabilization matrix (terminal-host)

Recorded validation for queue line: *execute stability matrix and close refocus campaign with review gate*.

**Smoke baseline (every RF-M5 session):**

- `./android/terminal-host/gradlew -p android/terminal-host :app:compileReleaseJavaWithJavac` — pass (2026-04-17)
- `python3 ops/android_terminal_host.py deploy` — pass (2026-04-17)
- `adb logcat -c && adb shell am start -n uk.laurencegouws.zide/uk.laurencegouws.terminal.ZideActivity && adb logcat -d -s AndroidRuntime:E` — pass, no lines (2026-04-17)
- Cold start: `adb shell am force-stop uk.laurencegouws.zide` then `adb shell am start -W -n uk.laurencegouws.zide/uk.laurencegouws.terminal.ZideActivity` — `LaunchState: COLD`, no `AndroidRuntime:E` (2026-04-17)

## Lifecycle matrix

| Check | Result | How verified |
| --- | --- | --- |
| `onCreate` / cold start | pass | force-stop + `am start -W`; cold launch; no Java crash log |
| `onStart` / `onResume` | pass | implied by successful foreground start; no `AndroidRuntime:E` |
| `onPause` / `onStop` | not run | Needs interactive home/recents or scripted instrumentation; follow-up if regressions reported |
| `onNewIntent` | not run | Product may not exercise multi-intent in smoke; exercise when deep-link/intent work lands |

**Follow-up delta:** Pause/stop/new-intent rows are operator spot-checks until a scripted harness exists; no CI added per project policy.

## Input matrix

| Check | Result | How verified |
| --- | --- | --- |
| IME show/hide / assist row | not run | Manual on device |
| Hardware keyboard | not run | Manual on device or `adb` key injection spot-check |
| Selection / gestures (pinch, scroll overlay, handles) | not run | Manual on device |

**Follow-up delta:** Input surface is unchanged by RF-M5 theming commit; full pass remains device-interactive.

## Userland matrix

| Check | Result | How verified |
| --- | --- | --- |
| Readiness blocker presentation | pass-smoke | App reaches activity without `AndroidRuntime:E` after install; full readiness flows manual |
| Install / update / package-doctor / restart | not run | Manual; depends on staged prefix and operator workflow |

**Follow-up delta:** No userland Java changes in RF-M5 color commit; matrix unchanged from RF-M4 seam review.

## Surface matrix

| Check | Result | How verified |
| --- | --- | --- |
| Surface create / attach | pass-smoke | Cold start completes; native bridge loads via deploy script |
| Resize / viewport | not run | Manual resize + terminal grid check |
| Destroy / teardown | not run | Manual or extended lifecycle |

**Follow-up delta:** Same as input — no surface code changes in hotspot color commit.

## Campaign close

Refocus queue items through RF-M4 are complete; RF-M5 records smoke plus explicit manual gaps above. Re-run this matrix after harness/widget changes in the same lanes.
