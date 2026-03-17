# Terminal Boundary Smell Checklist

Purpose: catch the class of terminal bugs that do not look wrong in a small
diff, but gradually create engine/host/chrome boundary confusion and then
produce unstable behavior.

This is a review aid, not a historical investigation note.

## Core Rule

For each new helper, state, or formatter, classify it first:

- engine truth
- bridge convenience
- host policy
- app/widget chrome

If a change spans more than one of those without an explicit seam, that is the
smell.

## Common Smell Patterns

### 1. Backend Convenience Masquerading As Engine Truth

Examples:

- close-confirm helper structs in core/session code
- title substitution with foreground-process labels
- host-specific clipboard or safety policy inside terminal-session APIs

Why it is dangerous:

- convenient helpers get reused
- native starts depending on them
- FFI either grows the wrong surface or drifts from native

Preferred shape:

- engine exports raw facts
- bridge or host packages policy locally

## 2. Chrome Rules Duplicated Outside Chrome Ownership

Examples:

- passive mouse wake logic duplicating scrollbar hover/hitbox rules
- widget-local hover math copied from runtime-owned chrome geometry
- visibility checks copied in input, draw, and wake code separately

Why it is dangerous:

- the feature feels flaky instead of obviously broken
- small follow-up tweaks reintroduce drift immediately

Preferred shape:

- one geometry/policy authority
- other layers ask that authority instead of re-deriving its heuristics

## 3. Presentation Formatting Built On Raw Ad Hoc Helpers

Examples:

- tab-chip strings assembled inline from title/process/progress/cwd
- status text rules encoded directly in sync glue
- backend exporting strings because host presentation is not modeled cleanly

Why it is dangerous:

- presentation rules accrete without a named model
- every new user-facing state adds more branching in glue files

Preferred shape:

- backend exports structured facts
- host owns the display model
- formatter logic stays in a small explicit presentation seam

## 4. Bridge Loops Using Broad Metadata As A Grab Bag

Examples:

- event sync code calling full metadata acquire each tick because it is easy
- bridge state changes inferred indirectly from a larger convenience surface

Why it is dangerous:

- metadata growth quietly increases hot-path work
- bridge ownership becomes less explicit

Preferred shape:

- acquire only the state the loop actually needs
- keep bridge convenience local to bridge code

## Review Questions

- Would this helper still make sense for a non-native host?
- Is this exporting a fact or a formatting decision?
- Is there already an owner for this geometry/policy?
- If this rule changes, how many files need to be updated together?
- Is this helper attractive because it is correct, or because it avoids making
  a proper seam explicit?

## Current High-Risk Hotspots

- `src/terminal/core/session_host_queries.zig`
  - acceptable for raw activity facts
  - risky for host-policy convenience packaging
- `src/app/terminal/terminal_tab_bar_sync.zig`
  - acceptable for native presentation
  - risky if it becomes the default dumping ground for every new host-visible
    terminal state
- `src/app/pointer_activity_frame.zig`
  - risky if passive wake heuristics duplicate runtime-owned chrome behavior
- `src/terminal/ffi/shared.zig`
  - acceptable for bridge-local event synthesis
  - risky if it leans on broad metadata convenience instead of explicit bridge
    state needs

## Use With

- `app_architecture/ENGINEERING.md`
- `app_architecture/terminal/VT_CORE_DESIGN.md`
- `docs/todo/terminal/widget_boundary_split.md`
