## Handoff

This file is a high-level session entrypoint for contributors and agents. It is
not a progress log and should stay brief.

### Current Focus

- The only default architecture focus is now VT maturity purity.
- Treat
  [VT_MATURITY_PURITY_CAMPAIGN.md](/home/home/personal/zide/app_architecture/terminal/VT_MATURITY_PURITY_CAMPAIGN.md)
  as the primary authority for what work counts.
- Treat
  [VT_MATURITY_COMPLETION_LIST.md](/home/home/personal/zide/app_architecture/terminal/VT_MATURITY_COMPLETION_LIST.md)
  as the numbered exit criteria for the same scrutiny war.
- Treat VT maturity purity as one continuous scrutiny war, not a chain of
  small wars with new names every few commits.
- The standard is no longer "find another cleanup seam."
- The standard is:
  - make `TerminalCore` feel unquestionably sufficient and mature as the VT
    library center
  - keep `TerminalRuntimeShell` obviously incidental
  - normalize the host-facing VT contract until the remaining gap versus
    Ghostty/WezTerm is maturity/taste, not ownership ambiguity
- Work outside this lane is deferred by default unless it directly unblocks VT
  maturity purity.

### Current Direction

- The active terminal baseline is much stronger now:
  - `TerminalSession` is gone
  - `PtyTerminalRuntime` is gone
  - key input semantics, resize semantics, and mutation ownership are cleaner
- The remaining VT work is now deeper and stricter:
  - no seam-hopping
  - no shell-thinning theater
  - no renaming every front as its own war
  - no reopening solved local lanes by momentum
  - no code unless one named maturity contradiction is explicit first
- Preferred execution style:
  - no compatibility theater
  - no fallback path without a deletion story
  - no broad helper extraction that leaves the same library story intact
  - no sentimental attachment to existing file centers

### Current State

- `zide-vt` is now credibly extractable, but still not near plug-and-play
  parity with `libghostty-vt`.
- The remaining gap is no longer obvious architecture sludge.
- The remaining gap is now:
  - `TerminalCore` sufficiency
  - public contract normalization
  - overall library-object maturity
- Recent VT lanes that should stay paused unless a fresh named contradiction
  appears:
  - input semantics
  - public resize
  - viewport/selection mutation
  - `host_queries`
- Current implementation authority lives in the VT maturity docs, not in older
  war framing or repo-wide reranks.
- We stay on this one war until we can honestly claim our VT contract quality
  is no longer clearly behind the peer references that matter.

### Where To Look

- VT maturity campaign authority:
  - `app_architecture/terminal/VT_MATURITY_PURITY_CAMPAIGN.md`
  - `app_architecture/terminal/VT_MATURITY_COMPLETION_LIST.md`
  - `app_architecture/terminal/VT_CORE_DESIGN.md`
  - `app_architecture/terminal/TERMINAL_ARCHITECTURE_COMPARISON.md`
  - `docs/todo/terminal/vt_core_rearchitecture.md`
  - `docs/review/VT_MATURITY_FULL_SCOPE_2026-04-03.md`
  - `docs/review/VT_PLUGANDPLAY_GAP_MATRIX_2026-04-03.md`
  - `docs/review/VT_SPRINT_STOP_MARKER_2026-04-03.md`
- Strongest current comparison pressure:
  - `dev_references/terminals/ghostty/src/terminal/Terminal.zig`
  - `dev_references/terminals/ghostty/include/ghostty/vt.h`
  - `dev_references/terminals/wezterm/term/src/terminal.rs`
- Repo workflow and doc ownership:
  - `AGENTS.md`
  - `docs/WORKFLOW.md`
  - `docs/INDEX.md`

### Constraints

- Keep this file high-level only.
- Detailed progress belongs in the owning files under `docs/todo/` and the relevant `app_architecture/` authority docs.
- Do not work directly on `main`; treat it as merge-only and start active work on a branch from current `main`.
- `.zide.lua` logging is agent-owned and should stay minimal and bug-scoped.
- No CI; validation is local build/test plus manual verification.
