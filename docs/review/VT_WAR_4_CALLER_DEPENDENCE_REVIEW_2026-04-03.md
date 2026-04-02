# VT War 4 Caller Dependence Review

Date: 2026-04-03

## Purpose

Classify the remaining live callers of
[TerminalRuntimeShell](/home/home/personal/zide/src/terminal/core/session/terminal_runtime_shell.zig)
to determine whether they still imply a fake shell center or now mostly look
legitimate.

## Current Judgment

Most remaining shell dependence now looks honest.

The strongest remaining suspect is not widget code, workspace code, or app
code.
It is the FFI handle/constructor path that still makes the shell the universal
host entrypoint.

## Ranked Findings

### 1. Highest-payoff suspect: FFI handle identity is still shell-centered

Evidence:

- [shared.zig:318](/home/home/personal/zide/src/terminal/ffi/shared.zig#L318)
  stores `session: *TerminalRuntimeShell`
- [core_api.zig:339](/home/home/personal/zide/src/terminal/ffi/core_api.zig#L339)
  creates `TerminalRuntimeShell`
- [core_api.zig:384](/home/home/personal/zide/src/terminal/ffi/core_api.zig#L384)
  immediately attaches external transport
- [host_api.zig:10](/home/home/personal/zide/src/terminal/ffi/host_api.zig#L10)
  through [host_api.zig:132](/home/home/personal/zide/src/terminal/ffi/host_api.zig#L132)
  route host actions through that shell-owned handle

Why it still matters:

- this is the main place where the shell still looks like the thing the host
  "has"
- it is a stronger signal than local shell use inside the native app

### 2. Workspace host use now looks mostly legitimate

Evidence:

- [workspace_host.zig:114](/home/home/personal/zide/src/terminal/core/workspace_host.zig#L114)
  uses runtime aggregation for close-confirm decisions
- [workspace_host.zig:124](/home/home/personal/zide/src/terminal/core/workspace_host.zig#L124)
  locks the shell and reads core cwd text directly
- [workspace_host.zig:183](/home/home/personal/zide/src/terminal/core/workspace_host.zig#L183)
  packages tab sync state using mixed metadata/activity/runtime truth

Current read:

- this code is coordinating active tabs, liveness, foreground process data,
  shell path, and close-confirm context
- that is honest host/runtime work
- it no longer looks like the best next extraction lane

### 3. Widget open/progress paths do not look like the next contradiction

Evidence:

- [terminal_widget_open.zig:46](/home/home/personal/zide/src/ui/widgets/terminal_widget_open.zig#L46)
  locks the shell and reads `session.core.hyperlinkUri(...)`
- [terminal_widget_open.zig:80](/home/home/personal/zide/src/ui/widgets/terminal_widget_open.zig#L80)
  and [terminal_widget_open.zig:199](/home/home/personal/zide/src/ui/widgets/terminal_widget_open.zig#L199)
  lock only to copy cwd text
- [terminal_draw_surface_runtime.zig:43](/home/home/personal/zide/src/app/terminal/terminal_draw_surface_runtime.zig#L43)
  locks only to read `core.activityState()`

Current read:

- these paths already follow the intended rule:
  - shell for synchronization
  - core for immutable or semantic engine truth
- reopening them would likely be fake progress

## Bottom Line

The caller map does not point at another broad in-repo shell cleanup wave.

It points at one remaining contract-identity problem:

- hosts still enter through a shell-centered FFI handle even though most of the
  interesting truth increasingly lives on `TerminalCore`
