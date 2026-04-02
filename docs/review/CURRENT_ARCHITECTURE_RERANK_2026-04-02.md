# Current Architecture Re-Rank 2026-04-02

## Purpose

Re-rank the current architectural pain points after the last two weeks of
terminal and renderer cleanup.

This is not a historical audit.
It is a current-state judgment based on the live code.

## Current Read

The repo is materially healthier than it was at the start of the last campaign.

The biggest remaining problem is no longer renderer-root residue.
It is terminal publication/native coordination and the larger engine-centered
clarity story around it.

The biggest mistake from this point would be to keep grinding the same review
queues after they have already yielded their strongest cuts.

The correct move now is:

- close or pause review lanes that are clearly thinning out
- re-rank from live code
- open the next review only where a real center-of-gravity problem still exists

## Ranked Pain Points

### 1. Terminal publication/native coordination is still the top pain point

Why it still wins:

- `src/terminal/core/publication/terminal_publication.zig` is still the
  heaviest terminal center outside the engine itself.
- native widget/frame/poll code is cleaner now, but terminal publication state
  still drives too much host behavior shape.
- recent work improved the situation, but it also clarified that the remaining
  problem is now about contract shape, not just thin wrappers.

Evidence from recent improvements:

- widget capture refresh moved to publication owner
- terminal presentation staging left app state
- widget handoff prep moved to publication owner
- submission feedback policy moved to publication owner
- published-generation change checks moved to publication owner
- frame pressure summary moved to workspace owner

Current judgment:

- this lane is still the highest-payoff terminal battlefield
- but the easy `VTCORE-05` wins are mostly gone
- the next review here should target the broader publication contract, not more
  tiny helper moves

### 2. Terminal engine-centered clarity is still the broadest structural issue

Why it is still near the top:

- `VTCORE-01` is not finished just because `terminal_runtime.zig` got smaller
- the system is cleaner, but the architecture still needs a sharper “one engine
  truth” read across native, workspace, poll/frame pacing, and publication
  consumers

Current judgment:

- the worst fake-center gravity is much lower than before
- but terminal still has the largest repo-wide architectural pressure
- the next good terminal review should likely inspect the combined
  engine/publication/workspace/native contract instead of one file in isolation

### 3. Renderer lane is no longer the top problem

Why it dropped:

- `renderer.zig` now reads much closer to render-core state
- host scene assembly and present feedback were moved to owners
- retained-surface forwarding shells and one-hop bounces were removed
- the remaining renderer issues are narrower and less embarrassing at first
  glance

Current judgment:

- renderer review is not closed forever
- but it is no longer where the biggest architectural embarrassment lives
- continue only for clear new lies or correctness bugs

### 4. Scene/publication convergence remains important, but is now secondary

Why:

- the renderer scene/publication contract still matters
- but the code now suggests it is a convergence project, not the repo’s worst
  current architecture wound

Current judgment:

- keep this lane active as design authority
- do not treat it as the default battlefield unless a new large seam appears

### 5. Wayland/native present bugs remain tactical work, not the strategic center

Why:

- the present path still has live correctness risk
- but those bugs are no longer the largest architecture problem

Current judgment:

- fix as bugs when needed
- do not let this lane dictate architecture priority

## Review Lanes To Pause Or Close

### Pause: renderer root scrutiny as the default lane

Reason:

- the strongest renderer-root cuts already landed
- continuing by default is likely to create cosmetic repacking instead of real
  structural improvement

### Pause: tiny `VTCORE-05` helper hunting

Reason:

- publication/native coordination still matters
- but the last few cuts show that the lane is thinning
- the next worthwhile step should be a fresh, broader publication-contract
  review instead of more one-function ownership nudges

## Next Recommended Reviews

### 1. Terminal publication contract re-review

Question:

- what should the native widget/workspace/frame pacing path consume as the
  authoritative publication contract now?

Target:

- replace raw generation/publication coordination patterns with one cleaner
  owner-shaped contract where possible

### 2. Terminal engine/publication/native boundary review

Question:

- after the recent cuts, what still prevents the native terminal path from
  reading like the cleanest host over one engine truth?

Target:

- review the combined ownership story across:
  - `src/terminal/core/publication/`
  - `src/terminal/core/workspace.zig`
  - `src/app/terminal/`
  - `src/ui/widgets/terminal_widget.zig`

### 3. Fresh renderer convergence review, but only after terminal re-rank work

Question:

- did the renderer campaign actually leave one cleaner scene/present host, or
  did it just reduce visible clutter?

Target:

- validate the current renderer/scene/publication story from the live codebase,
  not from the older scrutiny assumptions

## Bottom Line

The review work did make the implementation better.

The key improvements are real:

- renderer center is materially more honest
- terminal widget/app staging is materially cleaner
- publication owner authority is materially stronger

But the remaining biggest pain point is still terminal architecture, especially
publication/native contract shape.

So the right next move is not more random cleanup.
It is a fresh terminal-centered re-review of the current publication/engine/host
contract.
