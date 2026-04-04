# Terminal Beta Checkpoint Summary

This is the shortest practical orientation for users and integrators after the
post-rewrite terminal beta checkpoint.

## What is different now

- The native terminal path is the rewritten VT/render architecture and is no longer
  acting as a privileged semantic reference.
- The host contract is now explicit for redraw, snapshot, metadata, viewport,
  pending outbound input, and child-exit truth.
- FFI and native share one hot render loop intent instead of separate semantics.

## What is intentionally conservative

- `snapshot_diff` is available and real, but some transitions still fall back to
  full refresh by design:
  - startup full-baseline churn
  - unstable/transitioning history shifts
  - alt-screen transitions
- First-release contract design favors predictable host calls and simple ownership
  over maximal diff-compression cleverness.

## Where the current checkpoint points

- [Terminal architecture comparison](TERMINAL_ARCHITECTURE_COMPARISON.md)
- [Terminal FFI bridge design](ffi/BRIDGE_DESIGN.md)
- [Terminal snapshot ABI](ffi/SNAPSHOT_ABI.md)
- [Latest terminal release notes](../releases/v0.1.0-beta.5.md)

## Why this checkpoint exists

The rewrite is considered done for this phase. This checkpoint is now focused on
cleaning the host boundary and hardening behavior under real workloads, with a
second host integration proving shared semantics.
