# Tests Layout

Repo-wide test layout policy:

- `fixtures/` holds replay inputs, goldens, captured evidence, and stable test assets.
- `tests/` holds integration suites, aggregate test entrypoints, and multi-module test roots.
- product-adjacent tests under `src/` are allowed only when locality materially improves comprehension of a tightly coupled subsystem.

Current transition rule:

- keep tightly coupled tests near the subsystem they exercise
  - example: `src/terminal/core/terminal_session_tests.zig`
- move root-level non-product test entrypoints out of `src/` into `tests/` in category-based slices
- do not mass-move every test file in one patch

This policy is intended to eliminate ambiguity, not to ban source-adjacent tests.
