# Flutter Adapter Notes

Date: 2026-03-14

Purpose: record the design constraints for a future Flutter/mobile terminal
adapter so the downstream embedding work inherits the hardened native/FFI
contract instead of inventing a separate weaker path.

Status: planning authority only. No Flutter-specific ABI is being added in this
slice.

## Position

Flutter is downstream of the terminal backend bridge, not a special frontend
that gets a separate engine contract.

The native Linux GUI is still the proving ground for:
- redraw/publication semantics
- present acknowledgement
- resize/invalidation behavior
- steady-state performance discipline

The Flutter adapter should consume the same host-facing contract that now
exists for the FFI bridge:
- `poll`
- `redraw_ready` as wake-only
- `redraw_state` as authoritative redraw truth
- snapshot acquire/release
- metadata acquire/release
- scrollback acquire/release
- explicit `present_ack(...)`

## Non-Goals

The Flutter adapter should not:
- embed SDL or the native renderer into Flutter
- mirror the native widget tree or expose widget-local state
- invent a Flutter-specific redraw/publication contract
- require a second terminal core path for mobile or embedded hosts
- depend on default-framebuffer semantics from the native GUI

## Why Snapshot/Diff Transport Wins

The bridge boundary should stay above terminal publication and below host
rendering. That means Flutter should consume terminal state through structured
snapshot/history surfaces, not through exported textures or borrowed renderer
internals.

Reasons:
- Flutter already owns its own composition/presentation model.
- Exporting native textures or SDL/GL handles would make the adapter
  platform-fragile and lifecycle-hostile.
- The current FFI contract is explicit about ownership, lifetimes, redraw
  truth, and acknowledgement. That is the right engine-level boundary.
- Mobile and embedded hosts will likely need multiple render strategies over
  time, but they should not need multiple backend contracts.

The first Flutter adapter should therefore look like:
- FFI bridge -> Dart bindings -> host-side render model

not:
- native SDL/renderer surface -> Flutter texture shim

## Required Shared Contract

The Flutter adapter should inherit the same authority split documented in:
- `app_architecture/terminal/RENDER_PUBLICATION_CONTRACT.md`
- `app_architecture/terminal/FFI_BRIDGE_DESIGN.md`

Required semantics:
- published generation is backend publication truth
- acknowledged generation is host-presented truth
- `needs_redraw == (published_generation != acknowledged_generation)`
- `redraw_ready` is only a wake hint
- lifecycle/title/cwd/scrollback latest-state truth comes from
  `metadata_acquire(...)`
- structured history comes from metadata + scrollback surfaces
- copied text exports remain convenience views, not structured state authority

This is what keeps native and embedded paths aligned without forcing them onto
the same concrete renderer.

## Host Loop Shape

The future Flutter host loop should remain boring:

1. receive wake or host tick
2. call `poll(...)`
3. query `redraw_state(...)`
4. if redraw is pending:
   - acquire snapshot
   - update host-side render model
   - release snapshot
   - call `present_ack(...)` only after the host has committed the new frame
5. query `metadata_acquire(...)` when latest-state summary is needed
6. drain events for discrete change boundaries

The critical rule is:
- do not acknowledge publication at snapshot acquire time
- acknowledge only after the host has actually committed/presented the frame

That mirrors the stronger native renderer-owned present semantics already being
built on Linux.

## Mobile-Specific Constraints

The adapter should be designed with these constraints in mind:
- no assumption of PTY availability on mobile
- external byte-source mode matters more than bridge-owned PTY startup
- host-driven lifecycle suspends/resumes are normal
- memory pressure is tighter than desktop and should bias toward narrow,
  explicit surfaces
- frame pacing must cooperate with Flutter's scheduling model instead of trying
  to drive its own independent render loop

Implications:
- no-PTY host-fed mode is a first-class target, not a fallback
- bridge state surfaces must remain cheap to query repeatedly
- future diff/damage work should be evaluated partly on embedded/mobile memory
  bandwidth, not only desktop throughput

## Platform Priorities

Near term:
- polish Linux native first
- keep FFI host contract converging with native semantics
- keep no-PTY host mode healthy

Later:
- Flutter desktop adapter can prove the host-loop contract before mobile
- mobile-specific PTY/transport work should come only after the shared host
  contract is stable enough

## Reference Direction

Relevant local references:
- `reference_repos/terminals/ghostty/src/apprt/embedded.zig`
- `reference_repos/terminals/ghostty/include/ghostty.h`
- `reference_repos/terminals/wezterm/mux/src/renderable.rs`
- `reference_repos/terminals/contour/src/vtbackend/RenderBufferBuilder.h`

Takeaways:
- Ghostty is the strongest reference for a serious embedded runtime boundary.
- WezTerm is useful for separating terminal-model truth from GUI render
  consumption.
- Contour is useful for keeping render-facing state explicit and structured.

None of those justify exporting native renderer internals into the embedded
host. The better pattern is still a narrow engine contract with explicit
ownership and host-driven rendering.

## Next Adapter Preconditions

Before real Flutter adapter work starts, these should be true:
- native present path is firmly in the `kitty` / `ghostty` quality band
- FFI redraw/publication/present contract is stable and test-backed
- no-PTY host-fed flow is healthy and boring
- event/state authority splits are fully documented and reflected in smoke
  hosts

Only then should a Dart binding or Flutter-facing package be designed.
