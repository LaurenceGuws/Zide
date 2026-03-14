## Handoff

### Current Focus
- Primary active product lane: post-rewrite terminal quality hardening and bug hunting on Linux native.
- Quality bar: native terminal behavior must land in the same band as `kitty` / `ghostty` for correctness, smoothness, compatibility, and steady-state cost.
- Native GUI is still the proving ground for the embedded engine contract. Keep the native path honest first, then catch the FFI/embedded host path up to the same redraw/publication/present semantics, and only then converge toward one shared host-facing path where practical.

### Current Direction
- The initial VT/present rewrite is no longer the main invention lane on `main`.
- Current work should default to:
  - bug hunting on top of the rewritten VT/render seams
  - compatibility fixes against real workloads and terminals
  - native/FFI contract convergence where it materially improves quality
- The chosen native renderer architecture is already set:
  - keep narrow retained widget-local targets where they pay off
  - use a renderer-owned authoritative scene target
  - treat the default framebuffer as a one-frame present sink only

### Current State
- The scene-owned composition path is active on `main` and the initial render-seam redesign is effectively landed.
- `nvim` scrolling/cursorline behavior is currently good on the rewritten path.
- `btop` shaded-block rendering is currently good on the rewritten path.
- Focused native input latency is currently much tighter again after replacing blind focused-idle sleep with event-aware wake waiting; steady-state CPU stayed in the good pre-rewrite band on the user validation pass.
- `rain` is no longer part of the active renderer/present validation matrix. Treat it as deferred special-character / visual-polish follow-up work only; do not let it reopen redraw/publication investigation.
- Recently closed native compatibility bugs:
  - Codex inline resume history now retires into real primary scrollback on the rewritten path.
  - Zig `std.Progress` redraw now rewrites in place correctly; `ESC M` / reverse-index dispatch is no longer dropped during synchronized progress updates.
- The current active implementation authority is the terminal architecture/docs, not ad hoc investigation notes.

### Near-Term Plan
- Use the rewritten VT/render path as the baseline and close real bugs against it.
- Keep tightening the FFI/embedded contract only where it materially matches the stronger native redraw/publication/present semantics.
- Long-term intent remains one strong engine contract serving both native GUI and embedded/mobile hosts where that unification is architecturally honest.

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
