# Android Shell Bring-Up Plan

Status: closed and met. This document is a historical decision record, not an
active queue.

## Purpose

Record the bring-up decision that moved Android from probe-only behavior to a
real on-device shell loop through the repo terminal runtime.

## Decision

The first honest Android shell lane had to be:

- terminal-host owned
- terminal-FFI backed
- PTY backed through the real terminal engine
- validated on real device behavior, not probes

It explicitly was not:

- shared renderer backend adoption work
- Android UI polish work
- service-survival architecture work

## Result

Bring-up is met:

- Android terminal host runs a real shell loop through the terminal runtime.
- Shell input/output is proven on-device and repeatable.
- Bring-up is no longer the active blocker.

## Aftermath

Active work moved to product behavior and quality tickets in:

- `docs/todo/android/implementation.md`

Java ownership and cleanup pressure moved to:

- `app_architecture/platform/android/ANDROID_JAVA_HOST_STRUCTURE.md`

Long-lived host architecture constraints remain in:

- `app_architecture/platform/android/ANDROID_TERMINAL_HOST_PLAN.md`
