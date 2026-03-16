# Next Beta Release Notes Template

Use this as the starting point for the next prerelease notes.

The first paragraph should read like a technical checkpoint, not a changelog.
The next release is no longer "the first rewrite beta." The rewrite is already
landed. The notes should describe the current checkpoint honestly:

- terminal cleanup/restructure after the rewrite
- stronger native/FFI host-contract convergence
- narrower remaining gap against `ghostty` / `libghostty-vt`
- concrete compatibility and latency wins that changed the live product story

## Title

`<tag> - Terminal Cleanup And Host-Contract Beta`

## Summary

`<tag>` is a post-rewrite terminal checkpoint built on Zide's new VT/render
path rather than the old terminal stack. The renderer-owned scene/present path
is now the baseline, the terminal host contract is materially tighter on both
native and FFI, and the most important recent work has been cleanup,
convergence, and real compatibility/hardening wins rather than more rewrite
churn.

## Technical Breakdown

### Native Path

- Main terminal composition happens in a renderer-owned scene target.
- The default framebuffer is now only the final present sink or degraded
  fallback.
- Present acknowledgement is explicit and no longer piggybacks on blurrier
  widget-local completion assumptions.
- Native should be described as the reference host for the engine contract,
  not as a privileged semantic path that embedded hosts cannot match.

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

- The FFI host contract is now a real embeddable terminal surface, not just an
  aspirational bridge.
- Request-based metadata and snapshot acquisition now keep hot scalar reads
  cheaper while leaving strings explicit.
- Backend-owned viewport control, pending outbound input, child-exit reporting,
  and the first conservative snapshot-diff lane are now part of the live
  contract.
- Flutty has already exercised that contract as a second real host:
  the shared runtime/widget model held, the cursor-preservation workaround is
  gone, and the settled-baseline diff path now behaves coherently after the
  upstream `present_ack(...)` retirement fix.

## Current Quality Bar

This beta should be described honestly:

- Zide now has a more serious terminal architecture and host contract than the
  older release notes implied.
- It is still a beta and should not be framed as final parity with `kitty` or
  `ghostty`.
- Ghostty is still ahead on engine-centered cleanliness, and that should be
  stated plainly.
- Zide is now unusually strong on explicit host-contract richness and
  native/FFI convergence for a project at this stage.
- The current phase is post-rewrite cleanup/restructure plus disciplined
  hardening, not open-ended rewrite invention.

## Keep Out Of The Notes

- Do not dump a long commit inventory.
- Do not frame this as if the rewrite itself just landed yesterday.
- Do not emphasize old war-room env toggles, removed probes, or internal debug
  cleanup unless it materially changes the live runtime story.
- Do not claim final reference-terminal parity.
- Do not undersell the FFI lane now that a second real host has exercised it.

## Release Checklist

- Replace `<tag>` with the actual release tag.
- Use the canonical split:
  - product version: `0.x.y[-beta.n]`
  - release tag: `v0.x.y[-beta.n]`
- Confirm the release asset list matches what was published.
- Mention only the highest-value compatibility wins from that checkpoint.
- Mention the strongest host-contract checkpoint only if it changed user-facing
  confidence for embedded/foreign hosts.
- Keep the final notes short enough to scan quickly.
