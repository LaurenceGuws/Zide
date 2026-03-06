# Terminal FFI Event Inventory

Date: 2026-02-27

Purpose: enumerate terminal backend events and classify how they should cross the future FFI bridge.

Status: baseline inventory aligned to the shipped milestone-1 ABI in `app_architecture/terminal/FFI_EVENT_ABI.md`.

## Classification rules

Each signal should be one of:
- `snapshot-derived`: host reads it from the latest snapshot or direct getter
- `event-drain`: backend queues discrete events until host drains them
- `callback-later`: avoid in milestone 1; candidate for future wakeup/perf improvements
- `out-of-scope`: do not export in the first bridge

Milestone 1 default:
- prefer `snapshot-derived` or `event-drain`
- avoid callbacks unless the bridge cannot be practical without them

## Inventory

| Signal | Current local source | Classification | Why |
| --- | --- | --- | --- |
| Title changed | OSC title handling / session title state | `event-drain` + getter | Discrete change, useful for host window/tab titles. |
| Current working directory changed | OSC 7 / session cwd state | `event-drain` + getter | Discrete metadata change; hosts often update breadcrumbs or tabs. |
| Clipboard write received | OSC 52 write path | `event-drain` | Host must decide what to do with clipboard data. |
| Clipboard read requested | protocol/read path when supported | `out-of-scope` | Not exported in milestone 1. |
| Bell | terminal/session bell signal | `out-of-scope` | Deferred; not exported in milestone 1. |
| Child exited | PTY/process state | `event-drain` + getter | Host needs exit status and liveness updates. |
| Hyperlink open intent | hyperlink activation path | `out-of-scope` | Deferred; not exported in milestone 1. |
| Dirty/wakeup hint | dirty tracking / pending output | `callback-later` or getter | Useful for efficient hosts, but not required for milestone 1. |
| Cursor position | snapshot | `snapshot-derived` | Render state, not a discrete event. |
| Grid cells | snapshot | `snapshot-derived` | Core render/input inspection data. |
| Selection state | snapshot or getter | `snapshot-derived` | Only if preserved as core backend state. |
| Scroll offset / scrollback size | snapshot | `snapshot-derived` | View/model state, not an event. |
| Sync-update active | snapshot or getter | `snapshot-derived` | Render coordination state. |
| Process alive | getter | `snapshot-derived` or direct getter | Simple state query. |
| Window title stack semantics | internal only | `out-of-scope` | Too implementation-specific for the first bridge. |
| IME/preedit visuals | UI/widget state | `out-of-scope` | Not terminal-backend export work. |
| Hovered link / mouse hover | widget state | `out-of-scope` | UI concern. |
| Font metrics changes | renderer/widget state | `out-of-scope` | Host renderer concern. |

## Event payload candidates

Milestone 1 queued event kinds should be flat and small.

Implemented milestone-1 kinds:
- `title_changed { utf8_ptr, utf8_len }`
- `cwd_changed { utf8_ptr, utf8_len }`
- `clipboard_write { data_ptr, data_len }`
- `child_exit { exit_code, has_status }`

Notes:
- string payloads should live in the same owned event buffer returned by `event_drain`
- avoid nested allocations per event when possible
- do not expose backend-internal ids if the host cannot use them meaningfully

## Getter candidates

Simple direct getters can reduce event volume:
- `current_title`
- `current_cwd`
- `is_alive`
- `exit_status` once dead

These should complement event drains, not replace them.

Reason:
- hosts need both the latest state and the change boundary

## Notable open questions

1. Should clipboard read be synchronous or request/response?
- For milestone 1, request/response is safer.
- The backend emits a read request event.
- The host later responds with an explicit API call.

2. Should damage notifications be events?
- Not initially.
- A cheap getter or snapshot flag is enough for the first smoke host.

3. Should hyperlink activation be emitted by the backend?
- Only if activation semantics are already backend-owned.
- Hover state should remain a widget concern.

4. Should kitty image actions emit events?
- Not for milestone 1.
- Keep image state snapshot-driven if it is exported at all.

## Milestone 1 minimum set

Current required/shipped:
- title changed
- cwd changed
- clipboard write
- child exit

Deferred but likely useful:
- clipboard read request
- bell
- open-uri intent

Still deferred:
- wake callbacks
- advanced damage events
- renderer-affine or widget-affine events
