## Handoff

This file is a high-level session entrypoint for contributors and agents. It is
not a progress log and should stay brief.

### Current Focus

- Terminal is now the active invention lane on `main`.
- The current mission is not incremental cleanup around the existing center. The
  current mission is a ruthless architecture campaign against every terminal
  seam that does not read as:
  - engine-centered
  - loosely coupled
  - DRY
  - reference-grade
- All agent-facing terminal focus should now assume:
  - old fallback paths are guilty until proven necessary
  - compatibility residue is not a virtue
  - broad session facades are not sacred
  - native host convenience must not masquerade as engine truth
- The native terminal path is the proving ground and the battlefield:
  - it must become the cleanest reference host over one engine truth
  - it must not remain a privileged semantic path over FFI/embedded hosts
- The quality bar is aggressive:
  - the architecture should not merely keep up with `kitty` / `ghostty`
  - it should make strong terminal maintainers stop and stare at first glance
- Work outside this lane is deferred by default unless it directly unblocks the
  terminal architecture campaign.

### Current Direction

- Work sequentially, not timidly:
  - identify one structural lie
  - define the replacement shape
  - cut through the full affected surface area with care
  - validate hard
  - remove the old seam instead of preserving it for comfort
- Default terminal work now should be:
  - eliminate false centers around `TerminalCore`
  - dismantle `PtyTerminalRuntime` as the de facto architectural center
  - move semantic text/protocol behavior below the VT boundary where it
    belongs
  - collapse duplicated publication truth and compatibility mirrors
  - shrink native widget/render code into a pure host/presentation consumer
  - keep native and FFI aligned to one engine contract while doing all of the
    above
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
- `TerminalCore` is real, but it is still not the only obvious center.
- The broad remaining architectural enemy is not random compatibility debt. It
  is the collection of fake centers around the engine:
  - the remaining host-wrapper gravity around `PtyTerminalRuntime`, now living
    directly in `terminal_runtime.zig`
  - parser-hook text semantics above the engine boundary
  - duplicated publication/cache truth
  - oversized native widget/render coordination
- The archived `ascii-rain` lane is no longer the active driver. It should not
  dictate current architecture focus.
- The native present lane still contains a live migration seam:
  - some cleared frames still submit with `terminal_texture_draws=0`
  - that bug remains real
  - but it is no longer the strategic center of the terminal campaign
- Flutty/FFI validation remains useful background proof:
  - the contract is already broad enough to support a serious host surface
  - the bigger remaining gap is ownership clarity, not missing host API volume
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
  - `docs/review/TERMINAL_NATIVE_ARCHITECTURAL_SCRUTINY_2026-03-31.md`
  - `app_architecture/terminal/TERMINAL_ARCHITECTURE_COMPARISON.md`
  - `docs/review/TERMINAL_CORE_ARCHITECTURE_REVIEW_2026-03-10.md`
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
