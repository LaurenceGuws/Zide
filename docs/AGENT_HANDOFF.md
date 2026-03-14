## Handoff

### Current Focus
- Primary active product lane: terminal and present-path quality on Linux native.
- Quality bar: native terminal behavior must land in the same band as `kitty` / `ghostty` for correctness, smoothness, and steady-state cost.
- Native GUI is the proving ground for the embedded engine contract. Finish the native path cleanly first, then catch the FFI/embedded host path up to the same redraw/publication/present semantics, and only then converge toward one shared host-facing path where practical.

### Current Direction
- The Wayland present-path redesign is active on `main`.
- Chosen architecture:
  - keep narrow retained widget-local targets where they pay off
  - add a renderer-owned authoritative scene target
  - treat the default framebuffer as a one-frame present sink only
- Present acknowledgement is being moved under renderer ownership instead of relying on widget-local draw completion or ambiguous default-framebuffer behavior.

### Current State
- The scene-owned composition path is active on `main`.
- `nvim` scrolling/cursorline behavior is currently good on the new path.
- `btop` shaded-block rendering is currently good on the new path.
- `rain` is improved but still considered a narrower follow-up lane; do not let it reopen the older broad redraw/publication investigation.
- The current active implementation authority is the phased present-plan doc, not ad hoc investigation notes.

### Near-Term Plan
- Finish the current native present-path ownership work cleanly.
- After that, review and tighten the FFI/embedded contract so it matches the stronger native redraw/publication/present semantics.
- Long-term intent: one strong engine contract serving both native GUI and embedded/mobile hosts where that unification is architecturally honest.

### Where To Look
- Native present implementation authority:
  - `app_architecture/terminal/WAYLAND_PRESENT_IMPLEMENTATION_PLAN.md`
- Present redesign design docs:
  - `app_architecture/terminal/WAYLAND_PRESENT_DESIGN_BRIEF.md`
  - `app_architecture/terminal/WAYLAND_PRESENT_TECHNICAL_WRITEUP.md`
- Terminal core architecture and active queue:
  - `app_architecture/terminal/VT_CORE_DESIGN.md`
  - `app_architecture/terminal/vt_core_rearchitecture_todo.yaml`
  - `app_architecture/terminal/MODULARIZATION_PLAN.md`

### Constraints
- Keep this handoff high-level only. Detailed progress belongs in the todo and `app_architecture/` docs.
- `main` is the default branch unless isolation materially reduces risk.
- `.zide.lua` logging is agent-owned and should stay minimal and bug-scoped.
- No CI; validation is local build/test plus manual verification.
