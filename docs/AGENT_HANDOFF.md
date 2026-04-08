## Handoff

This file is a high-level session entrypoint for contributors and agents. It is
not a progress log and should stay brief.

### Current Focus

- The only default architecture focus is now renderer backend contract quality.
- Treat OpenGL and Metal as the two reference implementations for the shared
  backend abstraction.
- Linux GL is the active proving ground.
- Metal is paused for live validation, not removed from the contract.
- The standard is no longer "make Metal work for one more terminal case."
- The standard is:
  - define the renderer/backend contract we actually want
  - audit the renderer/backend contract we actually have
  - use OpenGL and Metal to prove the contract is backend-neutral instead of
    backend theater
  - make a future Vulkan backend feel like straightforward backend work, not
    renderer surgery
  - keep Android/mobile pressure in mind without letting mobile implementation
    work reshape the contract too early

### Current Direction

- Capability naming is better than it used to be, but the renderer root still
  owns too much concrete GL and Metal machinery.
- The active campaign is to make OpenGL and Metal read like two
  implementations of one rendering system instead of one renderer carrying both
  implementations inside itself.
- Preferred execution style:
  - no new backend-specific leakage in shared renderer state without an
    explicit deletion story
  - no "easy later" Vulkan claims while GL and Metal still need different
    structural treatment today
  - no polishing-first drift when the shared backend contract is still weak
  - no fake neutrality through enums/capabilities when control flow still
    depends on backend-native types

Execution discipline:

- default to the renderer ticket queue:
  - `docs/todo/ui/renderer.md`
- treat queue items as executable tickets, not vague themes
- if a task does not clearly map to the renderer queue, it is probably drift

### Current State

- OpenGL is still the most complete renderer implementation.
- OpenGL is the proving ground, not the design authority.
- The terminal-present gate-2 lane is now structurally complete on GL and
  behaviorally validated there.
- Metal remains unverified against that new seam contract; treat that as
  deferred verification, not as a reason to reopen gate-2 extraction work.
- Metal is now a real live implementation, especially on the terminal lane, but
  it still depends on backend-specific state and draw descriptions carried by
  the shared renderer.
- The current repo question is no longer "can Metal present frames?"
- The current repo question is:
  - do OpenGL and Metal prove a solid backend abstraction
  - or do they prove that `src/ui/renderer.zig` still knows too much about both
    backends
- The honest answer today is still "not yet."

### Where To Look

- Target backend contract authority:
  - `app_architecture/ui/RENDER_BACKEND_CONTRACT.md`
- Current-state backend contract authority:
  - `app_architecture/ui/RENDER_BACKEND_CURRENT_STATE.md`
- Active execution queue:
  - `docs/todo/ui/renderer.md`
- Rendering journey orientation:
  - `app_architecture/ui/DEVELOPMENT_JOURNEY.md`
- Reference-pressure scan:
  - `docs/research/RENDER_BACKEND_REFERENCE_SCAN_2026-04-05.md`
- Supporting platform/renderer authority:
  - `app_architecture/platform/PLATFORM_CAPABILITY_MODEL.md`
  - `app_architecture/platform/macos/RENDER_BACKEND.md`
  - `app_architecture/platform/android/RENDER_BACKEND.md`
  - `app_architecture/RENDERER_SCENE_PUBLICATION_CONTRACT.md`

### Deferred Focuses

- VT maturity purity is deferred as the repo-wide default focus.
- When that lane is resumed, start from:
  - `docs/deferred/VT_MATURITY_FOCUS.md`
  - `app_architecture/terminal/VT_MATURITY_PURITY_CAMPAIGN.md`
  - `app_architecture/terminal/VT_MATURITY_COMPLETION_LIST.md`

### Constraints

- Keep this file high-level only.
- Detailed progress belongs in the owning files under `docs/todo/` and the
  relevant `app_architecture/` authority docs.
- Do not let old "rendering roadmap" docs outrank the renderer queue and
  contract docs.
- Do not work directly on `main`; treat it as merge-only and start active work
  on a branch from current `main`.
- Weaker agents must stay on feature branches and keep small reviewable
  checkpoint commits; `main` should only move when the lead accepts a validated
  chunk.
- `.zide.lua` logging is agent-owned and should stay minimal and bug-scoped.
- No CI; validation is local build/test plus manual verification.
