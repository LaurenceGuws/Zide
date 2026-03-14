# Next Beta Release Notes Template

Use this as the starting point for the next prerelease notes.

The first paragraph should read like a technical checkpoint, not a changelog.
This release is the first public checkpoint of the rewritten VT/render path, so
the notes should explain that architecture first and then name the most
important compatibility wins.

## Title

`<tag> - First VT/Render Rewrite Beta`

## Summary

`<tag>` is the first public beta built on Zide's rewritten VT/render path.
This is the checkpoint where the terminal stopped treating the default
framebuffer as the normal composition surface and moved to a renderer-owned
scene target with explicit renderer-owned present acknowledgement. The result is
a much cleaner terminal presentation path on Linux native, plus a round of
post-rewrite bug hunting that closed several real compatibility and latency
gaps.

## Technical Breakdown

### Renderer / Present Path

- Main terminal composition now happens in a renderer-owned scene target.
- The default framebuffer is now just the final present sink or a degraded
  fallback, not the normal architectural path.
- Terminal present retirement no longer hangs directly off widget-local draw
  completion; it is tied to renderer-owned successful submission.
- The old rewrite war-room probe matrix has been pruned back so the live
  runtime reflects the intended architecture instead of the investigation
  scaffolding.

### Hardening Wins

- Codex inline resumed history now retires into real primary scrollback instead
  of collapsing into the visible pre-viewport band.
- Zig `std.Progress` redraw now rewrites in place correctly; synchronized redraw
  plus reverse-index handling no longer leave stale blocks appended at the
  bottom.
- Focused native input latency is materially tighter after replacing blind
  focused-idle sleep with event-aware wake waiting, while steady-state CPU stays
  in the good pre-rewrite range.
- Recent native validation also holds on the rewritten path for the current main
  workload set, including `nvim` and `btop`.

### FFI / Host Contract

- The FFI host contract has been tightened to match the stronger native redraw /
  publication / present ownership model.
- Hosts now have explicit publication truth, acknowledgement truth, and redraw
  truth instead of relying on blurrier wake/event semantics alone.
- This keeps the native GUI as the proving ground while making the eventual
  embedded / Flutter host path more honest.

## Current Quality Bar

This beta should be described honestly:

- Zide is now much closer to a clean production-oriented architecture than it
  was before the rewrite.
- It is a real terminal with credible production aspirations, not a toy shell
  wrapper.
- It is still a beta and should not be framed as full parity with `kitty` or
  `ghostty` yet.
- The current project phase is post-rewrite bug hunting and hardening on top of
  the rewritten path.

## Keep Out Of The Notes

- Do not dump a long commit inventory.
- Do not emphasize old war-room env toggles, removed probes, or internal debug
  cleanup unless it materially changes the live runtime story.
- Do not claim final reference-terminal parity.

## Release Checklist

- Replace `<tag>` with the actual release tag.
- Confirm the release asset list matches what was published.
- Mention only the highest-value compatibility wins from that checkpoint.
- Keep the final notes short enough to scan quickly.
