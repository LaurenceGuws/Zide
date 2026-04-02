## Handoff

This file is a high-level session entrypoint for contributors and agents. It is
not a progress log and should stay brief.

### Current Focus

- Terminal War 3 should be considered closed.
- The next default architecture battlefield is now renderer / scene /
  publication convergence.
- Terminal remains important, but the next terminal step is a deeper deliberate
  design question, not the default implementation-first lane.
- The quality bar is still ruthless: every terminal seam must read as:
  - engine-centered
  - loosely coupled
  - DRY
  - reference-grade
- All agent-facing architecture focus should now assume:
  - old fallback paths are guilty until proven necessary
  - compatibility residue is not a virtue
  - broad session facades are not sacred
  - native host convenience must not masquerade as engine truth
  - recently cleaned local seams must not be reopened just for momentum
- The quality bar is aggressive:
  - the architecture should not merely keep up with `kitty` / `ghostty`
  - it should make strong terminal maintainers stop and stare at first glance
- Work outside this lane is deferred by default unless it directly unblocks the
  current architecture campaign.

### Current Direction

- The next default war is renderer / scene / publication convergence:
  - generic subsystem publication
  - cleaner host scene assembly
  - renderer-owned scene truth without product-shaped APIs
- Terminal follow-up work should now be:
  - paused unless a fresh live bug appears, or
  - explicitly framed as a deeper design step around `TerminalCore` vs
    `TerminalSession`
- Preferred execution style:
  - no compatibility theater
  - no fallback path without a deletion story
  - no broad helper extraction that leaves the old ownership model intact
  - no sentimental attachment to existing file centers
- Renderer/present rules remain:
  - renderer-owned authoritative scene target
  - default framebuffer as present sink only
  - no reopening framebuffer-as-truth thinking under any new name

### Current State

- The scene-owned composition path is active on `main`.
- Terminal War 3 materially improved the terminal library-boundary story.
- The remaining terminal gap is now narrower and more ambiguous:
  - whether `TerminalCore` should become a more fully sufficient library object
    than "dominant field inside `TerminalSession`"
- The stronger immediate architecture question is now renderer-side:
  - can subsystem publication, host frame assembly, and scene composition be
    made to read like one generic scene/publication model instead of a cleaner
    transitional mix?
- The archived `ascii-rain` lane is no longer the active driver. It should not
  dictate current architecture focus.
- The reopened present omission lane should now be treated as closed unless a
  fresh live repro proves otherwise.
- Flutty/FFI validation remains useful background proof:
  - the contract is already broad enough to support a serious host surface
  - the bigger remaining gap is ownership clarity at the library center, not
    missing host API volume
- Current implementation authority lives in the terminal architecture docs and
  owning todos, not in stale bug lanes or historical cleanup assumptions.
- Working model for terminal cuts now:
  - identify the structural lie
  - design the replacement
  - cut through the real surface area
  - validate hard
  - delete the old center

### Where To Look

- Linux native catch-up queue:
  - `docs/todo/linux/implementation.md`
- Terminal rendering correctness / present migration cleanup:
  - `docs/todo/terminal/wayland_present.md`
  - `app_architecture/RENDERER_SCENE_PUBLICATION_CONTRACT.md`
- Editor implementation authority:
  - `app_architecture/editor/DESIGN.md`
  - `app_architecture/RUNTIME_ISOLATION_AND_RESOURCE_MANAGEMENT.md`
  - `docs/todo/editor/README.md`
  - `docs/todo/editor/app_baseline.md`
- Present implementation authority:
  - `app_architecture/terminal/present/WAYLAND_DESIGN_BRIEF.md`
  - `app_architecture/terminal/present/WAYLAND_TECHNICAL_WRITEUP.md`
- Present execution queue:
  - `docs/todo/terminal/wayland_present.md`
- Terminal core architecture and active queue:
  - `app_architecture/terminal/VT_CORE_DESIGN.md`
  - `docs/todo/terminal/vt_core_rearchitecture.md`
  - `docs/review/TERMINAL_WAR_3_CLOSURE_2026-04-02.md`
  - `docs/review/TERMINAL_POST_WAR_3_RERANK_2026-04-02.md`
  - `docs/review/POST_WAR_3_REPO_RERANK_2026-04-02.md`
  - `docs/review/TERMINAL_NATIVE_ARCHITECTURAL_SCRUTINY_2026-03-31.md`
  - `app_architecture/terminal/TERMINAL_ARCHITECTURE_COMPARISON.md`
  - `docs/review/TERMINAL_CORE_ARCHITECTURE_REVIEW_2026-03-10.md`
- Renderer / scene convergence authority:
  - `app_architecture/RENDERER_SCENE_PUBLICATION_CONTRACT.md`
  - `docs/todo/ui/rendering_scrutiny.md`
  - `docs/review/SDL_GL_RENDERER_AUDIT_2026-04-02.md`
- Repo workflow and doc ownership:
  - `AGENTS.md`
  - `docs/WORKFLOW.md`
  - `docs/INDEX.md`
 - Active Windows shell docs:
   - `app_architecture/windows/EXPLORER_COMMAND_INTEGRATION.md`
   - `docs/todo/windows/implementation.md`
 - Grammar/setup follow-up if bootstrapping a new machine:
   - `app_architecture/editor/TREE_SITTER_REPO_BOUNDARY.md`
   - `docs/todo/editor/treesitter_repo_extraction.md`
   - sibling repo `../zide-tree-sitter`

### Constraints

- Keep this file high-level only.
- Detailed progress belongs in the owning files under `docs/todo/` and the relevant `app_architecture/` authority docs.
- Do not work directly on `main`; treat it as merge-only and start active work on a branch from current `main`.
- `.zide.lua` logging is agent-owned and should stay minimal and bug-scoped.
- No CI; validation is local build/test plus manual verification.
