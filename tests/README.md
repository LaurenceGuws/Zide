# Tests Layout

Repo-wide test layout policy:

- `fixtures/` holds replay inputs, goldens, captured evidence, and stable test assets.
- `tests/` holds integration suites, aggregate test entrypoints, and multi-module test roots.
- product-adjacent tests under `src/` are allowed only when locality materially improves comprehension of a tightly coupled subsystem.

Current transition rule:

- keep tightly coupled tests near the subsystem they exercise
  - example: `src/terminal/core/terminal_session_tests.zig`
- keep FFI smoke roots under `src/` only when the build graph consumes them as standalone test artifacts
  - example: `src/editor_ffi_smoke_tests.zig`
- move root-level non-product test entrypoints out of `src/` into `tests/` in category-based slices
- do not mass-move every test file in one patch

Current intentional `src/` exceptions:

- [terminal_session_tests.zig](/home/home/personal/zide/src/terminal/core/terminal_session_tests.zig)
  - stays source-adjacent because it is tightly coupled to `TerminalSession` ownership and regression locality matters more than one fewer file in `tests/`
- [editor_ffi_smoke_tests.zig](/home/home/personal/zide/src/editor_ffi_smoke_tests.zig)
  - stays under `src/` because it is a dedicated standalone FFI smoke root consumed directly by the build graph, not a generic aggregate/integration entrypoint

This policy is intended to eliminate ambiguity, not to ban source-adjacent tests.
