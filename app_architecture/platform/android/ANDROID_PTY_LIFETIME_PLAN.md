# Android PTY Lifetime Plan

Purpose: define the next Android-specific execution lane after host surface
truth, focused on PTY/process lifetime under Android pause/stop/background
pressure.

Owner docs:

- `docs/research/terminal/ANDROID_HOST_PTY_SCAN_2026-04-08.md`
- `app_architecture/platform/android/RENDER_BACKEND.md`
- `app_architecture/platform/android/SURFACE_IDENTITY_POLICY.md`
- `docs/todo/android/implementation.md`

## Why This Is Next

The Android host lane has now proved enough surface truth for future rendering
work:

- same-surface geometry churn is explicit
- in-process `replaced` is explicit
- `retired` then later fresh `acquired` is explicit
- raw pointer/token reuse is not trusted as identity truth

That means the strongest remaining Android-specific blocker is no longer
surface identity ambiguity.

Android renderer binding is still repo-blocked by the shared renderer queue.
So the next Android lane that can move honestly is PTY/runtime lifetime.

## Current Evidence

From `docs/research/terminal/ANDROID_HOST_PTY_SCAN_2026-04-08.md`:

- PTY-backed subprocesses are viable on Android
- Termux and Android Terminal Emulator both use the expected `/dev/ptmx`
  pattern
- the real risk is Android background/process policy, especially Android 12+
  phantom-process kills

From the current host lane:

- pause, stop, surface retirement, and later reacquire are all real runtime
  truth on the Note10
- future terminal ownership cannot assume that visible-surface lifetime and PTY
  lifetime are the same thing

## Decision

The next Android-specific question is:

- what owns terminal/PTTY process lifetime when the app pauses, stops, loses
  its surface, or is background-trimmed?

This must be answered before Android terminal/runtime work becomes honest.

## Required Questions

The lane must answer:

1. Is PTY lifetime app-process-owned, service-owned, or explicitly disposable?
2. What product state is allowed to survive:
   - pause
   - stop
   - surface retirement
   - process death
3. What reconnect story exists after host return?
4. What minimum architecture avoids copying Termux wholesale while still
   respecting Android runtime policy?

## Constraints

Do not:

- assume PTY child processes survive backgrounding
- assume foreground service use is automatically acceptable product policy
- start Android renderer binding work from PTY confidence
- copy Termux app/service structure wholesale

## `AP-A1` Scope

Purpose:

- define Android PTY lifetime ownership and the first execution probe

Acceptance:

- one authority doc answers the ownership question at a product level
- the Android queue explicitly says PTY/runtime lifetime is now the stronger
  Android-specific blocker than renderer binding
- the first execution probe is defined narrowly enough to implement next

Do not do:

- no GLES or Vulkan work
- no fake PTY integration into the main app yet
- no broad Android service architecture rewrite

## First Execution Probe

The first honest probe after this authority step should be:

- a small Android-side PTY lifetime experiment that proves one of:
  - app-process-owned PTY dies with process/background pressure and must be
    treated as disposable
  - or a narrower owned survival seam is justified

That probe should optimize for truth, not feature completeness.

## Current Probe Result

The first probe is now implemented through `android/bootstrap-bridge/` using a
debug-only PTY-backed shell heartbeat.

Observed on the Note10:

- the probe starts successfully from the bootstrap app:
  - `debug.ptyProbeStart pid=29746 alive=true status=started`
- after `HOME` / background:
  - `activity.onPause`
  - `debug.ptyProbeAliveOnPause pid=29746`
  - `surface.destroyed`
  - `activity.onStop`
- the private heartbeat file kept growing while the app was backgrounded:
  - foreground sample: `COUNT1=25`
  - after background/stop: `COUNT2=29`
- after `am force-stop`:
  - heartbeat growth stopped:
    - `COUNT3=30`
  - direct PID probe returned `dead`

## Decision From Probe

Current honest baseline:

- app-process-owned Android PTYs can survive pause, stop, and surface
  retirement for at least a short window on this device
- app-process-owned Android PTYs do not survive app-process death
- product architecture must treat PTY/process loss on app death as normal
  platform pressure, not as an exceptional bug

This does not yet justify a service-owned survival design.

It does justify this narrower conclusion:

- if Android terminal work starts before a stronger service decision is made,
  the honest baseline is disposable app-process-owned PTY lifetime with
  reconnect/restart semantics after process death

## Current Baseline Decision

For the current tree:

- service-owned PTY survival is not justified yet
- disposable app-process-owned PTY lifetime is the Android terminal baseline
- any future service-owned survival design must open as a separate lane with
  explicit product authority

## Current `AP-A1.b` Probe Hardening

The bootstrap bridge should now be the live truth tool for this disposable
baseline.

Required shape:

- the app can start, stop, and restart the PTY probe without adb-only control
- the app can show live PTY status on-device:
  - alive vs dead
  - child pid
  - last start status
  - heartbeat count / last heartbeat line
- the app can keep observing that state across pause / stop / surface
  retirement and later foreground return

Observed on the Note10 after this hardening:

- a restarted probe stayed alive through `HOME` / pause / stop:
  - `activity.onPause.pty alive=true pid=22550 status=started beats=3`
  - `activity.onStop.pty alive=true pid=22550 status=started beats=4`
- the same probe was still alive on foreground return before the new surface
  was reacquired:
  - `activity.onStart.pty alive=true pid=22550 status=started beats=6`
  - `activity.onResume.pty alive=true pid=22550 status=started beats=6`
- surface retirement and later fresh `acquired` still happened independently:
  - `native.surfaceDestroyed ... epoch=2 transition=retired`
  - later `native.surfaceAvailable ... epoch=3 transition=acquired`

This is the strongest current proof that app-process-owned PTY lifetime and
visible Android surface lifetime are different things on this device.

Reason:

- this strengthens the disposable baseline without opening service-owned
  survival architecture
- it makes future Android terminal ownership decisions testable on-device
  without more bootstrap archaeology

This is still intentionally not:

- Android terminal product integration
- foreground-service survival design
- Android renderer binding work

## Next Honest Follow-Up

The next `AP-A1` sub-cut is now:

- make the bootstrap bridge expose live PTY status and manual
  start/stop/restart controls for the disposable baseline

After that:

- stop widening this lane unless a later product decision explicitly wants
  service-owned PTY survival on Android
- if that happens, define it as a separate product/ownership lane
