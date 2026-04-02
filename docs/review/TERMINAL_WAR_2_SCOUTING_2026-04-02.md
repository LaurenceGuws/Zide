# Terminal War 2 Scouting 2026-04-02

## Purpose

Capture the first serious War 2 scouting pass from:

- live Zide code
- current terminal authority docs
- strongest local `dev_references`

This is not another cleanup queue.
It is the decision memo for what War 2 should actually attack.

## Inputs Reviewed

Local authority:

- `docs/review/TERMINAL_WAR_2_RERANK_2026-04-02.md`
- `app_architecture/terminal/VT_CORE_DESIGN.md`
- `app_architecture/terminal/TERMINAL_ARCHITECTURE_COMPARISON.md`
- `docs/review/CURRENT_ARCHITECTURE_RERANK_2026-04-02.md`
- `docs/review/TERMINAL_HOST_CONTRACT_REVIEW_2026-04-02.md`
- `app_architecture/RENDERER_SCENE_PUBLICATION_CONTRACT.md`
- `docs/todo/terminal/wayland_present.md`

Live code hotspots:

- `src/terminal/core/publication/terminal_publication.zig`
- `src/terminal/core/workspace.zig`
- `src/terminal/core/workspace_host.zig`
- `src/terminal/core/session/runtime.zig`
- `src/app/terminal/visible_terminal_frame_hooks_runtime.zig`
- `src/app/terminal/terminal_draw_surface_runtime.zig`
- `src/app/present_feedback_runtime.zig`
- `src/ui/widgets/terminal_widget.zig`
- `src/ui/widgets/terminal_widget_draw.zig`
- `src/ui/renderer/scene_frame_runtime.zig`

Reference pressure:

- Ghostty:
  - `src/terminal/Terminal.zig`
  - `src/terminal/Screen.zig`
  - `src/termio/Termio.zig`
  - `src/termio/Options.zig`
  - `src/Surface.zig`
  - `include/ghostty/vt.h`
- Foot:
  - `render.c`
  - `wayland.c`
- Kitty:
  - `glfw/wl_window.c`
- Rio:
  - `rio-window/src/window.rs`
  - `rio-window/src/platform_impl/linux/wayland/window/*`
  - `frontends/rioterm/src/application.rs`

## High-Level Read

War 1 succeeded.

The current question is no longer:

- "what small seam should we flatten next?"

The current question is:

- "what is the next top-level reason the terminal system does not yet read as
  reference-grade at first glance?"

Two serious War 2 candidates emerged.

## Candidate A: Missing Engine-Owned Host-State Boundary

This is the strongest structural candidate.

### Read

Zide still does not have one unmistakable engine-owned host-state boundary.

Compared to Ghostty’s `Termio -> Terminal/Screen -> Surface` read, host-visible
terminal truth in Zide is still spread across:

- `TerminalCore`
- `terminal_publication.zig`
- `workspace.zig` / `workspace_host.zig`
- widget-side presentation handoff

The heaviest residue in that story is `terminal_publication.zig`, which still
reads like a second center for terminal lifecycle truth rather than a narrow
publication/export bridge.

### Why It Matters

This weakens first-glance architecture quality in two ways:

1. the native path still appears to derive host truth from multiple adjacent
   owners instead of consuming one obvious boundary
2. the embeddable-host story still looks like an orchestration product rather
   than a clean engine-facing contract

### Strongest Hotspots

- `src/terminal/core/publication/terminal_publication.zig`
  - `snapshot(...)`
  - `prepareLatestPresentation(...)`
  - `frameState(...)`
  - `completePresentationFeedback(...)`
- `src/terminal/core/workspace.zig`
  - `activeFrameState(...)`
  - poll metrics and counters living beside active-session truth
- `src/terminal/core/workspace_host.zig`
  - host packaging still iterates raw workspace/session state directly
- `src/ui/widgets/terminal_widget.zig`
  - widget still participates in presentation generation choreography

## Candidate B: Present/Render Correctness Discipline

This is the strongest correctness candidate.

### Read

War 1 flattened many ownership lies, but Zide still carries a live present
correctness seam:

- a frame can clear the authoritative scene target
- submit successfully
- and still omit the retained terminal re-blit

That is a stronger immediate embarrassment than many remaining ownership
questions because the best references are stricter here:

- Foot on damage/commit/presentation
- Rio and WezTerm on explicit pre-present discipline
- Kitty on backend-owned swap/commit truth

### Why It Matters

If the submitted scene cannot prove that the currently authoritative terminal
surface was actually reassembled before present, then present acknowledgement
and publication retirement remain too weak regardless of recent ownership
improvements.

### Strongest Hotspots

- `src/ui/widgets/terminal_widget_draw.zig`
  - retained terminal texture update / reuse / clear interaction
- `src/ui/renderer/scene_frame_runtime.zig`
  - scene clear and submit discipline
- `src/terminal/core/publication/terminal_publication.zig`
  - presentation retirement currently gates on `texture_updated` or
    `dirty == .none`, which is weaker than a full scene-submission invariant
- `src/app/present_feedback_runtime.zig`
  - present completion still trusts widget-staged feedback as submission truth

## Current Judgment

If War 2 is judged structurally, Candidate A wins.

If War 2 is judged by the strongest remaining live risk and reference pressure,
Candidate B may win.

That means War 2 should not start with code.
War 2 should start with a short, explicit decision review between:

1. structural clarity:
   - recenter host-facing terminal truth behind one explicit boundary
2. present discipline:
   - define the exact invariant required before native terminal presentation
     can be acknowledged and retired

## Recommended Immediate Review Question

Which is the truer next war:

- "build one obvious engine-owned host-state boundary"

or:

- "make submitted terminal present truth airtight before any further
  architectural expansion"

## Sub-Agent Seed Prompts

These are the preferred seed prompts for the next cross-reference wave.

### 1. Engine-Owned Host Boundary

You are reviewing Zide terminal architecture against Ghostty for War 2.
Determine whether Zide still lacks one unmistakable engine-owned host-state
boundary.

Read only what you need from:

- `app_architecture/terminal/VT_CORE_DESIGN.md`
- `app_architecture/terminal/TERMINAL_ARCHITECTURE_COMPARISON.md`
- `docs/review/TERMINAL_WAR_2_RERANK_2026-04-02.md`
- `docs/review/TERMINAL_WAR_2_SCOUTING_2026-04-02.md`
- `src/terminal/core/publication/terminal_publication.zig`
- `src/terminal/core/workspace.zig`
- `src/terminal/core/workspace_host.zig`
- `src/terminal/core/session/runtime.zig`
- `src/ui/widgets/terminal_widget.zig`

Compare against:

- `dev_references/terminals/ghostty/src/terminal/Terminal.zig`
- `dev_references/terminals/ghostty/src/terminal/Screen.zig`
- `dev_references/terminals/ghostty/src/termio/Termio.zig`
- `dev_references/terminals/ghostty/src/Surface.zig`
- `dev_references/terminals/ghostty/include/ghostty/vt.h`

Output only:

1. strongest remaining structural gap
2. why Ghostty still looks cleaner
3. 3-5 concrete Zide hotspots
4. one next review question

### 2. Publication As Parallel Truth Center

You are reviewing whether `terminal_publication.zig` is still a parallel truth
center instead of a narrower publication/export bridge.

Read only what you need from:

- `src/terminal/core/publication/terminal_publication.zig`
- `src/terminal/core/publication/view_cache.zig`
- `src/terminal/core/publication/render_cache.zig`
- `src/terminal/core/terminal_core.zig`
- `src/terminal/core/session/runtime.zig`
- `src/ui/widgets/terminal_widget.zig`
- `src/app/terminal/terminal_frame_pacing_runtime.zig`

Output only:

1. does publication still read like a second terminal center, yes/no
2. strongest evidence
3. 3-5 concrete hotspots
4. one next review question

### 3. Native Host Aggregate Truth

You are reviewing whether native host frame driving still treats `workspace`
as semantic runtime truth instead of consuming a sharper host contract.

Read only what you need from:

- `src/terminal/core/workspace.zig`
- `src/terminal/core/workspace_host.zig`
- `src/terminal/core/workspace_polling.zig`
- `src/app/terminal/terminal_poll_runtime.zig`
- `src/app/terminal/terminal_frame_pacing_runtime.zig`
- `src/app/frame_render_idle_runtime.zig`
- `app_architecture/terminal/TERMINAL_ARCHITECTURE_COMPARISON.md`

Compare against Ghostty `Surface` / `Termio`.

Output only:

1. does a top-level native host false center still dominate
2. if yes, where
3. 3-5 concrete hotspots
4. one next review question

### 4. Present Invariant Review

You are reviewing whether native terminal presentation acknowledgement is gated
by a strong enough invariant.

Read only what you need from:

- `docs/todo/terminal/wayland_present.md`
- `app_architecture/RENDERER_SCENE_PUBLICATION_CONTRACT.md`
- `src/ui/widgets/terminal_widget_draw.zig`
- `src/ui/renderer/scene_frame_runtime.zig`
- `src/terminal/core/publication/terminal_publication.zig`
- `src/app/present_feedback_runtime.zig`
- `src/app/terminal/terminal_draw_surface_runtime.zig`

Compare against:

- `dev_references/terminals/foot/render.c`
- `dev_references/terminals/foot/wayland.c`
- `dev_references/terminals/rio/rio-window/src/window.rs`
- `dev_references/terminals/rio/rio-window/src/platform_impl/linux/wayland/window/*`
- `dev_references/terminals/kitty/glfw/wl_window.c`

Output only:

1. strongest missing present invariant
2. why it matters
3. 3-5 concrete Zide hotspots
4. one next review question

### 5. Widget Retained Surface Truth

You are reviewing whether widget-local retained terminal texture state is still
honest local render state or whether it still hides terminal semantic truth.

Read only what you need from:

- `src/ui/widgets/terminal_widget.zig`
- `src/ui/widgets/terminal_widget_draw.zig`
- `src/terminal/core/publication/terminal_publication.zig`
- `src/app/present_feedback_runtime.zig`

Output only:

1. honest local render state or hidden semantic center
2. strongest evidence
3. 3-5 concrete hotspots
4. one next review question

### 6. FFI vs Native Contract Convergence

You are reviewing whether native and FFI now genuinely converge on one engine
contract or whether native still keeps privileged semantic pathways.

Read only what you need from:

- `app_architecture/terminal/TERMINAL_ARCHITECTURE_COMPARISON.md`
- `src/terminal/ffi/core_api.zig`
- `src/terminal/ffi/host_api.zig`
- `src/terminal/core/publication/terminal_publication.zig`
- `src/terminal/core/workspace.zig`
- `src/app/terminal/`

Output only:

1. does native still hold privileged terminal semantics, yes/no
2. strongest evidence
3. 3-5 concrete hotspots
4. one next review question

## Bottom Line

The next terminal war should not start from cleanup momentum.

It should start from one explicit choice between:

- structural recentering around a single engine-owned host boundary

and

- present/render correctness discipline as the strongest remaining truth gap
