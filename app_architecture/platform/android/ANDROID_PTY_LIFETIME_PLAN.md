# Android PTY Lifetime Plan

Purpose: define the next Android-specific execution lane after host surface
truth, focused on PTY/process lifetime under Android pause/stop/background
pressure.

Owner docs:

- `docs/research/terminal/ANDROID_HOST_PTY_SCAN_2026-04-08.md`
- `app_architecture/platform/android/RENDER_BACKEND.md`
- `app_architecture/platform/android/SURFACE_IDENTITY_POLICY.md`
- `app_architecture/platform/android/ANDROID_PTY_SERVICE_SURVIVAL_PLAN.md`
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

The bootstrap bridge PTY heartbeat probe is enough to answer the baseline
question.

Observed truth on the Note10:

- app-process-owned PTY survives pause, stop, and surface retirement briefly
- app-process-owned PTY does not survive app-process death
- visible surface lifetime and PTY lifetime are different things on this
  device

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
- the earlier bootstrap PTY probe implementation is retired from the live app;
  this doc keeps the validated result, not the old probe surface

That separate lane is now opened explicitly as `AP-A2` in
`app_architecture/platform/android/ANDROID_PTY_SERVICE_SURVIVAL_PLAN.md`.
That does not change the current baseline. It only creates the narrow probe
surface needed to test whether foreground-service ownership materially changes
the observed Android survival story.

## Current `AP-A1.b` Probe Hardening

The bootstrap bridge now owns the live truth surface for this baseline:

- on-device PTY status
- manual start / stop / restart
- observation across pause / stop / surface retirement and later foreground
  return

That hardening is complete. It strengthens the disposable baseline without
opening service-owned survival architecture.

## Next Honest Follow-Up

The next `AP-A1` sub-cut is now:

- make the bootstrap bridge expose live PTY status and manual
  start/stop/restart controls for the disposable baseline

After that:

- stop widening this lane unless a later product decision explicitly wants
  service-owned PTY survival on Android
- if that happens, define it as a separate product/ownership lane
