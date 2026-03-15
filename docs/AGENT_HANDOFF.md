## Handoff

This file is a high-level session entrypoint for contributors and agents. It is
not a progress log and should stay brief.

### Current Focus

- Primary active product lane: post-rewrite terminal quality hardening on Linux native.
- Quality bar: native terminal behavior should land in the same band as `kitty` / `ghostty` for correctness, smoothness, compatibility, and steady-state cost.
- Native GUI remains the proving ground for the engine contract. Keep native honest first, then bring the FFI/embedded path up to the same redraw/publication/present semantics.

### Current Direction

- The main VT/present rewrite is no longer the active invention lane on `main`.
- Default work now should be:
  - bug hunting on top of the rewritten VT/render seams
  - compatibility fixes against real workloads
  - native/FFI contract convergence where it materially improves quality
- Renderer architecture direction is already set:
  - narrow retained widget-local targets where they pay off
  - renderer-owned authoritative scene target
  - default framebuffer as present sink only

### Current State

- The scene-owned composition path is active on `main`.
- Rewrite-era present/debug baggage has been materially reduced from the live path.
- Native compatibility has recently improved on real workloads including `nvim`, `btop`, Codex inline history, and Zig `std.Progress`.
- Current implementation authority lives in the terminal architecture docs and owning todos, not in stale investigation notes.

### Where To Look

- Present implementation authority:
  - `app_architecture/terminal/WAYLAND_PRESENT_IMPLEMENTATION_PLAN.md`
- Terminal core architecture and active queue:
  - `app_architecture/terminal/VT_CORE_DESIGN.md`
  - `app_architecture/terminal/vt_core_rearchitecture_todo.md`
  - `app_architecture/terminal/MODULARIZATION_PLAN.md`
- Repo workflow and doc ownership:
  - `AGENTS.md`
  - `docs/WORKFLOW.md`
  - `docs/INDEX.md`

### Constraints

- Keep this file high-level only.
- Detailed progress belongs in the owning todo files and `app_architecture/` docs.
- `main` is the default branch unless isolation materially reduces risk.
- `.zide.lua` logging is agent-owned and should stay minimal and bug-scoped.
- No CI; validation is local build/test plus manual verification.
