# Android PTY Service Survival Plan

Purpose: define the separate Android product/ownership lane for testing whether
service-owned PTY survival is justified beyond the disposable app-process
baseline.

Owner docs:

- `app_architecture/platform/android/ANDROID_PTY_LIFETIME_PLAN.md`
- `app_architecture/platform/android/RENDER_BACKEND.md`
- `docs/todo/android/implementation.md`
- `docs/research/terminal/ANDROID_HOST_PTY_SCAN_2026-04-08.md`

Reference pressure:

- `dev_references/terminals/termux-app/`
- `dev_references/terminals/android-terminal-emulator/`

## Why This Is A Separate Lane

Current Android baseline is already explicit:

- app-process-owned PTY lifetime can survive pause / stop / surface retirement
  briefly on the Note10
- it does not survive app-process death
- that baseline is already strong enough for disposable reconnect/restart
  semantics

What is not answered yet is different:

- is service-owned PTY survival worth carrying as product architecture?

That is a separate question because it changes:

- ownership
- notification policy
- background execution policy
- user-visible behavior

So this lane must not hide under generic host/bootstrap work.

## Reference Pressure

Local terminal references show the common Android pattern clearly:

- Android Terminal Emulator keeps terminal sessions in a long-lived
  `TermService` foreground service with a persistent notification
- Termux splits app-owned terminal runtime and command execution through
  services, foreground notifications, and explicit command/service boundaries

What this validates:

- foreground services are the normal Android shape for "survive beyond one
  visible activity" terminal ownership
- service ownership is a real architecture decision, not a small runtime tweak

What this does not validate:

- copying Termux or Android Terminal Emulator wholesale
- assuming Zide should adopt persistent service survival by default

## Decision Question

The lane must answer:

- should Zide keep Android PTYs disposable and app-process-owned,
  or should it introduce a foreground-service-owned survival mode?

## Constraints

Do not:

- start Android renderer binding from service confidence
- treat a foreground service as product-approved by default
- widen this into Android terminal integration
- copy Termux permission, command, or plugin surfaces wholesale

## `AP-A2` Scope

Purpose:

- define and probe the narrowest honest service-owned PTY survival experiment

Acceptance:

- one authority doc records why service-owned survival is a separate lane
- the bootstrap bridge can run a minimal foreground-service PTY probe
- the probe proves whether service-owned PTY lifetime changes the observed
  survival story under backgrounding on the Note10
- queue/docs record the result without claiming product approval

Do not do:

- no terminal UI integration
- no renderer work
- no plugin/intent command surface
- no wake-lock policy beyond what the narrow probe absolutely needs

## Minimal Probe Shape

The first probe should be:

- one bootstrap foreground service
- start action and stop action
- foreground notification while active
- service starts the existing native PTY heartbeat probe
- service stop destroys that probe

This is enough to answer:

- whether foreground-service ownership materially changes survival behavior on
  the current device
- whether service semantics add real complexity that Zide would need to own

## Stop Marker

Stop `AP-A2` when:

- the bootstrap app/service can start a foreground PTY probe
- the service path is validated on-device
- docs record whether foreground-service ownership changes the practical
  Android survival story enough to justify a future product lane

## Current Probe Result

The minimal foreground-service probe was implemented and validated through
`android/terminal-host/` and is now retired from the live app.

Current truth:

- a foreground service can own the PTY heartbeat probe on the Note10
- service ownership is viable, but viability alone is not product approval

## Decision From Probe

The service-owned path is viable on this device, but it still does not justify
default product adoption by itself.

Why:

- the disposable app-process baseline already survives pause / stop / surface
  retirement briefly on the same device
- the service probe adds notification and background-ownership complexity
- this probe has not proved a materially better survival story under the
  current observed pressure, only that a service-owned mode is technically
  feasible

So the current answer is:

- disposable app-process-owned PTY lifetime remains the default Android
  baseline
- service-owned survival is now a validated option, not an approved default
- opening a real product/service lane still requires a stronger user-visible
  requirement than "the foreground-service probe works"

After that:

- either keep disposable app-process-owned PTY as the default answer
- or open a separate product decision lane if service-owned survival is
  compelling enough to justify its cost
